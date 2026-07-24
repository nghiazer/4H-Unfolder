import simd

// MARK: - Piece alignment (GĐ3.3: port of Windows MainViewModel.AlignSelected / PatternCanvasControl.PieceAabb)
//
// Pure geometry extracted here (rather than kept inline in AppState.alignSelectedPieces) so it's
// unit-testable: AppState.swift lives in the App executable target, which FourHUnfolderTests does
// not depend on — mirrors the PieceRotationTests.swift / rotated90InLocalBBox precedent from GĐ3.1.

enum PieceAlignMode { case left, right, top, bottom, centerH, centerV }

enum PieceAligner {
    /// Bbox center of a piece's raw (un-rotated, un-offset) face positions.
    static func pieceCenter(forPieceIdx pi: Int, result: UnfoldResult) -> SIMD2<Float> {
        let faceSet = Set(result.pieces[pi])
        let faces = result.faces.filter { faceSet.contains($0.faceId) }
        guard !faces.isEmpty else { return .zero }
        let allX = faces.flatMap { [$0.v0.x, $0.v1.x, $0.v2.x] }
        let allY = faces.flatMap { [$0.v0.y, $0.v1.y, $0.v2.y] }
        return SIMD2((allX.min()! + allX.max()!) / 2, (allY.min()! + allY.max()!) / 2)
    }

    private static func rotated(_ v: SIMD2<Float>, around center: SIMD2<Float>, degrees: Float) -> SIMD2<Float> {
        guard abs(degrees) > 0.001 else { return v }
        let r = degrees * .pi / 180
        let (cs, sn) = (cos(r), sin(r))
        let d = v - center
        return SIMD2(d.x * cs - d.y * sn, d.x * sn + d.y * cs) + center
    }

    /// Effective (rotated + offset) AABB of a piece, in the same paper-space units as `result`.
    static func effectiveAABB(forPieceIdx pi: Int, result: UnfoldResult,
                              rotationDeg: Float, offset: SIMD2<Float>) -> (min: SIMD2<Float>, max: SIMD2<Float>) {
        let faceIds = Set(result.pieces[pi])
        let center = pieceCenter(forPieceIdx: pi, result: result)
        var lo = SIMD2<Float>(repeating: .infinity)
        var hi = SIMD2<Float>(repeating: -.infinity)
        for face in result.faces where faceIds.contains(face.faceId) {
            for v in [face.v0, face.v1, face.v2] {
                let p = rotated(v, around: center, degrees: rotationDeg) + offset
                lo = simd_min(lo, p); hi = simd_max(hi, p)
            }
        }
        return (lo, hi)
    }

    /// Returns the per-piece offset DELTA to add to each selected piece's current offset so their
    /// effective bounding boxes align per `mode`. Requires `selected.count >= 2` after filtering
    /// out-of-range indices — returns empty otherwise (matches AppState's no-op guard).
    static func alignmentDeltas(
        result: UnfoldResult,
        selected: [Int],
        pieceOffsets: [Int: SIMD2<Float>],
        pieceRotations: [Int: Float],
        mode: PieceAlignMode
    ) -> [Int: SIMD2<Float>] {
        let sel = selected.filter { $0 < result.pieces.count }
        guard sel.count >= 2 else { return [:] }

        let boxes = sel.map { pi -> (pi: Int, box: (min: SIMD2<Float>, max: SIMD2<Float>)) in
            let rot = pieceRotations[pi] ?? 0
            let off = pieceOffsets[pi] ?? .zero
            return (pi, effectiveAABB(forPieceIdx: pi, result: result, rotationDeg: rot, offset: off))
        }
        let refL  = boxes.map(\.box.min.x).min()!
        let refR  = boxes.map(\.box.max.x).max()!
        let refT  = boxes.map(\.box.min.y).min()!
        let refB  = boxes.map(\.box.max.y).max()!
        let refCH = (refL + refR) / 2
        let refCV = (refT + refB) / 2

        var deltas: [Int: SIMD2<Float>] = [:]
        for (pi, box) in boxes {
            var d = SIMD2<Float>.zero
            switch mode {
            case .left:    d.x = refL  - box.min.x
            case .right:   d.x = refR  - box.max.x
            case .centerH: d.x = refCH - (box.min.x + box.max.x) / 2
            case .top:     d.y = refT  - box.min.y
            case .bottom:  d.y = refB  - box.max.y
            case .centerV: d.y = refCV - (box.min.y + box.max.y) / 2
            }
            deltas[pi] = d
        }
        return deltas
    }
}
