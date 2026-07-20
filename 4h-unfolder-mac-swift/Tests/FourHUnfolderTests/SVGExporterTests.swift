import XCTest
import simd
@testable import FourHUnfolderCore

final class SVGExporterTests: XCTestCase {

    // MARK: - Helpers

    private var defaultSettings: AppSettings.PrintSettings { AppSettings.PrintSettings() }

    /// Run the full unfold pipeline on a mesh and export to SVG.
    private func export(_ mesh: Mesh, settings: AppSettings.PrintSettings? = nil) -> String {
        let result = pipeline(mesh)
        return SVGExporter.export(result: result, settings: settings ?? defaultSettings)
    }

    private func pipeline(_ mesh: Mesh) -> UnfoldResult {
        let dg      = DualGraphBuilder().build(mesh: mesh)
        let mst     = KruskalMSTBuilder().build(graph: dg)
        let foldSet = Set(mst.map { $0.sharedMeshEdgeId })
        EdgeMarker().mark(mesh: mesh, foldEdgeIds: foldSet)
        let eng   = UnfoldEngine().unfold(mesh: mesh, foldEdgeIds: foldSet)
        let tabs  = GlueTabGenerator().generate(faces: eng.faces, mesh: mesh,
                                                settings: defaultSettings, flapOverrides: [:])
        let pieces = PieceComputer().computePieces(mesh: mesh)
        return UnfoldResult(faces: eng.faces, tabs: tabs, hasOverlaps: false,
                            cutEdgePairIds: [:], edgeDihedralAngles: [:], pieces: pieces)
    }

    // MARK: - SVG structure

    func testSVG_hasXMLHeader() {
        let svg = export(TestMesh.tetrahedron())
        XCTAssertTrue(svg.hasPrefix("<?xml"), "SVG must start with XML declaration")
    }

    func testSVG_hasSVGOpenTag() {
        let svg = export(TestMesh.tetrahedron())
        XCTAssertTrue(svg.contains("<svg "), "SVG must contain opening <svg> tag")
    }

    func testSVG_hasClosingTag() {
        let svg = export(TestMesh.tetrahedron())
        XCTAssertTrue(svg.contains("</svg>"), "SVG must be closed with </svg>")
    }

    func testSVG_facePolygonCount_tetrahedron() {
        let svg = export(TestMesh.tetrahedron())
        let count = svg.components(separatedBy: "<polygon ").count - 1
        XCTAssertGreaterThanOrEqual(count, 4, "Tetrahedron SVG must have at least 4 face polygons")
    }

    func testSVG_facePolygonCount_cube() {
        let svg = export(TestMesh.cube())
        let count = svg.components(separatedBy: "<polygon ").count - 1
        XCTAssertGreaterThanOrEqual(count, 12, "Cube SVG must have at least 12 face polygons")
    }

    // MARK: - Dimensions

    func testSVG_widthAndHeightPresent() {
        let svg = export(TestMesh.tetrahedron())
        XCTAssertTrue(svg.contains("width="), "SVG must declare a width attribute")
        XCTAssertTrue(svg.contains("height="), "SVG must declare a height attribute")
    }

    func testSVG_widthAndHeightPositive() {
        let svg = export(TestMesh.cube())
        // Extract width value from 'width="<value>mm"'
        if let range = svg.range(of: #"width="([\d.]+)mm""#, options: .regularExpression) {
            let token = String(svg[range])
            let digits = token.filter { $0.isNumber || $0 == "." }
            XCTAssertGreaterThan(Double(digits) ?? 0, 0, "SVG width must be > 0")
        }
    }

    // MARK: - Flags: fold lines

    func testSVG_foldLines_presentWhenEnabled() {
        var s = defaultSettings; s.printFoldLines = true
        let svg = export(TestMesh.tetrahedron(), settings: s)
        XCTAssertTrue(svg.contains("<!-- fold edges -->"),
                      "SVG must contain fold-edge comment when printFoldLines=true")
    }

    func testSVG_foldLines_absentWhenDisabled() {
        var s = defaultSettings; s.printFoldLines = false
        let svg = export(TestMesh.tetrahedron(), settings: s)
        XCTAssertFalse(svg.contains("<!-- fold edges -->"),
                       "SVG must NOT contain fold-edge section when printFoldLines=false")
    }

