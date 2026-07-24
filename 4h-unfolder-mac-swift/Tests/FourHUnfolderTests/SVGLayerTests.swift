import XCTest
import simd
@testable import FourHUnfolderCore

/// GĐ4.1: SVG cutting-machine layers (Inkscape-style <g> groups) so LightBurn / Cricut Design
/// Space / Inkscape can show, hide, or assign per-operation settings by layer.
final class SVGLayerTests: XCTestCase {

    // Two triangles: one fold edge (meshEdge 5), one cut edge (meshEdge 7).
    private func twoFacesFoldAndCut() -> UnfoldResult {
        let foldFace = UnfoldedFace(
            faceId: 0, materialId: -1,
            v0: SIMD2(0, 0), v1: SIMD2(10, 0), v2: SIMD2(0, 10),
            edge0IsFold: true, edge1IsFold: false, edge2IsFold: false,
            edge0IsBoundary: false, edge1IsBoundary: true, edge2IsBoundary: true,
            uv0: nil, uv1: nil, uv2: nil,
            meshEdge0: 5, meshEdge1: -1, meshEdge2: -1)
        let cutFace = UnfoldedFace(
            faceId: 1, materialId: -1,
            v0: SIMD2(10, 0), v1: SIMD2(20, 0), v2: SIMD2(10, 10),
            edge0IsFold: false, edge1IsFold: false, edge2IsFold: false,
            edge0IsBoundary: false, edge1IsBoundary: true, edge2IsBoundary: true,
            uv0: nil, uv1: nil, uv2: nil,
            meshEdge0: 7, meshEdge1: -1, meshEdge2: -1)

        return UnfoldResult(faces: [foldFace, cutFace], tabs: [], hasOverlaps: false,
                            cutEdgePairIds: [7: 1])
    }

    private func exportSvg() -> String {
        var s = AppSettings.PrintSettings()
        s.printFoldLines    = true
        s.printCutLines     = true
        s.includeEdgeLabels = true
        return SVGExporter.export(result: twoFacesFoldAndCut(), settings: s)
    }

    func testSvg_declaresInkscapeNamespace() {
        XCTAssertTrue(exportSvg().contains("xmlns:inkscape="))
    }

    func testSvg_hasFoldLinesLayer() {
        XCTAssertTrue(exportSvg().contains(#"inkscape:label="Fold Lines""#))
    }

    func testSvg_hasCutLinesLayer() {
        XCTAssertTrue(exportSvg().contains(#"inkscape:label="Cut Lines""#))
    }

    func testSvg_hasEdgeLabelsLayer() {
        XCTAssertTrue(exportSvg().contains(#"inkscape:label="Edge Labels""#))
    }

    func testSvg_existingCommentMarkers_stillPresent() {
        // The <g> wrapping added around these must not remove or alter them — other tests
        // (SVGExporterTests, EdgeLabelAndCoplanarExportTests) assert on these exact strings.
        let svg = exportSvg()
        XCTAssertTrue(svg.contains("<!-- fold edges -->"))
        XCTAssertTrue(svg.contains("<!-- cut edges -->"))
    }
}
