using System.Numerics;
using FluentAssertions;
using FourHUnfolder.Application.Services;
using FourHUnfolder.Domain.Results;
using FourHUnfolder.Domain.Settings;
using FourHUnfolder.Infrastructure.Exporters;
using Xunit;

namespace FourHUnfolder.Tests;

/// <summary>
/// Verifies IncludeEdgeLabels prints cut-edge pair numbers (assembly matching guide) on the
/// exported SVG, and that the setting is off by default (opt-in, matches AlternateFlaps /
/// MergeAdjacentFlaps / HideCoplanarFolds).
/// </summary>
public class SvgEdgeLabelTests
{
    // One triangle with a single cut edge (edge 0, meshEdgeId 7, pair number 3).
    private static UnfoldResult SingleCutFace()
    {
        var face = new UnfoldedFace(
            0,
            new Vector2(0, 0), new Vector2(10, 0), new Vector2(0, 10),
            edgeIsFold: [false, false, false],
            edgeIsBoundary: [false, true, true],
            meshEdgeIds: [7, -1, -1]);

        var pairIds = new Dictionary<int, int> { [7] = 3 };
        return new UnfoldResult([face], [], false, pairIds);
    }

    private static string ExportSvg(bool includeEdgeLabels)
    {
        var settings = new AppSettings();
        settings.Print.PrintCutLines    = true;
        settings.Print.IncludeEdgeLabels = includeEdgeLabels;

        var ss = new SettingsService();
        ss.Apply(settings);

        var path = Path.Combine(Path.GetTempPath(), $"edgelabel_{Guid.NewGuid():N}.svg");
        new SvgExporter(ss).Export(SingleCutFace(), path);
        var svg = File.ReadAllText(path);
        File.Delete(path);
        return svg;
    }

    [Fact]
    public void IncludeEdgeLabels_Defaults_ToFalse()
        => new AppSettings().Print.IncludeEdgeLabels.Should().BeFalse();

    [Fact]
    public void PairLabel_Suppressed_WhenDisabled()
        => ExportSvg(includeEdgeLabels: false).Should().NotContain("class=\"pairlabel\"");

    [Fact]
    public void PairLabel_Drawn_WithCorrectNumber_WhenEnabled()
    {
        var svg = ExportSvg(includeEdgeLabels: true);
        svg.Should().Contain("class=\"pairlabel\"");
        svg.Should().Contain(">3<");
    }
}