    // MARK: - Flags: cut lines

    func testSVG_cutLines_presentWhenEnabled() {
        var s = defaultSettings; s.printCutLines = true
        let svg = export(TestMesh.tetrahedron(), settings: s)
        XCTAssertTrue(svg.contains("<!-- cut edges -->"),
                      "SVG must contain cut-edge comment when printCutLines=true")
    }

    func testSVG_cutLines_absentWhenDisabled() {
        var s = defaultSettings; s.printCutLines = false
        let svg = export(TestMesh.tetrahedron(), settings: s)
        XCTAssertFalse(svg.contains("<!-- cut edges -->"),
                       "SVG must NOT contain cut-edge section when printCutLines=false")
    }

    // MARK: - Flags: glue tabs

    func testSVG_glueTabs_presentWhenEnabled() {
        var s = defaultSettings; s.includeGlueTabs = true
        let svg = export(TestMesh.tetrahedron(), settings: s)
        XCTAssertTrue(svg.contains("<!-- glue tabs -->"),
                      "SVG must contain glue-tab section when includeGlueTabs=true")
    }

    func testSVG_glueTabs_absentWhenDisabled() {
        var s = defaultSettings; s.includeGlueTabs = false
        let svg = export(TestMesh.tetrahedron(), settings: s)
        XCTAssertFalse(svg.contains("<!-- glue tabs -->"),
                       "SVG must NOT contain glue-tab section when includeGlueTabs=false")
    }

    // MARK: - Grayscale

    func testSVG_grayscale_fillColor() {
        var s = defaultSettings; s.grayscaleOutput = true
        let svg = export(TestMesh.tetrahedron(), settings: s)
        XCTAssertTrue(svg.contains("#d0d0d0"),
                      "Grayscale SVG must use gray fill color #d0d0d0")
    }

    func testSVG_color_fillColor() {
        var s = defaultSettings; s.grayscaleOutput = false
        let svg = export(TestMesh.tetrahedron(), settings: s)
        XCTAssertTrue(svg.contains("#cce0ff"),
                      "Color SVG must use blue fill color #cce0ff")
    }

    // MARK: - Empty result

    func testSVG_emptyResult_doesNotCrash() {
        let empty = UnfoldResult(faces: [], tabs: [], hasOverlaps: false,
                                 cutEdgePairIds: [:], edgeDihedralAngles: [:], pieces: [])
        let svg = SVGExporter.export(result: empty, settings: defaultSettings)
        XCTAssertTrue(svg.contains("<svg "), "Empty result must still produce valid SVG shell")
        XCTAssertTrue(svg.contains("</svg>"))
    }

    // MARK: - Coordinate sanity: root face at origin → polygon points near margin

    func testSVG_rootFace_coordsNearMargin() {
        // Use a single isolated face so bb.min = (0,0) and v0=(0,0) maps exactly to (margin, margin).
        // A tetrahedron unfolds children that extend to negative coords, shifting the origin offset.
        let mesh = Mesh()
        mesh.vertices = [
            Vertex(id: 0, position: SIMD3(0, 0, 0)),
            Vertex(id: 1, position: SIMD3(1, 0, 0)),
            Vertex(id: 2, position: SIMD3(0.5, Float(3.0.squareRoot() / 2.0), 0)),
        ]
        let e0 = mesh.getOrAddEdge(v1: 0, v2: 1, faceId: 0)
        let e1 = mesh.getOrAddEdge(v1: 1, v2: 2, faceId: 0)
        let e2 = mesh.getOrAddEdge(v1: 2, v2: 0, faceId: 0)
        mesh.faces.append(Face(id: 0, a: 0, b: 1, c: 2, edgeIds: (e0, e1, e2)))

        var s = defaultSettings
        s.marginMm = 10.0
        let svg = export(mesh, settings: s)
        // v0=(0,0) is at bb.min → maps to (margin, margin) = (10.0, 10.0)
        XCTAssertTrue(svg.contains("10.0,10.0") || svg.contains("10,10"),
                      "Root face v0=(0,0) must map to the margin point in SVG coordinates")
    }
}
