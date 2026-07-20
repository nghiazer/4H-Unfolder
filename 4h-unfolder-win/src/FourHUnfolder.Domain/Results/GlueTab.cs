using System.Numerics;
using FourHUnfolder.Domain.Models;

namespace FourHUnfolder.Domain.Results;

/// <summary>
/// Trapezoidal glue tab on a cut edge.
/// P0, P1 are on the cut edge; P2, P3 are the inset/offset points.
/// FaceId + LocalEdgeIdx identify the originating face edge.
/// </summary>
public sealed class GlueTab
{
    public int    FaceId       { get; }
    public int    LocalEdgeIdx { get; }  // 0,1,2 → edge V0-V1, V1-V2, V2-V0

    public Vector2 P0 { get; }
    public Vector2 P1 { get; }
    public Vector2 P2 { get; }
    public Vector2 P3 { get; }

    /// Non-null only for border-edge tabs; indicates the fold annotation style.
    public FlapMode? BorderFoldStyle { get; }

    // When non-null, this is a merged tab whose outline has more than 4 vertices.
    private readonly Vector2[]? _mergedPolygon;

    public GlueTab(int faceId, int localEdgeIdx,
                   Vector2 p0, Vector2 p1, Vector2 p2, Vector2 p3,
                   FlapMode? borderFoldStyle = null,
                   Vector2[]? mergedPolygon = null)
    {
        FaceId          = faceId;
        LocalEdgeIdx    = localEdgeIdx;
        P0 = p0; P1 = p1; P2 = p2; P3 = p3;
        BorderFoldStyle = borderFoldStyle;
        _mergedPolygon  = mergedPolygon;
    }

    public Vector2[] Vertices => _mergedPolygon ?? [P0, P1, P2, P3];
}
