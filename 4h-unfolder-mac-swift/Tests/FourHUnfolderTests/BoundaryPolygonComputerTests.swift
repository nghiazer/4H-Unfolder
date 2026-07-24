import XCTest
import simd
@testable import FourHUnfolderCore

/// Backlog Phase 1: port of Windows BoundaryPolygonComputer.Compute/ChainEdges. See
/// BoundaryPolygonComputer.swift.
final class BoundaryPolygonComputerTests: XCTestCase {

    /// A 2×2 square split by the (0,0)-(2,2) diagonal into two triangles. The diagonal is a fold
    /// edge (meshId 100, shared by both faces); the four outer sides are non-fold (cut) edges.
    private func squareResult() -> [UnfoldedFace] {
        let a = UnfoldedFace(
            faceId: 0, materialId: -1,
            v0: SIMD2(0, 0), v1: SIMD2(2, 0), v2: SIMD2(2, 2),
            edge0IsFold: false, edge1IsFold: false, edge2IsFold: true,
            edge0IsBoundary: true, edge1IsBoundary: true, edge2IsBoundary: false,
            uv0: nil, uv1: nil, uv2: nil,
            meshEdge0: 1, meshEdge1: 2, meshEdge2: 100
        )
        let b = UnfoldedFace(
            faceId: 1, materialId: -1,
            v0: SIMD2(0, 0), v1: SIMD2(2, 2), v2: SIMD2(0, 2),
            edge0IsFold: true, edge1IsFold: false, edge2IsFold: false,
            edge0IsBoundary: false, edge1IsBoundary: true, edge2IsBoundary: true,
            uv0: nil, uv1: nil, uv2: nil,
            meshEdge0: 100, meshEdge1: 3, meshEdge2: 4
        )
        return [a, b]
    }

    func testTwoTriangleSquare_chainsIntoFourCornerBoundary_noDuplicateClosingPoint() {
        let boundary = BoundaryPolygonComputer.compute(faces: squareResult())
        XCTAssertNotNil(boundary)
        guard let boundary else { return }

        // Fold edge (the diagonal) must be excluded — only the 4 outer corners remain, and the
        // chain-closing duplicate of the first point must be trimmed (see BoundaryPolygonComputer's
        // note on why PolygonOffset.inflate needs a clean, non-duplicated closed loop).
        XCTAssertEqual(boundary.count, 4)
        let expected: Set<SIMD2<Float>> = [SIMD2(0, 0), SIMD2(2, 0), SIMD2(2, 2), SIMD2(0, 2)]
        XCTAssertEqual(Set(boundary), expected)

        // Adjacent chain entries must actually be adjacent square corners (chain didn't skip/shuffle).
        for i in 0..<boundary.count {
            let a = boundary[i], b = boundary[(i + 1) % boundary.count]
            let d = simd_length(a - b)
            XCTAssertEqual(d, 2, accuracy: 0.001, "edge \(a)->\(b) should be a unit square side of length 2")
        }
    }

    func testSingleTriangleAllCutEdges_returnsTriangleWithoutDuplicateClosingPoint() {
        let tri = UnfoldedFace(
            faceId: 0, materialId: -1,
            v0: SIMD2(0, 0), v1: SIMD2(4, 0), v2: SIMD2(0, 3),
            edge0IsFold: false, edge1IsFold: false, edge2IsFold: false,
            edge0IsBoundary: true, edge1IsBoundary: true, edge2IsBoundary: true,
            uv0: nil, uv1: nil, uv2: nil,
            meshEdge0: 10, meshEdge1: 11, meshEdge2: 12
        )
        let boundary = BoundaryPolygonComputer.compute(faces: [tri])
        XCTAssertNotNil(boundary)
        XCTAssertEqual(boundary?.count, 3)
        XCTAssertEqual(Set(boundary ?? []), Set([SIMD2<Float>(0, 0), SIMD2(4, 0), SIMD2(0, 3)]))
    }

    func testAllFoldEdges_returnsNil() {
        let tri = UnfoldedFace(
            faceId: 0, materialId: -1,
            v0: SIMD2(0, 0), v1: SIMD2(1, 0), v2: SIMD2(0, 1),
            edge0IsFold: true, edge1IsFold: true, edge2IsFold: true,
            edge0IsBoundary: false, edge1IsBoundary: false, edge2IsBoundary: false,
            uv0: nil, uv1: nil, uv2: nil,
            meshEdge0: 1, meshEdge1: 2, meshEdge2: 3
        )
        XCTAssertNil(BoundaryPolygonComputer.compute(faces: [tri]))
    }

    func testEmptyFaces_returnsNil() {
        XCTAssertNil(BoundaryPolygonComputer.compute(faces: []))
    }

    func testVertsForClosure_isAppliedToOutput() {
        // vertsFor lets canvas trace the boundary in a piece's live rotated/offset position rather
        // than its raw baked (export) position — confirm the closure's output is actually used,
        // not just the raw v0/v1/v2.
        let offset = SIMD2<Float>(100, 100)
        let boundary = BoundaryPolygonComputer.compute(
            faces: squareResult(),
            vertsFor: { ($0.v0 + offset, $0.v1 + offset, $0.v2 + offset) }
        )
        XCTAssertNotNil(boundary)
        let expected: Set<SIMD2<Float>> = [SIMD2(100, 100), SIMD2(102, 100), SIMD2(102, 102), SIMD2(100, 102)]
        XCTAssertEqual(Set(boundary ?? []), expected)
    }
}
