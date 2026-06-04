using FourHUnfolder.Domain.Models;
using FourHUnfolder.Domain.Results;

namespace FourHUnfolder.Geometry.Algorithms;

/// <summary>
/// Builds a piece-by-piece assembly sequence from the unfolded mesh.
///
/// Algorithm:
///   1. Build a piece-adjacency graph from cut edges (two pieces are adjacent
///      if they share a cut edge in the original mesh — they will be glued).
///   2. BFS from the largest piece (root) to determine the order in which
///      each piece should be attached to the growing model.
///   3. Disconnected pieces (unreachable from root) are appended at the end.
/// </summary>
public static class AssemblyPlanner
{
    /// <param name="mesh">Mesh with edge types already set by EdgeMarker.</param>
    /// <param name="pieceGroups">
    ///   One entry per piece: GroupId and the face IDs it contains.
    /// </param>
    public static List<AssemblyStep> Build(
        Mesh mesh,
        IReadOnlyList<(int GroupId, int[] FaceIds)> pieceGroups)
    {
        if (pieceGroups.Count == 0) return [];

        // ── lookup tables ─────────────────────────────────────────────────────
        var faceToGroup  = new Dictionary<int, int>(mesh.Faces.Count);
        var groupFaceMap = new Dictionary<int, int[]>(pieceGroups.Count);

        foreach (var (gId, fIds) in pieceGroups)
        {
            groupFaceMap[gId] = fIds;
            foreach (var fId in fIds)
                faceToGroup[fId] = gId;
        }

        // ── piece-adjacency graph (cut edges only) ────────────────────────────
        var adjacency = pieceGroups.ToDictionary(
            p => p.GroupId,
            _ => new HashSet<int>());

        foreach (var edge in mesh.Edges)
        {
            if (edge.Type != EdgeType.Cut || !edge.ConnectsFaces) continue;

            if (!faceToGroup.TryGetValue(edge.FaceA, out var gA) ||
                !faceToGroup.TryGetValue(edge.FaceB, out var gB)) continue;

            if (gA == gB) continue;

            if (adjacency.TryGetValue(gA, out var setA)) setA.Add(gB);
            if (adjacency.TryGetValue(gB, out var setB)) setB.Add(gA);
        }

        // ── BFS from the largest piece ────────────────────────────────────────
        var root     = pieceGroups.OrderByDescending(p => p.FaceIds.Length).First().GroupId;
        var steps    = new List<AssemblyStep>(pieceGroups.Count);
        var visited  = new HashSet<int> { root };
        var parentOf = new Dictionary<int, int> { [root] = -1 };
        var queue    = new Queue<int>();
        queue.Enqueue(root);

        while (queue.Count > 0)
        {
            var gId   = queue.Dequeue();
            var faceIds = groupFaceMap.GetValueOrDefault(gId, []);

            steps.Add(new AssemblyStep(steps.Count, gId, parentOf[gId], faceIds));

            // Stable ordering: sort neighbours by GroupId so the sequence is
            // deterministic regardless of dictionary enumeration order.
            foreach (var nb in adjacency[gId].OrderBy(id => id))
            {
                if (!visited.Add(nb)) continue;
                parentOf[nb] = gId;
                queue.Enqueue(nb);
            }
        }

        // ── disconnected pieces (non-manifold or isolated) ────────────────────
        foreach (var (gId, fIds) in pieceGroups.OrderBy(p => p.GroupId))
        {
            if (!visited.Contains(gId))
                steps.Add(new AssemblyStep(steps.Count, gId, -1, fIds));
        }

        return steps;
    }
}
