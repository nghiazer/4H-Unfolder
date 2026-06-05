import simd

// MARK: - Three-phase overlap detector (mirrors C# OverlapDetector)
//
// Phase 0: Pre-compute AABBs and global bounds
// Phase 1: Spatial grid (cell size = 2× avg AABB side, ≤ 256×256 cells)
// Phase 2+3: Candidate pairs → AABB test → SAT triangle test

struct OverlapDetector {

    func hasOverlaps(faces: [UnfoldedFace]) -> Bool {
        guard faces.count >= 2 else { return false }

        // Phase 0: AABBs
        var aabbs = [(min: SIMD2<Float>, max: SIMD2<Float>)]()
        aabbs.reserveCapacity(faces.count)
        var totalSideSum: Float = 0
        var globalMin = SIMD2<Float>(repeating:  Float.infinity)
        var globalMax = SIMD2<Float>(repeating: -Float.infinity)

        for f in faces {
            let bb = f.aabb
            aabbs.append(bb)
            totalSideSum += (bb.max.x - bb.min.x) + (bb.max.y - bb.min.y)
            globalMin = simd_min(globalMin, bb.min)
            globalMax = simd_max(globalMax, bb.max)
        }

        let totalW = globalMax.x - globalMin.x
        let totalH = globalMax.y - globalMin.y
        let avgSide = totalSideSum / Float(2 * faces.count)

        // Phase 1: Spatial grid
        let minCellSize = max(totalW, totalH) / 256
        let cellSize    = max(2 * avgSide, minCellSize, GeometryConstants.degenerateEdge)
        let gridW = max(1, Int((totalW / cellSize).rounded(.up)))
        let gridH = max(1, Int((totalH / cellSize).rounded(.up)))

        var grid = [[Int]](repeating: [], count: gridW * gridH)

        func cellIdx(x: Int, y: Int) -> Int { y * gridW + x }

        for (fi, bb) in aabbs.enumerated() {
            let cx0 = max(0, Int(((bb.min.x - globalMin.x) / cellSize).rounded(.down)))
            let cy0 = max(0, Int(((bb.min.y - globalMin.y) / cellSize).rounded(.down)))
            let cx1 = min(gridW - 1, Int(((bb.max.x - globalMin.x) / cellSize).rounded(.up)))
            let cy1 = min(gridH - 1, Int(((bb.max.y - globalMin.y) / cellSize).rounded(.up)))
            for cy in cy0...cy1 {
                for cx in cx0...cx1 {
                    grid[cellIdx(x: cx, y: cy)].append(fi)
                }
            }
        }

        // Phase 2+3: Test candidates
        var tested = Set<Int64>()

        for cell in grid where cell.count >= 2 {
            for ci in 0..<cell.count {
                for cj in (ci + 1)..<cell.count {
                    let i = cell[ci], j = cell[cj]
                    let key = Int64(min(i, j)) << 32 | Int64(max(i, j))
                    guard tested.insert(key).inserted else { continue }

                    if aabbsOverlap(aabbs[i], aabbs[j]) &&
                       trianglesOverlap(faces[i], faces[j]) {
                        return true
                    }
                }
            }
        }
        return false
    }

    // MARK: - AABB test

    private func aabbsOverlap(
        _ a: (min: SIMD2<Float>, max: SIMD2<Float>),
        _ b: (min: SIMD2<Float>, max: SIMD2<Float>)
    ) -> Bool {
        a.max.x > b.min.x && b.max.x > a.min.x &&
        a.max.y > b.min.y && b.max.y > a.min.y
    }

    // MARK: - SAT triangle overlap

    private func trianglesOverlap(_ a: UnfoldedFace, _ b: UnfoldedFace) -> Bool {
        !isSeparated(a, against: b) && !isSeparated(b, against: a)
    }

    /// Returns true if `a`'s edge axes separate the two triangles.
    private func isSeparated(_ a: UnfoldedFace, against b: UnfoldedFace) -> Bool {
        let av = a.vertices
        let bv = b.vertices

        for i in 0..<3 {
            let e    = av[(i + 1) % 3] - av[i]
            let axis = SIMD2<Float>(-e.y, e.x)
            let axisLen = simd_length(axis)
            guard axisLen > GeometryConstants.degenerateEdge else { continue }

            let eps = GeometryConstants.satTouchEpsilon * axisLen

            let aProjs = av.map { simd_dot($0, axis) }
            let bProjs = bv.map { simd_dot($0, axis) }

            let aMin = aProjs.min()!, aMax = aProjs.max()!
            let bMin = bProjs.min()!, bMax = bProjs.max()!

            // Separated if projections don't overlap (allow epsilon for shared fold edges)
            if aMax <= bMin + eps || bMax <= aMin + eps { return true }
        }
        return false
    }
}
