import simd

// MARK: - Convex polygon boolean union
//
// Clipper-free replacement for the polygon union used by FlapMerger on Windows
// (Clipper.Union). Every glue-tab shape (trapezoid, rectangle, triangle) is convex,
// so a specialised convex-convex union is sufficient and far simpler than a general
// boolean engine.
//
// Method: collect the parts of A's boundary that lie outside B, plus the parts of B's
// boundary that lie outside A (each computed with Liang–Barsky segment clipping against
// the other convex polygon's half-planes), then stitch those sub-segments into one loop.
//
// Returns the union outline (CCW) when the two polygons overlap in area; returns nil
// when they are disjoint or merely touch at a point/edge — there is no single simple
// union polygon in those cases, and the caller keeps both tabs unmerged.

enum ConvexPolygonUnion {

    /// mm tolerance for point-on-line and endpoint stitching.
    static let eps: Float = 1e-3

    static func union(_ polyA: [SIMD2<Float>], _ polyB: [SIMD2<Float>]) -> [SIMD2<Float>]? {
        guard polyA.count >= 3, polyB.count >= 3 else { return nil }
        let a = normalizedCCW(polyA)
        let b = normalizedCCW(polyB)

        // Full containment → the outer polygon is the union.
        if allInside(a, of: b) { return b }
        if allInside(b, of: a) { return a }

        // Require genuine (positive-area) overlap; touching-only or disjoint → no merge.
        guard convexOverlap(a, b) else { return nil }

        var segs: [(SIMD2<Float>, SIMD2<Float>)] = []
        segs.append(contentsOf: outsideSubsegments(of: a, against: b))
        segs.append(contentsOf: outsideSubsegments(of: b, against: a))

        return stitch(segs)
    }

    // MARK: - Orientation

    static func signedArea(_ poly: [SIMD2<Float>]) -> Float {
        var s: Float = 0
        for i in 0..<poly.count {
            let p = poly[i], q = poly[(i + 1) % poly.count]
            s += p.x * q.y - q.x * p.y
        }
        return s * 0.5
    }

    private static func normalizedCCW(_ poly: [SIMD2<Float>]) -> [SIMD2<Float>] {
        signedArea(poly) < 0 ? poly.reversed() : poly
    }

    // MARK: - Point / polygon tests

    /// Signed distance of `p` from a CCW polygon: >= 0 inside, magnitude = distance to
    /// nearest bounding line when just outside. Returns the most-violated (smallest) value.
    private static func insideMargin(_ p: SIMD2<Float>, _ poly: [SIMD2<Float>]) -> Float {
        var minMargin = Float.greatestFiniteMagnitude
        for i in 0..<poly.count {
            let v0 = poly[i], v1 = poly[(i + 1) % poly.count]
            let dir = v1 - v0
            let len = simd_length(dir)
            guard len > 1e-9 else { continue }
            let n = SIMD2<Float>(-dir.y, dir.x) / len   // inward normal for CCW winding
            let margin = simd_dot(n, p - v0)
            minMargin = min(minMargin, margin)
        }
        return minMargin
    }

    private static func allInside(_ inner: [SIMD2<Float>], of outer: [SIMD2<Float>]) -> Bool {
        inner.allSatisfy { insideMargin($0, outer) >= -eps }
    }

    /// SAT overlap test with a strict positive threshold, so a point/edge touch is NOT
    /// treated as overlap.
    private static func convexOverlap(_ a: [SIMD2<Float>], _ b: [SIMD2<Float>]) -> Bool {
        for poly in [a, b] {
            for i in 0..<poly.count {
                let v0 = poly[i], v1 = poly[(i + 1) % poly.count]
                let edge = v1 - v0
                let len = simd_length(edge)
                guard len > 1e-9 else { continue }
                let axis = SIMD2<Float>(-edge.y, edge.x) / len
                let (aMin, aMax) = project(a, axis)
                let (bMin, bMax) = project(b, axis)
                // Gap or bare touch on this axis → separated.
                if aMax <= bMin + eps || bMax <= aMin + eps { return false }
            }
        }
        return true
    }

    private static func project(_ poly: [SIMD2<Float>], _ axis: SIMD2<Float>) -> (Float, Float) {
        var lo = Float.greatestFiniteMagnitude, hi = -Float.greatestFiniteMagnitude
        for p in poly {
            let d = simd_dot(p, axis)
            lo = min(lo, d); hi = max(hi, d)
        }
        return (lo, hi)
    }

