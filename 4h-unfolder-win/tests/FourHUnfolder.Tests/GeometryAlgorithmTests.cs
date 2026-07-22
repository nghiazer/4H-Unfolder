using System.Numerics;
using FluentAssertions;
using FourHUnfolder.Domain.Models;
using FourHUnfolder.Domain.Results;
using FourHUnfolder.Geometry.Algorithms;
using FourHUnfolder.Infrastructure.Loaders;
using Xunit;

namespace FourHUnfolder.Tests;

public class OverlapDetectorTests
{
    private static UnfoldedFace MakeFace(int id, Vector2 v0, Vector2 v1, Vector2 v2) =>
        new(id, v0, v1, v2,
            edgeIsFold: [false, false, false],
            edgeIsBoundary: [false, false, false]);

    [Fact]
    public void SeparatedTriangles_NoOverlap()
    {
        // Two triangles well apart
        var a = MakeFace(0, new(0, 0), new(1, 0), new(0, 1));
        var b = MakeFace(1, new(5, 5), new(6, 5), new(5, 6));

        new OverlapDetector().HasOverlaps([a, b]).Should().BeFalse();
    }

    [Fact]
    public void OverlappingTriangles_DetectedAsOverlap()
    {
        // Two triangles that share the same space
        var a = MakeFace(0, new(0, 0), new(2, 0), new(0, 2));
        var b = MakeFace(1, new(0.5f, 0.5f), new(2.5f, 0.5f), new(0.5f, 2.5f));

        new OverlapDetector().HasOverlaps([a, b]).Should().BeTrue();
    }

    [Fact]
    public void AdjacentTriangles_SharingEdge_NotOverlap()
    {
        // Two triangles sharing edge (0,0)-(1,0) — adjacent, not overlapping
        var a = MakeFace(0, new(0, 0), new(1, 0), new(0.5f,  1));
        var b = MakeFace(1, new(0, 0), new(1, 0), new(0.5f, -1));

        new OverlapDetector().HasOverlaps([a, b]).Should().BeFalse();
    }

    [Fact]
    public void SingleFace_NoOverlap()
    {
        var a = MakeFace(0, new(0, 0), new(1, 0), new(0, 1));

        new OverlapDetector().HasOverlaps([a]).Should().BeFalse();
    }

    // ── CountOverlaps (used by UnfoldService's multi-seed retry to compare candidates) ────────

    [Fact]
    public void CountOverlaps_NoOverlap_ReturnsZero()
    {
        var a = MakeFace(0, new(0, 0), new(1, 0), new(0, 1));
        var b = MakeFace(1, new(5, 5), new(6, 5), new(5, 6));

        new OverlapDetector().CountOverlaps([a, b]).Should().Be(0);
    }

    [Fact]
    public void CountOverlaps_OnePair_ReturnsOne()
    {
        var a = MakeFace(0, new(0, 0), new(2, 0), new(0, 2));
        var b = MakeFace(1, new(0.5f, 0.5f), new(2.5f, 0.5f), new(0.5f, 2.5f));

        new OverlapDetector().CountOverlaps([a, b]).Should().Be(1);
    }

    [Fact]
    public void CountOverlaps_TwoIndependentPairs_ReturnsTwo()
    {
        // Two separate overlapping pairs, far apart from each other, so the spatial grid keeps
        // them as independent candidate pairs (no cross-pair contamination).
        var a1 = MakeFace(0, new(0, 0),   new(2, 0),   new(0, 2));
        var a2 = MakeFace(1, new(0.5f, 0.5f), new(2.5f, 0.5f), new(0.5f, 2.5f));
        var b1 = MakeFace(2, new(100, 100), new(102, 100), new(100, 102));
        var b2 = MakeFace(3, new(100.5f, 100.5f), new(102.5f, 100.5f), new(100.5f, 102.5f));

        new OverlapDetector().CountOverlaps([a1, a2, b1, b2]).Should().Be(2);
    }

    [Fact]
    public void CountOverlaps_GreaterThanZero_MatchesHasOverlapsTrue()
    {
        var a = MakeFace(0, new(0, 0), new(2, 0), new(0, 2));
        var b = MakeFace(1, new(0.5f, 0.5f), new(2.5f, 0.5f), new(0.5f, 2.5f));
        var det = new OverlapDetector();

        det.CountOverlaps([a, b]).Should().BeGreaterThan(0);
        det.HasOverlaps([a, b]).Should().BeTrue();
    }
}

public class ObjMeshLoaderTests
{
    private static string TempObj(string content)
    {
        var path = System.IO.Path.Combine(
            System.IO.Path.GetTempPath(), $"test_{System.Guid.NewGuid():N}.obj");
        System.IO.File.WriteAllText(path, content);
        return path;
    }

    [Fact]
    public void LoadTetrahedron_FourFacesLoaded()
    {
        var obj = TempObj("""
            v 0.0 0.0 0.0
            v 1.0 0.0 0.0
            v 0.5 1.0 0.0
            v 0.5 0.5 1.0
            f 1 2 3
            f 1 2 4
            f 2 3 4
            f 1 3 4
            """);
        try
        {
            var mesh = new ObjMeshLoader().Load(obj);
            mesh.Faces.Should().HaveCount(4);
            mesh.Vertices.Should().HaveCount(4);
        }
        finally { System.IO.File.Delete(obj); }
    }

    [Fact]
    public void MalformedFloatToken_LoadsWithoutException()
    {
        // "1.0e" is an invalid float — should be treated as 0f, not throw
        var obj = TempObj("""
            v 1.0e 0.0 0.0
            v 1.0 0.0 0.0
            v 0.5 1.0 0.0
            f 1 2 3
            """);
        try
        {
            var act = () => new ObjMeshLoader().Load(obj);
            act.Should().NotThrow();
        }
        finally { System.IO.File.Delete(obj); }
    }

    [Fact]
    public void NegativeVertexIndices_IgnoredGracefully()
    {
        // OBJ negative index (-1) should be treated as absent, not throw
        var obj = TempObj("""
            v 0.0 0.0 0.0
            v 1.0 0.0 0.0
            v 0.5 1.0 0.0
            f 1/1 2/2 3/-1
            """);
        try
        {
            var act = () => new ObjMeshLoader().Load(obj);
            act.Should().NotThrow();
        }
        finally { System.IO.File.Delete(obj); }
    }

    [Fact]
    public void QuadFace_FanTriangulated()
    {
        // A quad face (4 vertices) should produce 2 triangles
        var obj = TempObj("""
            v 0 0 0
            v 1 0 0
            v 1 1 0
            v 0 1 0
            f 1 2 3 4
            """);
        try
        {
            var mesh = new ObjMeshLoader().Load(obj);
            mesh.Faces.Should().HaveCount(2);
        }
        finally { System.IO.File.Delete(obj); }
    }
}
