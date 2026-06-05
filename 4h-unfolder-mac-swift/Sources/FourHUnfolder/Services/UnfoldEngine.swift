import Foundation
import simd

// Core unfold pipeline — mirrors UnfoldEngine.cs / face_unfold.rs logic:
//   1. Build face adjacency (dual graph) from shared edges
//   2. BFS spanning tree from face 0
//   3. Unfold each face by projecting about the shared edge into 2D

struct UnfoldEngine {

    func unfold(mesh: Mesh) -> UnfoldResult {
        guard mesh.isValid else {
            return UnfoldResult(faces: [], tabs: [], boundingBox: (.zero, .zero))
        }
        let adj   = buildAdjacency(mesh)
        let tree  = buildSpanningTree(adj, faceCount: mesh.faces.count)
        let faces = unfoldFaces(mesh, tree: tree)
        let bbox  = computeBBox(faces)
        return UnfoldResult(faces: faces, tabs: [], boundingBox: bbox)
    }

    // MARK: - Adjacency

    struct Adjacency {
        let face1: Int; let face2: Int
        let v0: Int;    let v1: Int     // shared vertex indices (mesh-global)
    }

    private func buildAdjacency(_ mesh: Mesh) -> [Adjacency] {
        var edgeMap: [Edge: [Int]] = [:]
        for (fi, face) in mesh.faces.enumerated() {
            for e in face.edges() { edgeMap[e, default: []].append(fi) }
        }
        return edgeMap.compactMap { edge, fs in
            fs.count == 2 ? Adjacency(face1: fs[0], face2: fs[1], v0: edge.a, v1: edge.b) : nil
        }
    }

    // MARK: - Spanning tree (BFS from face 0)

    struct TreeEdge {
        let parent: Int; let child: Int
        let v0: Int;     let v1: Int
    }

    private func buildSpanningTree(_ adj: [Adjacency], faceCount: Int) -> [TreeEdge] {
        var graph: [Int: [(neighbor: Int, v0: Int, v1: Int)]] = [:]
        for a in adj {
            graph[a.face1, default: []].append((a.face2, a.v0, a.v1))
            graph[a.face2, default: []].append((a.face1, a.v0, a.v1))
        }

        var visited = Set<Int>([0])
        var queue   = [0]
        var tree:   [TreeEdge] = []

        while !queue.isEmpty {
            let cur = queue.removeFirst()
            for nb in graph[cur] ?? [] where !visited.contains(nb.neighbor) {
                visited.insert(nb.neighbor)
                tree.append(TreeEdge(parent: cur, child: nb.neighbor, v0: nb.v0, v1: nb.v1))
                queue.append(nb.neighbor)
            }
        }
        return tree
    }

    // MARK: - Face unfolding

    private func unfoldFaces(_ mesh: Mesh, tree: [TreeEdge]) -> [UnfoldedFace] {
        var result = [Int: UnfoldedFace]()

        // Root face: project onto its own local XY plane
        result[0] = projectRoot(mesh.faces[0], mesh: mesh, faceIndex: 0)

        // Build children map for BFS
        var children = [Int: [TreeEdge]]()
        for e in tree { children[e.parent, default: []].append(e) }

        var queue = [0]
        while !queue.isEmpty {
            let parent = queue.removeFirst()
            guard let parentFace2D = result[parent] else { continue }
            let parentFace3D = mesh.faces[parent]

            for te in children[parent] ?? [] {
                guard let p0_2D = vertex2D(meshIdx: te.v0, face3D: parentFace3D, face2D: parentFace2D),
                      let p1_2D = vertex2D(meshIdx: te.v1, face3D: parentFace3D, face2D: parentFace2D)
                else { continue }

                let childFace2D = unfoldChild(
                    child: mesh.faces[te.child], mesh: mesh, faceIndex: te.child,
                    sharedV0: te.v0, sharedV1: te.v1,
                    p0_2D: p0_2D, p1_2D: p1_2D,
                    parentCentroid2D: centroid2D(parentFace2D)
                )
                result[te.child] = childFace2D
                queue.append(te.child)
            }
        }

        return (0..<mesh.faces.count).compactMap { result[$0] }
    }