    // MARK: - Boundary extraction

    /// Sub-segments of `poly`'s edges that lie OUTSIDE the convex polygon `clip`.
    private static func outsideSubsegments(
        of poly: [SIMD2<Float>], against clip: [SIMD2<Float>]
    ) -> [(SIMD2<Float>, SIMD2<Float>)] {
        var out: [(SIMD2<Float>, SIMD2<Float>)] = []
        for i in 0..<poly.count {
            let p0 = poly[i], p1 = poly[(i + 1) % poly.count]
            let (t0, t1) = insideInterval(p0, p1, clip)   // param range inside clip
            let d = p1 - p0
            if t0 > t1 {
                // No inside portion → the whole edge is outside clip. Emit once.
                out.append((p0, p1))
                continue
            }
            // Leading outside part [0, t0]
            if t0 > eps01(d) { out.append((p0, p0 + t0 * d)) }
            // Trailing outside part [t1, 1]
            if t1 < 1 - eps01(d) { out.append((p0 + t1 * d, p1)) }
        }
        return out
    }

    /// Relative epsilon so a `eps`-mm gap maps onto the segment's parameter space.
    private static func eps01(_ d: SIMD2<Float>) -> Float {
        let len = simd_length(d)
        return len > 1e-9 ? eps / len : 1
    }

    /// Liang–Barsky clip of segment p0→p1 against convex CCW `clip`.
    /// Returns the parameter interval [t0, t1] that lies inside clip. When the segment is
    /// wholly outside, returns (1, 0) so both outside parts collapse to the full segment.
    private static func insideInterval(
        _ p0: SIMD2<Float>, _ p1: SIMD2<Float>, _ clip: [SIMD2<Float>]
    ) -> (Float, Float) {
        var tEnter: Float = 0
        var tExit: Float = 1
        let d = p1 - p0
        for i in 0..<clip.count {
            let v0 = clip[i], v1 = clip[(i + 1) % clip.count]
            let edge = v1 - v0
            let len = simd_length(edge)
            guard len > 1e-9 else { continue }
            let n = SIMD2<Float>(-edge.y, edge.x) / len   // inward normal (CCW)
            let denom = simd_dot(n, d)
            let numer = simd_dot(n, p0 - v0)              // want numer + t*denom >= 0
            if abs(denom) < 1e-9 {
                if numer < -eps { return (1, 0) }         // parallel & outside this half-plane
            } else {
                let t = -numer / denom
                if denom > 0 { tEnter = max(tEnter, t) }  // entering half-plane
                else         { tExit  = min(tExit,  t) }  // leaving half-plane
                if tEnter > tExit { return (1, 0) }        // no inside portion
            }
        }
        return (max(0, tEnter), min(1, tExit))
    }

    // MARK: - Stitching

    private static func stitch(_ segsIn: [(SIMD2<Float>, SIMD2<Float>)]) -> [SIMD2<Float>]? {
        var segs = segsIn.filter { simd_length($0.1 - $0.0) > eps }
        guard segs.count >= 3 else { return nil }

        var loop: [SIMD2<Float>] = []
        let current = segs.removeFirst()
        loop.append(current.0)
        let start = current.0
        var end = current.1

        var guardCount = 0
        let maxIter = segsIn.count + 4
        while !segs.isEmpty && guardCount <= maxIter {
            guardCount += 1
            var matched = false
            for (idx, s) in segs.enumerated() {
                if near(s.0, end) { loop.append(s.0); end = s.1; segs.remove(at: idx); matched = true; break }
                if near(s.1, end) { loop.append(s.1); end = s.0; segs.remove(at: idx); matched = true; break }
            }
            if !matched { break }
            if near(end, start) { break }   // loop closed
        }

        // Deduplicate consecutive near-identical vertices.
        var cleaned: [SIMD2<Float>] = []
        for p in loop where cleaned.last.map({ !near($0, p) }) ?? true {
            cleaned.append(p)
        }
        if cleaned.count >= 2, near(cleaned.first!, cleaned.last!) { cleaned.removeLast() }
        return cleaned.count >= 3 ? cleaned : nil
    }

    private static func near(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Bool {
        simd_length(a - b) < eps
    }
}
