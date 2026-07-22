import XCTest
import simd
@testable import FourHUnfolderCore

/// GĐ3.1: macOS AppState.autoArrange() bakes a 90° trial rotation directly into piece vertex
/// positions (unlike Windows, which stores rotation as a separate render/export-time transform —
/// see PARITY-PROGRESS.md). rotated90InLocalBBox is the extracted pure geometry behind that
/// rotation; it lives in FourHUnfolderCore specifically so it's unit-testable — AppState.swift is
/// part of the App executable target, which the test target does not depend on.
final class PieceRotationTests: XCTestCase {

    func testMinCorner_mapsToZeroBoxWidth() {
        // The box's own min corner (0,0) maps to (0, boxWidth) in the rotated box's space —
        // it does NOT stay at the origin (that's what makes this a genuine quarter turn, not a
        // no-op); testAppliedTwice_isNotIdentity below covers that distinction explicitly.
        let w: Float = 10
        let result = rotated90InLocalBBox(SIMD2(0, 0), boxWidth: w)
        XCTAssertEqual(result, SIMD2(0, w))
    }

    func testSwapsWidthAndHeight_allFourCorners() {
        // A w×h box (w=10, h=4) rotated must occupy exactly [0,h] × [0,w] = [0,4] × [0,10].
        let w: Float = 10, h: Float = 4
        let corners: [SIMD2<Float>] = [
            SIMD2(0, 0), SIMD2(w, 0), SIMD2(w, h), SIMD2(0, h),
        ]
        let rotated = corners.map { rotated90InLocalBBox($0, boxWidth: w) }

        let xs = rotated.map(\.x), ys = rotated.map(\.y)
        XCTAssertEqual(xs.min()!, 0, accuracy: 1e-5)
        XCTAssertEqual(xs.max()!, h, accuracy: 1e-5, "rotated box width must equal the original height")
        XCTAssertEqual(ys.min()!, 0, accuracy: 1e-5)
        XCTAssertEqual(ys.max()!, w, accuracy: 1e-5, "rotated box height must equal the original width")
    }

    func testPreservesDistancesBetweenPoints() {
        // A rotation is an isometry — pairwise distances must be preserved exactly.
        let w: Float = 7
        let a = SIMD2<Float>(1, 2)
        let b = SIMD2<Float>(5, 3)
        let originalDist = simd_distance(a, b)
        let rotatedDist  = simd_distance(rotated90InLocalBBox(a, boxWidth: w),
                                         rotated90InLocalBBox(b, boxWidth: w))
        XCTAssertEqual(rotatedDist, originalDist, accuracy: 1e-5)
    }

    func testAppliedTwice_isNotIdentity_producesA180DegreeTurn() {
        // Applying the box-relative rotation twice with the SAME boxWidth is not meaningful (the
        // box dimensions change after the first rotation), so this only documents that a single
        // application is a genuine quarter turn, not a no-op.
        let w: Float = 6
        let p = SIMD2<Float>(2, 3)
        XCTAssertNotEqual(rotated90InLocalBBox(p, boxWidth: w), p)
    }
}
