import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        List {
            // MARK: File
            Section("File") {
                meshInfoRow
                Button("Open Mesh…") { appState.openMeshFilePicker() }
                    .buttonStyle(.borderless).foregroundStyle(.accent)
            }

            // MARK: Unfold Settings
            Section("Unfold Settings") {
                LabeledContent("Tab Height") {
                    HStack(spacing: 4) {
                        TextField("5", value: $appState.settings.print.glueTabDepthMm, format: .number)
                            .textFieldStyle(.roundedBorder).frame(width: 56)
                        Text("mm").foregroundStyle(.secondary)
                    }
                }
                LabeledContent("Tab Angle") {
                    HStack(spacing: 4) {
                        TextField("45", value: $appState.settings.print.glueTabSideAngleDeg, format: .number)
                            .textFieldStyle(.roundedBorder).frame(width: 56)
                        Text("°").foregroundStyle(.secondary)
                    }
                }
                Picker("Tab Style", selection: $appState.settings.print.glueTabShape) {
                    ForEach(AppSettings.PrintSettings.TabShape.allCases) { style in
                        Text(style.rawValue).tag(style)
                    }
                }.pickerStyle(.menu)

                Toggle("Alternate Flaps", isOn: $appState.settings.print.alternateFlaps)
            }

            // MARK: View Options
            Section("View") {
                Toggle("Show Grid",         isOn: $appState.settings.view2D.showGrid)
                Toggle("Snap to Grid",      isOn: $appState.settings.view2D.snapToGrid)
                Toggle("Show Face Numbers", isOn: $appState.settings.view2D.showFaceNumbers)
                Toggle("Show Fold Angles",  isOn: $appState.settings.view2D.showFoldAngles)
                Toggle("Show Glue Tabs",    isOn: $appState.settings.view2D.showGlueTabs)
            }

            // MARK: Pattern Info
            if let result = appState.unfoldResult {
                Section("Pattern") {
                    LabeledContent("Faces",   value: "\(result.faces.count)")
                    LabeledContent("Tabs",    value: "\(result.tabs.count)")
                    LabeledContent("Pieces",  value: "\(result.pieces.count)")
                    LabeledContent("Width",   value: String(format: "%.1f mm", result.pageWidth))
                    LabeledContent("Height",  value: String(format: "%.1f mm", result.pageHeight))
                    if result.hasOverlaps {
                        Label("Overlaps detected", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .onChange(of: appState.settings) { _, new in new.save() }
    }

    @ViewBuilder
    private var meshInfoRow: some View {
        if let mesh = appState.mesh {
            VStack(alignment: .leading, spacing: 2) {
                Text(mesh.name.isEmpty ? "Untitled" : mesh.name).fontWeight(.semibold)
                Text("\(mesh.faces.count) faces · \(mesh.vertices.count) verts")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(.vertical, 2)
        } else {
            Text("No mesh loaded").foregroundStyle(.tertiary).italic()
        }
    }
}
