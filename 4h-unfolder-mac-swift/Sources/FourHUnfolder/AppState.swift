import AppKit
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var mesh: Mesh?
    @Published var unfoldResult: UnfoldResult?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var settings: AppSettings = .load()

    private let loader = MeshLoaderFactory()
    private let engine = UnfoldEngine()

    // MARK: - File operations

    func openMeshFilePicker() {
        let panel = NSOpenPanel()
        panel.title = "Open Mesh File"
        panel.allowedContentTypes = [.init(filenameExtension: "obj")!]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await loadMesh(from: url) }
    }

    func loadMesh(from url: URL) async {
        isLoading = true
        errorMessage = nil
        unfoldResult = nil
        do {
            mesh = try await loader.load(from: url)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Unfold

    func unfold() async {
        guard let mesh else { return }
        isLoading = true
        let snapshot = mesh
        let eng = engine
        unfoldResult = await Task.detached(priority: .userInitiated) {
            eng.unfold(mesh: snapshot)
        }.value
        isLoading = false
    }

    // MARK: - Export

    func exportSVG() async {
        guard let result = unfoldResult else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.svg]
        panel.nameFieldStringValue = "\(mesh?.name ?? "pattern").svg"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let svg = SVGExporter.export(result: result)
        try? svg.write(to: url, atomically: true, encoding: .utf8)
    }
}

// MARK: - Minimal SVG exporter

enum SVGExporter {
    static func export(result: UnfoldResult) -> String {
        let w  = result.pageWidth
        let h  = result.pageHeight
        let ox = -result.boundingBox.min.x
        let oy = -result.boundingBox.min.y
        var lines = [
            #"<?xml version="1.0" encoding="UTF-8"?>"#,
            #"<svg xmlns="http://www.w3.org/2000/svg" width="\#(w)mm" height="\#(h)mm" viewBox="0 0 \#(w) \#(h)">"#
        ]
        for face in result.faces {
            guard face.vertices2D.count >= 3 else { continue }
            let pts = face.vertices2D.map { "\($0.x + ox),\($0.y + oy)" }.joined(separator: " ")
            lines.append(#"  <polygon points="\#(pts)" fill="#cce0ff" stroke="#000" stroke-width="0.3"/>"#)
        }
        for tab in result.tabs {
            guard tab.polygon.count >= 3 else { continue }
            let pts = tab.polygon.map { "\($0.x + ox),\($0.y + oy)" }.joined(separator: " ")
            lines.append(#"  <polygon points="\#(pts)" fill="#e0e0e0" stroke="#000" stroke-width="0.2" stroke-dasharray="2 1"/>"#)
        }
        lines.append("</svg>")
        return lines.joined(separator: "\n")
    }
}
