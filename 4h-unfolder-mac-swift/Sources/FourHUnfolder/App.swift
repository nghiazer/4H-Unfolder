import SwiftUI
@testable import FourHUnfolderCore

@main
struct FourHUnfolderApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            // MARK: File menu

            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .newItem) {
                Button("Open Mesh…") { appState.openMeshFilePicker() }
                    .keyboardShortcut("o", modifiers: .command)
                Divider()
                Button("Open Project…") { appState.openProjectFilePicker() }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                Button("Save Project…") { appState.saveProjectFilePicker() }
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(appState.mesh == nil)
            }
            CommandGroup(after: .saveItem) {
                Divider()
                Button("Export SVG…") { Task { await appState.exportSVG() } }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                    .disabled(appState.unfoldResult == nil)
                Button("Export PDF…") { Task { await appState.exportPDF() } }
                    .keyboardShortcut("p", modifiers: .command)
                    .disabled(appState.unfoldResult == nil)
            }

            // MARK: Edit menu

            CommandGroup(replacing: .undoRedo) {
                Button("Undo Override") { appState.undo() }
                    .keyboardShortcut("z", modifiers: .command)
                Button("Redo Override") { appState.redo() }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
            }
            CommandGroup(after: .undoRedo) {
                Divider()
                Button("Clear All Overrides") { appState.clearEdgeOverrides() }
                    .disabled(appState.mesh == nil)
            }

            // MARK: Pattern menu (custom top-level)

            CommandMenu("Pattern") {
                Button("Run Unfold") { Task { await appState.unfold() } }
                    .keyboardShortcut("u", modifiers: .command)
                    .disabled(appState.mesh == nil)
                Divider()
                Button("Auto-Arrange Pieces") { appState.autoArrange() }
                    .keyboardShortcut("a", modifiers: [.command, .shift])
                    .disabled(appState.unfoldResult == nil)
            }

            // MARK: View menu (custom top-level)

            CommandMenu("View") {
                Button("Fit Pattern to Window") { appState.fitToWindow() }
                    .keyboardShortcut("0", modifiers: .command)
                Divider()
                Toggle("Show Grid",         isOn: $appState.settings.view2D.showGrid)
                Toggle("Show Glue Tabs",    isOn: $appState.settings.view2D.showGlueTabs)
                Toggle("Show Fold Angles",  isOn: $appState.settings.view2D.showFoldAngles)
                Toggle("Show Face Numbers", isOn: $appState.settings.view2D.showFaceNumbers)
                Toggle("Show Textures",     isOn: $appState.settings.view2D.showTexture)
            }
        }
    }
}
