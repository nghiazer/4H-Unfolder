// MARK: - Identifies connected paper pieces using Union-Find over fold edges
//
// Mirrors C# PieceComputer.

struct PieceComputer {
    func computePieces(mesh: Mesh) -> [[Int]] {
        let uf = UnionFind(count: mesh.faces.count)

        for edge in mesh.edges where edge.type == .fold && edge.connectsFaces {
            uf.union(edge.faceA, edge.faceB)
        }

        // Group face IDs by their component root
        var groups: [Int: [Int]] = [:]
        for face in mesh.faces {
            let root = uf.find(face.id)
            groups[root, default: []].append(face.id)
        }

        // Sort groups by root, sort face IDs within each group
        return groups
            .sorted { $0.key < $1.key }
            .map { $0.value.sorted() }
    }
}
