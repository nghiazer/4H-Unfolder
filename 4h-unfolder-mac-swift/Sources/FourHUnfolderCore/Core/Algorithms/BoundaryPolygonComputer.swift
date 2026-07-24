import simd

// MARK: - Piece outer-boundary polygon (backlog Phase 1: wire Outline Padding into export/canvas)
//
// Port of Windows FourHUnfolder.Geometry.Algorithms.BoundaryPolygonComputer.Compute/ChainEdges.
// Collects a piece's non-fold edges (cut + mesh-boundary — both get physically cut, so both are
// part of the piece's outer silhouette) and chains them into an ordered closed loop. This is the
// missing piece that left `PolygonOffset.inflate` with nothing to consume: that function inflates
// one already-ordered closed polygon, but macOS had no piece-boundary tracer to hand it one.

enum BoundaryPolygonComputer {

    private static let snapEpsMm: Float = 0.001

    /// Returns the ordered boundary polygon of a set of faces (one piece), or nil for
    /// degenerate/empty input. `vertsFor` supplies each face's triangle vertices — pass the
    /// default (raw `face.v0/v1/v2`) for export, where `result.faces` already holds final
    /// baked positions, or a transform closure (e.g. canvas's `effectiveVerts`) to trace the
    /// boundary in a piece's live rotated/offset position.
    static func compute(
        faces: [UnfoldedFace],
        vertsFor: (UnfoldedFace) -> (SIMD2<Float>, SIMD2<Float>, SIMD2<Float>) = { ($0.v0, $0.v1, $0.v2) }
    ) -> [SIMD2<Float>]? {
        guard !faces.isEmpty else { return nil }

        var edges: [(SIMD2<Float>, SIMD2<Float>)] = []
        var seenById = Set<Int>()
        var seenByCoord = Set<CoordKey>()

        for face in faces {
            let v = vertsFor(face)
            let verts = [v.0, v.1, v.2]
            for ei in 0..<3 where !face.edgeIsFold(ei) {
                let meshId = face.meshEdgeId(ei)
                if meshId >= 0 {
                    guard seenById.insert(meshId).inserted else { continue }
                } else {
                    let key = coordKey(verts[ei], verts[(ei + 1) % 3])
                    guard seenByCoord.insert(key).inserted else { continue }
                }
                edges.append((verts[ei], verts[(ei + 1) % 3]))
            }
        }

        return chainEdges(edges)
    }

    // MARK: - Helpers

    private static func chainEdges(_ edges: [(SIMD2<Float>, SIMD2<Float>)]) -> [SIMD2<Float>]? {
        guard !edges.isEmpty else { return nil }

        var polygon: [SIMD2<Float>] = [edges[0].0, edges[0].1]
        var remaining = edges
        remaining.removeFirst()

        var guardCount = 0
        while guardCount < edges.count && !remaining.isEmpty {
            guardCount += 1
            let tail = polygon[polygon.count - 1]
            guard let k = remaining.firstIndex(where: { near($0.0, tail) || near($0.1, tail) }) else { break }
            let (a, b) = remaining[k]
            polygon.append(near(a, tail) ? b : a)
            remaining.remove(at: k)
        }

        // When the chain closes the loop (last point lands back on the first), C#'s identical
        // ChainEdges leaves that duplicate in place — harmless there because Clipper2 silently
        // strips duplicate/collinear points before offsetting. `PolygonOffset.inflate` has no such
        // cleanup (documented as local-joins-only, Clipper-free), so a leftover duplicate makes it
        // treat that shared corner as two degenerate zero-length edges and drop the corner's arc
        // entirely, leaving a flat notch. Trim it here instead so `inflate` sees one clean corner.
        if polygon.count >= 4, near(polygon[0], polygon[polygon.count - 1]) {
            polygon.removeLast()
        }

        return polygon.count >= 3 ? polygon : nil
    }

    private static func near(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Bool {
        simd_length_squared(a - b) < snapEpsMm * snapEpsMm
    }

    /// Direction-independent rounded coordinate key for edge dedup when no meshEdgeId is known.
    private struct CoordKey: Hashable {
        let ax, ay, bx, by: Int64
    }

    private static func coordKey(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> CoordKey {
        let ax = Int64((a.x * 1000).rounded()), ay = Int64((a.y * 1000).rounded())
        let bx = Int64((b.x * 1000).rounded()), by = Int64((b.y * 1000).rounded())
        return ax < bx || (ax == bx && ay <= by)
            ? CoordKey(ax: ax, ay: ay, bx: bx, by: by)
            : CoordKey(ax: bx, ay: by, bx: ax, by: ay)
    }
}
