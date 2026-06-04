using System.Numerics;
using FourHUnfolder.Domain.Models;
using FourHUnfolder.Domain.Results;

namespace FourHUnfolder.Geometry.Algorithms;

using static FourHUnfolder.Geometry.GeometryConstants;

/// <summary>
/// Generates glue tabs on cut edges.
/// Supports Trapezoid / Rectangle / Triangle shapes, alternate-flap placement,
/// and per-edge overrides (position + border-tab generation).
/// </summary>
public class GlueTabGenerator
{
    public IReadOnlyList<GlueTab> Generate(
        IReadOnlyList<UnfoldedFace> faces,
        float tabDepthMm      = 5f,
        float sideAngleDeg    = 45f,
        string tabShape       = "Trapezoid",
        bool alternateFlaps   = false,
        Mesh? mesh            = null,
        IReadOnlyDictionary<int, FlapOverride>? flapOverrides = null)
    {
        var tabs = new List<GlueTab>();

        // Build alternate-flap exclusion set: for each cut mesh edge, only the face
        // with the lower FaceId gets a tab when alternateFlaps is enabled.
        HashSet<(int faceId, int edgeIdx)>? alternateDeny = null;
        if (alternateFlaps && mesh != null)
        {
            alternateDeny = new HashSet<(int, int)>();
            foreach (var face in faces)
            {
                var mf = mesh.Faces[face.FaceId];
                for (int i = 0; i < 3; i++)
                {
                    if (face.EdgeIsFold[i] || face.EdgeIsBoundary[i]) continue;
                    int eId = mf.EdgeIds[i];
                    var me  = mesh.Edges[eId];
                    if (me.FaceB >= 0 && face.FaceId != Math.Min(me.FaceA, me.FaceB))
                        alternateDeny.Add((face.FaceId, i));
                }
            }
        }

        foreach (var face in faces)
        {
            var verts    = face.Vertices;
            var centroid = (verts[0] + verts[1] + verts[2]) / 3f;

            for (int i = 0; i < 3; i++)
            {
                // Resolve mesh edge ID for override lookup
                int meshEdgeId = face.MeshEdgeIds[i] >= 0
                    ? face.MeshEdgeIds[i]
                    : (mesh != null ? mesh.Faces[face.FaceId].EdgeIds[i] : -1);

                FlapOverride? ov = (meshEdgeId >= 0 && flapOverrides != null)
                    ? flapOverrides.GetValueOrDefault(meshEdgeId)
                    : null;
                FlapMode mode = ov?.Mode ?? FlapMode.Default;

                var p0 = verts[i];
                var p1 = verts[(i + 1) % 3];

                switch (mode)
                {
                    case FlapMode.Default:
                        if (face.EdgeIsFold[i] || face.EdgeIsBoundary[i]) continue;
                        if (alternateDeny != null && alternateDeny.Contains((face.FaceId, i))) continue;
                        tabs.Add(CreateTab(face.FaceId, i, p0, p1, centroid, tabDepthMm, sideAngleDeg, tabShape));
                        break;

                    case FlapMode.OffOff_NoFlap:
                    case FlapMode.Border_NoFlap:
                        // Explicitly suppress tab — skip fold/boundary checks too
                        continue;

                    case FlapMode.OnOn_BothSides:
                        // Force tab on both faces — skip fold/boundary and alternateDeny
                        if (face.EdgeIsFold[i]) continue;  // fold edges never get tabs
                        tabs.Add(CreateTab(face.FaceId, i, p0, p1, centroid, tabDepthMm, sideAngleDeg, tabShape));
                        break;

                    case FlapMode.OnOn_ThisSide:
                        // Tab on PrimaryFaceId only; suppress on the partner
                        if (face.EdgeIsFold[i] || face.EdgeIsBoundary[i]) continue;
                        if (ov!.PrimaryFaceId >= 0 && face.FaceId != ov.PrimaryFaceId) continue;
                        tabs.Add(CreateTab(face.FaceId, i, p0, p1, centroid, tabDepthMm, sideAngleDeg, tabShape));
                        break;

                    case FlapMode.OffOn_OtherSide:
                    case FlapMode.SwitchPosition:
                        // Tab on the partner face only (suppress this face if it's PrimaryFaceId)
                        if (face.EdgeIsFold[i] || face.EdgeIsBoundary[i]) continue;
                        if (ov!.PrimaryFaceId >= 0 && face.FaceId == ov.PrimaryFaceId) continue;
                        tabs.Add(CreateTab(face.FaceId, i, p0, p1, centroid, tabDepthMm, sideAngleDeg, tabShape));
                        break;

                    case FlapMode.Border_MountainFold:
                    case FlapMode.Border_ValleyFold:
                    case FlapMode.Border_NoFold:
                        // Generate a tab on this border edge (normally skipped)
                        if (face.EdgeIsFold[i]) continue;
                        tabs.Add(CreateTab(face.FaceId, i, p0, p1, centroid, tabDepthMm, sideAngleDeg, tabShape, mode));
                        break;
                }
            }
        }

        return tabs;
    }

