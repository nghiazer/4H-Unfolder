import SwiftUI
import AppKit
import CoreGraphics
import simd
// FourHUnfolderCore is compiled with -enable-testing (see Package.swift) so
// internal symbols remain accessible here without a full public API surface.
@testable import FourHUnfolderCore

// MARK: - Scroll wheel monitor (NSEvent-based, main-thread safe)
//
// SwiftUI's MagnificationGesture handles trackpad pinch but not mouse scroll
// wheel. This class installs a local event monitor that fires only when the
// mouse is inside the canvas, enabling scroll-to-zoom for mouse users.

private final class CanvasScrollMonitor: ObservableObject {
    private var monitor: Any?

    // Set by PatternCanvasView before starting.
    var isHovering  = false
    var hoverPoint: CGPoint = .zero   // canvas-local SwiftUI coords (top-left origin)
    var onScroll: ((_ delta: CGFloat, _ at: CGPoint) -> Void)?

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, self.isHovering, !event.hasPreciseScrollingDeltas || event.scrollingDeltaY != 0 else {
                return event
            }
            // For trackpad precise scrolling (hasPreciseScrollingDeltas == true) the
            // two-finger pan is already handled by DragGesture; only non-precise
            // (mouse wheel) or explicit scroll-wheel events should zoom.
            if !event.hasPreciseScrollingDeltas {
                self.onScroll?(event.scrollingDeltaY, self.hoverPoint)
            }
            return event   // don't consume — let SwiftUI keep getting the event
        }
    }

    func stop() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }

    deinit { stop() }
}

// MARK: - 2D interactive pattern canvas
//
// Rendering layers (draw order):
//  1. Paper background (white rect)
//  2. Grid lines (optional)
//  3. Face polygons (filled, optionally UV-textured)
//  4. Edges (fold=blue dashed, cut=red, boundary=gray)
//  5. Glue tabs (semi-transparent green)
//  6. Cut-edge pair numbers
//  7. Face ID labels (optional)
//  8. Fold angle labels (optional)
//  9. Selection highlight (amber overlay)
//
// Interactions:
//  - Pinch (trackpad) → zoom
//  - Drag on empty space → pan canvas
//  - Drag on a face → move that piece (non-destructive offset, cleared on re-unfold)
//  - Tap near edge (≤8pt) → toggleEdge → re-unfold
//  - Tap on face → select face (shown in 3D viewport too)

struct PatternCanvasView: View {
    @EnvironmentObject var appState: AppState

    // Leaves 15% margin when fitting the pattern to the window.
    private let fitScalePadding: CGFloat = 0.85

    @State private var zoom: CGFloat  = 1.0
    @State private var pan:  CGSize   = .zero
    @State private var basePan: CGSize = .zero       // committed pan before current drag
    @State private var dragPieceIdx: Int? = nil
    @State private var isPieceDrag: Bool = false
    @State private var prevDragTranslation: CGSize = .zero
    @GestureState private var liveMag: CGFloat = 1.0

    // Rotate-pivot state machine (mirrors C# _rotatePtPhase)
    @State private var pivotPhase: Int = 0           // 0=pick pivot, 1=pick handle, 2=rotating
    @State private var pivotPieceIdx: Int? = nil
    @State private var pivotRawPos: SIMD2<Float> = .zero   // chosen pivot vertex (raw coords)
    @State private var pivotFixedMm: SIMD2<Float> = .zero  // effective pivot pos in mm at phase 2 start
    @State private var pivotScreenPt: CGPoint = .zero      // screen position of pivot (fixed during drag)
    @State private var handleInitialAngle: Float = 0       // atan2 of handle screen pos at phase 2 start
    @State private var pieceInitialRot: Float = 0          // piece rotation at phase 2 start

