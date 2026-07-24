using System.Globalization;
using System.IO;
using System.Numerics;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using FourHUnfolder.Application.Services;
using FourHUnfolder.Domain.Results;

namespace FourHUnfolder.App.Services;

/// <summary>
/// Exports an <see cref="UnfoldResult"/> to one PNG raster image per page — for
/// cutting-machine software (Cricut / laser) that prefers bitmap import over SVG/PDF.
///
/// Lives in the App project (not Infrastructure/Exporters, like SvgExporter/PdfExporter)
/// because it needs WPF's rendering stack (DrawingVisual, RenderTargetBitmap), which requires
/// net8.0-windows + UseWPF — Infrastructure targets plain net8.0 so it stays buildable/testable
/// cross-platform (verified throughout this repo's development on a non-Windows machine).
///
/// Mirrors PdfExporter's per-page grid layout (pagesWide × pagesTall, pageSepMm gap) — but no
/// Y-flip is needed here: WPF's DrawingVisual coordinate system is Y-down, same as the model's.
/// </summary>
public class PngExporter
{
    private readonly SettingsService _settings;

    public PngExporter(SettingsService settings) => _settings = settings;

    /// Device-independent units (WPF's fixed 96 DPI coordinate space) per mm. Constant regardless
    /// of the chosen output DPI — RenderTargetBitmap rescales this 96-DPI visual tree to the
    /// target pixel density itself, so mixing this up with the *output* DPI would corrupt scale.
    private const double UnitsPerMm = 96.0 / 25.4;

    /// <returns>Paths of the PNG files written — one per page, in row-major order.</returns>
    public List<string> Export(
        UnfoldResult result, string baseFilePath,
        double paperWidthMm, double paperHeightMm,
        int pagesWide = 1, int pagesTall = 1,
        double pageSepMm = 20)
    {
        var p   = _settings.Current.Print;
        double dpi = p.PngDpi > 0 ? p.PngDpi : 300.0;

        int pixelW = Math.Max(1, (int)Math.Round(paperWidthMm  * dpi / 25.4));
        int pixelH = Math.Max(1, (int)Math.Round(paperHeightMm * dpi / 25.4));

        string dir  = Path.GetDirectoryName(baseFilePath) is { Length: > 0 } d ? d : ".";
        string name = Path.GetFileNameWithoutExtension(baseFilePath);
        int totalPages = Math.Max(1, pagesWide) * Math.Max(1, pagesTall);

        var written = new List<string>(totalPages);

        for (int row = 0; row < pagesTall; row++)
        for (int col = 0; col < pagesWide; col++)
        {
            double oxMm = col * (paperWidthMm + pageSepMm);
            double oyMm = row * (paperHeightMm + pageSepMm);

            double MmToX(double x) => (x - oxMm) * UnitsPerMm;
            double MmToY(double y) => (y - oyMm) * UnitsPerMm; // no flip — model is Y-down too

            int pageNumForLabel = row * pagesWide + col + 1;
            string pageLabel = totalPages > 1 ? $"{name}  p.{pageNumForLabel}" : name;
            var visual = RenderPage(result, p, oxMm, oyMm, paperWidthMm, paperHeightMm,
                                     MmToX, MmToY, pixelW * 96.0 / dpi, pixelH * 96.0 / dpi, pageLabel);

            var rtb = new RenderTargetBitmap(pixelW, pixelH, dpi, dpi, PixelFormats.Pbgra32);
            rtb.Render(visual);

            var encoder = new PngBitmapEncoder();
            encoder.Frames.Add(BitmapFrame.Create(rtb));

            int pageNum = row * pagesWide + col + 1;
            string outPath = totalPages > 1
                ? Path.Combine(dir, $"{name}_p{pageNum}.png")
                : Path.Combine(dir, $"{name}.png");

            using (var fs = new FileStream(outPath, FileMode.Create, FileAccess.Write))
                encoder.Save(fs);

            written.Add(outPath);
        }

        return written;
    }

    // ── page rendering ──────────────────────────────────────────────────────────

