import SwiftUI

struct MainView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            HSplitView {
                SceneKitView(mesh: appState.mesh)
                    .frame(minWidth: 300)

                PatternCanvasView(
                    result: appState.unfoldResult,
                    showEdgeLabels: appState.settings.view2D.showEdgeIds
                )
                .frame(minWidth: 300)
            }
        }
        .navigationTitle(appState.mesh.map { $0.name.isEmpty ? "4H Unfolder" : $0.name } ?? "4H Unfolder")
        .toolbar {
            ToolbarItemGroup {
                if appState.isLoading {
                    ProgressView().controlSize(.small)
                }
                Button("Unfold") {
                    Task { await appState.unfold() }
                }
                .keyboardShortcut("u", modifiers: .command)
                .disabled(appState.mesh == nil || appState.isLoading)

                Button("Export SVG…") {
                    Task { await appState.exportSVG() }
                }
                .disabled(appState.unfoldResult == nil)
            }
        }
    }
}