    private static GlueTab CreateTab(int faceId, int edgeIdx,
                                    Vector2 p0, Vector2 p1, Vector2 centroid,
                                    float depth, float sideAngleDeg, string shape,
                                    FlapMode? borderFoldStyle = null)
    {
        var edge  = p1 - p0;
        float len = edge.Length();
        if (len < GeometryConstants.DegenerateTab) return new GlueTab(faceId, edgeIdx, p0, p1, p1, p0, borderFoldStyle);

        var dir  = edge / len;
        var perp = new Vector2(-dir.Y, dir.X);

        var mid      = (p0 + p1) * 0.5f;
        var toCenter = centroid - mid;
        if (Vector2.Dot(toCenter, perp) > 0f) perp = -perp;

        return shape switch
        {
            "Rectangle" => CreateRect    (faceId, edgeIdx, p0, p1, perp, depth, borderFoldStyle),
            "Triangle"  => CreateTriangle(faceId, edgeIdx, p0, p1, perp, depth, borderFoldStyle),
            _           => CreateTrapezoid(faceId, edgeIdx, p0, p1, dir, perp, depth, sideAngleDeg, borderFoldStyle)
        };
    }

    private static GlueTab CreateTrapezoid(int faceId, int edgeIdx,
        Vector2 p0, Vector2 p1, Vector2 dir, Vector2 perp, float depth, float sideAngleDeg,
        FlapMode? borderFoldStyle)
    {
        float len      = (p1 - p0).Length();
        float clampedAngle = Math.Clamp(sideAngleDeg, 1f, 90f);
        float angleRad = clampedAngle * MathF.PI / 180f;
        float inset = depth / MathF.Tan(angleRad);
        inset = Math.Min(inset, len * 0.45f);
        var q0 = p0 + inset * dir + depth * perp;
        var q1 = p1 - inset * dir + depth * perp;
        return new GlueTab(faceId, edgeIdx, p0, p1, q1, q0, borderFoldStyle);
    }

    private static GlueTab CreateRect(int faceId, int edgeIdx,
        Vector2 p0, Vector2 p1, Vector2 perp, float depth, FlapMode? borderFoldStyle)
    {
        var q0 = p0 + depth * perp;
        var q1 = p1 + depth * perp;
        return new GlueTab(faceId, edgeIdx, p0, p1, q1, q0, borderFoldStyle);
    }

    private static GlueTab CreateTriangle(int faceId, int edgeIdx,
        Vector2 p0, Vector2 p1, Vector2 perp, float depth, FlapMode? borderFoldStyle)
    {
        var tip = (p0 + p1) * 0.5f + depth * perp;
        return new GlueTab(faceId, edgeIdx, p0, p1, tip, tip, borderFoldStyle);
    }
}
