import Foundation
import simd
@testable import FourHUnfolderCore

// MARK: - Reusable test mesh factories

enum TestMesh {

    // MARK: - Tetrahedron

    /// Regular tetrahedron with unit edge length (4 faces, 4 vertices, 6 edges).
    static func tetrahedron() -> Mesh {
        // Vertices laid out so edge length == 1.0 everywhere.
        let s32 = Float(3.0.squareRoot() / 2.0)   // √3/2 ≈ 0.866
        let s36 = Float(3.0.squareRoot() / 6.0)   // √3/6 ≈ 0.289
        let s23 = Float((2.0 / 3.0).squareRoot())  // √(2/3) ≈ 0.816

        let mesh = Mesh()
        mesh.name = "test_tetrahedron"
        mesh.vertices = [
            Vertex(id: 0, position: SIMD3(0,    0,    0)),
            Vertex(id: 1, position: SIMD3(1,    0,    0)),
            Vertex(id: 2, position: SIMD3(0.5,  s32,  0)),
            Vertex(id: 3, position: SIMD3(0.5,  s36,  s23)),
        ]

        let tris: [(Int, Int, Int)] = [(0,1,2), (0,3,1), (1,3,2), (0,2,3)]
        for (i, (a, b, c)) in tris.enumerated() {
            let e0 = mesh.getOrAddEdge(v1: a, v2: b, faceId: i)
            let e1 = mesh.getOrAddEdge(v1: b, v2: c, faceId: i)
            let e2 = mesh.getOrAddEdge(v1: c, v2: a, faceId: i)
            mesh.faces.append(Face(id: i, a: a, b: b, c: c, edgeIds: (e0, e1, e2)))
        }
        return mesh
    }

    // MARK: - Cube

    /// Unit cube fan-triangulated into 12 triangles (8 vertices, 18 edges).
    static func cube() -> Mesh {
        let mesh = Mesh()
        mesh.name = "test_cube"
        mesh.vertices = [
            Vertex(id: 0, position: SIMD3(0, 0, 0)),
            Vertex(id: 1, position: SIMD3(1, 0, 0)),
            Vertex(id: 2, position: SIMD3(1, 1, 0)),
            Vertex(id: 3, position: SIMD3(0, 1, 0)),
            Vertex(id: 4, position: SIMD3(0, 0, 1)),
            Vertex(id: 5, position: SIMD3(1, 0, 1)),
            Vertex(id: 6, position: SIMD3(1, 1, 1)),
            Vertex(id: 7, position: SIMD3(0, 1, 1)),
        ]

        // 6 quads, each fan-triangulated as (a,b,c) + (a,c,d)
        let quads: [(Int, Int, Int, Int)] = [
            (0, 3, 2, 1), (4, 5, 6, 7),
            (0, 1, 5, 4), (2, 3, 7, 6),
            (1, 2, 6, 5), (0, 4, 7, 3),
        ]

        var fid = 0
        for (a, b, c, d) in quads {
            let e0 = mesh.getOrAddEdge(v1: a, v2: b, faceId: fid)
            let e1 = mesh.getOrAddEdge(v1: b, v2: c, faceId: fid)
            let e2 = mesh.getOrAddEdge(v1: c, v2: a, faceId: fid)
            mesh.faces.append(Face(id: fid, a: a, b: b, c: c, edgeIds: (e0, e1, e2)))
            fid += 1

            let e3 = mesh.getOrAddEdge(v1: a, v2: c, faceId: fid)
            let e4 = mesh.getOrAddEdge(v1: c, v2: d, faceId: fid)
            let e5 = mesh.getOrAddEdge(v1: d, v2: a, faceId: fid)
            mesh.faces.append(Face(id: fid, a: a, b: c, c: d, edgeIds: (e3, e4, e5)))
            fid += 1
        }
        return mesh
    }

    // MARK: - Two disconnected triangles

