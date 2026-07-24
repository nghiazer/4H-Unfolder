import XCTest
import simd
@testable import FourHUnfolderCore

/// GĐ3.3: port of Windows MainViewModel.FindAdjacentCutEdgeGroup — BFS over cut edges connected
/// via shared 2D paper-space vertices. See EdgeGroupFinder.swift.
final class EdgeGroupFinderTests: XCTestCase {

    private func makeFace(faceId: Int, v0: SIMD2<Float>, v1: SIMD2<Float>, v2: SIMD2<Float>,
                           cutEdge0: Int?) -> UnfoldedFace {
        UnfoldedFace(
            faceId: faceId, materialId: -1,
            v0: v0, v1: v1, v2: v2,
            edge0IsFold: cutEdge0 == nil, edge1IsFold: true, edge2IsFold: true,
            edge0IsBoundary: false, edge1IsBoundary: false, edge2IsBoundary: false,
            uv0: nil, uv1: nil, uv2: nil,
            meshEdge0: cutEdge0 ?? -1, meshEdge1: -1, meshEdge2: -1
        )
    }

    /// Three triangles whose edge-0 cut edges (100, 101, 102) share vertices in a chain
    /// (100↔101 at (1,0), 101↔102 at (2,0)), plus one far-away isolated cut edge (200).
    private func chainResult() -> UnfoldResult {
        let a = makeFace(faceId: 0, v0: SIMD2(0, 0), v1: SIMD2(1, 0), v2: SIMD2(0, 1), cutEdge0: 100)
        let b = makeFace(faceId: 1, v0: SIMD2(1, 0), v1: SIMD2(2, 0), v2: SIMD2(1, 1), cutEdge0: 101)
        let c = makeFace(faceId: 2, v0: SIMD2(2, 0), v1: SIMD2(3, 0), v2: SIMD2(2, 1), cutEdge0: 102)
        let d = makeFace(faceId: 3, v0: SIMD2(100, 100), v1: SIMD2(101, 100), v2: SIMD2(100, 101), cutEdge0: 200)
        return UnfoldResult(faces: [a, b, c, d], tabs: [])
    }

    func testStartFromChainEnd_findsWholeChain() {
        let group = EdgeGroupFinder.findAdjacentCutEdgeGroup(startEdgeId: 100, result: chainResult())
        XCTAssertEqual(group, Set([100, 101, 102]))
    }

    func testStartFromChainMiddle_findsWholeChain() {
        // BFS must expand in both directions from any starting point in the chain.
        let group = EdgeGroupFinder.findAdjacentCutEdgeGroup(startEdgeId: 101, result: chainResult())
        XCTAssertEqual(group, Set([100, 101, 102]))
    }

    func testIsolatedCutEdge_returnsOnlyItself() {
        let group = EdgeGroupFinder.findAdjacentCutEdgeGroup(startEdgeId: 200, result: chainResult())
        XCTAssertEqual(group, Set([200]))
    }

    func testUnknownEdgeId_returnsEmpty() {
        let group = EdgeGroupFinder.findAdjacentCutEdgeGroup(startEdgeId: 999, result: chainResult())
        XCTAssertTrue(group.isEmpty)
    }

    func testFoldEdge_isNotInCutVertsMap_returnsEmpty() {
        // meshEdgeId 100 is assigned to edge0, but edge0 is marked FOLD (not cut) — it must not
        // be treated as a joinable cut edge even though its meshEdgeId matches a real cut elsewhere.
        let foldedFace = UnfoldedFace(
            faceId: 0, materialId: -1,
            v0: SIMD2(0, 0), v1: SIMD2(1, 0), v2: SIMD2(0, 1),
            edge0IsFold: true, edge1IsFold: true, edge2IsFold: true,
            edge0IsBoundary: false, edge1IsBoundary: false, edge2IsBoundary: false,
            uv0: nil, uv1: nil, uv2: nil,
            meshEdge0: 100, meshEdge1: -1, meshEdge2: -1
        )
        let result = UnfoldResult(faces: [foldedFace], tabs: [])
        let group = EdgeGroupFinder.findAdjacentCutEdgeGroup(startEdgeId: 100, result: result)
        XCTAssertTrue(group.isEmpty)
    }
}
