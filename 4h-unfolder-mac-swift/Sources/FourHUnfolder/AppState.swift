import AppKit
import SwiftUI
import CoreGraphics
import ImageIO
import simd
// FourHUnfolderCore is compiled with -enable-testing (see Package.swift) so
// internal symbols remain accessible here without a full public API surface.
@testable import FourHUnfolderCore

// MARK: - Canvas interaction mode

enum CanvasMode: Equatable {
    case editEdge     // default: click edges to toggle fold/cut
    case editFlap     // click edges to apply selected FlapMode override
    case rotatePivot  // click vertices to pick pivot → handle → live rotate
}

@MainActor
final class AppState: ObservableObject {
    @Published var mesh: Mesh?
    @Published var unfoldResult: UnfoldResult?
    @Published var edgeOverrides: [Int: EdgeType] = [:]
    @Published var flapOverrides: [Int: FlapOverride] = [:]
    @Published var settings: AppSettings = .load()
    @Published var selectedFaceId: Int? = nil
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var fitToWindowTrigger: Int = 0
    @Published var textureCache: [Int: CGImage] = [:]
    /// Piece-index (index in result.pieces) → cumulative drag offset in mm
    @Published var pieceOffsets: [Int: SIMD2<Float>] = [:]
    /// Piece-index → rotation in degrees around piece bbox center
    @Published var pieceRotations: [Int: Float] = [:]
    /// Scale factor used for the last unfold (mm per model unit). Set by UnfoldSetupSheet.
    @Published var meshScaleMmPerUnit: Float = 1.0
    /// Controls whether the Unfold Setup sheet is visible.
    @Published var showUnfoldSetup = false
    /// Piece indices (index in result.pieces) that are currently selected in the 2D canvas.
    @Published var selectedPieceIndices: Set<Int> = []
    /// minFaceId of piece → userGroupId. Stable key across re-unfold; persisted in .4hu.
    @Published var userGroups: [Int: Int] = [:]
    /// Counter for assigning new user group IDs.
    @Published var nextUserGroupId: Int = 1
    /// Number of page columns in the current layout (set by autoArrange).
    @Published var pagesWide: Int = 1
    /// Number of page rows in the current layout (set by autoArrange).
    @Published var pagesTall: Int = 1
    /// Active canvas interaction mode.
    @Published var canvasMode: CanvasMode = .editEdge
    /// Selected FlapMode for inner (cut) edges in editFlap mode.
    @Published var selectedInnerFlapMode: FlapMode = .default
    /// Selected FlapMode for border edges in editFlap mode.
    @Published var selectedBorderFlapMode: FlapMode = .default

    /// URL of the file the current mesh was loaded from (needed for project save).
    private(set) var sourceMeshURL: URL?

    private let loader       = MeshLoaderFactory()
    private let unfoldSvc    = UnfoldService()
    private let serializer   = ProjectSerializer()

    // MARK: - Undo / Redo (snapshots of overrides only)

    private typealias OverrideSnapshot = (edges: [Int: EdgeType], flaps: [Int: FlapOverride])
    private var undoStack: [OverrideSnapshot] = []
    private var redoStack: [OverrideSnapshot] = []

    func pushUndo() {
        undoStack.append((edgeOverrides, flapOverrides))
        redoStack.removeAll()
    }

    func undo() {
        guard let snap = undoStack.popLast() else { return }
        redoStack.append((edgeOverrides, flapOverrides))
        edgeOverrides = snap.edges
        flapOverrides = snap.flaps
        Task { await unfold(); autoArrange() }
    }

    func redo() {
        guard let snap = redoStack.popLast() else { return }
        undoStack.append((edgeOverrides, flapOverrides))
        edgeOverrides = snap.edges
        flapOverrides = snap.flaps
        Task { await unfold(); autoArrange() }
    }

    // MARK: - Edge / flap overrides

