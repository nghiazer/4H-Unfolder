import Foundation

// MARK: - Paper size

struct PaperSizeModel: Codable, Equatable, Hashable, Identifiable {
    var name: String
    var widthMm: Double
    var heightMm: Double

    var id: String { name }

    func landscape() -> PaperSizeModel { PaperSizeModel(name: name + " L", widthMm: heightMm, heightMm: widthMm) }
    func portrait()  -> PaperSizeModel { PaperSizeModel(name: name + " P", widthMm: min(widthMm,heightMm), heightMm: max(widthMm,heightMm)) }

    static let a4     = PaperSizeModel(name: "A4",     widthMm: 210,  heightMm: 297)
    static let a3     = PaperSizeModel(name: "A3",     widthMm: 297,  heightMm: 420)
    static let a2     = PaperSizeModel(name: "A2",     widthMm: 420,  heightMm: 594)
    static let a1     = PaperSizeModel(name: "A1",     widthMm: 594,  heightMm: 841)
    static let letter = PaperSizeModel(name: "Letter", widthMm: 215.9,heightMm: 279.4)
    static let legal  = PaperSizeModel(name: "Legal",  widthMm: 215.9,heightMm: 355.6)

    static let presets: [PaperSizeModel] = [.a4, .a3, .a2, .a1, .letter, .legal]
}

// MARK: - AppSettings hierarchy (mirrors C# AppSettings)

struct AppSettings: Codable, Equatable {

    // MARK: Print / export settings
    struct PrintSettings: Codable, Equatable {
        var glueTabShape: TabShape = .trapezoid
        var glueTabDepthMm: Double = 5.0
        var glueTabSideAngleDeg: Double = 45.0
        var alternateFlaps: Bool = false

        var foldLineColor: String = "#4169e1"
        var foldLineWidth: Double = 0.8
        var foldLineDash: String  = "4,2"

        var cutLineColor: String = "#ff0000"
        var cutLineWidth: Double = 1.0

        var grayscaleOutput: Bool = false
        var includeGlueTabs: Bool = true
        var includePageLabel: Bool = true
        var printFoldLines: Bool = true
        var printCutLines: Bool = true

        var svgScaleFactor: Double = 1.0
        var marginMm: Double = 5.0
        var bleedMm: Double = 0.0

        var paperSize: PaperSizeModel = .a4
        var isLandscape: Bool = false

        var effectivePaper: PaperSizeModel {
            let w = paperSize.widthMm, h = paperSize.heightMm
            if isLandscape {
                return PaperSizeModel(name: paperSize.name, widthMm: max(w, h), heightMm: min(w, h))
            } else {
                return PaperSizeModel(name: paperSize.name, widthMm: min(w, h), heightMm: max(w, h))
            }
        }

        enum TabShape: String, Codable, CaseIterable, Identifiable {
            case trapezoid = "Trapezoid"
            case rectangle = "Rectangle"
            case triangle  = "Triangle"
            var id: String { rawValue }
        }
    }

    // MARK: 2D canvas settings
    struct View2DSettings: Codable, Equatable {
        var canvasBackground: String = "#f0f0f0"
        var paperColor: String = "#ffffff"
        var gridSizeMm: Double = 10.0
        var showGrid: Bool = false
        var snapToGrid: Bool = false
        var defaultPixelsPerMm: Double = 3.0

        var faceFillColor: String = "#cce0ff"
        var foldLineColor: String = "#4169e1"
        var foldLineWidth: Double = 0.8
        var foldLineDash: String  = "4,2"
        var cutLineColor: String  = "#ff0000"
        var cutLineWidth: Double  = 1.0
        var glueTabColor: String  = "#a8d5a2"

        var showFaceNumbers: Bool = false
        var showEdgeIds: Bool = false
        var showFoldAngles: Bool = false
        var showGlueTabs: Bool = true
        var showTexture: Bool = true
        var showPartNames: Bool = true
        var highlightFoldLines: Bool = false
    }

    // MARK: 3D viewport settings
    struct View3DSettings: Codable, Equatable {
        var backgroundColor: String = "#1e1e1e"
        var faceColor: String       = "#8dc8ff"
        var backFaceColor: String   = "#222244"
        var faceOpacity: Double = 1.0
        var displayMode: DisplayMode = .solidEdges
        var showCoordinateSystem: Bool = false
        var ambientIntensity: Double = 0.4
        var directionalIntensity: Double = 0.8
        var cameraFOV: Double = 60.0

        enum DisplayMode: String, Codable { case solid, solidEdges, wireframe }
    }

    // MARK: General
    struct GeneralSettings: Codable, Equatable {
        var displayUnit: String = "mm"
        var themeMode: String = "system"
        var skipOrientationDialog: Bool = false

        /// Units the OBJ/PDO mesh was authored in. Applied as a multiplier
        /// that converts mesh coordinates to millimetres before unfolding.
        var meshUnits: String = "mm"   // "mm" | "cm" | "m" | "in"

        /// Scale factor that converts one OBJ unit → mm.
        var meshScaleToMm: Float {
            switch meshUnits {
            case "cm": return 10
            case "m":  return 1000
            case "in": return 25.4
            default:   return 1       // mm (no conversion)
            }
        }
    }

    var print:   PrintSettings   = PrintSettings()
    var view2D:  View2DSettings  = View2DSettings()
    var view3D:  View3DSettings  = View3DSettings()
    var general: GeneralSettings = GeneralSettings()

    // MARK: - Persistence

    private static let storageURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("4H-Unfolder/settings.json")
    }()

    static func load() -> AppSettings {
        guard let data = try? Data(contentsOf: storageURL),
              let s    = try? JSONDecoder().decode(AppSettings.self, from: data)
        else { return AppSettings() }
        return s
    }

    func save() {
        let url = AppSettings.storageURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                  withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: url)
    }
}
