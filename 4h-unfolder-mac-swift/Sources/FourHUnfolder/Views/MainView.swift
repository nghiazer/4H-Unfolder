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
        .sheet(isPresented: $appState.showUnfoldSetup) {
            if let mesh = appState.mesh {
                UnfoldSetupSheet(mesh: mesh) { scale in
                    appState.unfoldAndArrange(scaleMmPerUnit: scale)
                }
            }
        }
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
                appState.showUnfoldSetup = true
            } label: {
                Label("Unfold", systemImage: "scissors")
            }
            .disabled(appState.mesh == nil || appState.isLoading)
            .help("Unfold mesh into 2D pattern (⌘U)")

            Divider()

            // Canvas mode: Edit Edges / Edit Flaps / Rotate Pivot (mutually exclusive)
            Button { appState.canvasMode = .editEdge } label: {
                Label("Edit Edges", systemImage: "pencil.tip")
            }
            .background(appState.canvasMode == .editEdge ? Color.accentColor.opacity(0.15) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 4))
            .help("Edit Edges: click edges to toggle fold/cut · ⌥-click a cut edge to join its whole connected chain (⌘1)")

            Button { appState.canvasMode = .editFlap } label: {
                Label("Edit Flaps", systemImage: "square.on.square")
            }
            .disabled(appState.unfoldResult == nil)
            .background(appState.canvasMode == .editFlap ? Color.accentColor.opacity(0.15) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 4))
            .help("Edit Flaps: click edges to set glue tab override (⌘2)")

            Button { appState.canvasMode = .rotatePivot } label: {
                Label("Rotate Pivot", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(appState.unfoldResult == nil)
            .background(appState.canvasMode == .rotatePivot ? Color.accentColor.opacity(0.15) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 4))
            .help("Rotate Pivot: click vertex as pivot, then another as handle (⌘3)")

            Divider()

            // Group / Ungroup selected pieces
            Button { appState.groupSelected() } label: {
                Label("Group", systemImage: "rectangle.3.group")
            }
            .disabled(appState.selectedPieceIndices.count < 2)
            .help("Group selected pieces — move together when dragged")

            Button { appState.ungroupSelected() } label: {
                Label("Ungroup", systemImage: "rectangle.3.group.fill")
            }
            .disabled(!appState.selectedPieceIndices.contains {
                guard let result = appState.unfoldResult, $0 < result.pieces.count else { return false }
                return appState.userGroups[result.pieces[$0].min() ?? -1] != nil
            })
            .help("Remove group assignment from selected pieces")

            // Align selected pieces (GĐ3.3 parity port from Windows)
            Group {
                Button { appState.alignSelectedPieces(.left) } label: {
                    Label("Align Left", systemImage: "align.horizontal.left")
                }
                .help("Align selected pieces to the leftmost edge")

                Button { appState.alignSelectedPieces(.right) } label: {
                    Label("Align Right", systemImage: "align.horizontal.right")
                }
                .help("Align selected pieces to the rightmost edge")

                Button { appState.alignSelectedPieces(.centerH) } label: {
                    Label("Align Center H", systemImage: "align.horizontal.center")
                }
                .help("Align selected pieces to their common horizontal center")

                Button { appState.alignSelectedPieces(.top) } label: {
                    Label("Align Top", systemImage: "align.vertical.top")
                }
                .help("Align selected pieces to the topmost edge")

                Button { appState.alignSelectedPieces(.bottom) } label: {
                    Label("Align Bottom", systemImage: "align.vertical.bottom")
                }
                .help("Align selected pieces to the bottommost edge")

                Button { appState.alignSelectedPieces(.centerV) } label: {
                    Label("Align Center V", systemImage: "align.vertical.center")
                }
                .help("Align selected pieces to their common vertical center")
            }
            .disabled(appState.selectedPieceIndices.count < 2)

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

            // Export PNG (one image per page — for cutting machines)
            Button {
                Task { await appState.exportPNG() }
            } label: {
                Label("Export PNG…", systemImage: "photo")
            }
            .disabled(appState.unfoldResult == nil)
            .help("Export unfolded pattern as PNG, one image per page — for cutting machines (⌘⇧P)")

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
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
            .help("Undo edge override (⌘Z)")

            Button { appState.redo() } label: {
                Label("Redo", systemImage: "arrow.uturn.forward")
            }
            .help("Redo (⌘⇧Z)")
        }
    }
}
