using FourHUnfolder.Domain.DualGraph;
using FourHUnfolder.Domain.Models;
using FourHUnfolder.Domain.Results;
using FourHUnfolder.Domain.Settings;
using FourHUnfolder.Geometry.Algorithms;
using FlapOverrideDict = System.Collections.Generic.IReadOnlyDictionary<int, FourHUnfolder.Domain.Models.FlapOverride>;

namespace FourHUnfolder.Application.Services;

/// <summary>
/// Orchestrates the full unfold pipeline with optional:
///   - Real-world scale (mm per model unit)
///   - User edge-type overrides (join / split)
/// </summary>
public class UnfoldService
{
    private readonly DualGraphBuilder   _graphBuilder    = new();
    private readonly KruskalMstBuilder  _mstBuilder      = new();
    private readonly EdgeMarker         _edgeMarker      = new();
    private readonly UnfoldEngine       _unfoldEngine    = new();
    private readonly OverlapDetector    _overlapDetector = new();
    private readonly GlueTabGenerator   _tabGenerator    = new();
    private readonly PieceComputer      _pieceComputer   = new();
    private readonly PdoUnfoldBuilder   _pdoBuilder      = new();

    /// <param name="mesh">The mesh to unfold (edge Types will be written).</param>
    /// <param name="edgeOverrides">
    ///   User-modified edge types keyed by mesh edge ID.
    ///   These override the MST result for the named edges.
    /// </param>
    /// <param name="seedCount">
    ///   When the default MST (natural tie-break) produces overlaps, retry with up to this many
    ///   alternate Kruskal tie-breaks and keep whichever candidate has the fewest overlapping face
    ///   pairs. 0 disables retrying. Free when the default already has no overlaps (no retries run).
    /// </param>
    public UnfoldResult Unfold(
        Mesh mesh,
        IReadOnlyDictionary<int, EdgeType>? edgeOverrides = null,
        AppSettings.PrintSettings? printSettings = null,
        FlapOverrideDict? flapOverrides = null,
        int seedCount = 8)
    {
        var (best, bestFoldIds, dualGraph) = UnfoldOnce(mesh, edgeOverrides, printSettings, flapOverrides, mstTieBreakSeed: null);

        // Skip the retry loop entirely when it's provably futile: if no two dual-graph edges are
        // within KruskalMstBuilder.TieEpsilonRad of each other, no seed can ever select a
        // different spanning tree, so retrying would just burn full pipeline passes for zero
        // chance of a different result (see PARITY-PROGRESS.md — empirically, irregular/organic
        // meshes very often have zero exact ties, though near-ties within ~1° are common).
        if (best.HasOverlaps && seedCount > 0 && KruskalMstBuilder.HasPotentialTies(dualGraph))
        {
            int bestCount = _overlapDetector.CountOverlaps(best.Faces);
            for (int seed = 0; seed < seedCount && bestCount > 0; seed++)
            {
                var (candidate, candidateFoldIds, _) = UnfoldOnce(mesh, edgeOverrides, printSettings, flapOverrides, mstTieBreakSeed: seed);
                int count = _overlapDetector.CountOverlaps(candidate.Faces);
                if (count < bestCount)
                {
                    best         = candidate;
                    bestFoldIds  = candidateFoldIds;
                    bestCount    = count;
                }
            }
        }

        // UnfoldOnce mutates mesh.Edges[].Type as a side effect on every call — after trying
        // several seeds, re-stamp with the WINNING seed's fold set so the mesh's persistent state
        // (read directly by e.g. MainViewModel.IsEdgeFold for canvas hit-testing) matches the
        // returned result, regardless of which seed happened to run last in the loop above.
        _edgeMarker.Mark(mesh, bestFoldIds);
        return best;
    }

    private (UnfoldResult, HashSet<int>, DualGraph) UnfoldOnce(
        Mesh mesh,
        IReadOnlyDictionary<int, EdgeType>? edgeOverrides,
        AppSettings.PrintSettings? printSettings,
        FlapOverrideDict? flapOverrides,
        int? mstTieBreakSeed)
    {
        // 1. Build dual graph + MST
        var dualGraph    = _graphBuilder.Build(mesh);
        var mstEdges     = _mstBuilder.Build(dualGraph, mstTieBreakSeed);
        var foldEdgeIds  = new HashSet<int>(mstEdges.Select(e => e.SharedMeshEdgeId));

        // 2. Apply user overrides
        if (edgeOverrides != null)
        {
            foreach (var (id, type) in edgeOverrides)
            {
                if (id < 0 || id >= mesh.Edges.Count) continue;
                if (type == EdgeType.Fold) foldEdgeIds.Add(id);
                else                       foldEdgeIds.Remove(id);
            }
        }

        // 3. Stamp edge types on the mesh
        _edgeMarker.Mark(mesh, foldEdgeIds);

        // 4. BFS unfold
        var rawResult   = _unfoldEngine.Unfold(mesh, foldEdgeIds);
        var hasOverlaps = _overlapDetector.HasOverlaps(rawResult.Faces);
        var rawTabs = _tabGenerator.Generate(
            rawResult.Faces,
            (float)(printSettings?.GlueTabDepthMm      ?? 5.0),
            (float)(printSettings?.GlueTabSideAngleDeg ?? 45.0),
            printSettings?.GlueTabShape   ?? "Trapezoid",
            printSettings?.AlternateFlaps ?? false,
            mesh,
            flapOverrides);

        var tabs = (printSettings?.MergeAdjacentFlaps == true)
            ? FlapMerger.Merge(rawResult.Faces, rawTabs)
            : rawTabs;

        // Assign sequential 1-based IDs to every cut edge pair (both faces share the same ID)
        var cutEdgePairIds = new Dictionary<int, int>();
        int pairCounter = 0;
        foreach (var edge in mesh.Edges)
        {
            if (edge.FaceB >= 0 && !foldEdgeIds.Contains(edge.Id))
                cutEdgePairIds[edge.Id] = ++pairCounter;
        }

        // Build meshEdgeId → dihedral angle (degrees) for all interior fold edges
        var dihedralAngles = new Dictionary<int, float>();
        foreach (var ge in dualGraph.Edges)
            dihedralAngles[ge.SharedMeshEdgeId] = ge.Weight * (180f / MathF.PI);

        var result = new UnfoldResult(rawResult.Faces, tabs, hasOverlaps, cutEdgePairIds, dihedralAngles);
        return (result, foldEdgeIds, dualGraph);
    }

