using System.Numerics;
using FourHUnfolder.Domain.Results;

namespace FourHUnfolder.Geometry.Algorithms;

/// <summary>
/// Computes the outer boundary polygon of a group of unfolded faces by collecting
/// all non-fold edges and chaining them into an ordered closed polygon path.
/// </summary>
public static class BoundaryPolygonComputer
{
    private const float SnapEps = 0.001f;

    /// Returns the ordered boundary polygon in the same coordinate space as the faces,
    /// or null for degenerate/empty input.
    public static List<Vector2>? Compute(IReadOnlyList<UnfoldedFace> faces)
    {
        if (faces.Count == 0) return null;

        var edges     = new List<(Vector2 A, Vector2 B)>();
        var seenById  = new HashSet<int>();
        var seenByCoord = new HashSet<(long, long, long, long)>();

        foreach (var face in faces)
        {
            var v = face.Vertices;
            for (int i = 0; i < 3; i++)
            {
                if (face.EdgeIsFold[i]) continue;

                int meshId = face.MeshEdgeIds[i];
                if (meshId >= 0)
                {
                    if (!seenById.Add(meshId)) continue;
                }
                else
                {
                    var key = CoordKey(v[i], v[(i + 1) % 3]);
                    if (!seenByCoord.Add(key)) continue;
                }
                edges.Add((v[i], v[(i + 1) % 3]));
            }
        }

        return ChainEdges(edges);
    }

    private static List<Vector2>? ChainEdges(List<(Vector2 A, Vector2 B)> edges)
    {
        if (edges.Count == 0) return null;

        var polygon   = new List<Vector2> { edges[0].A, edges[0].B };
        var remaining = new List<(Vector2 A, Vector2 B)>(edges);
        remaining.RemoveAt(0);

        for (int guard = 0; guard < edges.Count && remaining.Count > 0; guard++)
        {
            var tail  = polygon[^1];
            bool found = false;
            for (int k = 0; k < remaining.Count; k++)
            {
                var (a, b) = remaining[k];
                if (Near(tail, a)) { polygon.Add(b); remaining.RemoveAt(k); found = true; break; }
                if (Near(tail, b)) { polygon.Add(a); remaining.RemoveAt(k); found = true; break; }
            }
            if (!found) break;
        }

        return polygon.Count >= 3 ? polygon : null;
    }

    private static bool Near(Vector2 a, Vector2 b)
    {
        var d = a - b;
        return d.X * d.X + d.Y * d.Y < SnapEps * SnapEps;
    }

    // Symmetric (direction-independent) rounded coordinate key for deduplication.
    private static (long, long, long, long) CoordKey(Vector2 a, Vector2 b)
    {
        long ax = (long)MathF.Round(a.X * 1000), ay = (long)MathF.Round(a.Y * 1000);
        long bx = (long)MathF.Round(b.X * 1000), by = (long)MathF.Round(b.Y * 1000);
        return ax < bx || (ax == bx && ay <= by) ? (ax, ay, bx, by) : (bx, by, ax, ay);
    }
}