    // Project root face into its own local XY plane (first edge → X axis)
    private func projectRoot(_ face: Face, mesh: Mesh, faceIndex: Int) -> UnfoldedFace {
        guard face.vertices.count >= 3 else { return UnfoldedFace(faceIndex: faceIndex, vertices2D: []) }
        let v0 = mesh.vertices[face.vertices[0]].position
        let v1 = mesh.vertices[face.vertices[1]].position
        let v2 = mesh.vertices[face.vertices[2]].position
        let xAxis  = simd_normalize(v1 - v0)
        let normal = simd_normalize(simd_cross(v1 - v0, v2 - v0))
        let yAxis  = simd_cross(normal, xAxis)
        let pts = face.vertices.map { vi -> SIMD2<Float> in
            let p = mesh.vertices[vi].position - v0
            return SIMD2(simd_dot(p, xAxis), simd_dot(p, yAxis))
        }
        return UnfoldedFace(faceIndex: faceIndex, vertices2D: pts)
    }

    // Unfold child face about the shared edge (p0_2D ↔ p1_2D) into 2D
    private func unfoldChild(child: Face, mesh: Mesh, faceIndex: Int,
                             sharedV0: Int, sharedV1: Int,
                             p0_2D: SIMD2<Float>, p1_2D: SIMD2<Float>,
                             parentCentroid2D: SIMD2<Float>) -> UnfoldedFace {
        let q0 = mesh.vertices[sharedV0].position
        let q1 = mesh.vertices[sharedV1].position

        let edgeDir3D  = simd_normalize(q1 - q0)
        // Face-plane perpendicular pointing into child face interior
        let faceNormal = simd_normalize(simd_cross(q1 - q0,
                                                    thirdVertex(child, mesh: mesh,
                                                                shared: [sharedV0, sharedV1]) - q0))
        let intoFace3D = simd_cross(edgeDir3D, faceNormal)   // right-hand: points "into" face

        // 2D coordinate frame along the shared edge
        let edgeDir2D = simd_normalize(p1_2D - p0_2D)
        // Choose perpendicular pointing AWAY from parent centroid
        let perp2D_cw  = SIMD2<Float>( edgeDir2D.y, -edgeDir2D.x)
        let perp2D_ccw = SIMD2<Float>(-edgeDir2D.y,  edgeDir2D.x)
        let edgeMid    = (p0_2D + p1_2D) * 0.5
        let toParent   = parentCentroid2D - edgeMid
        let perp2D     = simd_dot(toParent, perp2D_cw) < 0 ? perp2D_cw : perp2D_ccw

        let pts = child.vertices.map { vi -> SIMD2<Float> in
            let p3D    = mesh.vertices[vi].position - q0
            let along  = simd_dot(p3D, edgeDir3D)   // component along edge
            let across = simd_dot(p3D, intoFace3D)  // component perpendicular to edge
            return p0_2D + edgeDir2D * along + perp2D * across
        }
        return UnfoldedFace(faceIndex: faceIndex, vertices2D: pts)
    }

    // MARK: - Helpers

    private func thirdVertex(_ face: Face, mesh: Mesh, shared: Set<Int>) -> SIMD3<Float> {
        for vi in face.vertices where !shared.contains(vi) {
            return mesh.vertices[vi].position
        }
        return mesh.vertices[face.vertices[0]].position
    }

    private func vertex2D(meshIdx: Int, face3D: Face, face2D: UnfoldedFace) -> SIMD2<Float>? {
        for (i, vi) in face3D.vertices.enumerated() where vi == meshIdx {
            return i < face2D.vertices2D.count ? face2D.vertices2D[i] : nil
        }
        return nil
    }

    private func centroid2D(_ face: UnfoldedFace) -> SIMD2<Float> {
        guard !face.vertices2D.isEmpty else { return .zero }
        return face.vertices2D.reduce(.zero, +) / Float(face.vertices2D.count)
    }

    private func computeBBox(_ faces: [UnfoldedFace]) -> (min: SIMD2<Float>, max: SIMD2<Float>) {
        var lo = SIMD2<Float>(repeating:  Float.infinity)
        var hi = SIMD2<Float>(repeating: -Float.infinity)
        for face in faces {
            for v in face.vertices2D { lo = simd_min(lo, v); hi = simd_max(hi, v) }
        }
        return (lo, hi)
    }
}
