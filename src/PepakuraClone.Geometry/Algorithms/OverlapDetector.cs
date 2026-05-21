using System.Numerics;
using PepakuraClone.Domain.Results;

namespace PepakuraClone.Geometry.Algorithms;

/// <summary>
/// O(n²) overlap check using the Separating Axis Theorem for convex polygons.
/// Good enough for moderate-sized meshes; replace with a spatial index for large ones.
/// </summary>
public class OverlapDetector
{
    public bool HasOverlaps(IReadOnlyList<UnfoldedFace> faces)
    {
        for (int i = 0; i < faces.Count; i++)
        for (int j = i + 1; j < faces.Count; j++)
            if (TrianglesOverlap(faces[i], faces[j]))
                return true;

        return false;
    }

    private static bool TrianglesOverlap(UnfoldedFace a, UnfoldedFace b)
    {
        var ta = a.Vertices;
        var tb = b.Vertices;
        // SAT: no overlap if any separating axis exists
        return !HasSeparatingAxis(ta, tb) && !HasSeparatingAxis(tb, ta);
    }

    private static bool HasSeparatingAxis(Vector2[] a, Vector2[] b)
    {
        for (int i = 0; i < 3; i++)
        {
            var edge  = a[(i + 1) % 3] - a[i];
            var axis  = new Vector2(-edge.Y, edge.X);  // outward normal

            var (minA, maxA) = Project(a, axis);
            var (minB, maxB) = Project(b, axis);

            if (maxA <= minB + 1e-5f || maxB <= minA + 1e-5f)
                return true;  // separated on this axis
        }
        return false;
    }

    private static (float min, float max) Project(Vector2[] verts, Vector2 axis)
    {
        float d0 = Vector2.Dot(verts[0], axis);
        float d1 = Vector2.Dot(verts[1], axis);
        float d2 = Vector2.Dot(verts[2], axis);
        return (MathF.Min(d0, MathF.Min(d1, d2)), MathF.Max(d0, MathF.Max(d1, d2)));
    }
}
