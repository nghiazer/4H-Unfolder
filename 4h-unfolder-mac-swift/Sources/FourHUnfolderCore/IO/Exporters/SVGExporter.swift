import Foundation
import simd

// MARK: - SVG exporter
//
// Coordinate convention (mirrors C# SvgExporter):
//   x' = (x - minX) * scale + margin
//   y' = (y - minY) * scale + margin   (Y increases downward, same as model convention)
//
// Draw order (matching PatternCanvasView layers):
//   1. Face polygons
//   2. Fold lines (dashed blue)
//   3. Cut lines (solid red)
//   4. Boundary lines (gray, thin)
//   5. Glue tab polygons
//   6. Cut-pair number labels
//   7. Page label (optional)

struct SVGExporter {

    /// True when a fold edge should be hidden because its faces are (near-)coplanar.
    /// `edgeDihedralAngles` omits edges ≤1° (see UnfoldEngine), so an absent angle means flat.
    static func isCoplanarFold(_ meshEdgeId: Int, result: UnfoldResult,
                               settings: AppSettings.PrintSettings) -> Bool {
        guard settings.hideCoplanarFolds, meshEdgeId >= 0 else { return false }
        // UnfoldEngine only stores angles > 1° (needed elsewhere to suppress fake fold-angle
        // labels on fan-triangulation diagonals) — an absent entry always means the real angle is
        // in [0°, 1°]. Clamp the effective threshold to that same 1° floor so the "absent →
        // coplanar" fallback below stays correct even if the user configures a threshold under
        // it; otherwise a real ~0.6° edge would get hidden even when asked to keep ≥0.3° visible.
        let threshold = max(1.0, Float(settings.coplanarAngleDeg))
        guard let deg = result.edgeDihedralAngles[meshEdgeId] else { return true }
        return deg < threshold
    }

    // MARK: - Public API

