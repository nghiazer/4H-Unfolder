import Foundation
import simd

// MARK: - STL mesh loader (backlog Phase 5: first "extra import format")
//
// STL has no shared-vertex topology — both binary and ASCII variants repeat each triangle's 3
// vertices independently as raw floats, unlike OBJ (index references) or PDO. Mesh.getOrAddEdge
// dedupes by VERTEX INDEX, so distinct-but-coincident positions from different triangles must be
// welded into the same Vertex index before edges are built, or every face would come out as its
// own disconnected piece (no shared edges for UnfoldEngine's BFS to walk).
//
// No external dependency — conforms to the existing MeshLoaderProtocol/MeshLoaderFactory
// extension point (see ObjMeshLoader/PdoMeshLoader), consistent with this codebase's preference
// for dependency-free geometry code (PolygonOffset/FlapMerger avoided Clipper2 the same way).

struct StlMeshLoader: MeshLoaderProtocol {
    var supportedExtensions: [String] { ["stl"] }

    func load(from url: URL) async throws -> Mesh {
        let data = try Data(contentsOf: url)
        let triangles = try Self.isBinary(data)
            ? Self.parseBinary(data)
            : Self.parseASCII(data)

        guard !triangles.isEmpty else { throw MeshLoadError.invalidFile("No triangles") }

        let mesh = Mesh()
        mesh.name = url.deletingPathExtension().lastPathComponent

        var weldIndex: [WeldKey: Int] = [:]
        var vertices: [SIMD3<Float>] = []

        func weld(_ p: SIMD3<Float>) -> Int {
            let key = WeldKey(p)
            if let existing = weldIndex[key] { return existing }
            let idx = vertices.count
            vertices.append(p)
            weldIndex[key] = idx
            return idx
        }

        for tri in triangles {
            let a = weld(tri.0), b = weld(tri.1), c = weld(tri.2)
            guard a != b, b != c, a != c else { continue }   // skip degenerate triangles
            let fid = mesh.faces.count
            let eAB = mesh.getOrAddEdge(v1: a, v2: b, faceId: fid)
            let eBC = mesh.getOrAddEdge(v1: b, v2: c, faceId: fid)
            let eCA = mesh.getOrAddEdge(v1: c, v2: a, faceId: fid)
            mesh.faces.append(Face(id: fid, a: a, b: b, c: c, edgeIds: (eAB, eBC, eCA)))
        }

        guard !mesh.faces.isEmpty else { throw MeshLoadError.invalidFile("All triangles degenerate") }
        mesh.vertices = vertices.enumerated().map { Vertex(id: $0.offset, position: $0.element) }
        return mesh
    }

    // MARK: - Vertex welding

    /// Rounded-coordinate key for merging coincident vertices from independently-listed
    /// triangles. 1e-5 absolute tolerance matches typical STL export precision (well-formed files
    /// repeat shared vertices with identical or near-identical floats).
    private struct WeldKey: Hashable {
        let x, y, z: Int64
        init(_ p: SIMD3<Float>) {
            x = Int64((p.x * 100_000).rounded())
            y = Int64((p.y * 100_000).rounded())
            z = Int64((p.z * 100_000).rounded())
        }
    }

    // MARK: - Binary vs ASCII detection

    /// A binary STL is 80-byte header + 4-byte triangle count + 50 bytes/triangle. Some binary
    /// files also start with the literal bytes "solid" (an unrelated convention some exporters
    /// copy from ASCII STL), so checking for that prefix alone is unreliable — the size formula
    /// is the discriminator that actually holds.
    static func isBinary(_ data: Data) -> Bool {
        guard data.count >= 84 else { return false }
        let count = readUInt32LE(data, at: 80)
        let expected = 84 + Int(count) * 50
        return data.count == expected
    }

    // MARK: - Binary parser

    private static func parseBinary(_ data: Data) throws -> [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)] {
        let count = Int(readUInt32LE(data, at: 80))
        guard data.count >= 84 + count * 50 else {
            throw MeshLoadError.invalidFile("Binary STL truncated (declared \(count) triangles)")
        }
        var triangles: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)] = []
        triangles.reserveCapacity(count)
        var offset = 84
        for _ in 0..<count {
            // Skip the 12-byte facet normal — this loader recomputes normals geometrically
            // elsewhere (Mesh.faceNormal), same as OBJ/PDO which don't trust file-provided normals.
            let v0 = readVec3LE(data, at: offset + 12)
            let v1 = readVec3LE(data, at: offset + 24)
            let v2 = readVec3LE(data, at: offset + 36)
            triangles.append((v0, v1, v2))
            offset += 50   // 12 (normal) + 36 (3 vertices) + 2 (attribute byte count)
        }
        return triangles
    }

    private static func readUInt32LE(_ data: Data, at offset: Int) -> UInt32 {
        var v: UInt32 = 0
        for i in 0..<4 { v |= UInt32(data[data.startIndex + offset + i]) << (8 * i) }
        return v
    }

    private static func readFloatLE(_ data: Data, at offset: Int) -> Float {
        let bits = readUInt32LE(data, at: offset)
        return Float(bitPattern: bits)
    }

    private static func readVec3LE(_ data: Data, at offset: Int) -> SIMD3<Float> {
        SIMD3(
            readFloatLE(data, at: offset),
            readFloatLE(data, at: offset + 4),
            readFloatLE(data, at: offset + 8)
        )
    }

    // MARK: - ASCII parser

    /// Scans for "vertex x y z" lines regardless of surrounding facet/loop structure (robust to
    /// whitespace/formatting variation across exporters) and groups every 3 into a triangle.
    private static func parseASCII(_ data: Data) throws -> [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)] {
        guard let text = String(data: data, encoding: .utf8) else {
            throw MeshLoadError.invalidFile("Not valid UTF-8 text and not a recognized binary STL")
        }
        var flat: [SIMD3<Float>] = []
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("vertex") else { continue }
            let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard parts.count >= 4,
                  let x = Float(parts[1]), let y = Float(parts[2]), let z = Float(parts[3])
            else { continue }
            flat.append(SIMD3(x, y, z))
        }
        guard flat.count >= 3 else { throw MeshLoadError.invalidFile("No vertex lines found") }
        var triangles: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)] = []
        var i = 0
        while i + 2 < flat.count {
            triangles.append((flat[i], flat[i + 1], flat[i + 2]))
            i += 3
        }
        return triangles
    }
}
