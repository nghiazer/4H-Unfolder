using FluentAssertions;
using FourHUnfolder.Domain.DualGraph;
using FourHUnfolder.Geometry.Algorithms;
using Xunit;

namespace FourHUnfolder.Tests;

public class MstAlgorithmTests
{
    // ── helpers ──────────────────────────────────────────────────────────

    private static DualGraph BuildGraph(
        int nodeCount,
        params (int a, int b, float w)[] edges)
    {
        var g = new DualGraph();
        for (int i = 0; i < nodeCount; i++)
            g.Nodes.Add(new GraphNode(i));

        foreach (var (a, b, w) in edges)
        {
            int id = g.Edges.Count;
            var ge = new GraphEdge(id, a, b, sharedMeshEdgeId: id, weight: w);
            g.Edges.Add(ge);
            g.Nodes[a].GraphEdgeIds.Add(id);
            g.Nodes[b].GraphEdgeIds.Add(id);
        }

        return g;
    }

    // ── tests ─────────────────────────────────────────────────────────────

    [Fact]
    public void EmptyGraph_ReturnsNoEdges()
    {
        var mst = new KruskalMstBuilder().Build(new DualGraph());
        mst.Should().BeEmpty();
    }

    [Fact]
    public void SingleNode_ReturnsNoEdges()
    {
        var g = BuildGraph(nodeCount: 1);
        new KruskalMstBuilder().Build(g).Should().BeEmpty();
    }

    [Fact]
    public void LineGraph_ProducesNMinus1Edges()
    {
        // 0 — 1 — 2 — 3
        var g   = BuildGraph(4, (0,1,1f), (1,2,1f), (2,3,1f));
        var mst = new KruskalMstBuilder().Build(g);
        mst.Should().HaveCount(3);
    }

    [Fact]
    public void MinimumWeightEdgesArePreferred()
    {
        // Square: four nodes, one high-weight diagonal should be excluded
        var g = BuildGraph(4,
            (0, 1, 1f),
            (1, 2, 2f),
            (2, 3, 3f),
            (0, 3, 100f),   // high-weight shortcut — should be excluded
            (0, 2,  50f));  // high-weight diagonal — should be excluded

        var mst = new KruskalMstBuilder().Build(g);

        mst.Should().HaveCount(3);
        mst.Sum(e => e.Weight).Should().BeLessThan(10f, "only low-weight edges enter the MST");
    }

    [Fact]
    public void MST_Acyclic_ConnectsAllNodes()
    {
        // Five nodes, fully connected
        var edges = new List<(int, int, float)>();
        float w = 1f;
        for (int i = 0; i < 5; i++)
        for (int j = i + 1; j < 5; j++)
            edges.Add((i, j, w++));

        var g   = BuildGraph(5, edges.ToArray());
        var mst = new KruskalMstBuilder().Build(g);

        mst.Should().HaveCount(4, "MST has n-1 edges");

        // Verify no duplicate node pairs (would indicate a cycle)
        var seen = new HashSet<(int, int)>();
        foreach (var e in mst)
        {
            var key = (Math.Min(e.FaceA, e.FaceB), Math.Max(e.FaceA, e.FaceB));
            seen.Add(key).Should().BeTrue("each pair should appear only once");
        }
    }

    [Fact]
    public void DisconnectedGraph_ReturnsBestPartialSpanningTree()
    {
        // Two disconnected components: {0,1} and {2,3}
        var g = BuildGraph(4,
            (0, 1, 1f),
            (2, 3, 1f));

        var mst = new KruskalMstBuilder().Build(g);

        // Kruskal picks both available edges (can't connect them)
        mst.Should().HaveCount(2);
    }

    // ── tieBreakSeed (used by UnfoldService's multi-seed overlap retry) ─────────────────────

    /// All-equal-weight K4 — mirrors a regular tetrahedron's dual graph, where every pair of the
    /// 4 faces shares an edge with the same dihedral angle, so every one of the 6 edges ties.
    private static DualGraph BuildAllTiedK4() => BuildGraph(4,
        (0, 1, 1f), (0, 2, 1f), (0, 3, 1f), (1, 2, 1f), (1, 3, 1f), (2, 3, 1f));

    [Fact]
    public void TieBreakSeed_Null_MatchesDefaultNoSeedParameter()
    {
        var g = BuildAllTiedK4();

        var withoutSeedParam = new KruskalMstBuilder().Build(g);
        var withExplicitNull = new KruskalMstBuilder().Build(g, tieBreakSeed: null);

        withExplicitNull.Select(e => e.Id).Should().Equal(withoutSeedParam.Select(e => e.Id),
            "an explicit null seed must match omitting the parameter entirely");
    }

    [Fact]
    public void TieBreakSeed_AlwaysReturnsValidSpanningTree()
    {
        var g = BuildAllTiedK4();
        foreach (var seed in new[] { 0, 1, 2, 5, 42 })
        {
            new KruskalMstBuilder().Build(g, tieBreakSeed: seed)
                .Should().HaveCount(3, $"seed {seed} must still produce a valid n-1 spanning tree");
        }
    }

    [Fact]
    public void TieBreakSeed_ProducesVariedMstsAcrossEqualWeightTies()
    {
        var g = BuildAllTiedK4();

        var distinctResults = Enumerable.Range(0, 20)
            .Select(seed => new KruskalMstBuilder().Build(g, tieBreakSeed: seed))
            .Select(mst => string.Join(",", mst.Select(e => e.Id).OrderBy(id => id)))
            .Distinct()
            .Count();

        distinctResults.Should().BeGreaterThan(1,
            "different tie-break seeds must be able to select a different spanning tree " +
            "among equal-weight ties — otherwise the multi-seed overlap retry can never help");
    }
}
