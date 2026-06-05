import AppKit
import SwiftUI

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

    func selectAll() { /* Phase 6 */ }

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
            mesh = try await loader.load(from: url)
            sourceMeshURL = url
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
        let edgeOv   = edgeOverrides
        let flapOv   = flapOverrides
        let snap     = settings
        let meshSnap = sourceMeshURL
        do {
            try await Task.detached(priority: .utility) {
                try ProjectSerializer().save(
                    meshURL: meshSnap,
                    edgeOverrides: edgeOv,
                    flapOverrides: flapOv,
                    settings: snap,
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

            // Load mesh (reads entire file into memory — temp dir can be deleted after)
            let loadedMesh = try await loader.load(from: meshURL)
            try? FileManager.default.removeItem(at: tempDir)

            // Restore state
            mesh            = loadedMesh
            sourceMeshURL   = url          // project file becomes the source URL
            edgeOverrides   = state.edgeOverrides
            flapOverrides   = state.flapOverrides
            settings        = state.settings

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
