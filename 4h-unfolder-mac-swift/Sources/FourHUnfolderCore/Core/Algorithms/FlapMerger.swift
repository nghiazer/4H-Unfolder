import simd

// MARK: - Flap merger
//
// Mirrors C# FlapMerger: merges pairs of adjacent glue tabs (tabs that share a corner
// vertex on the same piece) into single larger polygons. The Windows version uses
// Clipper2's boolean union; here we use the dependency-free ConvexPolygonUnion, which is
// sufficient because every tab shape is convex.

enum FlapMerger {

    /// mm tolerance for two tabs sharing a base-edge vertex (matches C# SnapEps).
    private static let snapEps: Float = 0.01

    /// - Parameters:
    ///   - faces: unfolded faces (fold flags used to group faces into pieces).
    ///   - tabs:  all glue tabs across all pieces.
    /// - Returns: a new tab list with adjacent pairs replaced by merged tabs where possible.
    static func merge(faces: [UnfoldedFace], tabs: [GlueTab]) -> [GlueTab] {
        if tabs.count < 2 { return tabs }

        // Face → piece via union-find over fold edges (faces sharing a fold edge = one piece).
        let maxFaceId = faces.map(\.faceId).max() ?? 0
        let uf = UnionFind(count: maxFaceId + 1)

        var edgeToFaces: [Int: [Int]] = [:]
        for face in faces {
            for i in 0..<3 where face.edgeIsFold(i) {
                let eid = face.meshEdgeId(i)
                guard eid >= 0 else { continue }
                edgeToFaces[eid, default: []].append(face.faceId)
            }
        }
        for (_, lst) in edgeToFaces where lst.count > 1 {
            for i in 1..<lst.count { _ = uf.union(lst[0], lst[i]) }
        }

        // Group tab indices by piece root.
        func pieceRoot(_ faceId: Int) -> Int {
            (faceId >= 0 && faceId <= maxFaceId) ? uf.find(faceId) : faceId
        }
        var byPiece: [Int: [Int]] = [:]
        for (i, tab) in tabs.enumerated() {
            byPiece[pieceRoot(tab.faceId), default: []].append(i)
        }

        var consumed = Set<Int>()
        var result: [GlueTab] = []
        result.reserveCapacity(tabs.count)

        for (_, indices) in byPiece {
            for a in 0..<indices.count {
                let ia = indices[a]
                if consumed.contains(ia) { continue }
                let ta = tabs[ia]

                for b in (a + 1)..<indices.count {
                    let ib = indices[b]
                    if consumed.contains(ib) { continue }
                    let tb = tabs[ib]

                    guard sharesBaseVertex(ta, tb) else { continue }
                    guard let unionPoly = ConvexPolygonUnion.union(ta.polygon, tb.polygon),
                          unionPoly.count >= 3 else { continue }

                    let style = ta.borderFoldStyle ?? tb.borderFoldStyle
                    result.append(buildMergedTab(faceId: ta.faceId, localEdgeIdx: ta.localEdgeIdx,
                                                  borderFoldStyle: style, polygon: unionPoly))
                    consumed.insert(ia)
                    consumed.insert(ib)
                    break   // ta consumed — stop searching for its partner
                }
            }
        }

        // Emit all non-merged tabs unchanged.
        for (i, tab) in tabs.enumerated() where !consumed.contains(i) {
            result.append(tab)
        }
        return result
    }

    // MARK: - Helpers

    private static func sharesBaseVertex(_ a: GlueTab, _ b: GlueTab) -> Bool {
        near(a.p0, b.p0) || near(a.p0, b.p1) || near(a.p1, b.p0) || near(a.p1, b.p1)
    }

    private static func near(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Bool {
        simd_length_squared(a - b) < snapEps * snapEps
    }

    private static func buildMergedTab(
        faceId: Int, localEdgeIdx: Int, borderFoldStyle: FlapMode?, polygon: [SIMD2<Float>]
    ) -> GlueTab {
        GlueTab(
            faceId: faceId, localEdgeIdx: localEdgeIdx,
            p0: polygon[0],
            p1: polygon[1],
            p2: polygon.count > 2 ? polygon[2] : polygon[0],
            p3: polygon.count > 3 ? polygon[3] : polygon[0],
            borderFoldStyle: borderFoldStyle,
            mergedPolygon: polygon
        )
    }
}
