import XCTest
import simd
@testable import FourHUnfolderCore

/// GĐ3.3: port of Windows MainViewModel.AlignSelected / PatternCanvasControl.PieceAabb.
/// AppState.alignSelectedPieces (App executable target, not covered by this test target) is a
/// thin wrapper over PieceAligner — see PieceRotationTests.swift for the established precedent
/// of extracting AppState geometry into FourHUnfolderCore for testability.
final class PieceAlignerTests: XCTestCase {

    private func face(_ faceId: Int, _ v0: SIMD2<Float>, _ v1: SIMD2<Float>, _ v2: SIMD2<Float>) -> UnfoldedFace {
        UnfoldedFace(
            faceId: faceId, materialId: -1,
            v0: v0, v1: v1, v2: v2,
            edge0IsFold: true, edge1IsFold: true, edge2IsFold: true,
            edge0IsBoundary: false, edge1IsBoundary: false, edge2IsBoundary: false,
            uv0: nil, uv1: nil, uv2: nil,
            meshEdge0: -1, meshEdge1: -1, meshEdge2: -1
        )
    }

    /// Piece 0: bbox [0,10]×[0,10]. Piece 1: bbox [20,30]×[5,15].
    private func twoPieceResult() -> UnfoldResult {
        let p0 = face(0, SIMD2(0, 0), SIMD2(10, 0), SIMD2(0, 10))
        let p1 = face(1, SIMD2(20, 5), SIMD2(30, 5), SIMD2(20, 15))
        var r = UnfoldResult(faces: [p0, p1], tabs: [])
        r.pieces = [[0], [1]]
        return r
    }

    // MARK: - effectiveAABB

    func testEffectiveAABB_noRotationNoOffset_matchesRawBounds() {
        let box = PieceAligner.effectiveAABB(forPieceIdx: 0, result: twoPieceResult(),
                                              rotationDeg: 0, offset: .zero)
        XCTAssertEqual(box.min, SIMD2(0, 0))
        XCTAssertEqual(box.max, SIMD2(10, 10))
    }

    func test90DegreeRotation_swapsWidthAndHeight() {
        let wide = face(0, SIMD2(0, 0), SIMD2(20, 0), SIMD2(0, 4))
        var r = UnfoldResult(faces: [wide], tabs: [])
        r.pieces = [[0]]

        let flat = PieceAligner.effectiveAABB(forPieceIdx: 0, result: r, rotationDeg: 0, offset: .zero)
        let rot  = PieceAligner.effectiveAABB(forPieceIdx: 0, result: r, rotationDeg: 90, offset: .zero)

        let flatW = flat.max.x - flat.min.x, flatH = flat.max.y - flat.min.y
        let rotW  = rot.max.x  - rot.min.x,  rotH  = rot.max.y  - rot.min.y
        XCTAssertEqual(rotW, flatH, accuracy: 1e-4)
        XCTAssertEqual(rotH, flatW, accuracy: 1e-4)
    }

    func testOffset_translatesBoxByExactAmount() {
        let box = PieceAligner.effectiveAABB(forPieceIdx: 0, result: twoPieceResult(),
                                              rotationDeg: 0, offset: SIMD2(5, -3))
        XCTAssertEqual(box.min, SIMD2(5, -3))
        XCTAssertEqual(box.max, SIMD2(15, 7))
    }

    // MARK: - alignmentDeltas

    func testLeft_movesRightPieceToSharedMinX() {
        let d = PieceAligner.alignmentDeltas(result: twoPieceResult(), selected: [0, 1],
                                              pieceOffsets: [:], pieceRotations: [:], mode: .left)
        XCTAssertEqual(d[0]!.x, 0, accuracy: 1e-4)
        XCTAssertEqual(d[1]!.x, -20, accuracy: 1e-4)
    }

    func testRight_movesLeftPieceToSharedMaxX() {
        let d = PieceAligner.alignmentDeltas(result: twoPieceResult(), selected: [0, 1],
                                              pieceOffsets: [:], pieceRotations: [:], mode: .right)
        XCTAssertEqual(d[0]!.x, 20, accuracy: 1e-4)
        XCTAssertEqual(d[1]!.x, 0, accuracy: 1e-4)
    }

    func testCenterH_movesBothToSharedHorizontalCenter() {
        let d = PieceAligner.alignmentDeltas(result: twoPieceResult(), selected: [0, 1],
                                              pieceOffsets: [:], pieceRotations: [:], mode: .centerH)
        XCTAssertEqual(d[0]!.x, 10, accuracy: 1e-4)
        XCTAssertEqual(d[1]!.x, -10, accuracy: 1e-4)
    }

    func testTop_movesLowerPieceToSharedMinY() {
        let d = PieceAligner.alignmentDeltas(result: twoPieceResult(), selected: [0, 1],
                                              pieceOffsets: [:], pieceRotations: [:], mode: .top)
        XCTAssertEqual(d[0]!.y, 0, accuracy: 1e-4)
        XCTAssertEqual(d[1]!.y, -5, accuracy: 1e-4)
    }

    func testBottom_movesUpperPieceToSharedMaxY() {
        let d = PieceAligner.alignmentDeltas(result: twoPieceResult(), selected: [0, 1],
                                              pieceOffsets: [:], pieceRotations: [:], mode: .bottom)
        XCTAssertEqual(d[0]!.y, 5, accuracy: 1e-4)
        XCTAssertEqual(d[1]!.y, 0, accuracy: 1e-4)
    }

    func testCenterV_movesBothToSharedVerticalCenter() {
        let d = PieceAligner.alignmentDeltas(result: twoPieceResult(), selected: [0, 1],
                                              pieceOffsets: [:], pieceRotations: [:], mode: .centerV)
        XCTAssertEqual(d[0]!.y, 2.5, accuracy: 1e-4)
        XCTAssertEqual(d[1]!.y, -2.5, accuracy: 1e-4)
    }

    func testFewerThanTwoSelected_returnsEmptyDeltas() {
        let d = PieceAligner.alignmentDeltas(result: twoPieceResult(), selected: [0],
                                              pieceOffsets: [:], pieceRotations: [:], mode: .left)
        XCTAssertTrue(d.isEmpty)
    }

    func testOutOfRangeIndex_filteredOut_leavesFewerThanTwo_returnsEmpty() {
        let d = PieceAligner.alignmentDeltas(result: twoPieceResult(), selected: [0, 99],
                                              pieceOffsets: [:], pieceRotations: [:], mode: .left)
        XCTAssertTrue(d.isEmpty)
    }

    func testPreExistingOffset_isIncludedInAlignmentReferenceComputation() {
        // Piece 0 pre-shifted to x=[100,110]; new shared-left reference becomes min(100, 20)=20.
        let d = PieceAligner.alignmentDeltas(result: twoPieceResult(), selected: [0, 1],
                                              pieceOffsets: [0: SIMD2<Float>(100, 0)],
                                              pieceRotations: [:], mode: .left)
        XCTAssertEqual(d[0]!.x, -80, accuracy: 1e-4)
        XCTAssertEqual(d[1]!.x, 0, accuracy: 1e-4)
    }
}
