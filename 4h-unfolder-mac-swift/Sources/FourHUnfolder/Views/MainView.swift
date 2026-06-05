import SwiftUI
import UniformTypeIdentifiers
@testable import FourHUnfolderCore

struct MainView: View {
    @EnvironmentObject var appState: AppState
    @State private var isDropTarget = false

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            VStack(spacing: 0) {
                // Error banner (dismiss on tap)
                if let msg = appState.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(msg)
                            .font(.callout)
                            .lineLimit(2)
                        Spacer()
                        Button { appState.errorMessage = nil } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.15))
                }

                HSplitView {
                    SceneKitView(
                        mesh: appState.mesh,
                        selectedFaceId: appState.selectedFaceId,
                        textureCache: appState.textureCache
                    )
                    .frame(minWidth: 280)

                    PatternCanvasView()
                        .frame(minWidth: 280)
                }

                // Status bar
                if let result = appState.unfoldResult {
                    statusBar(result: result)
                }
            }
        }
        .navigationTitle(appState.mesh.map {
            $0.name.isEmpty ? "4H Unfolder" : $0.name
        } ?? "4H Unfolder")
        .toolbar { toolbarItems }
        // Accept .obj / .pdo / .4hu dragged onto the window
        .onDrop(of: [UTType.fileURL], isTargeted: $isDropTarget) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in await appState.loadMesh(from: url) }
            }
            return true
        }
        .overlay {
            if isDropTarget {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor, lineWidth: 3)
                    .background(Color.accentColor.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: 12))
                    .padding(4)
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Status bar

    @ViewBuilder
    private func statusBar(result: UnfoldResult) -> some View {
        HStack(spacing: 14) {
            Label("\(result.faces.count)", systemImage: "triangle")
                .help("Face count")
            Label("\(result.pieces.count)", systemImage: "square.on.square")
                .help("Piece count")
            if result.hasOverlaps {
                Label("Overlaps", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help("Pattern has overlapping pieces")
            }
            Spacer()
            let p = appState.settings.print.effectivePaper
            Text("\(p.name) \(appState.settings.print.isLandscape ? "L" : "P")")
                .foregroundStyle(.tertiary)
            Text(String(format: "%.0f × %.0f mm", p.widthMm, p.heightMm))
                .foregroundStyle(.tertiary)
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItemGroup {
            // Loading indicator
            if appState.isLoading {
                ProgressView().controlSize(.small)
            }

            // Open mesh
            Button {
                appState.openMeshFilePicker()
            } label: {
                Label("Open Mesh…", systemImage: "cube.fill")
            }
            .help("Open an OBJ or PDO mesh file (⌘O)")

            Divider()

            // Unfold
            Button {
                Task { await appState.unfold() }
            } label: {
                Label("Unfold", systemImage: "triangle.bottomhalf.pattern.checkered")
            }
            .disabled(appState.mesh == nil || appState.isLoading)
            .help("Run unfold pipeline (⌘U)")

            Divider()

            // Export SVG
            Button {
                Task { await appState.exportSVG() }
            } label: {
                Label("Export SVG…", systemImage: "doc.text")
            }
            .disabled(appState.unfoldResult == nil)
            .help("Export unfolded pattern as SVG (⌘⇧E)")

            // Export PDF
            Button {
                Task { await appState.exportPDF() }
            } label: {
                Label("Export PDF…", systemImage: "doc.richtext")
            }
            .disabled(appState.unfoldResult == nil)
            .help("Export unfolded pattern as PDF (⌘P)")

            Divider()

            // Project save / open
            Button {
                appState.openProjectFilePicker()
            } label: {
                Label("Open Project…", systemImage: "folder.badge.plus")
            }
            .help("Open a saved .4hu project (⌘⇧O)")

            Button {
                appState.saveProjectFilePicker()
            } label: {
                Label("Save Project…", systemImage: "externaldrive.badge.checkmark")
            }
            .disabled(appState.mesh == nil)
            .help("Save project as .4hu bundle (⌘S)")

            Divider()

            // Undo / Redo
            Button { appState.undo() } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .help("Undo edge override (⌘Z)")

            Button { appState.redo() } label: {
                Image(systemName: "arrow.uturn.forward")
            }
            .help("Redo (⌘⇧Z)")
        }
    }
}
