import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        List {
            // MARK: File
            Section("File") {
                meshInfoRow

                Button("Open Mesh…") { appState.openMeshFilePicker() }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.accent)
            }

            // MARK: Unfold settings
            Section("Unfold Settings") {
                LabeledContent("Tab Height") {
                    HStack(spacing: 4) {
                        TextField("5", value: $appState.settings.tabHeightMm, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 56)
                        Text("mm").foregroundStyle(.secondary)
                    }
                }

                LabeledContent("Tab Angle") {
                    HStack(spacing: 4) {
                        TextField("45", value: $appState.settings.tabAngleDeg, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 56)
                        Text("°").foregroundStyle(.secondary)
                    }
                }

                Picker("Tab Style", selection: $appState.settings.tabStyle) {
                    ForEach(AppSettings.TabStyle.allCases) { style in
                        Text(style.rawValue.capitalized).tag(style)
                    }
                }
                .pickerStyle(.menu)
            }

            // MARK: View options
            Section("View") {
                Toggle("Edge Labels",   isOn: $appState.settings.showEdgeLabels)
                Toggle("Face Normals",  isOn: $appState.settings.showFaceNormals)
                Toggle("Auto-fit",      isOn: $appState.settings.autoFitOnUnfold)
            }

            // MARK: Pattern info
            if let result = appState.unfoldResult {
                Section("Pattern") {
                    LabeledContent("Faces",  value: "\(result.faces.count)")
                    LabeledContent("Tabs",   value: "\(result.tabs.count)")
                    LabeledContent("Width",  value: String(format: "%.1f mm", result.pageWidth))
                    LabeledContent("Height", value: String(format: "%.1f mm", result.pageHeight))
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
                Text(mesh.name).fontWeight(.semibold)
                Text("\(mesh.faces.count) faces · \(mesh.vertices.count) verts")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        } else {
            Text("No mesh loaded")
                .foregroundStyle(.tertiary)
                .italic()
        }
    }
}