    // Scroll-wheel zoom support
    @StateObject private var scrollMonitor = CanvasScrollMonitor()
    @State private var isHovering = false
    @State private var hoverPoint: CGPoint = .zero
    @State private var latestCanvasSize: CGSize = .zero

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
                        if v2d.showGlueTabs    { drawTabs(ctx, result: result, xf: xf) }
                        drawCutLabels(ctx, result: result, xf: xf)
                        if v2d.showFaceNumbers { drawFaceLabels(ctx, result: result, xf: xf) }
                        if v2d.showFoldAngles  { drawFoldAngles(ctx, result: result, xf: xf) }
                        drawSelection(ctx, result: result, xf: xf)
                        if appState.canvasMode == .rotatePivot {
                            drawVertexDots(ctx, result: result, xf: xf)
                        }
                    }
                    .gesture(magnifyGesture)
                    .gesture(makeUnifiedDragGesture(result: result, canvasSize: geo.size))
                    .onTapGesture { pt in
                        handleTap(at: pt, result: result, canvasSize: geo.size)
                    }
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let loc):
                            isHovering = true
                            hoverPoint = loc
                            scrollMonitor.isHovering = true
                            scrollMonitor.hoverPoint = loc
                        case .ended:
                            isHovering = false
                            scrollMonitor.isHovering = false
                        }
                    }
                    .overlay(alignment: .bottomTrailing) { zoomBadge }
                    .overlay(alignment: .topLeading)     { statusBadge(result: result) }
                } else {
                    emptyState
                }
            }
            .onAppear { latestCanvasSize = geo.size }
            .onChange(of: geo.size) { latestCanvasSize = $0 }
        }
        .onChange(of: appState.mesh?.name ?? "") { _ in
            zoom = 1.0; pan = .zero; basePan = .zero
        }
        .onChange(of: appState.fitToWindowTrigger) { _ in
            zoom = 1.0; pan = .zero; basePan = .zero
        }
        .onChange(of: appState.canvasMode) { _ in
            resetPivotState()
        }
        .onAppear {
            scrollMonitor.onScroll = { [weak scrollMonitor] delta, _ in
                guard scrollMonitor != nil else { return }
                handleScrollZoom(delta: delta, cursorPt: hoverPoint, canvasSize: latestCanvasSize)
            }
            scrollMonitor.start()
        }
        .onDisappear { scrollMonitor.stop() }
    }

    // MARK: - Scroll wheel zoom (mouse)
    //
    // Zoom is centered on the cursor so the model point under the cursor
    // remains stationary after the zoom is applied.
    private func handleScrollZoom(delta: CGFloat, cursorPt: CGPoint, canvasSize: CGSize) {
        // ~10% zoom per scroll tick (delta ≈ ±3 per mouse wheel click)
        let factor = exp(delta * 0.04)
        let newZoom = clampZoom(zoom * factor)
        let actualFactor = newZoom / zoom
        // Pan adjustment so cursor stays fixed:
        // cursorFromCenter = cursor - (size/2)
        // newPan = cursorFromCenter * (1 - f) + oldPan * f
        let cx = cursorPt.x - canvasSize.width  / 2
        let cy = cursorPt.y - canvasSize.height / 2
        pan = CGSize(
            width:  cx * (1 - actualFactor) + pan.width  * actualFactor,
            height: cy * (1 - actualFactor) + pan.height * actualFactor
        )
        basePan = pan
        zoom    = newZoom
    }

    // MARK: - Gestures

    private var magnifyGesture: some Gesture {
        MagnificationGesture()
            .updating($liveMag) { val, state, _ in state = val }
            .onEnded { zoom = clampZoom(zoom * $0) }
    }

    // Combined drag gesture — handles pan, piece-drag, and pivot rotation (phase 2).
    // Decision is made on first movement using hit-test of start location.
    private func makeUnifiedDragGesture(result: UnfoldResult, canvasSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { val in
                let xf    = modelToScreen(size: canvasSize, result: result)
                let scale = currentScale(canvasSize: canvasSize, result: result)

                // ── Rotate pivot phase 2: mouse drag rotates piece ──────────
                if appState.canvasMode == .rotatePivot && pivotPhase == 2,
                   let pi = pivotPieceIdx {
                    let dx = Float(val.location.x - CGFloat(pivotScreenPt.x))
                    let dy = Float(val.location.y - CGFloat(pivotScreenPt.y))
                    let currentAngle = atan2(dy, dx)
                    var delta = currentAngle - handleInitialAngle
                    while delta >  Float.pi { delta -= 2 * Float.pi }
                    while delta < -Float.pi { delta += 2 * Float.pi }

                    let newRot = pieceInitialRot + delta * 180 / Float.pi
                    appState.pieceRotations[pi] = newRot

                    // Recompute offset so pivot stays fixed in mm space
                    let faceIds = result.pieces[pi]
                    let center  = appState.pieceCenter(for: faceIds, result: result)
                    let rotated = rotate2D(pivotRawPos, around: center, degrees: newRot)
                    appState.pieceOffsets[pi] = pivotFixedMm - rotated
                    appState.recomputePagesForOffsets()
                    return
                }

                // ── Piece drag or canvas pan (editEdge / editFlap modes) ────
                if appState.canvasMode != .rotatePivot {
                    if dragPieceIdx == nil && !isPieceDrag {
                        let inv  = xf.inverted()
                        let spt  = val.startLocation.applying(inv)
                        let mp   = SIMD2<Float>(Float(spt.x), Float(spt.y))
                        var found = false
                        for face in result.faces {
                            let (ev0, ev1, ev2) = effectiveVerts(face, result: result)
                            if pointInTriangle(mp, ev0, ev1, ev2),
                               let pi = appState.pieceIndex(forFaceId: face.faceId, result: result) {
                                dragPieceIdx = pi; isPieceDrag = true
                                prevDragTranslation = .zero; found = true; break
                            }
                        }
                        if !found { isPieceDrag = false }
                    }

                    if isPieceDrag, let pi = dragPieceIdx {
                        let delta = CGSize(width:  val.translation.width  - prevDragTranslation.width,
                                          height: val.translation.height - prevDragTranslation.height)
                        let dmm = SIMD2<Float>(Float(delta.width / scale), Float(delta.height / scale))
                        appState.pieceOffsets[pi, default: .zero] += dmm
                        prevDragTranslation = val.translation
                        appState.recomputePagesForOffsets()
                    } else if !isPieceDrag {
                        pan = CGSize(width:  basePan.width  + val.translation.width,
                                     height: basePan.height + val.translation.height)
                    }
                } else {
                    // rotatePivot mode but phase != 2 → pan canvas
                    if !isPieceDrag {
                        pan = CGSize(width:  basePan.width  + val.translation.width,
                                     height: basePan.height + val.translation.height)
                    }
                }
            }
            .onEnded { val in
                if appState.canvasMode == .rotatePivot && pivotPhase == 2 {
                    // End of rotation drag → commit, stay in phase 2 for further adjustments
                    return
                }
                if !isPieceDrag {
                    pan = CGSize(width:  basePan.width  + val.translation.width,
                                 height: basePan.height + val.translation.height)
                    basePan = pan
                }
                dragPieceIdx = nil
                isPieceDrag  = false
                prevDragTranslation = .zero
            }
    }

    /// Uniform mm-per-pixel scale used by both drag conversion and modelToScreen.
    private func currentScale(canvasSize: CGSize, result: UnfoldResult) -> CGFloat {
        let bb = result.boundingBox
        let pw = CGFloat(bb.max.x - bb.min.x)
        let ph = CGFloat(bb.max.y - bb.min.y)
        let fitScale = min(canvasSize.width / max(1, pw), canvasSize.height / max(1, ph)) * fitScalePadding
        return fitScale * zoom * liveMag
    }

    // MARK: - Tap handler (mode-aware)

    private func handleTap(at point: CGPoint, result: UnfoldResult, canvasSize: CGSize) {
        let xf = modelToScreen(size: canvasSize, result: result)

        switch appState.canvasMode {

        case .editEdge:
            // Priority 1: edge hit → toggle fold/cut
            if let (_, ei, face) = nearestEdge(at: point, result: result, xf: xf) {
                let meshEdgeId = face.meshEdgeId(ei)
                if meshEdgeId >= 0 { appState.toggleEdge(meshEdgeId); return }
            }
            // Priority 2: face under tap → select
            let inv = xf.inverted()
            let mpt = point.applying(inv)
            let mp = SIMD2<Float>(Float(mpt.x), Float(mpt.y))
            for face in result.faces {
                let (ev0, ev1, ev2) = effectiveVerts(face, result: result)
                if pointInTriangle(mp, ev0, ev1, ev2) { appState.selectedFaceId = face.faceId; return }
            }
            appState.selectedFaceId = nil

        case .editFlap:
            // Apply selected flap mode to nearest edge
            guard let (_, ei, face) = nearestEdge(at: point, result: result, xf: xf) else { return }
            let meshEdgeId = face.meshEdgeId(ei)
            guard meshEdgeId >= 0 else { return }
            let isBoundary = face.edgeIsBoundary(ei)
            let mode = isBoundary ? appState.selectedBorderFlapMode : appState.selectedInnerFlapMode
            let override = mode == .default ? nil : FlapOverride(mode: mode, primaryFaceId: face.faceId)
            appState.setFlapOverride(meshEdgeId, override)

        case .rotatePivot:
            handlePivotTap(at: point, result: result, xf: xf)
        }
    }

    // MARK: - Pivot tap state machine

    private func handlePivotTap(at point: CGPoint, result: UnfoldResult, xf: CGAffineTransform) {
        let inv = xf.inverted()
        let mpt = point.applying(inv)
        let mp  = SIMD2<Float>(Float(mpt.x), Float(mpt.y))

        // Find nearest vertex dot within hit threshold (12 pt screen)
        let threshold: Float = 12 / Float(zoom)
        var bestDist = Float.infinity
        var bestVertex: SIMD2<Float>? = nil
        var bestPieceIdx: Int? = nil

        for face in result.faces {
            guard let pi = appState.pieceIndex(forFaceId: face.faceId, result: result) else { continue }
            let (ev0, ev1, ev2) = effectiveVerts(face, result: result)
            for v in [ev0, ev1, ev2] {
                let d = simd_length(v - mp)
                if d < bestDist && d < threshold { bestDist = d; bestVertex = v; bestPieceIdx = pi }
            }
        }

        guard let vertex = bestVertex, let pi = bestPieceIdx else {
            // Tap on empty area → reset pivot
            resetPivotState()
            return
        }

        // Reverse-map effective vertex back to raw coords for this piece
        let rawVertex = effectiveToRaw(vertex, pieceIdx: pi, result: result)

        if pivotPhase == 0 {
            // Phase 0 → 1: set pivot
            pivotRawPos  = rawVertex
            pivotPieceIdx = pi
            pivotPhase   = 1

        } else if pivotPhase == 1 {
            guard let pivotPi = pivotPieceIdx, pi == pivotPi else {
                // Tapped a vertex on a different piece → change pivot piece
                pivotRawPos   = rawVertex
                pivotPieceIdx = pi
                return
            }
            // Check if tapping pivot again → deselect
            let rawDistToPivot = simd_length(rawVertex - pivotRawPos)
            if rawDistToPivot < 0.1 { resetPivotState(); return }

            // Phase 1 → 2: set handle, begin rotation
            let faceIds = result.pieces[pi]
            let center  = appState.pieceCenter(for: faceIds, result: result)
            let curRot  = appState.pieceRotations[pi] ?? 0
            let off     = appState.pieceOffsets[pi] ?? .zero

            // Compute effective handle pos in screen coords
            let effHandle = rotate2D(rawVertex, around: center, degrees: curRot) + off
            let handleSc  = CGPoint(x: CGFloat(effHandle.x), y: CGFloat(effHandle.y)).applying(xf)

            // Compute effective pivot pos (for keeping it fixed during drag)
            let effPivot  = rotate2D(pivotRawPos, around: center, degrees: curRot) + off
            pivotFixedMm  = effPivot
            pivotScreenPt = CGPoint(x: CGFloat(effPivot.x), y: CGFloat(effPivot.y)).applying(xf)

            handleInitialAngle = Float(atan2(Double(handleSc.y) - Double(pivotScreenPt.y),
                                             Double(handleSc.x) - Double(pivotScreenPt.x)))
            pieceInitialRot = curRot
            pivotPhase = 2
        }
    }

    private func resetPivotState() {
        pivotPhase    = 0
        pivotPieceIdx = nil
        pivotRawPos   = .zero
        pivotFixedMm  = .zero
    }

    /// Reverse-map an effective (rendered) vertex back to its raw (pre-rotation, pre-offset) coord.
    private func effectiveToRaw(_ v: SIMD2<Float>, pieceIdx pi: Int, result: UnfoldResult) -> SIMD2<Float> {
        let off    = appState.pieceOffsets[pi] ?? .zero
        let rot    = appState.pieceRotations[pi] ?? 0
        let faceIds = result.pieces[pi]
        let center = appState.pieceCenter(for: faceIds, result: result)
        // v = rotate2D(raw, center, rot) + off → raw = rotate2D(v - off - center, _, -rot) + center
        let vLocal = (v - off) - center
        let rad    = -rot * Float.pi / 180
        let (cosR, sinR) = (cos(rad), sin(rad))
        return center + SIMD2(vLocal.x*cosR - vLocal.y*sinR, vLocal.x*sinR + vLocal.y*cosR)
    }

    // MARK: - Rendering layers

    // 1. Page grid — draw pages based on appState.pagesWide / pagesTall.
    //    Page count is fixed by autoArrange(); dragging pieces does NOT add pages.
    //    Pages are separated by pageSep (= margin) and start at model origin (0,0).
    private func drawPaper(_ ctx: GraphicsContext, result: UnfoldResult, xf: CGAffineTransform) {
        let paper   = appState.settings.print.effectivePaper
        let pageW   = CGFloat(paper.widthMm)
        let pageH   = CGFloat(paper.heightMm)
        let pageSep = CGFloat(appState.settings.print.marginMm)

        let numCols = max(1, appState.pagesWide)
        let numRows = max(1, appState.pagesTall)

        // Shadow pass
        for row in 0..<numRows {
            for col in 0..<numCols {
                let x = CGFloat(col) * (pageW + pageSep)
                let y = CGFloat(row) * (pageH + pageSep)
                let shadow = CGRect(x: x, y: y, width: pageW, height: pageH)
                    .applying(xf).offsetBy(dx: 2, dy: 2)
                ctx.fill(Path(shadow), with: .color(.black.opacity(0.08)))
            }
        }

        // Page fill + border + label
        for row in 0..<numRows {
            for col in 0..<numCols {
                let x = CGFloat(col) * (pageW + pageSep)
                let y = CGFloat(row) * (pageH + pageSep)
                let pageRect = CGRect(x: x, y: y, width: pageW, height: pageH).applying(xf)
                ctx.fill(Path(pageRect), with: .color(.white))
                ctx.stroke(Path(pageRect), with: .color(.black.opacity(0.18)), lineWidth: 0.7)

                if numCols * numRows > 1 {
                    let pageNum = row * numCols + col + 1
                    ctx.draw(
                        Text("p\(pageNum)")
                            .font(.system(size: 9))
                            .foregroundColor(Color.black.opacity(0.25)),
                        at: CGPoint(x: pageRect.minX + 14, y: pageRect.minY + 6)
                    )
                }
            }
        }
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

    // 3. Face fills — textured when UV data + texture available, solid otherwise
    private func drawFaces(_ ctx: GraphicsContext, result: UnfoldResult, xf: CGAffineTransform) {
        let solidFill = Color(hex: v2d.faceFillColor) ?? Color(red: 0.80, green: 0.88, blue: 1.0, opacity: 0.85)
        let mesh = appState.mesh

        for face in result.faces {
            let (ev0, ev1, ev2) = effectiveVerts(face, result: result)
            if v2d.showTexture,
               let mesh,
               face.materialId >= 0,
               let img = appState.textureCache[face.materialId],
               face.faceId < mesh.faceUVs.count,
               !mesh.uvs.isEmpty {
                let faceUV = mesh.faceUVs[face.faceId]
                func safeUV(_ i: Int) -> SIMD2<Float> { i < mesh.uvs.count ? mesh.uvs[i] : .zero }
                let uvA = safeUV(faceUV.ua), uvB = safeUV(faceUV.ub), uvC = safeUV(faceUV.uc)
                let sa = screenPt(ev0, xf: xf)
                let sb = screenPt(ev1, xf: xf)
                let sc = screenPt(ev2, xf: xf)
                ctx.withCGContext { cg in
                    drawTexturedTriangle(cg, image: img,
                                         uvA: uvA, uvB: uvB, uvC: uvC,
                                         sa: sa, sb: sb, sc: sc)
                }
            } else {
                ctx.fill(triPath([ev0, ev1, ev2], xf: xf), with: .color(solidFill))
            }
        }
    }

    // Draw a CGImage affine-mapped onto a triangle in screen space.
    private func drawTexturedTriangle(
        _ cg: CGContext,
        image: CGImage,
        uvA: SIMD2<Float>, uvB: SIMD2<Float>, uvC: SIMD2<Float>,
        sa: CGPoint, sb: CGPoint, sc: CGPoint
    ) {
        let w = CGFloat(image.width), h = CGFloat(image.height)
        let ta = CGPoint(x: CGFloat(uvA.x) * w, y: CGFloat(uvA.y) * h)
        let tb = CGPoint(x: CGFloat(uvB.x) * w, y: CGFloat(uvB.y) * h)
        let tc = CGPoint(x: CGFloat(uvC.x) * w, y: CGFloat(uvC.y) * h)

        guard let xf = affineFromTriangle(src: (ta, tb, tc), dst: (sa, sb, sc)) else {
            cg.saveGState()
            cg.setFillColor(CGColor(red: 0.8, green: 0.88, blue: 1.0, alpha: 0.85))
            cg.addPath(cgTriangle(sa, sb, sc)); cg.fillPath()
            cg.restoreGState()
            return
        }

        // SwiftUI withCGContext provides a top-left-origin context (y increases downward).
        // UVs stored in mesh.uvs are already in top-left convention (1-v_obj), so ta.y is
        // already the correct image pixel coordinate. No extra Y-flip is needed — applying
        // one would double-flip and produce upside-down textures.
        cg.saveGState()
        cg.addPath(cgTriangle(sa, sb, sc))
        cg.clip()
        cg.concatenate(xf)
        cg.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        cg.restoreGState()
    }

    private func cgTriangle(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> CGPath {
        let p = CGMutablePath()
        p.move(to: a); p.addLine(to: b); p.addLine(to: c); p.closeSubpath()
        return p
    }

    private func affineFromTriangle(
        src: (CGPoint, CGPoint, CGPoint),
        dst: (CGPoint, CGPoint, CGPoint)
    ) -> CGAffineTransform? {
        let (u0, v0) = (src.0.x, src.0.y)
        let (u1, v1) = (src.1.x, src.1.y)
        let (u2, v2) = (src.2.x, src.2.y)
        let det = u0 * (v1 - v2) - v0 * (u1 - u2) + (u1 * v2 - u2 * v1)
        guard abs(det) > 1e-5 else { return nil }
        let (x0, y0) = (dst.0.x, dst.0.y)
        let (x1, y1) = (dst.1.x, dst.1.y)
        let (x2, y2) = (dst.2.x, dst.2.y)
        let a  = ((v1 - v2) * x0 + (v2 - v0) * x1 + (v0 - v1) * x2) / det
        let b  = ((u2 - u1) * x0 + (u0 - u2) * x1 + (u1 - u0) * x2) / det
        let tx = ((u1 * v2 - u2 * v1) * x0 + (u2 * v0 - u0 * v2) * x1 + (u0 * v1 - u1 * v0) * x2) / det
        let c  = ((v1 - v2) * y0 + (v2 - v0) * y1 + (v0 - v1) * y2) / det
        let d  = ((u2 - u1) * y0 + (u0 - u2) * y1 + (u1 - u0) * y2) / det
        let ty = ((u1 * v2 - u2 * v1) * y0 + (u2 * v0 - u0 * v2) * y1 + (u0 * v1 - u1 * v0) * y2) / det
        return CGAffineTransform(a: a, b: c, c: b, d: d, tx: tx, ty: ty)
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
            let (ev0, ev1, ev2) = effectiveVerts(face, result: result)
            let verts = [ev0, ev1, ev2]
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
            let poly = effectiveTabPolygon(tab, result: result)
            guard poly.count >= 3 else { continue }
            let path = polyPath(poly, xf: xf)
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
            let (ev0, ev1, ev2) = effectiveVerts(face, result: result)
            let verts = [ev0, ev1, ev2]
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
            let (ev0, ev1, ev2) = effectiveVerts(face, result: result)
            let c = (ev0 + ev1 + ev2) / 3
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
            let (ev0, ev1, ev2) = effectiveVerts(face, result: result)
            let verts = [ev0, ev1, ev2]
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
            let (ev0, ev1, ev2) = effectiveVerts(face, result: result)
            let path = triPath([ev0, ev1, ev2], xf: xf)
            ctx.fill(path,   with: .color(Color.orange.opacity(0.35)))
            ctx.stroke(path, with: .color(Color.orange), lineWidth: 2.0)
        }
    }

    // MARK: - Coordinate transform (model mm → screen px)

    private func modelToScreen(size: CGSize, result: UnfoldResult) -> CGAffineTransform {
        let bb = result.boundingBox
        let pw = CGFloat(bb.max.x - bb.min.x); guard pw > 0 else { return .identity }
        let ph = CGFloat(bb.max.y - bb.min.y); guard ph > 0 else { return .identity }

        let fitScale   = min(size.width / pw, size.height / ph) * fitScalePadding
        let effectZoom = fitScale * zoom * liveMag
        let cx = size.width  / 2 + pan.width
        let cy = size.height / 2 + pan.height
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
            let (ev0, ev1, ev2) = effectiveVerts(face, result: result)
            let verts = [ev0, ev1, ev2]
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

    // MARK: - Effective vertex helpers (apply per-piece rotation then offset)

    private func effectiveVerts(_ face: UnfoldedFace, result: UnfoldResult)
        -> (SIMD2<Float>, SIMD2<Float>, SIMD2<Float>) {
        let off = appState.offset(forFaceId: face.faceId, result: result)
        let rot = appState.rotation(forFaceId: face.faceId, result: result)
        guard abs(rot) > 0.001,
              let pi = appState.pieceIndex(forFaceId: face.faceId, result: result),
              pi < result.pieces.count else {
            return (face.v0 + off, face.v1 + off, face.v2 + off)
        }
        let center = appState.pieceCenter(for: result.pieces[pi], result: result)
        return (
            rotate2D(face.v0, around: center, degrees: rot) + off,
            rotate2D(face.v1, around: center, degrees: rot) + off,
            rotate2D(face.v2, around: center, degrees: rot) + off
        )
    }

    private func effectiveTabPolygon(_ tab: GlueTab, result: UnfoldResult) -> [SIMD2<Float>] {
        let off = appState.offset(forFaceId: tab.faceId, result: result)
        let rot = appState.rotation(forFaceId: tab.faceId, result: result)
        guard abs(rot) > 0.001,
              let pi = appState.pieceIndex(forFaceId: tab.faceId, result: result),
              pi < result.pieces.count else {
            return tab.polygon.map { $0 + off }
        }
        let center = appState.pieceCenter(for: result.pieces[pi], result: result)
        return tab.polygon.map { rotate2D($0, around: center, degrees: rot) + off }
    }

    // MARK: - Vertex dots (rotate-pivot mode)

    private func drawVertexDots(_ ctx: GraphicsContext, result: UnfoldResult, xf: CGAffineTransform) {
        let dotR: CGFloat = 5
        var seen = Set<SIMD2<Int32>>()

        for face in result.faces {
            guard let pi = appState.pieceIndex(forFaceId: face.faceId, result: result) else { continue }
            let (ev0, ev1, ev2) = effectiveVerts(face, result: result)
            for ev in [ev0, ev1, ev2] {
                let key = SIMD2<Int32>(Int32(ev.x * 100), Int32(ev.y * 100))
                guard seen.insert(key).inserted else { continue }

                let sc  = screenPt(ev, xf: xf)
                let r   = CGRect(x: sc.x - dotR, y: sc.y - dotR, width: dotR*2, height: dotR*2)
                let dot = Path(ellipseIn: r)

                // Color: red = selected pivot, yellow = hover, white = default
                let isHovered = hypot(hoverPoint.x - sc.x, hoverPoint.y - sc.y) < dotR * 2

                let isPivot: Bool = {
                    guard pivotPhase >= 1, let pivotPi = pivotPieceIdx, pivotPi == pi else { return false }
                    let rawEv = effectiveToRaw(ev, pieceIdx: pi, result: result)
                    return simd_length(rawEv - pivotRawPos) < 0.1
                }()

                let fill: Color = isPivot ? .red : (isHovered ? Color(red: 1, green: 0.87, blue: 0.3) : Color.white.opacity(0.85))
                let stroke: Color = isPivot ? Color(red: 0.7, green: 0, blue: 0) : Color.gray.opacity(0.6)

                ctx.fill(dot, with: .color(fill))
                ctx.stroke(dot, with: .color(stroke), lineWidth: 1)
            }
        }
    }

    // MARK: - Rotation math helper

    private func rotate2D(_ v: SIMD2<Float>, around center: SIMD2<Float>, degrees: Float) -> SIMD2<Float> {
        let rad = degrees * Float.pi / 180
        let (cosR, sinR) = (cos(rad), sin(rad))
        let d = v - center
        return center + SIMD2(d.x*cosR - d.y*sinR, d.x*sinR + d.y*cosR)
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
