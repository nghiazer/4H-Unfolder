import simd

struct Vertex {
    var position: SIMD3<Float>
    var normal: SIMD3<Float>
    var uv: SIMD2<Float>
}

struct Edge: Hashable {
    let a: Int
    let b: Int

    init(_ a: Int, _ b: Int) {
        self.a = min(a, b)
        self.b = max(a, b)
    }
}

struct Face {
    var vertices: [Int]

    func edges() -> [Edge] {
        let n = vertices.count
        return (0..<n).map { Edge(vertices[$0], vertices[($0 + 1) % n]) }
    }
}

struct Mesh {
    var vertices: [Vertex]
    var faces: [Face]
    var name: String

    var isValid: Bool { !vertices.isEmpty && !faces.isEmpty }

    func faceNormal(_ fi: Int) -> SIMD3<Float> {
        let f = faces[fi]
        guard f.vertices.count >= 3 else { return .zero }
        let v0 = vertices[f.vertices[0]].position
        let v1 = vertices[f.vertices[1]].position
        let v2 = vertices[f.vertices[2]].position
        return simd_normalize(simd_cross(v1 - v0, v2 - v0))
    }

    func faceCentroid(_ fi: Int) -> SIMD3<Float> {
        let f = faces[fi]
        let sum = f.vertices.reduce(SIMD3<Float>.zero) { $0 + vertices[$1].position }
        return sum / Float(f.vertices.count)
    }
}