    func toggleEdge(_ meshEdgeId: Int) {
        guard let mesh, meshEdgeId < mesh.edges.count else { return }
        pushUndo()
        let current = edgeOverrides[meshEdgeId] ?? mesh.edges[meshEdgeId].type
        edgeOverrides[meshEdgeId] = (current == .fold) ? .cut : .fold
        Task { await unfold(); autoArrange() }
    }

    func setFlapOverride(_ meshEdgeId: Int, _ override: FlapOverride?) {
        pushUndo()
        flapOverrides[meshEdgeId] = override
        Task { await unfold(); autoArrange() }
    }

    // MARK: - Piece selection & grouping

    func clearSelection() { selectedPieceIndices = [] }

    /// Assigns a new shared group ID to all currently selected pieces.
    func groupSelected() {
        guard let result = unfoldResult, selectedPieceIndices.count >= 2 else { return }
        let gid = nextUserGroupId; nextUserGroupId += 1
        for pi in selectedPieceIndices {
            guard pi < result.pieces.count, let minFid = result.pieces[pi].min() else { continue }
            userGroups[minFid] = gid
        }
    }

    /// Removes the group assignment from all currently selected pieces.
    func ungroupSelected() {
        guard let result = unfoldResult else { return }
        for pi in selectedPieceIndices {
            guard pi < result.pieces.count, let minFid = result.pieces[pi].min() else { continue }
            userGroups.removeValue(forKey: minFid)
        }
    }

    /// Returns the userGroupId for a piece at the given index (keyed by its minFaceId).
    func userGroupId(forPieceIdx pi: Int, result: UnfoldResult) -> Int? {
        guard pi < result.pieces.count, let minFid = result.pieces[pi].min() else { return nil }
        return userGroups[minFid]
    }

    // MARK: - Align selected pieces (GĐ3.3 parity port from Windows MainViewModel.AlignSelected)

    /// Aligns the bounding boxes of the ≥2 currently-selected pieces to their common
    /// left/right/top/bottom edge or horizontal/vertical center — only ever adjusts
    /// `pieceOffsets` (rotation is left untouched), matching Windows' equivalent toolbar action.
    /// Not undo-able: `pushUndo`/`undo` only snapshot edge/flap overrides here, not piece
    /// positions — same pre-existing limitation as the manual piece-drag gesture below.
    /// Geometry lives in PieceAligner (FourHUnfolderCore) so it's unit-testable — see
    /// PieceAlignerTests.swift.
    func alignSelectedPieces(_ mode: PieceAlignMode) {
        guard let result = unfoldResult else { return }
        let deltas = PieceAligner.alignmentDeltas(
            result: result,
            selected: Array(selectedPieceIndices),
            pieceOffsets: pieceOffsets,
            pieceRotations: pieceRotations,
            mode: mode
        )
        guard !deltas.isEmpty else { return }
        for (pi, d) in deltas {
            pieceOffsets[pi] = (pieceOffsets[pi] ?? .zero) + d
        }
    }

    func clearEdgeOverrides() {
        pushUndo()
        edgeOverrides.removeAll()
        flapOverrides.removeAll()
        Task { await unfold(); autoArrange() }
    }

    // MARK: - Smart edge operations (editEdge mode — position-aware)

    /// Fold → cut (disjoin). After unfold, keeps all pieces at their old display
    /// positions and nudges the newly separated piece away slightly.
    func splitEdge(_ meshEdgeId: Int) {
        guard let mesh, meshEdgeId < mesh.edges.count else { return }
        guard let result = unfoldResult else { return }
        pushUndo()
        let oldCentroids   = captureEffectiveCentroids(result: result)
        let oldFaceSets    = result.pieces.map { Set($0) }
        edgeOverrides[meshEdgeId] = .cut
        Task {
            await unfold()
            repositionAfterSplit(oldFaceSets: oldFaceSets, oldCentroids: oldCentroids)
        }
    }

