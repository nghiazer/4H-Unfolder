import simd

// MARK: - Polygon outward offset (outline padding)
//
// Clipper-free replacement for C# OutlinePaddingGenerator.Inflate, which uses
// Clipper.InflatePaths(..., JoinType.Round, EndType.Polygon). Inflates a closed polygon
// outward by `paddingMm`, adding round arcs at convex corners and miter/bevel joins at
// reflex corners.
//
// Limitation vs Clipper: this performs only LOCAL joins and does not remove global
// self-intersections that can appear on deeply concave outlines at large padding. For the
// small paddings used in practice (≈0.5–2 mm relative to piece size) the result matches
// Clipper closely. The Windows build remains the reference for exact parity.

enum PolygonOffset {

    private static let miterLimit: Float = 2.0

    /// Inflate a closed polygon outward by `paddingMm`.
    /// - Returns: the inflated CCW outline, or nil when input/padding is degenerate.
    static func inflate(
        _ polygon: [SIMD2<Float>],
        paddingMm: Float,
        arcToleranceMm: Float = 0.25
    ) -> [SIMD2<Float>]? {
        guard polygon.count >= 3, paddingMm > 0 else { return nil }

        // Work on a CCW copy so "outward" is well defined.
        let poly = ConvexPolygonUnion.signedArea(polygon) < 0 ? Array(polygon.reversed()) : polygon
        let n = poly.count
        let r = paddingMm
        var out: [SIMD2<Float>] = []

        for i in 0..<n {
            let prev = poly[(i - 1 + n) % n]
            let cur  = poly[i]
            let next = poly[(i + 1) % n]

            let dIn  = safeNormalize(cur - prev)
            let dOut = safeNormalize(next - cur)
            guard let eIn = dIn, let eOut = dOut else { continue }

            let nIn  = outwardNormal(eIn)   // CCW → outward
            let nOut = outwardNormal(eOut)
            let pIn  = cur + r * nIn
            let pOut = cur + r * nOut

            let cross = eIn.x * eOut.y - eIn.y * eOut.x

            if cross > 1e-6 {
                // Convex corner → round arc from nIn to nOut around cur.
                appendArc(&out, center: cur, fromDir: nIn, toDir: nOut, radius: r, tol: arcToleranceMm)
            } else if cross < -1e-6 {
                // Reflex corner → miter intersection of the two offset lines, capped.
                if let m = intersect(pIn, eIn, pOut, eOut), simd_length(m - cur) <= r * miterLimit {
                    out.append(m)
                } else {
                    out.append(pIn); out.append(pOut)   // bevel fallback
                }
            } else {
                // Straight / collinear → single offset point.
                out.append(pIn)
            }
        }

        // Deduplicate consecutive near-identical vertices.
        var cleaned: [SIMD2<Float>] = []
        for p in out where cleaned.last.map({ simd_length($0 - p) > 1e-4 }) ?? true {
            cleaned.append(p)
        }
        if cleaned.count >= 2, simd_length(cleaned.first! - cleaned.last!) < 1e-4 { cleaned.removeLast() }
        return cleaned.count >= 3 ? cleaned : nil
    }

    // MARK: - Helpers

    /// Outward normal for a CCW polygon edge direction (interior is on the left).
    private static func outwardNormal(_ dir: SIMD2<Float>) -> SIMD2<Float> {
        SIMD2(dir.y, -dir.x)
    }

    private static func safeNormalize(_ v: SIMD2<Float>) -> SIMD2<Float>? {
        let len = simd_length(v)
        return len > 1e-9 ? v / len : nil
    }

    /// Append a round arc of `radius` around `center`, sweeping CCW from unit `fromDir`
    /// to unit `toDir` (the outward side of a convex corner).
    private static func appendArc(
        _ out: inout [SIMD2<Float>],
        center: SIMD2<Float>, fromDir: SIMD2<Float>, toDir: SIMD2<Float>,
        radius: Float, tol: Float
    ) {
        let a0 = atan2(fromDir.y, fromDir.x)
        var sweep = atan2(toDir.y, toDir.x) - a0
        while sweep < 0 { sweep += 2 * Float.pi }          // CCW sweep
        // Angular step honoring the sagitta tolerance.
        let maxStep = max(0.05, 2 * acos(max(-1, 1 - tol / radius)))
        let steps = max(1, Int(ceil(sweep / maxStep)))
        for s in 0...steps {
            let a = a0 + sweep * Float(s) / Float(steps)
            out.append(center + radius * SIMD2(cos(a), sin(a)))
        }
    }

    /// Intersection of line (p1 + t·d1) and (p2 + s·d2); nil if parallel.
    private static func intersect(
        _ p1: SIMD2<Float>, _ d1: SIMD2<Float>, _ p2: SIMD2<Float>, _ d2: SIMD2<Float>
    ) -> SIMD2<Float>? {
        let denom = d1.x * d2.y - d1.y * d2.x
        if abs(denom) < 1e-9 { return nil }
        let diff = p2 - p1
        let t = (diff.x * d2.y - diff.y * d2.x) / denom
        return p1 + t * d1
    }
}
