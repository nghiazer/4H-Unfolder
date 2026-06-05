import Foundation
import CoreGraphics
import CoreText
import simd

// MARK: - PDF exporter (Core Graphics, no external deps)
//
// Coordinate convention:
//   PDF origin is bottom-left, Y increases upward.
//   Model convention: Y increases downward (same as screen).
//   → Y is flipped:  pdf_y = pageH - (y - minY)*scale - margin
//
// Draw order: face fills → fold lines → cut lines → boundary lines → tabs → labels

struct PDFExporter {

    // MARK: - Public API

    /// Returns PDF data, or nil if the context could not be created.
    static func export(result: UnfoldResult, settings: AppSettings.PrintSettings) -> Data? {
        let sc  = settings.svgScaleFactor * 72.0 / 25.4   // mm → PDF points (1 pt = 1/72 in)
        let mg  = settings.marginMm * 72.0 / 25.4
        let bb  = result.boundingBox
        let minX = Double(bb.min.x); let minY = Double(bb.min.y)
        let patW = Double(bb.max.x - bb.min.x)
        let patH = Double(bb.max.y - bb.min.y)
        let pageW = patW * sc + 2 * mg
        let pageH = patH * sc + 2 * mg

        // Coordinate helpers (model mm → PDF points)
        func px(_ v: SIMD2<Float>) -> CGFloat { CGFloat((Double(v.x) - minX) * sc + mg) }
        func py(_ v: SIMD2<Float>) -> CGFloat { CGFloat(pageH - (Double(v.y) - minY) * sc - mg) }
        func pt(_ v: SIMD2<Float>) -> CGPoint { CGPoint(x: px(v), y: py(v)) }

        // Set up PDF context writing to a mutable Data buffer
        var mediaBox = CGRect(x: 0, y: 0, width: pageW, height: pageH)
        let pdfData  = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else { return nil }

        ctx.beginPDFPage(nil)

        // ── Layer 1: face fills ──────────────────────────────────────────────
        let faceFill = settings.grayscaleOutput
            ? CGColor(gray: 0.82, alpha: 1)
            : CGColor(red: 0.80, green: 0.88, blue: 1.00, alpha: 0.85)

        for face in result.faces {
            let path = triPath([face.v0, face.v1, face.v2], pt: pt)
            ctx.setFillColor(faceFill)
            ctx.addPath(path)
            ctx.fillPath()
        }

        // ── Layer 2: fold edges ──────────────────────────────────────────────
        if settings.printFoldLines {
            let foldColor = cgColor(hex: settings.foldLineColor) ?? CGColor(red: 0.25, green: 0.40, blue: 0.87, alpha: 1)
            var drawn = Set<Int>()
            for face in result.faces {
                let verts = [face.v0, face.v1, face.v2]
                for ei in 0..<3 where face.edgeIsFold(ei) {
                    let mid = face.meshEdgeId(ei)
                    guard mid < 0 || drawn.insert(mid).inserted else { continue }
                    ctx.setStrokeColor(foldColor)
                    ctx.setLineWidth(CGFloat(settings.foldLineWidth) * 72 / 25.4)
                    if settings.foldLineDash != "Solid" {
                        let dash = parseDash(settings.foldLineDash, scale: 72.0 / 25.4)
                        ctx.setLineDash(phase: 0, lengths: dash)
                    } else {
                        ctx.setLineDash(phase: 0, lengths: [])
                    }
                    strokeLine(ctx, from: pt(verts[ei]), to: pt(verts[(ei+1)%3]))
                }
            }
        }

        // ── Layer 3: cut edges ───────────────────────────────────────────────
        if settings.printCutLines {
            let cutColor = cgColor(hex: settings.cutLineColor) ?? CGColor(red: 0.9, green: 0.1, blue: 0.1, alpha: 1)
            ctx.setLineDash(phase: 0, lengths: [])
            var drawn = Set<Int>()
            for face in result.faces {
                let verts = [face.v0, face.v1, face.v2]
                for ei in 0..<3 where !face.edgeIsFold(ei) && !face.edgeIsBoundary(ei) {
                    let mid = face.meshEdgeId(ei)
                    guard mid < 0 || drawn.insert(mid).inserted else { continue }
                    ctx.setStrokeColor(cutColor)
                    ctx.setLineWidth(CGFloat(settings.cutLineWidth) * 72 / 25.4)
                    strokeLine(ctx, from: pt(verts[ei]), to: pt(verts[(ei+1)%3]))
                }
            }
            // Boundary edges (thin gray)
            var drawnB = Set<Int>()
            for face in result.faces {
                let verts = [face.v0, face.v1, face.v2]
                for ei in 0..<3 where face.edgeIsBoundary(ei) {
                    let mid = face.meshEdgeId(ei)
                    guard mid < 0 || drawnB.insert(mid).inserted else { continue }
                    ctx.setStrokeColor(CGColor(gray: 0.5, alpha: 0.6))
                    ctx.setLineWidth(0.5)
                    strokeLine(ctx, from: pt(verts[ei]), to: pt(verts[(ei+1)%3]))
                }
            }
        }

        // ── Layer 4: glue tabs ───────────────────────────────────────────────
        if settings.includeGlueTabs {
            let tabFill   = settings.grayscaleOutput
                ? CGColor(gray: 0.63, alpha: 0.55)
                : CGColor(red: 0.66, green: 0.84, blue: 0.64, alpha: 0.55)
            let tabStroke = CGColor(red: 0.18, green: 0.49, blue: 0.20, alpha: 1)
            ctx.setLineDash(phase: 0, lengths: [4.0, 2.0])
            ctx.setLineWidth(0.5)
            for tab in result.tabs {
                guard tab.polygon.count >= 3 else { continue }
                let path = polyPath(tab.polygon, pt: pt)
                ctx.setFillColor(tabFill)
                ctx.addPath(path); ctx.fillPath()
                ctx.setStrokeColor(tabStroke)
                ctx.addPath(path); ctx.strokePath()
            }
        }

        // ── Layer 5: cut-pair labels ─────────────────────────────────────────
        ctx.setLineDash(phase: 0, lengths: [])
        if !result.cutEdgePairIds.isEmpty {
            let labelColor = cgColor(hex: settings.cutLineColor) ?? CGColor(red: 0.9, green: 0.1, blue: 0.1, alpha: 0.8)
            var drawn = Set<Int>()
            for face in result.faces {
                let verts = [face.v0, face.v1, face.v2]
                for ei in 0..<3 where !face.edgeIsFold(ei) && !face.edgeIsBoundary(ei) {
                    let mid = face.meshEdgeId(ei)
                    guard mid >= 0, let pairId = result.cutEdgePairIds[mid],
                          drawn.insert(mid).inserted else { continue }
                    let mp = (verts[ei] + verts[(ei+1)%3]) / 2
                    drawLabel(ctx, text: "\(pairId)", at: pt(mp), fontSize: 5, color: labelColor)
                }
            }
        }

        // ── Layer 6: page footer label ───────────────────────────────────────
        if settings.includePageLabel {
            let gray = CGColor(gray: 0.4, alpha: 1)
            let text = "4H Unfolder — \(result.faces.count) faces · \(result.pieces.count) pieces"
            drawLabel(ctx, text: text,
                      at: CGPoint(x: CGFloat(mg), y: CGFloat(mg * 0.4)),
                      fontSize: 6, color: gray)
        }

        ctx.endPDFPage()
        ctx.closePDF()
        return pdfData as Data
    }

