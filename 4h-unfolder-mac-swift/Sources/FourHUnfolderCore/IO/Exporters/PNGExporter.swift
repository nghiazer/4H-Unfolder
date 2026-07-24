import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers
import simd

// MARK: - PNG exporter (Core Graphics, no external deps)
//
// Exports one PNG raster image per page — for cutting-machine software (Cricut / laser) that
// prefers bitmap import over SVG/PDF. Mirrors PDFExporter's drawing approach (same CoreGraphics
// calls) but targets a bitmap CGContext instead of a PDF context, and adds per-page grid
// splitting (pagesWide × pagesTall, pageSepMm gap) that PDFExporter doesn't currently have on
// this platform (single-page only there).
//
// A bitmap CGContext has the same bottom-left-origin, Y-up coordinate convention as a PDF
// context, so the Y-flip math is identical to PDFExporter's.

struct PNGExporter {

    /// Returns the file URLs written — one per page, in row-major order.
    static func export(
        result: UnfoldResult, settings: AppSettings.PrintSettings,
        baseURL: URL, paperWidthMm: Double, paperHeightMm: Double,
        pagesWide: Int = 1, pagesTall: Int = 1, pageSepMm: Double = 20
    ) -> [URL] {
        let dpi     = settings.pngDpi > 0 ? settings.pngDpi : 300.0
        let pxPerMm = dpi / 25.4

        let pixelW = max(1, Int((paperWidthMm  * pxPerMm).rounded()))
        let pixelH = max(1, Int((paperHeightMm * pxPerMm).rounded()))

        let dir  = baseURL.deletingLastPathComponent()
        let name = baseURL.deletingPathExtension().lastPathComponent
        let cols = max(1, pagesWide), rows = max(1, pagesTall)
        let totalPages = cols * rows

        var written: [URL] = []

        for row in 0..<rows {
            for col in 0..<cols {
                let oxMm = Double(col) * (paperWidthMm + pageSepMm)
                let oyMm = Double(row) * (paperHeightMm + pageSepMm)

                guard let ctx = CGContext(
                    data: nil, width: pixelW, height: pixelH,
                    bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                ) else { continue }

                func px(_ v: SIMD2<Float>) -> CGFloat { CGFloat((Double(v.x) - oxMm) * pxPerMm) }
                func py(_ v: SIMD2<Float>) -> CGFloat { CGFloat(pixelH) - CGFloat((Double(v.y) - oyMm) * pxPerMm) }
                func pt(_ v: SIMD2<Float>) -> CGPoint { CGPoint(x: px(v), y: py(v)) }

                drawPage(ctx: ctx, result: result, settings: settings, pt: pt,
                         pxPerMm: pxPerMm, pixelW: pixelW, pixelH: pixelH,
                         oxMm: oxMm, oyMm: oyMm, paperWidthMm: paperWidthMm, paperHeightMm: paperHeightMm,
                         pageLabel: totalPages > 1 ? "\(name)  p.\(row * cols + col + 1)" : name)

                guard let image = ctx.makeImage() else { continue }
                let pageNum = row * cols + col + 1
                let fileName = totalPages > 1 ? "\(name)_p\(pageNum).png" : "\(name).png"
                let outURL = dir.appendingPathComponent(fileName)

                guard let dest = CGImageDestinationCreateWithURL(outURL as CFURL, UTType.png.identifier as CFString, 1, nil)
                else { continue }
                CGImageDestinationAddImage(dest, image, nil)
                guard CGImageDestinationFinalize(dest) else { continue }

                written.append(outURL)
            }
        }

        return written
    }

    // MARK: - Page content

