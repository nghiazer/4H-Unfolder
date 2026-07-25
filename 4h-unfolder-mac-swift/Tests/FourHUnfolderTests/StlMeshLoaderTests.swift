import XCTest
import Foundation
import simd
@testable import FourHUnfolderCore

/// Backlog Phase 5: StlMeshLoader (first "extra import format", conforms to the existing
/// MeshLoaderProtocol/MeshLoaderFactory extension point). See StlMeshLoader.swift.
final class StlMeshLoaderTests: XCTestCase {

    // MARK: - Synthetic cube fixture (12 triangles, vertices repeated per-triangle — no shared
    // indices, matching real STL's lack of topology, unlike OBJ's index references)

    private let cubeVerts: [SIMD3<Float>] = [
        SIMD3(0, 0, 0), SIMD3(1, 0, 0), SIMD3(1, 1, 0), SIMD3(0, 1, 0),
        SIMD3(0, 0, 1), SIMD3(1, 0, 1), SIMD3(1, 1, 1), SIMD3(0, 1, 1),
    ]
    private let cubeQuads: [(Int, Int, Int, Int)] = [
        (0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (2, 3, 7, 6), (1, 2, 6, 5), (0, 4, 7, 3),
    ]

    private func cubeTriangles() -> [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)] {
        var tris: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)] = []
        for (a, b, c, d) in cubeQuads {
            tris.append((cubeVerts[a], cubeVerts[b], cubeVerts[c]))
            tris.append((cubeVerts[a], cubeVerts[c], cubeVerts[d]))
        }
        return tris
    }

    private func binaryCubeData() -> Data {
        func f32le(_ v: Float) -> [UInt8] { withUnsafeBytes(of: v.bitPattern.littleEndian) { Array($0) } }
        func u32le(_ v: UInt32) -> [UInt8] { withUnsafeBytes(of: v.littleEndian) { Array($0) } }
        let tris = cubeTriangles()
        var data = Data(repeating: 0, count: 80)
        data.append(contentsOf: u32le(UInt32(tris.count)))
        for (v0, v1, v2) in tris {
            data.append(contentsOf: f32le(0) + f32le(0) + f32le(0))
            for v in [v0, v1, v2] { data.append(contentsOf: f32le(v.x) + f32le(v.y) + f32le(v.z)) }
            data.append(contentsOf: [0, 0])
        }
        return data
    }

    private func asciiCubeData() -> Data {
        var lines = ["solid testcube"]
        for (v0, v1, v2) in cubeTriangles() {
            lines.append("facet normal 0 0 0")
            lines.append("  outer loop")
            for v in [v0, v1, v2] { lines.append("    vertex \(v.x) \(v.y) \(v.z)") }
            lines.append("  endloop")
            lines.append("endfacet")
        }
        lines.append("endsolid testcube")
        return lines.joined(separator: "\n").data(using: .utf8)!
    }

    // MARK: - Binary vs ASCII detection

    func testIsBinary_realBinaryBuffer_true() {
        XCTAssertTrue(StlMeshLoader.isBinary(binaryCubeData()))
    }

    func testIsBinary_realAsciiBuffer_false() {
        XCTAssertFalse(StlMeshLoader.isBinary(asciiCubeData()))
    }

    func testIsBinary_binaryHeaderStartingWithSolidBytes_stillDetectedAsBinary() {
        // Some binary STL exporters copy the "solid" convention into the header — the size
        // formula must win over any prefix check.
        func f32le(_ v: Float) -> [UInt8] { withUnsafeBytes(of: v.bitPattern.littleEndian) { Array($0) } }
        func u32le(_ v: UInt32) -> [UInt8] { withUnsafeBytes(of: v.littleEndian) { Array($0) } }
        let tris = cubeTriangles()
        var data = Data("solid ".utf8)
        data.append(Data(repeating: 0x41, count: 80 - data.count))
        data.append(contentsOf: u32le(UInt32(tris.count)))
        for (v0, v1, v2) in tris {
            data.append(contentsOf: f32le(0) + f32le(0) + f32le(0))
            for v in [v0, v1, v2] { data.append(contentsOf: f32le(v.x) + f32le(v.y) + f32le(v.z)) }
            data.append(contentsOf: [0, 0])
        }
        XCTAssertTrue(StlMeshLoader.isBinary(data))
    }

    func testIsBinary_tooShortForHeader_false() {
        XCTAssertFalse(StlMeshLoader.isBinary(Data(repeating: 0, count: 10)))
    }

    // MARK: - Binary cube load

    func testBinaryCube_faceCount() async throws {
        let mesh = try await loadData(binaryCubeData(), name: "cube.stl")
        XCTAssertEqual(mesh.faces.count, 12)
    }

    func testBinaryCube_weldsToEightVertices() async throws {
        let mesh = try await loadData(binaryCubeData(), name: "cube.stl")
        XCTAssertEqual(mesh.vertices.count, 8,
                       "36 raw triangle-vertices must weld down to the cube's 8 unique corners")
    }

    func testBinaryCube_edgeCount() async throws {
        let mesh = try await loadData(binaryCubeData(), name: "cube.stl")
        XCTAssertEqual(mesh.edges.count, 18)
    }

    func testBinaryCube_noBoundaryEdges() async throws {
        let mesh = try await loadData(binaryCubeData(), name: "cube.stl")
        let boundary = mesh.edges.filter { $0.isBoundary }
        XCTAssertEqual(boundary.count, 0, "Closed cube surface has no boundary edges")
    }

    func testBinaryCube_meshNameFromFilename() async throws {
        let mesh = try await loadData(binaryCubeData(), name: "my_cube.stl")
        XCTAssertEqual(mesh.name, "my_cube")
    }

    // MARK: - ASCII cube load

    func testAsciiCube_faceCount() async throws {
        let mesh = try await loadData(asciiCubeData(), name: "cube_ascii.stl")
        XCTAssertEqual(mesh.faces.count, 12)
    }

    func testAsciiCube_weldsToEightVertices() async throws {
        let mesh = try await loadData(asciiCubeData(), name: "cube_ascii.stl")
        XCTAssertEqual(mesh.vertices.count, 8)
    }

    func testAsciiCube_edgeCount() async throws {
        let mesh = try await loadData(asciiCubeData(), name: "cube_ascii.stl")
        XCTAssertEqual(mesh.edges.count, 18)
    }

    // MARK: - MeshLoaderFactory dispatch

    func testMeshLoaderFactory_routesStlExtension() async throws {
        let url = try writeTemp(binaryCubeData(), name: "factory_cube.stl")
        defer { try? FileManager.default.removeItem(at: url) }
        let mesh = try await MeshLoaderFactory().load(from: url)
        XCTAssertEqual(mesh.faces.count, 12)
    }

    // MARK: - Error cases

    func testEmptyFile_throws() async throws {
        let url = try writeTemp(Data(), name: "empty.stl")
        defer { try? FileManager.default.removeItem(at: url) }
        do {
            _ = try await StlMeshLoader().load(from: url)
            XCTFail("Empty file should throw")
        } catch { /* expected */ }
    }

    func testGarbageNonUtf8NonBinary_throws() async throws {
        // Too short to be a valid binary STL AND not valid UTF-8 text.
        let garbage = Data([0xFF, 0xFE, 0xFD, 0x00, 0x01])
        let url = try writeTemp(garbage, name: "garbage.stl")
        defer { try? FileManager.default.removeItem(at: url) }
        do {
            _ = try await StlMeshLoader().load(from: url)
            XCTFail("Unparseable garbage should throw")
        } catch { /* expected */ }
    }

    func testAsciiWithNoVertexLines_throws() async throws {
        let content = "solid empty\nendsolid empty\n".data(using: .utf8)!
        let url = try writeTemp(content, name: "no_vertices.stl")
        defer { try? FileManager.default.removeItem(at: url) }
        do {
            _ = try await StlMeshLoader().load(from: url)
            XCTFail("ASCII STL with no vertex lines should throw")
        } catch { /* expected */ }
    }

    // MARK: - Helpers

    private func loadData(_ data: Data, name: String) async throws -> Mesh {
        let url = try writeTemp(data, name: name)
        defer { try? FileManager.default.removeItem(at: url) }
        return try await StlMeshLoader().load(from: url)
    }

    private func writeTemp(_ data: Data, name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try data.write(to: url)
        return url
    }
}