    /// Cut → fold (join). After unfold, keeps the merged piece near the anchor
    /// piece's old display position (anchor = the piece the user wants to stay put).
    func joinEdge(_ meshEdgeId: Int, anchorFaceId: Int) {
        guard let mesh, meshEdgeId < mesh.edges.count else { return }
        guard let result = unfoldResult else { return }
        pushUndo()
        let oldCentroids = captureEffectiveCentroids(result: result)
        let oldFaceSets  = result.pieces.map { Set($0) }
        edgeOverrides[meshEdgeId] = .fold
        Task {
            await unfold()
            repositionAfterJoin(oldFaceSets: oldFaceSets, oldCentroids: oldCentroids,
                                anchorFaceId: anchorFaceId)
        }
    }

    /// GĐ3.3: batch version of joinEdge — converts the whole chain of cut edges transitively
    /// connected to meshEdgeId (via shared 2D vertices) to Fold in one action. Mirrors Windows'
    /// MainViewModel.JoinEdgeGroup (triggered there from a right-click canvas context menu; here
    /// from ⌥-click on a cut edge in Edit Edges mode — this SwiftUI canvas draws all edges into
    /// one Canvas view via manual hit-testing rather than discrete per-edge elements, so a
    /// native per-edge right-click context menu isn't a small addition; a modifier-click is
    /// consistent with the existing Shift-for-additive-select convention on this same canvas).
    /// Unlike the single-edge joinEdge, this does not do the smart anchor-position reposition
    /// (a merge of several original pieces has no single natural anchor) — matches Windows, which
    /// also just re-unfolds plainly for the group case.
    func joinEdgeGroup(_ meshEdgeId: Int) {
        guard let mesh, meshEdgeId < mesh.edges.count else { return }
        guard let result = unfoldResult else { return }
        let group = EdgeGroupFinder.findAdjacentCutEdgeGroup(startEdgeId: meshEdgeId, result: result)
        guard !group.isEmpty else { return }
        pushUndo()
        for eid in group { edgeOverrides[eid] = .fold }
        Task { await unfold(); autoArrange() }
    }

    // MARK: - Reposition helpers

    /// Effective centroid (raw face positions + pieceOffset) per old piece index.
    private func captureEffectiveCentroids(result: UnfoldResult) -> [SIMD2<Float>] {
        result.pieces.enumerated().map { (pi, faceIds) in
            let faceSet = Set(faceIds)
            let off = pieceOffsets[pi] ?? .zero
            let faces = result.faces.filter { faceSet.contains($0.faceId) }
            guard !faces.isEmpty else { return .zero }
            let xs = faces.flatMap { [$0.v0.x + off.x, $0.v1.x + off.x, $0.v2.x + off.x] }
            let ys = faces.flatMap { [$0.v0.y + off.y, $0.v1.y + off.y, $0.v2.y + off.y] }
            return SIMD2((xs.min()! + xs.max()!) / 2, (ys.min()! + ys.max()!) / 2)
        }
    }

    /// Bbox centroid of a piece's raw face positions (no offset).
    private func rawCentroid(forPieceIdx pi: Int, result: UnfoldResult) -> SIMD2<Float> {
        let faceSet = Set(result.pieces[pi])
        let faces = result.faces.filter { faceSet.contains($0.faceId) }
        guard !faces.isEmpty else { return .zero }
        let xs = faces.flatMap { [$0.v0.x, $0.v1.x, $0.v2.x] }
        let ys = faces.flatMap { [$0.v0.y, $0.v1.y, $0.v2.y] }
        return SIMD2((xs.min()! + xs.max()!) / 2, (ys.min()! + ys.max()!) / 2)
    }

