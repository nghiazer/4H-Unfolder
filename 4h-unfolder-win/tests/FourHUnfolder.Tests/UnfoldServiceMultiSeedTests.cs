using System.Numerics;
using FluentAssertions;
using FourHUnfolder.Application.Services;
using FourHUnfolder.Domain.Models;
using Xunit;

namespace FourHUnfolder.Tests;

/// <summary>
/// GĐ3.2: when the default MST (natural Kruskal tie-break) produces overlaps, UnfoldService.Unfold
/// retries with alternate tie-break seeds and keeps whichever has the fewest overlapping face
/// pairs. These tests cover the two safety properties that matter regardless of any specific
/// mesh's overlap outcome — the actual "does retrying ever change the picked MST" behaviour is
/// covered separately at the KruskalMstBuilder level (MstAlgorithmTests.TieBreakSeed_*), since
/// constructing a real mesh where a specific tie-break provably reduces overlap is not easily
/// deterministic.
/// </summary>
public class UnfoldServiceMultiSeedTests
{
    /// Regular tetrahedron — same construction used by UnfoldEngineTests. Its dual graph is K4
    /// with all-equal dihedral angles (every pair of the 4 faces is geometrically equivalent),
    /// so Kruskal ties on every edge — exactly the scenario the retry logic is built for.
    private static Mesh Tetrahedron()
    {
        var mesh = new Mesh();
        mesh.AddVertex(new Vertex(0, new Vector3(0, 0, 0)));
        mesh.AddVertex(new Vertex(1, new Vector3(1, 0, 0)));
        mesh.AddVertex(new Vertex(2, new Vector3(0.5f, 0.8660254f, 0)));
        mesh.AddVertex(new Vertex(3, new Vector3(0.5f, 0.2886751f, 0.8164966f)));

        mesh.AddFace(0, 1, 2);
        mesh.AddFace(0, 3, 1);
        mesh.AddFace(1, 3, 2);
        mesh.AddFace(0, 2, 3);
        return mesh;
    }

    [Fact]
    public void Unfold_NoOverlaps_ReturnsValidResult()
    {
        var mesh   = Tetrahedron();
        var result = new UnfoldService().Unfold(mesh);

        result.HasOverlaps.Should().BeFalse("a tetrahedron's net never self-overlaps");
        result.Faces.Should().HaveCount(4);
    }

    [Fact]
    public void Unfold_SeedCountZero_DisablesRetry_StillReturnsValidResult()
    {
        var mesh   = Tetrahedron();
        var result = new UnfoldService().Unfold(mesh, seedCount: 0);

        result.Faces.Should().HaveCount(4);
    }

    [Fact]
    public void Unfold_MeshEdgeTypes_AreConsistentWithReturnedFoldFlags()
    {
        // The core safety property: EdgeMarker.Mark mutates mesh.Edges[].Type as a side effect on
        // every retry attempt. After Unfold() returns, the mesh MUST be re-stamped with the
        // WINNING candidate's fold set — not whichever seed happened to run last in the retry
        // loop — because MainViewModel.IsEdgeFold and glue-tab/canvas code read mesh.Edges[id].Type
        // directly, independent of the returned UnfoldResult.
        var mesh   = Tetrahedron();
        var result = new UnfoldService().Unfold(mesh);

        foreach (var face in result.Faces)
        {
            for (int i = 0; i < 3; i++)
            {
                int meshEdgeId = face.MeshEdgeIds[i];
                if (meshEdgeId < 0) continue;

                bool meshSaysFold = mesh.Edges[meshEdgeId].Type == EdgeType.Fold;
                face.EdgeIsFold[i].Should().Be(meshSaysFold,
                    $"face {face.FaceId} edge {i} (meshEdgeId {meshEdgeId}): the returned " +
                    "UnfoldResult and the mesh's persistent edge-type state must agree");
            }
        }
    }

    [Fact]
    public void Unfold_RepeatedCalls_AreDeterministic()
    {
        // Same mesh, same default seedCount → same result every time (no hidden randomness
        // leaking into the public API surface; tie-break seeds are always tried in the same
        // 0..<seedCount order starting from the same deterministic baseline).
        var mesh1 = Tetrahedron();
        var mesh2 = Tetrahedron();

        var r1 = new UnfoldService().Unfold(mesh1);
        var r2 = new UnfoldService().Unfold(mesh2);

        static string Signature(FourHUnfolder.Domain.Results.UnfoldResult r) =>
            string.Join("|", r.Faces.Select(f => $"{f.FaceId}:{string.Join(",", f.EdgeIsFold)}"));

        Signature(r1).Should().Be(Signature(r2));
    }
}
