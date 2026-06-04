using System.Numerics;
using FluentAssertions;
using FourHUnfolder.Domain.Models;
using FourHUnfolder.Domain.Results;
using FourHUnfolder.Geometry.Algorithms;
using Xunit;

namespace FourHUnfolder.Tests;

public class GlueTabGeneratorTests
{
    // ── helpers ───────────────────────────────────────────────────────────────

    /// A simple right-angle face pointing "up" (centroid above edge 0).
    private static UnfoldedFace BorderFace(int meshEdgeId = 10) =>
        new(faceId: 0,
            v0: new Vector2(0, 0), v1: new Vector2(4, 0), v2: new Vector2(2, 3),
            edgeIsFold:    [false, false, false],
            edgeIsBoundary:[true,  false, false],          // edge 0 is a border
            meshEdgeIds:   [meshEdgeId, -1, -1]);

    /// A face whose edge 0 is an interior cut (not fold, not boundary).
    private static UnfoldedFace CutFace(int meshEdgeId = 20) =>
        new(faceId: 1,
            v0: new Vector2(0, 0), v1: new Vector2(4, 0), v2: new Vector2(2, 3),
            edgeIsFold:    [false, false, false],
            edgeIsBoundary:[false, false, false],
            meshEdgeIds:   [meshEdgeId, -1, -1]);

    private static GlueTabGenerator Gen() => new();

    // ── Default mode: border edges are skipped ────────────────────────────────

    [Fact]
    public void Default_BorderEdge_NoTab()
    {
        var face = BorderFace();
        var tabs = Gen().Generate([face]);
        tabs.Should().BeEmpty("border edges get no tab in Default mode");
    }

    [Fact]
    public void Default_CutEdge_ProducesTab()
    {
        var face = CutFace();
        var tabs = Gen().Generate([face]);
        tabs.Should().HaveCount(1);
        tabs[0].BorderFoldStyle.Should().BeNull("Default cut tab has no border annotation");
    }

    // ── Border_MountainFold ───────────────────────────────────────────────────

    [Fact]
    public void Border_MountainFold_ProducesTabWithAnnotation()
    {
        var face      = BorderFace(meshEdgeId: 10);
        var overrides = new Dictionary<int, FlapOverride>
        {
            [10] = new FlapOverride(FlapMode.Border_MountainFold)
        };
        var tabs = Gen().Generate([face], flapOverrides: overrides);

        tabs.Should().HaveCount(1);
        tabs[0].BorderFoldStyle.Should().Be(FlapMode.Border_MountainFold);
        tabs[0].FaceId.Should().Be(0);
    }

    // ── Border_ValleyFold ─────────────────────────────────────────────────────

    [Fact]
    public void Border_ValleyFold_ProducesTabWithAnnotation()
    {
        var face      = BorderFace(meshEdgeId: 10);
        var overrides = new Dictionary<int, FlapOverride>
        {
            [10] = new FlapOverride(FlapMode.Border_ValleyFold)
        };
        var tabs = Gen().Generate([face], flapOverrides: overrides);

        tabs.Should().HaveCount(1);
        tabs[0].BorderFoldStyle.Should().Be(FlapMode.Border_ValleyFold);
    }

    // ── Border_NoFold ─────────────────────────────────────────────────────────

    [Fact]
    public void Border_NoFold_ProducesTabWithoutFoldAnnotation()
    {
        var face      = BorderFace(meshEdgeId: 10);
        var overrides = new Dictionary<int, FlapOverride>
        {
            [10] = new FlapOverride(FlapMode.Border_NoFold)
        };
        var tabs = Gen().Generate([face], flapOverrides: overrides);

        tabs.Should().HaveCount(1);
        tabs[0].BorderFoldStyle.Should().Be(FlapMode.Border_NoFold);
    }

    // ── Border_NoFlap suppresses tab ──────────────────────────────────────────

    [Fact]
    public void Border_NoFlap_SuppressesTab()
    {
        var face      = BorderFace(meshEdgeId: 10);
        var overrides = new Dictionary<int, FlapOverride>
        {
            [10] = new FlapOverride(FlapMode.Border_NoFlap)
        };
        var tabs = Gen().Generate([face], flapOverrides: overrides);
        tabs.Should().BeEmpty("Border_NoFlap explicitly suppresses the tab");
    }

    // ── Tab geometry: vertices are not degenerate ─────────────────────────────

    [Fact]
    public void Border_MountainFold_TabVerticesAreDistinct()
    {
        var face      = BorderFace(meshEdgeId: 10);
        var overrides = new Dictionary<int, FlapOverride>
        {
            [10] = new FlapOverride(FlapMode.Border_MountainFold)
        };
        var tabs = Gen().Generate([face], flapOverrides: overrides);
        var verts = tabs[0].Vertices;

        verts.Should().HaveCount(4);
        // At least one inner vertex must differ from the base edge — non-degenerate tab
        verts[2].Should().NotBe(verts[0]);
    }

    // ── OffOff_NoFlap on cut edge suppresses tab ──────────────────────────────

    [Fact]
    public void OffOff_NoFlap_OnCutEdge_SuppressesTab()
    {
        var face      = CutFace(meshEdgeId: 20);
        var overrides = new Dictionary<int, FlapOverride>
        {
            [20] = new FlapOverride(FlapMode.OffOff_NoFlap)
        };
        var tabs = Gen().Generate([face], flapOverrides: overrides);
        tabs.Should().BeEmpty();
    }
}
