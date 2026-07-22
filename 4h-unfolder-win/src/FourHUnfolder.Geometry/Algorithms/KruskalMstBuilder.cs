using FourHUnfolder.Domain.DualGraph;

namespace FourHUnfolder.Geometry.Algorithms;

/// <summary>
/// Kruskal's algorithm with path-compressed Union-Find.
/// Returns n-1 edges that form a minimum spanning tree of the dual graph.
/// MST edges → Fold; non-MST interior edges → Cut.
/// </summary>
public class KruskalMstBuilder
{
    /// <param name="tieBreakSeed">
    /// When null (default), equal-weight edges keep their natural dual-graph order (today's
    /// exact behaviour — deterministic, matches edge-ID order). When set, equal-weight edges are
    /// ordered by a deterministic hash of (edgeId, seed) instead, so different seeds can yield a
    /// different valid MST — used to retry the unfold when the default MST produces overlaps.
    /// </param>
    public IReadOnlyList<GraphEdge> Build(DualGraph graph, int? tieBreakSeed = null)
    {
        if (graph.Nodes.Count == 0) return Array.Empty<GraphEdge>();

        var sortedEdges = tieBreakSeed is int seed
            ? graph.Edges.OrderBy(e => e.Weight).ThenBy(e => TieBreakKey(e.SharedMeshEdgeId, seed)).ToList()
            : graph.Edges.OrderBy(e => e.Weight).ToList();

        // Map face IDs to contiguous array indices for Union-Find
        var faceIds = graph.Nodes.Select(n => n.FaceId).ToList();
        var faceIdx = faceIds.Select((id, i) => (id, i)).ToDictionary(t => t.id, t => t.i);
        int n       = faceIds.Count;
        var uf      = new UnionFind(n);

        var mst = new List<GraphEdge>(n - 1);

        foreach (var edge in sortedEdges)
        {
            if (uf.Union(faceIdx[edge.FaceA], faceIdx[edge.FaceB]))
            {
                mst.Add(edge);
                if (mst.Count == n - 1) break;  // MST complete
            }
        }

        return mst;
    }

    private static int TieBreakKey(int edgeId, int seed) => HashCode.Combine(edgeId, seed);
}
