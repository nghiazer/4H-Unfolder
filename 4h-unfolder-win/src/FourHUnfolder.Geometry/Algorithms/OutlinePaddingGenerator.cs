using System.Numerics;
using Clipper2Lib;

namespace FourHUnfolder.Geometry.Algorithms;

/// <summary>
/// Inflates a piece boundary polygon outward by a given amount using Clipper2.
/// </summary>
public static class OutlinePaddingGenerator
{
    /// Returns the inflated polygon, or null if the result is degenerate.
    /// <param name="polygon">Boundary polygon in mm coordinates (closed, CW or CCW).</param>
    /// <param name="paddingMm">Outward offset in mm. Must be > 0.</param>
    public static IReadOnlyList<Vector2>? Inflate(IReadOnlyList<Vector2> polygon, float paddingMm)
    {
        if (polygon.Count < 3 || paddingMm <= 0f) return null;

        var path  = new PathD(polygon.Select(p => new PointD(p.X, p.Y)));
        var paths = new PathsD { path };

        // miterLimit=2.0, precision=4 decimal places, minLength=0.0
        var result = Clipper.InflatePaths(paths, paddingMm, JoinType.Round, EndType.Polygon, 2.0, 4, 0.0);

        if (result.Count == 0 || result[0].Count < 3) return null;

        // Return the first (typically the only) result path.
        return result[0].Select(p => new Vector2((float)p.x, (float)p.y)).ToList();
    }
}
