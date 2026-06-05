import Foundation

// Saves and loads .4hu project bundles — a standard ZIP archive containing:
//   state.json    — ProjectState (edge/flap overrides, settings, mesh filename)
//   <mesh>.<ext>  — original mesh file (OBJ or PDO), copied verbatim
//
// Compatible with the C# .4hu bundle format for cross-platform project exchange.
// ZIP operations use the system /usr/bin/zip and /usr/bin/unzip tools (always
// present on macOS), avoiding any external SPM dependency.

struct ProjectSerializer {

    // MARK: - Error

    enum ProjectError: Error, LocalizedError {
        case noSourceMesh
        case zipFailed(String)
        case invalidBundle(String)

        var errorDescription: String? {
            switch self {
            case .noSourceMesh:
                "No mesh loaded — open an OBJ or PDO file before saving a project."
            case .zipFailed(let msg):
                "ZIP operation failed: \(msg)"
            case .invalidBundle(let msg):
                "Invalid .4hu bundle: \(msg)"
            }
        }
    }

    // MARK: - Save

    /// Bundles meshURL + state into a .4hu ZIP archive at `destURL`.
    func save(
        meshURL: URL,
        edgeOverrides: [Int: EdgeType],
        flapOverrides: [Int: FlapOverride],
        settings: AppSettings,
        to destURL: URL
    ) throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        // Copy mesh file into staging dir
        let meshFileName = meshURL.lastPathComponent
        try FileManager.default.copyItem(
            at: meshURL,
            to: tmp.appendingPathComponent(meshFileName)
        )

        // Write state.json
        let state = ProjectState(
            meshFileName: meshFileName,
            edgeOverrides: edgeOverrides,
            flapOverrides: flapOverrides,
            settings: settings
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let stateData = try encoder.encode(state)
        try stateData.write(to: tmp.appendingPathComponent("state.json"))

        // Remove existing bundle if present
        try? FileManager.default.removeItem(at: destURL)

        // Zip staging dir → dest
        try zipDirectory(tmp, to: destURL)
    }

    // MARK: - Load

    /// Extracts the .4hu bundle and returns the decoded state + path to the
    /// extracted mesh file. The caller MUST delete `tempDir` after loading the mesh.
    func load(from bundleURL: URL) throws -> (state: ProjectState, meshURL: URL, tempDir: URL) {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

        do {
            try unzipFile(bundleURL, to: tmp)
        } catch {
            try? FileManager.default.removeItem(at: tmp)
            throw error
        }

        let stateURL = tmp.appendingPathComponent("state.json")
        guard FileManager.default.fileExists(atPath: stateURL.path) else {
            try? FileManager.default.removeItem(at: tmp)
            throw ProjectError.invalidBundle("state.json not found in bundle")
        }

        let stateData = try Data(contentsOf: stateURL)
        let state: ProjectState
        do {
            state = try JSONDecoder().decode(ProjectState.self, from: stateData)
        } catch {
            try? FileManager.default.removeItem(at: tmp)
            throw ProjectError.invalidBundle("state.json is malformed: \(error.localizedDescription)")
        }

        let meshURL = tmp.appendingPathComponent(state.meshFileName)
        guard FileManager.default.fileExists(atPath: meshURL.path) else {
            try? FileManager.default.removeItem(at: tmp)
            throw ProjectError.invalidBundle(
                "Mesh file '\(state.meshFileName)' not found in bundle"
            )
        }

        return (state, meshURL, tmp)
    }

    // MARK: - ZIP helpers (system tools, no external deps)

    private func zipDirectory(_ sourceDir: URL, to destFile: URL) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        p.currentDirectoryURL = sourceDir
        p.arguments = ["-r", destFile.path, "."]
        let errPipe = Pipe()
        p.standardError = errPipe
        p.standardOutput = FileHandle.nullDevice
        try p.run()
        p.waitUntilExit()
        if p.terminationStatus != 0 {
            let msg = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(),
                             encoding: .utf8) ?? "unknown error"
            throw ProjectError.zipFailed(msg.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private func unzipFile(_ zipFile: URL, to destDir: URL) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        p.arguments = ["-o", zipFile.path, "-d", destDir.path]
        let errPipe = Pipe()
        p.standardError = errPipe
        p.standardOutput = FileHandle.nullDevice
        try p.run()
        p.waitUntilExit()
        if p.terminationStatus != 0 {
            let msg = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(),
                             encoding: .utf8) ?? "unknown error"
            throw ProjectError.zipFailed(msg.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}