    private func repositionAfterSplit(oldFaceSets: [Set<Int>], oldCentroids: [SIMD2<Float>]) {
        guard let result = unfoldResult else { return }
        for (newPi, newFaceIds) in result.pieces.enumerated() {
            let newSet  = Set(newFaceIds)
            let newRaw  = rawCentroid(forPieceIdx: newPi, result: result)

            // Find best-matching old piece (most shared faces)
            var bestOldPi = 0; var bestShared = 0
            for (oldPi, oldSet) in oldFaceSets.enumerated() {
                let shared = newSet.intersection(oldSet).count
                if shared > bestShared { bestShared = shared; bestOldPi = oldPi }
            }

            let targetCent = oldCentroids[bestOldPi]
            let oldSet = oldFaceSets[bestOldPi]

            // "Minor" split: this piece is a sub-piece AND another new piece matched
            // the same old piece with even more faces (i.e. THIS is the separated chunk).
            let isMinorSplit = newSet.count < oldSet.count &&
                result.pieces.enumerated().contains { (otherPi, otherIds) in
                    otherPi != newPi && Set(otherIds).intersection(oldSet).count > bestShared
                }

            if isMinorSplit {
                // Push the separated piece 30mm right+down so it's visibly distinct
                pieceOffsets[newPi] = targetCent + SIMD2<Float>(30, 30) - newRaw
            } else {
                pieceOffsets[newPi] = targetCent - newRaw
            }
        }
        recomputePagesForOffsets()
    }

    private func repositionAfterJoin(oldFaceSets: [Set<Int>], oldCentroids: [SIMD2<Float>],
                                     anchorFaceId: Int) {
        guard let result = unfoldResult else { return }
        // Find old piece that contained the anchor face → its centroid is the target
        let anchorOldPi = oldFaceSets.firstIndex { $0.contains(anchorFaceId) } ?? 0
        let anchorTargetCent = oldCentroids[anchorOldPi]

        for (newPi, newFaceIds) in result.pieces.enumerated() {
            let newSet = Set(newFaceIds)
            let newRaw = rawCentroid(forPieceIdx: newPi, result: result)

            if newSet.contains(anchorFaceId) {
                // Merged piece: snap to anchor's old position
                pieceOffsets[newPi] = anchorTargetCent - newRaw
            } else {
                // Unrelated piece: restore to its own old position
                var bestOldPi = 0; var bestShared = 0
                for (oldPi, oldSet) in oldFaceSets.enumerated() {
                    let shared = newSet.intersection(oldSet).count
                    if shared > bestShared { bestShared = shared; bestOldPi = oldPi }
                }
                pieceOffsets[newPi] = oldCentroids[bestOldPi] - newRaw
            }
        }
        recomputePagesForOffsets()
    }

    /// Cycles through faces one at a time. Repeated calls advance the selection.
    func selectAll() {
        guard let result = unfoldResult, !result.faces.isEmpty else { return }
        if let sel = selectedFaceId,
           let idx = result.faces.firstIndex(where: { $0.faceId == sel }),
           idx + 1 < result.faces.count {
            selectedFaceId = result.faces[idx + 1].faceId
        } else {
            selectedFaceId = result.faces.first?.faceId
        }
    }

    func fitToWindow() { fitToWindowTrigger &+= 1 }

    // MARK: - Piece offset helpers

    func pieceIndex(forFaceId fid: Int, result: UnfoldResult) -> Int? {
        result.pieces.firstIndex { $0.contains(fid) }
    }

    func offset(forFaceId fid: Int, result: UnfoldResult) -> SIMD2<Float> {
        guard let pi = pieceIndex(forFaceId: fid, result: result) else { return .zero }
        return pieceOffsets[pi] ?? .zero
    }

    func rotation(forFaceId fid: Int, result: UnfoldResult) -> Float {
        guard let pi = pieceIndex(forFaceId: fid, result: result) else { return 0 }
        return pieceRotations[pi] ?? 0
    }

    /// Effective centroid of a piece = raw bbox center + current offset.
    /// Stays fixed when the piece is rotated (rotation is around the raw center).
    func effectiveCentroid(forPieceIdx pi: Int, result: UnfoldResult) -> SIMD2<Float> {
        guard pi < result.pieces.count else { return .zero }
        return pieceCenter(for: result.pieces[pi], result: result) + (pieceOffsets[pi] ?? .zero)
    }

