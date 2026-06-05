import Foundation

struct AppSettings: Codable {
    var tabHeightMm: Float = 5.0
    var tabAngleDeg: Float = 45.0
    var tabStyle: TabStyle = .trapezoid
    var autoFitOnUnfold: Bool = true
    var showEdgeLabels: Bool = true
    var showFaceNormals: Bool = false

    enum TabStyle: String, Codable, CaseIterable, Identifiable {
        case trapezoid, rectangle, none
        var id: String { rawValue }
    }

    private static let defaultsKey = "AppSettings"

    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let s = try? JSONDecoder().decode(AppSettings.self, from: data)
        else { return AppSettings() }
        return s
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: AppSettings.defaultsKey)
    }
}
