using System.Numerics;
using Clipper2Lib;
using FourHUnfolder.Domain.Models;
using FourHUnfolder.Domain.Results;

namespace FourHUnfolder.Geometry.Algorithms;

/// <summary>
/// Merges pairs of adjacent glue tabs (tabs that share a corner vertex on the same piece)
/// into single larger polygons using Clipper2 union operations.
/// </summary>
public static class FlapMerger
{
    private const float SnapEps = 0.01f; // mm tolerance for vertex sharing

    /// <param name="faces">Unfolded faces with EdgeIsFold flags (used to determine piece membership).</param>
    /// <param name="tabs">All glue tabs (across all pieces).</param>
    /// <returns>New tab list with adjacent pairs replaced by merged tabs where possible.</returns>
    public static IReadOnlyList<GlueTab> Merge(
        IReadOnlyList<UnfoldedFace> faces,
        IReadOnlyList<GlueTab> tabs)
    {
        if (tabs.Count < 2) return tabs;

        // Build face→pieceId via union-find over fold edges
        var uf = new UnionFind(faces.Count == 0 ? 1 : faces.Max(f => f.FaceId) + 1);
        foreach (var face in faces)
        {
            for (int i = 0; i < 3; i++)
            {
                if (!face.EdgeIsFold[i]) continue;
                // Find the adjacent face sharing this fold edge — it shares the same two vertices
                // We only have faceId here; find the pair by matching mesh edge IDs when available
                // Fallback: union faces that share a fold edge (linked by MeshEdgeIds)
            }
        }

        // Simpler: build piece mapping using UnionFind on face connectivity via fold edges.
        // We use meshEdgeId (when valid) to link faces sharing a fold edge.
        var edgeToFaces = new Dictionary<int, List<int>>();
        foreach (var face in faces)
        {
            for (int i = 0; i < 3; i++)
            {
                if (!face.EdgeIsFold[i]) continue;
                int eid = face.MeshEdgeIds[i];
                if (eid < 0) continue;
                if (!edgeToFaces.TryGetValue(eid, out var lst))
                    edgeToFaces[eid] = lst = new List<int>();
                lst.Add(face.FaceId);
            }
        }
        foreach (var (_, lst) in edgeToFaces)
            for (int i = 1; i < lst.Count; i++)
                uf.Union(lst[0], lst[i]);

        // Map tab → pieceRoot so tabs in the same piece can be found
        var tabPieceRoot = tabs.Select(t => uf.Find(t.FaceId)).ToList();

        // Group tab indices by pieceRoot
        var byPiece = new Dictionary<int, List<int>>();
        for (int i = 0; i < tabs.Count; i++)
        {
            var root = tabPieceRoot[i];
            if (!byPiece.TryGetValue(root, out var lst))
                byPiece[root] = lst = new List<int>();
            lst.Add(i);
        }

        var merged    = new HashSet<int>(); // tab indices already consumed by a merge
        var result    = new List<GlueTab>(tabs.Count);

        foreach (var (_, indices) in byPiece)
        {
            // Find adjacent pairs within the piece
            // Build adjacency: tab i is adjacent to tab j if they share a base vertex
            for (int a = 0; a < indices.Count; a++)
            {
                int ia = indices[a];
                if (merged.Contains(ia)) continue;

                var ta = tabs[ia];

                for (int b = a + 1; b < indices.Count; b++)
                {
                    int ib = indices[b];
                    if (merged.Contains(ib)) continue;

                    var tb = tabs[ib];

                    if (!SharesBaseVertex(ta, tb)) continue;

                    // Union the two tab polygons
                    var unionPoly = TryUnion(ta.Vertices, tb.Vertices);
                    if (unionPoly != null && unionPoly.Count >= 3)
                    {
                        // Prefer non-null BorderFoldStyle from either tab
                        var style = ta.BorderFoldStyle ?? tb.BorderFoldStyle;
                        result.Add(BuildMergedTab(ta.FaceId, ta.LocalEdgeIdx, style, unionPoly));
                        merged.Add(ia);
                        merged.Add(ib);
                        break; // ta is now consumed — stop looking for ta's partner
                    }
                }
            }
        }

        // Add all non-merged tabs unchanged
        for (int i = 0; i < tabs.Count; i++)
            if (!merged.Contains(i))
                result.Add(tabs[i]);

        return result;
    }

    // ── helpers ──────────────────────────────────────────────────────────────────

    private static bool SharesBaseVertex(GlueTab a, GlueTab b)
    {
        // Base vertices are P0 and P1
        return Near(a.P0, b.P0) || Near(a.P0, b.P1)
            || Near(a.P1, b.P0) || Near(a.P1, b.P1);
    }

    private static bool Near(Vector2 a, Vector2 b)
    {
        var d = a - b;
        return d.X * d.X + d.Y * d.Y < SnapEps * SnapEps;
    }

    private static List<Vector2>? TryUnion(Vector2[] polyA, Vector2[] polyB)
    {
        try
        {
            var pathA = new PathD(polyA.Select(v => new PointD(v.X, v.Y)));
            var pathB = new PathD(polyB.Select(v => new PointD(v.X, v.Y)));
            var subj  = new PathsD { pathA };
            var clip  = new PathsD { pathB };

            var result = Clipper.Union(subj, clip, FillRule.NonZero, 4);
            if (result.Count == 0 || result[0].Count < 3) return null;

            return result[0].Select(p => new Vector2((float)p.x, (float)p.y)).ToList();
        }
        catch { return null; }
    }

    private static GlueTab BuildMergedTab(int faceId, int localEdgeIdx, FlapMode? borderFoldStyle, List<Vector2> polygon)
    {
        var arr = polygon.ToArray();
        return new GlueTab(faceId, localEdgeIdx, arr[0], arr[1],
            arr.Length > 2 ? arr[2] : arr[0],
            arr.Length > 3 ? arr[3] : arr[0],
            borderFoldStyle: borderFoldStyle,
            mergedPolygon: arr);
    }
}
