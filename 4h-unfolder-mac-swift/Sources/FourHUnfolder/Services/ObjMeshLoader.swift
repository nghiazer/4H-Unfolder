import Foundation
import simd

struct ObjMeshLoader: MeshLoaderProtocol {
    var supportedExtensions: [String] { ["obj"] }

    func load(from url: URL) async throws -> Mesh {
        let content = try String(contentsOf: url, encoding: .utf8)
        return try parse(content, name: url.deletingPathExtension().lastPathComponent)
    }

    private func parse(_ content: String, name: String) throws -> Mesh {
        var positions: [SIMD3<Float>] = []
        var normals:   [SIMD3<Float>] = []
        var uvs:       [SIMD2<Float>] = []
        var vertices:  [Vertex]       = []
        var faces:     [Face]         = []
        var cache:     [String: Int]  = [:]

        for raw in content.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard let token = parts.first else { continue }

            switch token {
            case "v":
                guard parts.count >= 4,
                      let x = Float(parts[1]), let y = Float(parts[2]), let z = Float(parts[3])
                else { continue }
                positions.append(SIMD3(x, y, z))

            case "vn":
                guard parts.count >= 4,
                      let x = Float(parts[1]), let y = Float(parts[2]), let z = Float(parts[3])
                else { continue }
                normals.append(simd_normalize(SIMD3(x, y, z)))

            case "vt":
                guard parts.count >= 3,
                      let u = Float(parts[1]), let v = Float(parts[2])
                else { continue }
                uvs.append(SIMD2(u, v))

            case "f":
                var faceVerts: [Int] = []
                for tok in parts.dropFirst() {
                    if let cached = cache[tok] {
                        faceVerts.append(cached)
                        continue
                    }
                    let comps = tok.components(separatedBy: "/")
                    let pi = (Int(comps[0]) ?? 1) - 1
                    let ti = comps.count > 1 && !comps[1].isEmpty ? (Int(comps[1]) ?? 1) - 1 : 0
                    let ni = comps.count > 2 ? (Int(comps[2]) ?? 1) - 1 : 0
                    let v = Vertex(
                        position: pi < positions.count ? positions[pi] : .zero,
                        normal:   ni < normals.count   ? normals[ni]   : .zero,
                        uv:       ti < uvs.count       ? uvs[ti]       : .zero
                    )
                    let idx = vertices.count
                    vertices.append(v)
                    cache[tok] = idx
                    faceVerts.append(idx)
                }
                if faceVerts.count >= 3 { faces.append(Face(vertices: faceVerts)) }

            default: break
            }
        }

        guard !vertices.isEmpty else { throw MeshLoadError.invalidFile("No vertices") }
        guard !faces.isEmpty    else { throw MeshLoadError.invalidFile("No faces") }
        return Mesh(vertices: vertices, faces: faces, name: name)
    }
}
