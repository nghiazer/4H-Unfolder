import XCTest
import simd
@testable import FourHUnfolderCore

final class GlueTabGeneratorTests: XCTestCase {

    // MARK: - Helpers

    private var defaultSettings: AppSettings.PrintSettings { AppSettings.PrintSettings() }

    /// A single face where only edge 0 (v0→v1) is a cut edge (others are boundary).
    private func singleCutFace(
        v0: SIMD2<Float> = .zero,
        v1: SIMD2<Float> = SIMD2(10, 0),
        v2: SIMD2<Float> = SIMD2(5, 8)
    ) -> UnfoldedFace {
        UnfoldedFace(
            faceId: 0, materialId: -1,
            v0: v0, v1: v1, v2: v2,
            edge0IsFold: false, edge1IsFold: false, edge2IsFold: false,
            edge0IsBoundary: false, edge1IsBoundary: true, edge2IsBoundary: true,
            uv0: nil, uv1: nil, uv2: nil,
            meshEdge0: -1, meshEdge1: -1, meshEdge2: -1
        )
    }

    private func generate(
        _ face: UnfoldedFace,
        settings: AppSettings.PrintSettings? = nil
    ) -> [GlueTab] {
        var s = settings ?? defaultSettings
        s.alternateFlaps = false
        return GlueTabGenerator().generate(
            faces: [face], mesh: Mesh(), settings: s, flapOverrides: [:]
        )
    }

    // MARK: - Trapezoid shape

    func testTrapezoid_polygonHasFourVertices() {
        var s = defaultSettings
        s.glueTabShape = .trapezoid
        let tabs = generate(singleCutFace(), settings: s)
        XCTAssertEqual(tabs.count, 1, "One cut edge → one tab")
        XCTAssertEqual(tabs[0].polygon.count, 4, "Trapezoid tab has 4 vertices")
    }

    func testTrapezoid_insetCappedAt45Percent() {
        // Edge length = 10mm, depth = 50mm, angle = 45° → raw inset = depth/tan(45°) = 50mm
        // Capped at edgeLen × 0.45 = 4.5mm → p3.x ≈ 4.5, p2.x ≈ 5.5
        var s = defaultSettings
        s.glueTabShape = .trapezoid
        s.glueTabDepthMm = 50   // trigger inset cap
        s.glueTabSideAngleDeg = 45
        let tab = generate(singleCutFace(), settings: s)[0]

        // p0=(0,0), p1=(10,0); perp points toward centroid (+Y)
        XCTAssertEqual(tab.p3.x, 4.5, accuracy: 0.01,
                       "Inset capped at 45% of edge length = 4.5mm")
        XCTAssertEqual(tab.p2.x, 5.5, accuracy: 0.01,
                       "Inset from right: 10 - 4.5 = 5.5mm")
    }

    func testTrapezoid_normalDepth_noInsetCap() {
        // depth = 3mm, angle = 45° → inset = 3mm; cap = edgeLen(10) × 0.45 = 4.5mm → not capped
        var s = defaultSettings
        s.glueTabShape = .trapezoid
        s.glueTabDepthMm = 3
        s.glueTabSideAngleDeg = 45
        let tab = generate(singleCutFace(), settings: s)[0]

        XCTAssertEqual(tab.p3.x, 3.0, accuracy: 0.01,
                       "Inset = depth/tan(45°) = 3mm (not capped, cap=4.5)")
        XCTAssertEqual(tab.p2.x, 7.0, accuracy: 0.01, "10 - 3 = 7mm from right side")
    }

    func testTrapezoid_innerEdgeAboveBaseline() {
        var s = defaultSettings; s.glueTabShape = .trapezoid; s.glueTabDepthMm = 5
        let tab = generate(singleCutFace(), settings: s)[0]
        XCTAssertGreaterThan(tab.p2.y, tab.p1.y, "Inner edge of tab is above the base edge")
        XCTAssertGreaterThan(tab.p3.y, tab.p0.y)
    }

    // MARK: - Rectangle shape

    func testRectangle_parallelEdges() {
        var s = defaultSettings; s.glueTabShape = .rectangle; s.glueTabDepthMm = 5
        let tab = generate(singleCutFace(), settings: s)[0]
        XCTAssertEqual(tab.p3.x, tab.p0.x, accuracy: 0.001, "p3 is directly above p0")
        XCTAssertEqual(tab.p2.x, tab.p1.x, accuracy: 0.001, "p2 is directly above p1")
    }