    /// <summary>
    /// Restores the pre-computed 2-D layout from a PDO file into an <see cref="UnfoldResult"/>
    /// without running the MST/BFS pipeline.
    /// Returns <c>null</c> when the mesh has no PDO layout data.
    /// </summary>
    public UnfoldResult? TryBuildFromPdoLayout(
        Mesh mesh,
        AppSettings.PrintSettings? printSettings = null,
        FlapOverrideDict? flapOverrides = null)
    {
        if (mesh.PdoLayout is null) return null;

        // Build UnfoldedFace list + classify edges using part-index comparison
        var faces = _pdoBuilder.Build(mesh);

        // Generate glue tabs on cut edges
        var rawPdoTabs = _tabGenerator.Generate(
            faces,
            (float)(printSettings?.GlueTabDepthMm      ?? 5.0),
            (float)(printSettings?.GlueTabSideAngleDeg ?? 45.0),
            printSettings?.GlueTabShape   ?? "Trapezoid",
            printSettings?.AlternateFlaps ?? false,
            mesh,
            flapOverrides);

        var tabs = (printSettings?.MergeAdjacentFlaps == true)
            ? FlapMerger.Merge(faces, rawPdoTabs)
            : rawPdoTabs;

        // Overlap detection (PDO layouts are always valid, but check anyway)
        var hasOverlaps = _overlapDetector.HasOverlaps(faces);

        // Assign 1-based IDs to cut edge pairs
        var cutEdgePairIds = new Dictionary<int, int>();
        int pairCounter = 0;
        foreach (var edge in mesh.Edges)
        {
            if (edge.FaceB >= 0 && edge.Type == EdgeType.Cut)
                cutEdgePairIds[edge.Id] = ++pairCounter;
        }

        // Build meshEdgeId → dihedral angle (degrees) so HideCoplanarFolds works for PDO layouts
        // too. This is pure mesh-topology geometry (face normals), independent of the PDO fold/cut
        // classification above, so building a fresh dual graph here is safe and correct.
        var dualGraph = _graphBuilder.Build(mesh);
        var dihedralAngles = new Dictionary<int, float>();
        foreach (var ge in dualGraph.Edges)
            dihedralAngles[ge.SharedMeshEdgeId] = ge.Weight * (180f / MathF.PI);

        return new UnfoldResult(faces, tabs, hasOverlaps, cutEdgePairIds, dihedralAngles);
    }

    /// Returns the connected components (pieces) for an already-marked mesh.
    public List<List<int>> ComputePieces(Mesh mesh) =>
        _pieceComputer.ComputePieces(mesh);

    /// Computes a uniform scale factor (mm per model unit) from the mesh bounding box.
    public static double ComputeScale(Mesh mesh, ModelScale scale)
    {
        if (mesh.Vertices.Count == 0) return 1.0;

        float minX = mesh.Vertices.Min(v => v.Position.X);
        float maxX = mesh.Vertices.Max(v => v.Position.X);
        float minY = mesh.Vertices.Min(v => v.Position.Y);
        float maxY = mesh.Vertices.Max(v => v.Position.Y);
        float minZ = mesh.Vertices.Min(v => v.Position.Z);
        float maxZ = mesh.Vertices.Max(v => v.Position.Z);

        float modelDim = scale.Axis switch
        {
            ScaleAxis.Width   => maxX - minX,
            ScaleAxis.Height  => maxY - minY,
            ScaleAxis.Depth   => maxZ - minZ,
            ScaleAxis.Longest => Math.Max(maxX - minX, Math.Max(maxY - minY, maxZ - minZ)),
            _                 => Math.Max(maxX - minX, Math.Max(maxY - minY, maxZ - minZ))
        };

        return modelDim < 1e-6f ? 1.0 : scale.TargetMm / modelDim;
    }

    /// Returns a human-readable bounding box summary for display in the dialog.
    public static string BoundingBoxInfo(Mesh mesh)
    {
        if (mesh.Vertices.Count == 0) return "—";
        float dx = mesh.Vertices.Max(v => v.Position.X) - mesh.Vertices.Min(v => v.Position.X);
        float dy = mesh.Vertices.Max(v => v.Position.Y) - mesh.Vertices.Min(v => v.Position.Y);
        float dz = mesh.Vertices.Max(v => v.Position.Z) - mesh.Vertices.Min(v => v.Position.Z);
        return $"W={dx:F3}  H={dy:F3}  D={dz:F3}  (model units)";
    }
}
