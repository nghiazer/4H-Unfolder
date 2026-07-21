import XCTest
import simd
@testable import FourHUnfolderCore

final class FlapMergerTests: XCTestCase {

    // MARK: - Helpers

    private func area(_ poly: [SIMD2<Float>]) -> Float {
        abs(ConvexPolygonUnion.signedArea(poly))
    }

    private func square(_ ox: Float, _ oy: Float, _ s: Float) -> [SIMD2<Float>] {
        [SIMD2(ox, oy), SIMD2(ox + s, oy), SIMD2(ox + s, oy + s), SIMD2(ox, oy + s)]
    }

    private func quadTab(faceId: Int, _ p: [SIMD2<Float>]) -> GlueTab {
        GlueTab(faceId: faceId, localEdgeIdx: 0,
                p0: p[0], p1: p[1], p2: p[2], p3: p[3], borderFoldStyle: nil)
    }

    private func cutFace(faceId: Int) -> UnfoldedFace {
        UnfoldedFace(
            faceId: faceId, materialId: -1,
            v0: .zero, v1: SIMD2(10, 0), v2: SIMD2(5, 8),
            edge0IsFold: false, edge1IsFold: false, edge2IsFold: false,
            edge0IsBoundary: false, edge1IsBoundary: false, edge2IsBoundary: false,
            uv0: nil, uv1: nil, uv2: nil,
            meshEdge0: -1, meshEdge1: -1, meshEdge2: -1)
    }

    // MARK: - ConvexPolygonUnion

    func testUnionOfOverlappingSquaresIsLShape() {
        // A=[0,2]², B=[1,3]² overlap in [1,2]². Union area = 4 + 4 - 1 = 7.
        let u = ConvexPolygonUnion.union(square(0, 0, 2), square(1, 1, 2))
        XCTAssertNotNil(u)
        XCTAssertEqual(area(u!), 7, accuracy: 0.05)
    }

    func testUnionOfDisjointSquaresIsNil() {
        XCTAssertNil(ConvexPolygonUnion.union(square(0, 0, 2), square(5, 5, 2)))
    }

    func testUnionOfCornerTouchingSquaresIsNil() {
        // Share only the corner (2,2) → no positive-area overlap.
        XCTAssertNil(ConvexPolygonUnion.union(square(0, 0, 2), square(2, 2, 2)))
    }

    func testUnionWithContainmentReturnsOuter() {
        let outer = square(0, 0, 10)
        let u = ConvexPolygonUnion.union(outer, square(2, 2, 3))
        XCTAssertNotNil(u)
        XCTAssertEqual(area(u!), 100, accuracy: 0.05)
    }

    // MARK: - PolygonOffset

    func testInflateGrowsAreaAndBounds() {
        let sq = square(0, 0, 4)          // area 16
        let inflated = PolygonOffset.inflate(sq, paddingMm: 1.0)
        XCTAssertNotNil(inflated)
        // area ≈ 16 + perimeter·r + π·r² = 16 + 16 + π ≈ 35.14
        XCTAssertEqual(area(inflated!), 35.14, accuracy: 0.6)
        // Left edge should be offset outward to x ≈ -1.
        let minX = inflated!.map(\.x).min()!
        XCTAssertEqual(minX, -1, accuracy: 0.05)
    }

    func testInflateRejectsDegenerate() {
        XCTAssertNil(PolygonOffset.inflate(square(0, 0, 4), paddingMm: 0))
        XCTAssertNil(PolygonOffset.inflate([SIMD2(0, 0), SIMD2(1, 1)], paddingMm: 1))
    }

    // MARK: - FlapMerger

    func testAdjacentOverlappingTabsMerge() {
        let faces = [cutFace(faceId: 0)]
        let tabA = quadTab(faceId: 0, [SIMD2(0, 0), SIMD2(4, 0), SIMD2(4, -2), SIMD2(0, -2)])
        let tabB = quadTab(faceId: 0, [SIMD2(0, 0), SIMD2(0, -4), SIMD2(2, -4), SIMD2(2, 0)])

        let merged = FlapMerger.merge(faces: faces, tabs: [tabA, tabB])

        XCTAssertEqual(merged.count, 1, "two adjacent overlapping tabs collapse into one")
        XCTAssertNotNil(merged[0].mergedPolygon)
    }

    func testNonAdjacentTabsAreUnchanged() {
        let faces = [cutFace(faceId: 0)]
        let tabA = quadTab(faceId: 0, [SIMD2(0, 0), SIMD2(4, 0), SIMD2(4, -2), SIMD2(0, -2)])
        let tabB = quadTab(faceId: 0, [SIMD2(20, 20), SIMD2(24, 20), SIMD2(24, 18), SIMD2(20, 18)])

        let merged = FlapMerger.merge(faces: faces, tabs: [tabA, tabB])

        XCTAssertEqual(merged.count, 2)
        XCTAssertTrue(merged.allSatisfy { $0.mergedPolygon == nil })
    }

    func testSingleTabReturnedUnchanged() {
        let tabA = quadTab(faceId: 0, [SIMD2(0, 0), SIMD2(4, 0), SIMD2(4, -2), SIMD2(0, -2)])
        XCTAssertEqual(FlapMerger.merge(faces: [cutFace(faceId: 0)], tabs: [tabA]).count, 1)
    }
}
