import SwiftUI
@testable import FourHUnfolderCore

// MARK: - Preferences window (⌘,)
//
// Four tabs: General, Print, Canvas, 3D View
// Each tab writes through $appState.settings, which saves on change.

struct PreferencesView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("General", systemImage: "gearshape") }

            PrintTab()
                .tabItem { Label("Print", systemImage: "printer") }

            CanvasTab()
                .tabItem { Label("Canvas", systemImage: "rectangle.and.pencil.and.ellipsis") }

            View3DTab()
                .tabItem { Label("3D View", systemImage: "cube") }
        }
        .environmentObject(appState)
        .padding(20)
        .frame(width: 480, height: 400)
        .onChange(of: appState.settings) { _ in appState.settings.save() }
    }
}

// MARK: - General tab

private struct GeneralTab: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section("Display") {
                Picker("Unit", selection: $appState.settings.general.displayUnit) {
                    Text("Millimeters (mm)").tag("mm")
                    Text("Centimeters (cm)").tag("cm")
                    Text("Inches (in)").tag("in")
                }
                .pickerStyle(.menu)

                Picker("Theme", selection: $appState.settings.general.themeMode) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
            }

            Section("Behaviour") {
                Toggle("Skip orientation dialog on open",
                       isOn: $appState.settings.general.skipOrientationDialog)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Print tab

private struct PrintTab: View {
    @EnvironmentObject var appState: AppState

    private var ps: Binding<AppSettings.PrintSettings> { $appState.settings.print }

    var body: some View {
        Form {
            Section("Glue Tabs") {
                Picker("Shape", selection: ps.glueTabShape) {
                    ForEach(AppSettings.PrintSettings.TabShape.allCases) { shape in
                        Text(shape.rawValue).tag(shape)
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    Text("Depth")
                    Spacer()
                    TextField("mm", value: ps.glueTabDepthMm, format: .number)
                        .frame(width: 60).multilineTextAlignment(.trailing)
                    Text("mm")
                }
                HStack {
                    Text("Side Angle")
                    Spacer()
                    TextField("°", value: ps.glueTabSideAngleDeg, format: .number)
                        .frame(width: 60).multilineTextAlignment(.trailing)
                    Text("°")
                }
                Toggle("Alternate Flaps", isOn: ps.alternateFlaps)
                Toggle("Merge Adjacent Flaps", isOn: ps.mergeAdjacentFlaps)
                Toggle("Include Glue Tabs", isOn: ps.includeGlueTabs)
            }

            Section("Lines") {
                LabeledContent("Fold Line Color") {
                    ColorHexField(hex: ps.foldLineColor)
                }
                LabeledContent("Cut Line Color") {
                    ColorHexField(hex: ps.cutLineColor)
                }
                Toggle("Print Fold Lines", isOn: ps.printFoldLines)
                Toggle("Print Cut Lines",  isOn: ps.printCutLines)
                Toggle("Hide Coplanar Folds", isOn: ps.hideCoplanarFolds)
                HStack {
                    Text("Coplanar Threshold")
                    Spacer()
                    TextField("°", value: ps.coplanarAngleDeg, format: .number)
                        .frame(width: 60).multilineTextAlignment(.trailing)
                    Text("°")
                }
            }

            Section("Layout") {
                HStack {
                    Text("Margin")
                    Spacer()
                    TextField("mm", value: ps.marginMm, format: .number)
                        .frame(width: 60).multilineTextAlignment(.trailing)
                    Text("mm")
                }
                HStack {
                    Text("SVG Scale")
                    Spacer()
                    TextField("×", value: ps.svgScaleFactor, format: .number)
                        .frame(width: 60).multilineTextAlignment(.trailing)
                }
                Toggle("Grayscale Output", isOn: ps.grayscaleOutput)
                Toggle("Include Page Label", isOn: ps.includePageLabel)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Canvas tab

private struct CanvasTab: View {
    @EnvironmentObject var appState: AppState

    private var v2d: Binding<AppSettings.View2DSettings> { $appState.settings.view2D }

    var body: some View {
        Form {
            Section("Colours") {
                LabeledContent("Canvas Background") { ColorHexField(hex: v2d.canvasBackground) }
                LabeledContent("Face Fill")          { ColorHexField(hex: v2d.faceFillColor) }
                LabeledContent("Fold Line")          { ColorHexField(hex: v2d.foldLineColor) }
                LabeledContent("Cut Line")           { ColorHexField(hex: v2d.cutLineColor) }
                LabeledContent("Glue Tab")           { ColorHexField(hex: v2d.glueTabColor) }
            }

            Section("Grid") {
                HStack {
                    Text("Grid Size")
                    Spacer()
                    TextField("mm", value: v2d.gridSizeMm, format: .number)
                        .frame(width: 60).multilineTextAlignment(.trailing)
                    Text("mm")
                }
                Toggle("Show Grid",        isOn: v2d.showGrid)
                Toggle("Snap to Grid",     isOn: v2d.snapToGrid)
            }

            Section("Overlays") {
                Toggle("Show Glue Tabs",   isOn: v2d.showGlueTabs)
                Toggle("Show Textures",    isOn: v2d.showTexture)
                Toggle("Show Face Numbers",isOn: v2d.showFaceNumbers)
                Toggle("Show Fold Angles", isOn: v2d.showFoldAngles)
            }

            Section("Line Widths") {
                HStack {
                    Text("Fold")
                    Spacer()
                    TextField("pt", value: v2d.foldLineWidth, format: .number)
                        .frame(width: 50).multilineTextAlignment(.trailing)
                    Text("pt")
                }
                HStack {
                    Text("Cut")
                    Spacer()
                    TextField("pt", value: v2d.cutLineWidth, format: .number)
                        .frame(width: 50).multilineTextAlignment(.trailing)
                    Text("pt")
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - 3D View tab

private struct View3DTab: View {
    @EnvironmentObject var appState: AppState

    private var v3d: Binding<AppSettings.View3DSettings> { $appState.settings.view3D }

    var body: some View {
        Form {
            Section("Colours") {
                LabeledContent("Background") { ColorHexField(hex: v3d.backgroundColor) }
                LabeledContent("Face Color") { ColorHexField(hex: v3d.faceColor) }
            }

            Section("Lighting") {
                HStack {
                    Text("Ambient")
                    Slider(value: v3d.ambientIntensity, in: 0...1)
                    Text(String(format: "%.0f%%", appState.settings.view3D.ambientIntensity * 100))
                        .frame(width: 36)
                }
                HStack {
                    Text("Directional")
                    Slider(value: v3d.directionalIntensity, in: 0...1)
                    Text(String(format: "%.0f%%", appState.settings.view3D.directionalIntensity * 100))
                        .frame(width: 36)
                }
            }

            Section("Camera") {
                HStack {
                    Text("Field of View")
                    Spacer()
                    TextField("°", value: v3d.cameraFOV, format: .number)
                        .frame(width: 60).multilineTextAlignment(.trailing)
                    Text("°")
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Small hex colour field

private struct ColorHexField: View {
    var hex: Binding<String>

    var body: some View {
        HStack(spacing: 6) {
            // Colour swatch
            if let c = Color(hex: hex.wrappedValue) {
                c.frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.4)))
            }
            TextField("#rrggbb", text: hex)
                .frame(width: 80)
                .textFieldStyle(.roundedBorder)
                .font(.system(.caption, design: .monospaced))
        }
    }
}
