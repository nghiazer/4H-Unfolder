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
        // SVGExporter renders fold lines with an inline stroke="<foldLineColor>" attribute, not a
        // CSS class — the coplanar-hide guard runs per-edge; a flat strip's fold edges must all
        // be suppressed, so no line should carry the fold stroke color.
        XCTAssertFalse(svg.contains(#"stroke="\#(s.foldLineColor)""#))
    }

    func testSVG_nonCoplanarFold_notHidden() {
        var s = defaultSettings; s.hideCoplanarFolds = true; s.printFoldLines = true
        let result = pipeline(TestMesh.tetrahedron())   // sharp dihedral angles
        let svg = SVGExporter.export(result: result, settings: s)
        XCTAssertTrue(svg.contains(#"stroke="\#(s.foldLineColor)""#))
    }

    // MARK: - isCoplanarFold: threshold floor (cross-review fix)
    //
    // UnfoldEngine only stores angles > 1° in edgeDihedralAngles (needed to suppress fake
    // fold-angle labels on fan-triangulation diagonals) — so an absent entry always means the
    // real angle is in [0°, 1°]. isCoplanarFold clamps its effective threshold to that same 1°
    // floor so a user-configured value below it can't silently misclassify a real ~0.6° edge.

    func testIsCoplanarFold_absentEdge_hiddenEvenBelowEngineFloor() {
        var s = defaultSettings; s.hideCoplanarFolds = true; s.coplanarAngleDeg = 0.3
        let result = UnfoldResult(faces: [], tabs: [], hasOverlaps: false,
                                  cutEdgePairIds: [:], edgeDihedralAngles: [:], pieces: [])
        XCTAssertTrue(SVGExporter.isCoplanarFold(0, result: result, settings: s),
                     "an absent entry (real angle in [0°,1°]) must stay hidden even when the " +
                     "configured threshold is below the engine's 1° floor")
    }

    func testIsCoplanarFold_presentEdgeAboveThreshold_notHidden() {
        var s = defaultSettings; s.hideCoplanarFolds = true; s.coplanarAngleDeg = 5.0
        let result = UnfoldResult(faces: [], tabs: [], hasOverlaps: false,
                                  cutEdgePairIds: [:], edgeDihedralAngles: [7: Float(7.0)], pieces: [])
        XCTAssertFalse(SVGExporter.isCoplanarFold(7, result: result, settings: s))
    }

    func testIsCoplanarFold_presentEdgeBelowThreshold_hidden() {
        var s = defaultSettings; s.hideCoplanarFolds = true; s.coplanarAngleDeg = 5.0
        let result = UnfoldResult(faces: [], tabs: [], hasOverlaps: false,
                                  cutEdgePairIds: [:], edgeDihedralAngles: [7: Float(3.0)], pieces: [])
        XCTAssertTrue(SVGExporter.isCoplanarFold(7, result: result, settings: s))
    }

    func testIsCoplanarFold_disabled_neverHides() {
        var s = defaultSettings; s.hideCoplanarFolds = false
        let result = UnfoldResult(faces: [], tabs: [], hasOverlaps: false,
                                  cutEdgePairIds: [:], edgeDihedralAngles: [:], pieces: [])
        XCTAssertFalse(SVGExporter.isCoplanarFold(0, result: result, settings: s))
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