    private static DrawingVisual RenderPage(
        UnfoldResult result, Domain.Settings.AppSettings.PrintSettings p,
        double oxMm, double oyMm, double paperWidthMm, double paperHeightMm,
        Func<double, double> mmToX, Func<double, double> mmToY,
        double pageWidthDiu, double pageHeightDiu, string pageLabel)
    {
        var visual = new DrawingVisual();
        using var dc = visual.RenderOpen();

        // White page background.
        dc.DrawRectangle(Brushes.White, null, new Rect(0, 0, pageWidthDiu, pageHeightDiu));

        // ── face fills ───────────────────────────────────────────────────────
        var faceBrush = new SolidColorBrush(p.GrayscaleOutput
            ? Color.FromRgb(240, 240, 240) : Color.FromRgb(255, 253, 231));
        faceBrush.Freeze();
        foreach (var face in result.Faces)
        {
            if (!IsOnPage(face, oxMm, oyMm, paperWidthMm, paperHeightMm)) continue;
            dc.DrawGeometry(faceBrush, null, PolyGeometry(face.Vertices, mmToX, mmToY));
        }

        // ── glue tabs ────────────────────────────────────────────────────────
        if (p.IncludeGlueTabs)
        {
            var tabBrush = new SolidColorBrush(p.GrayscaleOutput
                ? Color.FromArgb(255, 200, 200, 200) : Color.FromArgb(100, 80, 200, 80));
            tabBrush.Freeze();
            var tabPen = new Pen(new SolidColorBrush(Color.FromRgb(46, 125, 50)), 0.6 * UnitsPerMm);
            tabPen.Freeze();
            foreach (var tab in result.GlueTabs)
            {
                if (!IsTabOnPage(tab, oxMm, oyMm, paperWidthMm, paperHeightMm)) continue;
                dc.DrawGeometry(tabBrush, tabPen, PolyGeometry(tab.Vertices, mmToX, mmToY));
            }
        }

        // ── fold / cut / boundary lines ──────────────────────────────────────
        string foldHex = p.GrayscaleOutput ? "#555555" : p.FoldLineColor;
        string cutHex  = p.GrayscaleOutput ? "#000000" : p.CutLineColor;

        var foldPen = new Pen(HexBrush(foldHex), Math.Max(0.1, p.FoldLineWidth) * UnitsPerMm);
        if (!p.FoldLineDash.Equals("Solid", StringComparison.OrdinalIgnoreCase))
            foldPen.DashStyle = ParseDash(p.FoldLineDash, foldPen.Thickness);
        foldPen.Freeze();

        var cutPen = new Pen(HexBrush(cutHex), Math.Max(0.1, p.CutLineWidth) * UnitsPerMm);
        cutPen.Freeze();

        var boundPen = new Pen(Brushes.DimGray, 0.6 * UnitsPerMm);
        boundPen.Freeze();

        var drawn = new HashSet<(float, float, float, float)>();
        foreach (var face in result.Faces)
        {
            if (!IsOnPage(face, oxMm, oyMm, paperWidthMm, paperHeightMm)) continue;
            var verts = face.Vertices;
            for (int i = 0; i < 3; i++)
            {
                bool isFold     = face.EdgeIsFold[i];
                bool isBoundary = face.EdgeIsBoundary[i];
                if (isFold && !p.PrintFoldLines) continue;
                if (!isFold && !isBoundary && !p.PrintCutLines) continue;

                if (isFold && p.HideCoplanarFolds)
                {
                    int meshEdgeId = face.MeshEdgeIds[i];
                    if (meshEdgeId >= 0
                        && result.EdgeDihedralAngles.TryGetValue(meshEdgeId, out var deg)
                        && deg < p.CoplanarAngleDeg)
                        continue;
                }

                var va = verts[i]; var vb = verts[(i + 1) % 3];
                if (!drawn.Add(EdgeKey(va, vb))) continue;

                var pen = isBoundary ? boundPen : (isFold ? foldPen : cutPen);
                dc.DrawLine(pen,
                    new Point(mmToX(va.X), mmToY(va.Y)),
                    new Point(mmToX(vb.X), mmToY(vb.Y)));
            }
        }

        // ── cut-edge pair labels ─────────────────────────────────────────────
        if (p.IncludeEdgeLabels && result.CutEdgePairIds.Count > 0)
        {
            var typeface   = new Typeface("Segoe UI");
            var labelBrush = HexBrush(cutHex);
            var drawnLabels = new HashSet<int>();
            foreach (var face in result.Faces)
            {
                if (!IsOnPage(face, oxMm, oyMm, paperWidthMm, paperHeightMm)) continue;
                var verts = face.Vertices;
                for (int i = 0; i < 3; i++)
                {
                    if (face.EdgeIsFold[i] || face.EdgeIsBoundary[i]) continue;
                    int meshEdgeId = face.MeshEdgeIds[i];
                    if (meshEdgeId < 0
                        || !result.CutEdgePairIds.TryGetValue(meshEdgeId, out var pairId)
                        || !drawnLabels.Add(meshEdgeId))
                        continue;

                    var mp = (verts[i] + verts[(i + 1) % 3]) * 0.5f;
                    var ft = new FormattedText(
                        pairId.ToString(), CultureInfo.InvariantCulture, FlowDirection.LeftToRight,
                        typeface, 7.0 * UnitsPerMm / 3.0, labelBrush, 1.0);
                    dc.DrawText(ft, new Point(mmToX(mp.X) - ft.Width / 2, mmToY(mp.Y) - ft.Height / 2));
                }
            }
        }

        // ── page footer label ────────────────────────────────────────────────
        if (p.IncludePageLabel)
        {
            var ft = new FormattedText(
                pageLabel, CultureInfo.InvariantCulture, FlowDirection.LeftToRight,
                new Typeface("Segoe UI"), 8.0 * UnitsPerMm / 3.0, Brushes.Gray, 1.0);
            dc.DrawText(ft, new Point(4, 4));
        }

        return visual;
    }

