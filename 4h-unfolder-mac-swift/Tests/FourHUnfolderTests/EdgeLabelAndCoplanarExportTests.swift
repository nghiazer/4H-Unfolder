import XCTest
import simd
@testable import FourHUnfolderCore

/// Covers GĐ2 (edge-matching labels) plus a GĐ1 gap found while working on GĐ2: PDFExporter had
/// no coplanar-hide gate at all, and neither exporter gated cut-pair labels behind a setting.
final class EdgeLabelAndCoplanarExportTests: XCTestCase {

    // MARK: - Helpers

    private var defaultSettings: AppSettings.PrintSettings { AppSettings.PrintSettings() }

    /// Like SVGExporterTests.pipeline, but keeps the real dihedral angles (needed to exercise
    /// HideCoplanarFolds — the shared helper there hardcodes edgeDihedralAngles: [:]).
    private func pipeline(_ mesh: Mesh) -> UnfoldResult {
        let dg      = DualGraphBuilder().build(mesh: mesh)
        let mst     = KruskalMSTBuilder().build(graph: dg)
        let foldSet = Set(mst.map { $0.sharedMeshEdgeId })
        EdgeMarker().mark(mesh: mesh, foldEdgeIds: foldSet)
        let eng   = UnfoldEngine().unfold(mesh: mesh, foldEdgeIds: foldSet)
        let tabs  = GlueTabGenerator().generate(faces: eng.faces, mesh: mesh,
                                                settings: defaultSettings, flapOverrides: [:])
        let pieces = PieceComputer().computePieces(mesh: mesh)
        // One synthetic cut-pair label so includeEdgeLabels tests have something to find.
        var cutEdgePairIds: [Int: Int] = [:]
        var n = 1
        for edge in mesh.edges where edge.type == .cut && edge.connectsFaces {
            cutEdgePairIds[edge.id] = n; n += 1
        }
        return UnfoldResult(faces: eng.faces, tabs: tabs, hasOverlaps: false,
                            cutEdgePairIds: cutEdgePairIds,
                            edgeDihedralAngles: eng.dihedralAngles, pieces: pieces)
    }

    // MARK: - SVG: edge-matching labels

    func testSVG_edgeLabels_presentByDefault() {
        // includeEdgeLabels defaults true (preserves pre-existing always-on SVG behaviour).
        let result = pipeline(TestMesh.tetrahedron())
        let svg = SVGExporter.export(result: result, settings: defaultSettings)
        XCTAssertTrue(svg.contains("<!-- cut pair labels -->"))
    }

    func testSVG_edgeLabels_absentWhenDisabled() {
        var s = defaultSettings; s.includeEdgeLabels = false
        let result = pipeline(TestMesh.tetrahedron())
        let svg = SVGExporter.export(result: result, settings: s)
        XCTAssertFalse(svg.contains("<!-- cut pair labels -->"))
    }

    // MARK: - SVG: coplanar fold-line hide (GĐ1 regression coverage)

    func testSVG_coplanarFold_hiddenWhenEnabled() {
        var s = defaultSettings; s.hideCoplanarFolds = true; s.printFoldLines = true
        let result = pipeline(TestMesh.flatStrip())   // all faces coplanar → fold dihedral ≈ 0
        let svg = SVGExporter.export(result: result, settings: s)
        // Coplanar-hide guard runs per-edge; a flat strip's fold edges must all be suppressed.
        XCTAssertFalse(svg.contains("class=\"fold\""))
    }

    func testSVG_nonCoplanarFold_notHidden() {
        var s = defaultSettings; s.hideCoplanarFolds = true; s.printFoldLines = true
        let result = pipeline(TestMesh.tetrahedron())   // sharp dihedral angles
        let svg = SVGExporter.export(result: result, settings: s)
        XCTAssertTrue(svg.contains("class=\"fold\""))
    }

    // MARK: - PDF: non-nil output + label/coplanar toggles change content size

    func testPDF_export_producesData() {
        let result = pipeline(TestMesh.tetrahedron())
        let data = PDFExporter.export(result: result, settings: defaultSettings)
        XCTAssertNotNil(data)
        XCTAssertGreaterThan(data?.count ?? 0, 0)
    }

    func testPDF_edgeLabels_toggleChangesOutput() {
        let result = pipeline(TestMesh.tetrahedron())
        var on = defaultSettings;  on.includeEdgeLabels = true
        var off = defaultSettings; off.includeEdgeLabels = false
        let dataOn  = PDFExporter.export(result: result, settings: on)
        let dataOff = PDFExporter.export(result: result, settings: off)
        XCTAssertNotNil(dataOn); XCTAssertNotNil(dataOff)
        XCTAssertNotEqual(dataOn?.count, dataOff?.count,
                          "enabling edge labels must change the rendered PDF content")
    }

    func testPDF_coplanarHide_toggleChangesOutput_onFlatMesh() {
        let result = pipeline(TestMesh.flatStrip())
        var on = defaultSettings;  on.hideCoplanarFolds = true
        var off = defaultSettings; off.hideCoplanarFolds = false
        let dataOn  = PDFExporter.export(result: result, settings: on)
        let dataOff = PDFExporter.export(result: result, settings: off)
        XCTAssertNotNil(dataOn); XCTAssertNotNil(dataOff)
        XCTAssertNotEqual(dataOn?.count, dataOff?.count,
                          "hiding coplanar folds must remove stroked fold lines from the PDF")
    }
}
