import Foundation

// Orchestrates the full unfold pipeline off the main thread.
// Being an actor gives it its own serial executor, so AppState can simply
// `await unfoldService.unfold(...)` without a manual Task.detached wrapper.

actor UnfoldService {

    /// - Parameter seedCount: when the default MST (natural tie-break) produces overlaps, retry
    ///   with up to this many alternate Kruskal tie-breaks and keep whichever candidate has the
    ///   fewest overlapping face pairs. 0 disables retrying. Free when the default already has no
    ///   overlaps (no retries run).
    func unfold(
        mesh: Mesh,
        edgeOverrides: [Int: EdgeType],
        flapOverrides: [Int: FlapOverride],
        settings: AppSettings.PrintSettings,
        meshScaleMm: Float = 1,
        seedCount: Int = 8
    ) -> UnfoldResult {
        var (best, bestFoldIds, dualGraph) = unfoldOnce(
            mesh: mesh, edgeOverrides: edgeOverrides, flapOverrides: flapOverrides,
            settings: settings, meshScaleMm: meshScaleMm, mstTieBreakSeed: nil)

        // Skip the retry loop entirely when it's provably futile: if no two dual-graph edges are
        // within KruskalMSTBuilder.tieEpsilonRad of each other, no seed can ever select a
        // different spanning tree, so retrying would just burn full pipeline passes for zero
        // chance of a different result (see PARITY-PROGRESS.md — empirically, irregular/organic
        // meshes very often have zero exact ties, though near-ties within ~1° are common).
        if best.hasOverlaps && seedCount > 0 && KruskalMSTBuilder.hasPotentialTies(graph: dualGraph) {
            var bestCount = OverlapDetector().countOverlaps(faces: best.faces)
            for seed in 0..<seedCount where bestCount > 0 {
                let (candidate, candidateFoldIds, _) = unfoldOnce(
                    mesh: mesh, edgeOverrides: edgeOverrides, flapOverrides: flapOverrides,
                    settings: settings, meshScaleMm: meshScaleMm, mstTieBreakSeed: seed)
                let count = OverlapDetector().countOverlaps(faces: candidate.faces)
                if count < bestCount {
                    best = candidate
                    bestFoldIds = candidateFoldIds
                    bestCount = count
                }
            }
        }

        // unfoldOnce mutates mesh.edges[].type as a side effect on every call — after trying
        // several seeds, re-stamp with the WINNING seed's fold set so the mesh's persistent state
        // (read directly by e.g. PieceComputer and canvas hit-testing) matches the returned
        // result, regardless of which seed happened to run last in the loop above.
        EdgeMarker().mark(mesh: mesh, foldEdgeIds: bestFoldIds)
        return best
    }

    private func unfoldOnce(
        mesh: Mesh,
        edgeOverrides: [Int: EdgeType],
        flapOverrides: [Int: FlapOverride],
        settings: AppSettings.PrintSettings,
        meshScaleMm: Float,
        mstTieBreakSeed: Int?
    ) -> (UnfoldResult, Set<Int>, DualGraph) {

        // 1. Build face-adjacency dual graph
        let dualGraph = DualGraphBuilder().build(mesh: mesh)

        // 2. Kruskal MST → preferred fold edges (flatten faces)
        let mstEdges = KruskalMSTBuilder().build(graph: dualGraph, tieBreakSeed: mstTieBreakSeed)
        var foldEdgeIds = Set(mstEdges.map { $0.sharedMeshEdgeId })

        // 3. Apply user edge overrides (toggle fold ↔ cut)
        for (eid, type) in edgeOverrides {
            if type == .fold { foldEdgeIds.insert(eid) }
            else             { foldEdgeIds.remove(eid) }
        }

        // 4. Stamp EdgeType on every mesh edge
        EdgeMarker().mark(mesh: mesh, foldEdgeIds: foldEdgeIds)

        // 5. BFS unfold → paper-space 2D positions + dihedral angles
        let engineResult = UnfoldEngine().unfold(mesh: mesh, foldEdgeIds: foldEdgeIds, meshScaleMm: meshScaleMm)

        // 6. Generate glue tabs with per-edge FlapMode overrides
        let rawTabs = GlueTabGenerator().generate(
            faces: engineResult.faces,
            mesh: mesh,
            settings: settings,
            flapOverrides: flapOverrides
        )

        // 6b. Optionally merge adjacent tabs on the same piece (mirrors C# FlapMerger gate)
        let tabs = settings.mergeAdjacentFlaps
            ? FlapMerger.merge(faces: engineResult.faces, tabs: rawTabs)
            : rawTabs

        // 7. SAT-based overlap detection
        let hasOverlaps = OverlapDetector().hasOverlaps(faces: engineResult.faces)

        // 8. Connected-component piece grouping
        let pieces = PieceComputer().computePieces(mesh: mesh)

        // 9. Assign 1-based pair numbers to cut edges (for assembly labels)
        var cutEdgePairIds: [Int: Int] = [:]
        var pairCounter = 1
        for edge in mesh.edges where edge.type == .cut && edge.connectsFaces {
            if cutEdgePairIds[edge.id] == nil {
                cutEdgePairIds[edge.id] = pairCounter
                if pairCounter < Int.max { pairCounter += 1 }
            }
        }

        let result = UnfoldResult(
            faces: engineResult.faces,
            tabs: tabs,
            hasOverlaps: hasOverlaps,
            cutEdgePairIds: cutEdgePairIds,
            edgeDihedralAngles: engineResult.dihedralAngles,
            pieces: pieces
        )
        return (result, foldEdgeIds, dualGraph)
    }
}
