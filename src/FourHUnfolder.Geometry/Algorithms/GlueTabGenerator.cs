using System.Numerics;
using FourHUnfolder.Domain.Results;

namespace FourHUnfolder.Geometry.Algorithms;

using static FourHUnfolder.Geometry.GeometryConstants;

/// <summary>
/// Generates trapezoidal glue tabs on every cut edge.
/// Each tab records which face+edge produced it so it can be
/// associated with the correct piece during layout.
/// </summary>
public class GlueTabGenerator
{
    public IReadOnlyList<GlueTab> Generate(IReadOnlyList<UnfoldedFace> faces,
                                           float tabDepthMm = 4f, float tabInsetRatio = 0.15f)
    {
        var tabs = new List<GlueTab>();

        foreach (var face in faces)
        {
            var verts = face.Vertices;
            for (int i = 0; i < 3; i++)
            {
                if (face.EdgeIsFold[i] || face.EdgeIsBoundary[i]) continue;

                var p0       = verts[i];
                var p1       = verts[(i + 1) % 3];
                var centroid = (verts[0] + verts[1] + verts[2]) / 3f;

                tabs.Add(BuildTab(face.FaceId, i, p0, p1, centroid, tabDepthMm, tabInsetRatio));
            }
        }

        return tabs;
    }

    private static GlueTab BuildTab(int faceId, int edgeIdx,
                                    Vector2 p0, Vector2 p1, Vector2 centroid,
                                    float tabDepthMm, float tabInsetRatio)
    {
        var edge  = p1 - p0;
        float len = edge.Length();
        if (len < GeometryConstants.DegenerateTab) return new GlueTab(faceId, edgeIdx, p0, p1, p1, p0);

        var dir  = edge / len;
        var perp = new Vector2(-dir.Y, dir.X);

        // Outward direction: away from the face centroid
        var mid      = (p0 + p1) * 0.5f;
        var toCenter = centroid - mid;
        if (Vector2.Dot(toCenter, perp) > 0f) perp = -perp;

        float inset = len * tabInsetRatio;
        var   q0    = p0 + inset * dir + tabDepthMm * perp;
        var   q1    = p1 - inset * dir + tabDepthMm * perp;

        return new GlueTab(faceId, edgeIdx, p0, p1, q1, q0);
    }
}
