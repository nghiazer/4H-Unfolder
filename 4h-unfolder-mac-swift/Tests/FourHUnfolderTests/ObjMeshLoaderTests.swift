import XCTest
import Foundation
@testable import FourHUnfolderCore

final class ObjMeshLoaderTests: XCTestCase {

    // MARK: - OBJ fixtures

    /// 6-quad unit cube: 8 vertices, fan-triangulates to 12 faces, 18 edges.
    private let cubeOBJ = """
        # Unit cube — 6 quads
        v 0 0 0
        v 1 0 0
        v 1 1 0
        v 0 1 0
        v 0 0 1
        v 1 0 1
        v 1 1 1
        v 0 1 1
        f 1 2 3 4
        f 5 8 7 6
        f 1 5 6 2
        f 2 6 7 3
        f 3 7 8 4
        f 4 8 5 1
        """

    /// Single triangle — minimal valid OBJ.
    private let triangleOBJ = """
        v 0 0 0
        v 1 0 0
        v 0.5 1 0
        f 1 2 3
        """

    // MARK: - Cube parsing

    func testCube_vertexCount() async throws {
        let mesh = try await loadString(cubeOBJ, name: "cube.obj")
        XCTAssertEqual(mesh.vertices.count, 8)
    }

    func testCube_faceCount() async throws {
        let mesh = try await loadString(cubeOBJ, name: "cube.obj")
        XCTAssertEqual(mesh.faces.count, 12,
                       "6 quads fan-triangulated = 12 triangles")
    }

    func testCube_edgeCount() async throws {
        let mesh = try await loadString(cubeOBJ, name: "cube.obj")
        // Euler: V(8) - E + F(12) = 2  →  E = 18
        XCTAssertEqual(mesh.edges.count, 18,
                       "Triangulated unit cube: 18 unique edges")
    }

    func testCube_noBoundaryEdges() async throws {
        let mesh = try await loadString(cubeOBJ, name: "cube.obj")
        let boundary = mesh.edges.filter { $0.isBoundary }
        XCTAssertEqual(boundary.count, 0, "Closed cube has no boundary edges")
    }

    func testCube_meshNameFromFilename() async throws {
        let mesh = try await loadString(cubeOBJ, name: "my_mesh.obj")
        XCTAssertEqual(mesh.name, "my_mesh")
    }

    // MARK: - Single triangle

    func testTriangle_faceCount() async throws {
        let mesh = try await loadString(triangleOBJ, name: "tri.obj")
        XCTAssertEqual(mesh.faces.count, 1)
    }

    func testTriangle_edgeCount() async throws {
        let mesh = try await loadString(triangleOBJ, name: "tri.obj")
        XCTAssertEqual(mesh.edges.count, 3)
    }

    func testTriangle_allBoundaryEdges() async throws {
        let mesh = try await loadString(triangleOBJ, name: "tri.obj")
        XCTAssertTrue(mesh.edges.allSatisfy { $0.isBoundary },
                      "Isolated triangle: all 3 edges are boundary")
    }

    func testTriangle_vertexPositions() async throws {
        let mesh = try await loadString(triangleOBJ, name: "tri.obj")
        XCTAssertEqual(mesh.vertices[0].position.x, 0, accuracy: 1e-5)
        XCTAssertEqual(mesh.vertices[1].position.x, 1, accuracy: 1e-5)
        XCTAssertEqual(mesh.vertices[2].position.x, 0.5, accuracy: 1e-5)
    }

    // MARK: - Error cases

    func testUnsupportedExtension_throws() async {
        let url = URL(fileURLWithPath: "/tmp/test_mesh.xyz")
        do {
            _ = try await MeshLoaderFactory().load(from: url)
            XCTFail("Should throw unsupportedFormat")
        } catch MeshLoadError.unsupportedFormat {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testEmptyFile_throws() async throws {
        let url = try writeTemp("", name: "empty.obj")
        defer { try? FileManager.default.removeItem(at: url) }
        do {
            _ = try await ObjMeshLoader().load(from: url)
            XCTFail("Empty file should throw")
        } catch { /* expected */ }
    }

    func testNoFaces_throws() async throws {
        let content = "v 0 0 0\nv 1 0 0\nv 0 1 0\n"   // vertices but no 'f' lines
        let url = try writeTemp(content, name: "no_faces.obj")
        defer { try? FileManager.default.removeItem(at: url) }
        do {
            _ = try await ObjMeshLoader().load(from: url)
            XCTFail("File with no face lines should throw")
        } catch { /* expected */ }
    }

    func testMissingMTL_loadsGracefully() async throws {
        // OBJ that references a non-existent MTL file must load without throwing;
        // missing material is silently ignored, geometry is still valid.
        let content = """
            mtllib does_not_exist.mtl
            v 0 0 0
            v 1 0 0
            v 0.5 1 0
            f 1 2 3
            """
        let mesh = try await loadString(content, name: "no_mtl.obj")
        XCTAssertEqual(mesh.faces.count, 1, "Geometry must load even when MTL is missing")
        XCTAssertEqual(mesh.vertices.count, 3)
    }

    // MARK: - Comments and blank lines

    func testCommentLines_areIgnored() async throws {
        let content = """
            # This is a comment
            v 0 0 0
            # another comment
            v 1 0 0
            v 0.5 1 0
            f 1 2 3
            """
        let mesh = try await loadString(content, name: "comments.obj")
        XCTAssertEqual(mesh.vertices.count, 3)
        XCTAssertEqual(mesh.faces.count, 1)
    }

    // MARK: - Helpers

    private func loadString(_ s: String, name: String) async throws -> Mesh {
        let url = try writeTemp(s, name: name)
        defer { try? FileManager.default.removeItem(at: url) }
        return try await ObjMeshLoader().load(from: url)
    }

    private func writeTemp(_ content: String, name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
