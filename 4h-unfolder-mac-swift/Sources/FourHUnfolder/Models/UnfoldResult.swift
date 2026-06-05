import simd

struct UnfoldedFace {
    let faceIndex: Int
    let vertices2D: [SIMD2<Float>]
    var color: SIMD3<Float> = SIMD3(0.78, 0.88, 1.0)
    var isSelected: Bool = false
}

struct GlueTab {
    let onFaceIndex: Int
    let polygon: [SIMD2<Float>]
    let label: String
}

struct UnfoldResult {
    var faces: [UnfoldedFace]
    var tabs: [GlueTab]
    var boundingBox: (min: SIMD2<Float>, max: SIMD2<Float>)

    var pageWidth: Float  { boundingBox.max.x - boundingBox.min.x }
    var pageHeight: Float { boundingBox.max.y - boundingBox.min.y }
}