    func testRectangle_depthMatchesSettings() {
        var s = defaultSettings; s.glueTabShape = .rectangle; s.glueTabDepthMm = 7
        let tab = generate(singleCutFace(v0: .zero, v1: SIMD2(10, 0), v2: SIMD2(5, 20)), settings: s)[0]
        let depth = simd_length(tab.p3 - tab.p0)
        XCTAssertEqual(depth, 7.0, accuracy: 0.01)
    }

    // MARK: - Triangle shape

    func testTriangle_tipIsMidpoint() {
        var s = defaultSettings; s.glueTabShape = .triangle; s.glueTabDepthMm = 5
        let tab = generate(singleCutFace(), settings: s)[0]
        XCTAssertEqual(tab.p2, tab.p3, "Triangle: p2 == p3 (same tip)")
        let mid = (tab.p0 + tab.p1) / 2
        XCTAssertEqual(tab.p2.x, mid.x, accuracy: 0.01, "Tip x == midpoint x")
    }

    // MARK: - Skip conditions

    func testFoldEdge_noTab() {
        let face = UnfoldedFace(
            faceId: 0, materialId: -1,
            v0: .zero, v1: SIMD2(10, 0), v2: SIMD2(5, 8),
            edge0IsFold: true, edge1IsFold: false, edge2IsFold: false,
            edge0IsBoundary: false, edge1IsBoundary: true, edge2IsBoundary: true,
            uv0: nil, uv1: nil, uv2: nil,
            meshEdge0: -1, meshEdge1: -1, meshEdge2: -1
        )
        XCTAssertTrue(generate(face).isEmpty, "Fold edge must not produce a tab")
    }

    func testBoundaryEdge_noTab_byDefault() {
        // Default mode = .default → boundary edges are skipped
        let face = UnfoldedFace(
            faceId: 0, materialId: -1,
            v0: .zero, v1: SIMD2(10, 0), v2: SIMD2(5, 8),
            edge0IsFold: false, edge1IsFold: false, edge2IsFold: false,
            edge0IsBoundary: true, edge1IsBoundary: true, edge2IsBoundary: true,
            uv0: nil, uv1: nil, uv2: nil,
            meshEdge0: -1, meshEdge1: -1, meshEdge2: -1
        )
        XCTAssertTrue(generate(face).isEmpty, "Boundary edges skip tabs in default mode")
    }

    func testDegenerateEdge_noTab() {
        // Edge length ≈ 0 → below degenerateTab threshold → tab skipped
        let face = singleCutFace(v0: .zero, v1: SIMD2(1e-6, 0), v2: SIMD2(5, 8))
        XCTAssertTrue(generate(face).isEmpty, "Degenerate edge (< 1e-4mm) must be skipped")
    }

    // MARK: - FlapMode.offOff_NoFlap

    func testOffOffNoFlap_noTab() {
        // Two faces sharing one edge. MST folds that edge → no tab in default mode either.
        // Adding .offOff_NoFlap override confirms no tab is produced for that edge.
        let mesh = TestMesh.twoFacesSharedEdge()
        let faces = TestMesh.runUnfold(mesh)
        guard let sharedEdge = mesh.edges.first(where: { $0.connectsFaces }) else {
            XCTFail("twoFacesSharedEdge must have a shared interior edge"); return
        }
        let override = [sharedEdge.id: FlapOverride(mode: .offOff_NoFlap)]
        var s = defaultSettings; s.alternateFlaps = false

        let tabs = GlueTabGenerator().generate(
            faces: faces, mesh: mesh, settings: s, flapOverrides: override
        )
        // Shared edge is fold (from MST) + all boundaries → no tabs from default mode.
        // .offOff_NoFlap on fold edge also returns nil, so result should be empty.
        XCTAssertTrue(tabs.isEmpty, ".offOff_NoFlap on a fold edge must produce no tabs")
    }

    // MARK: - AlternateFlaps

    func testAlternateFlaps_eachCutEdgeGetsAtMostOneTab() {
        let mesh  = TestMesh.cube()
        let faces = TestMesh.runUnfold(mesh)
        var s = defaultSettings
        s.alternateFlaps = true
        s.glueTabShape   = .trapezoid

        let tabs = GlueTabGenerator().generate(
            faces: faces, mesh: mesh, settings: s, flapOverrides: [:]
        )

        // Count how many tabs reference each mesh edge
        var edgeTabCount: [Int: Int] = [:]
        for tab in tabs {
            let eid = faces.first { $0.faceId == tab.faceId }?.meshEdgeId(tab.localEdgeIdx) ?? -1
            if eid >= 0 { edgeTabCount[eid, default: 0] += 1 }
        }

        for (eid, count) in edgeTabCount {
            XCTAssertLessThanOrEqual(count, 1,
                "AlternateFlaps: mesh edge \(eid) should have at most 1 tab")
        }
    }
}
