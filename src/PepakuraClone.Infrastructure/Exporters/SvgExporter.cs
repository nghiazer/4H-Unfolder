using System.Globalization;
using System.Numerics;
using System.Text;
using PepakuraClone.Application.Interfaces;
using PepakuraClone.Application.Services;
using PepakuraClone.Domain.Results;
using PepakuraClone.Domain.Settings;

namespace PepakuraClone.Infrastructure.Exporters;

/// <summary>
/// Exports an <see cref="UnfoldResult"/> to a standalone SVG file.
/// Appearance and layout are controlled by <see cref="AppSettings.PrintSettings"/>.
/// </summary>
public class SvgExporter : IExporter
{
    private readonly SettingsService _settings;

    public SvgExporter(SettingsService settings) => _settings = settings;

    public void Export(UnfoldResult result, string filePath)
    {
        var p = _settings.Current.Print;

        float scale   = (float)p.SvgScaleFactor;
        float margin  = (float)p.MarginMm * scale;

        var allVerts = result.Faces.SelectMany(f => f.Vertices).ToList();
        if (allVerts.Count == 0) return;

        float minX = allVerts.Min(v => v.X) - (float)p.MarginMm;
        float minY = allVerts.Min(v => v.Y) - (float)p.MarginMm;
        float maxX = allVerts.Max(v => v.X) + (float)p.MarginMm;
        float maxY = allVerts.Max(v => v.Y) + (float)p.MarginMm;

        float W = (maxX - minX) * scale + 2 * margin;
        float H = (maxY - minY) * scale + 2 * margin;

        string Sx(float x)  => F((x - minX) * scale + margin);
        string Sy(float y)  => F((y - minY) * scale + margin);
        string Pt(Vector2 v) => $"{Sx(v.X)},{Sy(v.Y)}";

        // Resolve colors (grayscale if enabled)
        string foldColor = p.GrayscaleOutput ? "#555555" : Clamp(p.FoldLineColor, "#4169e1");
        string cutColor  = p.GrayscaleOutput ? "#000000" : Clamp(p.CutLineColor,  "#ff0000");
        string tabFill   = p.GrayscaleOutput ? "#cccccc" : "rgba(80,200,80,0.4)";

        string foldDash = p.FoldLineDash.Equals("Solid", StringComparison.OrdinalIgnoreCase)
            ? string.Empty
            : $" stroke-dasharray=\"{p.FoldLineDash}\"";

        var sb = new StringBuilder();
        sb.AppendLine("<?xml version=\"1.0\" encoding=\"UTF-8\"?>");
        sb.AppendLine($"<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"{F(W)}\" height=\"{F(H)}\" viewBox=\"0 0 {F(W)} {F(H)}\">");
        sb.AppendLine("  <defs>");
        sb.AppendLine("    <style>");
        sb.AppendLine("      .face { fill:#fffde7; stroke:#aaa; stroke-width:0.3; }");
        sb.AppendLine($"      .fold {{ stroke:{foldColor}; stroke-width:{F((float)p.FoldLineWidth)}{foldDash}; fill:none; }}");
        sb.AppendLine($"      .cut  {{ stroke:{cutColor};  stroke-width:{F((float)p.CutLineWidth)}; fill:none; }}");
        sb.AppendLine($"      .tab  {{ fill:{tabFill}; stroke:#2e7d32; stroke-width:0.6; }}");
        sb.AppendLine($"      .label{{ font-family:sans-serif; font-size:8px; fill:#888; }}");
        sb.AppendLine("    </style>");
        sb.AppendLine("  </defs>");

        // Page label
        if (p.IncludePageLabel)
            sb.AppendLine($"  <text x=\"{F(margin)}\" y=\"{F(margin - 4)}\" class=\"label\">PepakuraClone Export</text>");

        // Face polygons
        foreach (var face in result.Faces)
        {
            string pts = $"{Pt(face.V0)} {Pt(face.V1)} {Pt(face.V2)}";
            sb.AppendLine($"  <polygon points=\"{pts}\" class=\"face\"/>");
        }

        // Fold / cut lines
        foreach (var face in result.Faces)
        {
            var verts = face.Vertices;
            for (int i = 0; i < 3; i++)
            {
                bool isFold = face.EdgeIsFold[i];
                if (isFold  && !p.PrintFoldLines) continue;
                if (!isFold && !p.PrintCutLines)  continue;

                var pa  = verts[i];
                var pb  = verts[(i + 1) % 3];
                var cls = isFold ? "fold" : "cut";
                sb.AppendLine($"  <line x1=\"{Sx(pa.X)}\" y1=\"{Sy(pa.Y)}\" " +
                              $"x2=\"{Sx(pb.X)}\" y2=\"{Sy(pb.Y)}\" class=\"{cls}\"/>");
            }
        }

        // Glue tabs
        if (p.IncludeGlueTabs)
        {
            foreach (var tab in result.GlueTabs)
            {
                string pts = string.Join(" ", tab.Vertices.Select(v => Pt(v)));
                sb.AppendLine($"  <polygon points=\"{pts}\" class=\"tab\"/>");
            }
        }

        sb.AppendLine("</svg>");
        File.WriteAllText(filePath, sb.ToString(), Encoding.UTF8);
    }

    private static string F(float v) => v.ToString("F2", CultureInfo.InvariantCulture);

    private static string Clamp(string hex, string fallback)
    {
        if (string.IsNullOrWhiteSpace(hex)) return fallback;
        return hex.StartsWith('#') ? hex : '#' + hex;
    }
}
