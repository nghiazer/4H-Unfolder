import SwiftUI

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
            CommandGroup(replacing: .newItem) {}          // disable File→New
            CommandGroup(after: .newItem) {
                Button("Open Mesh…") {
                    appState.openMeshFilePicker()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            CommandGroup(after: .saveItem) {
                Button("Export SVG…") {
                    Task { await appState.exportSVG() }
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(appState.unfoldResult == nil)
            }
        }
    }
}