    private static func drawPage(
        ctx: CGContext, result: UnfoldResult, settings: AppSettings.PrintSettings,
        pt: (SIMD2<Float>) -> CGPoint, pxPerMm: Double, pixelW: Int, pixelH: Int,
        oxMm: Double, oyMm: Double, paperWidthMm: Double, paperHeightMm: Double, pageLabel: String
    ) {
        // White page background.
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: pixelW, height: pixelH))

        // ── face fills ───────────────────────────────────────────────────────
        let faceFill = settings.grayscaleOutput
            ? CGColor(gray: 0.82, alpha: 1)
            : CGColor(red: 0.80, green: 0.88, blue: 1.00, alpha: 0.85)
        for face in result.faces {
            guard isOnPage(face, oxMm, oyMm, paperWidthMm, paperHeightMm) else { continue }
            ctx.setFillColor(faceFill)
            ctx.addPath(polyPath([face.v0, face.v1, face.v2], pt: pt))
            ctx.fillPath()
        }

        // ── fold edges ───────────────────────────────────────────────────────
        if settings.printFoldLines {
            let foldColor = settings.grayscaleOutput
                ? CGColor(red: 0.33, green: 0.33, blue: 0.33, alpha: 1)
                : (cgColor(hex: settings.foldLineColor) ?? CGColor(red: 0.25, green: 0.40, blue: 0.87, alpha: 1))
            var drawn = Set<Int>()
            for face in result.faces {
                guard isOnPage(face, oxMm, oyMm, paperWidthMm, paperHeightMm) else { continue }
                let verts = [face.v0, face.v1, face.v2]
                for ei in 0..<3 where face.edgeIsFold(ei) {
                    let mid = face.meshEdgeId(ei)
                    guard mid < 0 || drawn.insert(mid).inserted else { continue }
                    if SVGExporter.isCoplanarFold(mid, result: result, settings: settings) { continue }
                    ctx.setStrokeColor(foldColor)
                    ctx.setLineWidth(CGFloat(settings.foldLineWidth) * pxPerMm)
                    if settings.foldLineDash != "Solid" {
                        ctx.setLineDash(phase: 0, lengths: parseDash(settings.foldLineDash, scale: pxPerMm))
                    } else {
                        ctx.setLineDash(phase: 0, lengths: [])
                    }
                    strokeLine(ctx, from: pt(verts[ei]), to: pt(verts[(ei + 1) % 3]))
                }
            }
        }

        // ── cut / boundary edges ─────────────────────────────────────────────
        ctx.setLineDash(phase: 0, lengths: [])
        if settings.printCutLines {
            let cutColor = settings.grayscaleOutput
                ? CGColor(red: 0, green: 0, blue: 0, alpha: 1)
                : (cgColor(hex: settings.cutLineColor) ?? CGColor(red: 0.9, green: 0.1, blue: 0.1, alpha: 1))
            var drawn = Set<Int>()
            for face in result.faces {
                guard isOnPage(face, oxMm, oyMm, paperWidthMm, paperHeightMm) else { continue }
                let verts = [face.v0, face.v1, face.v2]
                for ei in 0..<3 where !face.edgeIsFold(ei) && !face.edgeIsBoundary(ei) {
                    let mid = face.meshEdgeId(ei)
                    guard mid < 0 || drawn.insert(mid).inserted else { continue }
                    ctx.setStrokeColor(cutColor)
                    ctx.setLineWidth(CGFloat(settings.cutLineWidth) * pxPerMm)
                    strokeLine(ctx, from: pt(verts[ei]), to: pt(verts[(ei + 1) % 3]))
                }
            }
            var drawnB = Set<Int>()
            for face in result.faces {
                guard isOnPage(face, oxMm, oyMm, paperWidthMm, paperHeightMm) else { continue }
                let verts = [face.v0, face.v1, face.v2]
                for ei in 0..<3 where face.edgeIsBoundary(ei) {
                    let mid = face.meshEdgeId(ei)
                    guard mid < 0 || drawnB.insert(mid).inserted else { continue }
                    ctx.setStrokeColor(CGColor(gray: 0.5, alpha: 0.6))
                    ctx.setLineWidth(0.5 * pxPerMm)
                    strokeLine(ctx, from: pt(verts[ei]), to: pt(verts[(ei + 1) % 3]))
                }
            }
        }

        // ── glue tabs ────────────────────────────────────────────────────────
        if settings.includeGlueTabs {
            let tabFill = settings.grayscaleOutput
                ? CGColor(gray: 0.63, alpha: 0.55)
                : CGColor(red: 0.66, green: 0.84, blue: 0.64, alpha: 0.55)
            let tabStroke = CGColor(red: 0.18, green: 0.49, blue: 0.20, alpha: 1)
            ctx.setLineDash(phase: 0, lengths: [])
            ctx.setLineWidth(0.5 * pxPerMm)
            for tab in result.tabs {
                guard tab.polygon.count >= 3, isTabOnPage(tab, oxMm, oyMm, paperWidthMm, paperHeightMm) else { continue }
                let path = polyPath(tab.polygon, pt: pt)
                ctx.setFillColor(tabFill); ctx.addPath(path); ctx.fillPath()
                ctx.setStrokeColor(tabStroke); ctx.addPath(path); ctx.strokePath()
            }
        }

        // ── cut-pair labels ──────────────────────────────────────────────────
        if settings.includeEdgeLabels && !result.cutEdgePairIds.isEmpty {
            let labelColor = settings.grayscaleOutput
                ? CGColor(red: 0, green: 0, blue: 0, alpha: 1)
                : (cgColor(hex: settings.cutLineColor) ?? CGColor(red: 0.9, green: 0.1, blue: 0.1, alpha: 0.8))
            var drawn = Set<Int>()
            for face in result.faces {
                guard isOnPage(face, oxMm, oyMm, paperWidthMm, paperHeightMm) else { continue }
                let verts = [face.v0, face.v1, face.v2]
                for ei in 0..<3 where !face.edgeIsFold(ei) && !face.edgeIsBoundary(ei) {
                    let mid = face.meshEdgeId(ei)
                    guard mid >= 0, let pairId = result.cutEdgePairIds[mid],
                          drawn.insert(mid).inserted else { continue }
                    let mp = (verts[ei] + verts[(ei + 1) % 3]) / 2
                    drawLabel(ctx, text: "\(pairId)", at: pt(mp), fontSize: 5 * CGFloat(pxPerMm / (settings.svgScaleFactor)), color: labelColor)
                }
            }
        }

        // ── page footer label ────────────────────────────────────────────────
        if settings.includePageLabel {
            drawLabel(ctx, text: pageLabel, at: CGPoint(x: 4 * pxPerMm, y: 4 * pxPerMm),
                      fontSize: 6 * CGFloat(pxPerMm / settings.svgScaleFactor), color: CGColor(gray: 0.4, alpha: 1))
        }
    }

    // MARK: - Page-slice filtering (mirrors PDFExporter's IsOnPage / IsTabOnPage)

    // Broken into an explicit loop with a named helper (rather than a `.contains { }` closure
    // with a compound && chain) — the compound-boolean-in-generic-closure form made the real
    // Swift compiler (Xcode, on CI) time out with "unable to type-check this expression in
    // reasonable time"; the local toolchain used during development didn't hit that timeout, so
    // this was only caught by real CI, not local `swift build`.
    private static func vertexInRect(_ v: SIMD2<Float>, _ oxMm: Double, _ oyMm: Double, _ wMm: Double, _ hMm: Double) -> Bool {
        let x = Double(v.x)
        let y = Double(v.y)
        let xOk = x >= oxMm && x <= oxMm + wMm
        let yOk = y >= oyMm && y <= oyMm + hMm
        return xOk && yOk
    }

    private static func isOnPage(_ face: UnfoldedFace, _ oxMm: Double, _ oyMm: Double, _ wMm: Double, _ hMm: Double) -> Bool {
        for v in [face.v0, face.v1, face.v2] where vertexInRect(v, oxMm, oyMm, wMm, hMm) { return true }
        return false
    }

    private static func isTabOnPage(_ tab: GlueTab, _ oxMm: Double, _ oyMm: Double, _ wMm: Double, _ hMm: Double) -> Bool {
        for v in tab.polygon where vertexInRect(v, oxMm, oyMm, wMm, hMm) { return true }
        return false
    }

    // MARK: - Path helpers

    private static func polyPath(_ pts: [SIMD2<Float>], pt: (SIMD2<Float>) -> CGPoint) -> CGPath {
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

    private static func drawLabel(_ ctx: CGContext, text: String, at pt: CGPoint, fontSize: CGFloat, color: CGColor) {
        let font = CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)
        let attrs: [CFString: Any] = [kCTFontAttributeName: font, kCTForegroundColorAttributeName: color]
        let attrStr = CFAttributedStringCreate(nil, text as CFString, attrs as CFDictionary)!
        let line = CTLineCreateWithAttributedString(attrStr)

        ctx.saveGState()
        ctx.translateBy(x: pt.x, y: pt.y)
        ctx.scaleBy(x: 1, y: -1)
        ctx.textPosition = .zero
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }

    // MARK: - Dash pattern

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
