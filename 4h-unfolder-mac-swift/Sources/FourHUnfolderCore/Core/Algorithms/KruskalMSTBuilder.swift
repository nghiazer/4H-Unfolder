// MARK: - Kruskal's MST on face-adjacency dual graph
//
// Sorts graph edges by dihedral angle (ascending).
// Low angle ≈ flat surface → prefer as fold edge (stay connected).
// High angle ≈ sharp crease → becomes cut edge.
//
// Mirrors C# KruskalMstBuilder.

struct KruskalMSTBuilder {
    /// Dihedral-angle difference (radians) below which two edges are treated as close enough to
    /// perturb via `tieBreakSeed` — ≈1°, matches AppSettings' coplanarAngleDeg default. Real,
    /// non-symmetric geometry almost never has EXACTLY equal (bit-identical) dihedral angles, so
    /// without this tolerance a seed could only ever affect perfectly symmetric meshes (e.g. a
    /// regular tetrahedron) — the irregular/organic meshes most likely to have unavoidable
    /// overlaps would see zero benefit from retrying. Empirically calibrated on a
    /// randomly-perturbed test mesh: MST composition only starts varying meaningfully around this
    /// magnitude, with negligible (<0.03%) total-weight quality loss versus the true MST.
    static let tieEpsilonRad: Float = 0.017453292 // 1° in radians

    /// True when the dual graph has at least one pair of edges within `tieEpsilonRad` of each
    /// other — i.e. whether a `tieBreakSeed` could possibly select a different spanning tree at
    /// all. Lets callers skip an expensive multi-seed retry when it's provably futile (most
    /// irregular/organic meshes with well-separated dihedral angles have no near-ties, so
    /// retrying would waste full pipeline passes for zero chance of a different result).
    /// Necessary but not sufficient: a near-tie existing somewhere doesn't guarantee THIS
    /// particular pair ever competes for the same spanning-tree slot, only that it's possible.
    static func hasPotentialTies(graph: DualGraph) -> Bool {
        let weights = graph.edges.map(\.weight).sorted()
        guard weights.count > 1 else { return false }
        for i in 1..<weights.count where weights[i] - weights[i - 1] < tieEpsilonRad {
            return true
        }
        return false
    }

    /// - Parameter tieBreakSeed: when nil (default), edges are ordered strictly by weight
    ///   (today's exact behaviour). When set, each edge's weight is perturbed by a small
    ///   deterministic offset derived from (edgeId, seed) before sorting — bounded so only edges
    ///   within `tieEpsilonRad` of each other can ever swap relative order — so different seeds
    ///   can yield a different, still near-minimal, spanning tree even when no two edges are
    ///   exactly tied.
    func build(graph: DualGraph, tieBreakSeed: Int? = nil) -> [GraphEdge] {
        let sorted: [GraphEdge]
        if let seed = tieBreakSeed {
            // Compute each edge's perturbed key once (not per comparison), then sort by it.
            sorted = graph.edges
                .map { edge -> (GraphEdge, Float) in
                    let offset = Self.tieBreakOffset(edgeId: edge.sharedMeshEdgeId, seed: seed)
                    return (edge, edge.weight + Self.tieEpsilonRad * offset)
                }
                .sorted { $0.1 < $1.1 }
                .map(\.0)
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

    /// Deterministic pseudo-random value in [-0.5, 0.5) derived from (edgeId, seed). Bounded so
    /// that two edges' perturbed weights can only swap relative order when their true weight
    /// difference is strictly less than tieEpsilonRad (worst case: +0.5·eps vs. −0.5·eps).
    private static func tieBreakOffset(edgeId: Int, seed: Int) -> Float {
        var hasher = Hasher()
        hasher.combine(edgeId)
        hasher.combine(seed)
        let bits = UInt64(bitPattern: Int64(hasher.finalize()))
        return Float(bits) / Float(UInt64.max) - 0.5
    }
}
