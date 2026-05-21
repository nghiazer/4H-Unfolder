using PepakuraClone.Domain.DualGraph;
using PepakuraClone.Domain.Models;

namespace PepakuraClone.Geometry.Algorithms;

/// <summary>
/// Stamps EdgeType on every mesh edge based on whether it's in the MST.
///   MST interior edge  → Fold
///   Non-MST interior   → Cut
///   Boundary edge      → Boundary
/// </summary>
public class EdgeMarker
{
    public void Mark(Mesh mesh, IReadOnlyList<GraphEdge> mstEdges)
    {
        var mstSet = new HashSet<int>(mstEdges.Select(e => e.SharedMeshEdgeId));

        foreach (var edge in mesh.Edges)
        {
            edge.Type = edge.ConnectsFaces
                ? (mstSet.Contains(edge.Id) ? EdgeType.Fold : EdgeType.Cut)
                : EdgeType.Boundary;
        }
    }
}
