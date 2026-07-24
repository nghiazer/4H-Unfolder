using System.Numerics;
using FluentAssertions;
using FourHUnfolder.Application.Services;
using FourHUnfolder.Domain.Results;
using FourHUnfolder.Domain.Settings;
using FourHUnfolder.Infrastructure.Exporters;
using Xunit;

namespace FourHUnfolder.Tests;

/// <summary>
/// GĐ4.1: SVG cutting-machine layers (Inkscape-style &lt;g&gt; groups + inline stroke, since many
/// lightweight laser/vinyl-cutter SVG importers don't execute the &lt;style&gt; CSS block).
///
/// PngExporter (the other half of GĐ4.1) intentionally has no test here: it lives in
/// FourHUnfolder.App because it needs WPF's rendering stack (DrawingVisual, RenderTargetBitmap),
/// which is Windows-only at RUNTIME (not just at compile time — confirmed empirically: even
/// compiling FourHUnfolder.Tests against App via EnableWindowsTargeting would only get the code to
/// compile on this Darwin dev machine, but executing it would still crash, since WPF has no
/// implementation outside Windows). Verify PngExporter output manually on a real Windows machine,
/// matching the existing constraint on WPF App / PatternCanvasControl.
/// </summary>
public class SvgLayerTests
{
    // Two triangles: one fold edge (meshEdgeId 5) and one cut edge (meshEdgeId 7).
    private static UnfoldResult TwoFacesFoldAndCut()
    {
        var foldFace = new UnfoldedFace(
            0, new Vector2(0, 0), new Vector2(10, 0), new Vector2(0, 10),
            edgeIsFold: [true, false, false], edgeIsBoundary: [false, true, true],
            meshEdgeIds: [5, -1, -1]);
        var cutFace = new UnfoldedFace(
            1, new Vector2(10, 0), new Vector2(20, 0), new Vector2(10, 10),
            edgeIsFold: [false, false, false], edgeIsBoundary: [false, true, true],
            meshEdgeIds: [7, -1, -1]);

        var pairIds = new Dictionary<int, int> { [7] = 1 };
        return new UnfoldResult([foldFace, cutFace], [], false, pairIds);
    }

    private static string ExportSvg()
    {
        var settings = new AppSettings();
        settings.Print.PrintFoldLines    = true;
        settings.Print.PrintCutLines     = true;
        settings.Print.IncludeEdgeLabels = true;

        var ss = new SettingsService();
        ss.Apply(settings);

        var path = Path.Combine(Path.GetTempPath(), $"layers_{Guid.NewGuid():N}.svg");
        new SvgExporter(ss).Export(TwoFacesFoldAndCut(), path);
        var svg = File.ReadAllText(path);
        File.Delete(path);
        return svg;
    }

    [Fact]
    public void Svg_DeclaresInkscapeNamespace()
        => ExportSvg().Should().Contain("xmlns:inkscape=");

    [Fact]
    public void Svg_HasFoldLinesLayer()
        => ExportSvg().Should().Contain("inkscape:label=\"Fold Lines\"");

    [Fact]
    public void Svg_HasCutLinesLayer()
        => ExportSvg().Should().Contain("inkscape:label=\"Cut Lines\"");

    [Fact]
    public void Svg_HasEdgeLabelsLayer()
        => ExportSvg().Should().Contain("inkscape:label=\"Edge Labels\"");

    [Fact]
    public void Svg_FoldLine_HasInlineStrokeAttribute_NotJustCssClass()
    {
        var svg = ExportSvg();
        // Default fold colour is #4169e1 — must appear as an inline stroke="", not only inside
        // the <style> block, so lightweight SVG importers that skip CSS still render it correctly.
        svg.Should().Contain("class=\"fold\" stroke=\"#4169e1\"");
    }

    [Fact]
    public void Svg_CutLine_HasInlineStrokeAttribute()
    {
        var svg = ExportSvg();
        svg.Should().Contain("class=\"cut\" stroke=\"#ff0000\"");
    }
}
