// MARK: - Kruskal's MST on face-adjacency dual graph
//
// Sorts graph edges by dihedral angle (ascending).
// Low angle ≈ flat surface → prefer as fold edge (stay connected).
// High angle ≈ sharp crease → becomes cut edge.
//
// Mirrors C# KruskalMstBuilder.

struct KruskalMSTBuilder {
    /// - Parameter tieBreakSeed: when nil (default), equal-weight edges keep their natural
    ///   dual-graph order (today's exact behaviour — deterministic, matches edge-ID order). When
    ///   set, equal-weight edges are ordered by a deterministic hash of (edgeId, seed) instead, so
    ///   different seeds can yield a different valid MST — used to retry the unfold when the
    ///   default MST produces overlaps.
    func build(graph: DualGraph, tieBreakSeed: Int? = nil) -> [GraphEdge] {
        let sorted: [GraphEdge]
        if let seed = tieBreakSeed {
            sorted = graph.edges.sorted { a, b in
                if a.weight != b.weight { return a.weight < b.weight }
                return Self.tieBreakKey(edgeId: a.sharedMeshEdgeId, seed: seed)
                     < Self.tieBreakKey(edgeId: b.sharedMeshEdgeId, seed: seed)
            }
        } else {
            sorted = graph.edges.sorted { $0.weight < $1.weight }
        }

        let uf = UnionFind(count: graph.nodes.count)
        var mst: [GraphEdge] = []
        let target = max(0, graph.nodes.count - 1)

        for edge in sorted {
            if uf.union(edge.faceA, edge.faceB) {
                mst.append(edge)
                if mst.count == target { break }
            }
        }
        return mst
    }

    private static func tieBreakKey(edgeId: Int, seed: Int) -> Int {
        var hasher = Hasher()
        hasher.combine(edgeId)
        hasher.combine(seed)
        return hasher.finalize()
    }
}