    // ── geometry helpers ─────────────────────────────────────────────────────────

    private static StreamGeometry PolyGeometry(
        IReadOnlyList<Vector2> verts, Func<double, double> mmToX, Func<double, double> mmToY)
    {
        var geo = new StreamGeometry();
        using (var ctx = geo.Open())
        {
            if (verts.Count == 0) return geo;
            ctx.BeginFigure(new Point(mmToX(verts[0].X), mmToY(verts[0].Y)), isFilled: true, isClosed: true);
            for (int i = 1; i < verts.Count; i++)
                ctx.LineTo(new Point(mmToX(verts[i].X), mmToY(verts[i].Y)), isStroked: true, isSmoothJoin: false);
        }
        geo.Freeze();
        return geo;
    }

    private static (float, float, float, float) EdgeKey(Vector2 a, Vector2 b)
    {
        float ax = MathF.Round(a.X, 3), ay = MathF.Round(a.Y, 3);
        float bx = MathF.Round(b.X, 3), by = MathF.Round(b.Y, 3);
        return (ax < bx || (ax == bx && ay <= by)) ? (ax, ay, bx, by) : (bx, by, ax, ay);
    }

    private static bool IsOnPage(UnfoldedFace face, double oxMm, double oyMm, double wMm, double hMm)
    {
        var vs = face.Vertices;
        return vs.Any(v => v.X >= oxMm && v.X <= oxMm + wMm && v.Y >= oyMm && v.Y <= oyMm + hMm);
    }

    private static bool IsTabOnPage(GlueTab tab, double oxMm, double oyMm, double wMm, double hMm)
        => tab.Vertices.Any(v => v.X >= oxMm && v.X <= oxMm + wMm && v.Y >= oyMm && v.Y <= oyMm + hMm);

    private static DashStyle ParseDash(string s, double penThicknessDiu)
    {
        var parts = s.Split(',')
            .Select(x => double.TryParse(x.Trim(), NumberStyles.Float, CultureInfo.InvariantCulture, out var v) ? v : 0)
            .Where(v => v > 0)
            .ToArray();
        if (parts.Length == 0 || penThicknessDiu <= 0) return DashStyles.Solid;

        // WPF dash values are multiples of pen thickness; settings store mm-like SVG units.
        var relative = parts.Select(mm => mm * UnitsPerMm / penThicknessDiu).ToArray();
        return new DashStyle(relative, 0);
    }

    private static SolidColorBrush HexBrush(string hex)
    {
        hex = hex.TrimStart('#');
        byte a = 255, r = 0, g = 0, b = 0;
        if (hex.Length == 8)
        {
            a = Convert.ToByte(hex[0..2], 16);
            r = Convert.ToByte(hex[2..4], 16);
            g = Convert.ToByte(hex[4..6], 16);
            b = Convert.ToByte(hex[6..8], 16);
        }
        else if (hex.Length == 6)
        {
            r = Convert.ToByte(hex[0..2], 16);
            g = Convert.ToByte(hex[2..4], 16);
            b = Convert.ToByte(hex[4..6], 16);
        }
        var brush = new SolidColorBrush(Color.FromArgb(a, r, g, b));
        brush.Freeze();
        return brush;
    }
}
