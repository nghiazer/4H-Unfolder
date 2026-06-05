import Foundation

protocol MeshLoaderProtocol {
    var supportedExtensions: [String] { get }
    func load(from url: URL) async throws -> Mesh
}

enum MeshLoadError: LocalizedError {
    case unsupportedFormat(String)
    case invalidFile(String)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let ext): "Unsupported format: .\(ext)"
        case .invalidFile(let msg):       "Invalid file: \(msg)"
        case .parseError(let msg):        "Parse error: \(msg)"
        }
    }
}

struct MeshLoaderFactory {
    private let loaders: [MeshLoaderProtocol] = [ObjMeshLoader(), PdoMeshLoader()]

    func load(from url: URL) async throws -> Mesh {
        let ext = url.pathExtension.lowercased()
        guard let loader = loaders.first(where: { $0.supportedExtensions.contains(ext) }) else {
            throw MeshLoadError.unsupportedFormat(ext)
        }
        return try await loader.load(from: url)
    }
}
