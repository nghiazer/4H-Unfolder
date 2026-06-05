// MARK: - Kruskal's MST on face-adjacency dual graph
//
// Sorts graph edges by dihedral angle (ascending).
// Low angle ≈ flat surface → prefer as fold edge (stay connected).
// High angle ≈ sharp crease → becomes cut edge.
//
// Mirrors C# KruskalMstBuilder.

struct KruskalMSTBuilder {
    func build(graph: DualGraph) -> [GraphEdge] {
        let sorted = graph.edges.sorted { $0.weight < $1.weight }
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
}