    // MARK: - Path helpers

    private static func triPath(_ pts: [SIMD2<Float>],
                                pt: (SIMD2<Float>) -> CGPoint) -> CGPath {
        polyPath(pts, pt: pt)
    }

    private static func polyPath(_ pts: [SIMD2<Float>],
                                 pt: (SIMD2<Float>) -> CGPoint) -> CGPath {
        let path = CGMutablePath()
        guard !pts.isEmpty else { return path }
        path.move(to: pt(pts[0]))
        pts.dropFirst().forEach { path.addLine(to: pt($0)) }
        path.closeSubpath()
        return path
    }

    private static func strokeLine(_ ctx: CGContext, from a: CGPoint, to b: CGPoint) {
        ctx.move(to: a); ctx.addLine(to: b); ctx.strokePath()
    }

    // MARK: - Text (Core Text)

    private static func drawLabel(_ ctx: CGContext, text: String, at pt: CGPoint,
                                  fontSize: CGFloat, color: CGColor) {
        let font = CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)
        let attrs: [CFString: Any] = [
            kCTFontAttributeName:            font,
            kCTForegroundColorAttributeName: color
        ]
        let attrStr = CFAttributedStringCreate(
            nil, text as CFString, attrs as CFDictionary
        )!
        let line = CTLineCreateWithAttributedString(attrStr)

        // CG text origin = baseline left; flip Y locally for PDF coordinate system
        ctx.saveGState()
        ctx.translateBy(x: pt.x, y: pt.y)
        ctx.scaleBy(x: 1, y: -1)
        ctx.textPosition = .zero
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }

    // MARK: - Dash pattern helpers

    private static func parseDash(_ s: String, scale: Double) -> [CGFloat] {
        s.split(separator: ",").compactMap {
            guard let v = Double($0.trimmingCharacters(in: .whitespaces)) else { return nil }
            return CGFloat(v * scale)
        }
    }

    // MARK: - Color from hex

    private static func cgColor(hex: String) -> CGColor? {
        var h = hex.trimmingCharacters(in: .whitespaces)
        if h.hasPrefix("#") { h = String(h.dropFirst()) }
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return nil }
        return CGColor(
            red:   CGFloat((val >> 16) & 0xFF) / 255,
            green: CGFloat((val >>  8) & 0xFF) / 255,
            blue:  CGFloat( val        & 0xFF) / 255,
            alpha: 1
        )
    }
}
