import simd

// MARK: - Geometry constants (tuned for mm-scale models, mirrors C# GeometryConstants)

enum GeometryConstants {
    static let degenerateEdge: Float  = 1e-6   // coincident vertices (< 1 nm)
    static let degenerateFace: Float  = 1e-10  // zero-area triangle
    static let degenerateTab: Float   = 1e-4   // tab edge too short to print (< 0.1 mm)
    static let satTouchEpsilon: Float = 1e-5   // SAT shared fold-edge tolerance
}

// MARK: - Triangle apex (law of cosines, mirrors C# UnfoldEngine.TriangleApex)

/// Computes the 2D apex position C given base edge [p1, p2] and distances from C to each endpoint.
/// - Parameters:
///   - da: distance from apex to p1
///   - db: distance from apex to p2
///   - apexAbove: if true, apex is on the left side of the directed edge p1→p2 (CCW)
func triangleApex(p1: SIMD2<Float>, p2: SIMD2<Float>, da: Float, db: Float, apexAbove: Bool) -> SIMD2<Float> {
    let ab  = p2 - p1
    let len = simd_length(ab)
    guard len > GeometryConstants.degenerateEdge else { return p1 }

    // Projection parameter: t = (da²−db²+len²) / (2·len²)
    let t  = (da * da - db * db + len * len) / (2 * len * len)
    let ft = p1 + t * ab                        // foot of perpendicular from apex

    // Height h = sqrt(max(0, da²−t²·len²))
    let h  = (max(0, da * da - t * t * len * len)).squareRoot()

    // Unit perpendicular (CCW: rotate ab by +90°)
    let perp = SIMD2<Float>(-ab.y, ab.x) / len

    return apexAbove ? ft + h * perp : ft - h * perp
}

// MARK: - Reconstruct apex with side disambiguation (mirrors C# ReconstructApex)

/// Like `triangleApex` but picks the candidate on the **opposite** side from `parentCentroid`.
/// Used when unfolding child faces — the child should unfold away from the parent.
func reconstructApex(
    sv1: SIMD2<Float>, sv2: SIMD2<Float>,
    da: Float, db: Float,
    parentCentroid: SIMD2<Float>
) -> SIMD2<Float> {
    let ab  = sv2 - sv1
    let len = simd_length(ab)
    guard len > GeometryConstants.degenerateEdge else { return sv1 }

    let t    = (da * da - db * db + len * len) / (2 * len * len)
    let ft   = sv1 + t * ab
    let h    = (max(0, da * da - t * t * len * len)).squareRoot()
    let perp = SIMD2<Float>(-ab.y, ab.x) / len

    let c0 = ft + h * perp
    let c1 = ft - h * perp

    // The parent centroid is on one side of the shared edge.
    // The child apex must be on the opposite side.
    // Sign of cross(ab, p-sv1) tells which side p is on.
    let parentSign = ab.x * (parentCentroid.y - sv1.y) - ab.y * (parentCentroid.x - sv1.x)
    let c0Sign     = ab.x * (c0.y - sv1.y)             - ab.y * (c0.x - sv1.x)

    // If c0 is on the SAME side as parent → use c1 (opposite side)
    return (parentSign * c0Sign > 0) ? c1 : c0
}

// MARK: - Dihedral angle

/// Signed dihedral angle between two face normals around shared edge direction.
/// Returns value in [0, π] (unsigned, like C# DualGraphBuilder).
func dihedralAngle(nA: SIMD3<Float>, nB: SIMD3<Float>) -> Float {
    acos(min(1, max(-1, simd_dot(nA, nB))))
}

/// Signed fold angle (used in PieceFoldTree) — returns value in (-π, π].
func signedFoldAngle(nParent: SIMD3<Float>, nChild: SIMD3<Float>, edgeDir: SIMD3<Float>) -> Float {
    let sinTheta = simd_dot(simd_cross(nParent, nChild), edgeDir)
    let cosTheta = simd_dot(nParent, nChild)
    return atan2(sinTheta, cosTheta)
}

// MARK: - SIMD2 convenience

extension SIMD2 where Scalar == Float {
    /// Distance to another point
    func distance(to other: SIMD2<Float>) -> Float { simd_length(other - self) }

    /// Perpendicular (CCW rotation by 90°)
    var perp: SIMD2<Float> { SIMD2(-y, x) }
}

extension SIMD3 where Scalar == Float {
    static var unitY: SIMD3<Float> { SIMD3(0, 1, 0) }
}
