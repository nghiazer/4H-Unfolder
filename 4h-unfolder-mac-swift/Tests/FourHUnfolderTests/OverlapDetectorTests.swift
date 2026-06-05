import XCTest
import simd
@testable import FourHUnfolderCore

final class OverlapDetectorTests: XCTestCase {

    // MARK: - Helpers

    private func tri(
        _ a: SIMD2<Float>, _ b: SIMD2<Float>, _ c: SIMD2<Float>,
        faceId: Int = 0
    ) -> UnfoldedFace {
        UnfoldedFace(
            faceId: faceId, materialId: -1,
            v0: a, v1: b, v2: c,
            edge0IsFold: false, edge1IsFold: false, edge2IsFold: false,
            edge0IsBoundary: true, edge1IsBoundary: true, edge2IsBoundary: true,
            uv0: nil, uv1: nil, uv2: nil,
            meshEdge0: -1, meshEdge1: -1, meshEdge2: -1
        )
    }

    // MARK: - Basic cases

    func testEmpty_noOverlap() {
        XCTAssertFalse(OverlapDetector().hasOverlaps(faces: []))
    }

    func testSingleFace_noOverlap() {
        let f = tri(.zero, SIMD2(1, 0), SIMD2(0.5, 1))
        XCTAssertFalse(OverlapDetector().hasOverlaps(faces: [f]))
    }

    func testSeparateFaces_noOverlap() {
        let f1 = tri(SIMD2(0,  0), SIMD2(1,  0), SIMD2(0.5,  1), faceId: 0)
        let f2 = tri(SIMD2(5,  0), SIMD2(6,  0), SIMD2(5.5,  1), faceId: 1)
        XCTAssertFalse(OverlapDetector().hasOverlaps(faces: [f1, f2]),
                       "Spatially separate triangles must not be detected as overlapping")
    }

    func testOverlappingFaces_detectedAsOverlap() {
        let f1 = tri(SIMD2(0,   0), SIMD2(2,   0), SIMD2(1,   2), faceId: 0)
        let f2 = tri(SIMD2(0.5, 0.5), SIMD2(2.5, 0.5), SIMD2(1.5, 2.5), faceId: 1)
        XCTAssertTrue(OverlapDetector().hasOverlaps(faces: [f1, f2]),
                      "Overlapping triangles must be detected")
    }

    func testSharedEdge_noFalsePositive() {
        // Two triangles touching along their shared edge (fold-adjacent pair).
        // The SAT epsilon for shared edges must prevent false overlap.
        let f1 = tri(SIMD2(0, 0), SIMD2(1, 0), SIMD2(0.5,  1), faceId: 0)
        let f2 = tri(SIMD2(0, 0), SIMD2(1, 0), SIMD2(0.5, -1), faceId: 1)
        XCTAssertFalse(OverlapDetector().hasOverlaps(faces: [f1, f2]),
                       "Fold-adjacent triangles share an edge but must NOT be counted as overlapping")
    }

    func testSharedVertex_noFalsePositive() {
        // Triangles touching only at a single vertex
        let f1 = tri(SIMD2(0, 0), SIMD2(1, 0), SIMD2(0.5, 1), faceId: 0)
        let f2 = tri(SIMD2(1, 0), SIMD2(2, 0), SIMD2(1.5, 1), faceId: 1)
        XCTAssertFalse(OverlapDetector().hasOverlaps(faces: [f1, f2]))
    }

    // MARK: - Full pipeline

    func testTetrahedronUnfold_noOverlap() {
        let faces = TestMesh.runUnfold(TestMesh.tetrahedron())
        XCTAssertFalse(OverlapDetector().hasOverlaps(faces: faces),
                       "MST unfold of a tetrahedron should be overlap-free")
    }

    func testCubeUnfold_noOverlap() {
        let faces = TestMesh.runUnfold(TestMesh.cube())
        XCTAssertFalse(OverlapDetector().hasOverlaps(faces: faces),
                       "MST unfold of a cube should be overlap-free")
    }

    // MARK: - Many faces

    func testManyNonOverlappingFaces_noneDetected() {
        // Grid of 5×5 = 25 small non-overlapping triangles spaced 2 units apart
        var faces: [UnfoldedFace] = []
        for row in 0..<5 {
            for col in 0..<5 {
                let ox = Float(col) * 2
                let oy = Float(row) * 2
                faces.append(tri(SIMD2(ox, oy), SIMD2(ox + 1, oy), SIMD2(ox + 0.5, oy + 1),
                                 faceId: row * 5 + col))
            }
        }
        XCTAssertFalse(OverlapDetector().hasOverlaps(faces: faces))
    }
}
