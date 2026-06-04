using System.Numerics;

namespace FourHUnfolder.Infrastructure.Exporters;

/// <summary>
/// Canonical edge key using 3-dp rounded coordinates, order-independent.
/// Used by both SvgExporter and PdfExporter to deduplicate shared edges.
/// </summary>
internal static class EdgeKeyHelper
{
    public static (float, float, float, float) Compute(Vector2 a, Vector2 b)
    {
        float ax = MathF.Round(a.X, 3), ay = MathF.Round(a.Y, 3);
        float bx = MathF.Round(b.X, 3), by = MathF.Round(b.Y, 3);
        return (ax < bx || (ax == bx && ay <= by)) ? (ax, ay, bx, by) : (bx, by, ax, ay);
    }
}
