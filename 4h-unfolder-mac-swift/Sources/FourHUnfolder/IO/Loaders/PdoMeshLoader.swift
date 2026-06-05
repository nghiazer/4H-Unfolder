import Foundation
import Compression

// MARK: - PDO v3 / PD6 binary mesh loader
//
// Format layout (absolute offsets from file start):
//   0–9   : "version 3\n" ASCII signature
//  10–21  : locked(4) + unk1(4) + version(4)  — all UInt32 LE
//  22–25  : localeLen (bytes)
//  26–..  : localeLen bytes UTF-16LE locale  (raw, NO cipher)
//  26+localeLen+0 : cipherKey  UInt32 — subtraction cipher: (raw-key+256)&0xFF
//  26+localeLen+4 : commentLen UInt32
//  26+localeLen+8 : commentLen bytes cipher-encoded comment (skipped)
//  154+localeLen+commentLen : geoCount UInt32  ← absolute seek target
//
// Geometry: wstr name + bool unk8 + vertices (raw doubles) + shapes + edges
// Per-point (85 bytes): vtxIdx(4) + cx(8) + cy(8) + u(8) + v(8) + unk(49)
// Textures (after geo): texCount + per-tex (wstr + 80 bytes + hasImage byte + optional w/h/csize/zlib)

struct PdoMeshLoader: MeshLoaderProtocol {
    var supportedExtensions: [String] { ["pdo"] }

    func load(from url: URL) async throws -> Mesh {
        let fileData = try Data(contentsOf: url, options: .mappedIfSafe)
        var r = DataReader(data: fileData)

        // ── 1. Signature ────────────────────────────────────────────────────
        let sig = try r.readASCII(length: 10)
        guard sig == "version 3\n" else {
            throw MeshLoadError.invalidFile("Not a PDO v3 file — bad signature: '\(sig.trimmingCharacters(in: .newlines))'")
        }

        // ── 2. Fixed header ──────────────────────────────────────────────────
        _ = try r.readUInt32()                    // locked
        _ = try r.readUInt32()                    // unk1
        _ = try r.readUInt32()                    // version

        let localeLen  = try r.readUInt32()       // abs 22
        try r.skip(Int(localeLen))                // locale bytes (raw, no cipher)

        let key        = try r.readUInt32()       // cipher key
        let commentLen = try r.readUInt32()       // comment byte count
        try r.skip(Int(commentLen))               // comment (cipher-encoded, skipped)

        // ── 3. Seek to geometry section ─────────────────────────────────────
        // abs = 154 + localeLen + commentLen  (bypasses 120-byte pre-geo settings block)
        let geoStart = 154 + Int(localeLen) + Int(commentLen)
        try r.seek(to: geoStart)

        // ── 4. Geometry ──────────────────────────────────────────────────────
        let mesh = Mesh()
        mesh.name = url.deletingPathExtension().lastPathComponent
        var pdoLayout = PdoLayout(faces: [])

        let geoCount = try r.readUInt32()
        for _ in 0..<geoCount {
            let vtxBase = mesh.vertices.count

            _ = try r.readWStr(key: key)          // geo name — discard
            _ = try r.readByte()                  // unk8

            // Vertices — raw doubles, NO cipher
            let vtxCount = try r.readUInt32()
            for _ in 0..<vtxCount {
                let x = Float(try r.readDouble())
                let y = Float(try r.readDouble())
                let z = Float(try r.readDouble())
                let vid = mesh.vertices.count
                mesh.vertices.append(Vertex(id: vid, position: SIMD3<Float>(x, y, z)))
            }

            // Shapes → fan-triangulated faces
            let shapeCount = try r.readUInt32()
            for _ in 0..<shapeCount {
                let materialId = Int(try r.readInt32())  // texture index (unk11)
                let partIndex  = Int(try r.readUInt32()) // 2D piece group
                try r.skip(32)                           // 4×double unk12

                let ptCount = Int(try r.readUInt32())
                var indices   = [Int](repeating: 0, count: ptCount)
                var uvIndices = [Int](repeating: 0, count: ptCount)
                var coords2D  = [SIMD2<Float>](repeating: .zero, count: ptCount)

                for pi in 0..<ptCount {
                    indices[pi] = Int(try r.readUInt32()) + vtxBase  // 4 bytes

                    let cx = Float(try r.readDouble())                // 8 bytes — paper x
                    let cy = Float(try r.readDouble())                // 8 bytes — paper y
                    coords2D[pi] = SIMD2<Float>(cx, cy)

                    let u = Float(try r.readDouble())                 // 8 bytes
                    let v = 1.0 - Float(try r.readDouble())           // 8 bytes — Y-flip
                    mesh.uvs.append(SIMD2<Float>(u, v))
                    uvIndices[pi] = mesh.uvs.count - 1

                    try r.skip(49) // unk14(1) + unk15(24) + unk16(24) = 49
                    // total per-point: 4+8+8+8+8+49 = 85 ✓
                }

                // Fan-triangulate polygon: (v0,v1,v2), (v0,v2,v3), …
                if ptCount >= 3 {
                    for ti in 1..<(ptCount - 1) {
                        let faceIdx = mesh.faces.count
                        let a = indices[0], b = indices[ti], c = indices[ti + 1]
                        let ua = uvIndices[0], ub = uvIndices[ti], uc = uvIndices[ti + 1]

                        let eAB = mesh.getOrAddEdge(v1: a, v2: b, faceId: faceIdx)
                        let eBC = mesh.getOrAddEdge(v1: b, v2: c, faceId: faceIdx)
                        let eCA = mesh.getOrAddEdge(v1: c, v2: a, faceId: faceIdx)

                        mesh.faces.append(Face(
                            id: faceIdx,
                            a: a, b: b, c: c,
                            edgeIds: (eAB, eBC, eCA),
                            materialId: materialId
                        ))
                        mesh.faceUVs.append((ua: ua, ub: ub, uc: uc))

                        pdoLayout.faces.append(PdoFace(
                            faceIndex: faceIdx,
                            partIndex: partIndex,
                            a: coords2D[0],
                            b: coords2D[ti],
                            c: coords2D[ti + 1]
                        ))
                    }
                }
            }

            // Skip edge data (22 bytes per entry) — topology reconstructed from geometry
            let edgeCount = try r.readUInt32()
            try r.skip(Int(edgeCount) * 22)
        }

        if !pdoLayout.faces.isEmpty {
            mesh.pdoLayout = pdoLayout
        }

        // ── 5. Texture section ───────────────────────────────────────────────
        // Optional — silently ignore parse failures
        do {
            let texCount = try r.readUInt32()
            for _ in 0..<texCount {
                let texName = try r.readWStr(key: key)
                try r.skip(80)                         // 5×(4 floats)

                let hasImage = try r.readByte() != 0
                guard hasImage else { continue }

                let w     = Int(try r.readUInt32())
                let h     = Int(try r.readUInt32())
                let csize = Int(try r.readUInt32())
                let compressed = try r.readData(csize)

                let expectedSize = w * h * 3
                guard expectedSize > 0 else { continue }
                if let rgb = decompressZlib(compressed, expectedSize: expectedSize) {
                    mesh.embeddedTextures.append(
                        EmbeddedTextureData(name: texName, width: w, height: h, rgb24Bytes: rgb)
                    )
                }
            }
        } catch {
            // Texture section is optional — ignore EOF / parse errors
        }

        // ── 6. Material names from embedded textures ─────────────────────────
        for tex in mesh.embeddedTextures {
            mesh.materialNames.append(tex.name)
            mesh.materialTexturePaths.append(nil) // embedded, no file path
        }

        return mesh
    }

