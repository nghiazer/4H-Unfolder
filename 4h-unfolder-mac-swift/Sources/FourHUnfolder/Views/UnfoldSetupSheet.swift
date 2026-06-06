import SwiftUI
@testable import FourHUnfolderCore

// MARK: - Enums

enum ModelScaleUnit: String, CaseIterable, Identifiable {
    case mm, cm, inch

    var id: Self { self }

    var label: String {
        switch self {
        case .mm:   return "mm"
        case .cm:   return "cm"
        case .inch: return "in"
        }
    }

    var toMm: Double {
        switch self {
        case .mm:   return 1.0
        case .cm:   return 10.0
        case .inch: return 25.4
        }
    }
}

enum ModelScaleAxis: String, CaseIterable, Identifiable {
    case longest, width, height, depth

    var id: Self { self }

    var label: String {
        switch self {
        case .longest: return "Longest"
        case .width:   return "Width (X)"
        case .height:  return "Height (Y)"
        case .depth:   return "Depth (Z)"
        }
    }
}

// MARK: - Bounding box helper

struct ModelBBox {
    let w: Float  // X span
    let h: Float  // Y span
    let d: Float  // Z span

    static func from(mesh: Mesh) -> ModelBBox {
        guard !mesh.vertices.isEmpty else { return ModelBBox(w: 0, h: 0, d: 0) }
        let xs = mesh.vertices.map { $0.position.x }
        let ys = mesh.vertices.map { $0.position.y }
        let zs = mesh.vertices.map { $0.position.z }
        return ModelBBox(
            w: xs.max()! - xs.min()!,
            h: ys.max()! - ys.min()!,
            d: zs.max()! - zs.min()!
        )
    }

    func axisLength(for axis: ModelScaleAxis) -> Float {
        switch axis {
        case .longest: return max(w, max(h, d))
        case .width:   return w
        case .height:  return h
        case .depth:   return d
        }
    }
}

// MARK: - Sheet view

struct UnfoldSetupSheet: View {
    let mesh: Mesh
    /// Called with the computed scale (mm per model unit) when user confirms.
    var onConfirm: (_ scaleMmPerUnit: Float) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var targetValue: Double = 200
    @State private var unit: ModelScaleUnit = .mm
    @State private var axis: ModelScaleAxis = .longest

    // MARK: Computed

    private var bbox: ModelBBox { ModelBBox.from(mesh: mesh) }

    private var targetMm: Double { targetValue * unit.toMm }

    private var axisLengthModelUnits: Float { bbox.axisLength(for: axis) }

    private var scaleFactor: Float {
        guard axisLengthModelUnits > 1e-6 else { return 1.0 }
        return Float(targetMm) / axisLengthModelUnits
    }

    private var resultW: Float { bbox.w * scaleFactor }
    private var resultH: Float { bbox.h * scaleFactor }
    private var resultD: Float { bbox.d * scaleFactor }

    private var isValid: Bool {
        targetValue > 0 && scaleFactor.isFinite && scaleFactor > 0
    }

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title bar
            Text("Unfold Setup")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.bottom, 16)

            // ── Section 1: Bounding box ─────────────────────────────────────
            sectionHeader("Model Bounding Box (original units)")
            GroupBox {
                HStack(spacing: 20) {
                    bboxCell("W", value: bbox.w)
                    Divider().frame(height: 24)
                    bboxCell("H", value: bbox.h)
                    Divider().frame(height: 24)
                    bboxCell("D", value: bbox.d)
                }
                .padding(.vertical, 2)
            }
            .padding(.bottom, 14)

            // ── Section 2: Target size ─────────────────────────────────────
            sectionHeader("Target Size")
            GroupBox {
                HStack(spacing: 8) {
                    TextField("200", value: $targetValue, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)

                    Picker("", selection: $unit) {
                        ForEach(ModelScaleUnit.allCases) { u in
                            Text(u.label).tag(u)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 64)

                    Text("along")
                        .foregroundStyle(.secondary)

                    Picker("", selection: $axis) {
                        ForEach(ModelScaleAxis.allCases) { a in
                            Text(a.label).tag(a)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 110)
                }
            }
            .padding(.bottom, 14)

            // ── Section 3: Computed result ─────────────────────────────────
            sectionHeader("Result at This Scale")
            GroupBox {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                    resultRow("Scale factor",
                              String(format: "%.5g mm/unit", scaleFactor),
                              bold: true)
                    Divider()
                    resultRow("Width (X)",  fmtMm(resultW))
                    resultRow("Height (Y)", fmtMm(resultH))
                    resultRow("Depth (Z)",  fmtMm(resultD))
                }
                .padding(.vertical, 2)
            }
            .padding(.bottom, 20)

            // ── Buttons ────────────────────────────────────────────────────
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Unfold") {
                    onConfirm(scaleFactor)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
        }
        .padding(20)
        .frame(width: 400)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)
            .padding(.bottom, 4)
    }

    @ViewBuilder
    private func bboxCell(_ label: String, value: Float) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(String(format: "%.4g", value))
                .font(.callout)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func resultRow(_ label: String, _ value: String, bold: Bool = false) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
                .font(.callout)
            Text(value)
                .font(bold ? .callout.weight(.semibold) : .callout)
                .monospacedDigit()
                .foregroundStyle(bold ? Color.primary : Color.secondary)
        }
    }

    private func fmtMm(_ v: Float) -> String {
        if v.isFinite { return String(format: "%.1f mm", v) }
        return "—"
    }
}