    /// Bbox center of a piece's raw face positions (no offsets applied).
    /// Used as the rotation origin so the piece rotates around its own center.
    func pieceCenter(for faceIds: [Int], result: UnfoldResult) -> SIMD2<Float> {
        let faceSet = Set(faceIds)
        let faces = result.faces.filter { faceSet.contains($0.faceId) }
        guard !faces.isEmpty else { return .zero }
        let allX = faces.flatMap { [$0.v0.x, $0.v1.x, $0.v2.x] }
        let allY = faces.flatMap { [$0.v0.y, $0.v1.y, $0.v2.y] }
        return SIMD2((allX.min()! + allX.max()!) / 2, (allY.min()! + allY.max()!) / 2)
    }

    // MARK: - Texture cache (materialId → CGImage)

    private func buildTextureCache(mesh: Mesh, sourceURL: URL) -> [Int: CGImage] {
        var cache: [Int: CGImage] = [:]
        // Embedded textures (PDO): index in embeddedTextures == materialId
        for (i, tex) in mesh.embeddedTextures.enumerated() {
            if let img = cgImageFromRGB24(tex) { cache[i] = img }
        }
        // File-based textures (OBJ + MTL)
        for (i, path) in mesh.materialTexturePaths.enumerated() where cache[i] == nil {
            guard let path else { continue }
            guard let url = resolveTextureURL(path, relativeTo: sourceURL) else { continue }
            guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { continue }
            cache[i] = img
        }
        return cache
    }

    private func cgImageFromRGB24(_ tex: EmbeddedTextureData) -> CGImage? {
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let provider = CGDataProvider(data: tex.rgb24Bytes as CFData) else { return nil }
        return CGImage(
            width: tex.width, height: tex.height,
            bitsPerComponent: 8, bitsPerPixel: 24, bytesPerRow: tex.width * 3,
            space: cs,
            bitmapInfo: CGBitmapInfo(rawValue: 0),
            provider: provider,
            decode: nil, shouldInterpolate: true, intent: .defaultIntent
        )
    }