    /// Two separate triangles with no shared edges (2 connected components).
    static func twoSeparateTriangles() -> Mesh {
        let mesh = Mesh()
        mesh.name = "test_disconnected"
        mesh.vertices = [
            Vertex(id: 0, position: SIMD3(0,   0, 0)),
            Vertex(id: 1, position: SIMD3(1,   0, 0)),
            Vertex(id: 2, position: SIMD3(0.5, 1, 0)),
            Vertex(id: 3, position: SIMD3(5,   0, 0)),
            Vertex(id: 4, position: SIMD3(6,   0, 0)),
            Vertex(id: 5, position: SIMD3(5.5, 1, 0)),
        ]
        let tris: [(Int, Int, Int)] = [(0,1,2), (3,4,5)]
        for (i, (a, b, c)) in tris.enumerated() {
            let e0 = mesh.getOrAddEdge(v1: a, v2: b, faceId: i)
            let e1 = mesh.getOrAddEdge(v1: b, v2: c, faceId: i)
            let e2 = mesh.getOrAddEdge(v1: c, v2: a, faceId: i)
            mesh.faces.append(Face(id: i, a: a, b: b, c: c, edgeIds: (e0, e1, e2)))
        }
        return mesh
    }

    // MARK: - Two faces sharing one edge

    /// Two triangles sharing one edge — simplest non-trivial fold/cut pair.
    static func twoFacesSharedEdge() -> Mesh {
        let mesh = Mesh()
        mesh.name = "test_two_faces"
        mesh.vertices = [
            Vertex(id: 0, position: SIMD3(0,   0, 0)),
            Vertex(id: 1, position: SIMD3(1,   0, 0)),
            Vertex(id: 2, position: SIMD3(0.5, 1, 0)),
            Vertex(id: 3, position: SIMD3(0.5, 0, 1)),   // lifted out of plane
        ]
        // Face 0: (0,1,2), Face 1: (0,1,3) — share edge 0-1
        let tris: [(Int, Int, Int)] = [(0,1,2), (0,1,3)]
        for (i, (a, b, c)) in tris.enumerated() {
            let e0 = mesh.getOrAddEdge(v1: a, v2: b, faceId: i)
            let e1 = mesh.getOrAddEdge(v1: b, v2: c, faceId: i)
            let e2 = mesh.getOrAddEdge(v1: c, v2: a, faceId: i)
            mesh.faces.append(Face(id: i, a: a, b: b, c: c, edgeIds: (e0, e1, e2)))
        }
        return mesh
    }

    // MARK: - Flat strip

    /// 3 coplanar triangles in a strip, connected by 2 shared edges.
    /// MST must have exactly 2 fold edges (n-1 = 3-1).
    static func flatStrip() -> Mesh {
        // Layout: zigzag strip in XY plane
        //  v0 — v1 — v4
        //   \  / \  /
        //   v2   v3
        let mesh = Mesh()
        mesh.name = "test_flat_strip"
        mesh.vertices = [
            Vertex(id: 0, position: SIMD3(0,   0, 0)),
            Vertex(id: 1, position: SIMD3(2,   0, 0)),
            Vertex(id: 2, position: SIMD3(1,   1, 0)),
            Vertex(id: 3, position: SIMD3(3,   1, 0)),
            Vertex(id: 4, position: SIMD3(4,   0, 0)),
        ]
        // Face 0: (0,1,2), Face 1: (1,3,2), Face 2: (1,4,3)
        let tris: [(Int, Int, Int)] = [(0,1,2), (1,3,2), (1,4,3)]
        for (i, (a, b, c)) in tris.enumerated() {
            let e0 = mesh.getOrAddEdge(v1: a, v2: b, faceId: i)
            let e1 = mesh.getOrAddEdge(v1: b, v2: c, faceId: i)
            let e2 = mesh.getOrAddEdge(v1: c, v2: a, faceId: i)
            mesh.faces.append(Face(id: i, a: a, b: b, c: c, edgeIds: (e0, e1, e2)))
        }
        return mesh
    }
}

// MARK: - Pipeline helper (run full unfold pipeline on a mesh)

extension TestMesh {
    /// Runs DualGraph + KruskalMST + EdgeMarker + UnfoldEngine on mesh, returns faces.
    static func runUnfold(_ mesh: Mesh, edgeOverrides: [Int: EdgeType] = [:]) -> [UnfoldedFace] {
        let dg = DualGraphBuilder().build(mesh: mesh)
        let mstEdges = KruskalMSTBuilder().build(graph: dg)
        var foldSet = Set(mstEdges.map { $0.sharedMeshEdgeId })
        for (eid, type) in edgeOverrides {
            if type == .fold { foldSet.insert(eid) } else { foldSet.remove(eid) }
        }
        EdgeMarker().mark(mesh: mesh, foldEdgeIds: foldSet)
        return UnfoldEngine().unfold(mesh: mesh, foldEdgeIds: foldSet).faces
    }
}
