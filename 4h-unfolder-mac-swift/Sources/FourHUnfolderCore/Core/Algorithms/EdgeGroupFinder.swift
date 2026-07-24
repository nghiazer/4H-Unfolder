import simd

// MARK: - Connected cut-edge group (GĐ3.3: port of Windows MainViewModel.FindAdjacentCutEdgeGroup)
//
// "Join connected cut edges" (rodrigorc-style batch edge operation): starting from one clicked
// cut edge, finds every other cut edge transitively connected to it via a shared 2D paper-space
// vertex (BFS), so the whole chain can be converted to Fold in one action instead of one edge at
// a time. Windows already has this (via a right-click canvas context menu); this was the last
// tracked cross-platform parity gap for GĐ3.3 after investigation showed the rest of rodrigorc's
// Edge/Flap/Face-rotate mode set already exists on both platforms in equivalent form.

enum EdgeGroupFinder {
    /// Returns the set of cut mesh-edge IDs connected (via shared 2D vertices) to `startEdgeId`,
    /// or empty if `startEdgeId` isn't a currently-cut edge in `result`.
    static func findAdjacentCutEdgeGroup(startEdgeId: Int, result: UnfoldResult) -> Set<Int> {
        let epsSquared: Float = 0.01 * 0.01

        // Build meshEdgeId → (vertex A, vertex B) for every currently-cut edge.
        var cutVerts: [Int: (SIMD2<Float>, SIMD2<Float>)] = [:]
        for face in result.faces {
            let verts = [face.v0, face.v1, face.v2]
            for i in 0..<3 where !face.edgeIsFold(i) && !face.edgeIsBoundary(i) {
                let eid = face.meshEdgeId(i)
                if eid >= 0 && cutVerts[eid] == nil {
                    cutVerts[eid] = (verts[i], verts[(i + 1) % 3])
                }
            }
        }
        guard cutVerts[startEdgeId] != nil else { return [] }

        func nearSq(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Bool {
            let d = a - b
            return d.x * d.x + d.y * d.y < epsSquared
        }

        var visited: Set<Int> = [startEdgeId]
        var queue = [startEdgeId]
        var qi = 0
        while qi < queue.count {
            let curr = queue[qi]; qi += 1
            let (cA, cB) = cutVerts[curr]!
            for (eid, verts) in cutVerts where !visited.contains(eid) {
                let (a, b) = verts
                if nearSq(cA, a) || nearSq(cA, b) || nearSq(cB, a) || nearSq(cB, b) {
                    visited.insert(eid)
                    queue.append(eid)
                }
            }
        }
        return visited
    }
}
