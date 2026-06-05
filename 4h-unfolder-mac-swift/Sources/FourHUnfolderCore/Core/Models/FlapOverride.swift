import Foundation

// MARK: - FlapMode mirrors C# FlapMode enum exactly

enum FlapMode: String, Codable, CaseIterable, Identifiable {
    // Inner (interior) edges
    case `default`          = "Default"
    case switchPosition     = "SwitchPosition"
    case onOn_ThisSide      = "OnOn_ThisSide"
    case offOn_OtherSide    = "OffOn_OtherSide"
    case offOff_NoFlap      = "OffOff_NoFlap"
    case onOn_BothSides     = "OnOn_BothSides"

    // Border (boundary) edges
    case border_MountainFold = "Border_MountainFold"
    case border_ValleyFold   = "Border_ValleyFold"
    case border_NoFold       = "Border_NoFold"
    case border_NoFlap       = "Border_NoFlap"

    var id: String { rawValue }

    var isBorderMode: Bool {
        switch self {
        case .border_MountainFold, .border_ValleyFold, .border_NoFold, .border_NoFlap: true
        default: false
        }
    }

    var displayName: String {
        switch self {
        case .default:           "Default"
        case .switchPosition:    "Switch Side"
        case .onOn_ThisSide:     "Tab This Side"
        case .offOn_OtherSide:   "Tab Other Side"
        case .offOff_NoFlap:     "No Tab"
        case .onOn_BothSides:    "Tab Both Sides"
        case .border_MountainFold: "Mountain Fold"
        case .border_ValleyFold:   "Valley Fold"
        case .border_NoFold:       "No Fold"
        case .border_NoFlap:       "No Flap"
        }
    }
}

// MARK: - Per-edge override

struct FlapOverride: Codable, Equatable {
    var mode: FlapMode
    var primaryFaceId: Int = -1

    // Mirrors C# FlapOverride.Serialize() / Deserialize()
    func serialize() -> String { "\(mode.rawValue),\(primaryFaceId)" }

    static func deserialize(_ s: String) -> FlapOverride? {
        let parts = s.split(separator: ",", maxSplits: 1)
        guard parts.count == 2,
              let mode = FlapMode(rawValue: String(parts[0])),
              let fid  = Int(parts[1])
        else { return nil }
        return FlapOverride(mode: mode, primaryFaceId: fid)
    }
}
