using System.Numerics;
using FluentAssertions;
using FourHUnfolder.Application.Services;
using FourHUnfolder.Domain.Results;
using FourHUnfolder.Domain.Settings;
using FourHUnfolder.Infrastructure.Exporters;
using Xunit;

namespace FourHUnfolder.Tests;

/// <summary>
/// Verifies HideCoplanarFolds suppresses fold lines whose dihedral angle is below the
/// coplanar threshold (papercraft convention learned from osresearch/papercraft).
/// </summary>
public class SvgCoplanarFoldTests
{
    // One triangle whose edge 0 is a near-coplanar fold edge (meshEdgeId 5, dihedral 0.2°).
    private static UnfoldResult SingleCoplanarFoldFace()
    {
        var face = new UnfoldedFace(
            0,
            new Vector2(0, 0), new Vector2(10, 0), new Vector2(0, 10),
            edgeIsFold: [true, false, false],
            edgeIsBoundary: [false, true, true],
            meshEdgeIds: [5, -1, -1]);

        var dihedral = new Dictionary<int, float> { [5] = 0.2f }; // < 1° → coplanar
        return new UnfoldResult([face], [], false, null, dihedral);
    }

    private static string ExportSvg(bool hideCoplanar)
    {
        var settings = new AppSettings();
        settings.Print.PrintFoldLines   = true;
        settings.Print.HideCoplanarFolds = hideCoplanar;
        settings.Print.CoplanarAngleDeg  = 1.0;

        var ss = new SettingsService();
        ss.Apply(settings);

        var path = Path.Combine(Path.GetTempPath(), $"coplanar_{Guid.NewGuid():N}.svg");
        new SvgExporter(ss).Export(SingleCoplanarFoldFace(), path);
        var svg = File.ReadAllText(path);
        File.Delete(path);
        return svg;
    }

    [Fact]
    public void FoldLine_Drawn_WhenHideDisabled()
        => ExportSvg(hideCoplanar: false).Should().Contain("class=\"fold\"");

    [Fact]
    public void CoplanarFoldLine_Suppressed_WhenHideEnabled()
        => ExportSvg(hideCoplanar: true).Should().NotContain("class=\"fold\"");
}
