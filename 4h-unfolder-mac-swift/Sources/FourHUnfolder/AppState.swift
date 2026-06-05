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

    // MARK: - SVG export

    func exportSVG() async {
        guard let result = unfoldResult else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.svg]
        panel.nameFieldStringValue = "\(mesh?.name ?? "pattern").svg"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let svg = SVGExporter.export(result: result, settings: settings.print)
        try? svg.write(to: url, atomically: true, encoding: .utf8)
    }
}

// MARK: - Minimal SVG exporter

enum SVGExporter {
    static func export(result: UnfoldResult, settings: AppSettings.PrintSettings) -> String {
        let bbox = result.boundingBox
        let w  = Double(result.pageWidth)
        let h  = Double(result.pageHeight)
        let sc = settings.svgScaleFactor
        let mg = settings.marginMm * sc
        let ox = Double(-bbox.min.x) * sc + mg
        let oy = Double(-bbox.min.y) * sc + mg
        let svgW = w * sc + 2 * mg
        let svgH = h * sc + 2 * mg

        var lines = [
            #"<?xml version="1.0" encoding="UTF-8"?>"#,
            #"<svg xmlns="http://www.w3.org/2000/svg" width="\#(svgW)mm" height="\#(svgH)mm" viewBox="0 0 \#(svgW) \#(svgH)">"#
        ]

        let fillColor = settings.grayscaleOutput ? "#d0d0d0" : "#cce0ff"

        for face in result.faces {
            let pts = [face.v0, face.v1, face.v2]
                .map { "\(Double($0.x) * sc + ox),\(Double($0.y) * sc + oy)" }
                .joined(separator: " ")
            lines.append(#"  <polygon points="\#(pts)" fill="\#(fillColor)" stroke="none"/>"#)
        }

        if settings.printFoldLines {
            let foldDash = settings.foldLineDash == "Solid" ? "" : #" stroke-dasharray="\#(settings.foldLineDash)""#
            var drawnFolds = Set<Int>()
            for face in result.faces {
                let verts = [face.v0, face.v1, face.v2]
                for ei in 0..<3 where face.edgeIsFold(ei) {
                    let mid = face.meshEdgeId(ei)
                    guard mid >= 0, drawnFolds.insert(mid).inserted else { continue }
                    let p0 = verts[ei], p1 = verts[(ei + 1) % 3]
                    lines.append(#"  <line x1="\#(Double(p0.x)*sc+ox)" y1="\#(Double(p0.y)*sc+oy)" x2="\#(Double(p1.x)*sc+ox)" y2="\#(Double(p1.y)*sc+oy)" stroke="\#(settings.foldLineColor)" stroke-width="\#(settings.foldLineWidth)"\#(foldDash)/>"#)
                }
            }
        }

        if settings.printCutLines {
            var drawnCuts = Set<Int>()
            for face in result.faces {
                let verts = [face.v0, face.v1, face.v2]
                for ei in 0..<3 where !face.edgeIsFold(ei) && !face.edgeIsBoundary(ei) {
                    let mid = face.meshEdgeId(ei)
                    guard mid >= 0, drawnCuts.insert(mid).inserted else { continue }
                    let p0 = verts[ei], p1 = verts[(ei + 1) % 3]
                    lines.append(#"  <line x1="\#(Double(p0.x)*sc+ox)" y1="\#(Double(p0.y)*sc+oy)" x2="\#(Double(p1.x)*sc+ox)" y2="\#(Double(p1.y)*sc+oy)" stroke="\#(settings.cutLineColor)" stroke-width="\#(settings.cutLineWidth)"/>"#)
                }
            }
        }

        if settings.includGlueTabs {
            let tabColor = settings.grayscaleOutput ? "#a0a0a0" : "#a8d5a2"
            for tab in result.tabs {
                let pts = tab.polygon
                    .map { "\(Double($0.x) * sc + ox),\(Double($0.y) * sc + oy)" }
                    .joined(separator: " ")
                lines.append("  <polygon points=\"\(pts)\" fill=\"\(tabColor)\" fill-opacity=\"0.6\" stroke=\"#2e7d32\" stroke-width=\"0.4\"/>")
            }
        }

        lines.append("</svg>")
        return lines.joined(separator: "\n")
    }
}