    // MARK: - zlib decompression (RFC 1950 — strip 2-byte header, raw DEFLATE)

    private func decompressZlib(_ data: Data, expectedSize: Int) -> Data? {
        // Zlib RFC 1950: 2-byte CMF+FLG header + raw DEFLATE + 4-byte Adler-32
        // Apple's COMPRESSION_ZLIB handles raw DEFLATE (RFC 1951), so strip the header.
        guard data.count > 6 else { return nil }
        let deflate = data.dropFirst(2)

        var output = Data(repeating: 0, count: expectedSize)
        let decoded = deflate.withUnsafeBytes { src -> Int in
            guard let srcPtr = src.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return output.withUnsafeMutableBytes { dst -> Int in
                guard let dstPtr = dst.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                return compression_decode_buffer(dstPtr, expectedSize,
                                                 srcPtr, deflate.count,
                                                 nil, COMPRESSION_ZLIB)
            }
        }
        return decoded == expectedSize ? output : nil
    }
}

// MARK: - Internal binary reader

private struct DataReader {
    private let data: Data
    private(set) var offset: Int = 0

    init(data: Data) { self.data = data }

    mutating func readByte() throws -> UInt8 {
        guard offset < data.count else { throw PDOParseError.unexpectedEOF }
        defer { offset += 1 }
        return data[offset]
    }

    mutating func readUInt32() throws -> UInt32 {
        let bytes = try readData(4)
        return bytes.withUnsafeBytes { UInt32(littleEndian: $0.load(as: UInt32.self)) }
    }

    mutating func readInt32() throws -> Int32 {
        let bytes = try readData(4)
        return bytes.withUnsafeBytes { Int32(littleEndian: $0.load(as: Int32.self)) }
    }

    mutating func readDouble() throws -> Double {
        let bytes = try readData(8)
        let bits = bytes.withUnsafeBytes { UInt64(littleEndian: $0.load(as: UInt64.self)) }
        return Double(bitPattern: bits)
    }

    mutating func readData(_ count: Int) throws -> Data {
        guard count >= 0, offset + count <= data.count else { throw PDOParseError.unexpectedEOF }
        let slice = data[offset..<offset + count]
        offset += count
        return slice
    }

    mutating func skip(_ count: Int) throws {
        guard count >= 0, offset + count <= data.count else { throw PDOParseError.unexpectedEOF }
        offset += count
    }

    mutating func seek(to position: Int) throws {
        guard position >= 0, position <= data.count else { throw PDOParseError.unexpectedEOF }
        offset = position
    }

    /// Reads `length` bytes as an ASCII string (no cipher).
    mutating func readASCII(length: Int) throws -> String {
        let bytes = try readData(length)
        return String(bytes: bytes, encoding: .ascii) ?? ""
    }

    /// PDO wide-string: UInt32 byte-count (raw) + UTF-16LE bytes (cipher-encoded).
    /// Cipher: decoded = (raw - key + 256) & 0xFF
    mutating func readWStr(key: UInt32) throws -> String {
        let byteLen = Int(try readUInt32())
        guard byteLen > 0 else { return "" }
        var raw = try readData(byteLen)
        let k = UInt8(key & 0xFF)
        for i in raw.indices {
            raw[i] = UInt8((Int(raw[i]) &- Int(k) &+ 256) & 0xFF)
        }
        return String(bytes: raw, encoding: .utf16LittleEndian)?
            .trimmingCharacters(in: CharacterSet(["\0"])) ?? ""
    }

    enum PDOParseError: Error { case unexpectedEOF }
}
