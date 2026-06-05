import Foundation
import simd

// MARK: - OBJ mesh loader
//
// Supports: v / vt / vn / f (n-gon fan-triangulated) / mtl material libraries
// Mirrors C# ObjMeshLoader: separates position vertices from UV coords,
// stores both in Mesh.vertices + Mesh.uvs + Mesh.faceUVs.

struct ObjMeshLoader: MeshLoaderProtocol {
    var supportedExtensions: [String] { ["obj"] }

    func load(from url: URL) async throws -> Mesh {
        let content = try String(contentsOf: url, encoding: .utf8)
        return try parse(content, url: url)
    }

    // MARK: - Parser

    private func parse(_ content: String, url: URL) throws -> Mesh {
        // Phase 1: collect raw data
        var positions:  [SIMD3<Float>] = []
        var uvCoords:   [SIMD2<Float>] = []
        var materialMap: [String: Int] = [:]
        var materialNames: [String] = []
        var materialTexturePaths: [String?] = []
        var currentMaterialId = -1

        struct RawFace {
            var posIdxs: [Int]
            var uvIdxs:  [Int]     // -1 if no UV for this vertex
            var materialId: Int
        }
        var rawFaces: [RawFace] = []

        let lines = content.components(separatedBy: .newlines)

        // Attempt to load MTL sidecar
        if let mtlLine = lines.first(where: { $0.hasPrefix("mtllib ") }) {
            let mtlFile = String(mtlLine.dropFirst(7)).trimmingCharacters(in: .whitespaces)
            let mtlURL  = url.deletingLastPathComponent().appendingPathComponent(mtlFile)
            parseMTL(at: mtlURL, materialMap: &materialMap,
                     materialNames: &materialNames, materialTexturePaths: &materialTexturePaths,
                     baseURL: url.deletingLastPathComponent())
        }

        for raw in lines {
            let line  = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard let token = parts.first else { continue }

            switch token {
            case "v":
                guard parts.count >= 4,
                      let x = Float(parts[1]), let y = Float(parts[2]), let z = Float(parts[3])
                else { continue }
                positions.append(SIMD3(x, y, z))

            case "vt":
                guard parts.count >= 3,
                      let u = Float(parts[1]), let v = Float(parts[2])
                else { continue }
                uvCoords.append(SIMD2(u, v))

            case "usemtl":
                guard parts.count >= 2 else { continue }
                let matName = parts[1]
                if let mid = materialMap[matName] {
                    currentMaterialId = mid
                } else {
                    // On-the-fly material
                    currentMaterialId = materialNames.count
                    materialMap[matName] = currentMaterialId
                    materialNames.append(matName)
                    materialTexturePaths.append(nil)
                }

            case "f":
                var posIdxs: [Int] = []
                var uvIdxs:  [Int] = []
                for tok in parts.dropFirst() {
                    let comps = tok.components(separatedBy: "/")
                    let pi = (Int(comps[0]) ?? 1) - 1   // 1-based → 0-based
                    let ti: Int
                    if comps.count > 1 && !comps[1].isEmpty {
                        ti = (Int(comps[1]) ?? 1) - 1
                    } else {
                        ti = -1
                    }
                    posIdxs.append(pi)
                    uvIdxs.append(ti)
                }
                guard posIdxs.count >= 3 else { continue }
                rawFaces.append(RawFace(posIdxs: posIdxs, uvIdxs: uvIdxs, materialId: currentMaterialId))

            default: break
            }
        }

        guard !positions.isEmpty else { throw MeshLoadError.invalidFile("No vertices") }
        guard !rawFaces.isEmpty  else { throw MeshLoadError.invalidFile("No faces") }

        // Phase 2: build Mesh
        let mesh = Mesh()
        mesh.name = url.deletingPathExtension().lastPathComponent
        mesh.materialNames = materialNames
        mesh.materialTexturePaths = materialTexturePaths

        // One Vertex per unique position index
        mesh.vertices = positions.enumerated().map { Vertex(id: $0.offset, position: $0.element) }
        mesh.uvs = uvCoords

        for raw in rawFaces {
            // Fan triangulation: (0, i, i+1)
            for i in 1..<(raw.posIdxs.count - 1) {
                let va = raw.posIdxs[0]
                let vb = raw.posIdxs[i]
                let vc = raw.posIdxs[i + 1]
                guard va < positions.count, vb < positions.count, vc < positions.count else { continue }

                let fid = mesh.faces.count
                let eAB = mesh.getOrAddEdge(v1: va, v2: vb, faceId: fid)
                let eBC = mesh.getOrAddEdge(v1: vb, v2: vc, faceId: fid)
                let eCA = mesh.getOrAddEdge(v1: vc, v2: va, faceId: fid)

                mesh.faces.append(Face(id: fid, a: va, b: vb, c: vc,
                                       edgeIds: (eAB, eBC, eCA),
                                       materialId: raw.materialId))

                // UV indices (-1 → 0 as safe fallback)
                let ua = raw.uvIdxs[0]     < uvCoords.count ? raw.uvIdxs[0]     : 0
                let ub = raw.uvIdxs[i]     < uvCoords.count ? raw.uvIdxs[i]     : 0
                let uc = raw.uvIdxs[i + 1] < uvCoords.count ? raw.uvIdxs[i + 1] : 0
                mesh.faceUVs.append((ua: max(0, ua), ub: max(0, ub), uc: max(0, uc)))
            }
        }

        return mesh
    }

    // MARK: - MTL sidecar parser

    private func parseMTL(at url: URL,
                          materialMap: inout [String: Int],
                          materialNames: inout [String],
                          materialTexturePaths: inout [String?],
                          baseURL: URL) {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }

        var currentMatName: String? = nil
        var currentTexPath: String? = nil

        func flush() {
            guard let name = currentMatName else { return }
            if materialMap[name] == nil {
                materialMap[name] = materialNames.count
                materialNames.append(name)
                materialTexturePaths.append(currentTexPath)
            }
            currentTexPath = nil
        }

        for raw in content.components(separatedBy: .newlines) {
            let line  = raw.trimmingCharacters(in: .whitespaces)
            let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard let token = parts.first else { continue }

            switch token {
            case "newmtl":
                flush()
                currentMatName = parts.dropFirst().joined(separator: " ")
            case "map_Kd":
                guard parts.count >= 2 else { continue }
                let rel = parts.dropFirst().joined(separator: " ")
                let resolved = URL(fileURLWithPath: rel, relativeTo: baseURL)
                currentTexPath = FileManager.default.fileExists(atPath: resolved.path)
                    ? resolved.path
                    : (FileManager.default.fileExists(atPath: rel) ? rel : nil)
            default: break
            }
        }
        flush()
    }
}
