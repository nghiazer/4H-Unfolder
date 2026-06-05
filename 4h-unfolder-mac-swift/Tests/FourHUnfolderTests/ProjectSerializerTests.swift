import XCTest
import simd
@testable import FourHUnfolderCore

final class ProjectSerializerTests: XCTestCase {

    private let serializer = ProjectSerializer()
    private let tmp = FileManager.default.temporaryDirectory

    // MARK: - Round-trip: state.json fields survive save + load

    func testRoundTrip_edgeAndFlapOverrides() throws {
        let objURL = tmp.appendingPathComponent("ps_test_cube.obj")
        try minimalOBJ().write(to: objURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: objURL) }

        let edgeOverrides: [Int: EdgeType]     = [0: .cut, 1: .fold]
        let flapOverrides: [Int: FlapOverride] = [2: FlapOverride(mode: .offOff_NoFlap)]
        var settings = AppSettings()
        settings.print.glueTabDepthMm    = 7.5
        settings.print.alternateFlaps    = true
        settings.print.includeGlueTabs   = false

        let bundleURL = tmp.appendingPathComponent("ps_test.4hu")
        defer { try? FileManager.default.removeItem(at: bundleURL) }

        try serializer.save(
            meshURL: objURL,
            edgeOverrides: edgeOverrides,
            flapOverrides: flapOverrides,
            settings: settings,
            to: bundleURL
        )

        let (loaded, meshURL, tempDir) = try serializer.load(from: bundleURL)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        XCTAssertEqual(loaded.edgeOverrides, edgeOverrides,
                       "edgeOverrides must survive round-trip")
        XCTAssertEqual(loaded.flapOverrides, flapOverrides,
                       "flapOverrides must survive round-trip")
        XCTAssertEqual(loaded.settings.print.glueTabDepthMm, 7.5, accuracy: 0.001,
                       "glueTabDepthMm must survive round-trip")
        XCTAssertTrue(loaded.settings.print.alternateFlaps,
                      "alternateFlaps must survive round-trip")
        XCTAssertFalse(loaded.settings.print.includeGlueTabs,
                       "includeGlueTabs must survive round-trip")
        XCTAssertTrue(FileManager.default.fileExists(atPath: meshURL.path),
                      "Mesh file must exist in extracted temp dir")
    }

    func testRoundTrip_pieceOffsets() throws {
        let objURL = tmp.appendingPathComponent("ps_test_offsets.obj")
        try minimalOBJ().write(to: objURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: objURL) }

        let pieceOffsets: [Int: SIMD2<Float>] = [
            0: SIMD2(10.5, -3.25),
            1: SIMD2(0, 0),
            3: SIMD2(-100, 200),
        ]

        let bundleURL = tmp.appendingPathComponent("ps_test_offsets.4hu")
        defer { try? FileManager.default.removeItem(at: bundleURL) }

        try serializer.save(
            meshURL: objURL,
            edgeOverrides: [:],
            flapOverrides: [:],
            settings: AppSettings(),
            pieceOffsets: pieceOffsets,
            to: bundleURL
        )

        let (loaded, _, tempDir) = try serializer.load(from: bundleURL)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Decode pieceOffsets back
        let restored = loaded.pieceOffsets.reduce(into: [Int: SIMD2<Float>]()) { d, kv in
            guard let pi = Int(kv.key), kv.value.count >= 2 else { return }
            d[pi] = SIMD2<Float>(kv.value[0], kv.value[1])
        }

        XCTAssertEqual(restored.count, pieceOffsets.count)
        for (pi, expected) in pieceOffsets {
            let got = try XCTUnwrap(restored[pi], "pieceOffset[\(pi)] must survive round-trip")
            XCTAssertEqual(got.x, expected.x, accuracy: 0.001)
            XCTAssertEqual(got.y, expected.y, accuracy: 0.001)
        }
    }

    // MARK: - Error cases

    func testLoad_missingStateJson_throws() throws {
        // Create a ZIP that contains no state.json
        let empty = tmp.appendingPathComponent("ps_empty")
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: empty) }

        let placeholder = empty.appendingPathComponent("dummy.txt")
        try "dummy".write(to: placeholder, atomically: true, encoding: .utf8)

        let bundleURL = tmp.appendingPathComponent("ps_bad.4hu")
        defer { try? FileManager.default.removeItem(at: bundleURL) }

        let zip = Process()
        zip.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        zip.currentDirectoryURL = empty
        zip.arguments = ["-r", bundleURL.path, "."]
        zip.standardOutput = FileHandle.nullDevice
        zip.standardError = FileHandle.nullDevice
        try zip.run(); zip.waitUntilExit()

        XCTAssertThrowsError(try serializer.load(from: bundleURL)) { error in
            let desc = (error as? LocalizedError)?.errorDescription ?? ""
            XCTAssertTrue(desc.contains("state.json"), "Error must mention state.json")
        }
    }

    // MARK: - Helpers

    private func minimalOBJ() -> String {
        """
        v 0 0 0
        v 1 0 0
        v 1 1 0
        v 0 1 0
        f 1 2 3
        f 1 3 4
        """
    }
}
