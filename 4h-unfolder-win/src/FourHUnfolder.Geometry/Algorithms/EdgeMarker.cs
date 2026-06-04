using FourHUnfolder.Domain.Models;

namespace FourHUnfolder.Geometry.Algorithms;

/// <summary>
/// Stamps EdgeType on every mesh edge based on whether it's in the MST.
///   MST interior edge  → Fold
///   Non-MST interior   → Cut
///   Boundary edge      → Boundary
/// </summary>
public class EdgeMarker
{
    public void Mark(Mesh mesh, IReadOnlySet<int> foldEdgeIds)
    {
        foreach (var edge in mesh.Edges)
        {
            edge.Type = edge.ConnectsFaces
                ? (foldEdgeIds.Contains(edge.Id) ? EdgeType.Fold : EdgeType.Cut)
                : EdgeType.Boundary;
        }
    }
}