    static func export(result: UnfoldResult, settings: AppSettings.PrintSettings) -> String {
        let bb  = result.boundingBox
        let sc  = settings.svgScaleFactor
        let mg  = settings.marginMm * sc
        let ox  = Double(-bb.min.x) * sc + mg
        let oy  = Double(-bb.min.y) * sc + mg
        let svgW = Double(bb.max.x - bb.min.x) * sc + 2 * mg
        let svgH = Double(bb.max.y - bb.min.y) * sc + 2 * mg

        func px(_ v: SIMD2<Float>) -> String {
            "\(Double(v.x) * sc + ox),\(Double(v.y) * sc + oy)"
        }
        func x(_ v: SIMD2<Float>) -> String { String(Double(v.x) * sc + ox) }
        func y(_ v: SIMD2<Float>) -> String { String(Double(v.y) * sc + oy) }

        var lines: [String] = []

        // Header
        lines.append(#"<?xml version="1.0" encoding="UTF-8"?>"#)
        lines.append("""
            <svg xmlns="http://www.w3.org/2000/svg" \
            xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape" \
            width="\(svgW)mm" height="\(svgH)mm" \
            viewBox="0 0 \(svgW) \(svgH)">
            """)

        // ── Layer 1: face fills ──────────────────────────────────────────────
        let fillColor = settings.grayscaleOutput ? "#d0d0d0" : "#cce0ff"
        lines.append("  <!-- faces -->")
        for face in result.faces {
            let pts = [face.v0, face.v1, face.v2].map(px).joined(separator: " ")
            lines.append(#"  <polygon points="\#(pts)" fill="\#(fillColor)" stroke="none"/>"#)
        }

        // ── Layer 2 & 3: edges ───────────────────────────────────────────────
        let foldDash  = settings.foldLineDash == "Solid" ? "" :
            #" stroke-dasharray="\#(settings.foldLineDash)""#
        var drawnFolds = Set<Int>(); var drawnCuts = Set<Int>(); var drawnBounds = Set<Int>()

        // Each category below is wrapped in an Inkscape-style layer <g> — lets cutting-machine
        // software (LightBurn, Cricut Design Space, Inkscape) show/hide or assign per-operation
        // settings by layer. Existing HTML comments are kept as-is (tests assert on them);
        // the <g> wrapping is purely additive.
        if settings.printFoldLines {
            lines.append("  <g inkscape:groupmode=\"layer\" inkscape:label=\"Fold Lines\" id=\"layer-fold\">")
            lines.append("  <!-- fold edges -->")
            for face in result.faces {
                let verts = [face.v0, face.v1, face.v2]
                for ei in 0..<3 where face.edgeIsFold(ei) {
                    let mid = face.meshEdgeId(ei)
                    guard mid < 0 || drawnFolds.insert(mid).inserted else { continue }
                    if isCoplanarFold(mid, result: result, settings: settings) { continue }
                    let (p0, p1) = (verts[ei], verts[(ei+1)%3])
                    lines.append(#"  <line x1="\#(x(p0))" y1="\#(y(p0))" x2="\#(x(p1))" y2="\#(y(p1))" stroke="\#(settings.foldLineColor)" stroke-width="\#(settings.foldLineWidth)"\#(foldDash)/>"#)
                }
            }
            lines.append("  </g>")
        }

        if settings.printCutLines {
            // Boundary edges are the outer silhouette of a piece — a cutting machine treats
            // them the same as internal cut edges (both get physically cut), so they share
            // this layer rather than the fold layer above.
            lines.append("  <g inkscape:groupmode=\"layer\" inkscape:label=\"Cut Lines\" id=\"layer-cut\">")
            lines.append("  <!-- cut edges -->")
            for face in result.faces {
                let verts = [face.v0, face.v1, face.v2]
                for ei in 0..<3 where !face.edgeIsFold(ei) && !face.edgeIsBoundary(ei) {
                    let mid = face.meshEdgeId(ei)
                    guard mid < 0 || drawnCuts.insert(mid).inserted else { continue }
                    let (p0, p1) = (verts[ei], verts[(ei+1)%3])
                    lines.append(#"  <line x1="\#(x(p0))" y1="\#(y(p0))" x2="\#(x(p1))" y2="\#(y(p1))" stroke="\#(settings.cutLineColor)" stroke-width="\#(settings.cutLineWidth)"/>"#)
                }
            }
            lines.append("  <!-- boundary edges -->")
            for face in result.faces {
                let verts = [face.v0, face.v1, face.v2]
                for ei in 0..<3 where face.edgeIsBoundary(ei) {
                    let mid = face.meshEdgeId(ei)
                    guard mid < 0 || drawnBounds.insert(mid).inserted else { continue }
                    let (p0, p1) = (verts[ei], verts[(ei+1)%3])
                    lines.append(##"  <line x1="\##(x(p0))" y1="\##(y(p0))" x2="\##(x(p1))" y2="\##(y(p1))" stroke="#888" stroke-width="0.5"/>"##)
                }
            }
            lines.append("  </g>")
        }

        // ── Layer 4: glue tabs ───────────────────────────────────────────────
        if settings.includeGlueTabs {
            let tabColor = settings.grayscaleOutput ? "#a0a0a0" : "#a8d5a2"
            lines.append("  <g inkscape:groupmode=\"layer\" inkscape:label=\"Glue Tabs\" id=\"layer-tabs\">")
            lines.append("  <!-- glue tabs -->")
            for tab in result.tabs {
                let pts = tab.polygon.map(px).joined(separator: " ")
                lines.append("  <polygon points=\"\(pts)\" fill=\"\(tabColor)\" fill-opacity=\"0.6\" stroke=\"#2e7d32\" stroke-width=\"0.4\"/>")
            }
            lines.append("  </g>")
        }

        // ── Layer 5: cut-pair number labels ──────────────────────────────────
        if settings.includeEdgeLabels && !result.cutEdgePairIds.isEmpty {
            lines.append("  <g inkscape:groupmode=\"layer\" inkscape:label=\"Edge Labels\" id=\"layer-labels\">")
            lines.append("  <!-- cut pair labels -->")
            var drawnLabels = Set<Int>()
            for face in result.faces {
                let verts = [face.v0, face.v1, face.v2]
                for ei in 0..<3 where !face.edgeIsFold(ei) && !face.edgeIsBoundary(ei) {
                    let mid = face.meshEdgeId(ei)
                    guard mid >= 0, let pairId = result.cutEdgePairIds[mid],
                          drawnLabels.insert(mid).inserted else { continue }
                    let mp = (verts[ei] + verts[(ei+1)%3]) / 2
                    lines.append(#"  <text x="\#(x(mp))" y="\#(y(mp))" font-family="Helvetica,sans-serif" font-size="3" fill="\#(settings.cutLineColor)" text-anchor="middle" dominant-baseline="middle">\#(pairId)</text>"#)
                }
            }
            lines.append("  </g>")
        }

        // ── Layer 6: page label ──────────────────────────────────────────────
        if settings.includePageLabel {
            let lx = String(mg / 2)
            let ly = String(svgH - mg / 2)
            lines.append(##"  <text x="\##(lx)" y="\##(ly)" font-family="Helvetica,sans-serif" font-size="4" fill="#555">4H Unfolder \##(result.faces.count) faces / \##(result.pieces.count) pieces</text>"##)
        }

        lines.append("</svg>")
        return lines.joined(separator: "\n")
    }
}
