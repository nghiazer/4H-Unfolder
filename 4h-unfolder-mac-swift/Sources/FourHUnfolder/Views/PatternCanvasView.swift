import SwiftUI
import simd

// 2D unfolded pattern canvas — renders all UnfoldedFaces and GlueTabs.
// Supports pinch-to-zoom and drag-to-pan.
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
                    drawTabs(ctx,  result: result, transform: xf)
                }
                .gesture(
                    MagnificationGesture()
                        .onChanged { zoom = max(0.05, min($0, 80)) }
                )
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .updating($livePan) { v, state, _ in state = v.translation }
                        .onEnded { pan.width += $0.translation.width; pan.height += $0.translation.height }
                )
                .overlay(alignment: .bottomTrailing) {
                    zoomLabel
                }
            } else {
                emptyState
            }
        }
        .background(Color(white: 0.96))
    }

    // MARK: - Drawing

    private func drawFaces(_ ctx: GraphicsContext, result: UnfoldResult, transform: CGAffineTransform) {
        for face in result.faces {
            guard face.vertices2D.count >= 3 else { continue }
            let path = polygon(face.vertices2D, transform: transform)
            let fill: Color = face.isSelected
                ? Color(red: 0.2, green: 0.5, blue: 1.0, opacity: 0.55)
                : Color(red:  Double(face.color.x),
                        green: Double(face.color.y),
                        blue:  Double(face.color.z),
                        opacity: 0.85)
            ctx.fill(path, with: .color(fill))
            ctx.stroke(path, with: .color(.black.opacity(0.75)), lineWidth: 0.8)
        }
    }

    private func drawTabs(_ ctx: GraphicsContext, result: UnfoldResult, transform: CGAffineTransform) {
        for tab in result.tabs {
            guard tab.polygon.count >= 3 else { continue }
            let path = polygon(tab.polygon, transform: transform)
            ctx.fill(path, with: .color(.gray.opacity(0.30)))
            ctx.stroke(path, with: .color(.black.opacity(0.50)),
                       lineWidth: 0.6,
                       style: StrokeStyle(lineWidth: 0.6, dash: [4, 2]))
        }
    }

    private func polygon(_ pts: [SIMD2<Float>], transform: CGAffineTransform) -> Path {
        var p = Path()
        let cg = pts.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)).applying(transform) }
        p.move(to: cg[0])
        cg.dropFirst().forEach { p.addLine(to: $0) }
        p.closeSubpath()
        return p
    }

    // MARK: - Transform

    private func viewTransform(size: CGSize, result: UnfoldResult) -> CGAffineTransform {
        let pw = CGFloat(result.pageWidth);  guard pw > 0 else { return .identity }
        let ph = CGFloat(result.pageHeight); guard ph > 0 else { return .identity }

        let fit   = min(size.width / pw, size.height / ph) * 0.90
        let total = fit * zoom
        let cx    = size.width  / 2 + pan.width  + livePan.width
        let cy    = size.height / 2 + pan.height + livePan.height
        let ox    = CGFloat(-result.boundingBox.min.x - result.pageWidth  / 2)
        let oy    = CGFloat(-result.boundingBox.min.y - result.pageHeight / 2)

        return CGAffineTransform.identity
            .translatedBy(x: cx, y: cy)
            .scaledBy(x: total, y: total)
            .translatedBy(x: ox, y: oy)
    }

    // MARK: - Auxiliary views

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
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("Load a mesh, then press ⌘U to unfold")
                .foregroundStyle(.secondary)
        }
    }
}
