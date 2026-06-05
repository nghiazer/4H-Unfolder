import SwiftUI
import simd

// MARK: - 2D unfolded pattern canvas
// Renders UnfoldedFaces + GlueTabs via SwiftUI Canvas.
// Phase 6 will add: edge interaction, piece drag, lasso, texture mapping, grid.

struct PatternCanvasView: View {
    let result: UnfoldResult?
    let showEdgeLabels: Bool

    @State private var zoom: CGFloat = 1.0
    @State private var pan:  CGSize  = .zero
    @GestureState private var livePan: CGSize = .zero

    var body: some View {
        ZStack {
            Color(white: 0.96)

            if let result {
                Canvas { ctx, size in
                    let xf = viewTransform(size: size, result: result)
                    drawFaces(ctx, result: result, transform: xf)
                    drawEdges(ctx, result: result, transform: xf)
                    drawTabs(ctx,  result: result, transform: xf)
                }
                .gesture(MagnificationGesture()
                    .onChanged { zoom = max(0.05, min($0, 80)) })
                .gesture(DragGesture(minimumDistance: 1)
                    .updating($livePan) { v, state, _ in state = v.translation }
                    .onEnded { pan.width += $0.translation.width; pan.height += $0.translation.height })
                .overlay(alignment: .bottomTrailing) { zoomLabel }
            } else {
                emptyState
            }
        }
    }

    // MARK: - Drawing

    private func drawFaces(_ ctx: GraphicsContext, result: UnfoldResult, transform: CGAffineTransform) {
        let fillColor = Color(red: 0.80, green: 0.88, blue: 1.0, opacity: 0.85)
        let selectedColor = Color(red: 0.2, green: 0.5, blue: 1.0, opacity: 0.55)

        for face in result.faces {
            let path = triangle([face.v0, face.v1, face.v2], transform: transform)
            ctx.fill(path, with: .color(fillColor))
            // Selection overlay will be wired in Phase 6
            _ = selectedColor
        }
    }

    private func drawEdges(_ ctx: GraphicsContext, result: UnfoldResult, transform: CGAffineTransform) {
        var drawnFolds = Set<Int>()
        var drawnCuts  = Set<Int>()

        for face in result.faces {
            let verts = [face.v0, face.v1, face.v2]
            for ei in 0..<3 {
                let p0 = verts[ei], p1 = verts[(ei + 1) % 3]
                let mid = face.meshEdgeId(ei)

                if face.edgeIsFold(ei) {
                    guard mid < 0 || drawnFolds.insert(mid).inserted else { continue }
                    let path = segment(p0, p1, transform: transform)
                    ctx.stroke(path, with: .color(Color(red: 0.25, green: 0.40, blue: 0.87)),
                               style: StrokeStyle(lineWidth: 1.0, dash: [4, 2]))
                } else if !face.edgeIsBoundary(ei) {
                    guard mid < 0 || drawnCuts.insert(mid).inserted else { continue }
                    let path = segment(p0, p1, transform: transform)
                    ctx.stroke(path, with: .color(Color(red: 0.9, green: 0.1, blue: 0.1)),
                               lineWidth: 1.0)
                } else {
                    let path = segment(p0, p1, transform: transform)
                    ctx.stroke(path, with: .color(.black.opacity(0.6)), lineWidth: 0.6)
                }
            }
        }
    }

    private func drawTabs(_ ctx: GraphicsContext, result: UnfoldResult, transform: CGAffineTransform) {
        for tab in result.tabs {
            guard tab.polygon.count >= 3 else { continue }
            let path = polygon(tab.polygon, transform: transform)
            ctx.fill(path,   with: .color(.green.opacity(0.25)))
            ctx.stroke(path, with: .color(Color(red: 0.18, green: 0.49, blue: 0.20)),
                       style: StrokeStyle(lineWidth: 0.6, dash: [4, 2]))
        }
    }

    // MARK: - Path helpers

    private func triangle(_ pts: [SIMD2<Float>], transform: CGAffineTransform) -> Path {
        polygon(pts, transform: transform)
    }

    private func polygon(_ pts: [SIMD2<Float>], transform: CGAffineTransform) -> Path {
        var p = Path()
        let cg = pts.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)).applying(transform) }
        p.move(to: cg[0])
        cg.dropFirst().forEach { p.addLine(to: $0) }
        p.closeSubpath()
        return p
    }

    private func segment(_ a: SIMD2<Float>, _ b: SIMD2<Float>, transform: CGAffineTransform) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: CGFloat(a.x), y: CGFloat(a.y)).applying(transform))
        p.addLine(to: CGPoint(x: CGFloat(b.x), y: CGFloat(b.y)).applying(transform))
        return p
    }

    // MARK: - View transform (model mm → screen px)

    private func viewTransform(size: CGSize, result: UnfoldResult) -> CGAffineTransform {
        let bb = result.boundingBox
        let pw = CGFloat(bb.max.x - bb.min.x); guard pw > 0 else { return .identity }
        let ph = CGFloat(bb.max.y - bb.min.y); guard ph > 0 else { return .identity }

        let fit   = min(size.width / pw, size.height / ph) * 0.90
        let total = fit * zoom
        let cx    = size.width  / 2 + pan.width  + livePan.width
        let cy    = size.height / 2 + pan.height + livePan.height
        let ox    = CGFloat(-bb.min.x - (bb.max.x - bb.min.x) / 2)
        let oy    = CGFloat(-bb.min.y - (bb.max.y - bb.min.y) / 2)

        return CGAffineTransform.identity
            .translatedBy(x: cx, y: cy)
            .scaledBy(x: total, y: total)
            .translatedBy(x: ox, y: oy)
    }

    // MARK: - Aux views

    private var zoomLabel: some View {
        Text(String(format: "%.0f%%", zoom * 100))
            .font(.caption2.monospacedDigit())
            .padding(4)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 4))
            .padding(8)
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
