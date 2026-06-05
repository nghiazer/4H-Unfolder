import SwiftUI

struct MainView: View {
    @EnvironmentObject var appState: AppState

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
                        selectedFaceId: appState.selectedFaceId
                    )
                    .frame(minWidth: 280)

                    PatternCanvasView()
                        .frame(minWidth: 280)
                }
            }
        }
        .navigationTitle(appState.mesh.map {
            $0.name.isEmpty ? "4H Unfolder" : $0.name
        } ?? "4H Unfolder")
        .toolbar { toolbarItems }
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
            .keyboardShortcut("o", modifiers: .command)
            .help("Open an OBJ or PDO mesh file (⌘O)")

            Divider()

            // Unfold
            Button {
                Task { await appState.unfold() }
            } label: {
                Label("Unfold", systemImage: "triangle.bottomhalf.pattern.checkered")
            }
            .keyboardShortcut("u", modifiers: .command)
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
            .keyboardShortcut("e", modifiers: [.command, .shift])

            // Export PDF
            Button {
                Task { await appState.exportPDF() }
            } label: {
                Label("Export PDF…", systemImage: "doc.richtext")
            }
            .disabled(appState.unfoldResult == nil)
            .help("Export unfolded pattern as PDF (⌘P)")
            .keyboardShortcut("p", modifiers: .command)

            Divider()

            // Project save / open
            Button {
                appState.openProjectFilePicker()
            } label: {
                Label("Open Project…", systemImage: "folder.badge.plus")
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
            .help("Open a saved .4hu project (⌘⇧O)")

            Button {
                appState.saveProjectFilePicker()
            } label: {
                Label("Save Project…", systemImage: "externaldrive.badge.checkmark")
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(appState.mesh == nil)
            .help("Save project as .4hu bundle (⌘S)")

            Divider()

            // Undo / Redo
            Button { appState.undo() } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .keyboardShortcut("z", modifiers: .command)
            .help("Undo edge override (⌘Z)")

            Button { appState.redo() } label: {
                Image(systemName: "arrow.uturn.forward")
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .help("Redo (⌘⇧Z)")
        }
    }
}
