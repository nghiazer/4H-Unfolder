import simd

// MARK: - 2D unfolded face

struct UnfoldedFace {
    let faceId: Int
    let materialId: Int             // -1 = none

    let v0: SIMD2<Float>            // paper-space mm
    let v1: SIMD2<Float>
    let v2: SIMD2<Float>

    // Edge index convention: [0]=V0→V1, [1]=V1→V2, [2]=V2→V0
    let edge0IsFold: Bool;     let edge1IsFold: Bool;     let edge2IsFold: Bool
    let edge0IsBoundary: Bool; let edge1IsBoundary: Bool; let edge2IsBoundary: Bool

    let uv0: SIMD2<Float>?; let uv1: SIMD2<Float>?; let uv2: SIMD2<Float>?

    let meshEdge0: Int; let meshEdge1: Int; let meshEdge2: Int   // -1 if unknown

    // Helpers
    var vertices: [SIMD2<Float>] { [v0, v1, v2] }

    var centroid: SIMD2<Float> { (v0 + v1 + v2) / 3 }

    var aabb: (min: SIMD2<Float>, max: SIMD2<Float>) {
        let lo = simd_min(simd_min(v0, v1), v2)
        let hi = simd_max(simd_max(v0, v1), v2)
        return (lo, hi)
    }

    func edgeIsFold(_ i: Int) -> Bool {
        switch i { case 0: edge0IsFold; case 1: edge1IsFold; default: edge2IsFold }
    }
    func edgeIsBoundary(_ i: Int) -> Bool {
        switch i { case 0: edge0IsBoundary; case 1: edge1IsBoundary; default: edge2IsBoundary }
    }
    func meshEdgeId(_ i: Int) -> Int {
        switch i { case 0: meshEdge0; case 1: meshEdge1; default: meshEdge2 }
    }

    func translated(by offset: SIMD2<Float>) -> UnfoldedFace {
        UnfoldedFace(
            faceId: faceId, materialId: materialId,
            v0: v0 + offset, v1: v1 + offset, v2: v2 + offset,
            edge0IsFold: edge0IsFold, edge1IsFold: edge1IsFold, edge2IsFold: edge2IsFold,
            edge0IsBoundary: edge0IsBoundary, edge1IsBoundary: edge1IsBoundary, edge2IsBoundary: edge2IsBoundary,
            uv0: uv0, uv1: uv1, uv2: uv2,
            meshEdge0: meshEdge0, meshEdge1: meshEdge1, meshEdge2: meshEdge2
        )
    }
}

// MARK: - Glue tab

struct GlueTab {
    let faceId: Int
    let localEdgeIdx: Int       // 0, 1, or 2

    let p0: SIMD2<Float>        // base edge endpoints (on cut)
    let p1: SIMD2<Float>
    let p2: SIMD2<Float>        // inset vertices
    let p3: SIMD2<Float>

    let borderFoldStyle: FlapMode?

    /// When two adjacent tabs are merged (FlapMerger), the exact union outline is stored
    /// here as an arbitrary-length polygon. `p0…p3` still hold the first four vertices for
    /// callers that expect a quad. Mirrors C# GlueTab.MergedPolygon.
    var mergedPolygon: [SIMD2<Float>]? = nil

    /// Render outline: the merged polygon when present, otherwise the p0…p3 quad.
    var polygon: [SIMD2<Float>] { mergedPolygon ?? [p0, p1, p2, p3] }

    func translated(by offset: SIMD2<Float>) -> GlueTab {
        GlueTab(faceId: faceId, localEdgeIdx: localEdgeIdx,
                p0: p0 + offset, p1: p1 + offset,
                p2: p2 + offset, p3: p3 + offset,
                borderFoldStyle: borderFoldStyle,
                mergedPolygon: mergedPolygon?.map { $0 + offset })
    }
}

// MARK: - Complete unfold result

struct UnfoldResult {
    var faces: [UnfoldedFace]
    var tabs: [GlueTab]
    var hasOverlaps: Bool = false

    /// meshEdgeId → 1-based cut-pair number (for label printing)
    var cutEdgePairIds: [Int: Int] = [:]

    /// meshEdgeId → dihedral angle in degrees
    var edgeDihedralAngles: [Int: Float] = [:]

    /// Connected components: each inner array is a list of faceIds
    var pieces: [[Int]] = []

    // MARK: - Derived geometry

    var boundingBox: (min: SIMD2<Float>, max: SIMD2<Float>) {
        guard !faces.isEmpty else { return (.zero, .zero) }
        var lo = SIMD2<Float>(repeating:  Float.infinity)
        var hi = SIMD2<Float>(repeating: -Float.infinity)
        for f in faces {
            lo = simd_min(lo, simd_min(simd_min(f.v0, f.v1), f.v2))
            hi = simd_max(hi, simd_max(simd_max(f.v0, f.v1), f.v2))
        }
        return (lo, hi)
    }

    var pageWidth: Float  { let b = boundingBox; return b.max.x - b.min.x }
    var pageHeight: Float { let b = boundingBox; return b.max.y - b.min.y }
}
