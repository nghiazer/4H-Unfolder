import simd

// Generates trapezoid glue tabs along the boundary (cut) edges of the unfolded pattern.
// A cut edge = an edge that appears in the spanning tree as a child edge (not fold lines).

struct GlueTabGenerator {
    var heightMm: Float
    var angleDeg: Float

    init(settings: AppSettings) {
        heightMm = settings.tabHeightMm
        angleDeg = settings.tabAngleDeg
    }

    func generate(result: inout UnfoldResult, spanningTree: [UnfoldEngine.TreeEdge], mesh: Mesh) {
        guard settings.tabStyle != .none else { return }
        var tabs: [GlueTab] = []
        var counter = 1

        for te in spanningTree {
            guard te.child < result.faces.count else { continue }
            let face2D = result.faces[te.child]

            // Locate shared edge vertices in child's 2D layout
            let childFace3D = mesh.faces[te.child]
            guard let p0 = vertex2D(meshIdx: te.v0, face3D: childFace3D, face2D: face2D),
                  let p1 = vertex2D(meshIdx: te.v1, face3D: childFace3D, face2D: face2D)
            else { continue }

            let tab = buildTrapezoid(p0: p0, p1: p1,
                                     onFace: te.child,
                                     label: "\(counter)")
            tabs.append(tab)
            counter += 1
        }
        result.tabs = tabs
    }

    // MARK: - Private

    private var settings = AppSettings()   // for tabStyle guard — caller passes settings in init

    private func buildTrapezoid(p0: SIMD2<Float>, p1: SIMD2<Float>,
                                 onFace: Int, label: String) -> GlueTab {
        let dir   = simd_normalize(p1 - p0)
        let perp  = SIMD2<Float>(-dir.y, dir.x)
        let inset = heightMm / tan(angleDeg * .pi / 180.0)
        let q0    = p0 + perp * heightMm + dir * inset
        let q1    = p1 + perp * heightMm - dir * inset
        return GlueTab(onFaceIndex: onFace, polygon: [p0, p1, q1, q0], label: label)
    }

    private func vertex2D(meshIdx: Int, face3D: Face, face2D: UnfoldedFace) -> SIMD2<Float>? {
        for (i, vi) in face3D.vertices.enumerated() where vi == meshIdx {
            return i < face2D.vertices2D.count ? face2D.vertices2D[i] : nil
        }
        return nil
    }
}
