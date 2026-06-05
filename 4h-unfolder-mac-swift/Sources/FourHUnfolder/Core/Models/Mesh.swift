import Foundation
import simd

// MARK: - Edge type (assigned after MST + overrides)

enum EdgeType: String, Codable, Equatable {
    case unknown, fold, cut, boundary
}

// MARK: - Core mesh components

struct Vertex {
    var id: Int
    var position: SIMD3<Float>
}

struct Edge {
    var id: Int
    var v1: Int             // canonical: v1 < v2
    var v2: Int
    var faceA: Int = -1
    var faceB: Int = -1
    var type: EdgeType = .unknown

    var isBoundary: Bool    { faceB == -1 }
    var connectsFaces: Bool { faceA >= 0 && faceB >= 0 }
}

struct Face {
    var id: Int
    var a: Int, b: Int, c: Int      // indices into Mesh.vertices
    var edgeIds: (Int, Int, Int)    // edge AB, BC, CA
    var materialId: Int = -1
}

// MARK: - Texture / material data

struct EmbeddedTextureData {
    let name: String
    let width: Int
    let height: Int
    let rgb24Bytes: Data        // width × height × 3, RGB, top-to-bottom
}

// MARK: - PDO pre-computed 2D layout

struct PdoFace {
    let faceIndex: Int
    let partIndex: Int
    let a: SIMD2<Float>
    let b: SIMD2<Float>
    let c: SIMD2<Float>
}

struct PdoLayout {
    var faces: [PdoFace]        // parallel to Mesh.faces (may be shorter if face filtered)
}

// MARK: - Mesh

final class Mesh {
    var name: String = ""
    var vertices: [Vertex] = []
    var edges: [Edge] = []
    var faces: [Face] = []

    var uvs: [SIMD2<Float>] = []
    var faceUVs: [(ua: Int, ub: Int, uc: Int)] = []     // parallel to faces

    var embeddedTextures: [EmbeddedTextureData] = []
    var materialNames: [String] = []
    var materialTexturePaths: [String?] = []

    var pdoLayout: PdoLayout? = nil

    // Canonical (min, max) → edgeId lookup built during face construction
    private var edgeMap: [SIMD2<Int32>: Int] = [:]

    var isValid: Bool { !vertices.isEmpty && !faces.isEmpty }

    // MARK: - Edge management

    /// Returns edge ID, creating the edge if it doesn't exist yet.
    @discardableResult
    func getOrAddEdge(v1: Int, v2: Int, faceId: Int) -> Int {
        let key = SIMD2<Int32>(Int32(min(v1, v2)), Int32(max(v1, v2)))
        if let existing = edgeMap[key] {
            // Second face encountering this edge
            if edges[existing].faceB == -1 {
                edges[existing].faceB = faceId
            }
            return existing
        }
        let eid = edges.count
        var edge = Edge(id: eid, v1: min(v1, v2), v2: max(v1, v2))
        edge.faceA = faceId
        edges.append(edge)
        edgeMap[key] = eid
        return eid
    }

    // MARK: - Geometry helpers

    func faceNormal(_ fi: Int) -> SIMD3<Float> {
        let f = faces[fi]
        guard f.a < vertices.count, f.b < vertices.count, f.c < vertices.count else {
            return SIMD3(0, 1, 0)
        }
        let p0 = vertices[f.a].position
        let p1 = vertices[f.b].position
        let p2 = vertices[f.c].position
        let n = simd_cross(p1 - p0, p2 - p0)
        let len = simd_length(n)
        return len > 1e-10 ? n / len : SIMD3(0, 1, 0)
    }

    func faceCentroid(_ fi: Int) -> SIMD3<Float> {
        let f = faces[fi]
        return (vertices[f.a].position + vertices[f.b].position + vertices[f.c].position) / 3
    }

    func edgeLength(_ eid: Int) -> Float {
        let e = edges[eid]
        return simd_length(vertices[e.v2].position - vertices[e.v1].position)
    }

    /// Apply rigid-body transform to all vertices.
    func applyTransform(_ m: simd_float4x4) {
        for i in vertices.indices {
            let p = vertices[i].position
            let t = m * SIMD4(p.x, p.y, p.z, 1)
            vertices[i].position = SIMD3(t.x, t.y, t.z)
        }
    }
}
