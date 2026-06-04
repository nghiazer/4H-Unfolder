using FourHUnfolder.Domain.Models;

namespace FourHUnfolder.Geometry.Algorithms;

/// <summary>
/// Computes connected components of the fold graph.
/// Each component = one independent paper piece.
/// The component key is the smallest face ID in the group.
/// </summary>
public class PieceComputer
{
    public List<List<int>> ComputePieces(Mesh mesh)
    {
        var uf = new UnionFind(mesh.Faces.Count);

        foreach (var edge in mesh.Edges)
        {
            if (edge.Type == EdgeType.Fold && edge.ConnectsFaces)
                uf.Union(edge.FaceA, edge.FaceB);
        }

        return mesh.Faces
            .GroupBy(f => uf.Find(f.Id))
            .OrderBy(g => g.Key)
            .Select(g => g.Select(f => f.Id).ToList())
            .ToList();
    }
}
