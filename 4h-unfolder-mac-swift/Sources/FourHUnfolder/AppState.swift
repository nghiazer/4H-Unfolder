import AppKit
import SwiftUI
import CoreGraphics
import ImageIO
@testable import FourHUnfolderCore

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
        Task { await unfold() }
    }

    func redo() {
        guard let snap = redoStack.popLast() else { return }
        undoStack.append((edgeOverrides, flapOverrides))
        edgeOverrides = snap.edges
        flapOverrides = snap.flaps
        Task { await unfold() }
    }

    // MARK: - Edge / flap overrides

    func toggleEdge(_ meshEdgeId: Int) {
        guard let mesh, meshEdgeId < mesh.edges.count else { return }
        pushUndo()
        let current = edgeOverrides[meshEdgeId] ?? mesh.edges[meshEdgeId].type
        edgeOverrides[meshEdgeId] = (current == .fold) ? .cut : .fold
        Task { await unfold() }
    }

    func setFlapOverride(_ meshEdgeId: Int, _ override: FlapOverride?) {
        pushUndo()
        flapOverrides[meshEdgeId] = override
        Task { await unfold() }
    }

    func clearEdgeOverrides() {
        pushUndo()
        edgeOverrides.removeAll()
        flapOverrides.removeAll()
        Task { await unfold() }
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

    // MARK: - Auto-arrange pieces on paper

    func autoArrange() {
        guard var result = unfoldResult else { return }
        let paper  = settings.print.effectivePaper
        let margin = Float(settings.print.marginMm)
        let pageW  = Float(paper.widthMm)

        var newFaces = result.faces
        var newTabs  = result.tabs
        var curX: Float = margin
        var curY: Float = margin
        var rowH: Float = 0

        for faceIds in result.pieces {
            let faceSet   = Set(faceIds)
            let pieceFaces = result.faces.filter { faceSet.contains($0.faceId) }
            guard !pieceFaces.isEmpty else { continue }

            let allX = pieceFaces.flatMap { [$0.v0.x, $0.v1.x, $0.v2.x] }
            let allY = pieceFaces.flatMap { [$0.v0.y, $0.v1.y, $0.v2.y] }
            let minX = allX.min()!, maxX = allX.max()!
            let minY = allY.min()!, maxY = allY.max()!
            let w = maxX - minX, h = maxY - minY

            if curX + w > pageW - margin && curX > margin {
                curX = margin; curY += rowH + margin; rowH = 0
            }

            let off = SIMD2<Float>(curX - minX, curY - minY)
            for i in newFaces.indices where faceSet.contains(newFaces[i].faceId) {
                newFaces[i] = newFaces[i].translated(by: off)
            }
            for i in newTabs.indices where faceSet.contains(newTabs[i].faceId) {
                newTabs[i] = newTabs[i].translated(by: off)
            }
            curX += w + margin
            rowH = max(rowH, h)
        }

        result.faces = newFaces
        result.tabs  = newTabs
        unfoldResult = result
        pieceOffsets = [:]
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
        do {
            let loaded = try await loader.load(from: url)
            mesh = loaded
            sourceMeshURL = url
            textureCache = buildTextureCache(mesh: loaded, sourceURL: url)
            await unfold()
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
            settings: settings.print
        )
        pieceOffsets = [:]
        isLoading = false
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
        do {
            try await Task.detached(priority: .utility) {
                try ProjectSerializer().save(
                    meshURL: meshSnap,
                    edgeOverrides: edgeOv,
                    flapOverrides: flapOv,
                    settings: snap,
                    pieceOffsets: offsetsSnap,
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

            await unfold()
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
}
