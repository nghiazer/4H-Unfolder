import SwiftUI
import simd

// MARK: - 2D interactive pattern canvas
//
// Rendering layers (draw order):
//  1. Paper background (white rect)
//  2. Grid lines (optional)
//  3. Face polygons (filled)
//  4. Edges (fold=blue dashed, cut=red, boundary=gray)
//  5. Glue tabs (semi-transparent green)
//  6. Cut-edge pair numbers
//  7. Face ID labels (optional)
//  8. Fold angle labels (optional)
//  9. Selection highlight (amber overlay)
//
// Interactions:
//  - Pinch (trackpad) → zoom centered on view
//  - Click + drag → pan
//  - Tap near edge (≤8pt) → toggleEdge → re-unfold
//  - Tap on face → select face (shown in 3D viewport too)
//  - Mesh change → auto-reset zoom/pan to fit

struct PatternCanvasView: View {
    @EnvironmentObject var appState: AppState

    @State private var zoom: CGFloat = 1.0
    @State private var pan:  CGSize  = .zero
    @GestureState private var livePan: CGSize  = .zero
    @GestureState private var liveMag: CGFloat = 1.0

    private var v2d: AppSettings.View2DSettings { appState.settings.view2D }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            ZStack {
                canvasBg

                if let result = appState.unfoldResult {
                    Canvas { ctx, size in
                        let xf = modelToScreen(size: size, result: result)
                        drawPaper(ctx, result: result, xf: xf)
                        if v2d.showGrid { drawGrid(ctx, size: size, result: result, xf: xf) }
                        drawFaces(ctx, result: result, xf: xf)
                        drawEdges(ctx, result: result, xf: xf)
                        if v2d.showGlueTabs   { drawTabs(ctx, result: result, xf: xf) }
                        drawCutLabels(ctx, result: result, xf: xf)
                        if v2d.showFaceNumbers { drawFaceLabels(ctx, result: result, xf: xf) }
                        if v2d.showFoldAngles  { drawFoldAngles(ctx, result: result, xf: xf) }
                        drawSelection(ctx, result: result, xf: xf)
                    }
                    .gesture(magnifyGesture)
                    .gesture(panGesture)
                    .onTapGesture { pt in
                        handleTap(at: pt, result: result, canvasSize: geo.size)
                    }
                    .overlay(alignment: .bottomTrailing) { zoomBadge }
                    .overlay(alignment: .topLeading)     { statusBadge(result: result) }
                } else {
                    emptyState
                }
            }
        }
        // Reset pan/zoom whenever a new mesh is loaded
        .onChange(of: appState.mesh?.name ?? "", perform: { _ in
            zoom = 1.0
            pan  = .zero
        })
    }

    // MARK: - Gestures

    private var magnifyGesture: some Gesture {
        MagnificationGesture()
            .updating($liveMag) { val, state, _ in state = val }
            .onEnded { zoom = clampZoom(zoom * $0) }
    }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .updating($livePan) { val, state, _ in state = val.translation }
            .onEnded {
                pan.width  += $0.translation.width
                pan.height += $0.translation.height
            }
    }

    // MARK: - Tap handler

    private func handleTap(at point: CGPoint, result: UnfoldResult, canvasSize: CGSize) {
        let xf = modelToScreen(size: canvasSize, result: result)

        // Priority 1: edge hit within 8-pt threshold → toggle fold/cut
        if let (_, ei, face) = nearestEdge(at: point, result: result, xf: xf) {
            let meshEdgeId = face.meshEdgeId(ei)
            if meshEdgeId >= 0 {
                appState.toggleEdge(meshEdgeId)
                return
            }
        }

        // Priority 2: face under tap → select
        let inv = xf.inverted()
        let modelPt = point.applying(inv)
        let mp = SIMD2<Float>(Float(modelPt.x), Float(modelPt.y))
        for face in result.faces {
            if pointInTriangle(mp, face.v0, face.v1, face.v2) {
                appState.selectedFaceId = face.faceId
                return
            }
        }
        appState.selectedFaceId = nil
    }

    // MARK: - Rendering layers

    // 1. White paper background (pattern bounding box + 5 mm padding)
    private func drawPaper(_ ctx: GraphicsContext, result: UnfoldResult, xf: CGAffineTransform) {
        let bb  = result.boundingBox
        let pad: CGFloat = 5
        let r = CGRect(x: CGFloat(bb.min.x) - pad,
                       y: CGFloat(bb.min.y) - pad,
                       width: CGFloat(bb.max.x - bb.min.x) + 2 * pad,
                       height: CGFloat(bb.max.y - bb.min.y) + 2 * pad)
            .applying(xf)
        ctx.fill(Path(roundedRect: r, cornerRadius: 4), with: .color(.white))
        ctx.stroke(Path(roundedRect: r, cornerRadius: 4),
                   with: .color(.black.opacity(0.12)), lineWidth: 1)
    }

    // 2. Grid lines at v2d.gridSizeMm intervals
    private func drawGrid(_ ctx: GraphicsContext, size: CGSize, result: UnfoldResult,
                          xf: CGAffineTransform) {
        let gMm = CGFloat(v2d.gridSizeMm)
        guard gMm > 0 else { return }
        let inv = xf.inverted()
        let tl  = CGPoint(x: 0,          y: 0).applying(inv)
        let br  = CGPoint(x: size.width,  y: size.height).applying(inv)
        let x0  = floor(min(tl.x, br.x) / gMm) * gMm
        let x1  = ceil( max(tl.x, br.x) / gMm) * gMm
        let y0  = floor(min(tl.y, br.y) / gMm) * gMm
        let y1  = ceil( max(tl.y, br.y) / gMm) * gMm

        var p = Path()
        var x = x0
        while x <= x1 {
            let sx = CGPoint(x: x, y: 0).applying(xf).x
            p.move(to: CGPoint(x: sx, y: 0)); p.addLine(to: CGPoint(x: sx, y: size.height))
            x += gMm
        }
        var y = y0
        while y <= y1 {
            let sy = CGPoint(x: 0, y: y).applying(xf).y
            p.move(to: CGPoint(x: 0, y: sy)); p.addLine(to: CGPoint(x: size.width, y: sy))
            y += gMm
        }
        ctx.stroke(p, with: .color(.gray.opacity(0.18)), lineWidth: 0.5)
    }

    // 3. Face fills
    private func drawFaces(_ ctx: GraphicsContext, result: UnfoldResult, xf: CGAffineTransform) {
        let fill = Color(hex: v2d.faceFillColor) ?? Color(red: 0.80, green: 0.88, blue: 1.0, opacity: 0.85)
        for face in result.faces {
            ctx.fill(triPath([face.v0, face.v1, face.v2], xf: xf), with: .color(fill))
        }
    }

    // 4. Edges
    private func drawEdges(_ ctx: GraphicsContext, result: UnfoldResult, xf: CGAffineTransform) {
        let foldColor  = Color(hex: v2d.foldLineColor) ?? Color(red: 0.25, green: 0.40, blue: 0.87)
        let cutColor   = Color(hex: v2d.cutLineColor)  ?? Color(red: 0.9,  green: 0.1,  blue: 0.1)
        let boundColor = Color.black.opacity(0.35)
        let foldDash   = parseDash(v2d.foldLineDash)
        let foldW      = CGFloat(v2d.foldLineWidth)
        let cutW       = CGFloat(v2d.cutLineWidth)

        var drawnFolds = Set<Int>()
        var drawnCuts  = Set<Int>()

        for face in result.faces {
            let verts = [face.v0, face.v1, face.v2]
            for ei in 0..<3 {
                let p0 = verts[ei], p1 = verts[(ei + 1) % 3]
                let mid = face.meshEdgeId(ei)
                let seg = segPath(p0, p1, xf: xf)

                if face.edgeIsFold(ei) {
                    guard mid < 0 || drawnFolds.insert(mid).inserted else { continue }
                    ctx.stroke(seg, with: .color(foldColor),
                               style: StrokeStyle(lineWidth: foldW, dash: foldDash))
                } else if !face.edgeIsBoundary(ei) {
                    guard mid < 0 || drawnCuts.insert(mid).inserted else { continue }
                    ctx.stroke(seg, with: .color(cutColor), lineWidth: cutW)
                } else {
                    ctx.stroke(seg, with: .color(boundColor), lineWidth: 0.6)
                }
            }
        }
    }

    // 5. Glue tabs
    private func drawTabs(_ ctx: GraphicsContext, result: UnfoldResult, xf: CGAffineTransform) {
        let fill   = (Color(hex: v2d.glueTabColor) ?? .green).opacity(0.30)
        let stroke = Color(red: 0.18, green: 0.49, blue: 0.20)
        for tab in result.tabs {
            guard tab.polygon.count >= 3 else { continue }
            let path = polyPath(tab.polygon, xf: xf)
            ctx.fill(path,   with: .color(fill))
            ctx.stroke(path, with: .color(stroke),
                       style: StrokeStyle(lineWidth: 0.6, dash: [4, 2]))
        }
    }

    // 6. Cut-edge pair labels (small red numbers at edge midpoints)
    private func drawCutLabels(_ ctx: GraphicsContext, result: UnfoldResult, xf: CGAffineTransform) {
        guard !result.cutEdgePairIds.isEmpty else { return }
        var drawn = Set<Int>()
        for face in result.faces {
            let verts = [face.v0, face.v1, face.v2]
            for ei in 0..<3 where !face.edgeIsFold(ei) && !face.edgeIsBoundary(ei) {
                let mid = face.meshEdgeId(ei)
                guard mid >= 0, let pairId = result.cutEdgePairIds[mid],
                      drawn.insert(mid).inserted else { continue }
                let mp = (verts[ei] + verts[(ei + 1) % 3]) / 2
                ctx.draw(
                    Text("\(pairId)")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(Color.red.opacity(0.75)),
                    at: screenPt(mp, xf: xf)
                )
            }
        }
    }

    // 7. Face ID labels (at face centroid)
    private func drawFaceLabels(_ ctx: GraphicsContext, result: UnfoldResult, xf: CGAffineTransform) {
        for face in result.faces {
            let c = (face.v0 + face.v1 + face.v2) / 3
            ctx.draw(
                Text("\(face.faceId)")
                    .font(.system(size: 9))
                    .foregroundColor(Color.black.opacity(0.45)),
                at: screenPt(c, xf: xf)
            )
        }
    }

    // 8. Fold angle labels (at fold-edge midpoints)
    private func drawFoldAngles(_ ctx: GraphicsContext, result: UnfoldResult, xf: CGAffineTransform) {
        var drawn = Set<Int>()
        let foldColor = Color(hex: v2d.foldLineColor) ?? Color(red: 0.25, green: 0.40, blue: 0.87)
        for face in result.faces {
            let verts = [face.v0, face.v1, face.v2]
            for ei in 0..<3 where face.edgeIsFold(ei) {
                let mid = face.meshEdgeId(ei)
                guard mid >= 0, let deg = result.edgeDihedralAngles[mid],
                      drawn.insert(mid).inserted else { continue }
                let mp = (verts[ei] + verts[(ei + 1) % 3]) / 2
                ctx.draw(
                    Text(String(format: "%.0f°", deg))
                        .font(.system(size: 7))
                        .foregroundColor(foldColor.opacity(0.85)),
                    at: screenPt(mp, xf: xf)
                )
            }
        }
    }

    // 9. Selection highlight (amber overlay + border)
    private func drawSelection(_ ctx: GraphicsContext, result: UnfoldResult, xf: CGAffineTransform) {
        guard let selId = appState.selectedFaceId else { return }
        for face in result.faces where face.faceId == selId {
            let path = triPath([face.v0, face.v1, face.v2], xf: xf)
            ctx.fill(path,   with: .color(Color.orange.opacity(0.35)))
            ctx.stroke(path, with: .color(Color.orange), lineWidth: 2.0)
        }
    }

    // MARK: - Coordinate transform (model mm → screen px)

    private func modelToScreen(size: CGSize, result: UnfoldResult) -> CGAffineTransform {
        let bb = result.boundingBox
        let pw = CGFloat(bb.max.x - bb.min.x); guard pw > 0 else { return .identity }
        let ph = CGFloat(bb.max.y - bb.min.y); guard ph > 0 else { return .identity }

        let fitScale   = min(size.width / pw, size.height / ph) * 0.85
        let effectZoom = fitScale * zoom * liveMag
        let cx = size.width  / 2 + pan.width  + livePan.width
        let cy = size.height / 2 + pan.height + livePan.height
        let ox = -CGFloat(bb.min.x) - pw / 2
        let oy = -CGFloat(bb.min.y) - ph / 2

        return CGAffineTransform.identity
            .translatedBy(x: cx, y: cy)
            .scaledBy(x: effectZoom, y: effectZoom)
            .translatedBy(x: ox, y: oy)
    }

    // MARK: - Hit testing

    private func nearestEdge(at pt: CGPoint, result: UnfoldResult, xf: CGAffineTransform)
        -> (faceIdx: Int, edgeIdx: Int, face: UnfoldedFace)? {
        let threshold: CGFloat = 8.0
        var bestDist = threshold
        var bestFI: Int? = nil; var bestEI: Int? = nil

        for (fi, face) in result.faces.enumerated() {
            let verts = [face.v0, face.v1, face.v2]
            for ei in 0..<3 {
                let a = screenPt(verts[ei],         xf: xf)
                let b = screenPt(verts[(ei+1) % 3], xf: xf)
                let d = ptSegDist(pt, a, b)
                if d < bestDist { bestDist = d; bestFI = fi; bestEI = ei }
            }
        }
        guard let fi = bestFI, let ei = bestEI else { return nil }
        return (fi, ei, result.faces[fi])
    }

    // MARK: - Geometry helpers

    private func screenPt(_ v: SIMD2<Float>, xf: CGAffineTransform) -> CGPoint {
        CGPoint(x: CGFloat(v.x), y: CGFloat(v.y)).applying(xf)
    }

    private func triPath(_ pts: [SIMD2<Float>], xf: CGAffineTransform) -> Path {
        polyPath(pts, xf: xf)
    }

    private func polyPath(_ pts: [SIMD2<Float>], xf: CGAffineTransform) -> Path {
        var p = Path()
        guard !pts.isEmpty else { return p }
        let cg = pts.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)).applying(xf) }
        p.move(to: cg[0]); cg.dropFirst().forEach { p.addLine(to: $0) }
        p.closeSubpath(); return p
    }

    private func segPath(_ a: SIMD2<Float>, _ b: SIMD2<Float>, xf: CGAffineTransform) -> Path {
        var p = Path()
        p.move(to: screenPt(a, xf: xf)); p.addLine(to: screenPt(b, xf: xf))
        return p
    }

    private func ptSegDist(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let ab = CGPoint(x: b.x - a.x, y: b.y - a.y)
        let ap = CGPoint(x: p.x - a.x, y: p.y - a.y)
        let len2 = ab.x * ab.x + ab.y * ab.y
        guard len2 > 1e-10 else { return hypot(ap.x, ap.y) }
        let t  = max(0, min(1, (ap.x * ab.x + ap.y * ab.y) / len2))
        return hypot(p.x - (a.x + t * ab.x), p.y - (a.y + t * ab.y))
    }

    private func pointInTriangle(_ p: SIMD2<Float>, _ a: SIMD2<Float>,
                                  _ b: SIMD2<Float>, _ c: SIMD2<Float>) -> Bool {
        func sign(_ p1: SIMD2<Float>, _ p2: SIMD2<Float>, _ p3: SIMD2<Float>) -> Float {
            (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y)
        }
        let d1 = sign(p, a, b); let d2 = sign(p, b, c); let d3 = sign(p, c, a)
        return !((d1 < 0 || d2 < 0 || d3 < 0) && (d1 > 0 || d2 > 0 || d3 > 0))
    }

    private func parseDash(_ s: String) -> [CGFloat] {
        s == "Solid" ? [] :
        s.split(separator: ",").compactMap {
            CGFloat(Double($0.trimmingCharacters(in: .whitespaces)) ?? 0)
        }
    }

    private func clampZoom(_ z: CGFloat) -> CGFloat { max(0.05, min(z, 80)) }

    // MARK: - Auxiliary views

    private var canvasBg: some View {
        (Color(hex: v2d.canvasBackground) ?? Color(white: 0.94)).ignoresSafeArea()
    }

    private var zoomBadge: some View {
        Text(String(format: "%.0f%%", zoom * liveMag * 100))
            .font(.caption2.monospacedDigit())
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 4))
            .padding(8)
    }

    @ViewBuilder
    private func statusBadge(result: UnfoldResult) -> some View {
        let hasOverlap = result.hasOverlaps
        let hasSelFace = appState.selectedFaceId != nil
        if hasOverlap || hasSelFace {
            VStack(alignment: .leading, spacing: 3) {
                if hasOverlap {
                    Label("Overlaps detected", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange).font(.caption)
                }
                if let selId = appState.selectedFaceId {
                    Text("Face \(selId) selected").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(6)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
            .padding(8)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "cube.transparent")
                .font(.system(size: 40)).foregroundStyle(.tertiary)
            Text("Load a mesh, then press ⌘U to unfold")
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Color from hex string

extension Color {
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespaces)
        if h.hasPrefix("#") { h = String(h.dropFirst()) }
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return nil }
        self.init(
            red:   Double((val >> 16) & 0xFF) / 255,
            green: Double((val >>  8) & 0xFF) / 255,
            blue:  Double( val        & 0xFF) / 255
        )
    }
}
