using System.Numerics;

namespace FourHUnfolder.Geometry.Algorithms;

/// <summary>
/// Backlog Phase 7 (TD-38-4): "Select Symmetrical Pair" — pick a piece, auto-select its mirror.
///
/// Scoped to axis-aligned mirror symmetry (a plane perpendicular to X, Y, or Z through the
/// mesh's bounding-box center) rather than a fully general symmetry-plane search. This covers
/// the common case — most bilaterally-symmetric real-world models (figures, vehicles, robots)
/// are modeled upright and centered on a cardinal axis — without the much larger scope of
/// arbitrary-orientation symmetry detection, which is why this item was previously deferred as
/// "too complex" (see SESSION_PROGRESS.md TD-38-4).
/// </summary>
public static class SymmetryDetector
{
    public enum Axis { X, Y, Z }

    public readonly record struct MirrorPlane(Axis Axis, float Center);

    /// <summary>
    /// Detects the best-fit axis-aligned mirror plane, or null if no candidate axis has enough
    /// vertices with a mirrored counterpart to be confident the mesh is actually symmetric
    /// (as opposed to a handful of coincidentally-mirrored vertices on an asymmetric model).
    /// </summary>
    /// <param name="matchThreshold">Fraction of vertices that must have a mirrored match
    /// (0.9 = 90%) for an axis to be accepted.</param>
    public static MirrorPlane? DetectMirrorPlane(IReadOnlyList<Vector3> positions, float matchThreshold = 0.9f)
    {
        if (positions.Count == 0) return null;

        var min = new Vector3(float.MaxValue);
        var max = new Vector3(float.MinValue);
        foreach (var p in positions) { min = Vector3.Min(min, p); max = Vector3.Max(max, p); }

        float diagonal = (max - min).Length();
        if (diagonal < 1e-6f) return null;   // degenerate (single point)
        float epsilon = Math.Max(diagonal * 0.002f, 1e-4f);

        MirrorPlane? best = null;
        float bestScore = 0f;

        foreach (var axis in new[] { Axis.X, Axis.Y, Axis.Z })
        {
            float center = axis switch
            {
                Axis.X => (min.X + max.X) / 2,
                Axis.Y => (min.Y + max.Y) / 2,
                _      => (min.Z + max.Z) / 2,
            };
            float score = MatchScore(positions, axis, center, epsilon);
            if (score > bestScore)
            {
                bestScore = score;
                best = new MirrorPlane(axis, center);
            }
        }

        return bestScore >= matchThreshold ? best : null;
    }

    /// <summary>
    /// Fraction of vertices whose mirror image lands within epsilon of another vertex.
    /// Uses a spatial hash (bucket size = epsilon) so this stays O(n) instead of O(n²) — same
    /// grid-neighbor-search shape as OverlapDetector's candidate-pair phase.
    /// </summary>
    private static float MatchScore(IReadOnlyList<Vector3> positions, Axis axis, float center, float epsilon)
    {
        var grid = new Dictionary<(long, long, long), List<int>>();
        (long, long, long) KeyOf(Vector3 p) =>
            ((long)MathF.Round(p.X / epsilon), (long)MathF.Round(p.Y / epsilon), (long)MathF.Round(p.Z / epsilon));

        for (int i = 0; i < positions.Count; i++)
        {
            var key = KeyOf(positions[i]);
            if (!grid.TryGetValue(key, out var list)) { list = new List<int>(); grid[key] = list; }
            list.Add(i);
        }

        float epsSq = epsilon * epsilon;
        int matched = 0;
        for (int i = 0; i < positions.Count; i++)
        {
            var mirrored = Mirror(positions[i], axis, center);
            var (kx, ky, kz) = KeyOf(mirrored);
            bool found = false;
            for (int dx = -1; dx <= 1 && !found; dx++)
            for (int dy = -1; dy <= 1 && !found; dy++)
            for (int dz = -1; dz <= 1 && !found; dz++)
            {
                if (!grid.TryGetValue((kx + dx, ky + dy, kz + dz), out var candidates)) continue;
                foreach (var c in candidates)
                {
                    if (Vector3.DistanceSquared(positions[c], mirrored) <= epsSq) { found = true; break; }
                }
            }
            if (found) matched++;
        }
        return (float)matched / positions.Count;
    }

    public static Vector3 Mirror(Vector3 p, Axis axis, float center) => axis switch
    {
        Axis.X => new Vector3(2 * center - p.X, p.Y, p.Z),
        Axis.Y => new Vector3(p.X, 2 * center - p.Y, p.Z),
        _      => new Vector3(p.X, p.Y, 2 * center - p.Z),
    };

    /// <summary>
    /// Given a mirror plane and each piece's 3-D centroid (average of its faces' mesh-space
    /// vertex positions — NOT its 2-D unfolded canvas position, which has no relation to 3-D
    /// symmetry), finds the piece whose centroid best matches the mirror of the picked piece's
    /// centroid. Returns null if no other piece is close enough to the mirrored position to be
    /// confident it's a real pair (as opposed to just "the nearest piece, however far").
    /// </summary>
    public static int? FindMirrorPiece(
        MirrorPlane plane,
        int pickedPieceId,
        IReadOnlyDictionary<int, Vector3> pieceCentroids,
        float matchToleranceMm = 5.0f)
    {
        if (!pieceCentroids.TryGetValue(pickedPieceId, out var centroid)) return null;
        var mirrored = Mirror(centroid, plane.Axis, plane.Center);

        int? best = null;
        float bestDistSq = float.MaxValue;
        foreach (var (pieceId, pieceCentroid) in pieceCentroids)
        {
            if (pieceId == pickedPieceId) continue;   // a piece straddling the mirror plane has no distinct pair
            float distSq = Vector3.DistanceSquared(pieceCentroid, mirrored);
            if (distSq < bestDistSq) { bestDistSq = distSq; best = pieceId; }
        }

        return best.HasValue && bestDistSq <= matchToleranceMm * matchToleranceMm ? best : null;
    }
}
