import XCTest
@testable import FourHUnfolderCore

/// GĐ3.2: when the default MST (natural Kruskal tie-break) produces overlaps, UnfoldService.unfold
/// retries with alternate tie-break seeds and keeps whichever has the fewest overlapping face
/// pairs. These tests cover the two safety properties that matter regardless of any specific
/// mesh's overlap outcome — the actual "does retrying ever change the picked MST" behaviour is
/// covered separately at the KruskalMSTBuilder level (KruskalMSTTests.testTieBreakSeed_*), since
/// constructing a real mesh where a specific tie-break provably reduces overlap is not easily
/// deterministic.
final class UnfoldServiceMultiSeedTests: XCTestCase {

    private var defaultSettings: AppSettings.PrintSettings { AppSettings.PrintSettings() }

    func testUnfold_noOverlaps_returnsValidResult() async {
        let mesh = TestMesh.tetrahedron()
        let result = await UnfoldService().unfold(
            mesh: mesh, edgeOverrides: [:], flapOverrides: [:], settings: defaultSettings)

        XCTAssertFalse(result.hasOverlaps, "a tetrahedron's net never self-overlaps")
        XCTAssertEqual(result.faces.count, 4)
    }

    func testUnfold_seedCountZero_disablesRetry_stillReturnsValidResult() async {
        let mesh = TestMesh.tetrahedron()
        let result = await UnfoldService().unfold(
            mesh: mesh, edgeOverrides: [:], flapOverrides: [:], settings: defaultSettings,
            seedCount: 0)

        XCTAssertEqual(result.faces.count, 4)
    }

    func testUnfold_meshEdgeTypes_areConsistentWithReturnedFoldFlags() async {
        // The core safety property: EdgeMarker.mark mutates mesh.edges[].type as a side effect on
        // every retry attempt. After unfold() returns, the mesh MUST be re-stamped with the
        // WINNING candidate's fold set — not whichever seed happened to run last in the retry
        // loop — because PieceComputer and canvas hit-testing read mesh.edges[id].type directly,
        // independent of the returned UnfoldResult.
        let mesh = TestMesh.tetrahedron()
        let result = await UnfoldService().unfold(
            mesh: mesh, edgeOverrides: [:], flapOverrides: [:], settings: defaultSettings)

        for face in result.faces {
            for i in 0..<3 {
                let meshEdgeId = face.meshEdgeId(i)
                guard meshEdgeId >= 0 else { continue }

                let meshSaysFold = mesh.edges[meshEdgeId].type == .fold
                XCTAssertEqual(face.edgeIsFold(i), meshSaysFold,
                    "face \(face.faceId) edge \(i) (meshEdgeId \(meshEdgeId)): the returned " +
                    "UnfoldResult and the mesh's persistent edge-type state must agree")
            }
        }
    }

    func testUnfold_repeatedCalls_areDeterministic() async {
        let mesh1 = TestMesh.tetrahedron()
        let mesh2 = TestMesh.tetrahedron()

        let r1 = await UnfoldService().unfold(
            mesh: mesh1, edgeOverrides: [:], flapOverrides: [:], settings: defaultSettings)
        let r2 = await UnfoldService().unfold(
            mesh: mesh2, edgeOverrides: [:], flapOverrides: [:], settings: defaultSettings)

        func signature(_ r: UnfoldResult) -> String {
            r.faces.map { "\($0.faceId):\($0.edge0IsFold),\($0.edge1IsFold),\($0.edge2IsFold)" }
                .joined(separator: "|")
        }

        XCTAssertEqual(signature(r1), signature(r2))
    }
}