    private func resolveTextureURL(_ path: String, relativeTo base: URL) -> URL? {
        let abs = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: abs.path) { return abs }
        let rel = base.deletingLastPathComponent().appendingPathComponent(path)
        return FileManager.default.fileExists(atPath: rel.path) ? rel : nil
    }

    // MARK: - Dynamic page expansion (called after each piece drag)

    /// Recomputes pagesWide/pagesTall from current effective piece positions.
    /// Called from PatternCanvasView after each drag update so that dragging a
    /// piece beyond the current page boundary adds a new page, while dragging
    /// it back removes the no-longer-needed page.
    func recomputePagesForOffsets() {
        guard let result = unfoldResult else { return }
        let paper = settings.print.effectivePaper
        let pageW = Float(paper.widthMm)
        let pageH = Float(paper.heightMm)
        let sep   = Float(settings.print.marginMm)

        var maxX: Float = 0
        var maxY: Float = 0
        for face in result.faces {
            let off = offset(forFaceId: face.faceId, result: result)
            for v in [face.v0 + off, face.v1 + off, face.v2 + off] {
                maxX = max(maxX, v.x)
                maxY = max(maxY, v.y)
            }
        }

        let newCols = max(1, Int(ceil(maxX / (pageW + sep))))
        let newRows = max(1, Int(ceil(maxY / (pageH + sep))))
        if newCols != pagesWide { pagesWide = newCols }
        if newRows != pagesTall { pagesTall = newRows }
    }

    // MARK: - Auto-arrange pieces on paper

    /// Packs all pieces into a multi-page grid.
    /// Pages expand to the right (up to maxPageCols columns), then wrap to a new page row.
    func autoArrange() {
        guard var result = unfoldResult else { return }
        let paper   = settings.print.effectivePaper
        let margin  = Float(settings.print.marginMm)
        let pageW   = Float(paper.widthMm)
        let pageH   = Float(paper.heightMm)
        let pageSep = margin          // gap between adjacent pages
        let maxCols = 4               // max page columns before starting a new page row
        let usableW = pageW - 2 * margin
        let usableH = pageH - 2 * margin

        // Sort pieces largest-area first so big pieces get prime positions
        let sortedPieces = result.pieces.sorted { lhs, rhs in
            func area(_ faceIds: [Int]) -> Float {
                let faces = result.faces.filter { faceIds.contains($0.faceId) }
                guard !faces.isEmpty else { return 0 }
                let xs = faces.flatMap { [$0.v0.x, $0.v1.x, $0.v2.x] }
                let ys = faces.flatMap { [$0.v0.y, $0.v1.y, $0.v2.y] }
                return (xs.max()! - xs.min()!) * (ys.max()! - ys.min()!)
            }
            return area(lhs) > area(rhs)
        }

        var newFaces = result.faces
        var newTabs  = result.tabs

        var localX: Float = margin
        var localY: Float = margin
        var rowH:   Float = 0
        var pageCol = 0, pageRow = 0
        var newPagesWide = 1, newPagesTall = 1

        for faceIds in sortedPieces {
            let faceSet    = Set(faceIds)
            let pieceFaces = result.faces.filter { faceSet.contains($0.faceId) }
            guard !pieceFaces.isEmpty else { continue }

            let allX = pieceFaces.flatMap { [$0.v0.x, $0.v1.x, $0.v2.x] }
            let allY = pieceFaces.flatMap { [$0.v0.y, $0.v1.y, $0.v2.y] }
            let minX = allX.min()!, minY = allY.min()!
            let wNat = allX.max()! - minX, hNat = allY.max()! - minY

            // Try a 90° rotation when it produces a narrower footprint that still fits both axes
            // (mirrors Windows RunAutoArrange's First-Fit-Decreasing-with-rotation heuristic).
            var w = wNat, h = hNat, rotate90 = false
            if hNat < wNat && hNat <= usableW && wNat <= usableH {
                w = hNat; h = wNat; rotate90 = true
            }

            // Wrap to next row within the current page when horizontal space runs out
            if localX > margin && localX + w > pageW - margin {
                localX = margin
                localY += rowH + margin
                rowH = 0
            }

            // Advance to the next page column when vertical space on this page runs out
            if localY > margin && localY + h > pageH - margin {
                pageCol += 1
                if pageCol >= maxCols {   // hit column limit → start a new page row
                    pageCol = 0
                    pageRow += 1
                }
                localX = margin; localY = margin; rowH = 0
            }

            // Absolute position in mm across the full multi-page canvas
            let absX = Float(pageCol) * (pageW + pageSep) + localX
            let absY = Float(pageRow) * (pageH + pageSep) + localY

            // Rotating bakes the 90° turn directly into vertex positions (this platform's
            // autoArrange commits absolute geometry, unlike Windows' local-space + render-time
            // RotateTransform) — rotate the piece's local bbox around its own origin (swapping
            // w/h), then translate into the page slot.
            let transform: (SIMD2<Float>) -> SIMD2<Float>
            if rotate90 {
                transform = { v in
                    rotated90InLocalBBox(SIMD2(v.x - minX, v.y - minY), boxWidth: wNat)
                        + SIMD2<Float>(absX, absY)
                }
            } else {
                let off = SIMD2<Float>(absX - minX, absY - minY)
                transform = { $0 + off }
            }

            for i in newFaces.indices where faceSet.contains(newFaces[i].faceId) {
                newFaces[i] = newFaces[i].transformed(transform)
            }
            for i in newTabs.indices where faceSet.contains(newTabs[i].faceId) {
                newTabs[i] = newTabs[i].transformed(transform)
            }

            localX += w + margin
            rowH = max(rowH, h)
            newPagesWide = max(newPagesWide, pageCol + 1)
            newPagesTall = max(newPagesTall, pageRow + 1)
        }

        result.faces         = newFaces
        result.tabs          = newTabs
        unfoldResult         = result
        pieceOffsets         = [:]
        pagesWide            = newPagesWide
        pagesTall            = newPagesTall
        selectedPieceIndices = []
    }

    // MARK: - Mesh file operations

    func openMeshFilePicker() {
        let panel = NSOpenPanel()
        panel.title = "Open Mesh File"
        panel.allowedContentTypes = [
            .init(filenameExtension: "obj")!,
            .init(filenameExtension: "pdo")!
        ]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await loadMesh(from: url) }
    }

    func loadMesh(from url: URL) async {
        isLoading = true
        errorMessage = nil
        unfoldResult = nil
        edgeOverrides = [:]
        flapOverrides = [:]
        undoStack = []
        redoStack = []
        pagesWide = 1
        pagesTall = 1
        selectedPieceIndices = []
        userGroups = [:]
        nextUserGroupId = 1
        do {
            let loaded = try await loader.load(from: url)
            mesh = loaded
            sourceMeshURL = url
            textureCache = buildTextureCache(mesh: loaded, sourceURL: url)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: - Unfold pipeline (delegates to UnfoldService actor)

    func unfold() async {
        guard let mesh else { return }
        isLoading = true
        unfoldResult = await unfoldSvc.unfold(
            mesh: mesh,
            edgeOverrides: edgeOverrides,
            flapOverrides: flapOverrides,
            settings: settings.print,
            meshScaleMm: meshScaleMmPerUnit
        )
        pieceOffsets         = [:]
        pieceRotations       = [:]
        selectedPieceIndices = []   // clear selection; userGroups kept (stable by minFaceId)
        isLoading = false
    }

    /// Called by UnfoldSetupSheet on confirm: stores scale, runs unfold, then auto-arranges.
    func unfoldAndArrange(scaleMmPerUnit: Float) {
        meshScaleMmPerUnit = scaleMmPerUnit
        Task {
            await unfold()
            autoArrange()
        }
    }

    // MARK: - Project save / load (.4hu bundle)

    func openProjectFilePicker() {
        let panel = NSOpenPanel()
        panel.title = "Open Project"
        panel.allowedContentTypes = [.init(filenameExtension: "4hu")!]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await loadProject(from: url) }
    }

    func saveProjectFilePicker() {
        guard sourceMeshURL != nil else {
            errorMessage = "No mesh loaded — open an OBJ or PDO file first."
            return
        }
        let panel = NSSavePanel()
        panel.title = "Save Project"
        panel.allowedContentTypes = [.init(filenameExtension: "4hu")!]
        panel.nameFieldStringValue = "\(mesh?.name ?? "project").4hu"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await saveProject(to: url) }
    }

    private func saveProject(to url: URL) async {
        guard let sourceMeshURL else {
            errorMessage = ProjectSerializer.ProjectError.noSourceMesh.localizedDescription
            return
        }
        isLoading = true
        errorMessage = nil
        let edgeOv      = edgeOverrides
        let flapOv      = flapOverrides
        let snap        = settings
        let meshSnap    = sourceMeshURL
        let offsetsSnap = pieceOffsets
        let groupsSnap  = userGroups
        do {
            try await Task.detached(priority: .utility) {
                try ProjectSerializer().save(
                    meshURL: meshSnap,
                    edgeOverrides: edgeOv,
                    flapOverrides: flapOv,
                    settings: snap,
                    pieceOffsets: offsetsSnap,
                    userGroups: groupsSnap,
                    to: url
                )
            }.value
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func loadProject(from url: URL) async {
        isLoading = true
        errorMessage = nil
        unfoldResult = nil
        undoStack = []
        redoStack = []
        do {
            // Extract bundle off main thread
            let (state, meshURL, tempDir) = try await Task.detached(priority: .utility) {
                try ProjectSerializer().load(from: url)
            }.value
            // tempDir is always cleaned up, even if loader.load throws
            defer { try? FileManager.default.removeItem(at: tempDir) }

            // Load mesh (reads entire file into memory)
            let loadedMesh = try await loader.load(from: meshURL)

            // Restore state
            mesh          = loadedMesh
            sourceMeshURL = url          // project file becomes the source URL
            edgeOverrides = state.edgeOverrides
            flapOverrides = state.flapOverrides
            settings      = state.settings
            pieceOffsets  = state.pieceOffsets.reduce(into: [Int: SIMD2<Float>]()) { d, kv in
                guard let pi = Int(kv.key), kv.value.count >= 2,
                      kv.value[0].isFinite, kv.value[1].isFinite else { return }
                d[pi] = SIMD2<Float>(kv.value[0], kv.value[1])
            }
            userGroups = state.userGroups.reduce(into: [Int: Int]()) { d, kv in
                guard let k = Int(kv.key) else { return }
                d[k] = kv.value
            }
            nextUserGroupId = (userGroups.values.max() ?? 0) + 1

            await unfold()
            autoArrange()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: - Export

    func exportSVG() async {
        guard let result = unfoldResult else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.svg]
        panel.nameFieldStringValue = "\(mesh?.name ?? "pattern").svg"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let svg = SVGExporter.export(result: result, settings: settings.print)
        try? svg.write(to: url, atomically: true, encoding: .utf8)
    }

    func exportPDF() async {
        guard let result = unfoldResult else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(mesh?.name ?? "pattern").pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let data = PDFExporter.export(result: result, settings: settings.print) else {
            errorMessage = "PDF export failed — could not create PDF context."
            return
        }
        do {
            try data.write(to: url)
        } catch {
            errorMessage = "PDF write failed: \(error.localizedDescription)"
        }
    }

    /// Exports one PNG raster image per page (for cutting-machine software that prefers bitmap
    /// import over SVG/PDF). Mirrors exportSVG/exportPDF's save-panel pattern.
    func exportPNG() async {
        guard let result = unfoldResult else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "\(mesh?.name ?? "pattern").png"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let paper = settings.print.effectivePaper
        let written = PNGExporter.export(
            result: result, settings: settings.print, baseURL: url,
            paperWidthMm: paper.widthMm, paperHeightMm: paper.heightMm,
            pagesWide: pagesWide, pagesTall: pagesTall,
            pageSepMm: settings.print.marginMm)

        if written.isEmpty {
            errorMessage = "PNG export failed — could not create bitmap context."
        }
    }
}

// MARK: - Arbitrary per-vertex transform (rotate + translate in one pass)
//
// `translated(by:)` on UnfoldedFace/GlueTab only supports pure translation. autoArrange() also
// needs to rotate a piece 90° when that improves packing, so these apply any per-point closure.

private extension UnfoldedFace {
    func transformed(_ f: (SIMD2<Float>) -> SIMD2<Float>) -> UnfoldedFace {
        UnfoldedFace(
            faceId: faceId, materialId: materialId,
            v0: f(v0), v1: f(v1), v2: f(v2),
            edge0IsFold: edge0IsFold, edge1IsFold: edge1IsFold, edge2IsFold: edge2IsFold,
            edge0IsBoundary: edge0IsBoundary, edge1IsBoundary: edge1IsBoundary, edge2IsBoundary: edge2IsBoundary,
            uv0: uv0, uv1: uv1, uv2: uv2,
            meshEdge0: meshEdge0, meshEdge1: meshEdge1, meshEdge2: meshEdge2
        )
    }
}

private extension GlueTab {
    func transformed(_ f: (SIMD2<Float>) -> SIMD2<Float>) -> GlueTab {
        GlueTab(faceId: faceId, localEdgeIdx: localEdgeIdx,
                p0: f(p0), p1: f(p1), p2: f(p2), p3: f(p3),
                borderFoldStyle: borderFoldStyle,
                mergedPolygon: mergedPolygon?.map(f))
    }
}
