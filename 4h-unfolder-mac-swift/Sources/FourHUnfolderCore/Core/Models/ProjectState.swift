import Foundation

// Serializable snapshot of a project — stored as state.json inside the .4hu bundle.
// Dictionary keys are Int (mesh edge IDs); JSON encodes them as string-integer keys.

struct ProjectState: Codable {
    var meshFileName: String                    // filename inside bundle, e.g. "cube.obj"
    var edgeOverrides: [Int: EdgeType]          // meshEdgeId → forced type
    var flapOverrides: [Int: FlapOverride]      // meshEdgeId → FlapOverride
    var settings: AppSettings
    var appVersion: String = "0.0.0.1-alpha"
    /// pieceIndex (stringified) → [x, y] offset in mm
    var pieceOffsets: [String: [Float]] = [:]
}
