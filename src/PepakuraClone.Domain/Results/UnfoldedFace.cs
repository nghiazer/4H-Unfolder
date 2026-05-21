using System.Numerics;

namespace PepakuraClone.Domain.Results;

/// <summary>
/// 2-D position of the three vertices of one unfolded triangle.
/// EdgeIsFold[i] corresponds to the edge from vertex i to vertex (i+1)%3.
/// </summary>
public sealed class UnfoldedFace
{
    public int     FaceId     { get; }
    public Vector2 V0         { get; }
    public Vector2 V1         { get; }
    public Vector2 V2         { get; }

    // [0]=edge V0-V1, [1]=edge V1-V2, [2]=edge V2-V0
    public bool[]  EdgeIsFold { get; }

    public UnfoldedFace(int faceId, Vector2 v0, Vector2 v1, Vector2 v2, bool[] edgeIsFold)
    {
        FaceId     = faceId;
        V0         = v0;
        V1         = v1;
        V2         = v2;
        EdgeIsFold = edgeIsFold;
    }

    public Vector2[] Vertices => [V0, V1, V2];
}
