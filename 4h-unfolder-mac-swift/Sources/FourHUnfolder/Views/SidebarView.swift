import SwiftUI
@testable import FourHUnfolderCore

struct SidebarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            NamedSection("File") {
                meshInfoRow
                Button("Open Mesh…") { appState.openMeshFilePicker() }
                    .buttonStyle(.borderless).foregroundStyle(Color.accentColor)
            }
            NamedSection("Mesh") {
                Picker("Units", selection: $appState.settings.general.meshUnits) {
                    Text("mm").tag("mm")
                    Text("cm").tag("cm")
                    Text("m").tag("m")
                    Text("in").tag("in")
                }
                .help("Set the unit used in the OBJ/PDO file. Affects real-world size of the unfolded pattern.")
            }
            NamedSection("Unfold Settings") {
                rowField("Tab Height",
                         value: $appState.settings.print.glueTabDepthMm,
                         placeholder: "5", unit: "mm")
                rowField("Tab Angle",
                         value: $appState.settings.print.glueTabSideAngleDeg,
                         placeholder: "45", unit: "°")
                Picker("Tab Style", selection: $appState.settings.print.glueTabShape) {
                    ForEach(AppSettings.PrintSettings.TabShape.allCases) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                Toggle("Alternate Flaps", isOn: $appState.settings.print.alternateFlaps)
            }
            NamedSection("Print Layout") {
                Picker("Paper Size", selection: $appState.settings.print.paperSize) {
                    ForEach(PaperSizeModel.presets) { size in
                        Text(size.name).tag(size)
                    }
                }
                Toggle("Landscape", isOn: $appState.settings.print.isLandscape)
                paperDimensionsRow
                Button("Auto-Arrange Pieces") { appState.autoArrange() }
                    .buttonStyle(.bordered)
                    .disabled(appState.unfoldResult == nil)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            NamedSection("View") {
                Toggle("Show Grid",         isOn: $appState.settings.view2D.showGrid)
                Toggle("Snap to Grid",      isOn: $appState.settings.view2D.snapToGrid)
                Toggle("Show Face Numbers", isOn: $appState.settings.view2D.showFaceNumbers)
                Toggle("Show Fold Angles",  isOn: $appState.settings.view2D.showFoldAngles)
                Toggle("Show Glue Tabs",    isOn: $appState.settings.view2D.showGlueTabs)
            }
            if appState.canvasMode == .editFlap && appState.unfoldResult != nil {
                NamedSection("Edit Flap") {
                    editFlapSection
                }
            }
            if appState.canvasMode == .rotatePivot {
                NamedSection("Rotate Pivot") {
                    rotatePivotHint
                }
            }
            if let result = appState.unfoldResult {
                NamedSection("Pattern") {
                    infoRow("Faces",  "\(result.faces.count)")
                    infoRow("Tabs",   "\(result.tabs.count)")
                    infoRow("Pieces", "\(result.pieces.count)")
                    infoRow("Width",  String(format: "%.1f mm", result.pageWidth))
                    infoRow("Height", String(format: "%.1f mm", result.pageHeight))
                    if result.hasOverlaps {
                        Label("Overlaps detected",
                              systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: appState.settings, perform: { $0.save() })
    }

    // MARK: - Edit Flap panel

    private static let innerOptions: [(FlapMode, String)] = [
        (.switchPosition,  "Switch Flap Position"),
        (.onOn_ThisSide,   "ON-ON (This Side)"),
        (.offOn_OtherSide, "OFF-ON (Other Side)"),
        (.offOff_NoFlap,   "OFF-OFF (No Flap)"),
        (.onOn_BothSides,  "ON-ON (Both Sides)"),
        (.default,         "Do Nothing"),
    ]

    private static let borderOptions: [(FlapMode, String)] = [
        (.default,             "Do Nothing"),
        (.border_MountainFold, "Flap + Mountain Fold"),
        (.border_ValleyFold,   "Flap + Valley Fold"),
        (.border_NoFold,       "Flap without Fold"),
        (.border_NoFlap,       "No Flap"),
    ]

    @ViewBuilder
    private var editFlapSection: some View {
        Text("Click an edge on the canvas to apply the selected override.")
            .font(.caption).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        Divider()
        VStack(alignment: .leading, spacing: 6) {
            Text("Inner Edge (cut)").font(.caption).foregroundStyle(.secondary)
            Picker("", selection: $appState.selectedInnerFlapMode) {
                ForEach(Self.innerOptions, id: \.0) { mode, label in
                    Text(label).tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
        VStack(alignment: .leading, spacing: 6) {
            Text("Border Edge (mesh boundary)").font(.caption).foregroundStyle(.secondary)
            Picker("", selection: $appState.selectedBorderFlapMode) {
                ForEach(Self.borderOptions, id: \.0) { mode, label in
                    Text(label).tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
        Button("Reset All Flap Overrides") {
            appState.pushUndo()
            appState.flapOverrides.removeAll()
            Task { await appState.unfold(); appState.autoArrange() }
        }
        .buttonStyle(.borderless).foregroundStyle(.red)
        .font(.caption)
    }

    @ViewBuilder
    private var rotatePivotHint: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Phase 1", systemImage: "1.circle").font(.caption).foregroundStyle(.secondary)
            Text("Click a vertex dot to set the pivot (red).").font(.caption2)
            Label("Phase 2", systemImage: "2.circle").font(.caption).foregroundStyle(.secondary)
            Text("Click another vertex to start rotating.").font(.caption2)
            Label("Phase 3", systemImage: "3.circle").font(.caption).foregroundStyle(.secondary)
            Text("Drag to rotate. Click empty space to reset.").font(.caption2)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Sub-views

    @ViewBuilder
    private func rowField(_ label: String, value: Binding<Double>,
                           placeholder: String, unit: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField(placeholder, value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 56)
                .multilineTextAlignment(.trailing)
            Text(unit).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var paperDimensionsRow: some View {
        let p = appState.settings.print.effectivePaper
        HStack {
            Text("Size")
            Spacer()
            Text(String(format: "%.0f × %.0f mm", p.widthMm, p.heightMm))
                .foregroundStyle(.secondary)
                .font(.caption)
        }
    }

    @ViewBuilder
    private var meshInfoRow: some View {
        if let mesh = appState.mesh {
            VStack(alignment: .leading, spacing: 2) {
                Text(mesh.name.isEmpty ? "Untitled" : mesh.name)
                    .fontWeight(.semibold)
                Text("\(mesh.faces.count) faces · \(mesh.vertices.count) verts")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(.vertical, 2)
        } else {
            Text("No mesh loaded").foregroundStyle(.tertiary).italic()
        }
    }
}

// MARK: - NamedSection helper
// Wraps Section { content } header: { Text(title) } inside a concrete generic View,
// preventing Swift 6's Form content builder from choosing the @TableRowBuilder overload.

private struct NamedSection<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder _ content: () -> Content) {
        self.title   = title
        self.content = content()
    }

    var body: some View {
        Section { content } header: { Text(title) }
    }
}
