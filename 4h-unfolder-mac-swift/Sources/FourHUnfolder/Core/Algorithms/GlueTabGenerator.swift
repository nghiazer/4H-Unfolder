import simd

// MARK: - Glue tab generator
//
// Mirrors C# GlueTabGenerator exactly:
//   - 3 tab shapes: Trapezoid, Rectangle, Triangle
//   - AlternateFlaps: only lower faceId gets the tab on a cut edge
//   - 8 FlapMode variants for per-edge overrides
//   - Degenerate tab guard: skip if edge shorter than GeometryConstants.degenerateTab

struct GlueTabGenerator {

    func generate(
        faces: [UnfoldedFace],
        mesh: Mesh,
        settings: AppSettings.PrintSettings,
        flapOverrides: [Int: FlapOverride]   // meshEdgeId → override
    ) -> [GlueTab] {

        let depth    = Float(settings.glueTabDepthMm)
        let angleDeg = Float(settings.glueTabSideAngleDeg)
        let shape    = settings.glueTabShape

        // AlternateFlaps: build deny set of (faceId, localEdgeIdx) that should NOT get a tab
        var alternateDeny = Set<FaceEdgeKey>()
        if settings.alternateFlaps {
            for face in faces {
                for ei in 0..<3 {
                    let meshEid = face.meshEdgeId(ei)
                    guard meshEid >= 0, meshEid < mesh.edges.count else { continue }
                    let edge = mesh.edges[meshEid]
                    guard edge.connectsFaces else { continue }
                    // Deny the face with the higher faceId
                    let otherFaceId = edge.faceA == face.faceId ? edge.faceB : edge.faceA
                    if face.faceId > otherFaceId {
                        alternateDeny.insert(FaceEdgeKey(faceId: face.faceId, edgeIdx: ei))
                    }
                }
            }
        }

        var tabs: [GlueTab] = []

        for face in faces {
            let verts = face.vertices

            for ei in 0..<3 {
                let p0 = verts[ei]
                let p1 = verts[(ei + 1) % 3]
                let meshEid = face.meshEdgeId(ei)

                // Resolve FlapMode
                let override = meshEid >= 0 ? flapOverrides[meshEid] : nil
                let mode = override?.mode ?? .default

                guard let tab = evaluateMode(
                    mode: mode, override: override,
                    face: face, edgeIdx: ei, p0: p0, p1: p1,
                    meshEid: meshEid, mesh: mesh,
                    alternateDeny: alternateDeny,
                    depth: depth, angleDeg: angleDeg, shape: shape
                ) else { continue }

                tabs.append(tab)
            }
        }
        return tabs
    }

    // MARK: - Mode dispatch

    private func evaluateMode(
        mode: FlapMode,
        override: FlapOverride?,
        face: UnfoldedFace,
        edgeIdx: Int,
        p0: SIMD2<Float>, p1: SIMD2<Float>,
        meshEid: Int,
        mesh: Mesh,
        alternateDeny: Set<FaceEdgeKey>,
        depth: Float, angleDeg: Float, shape: AppSettings.PrintSettings.TabShape
    ) -> GlueTab? {
        let isFold     = face.edgeIsFold(edgeIdx)
        let isBoundary = face.edgeIsBoundary(edgeIdx)

        switch mode {

        case .default:
            guard !isFold, !isBoundary else { return nil }
            guard !alternateDeny.contains(FaceEdgeKey(faceId: face.faceId, edgeIdx: edgeIdx)) else { return nil }
            return makeTab(face: face, edgeIdx: edgeIdx, p0: p0, p1: p1,
                           depth: depth, angleDeg: angleDeg, shape: shape)

        case .onOn_BothSides:
            guard !isFold else { return nil }  // only cut and boundary
            return makeTab(face: face, edgeIdx: edgeIdx, p0: p0, p1: p1,
                           depth: depth, angleDeg: angleDeg, shape: shape)

        case .onOn_ThisSide:
            guard !isFold, !isBoundary,
                  face.faceId == (override?.primaryFaceId ?? face.faceId) else { return nil }
            return makeTab(face: face, edgeIdx: edgeIdx, p0: p0, p1: p1,
                           depth: depth, angleDeg: angleDeg, shape: shape)

        case .offOn_OtherSide, .switchPosition:
            guard !isFold, !isBoundary,
                  face.faceId != (override?.primaryFaceId ?? face.faceId) else { return nil }
            return makeTab(face: face, edgeIdx: edgeIdx, p0: p0, p1: p1,
                           depth: depth, angleDeg: angleDeg, shape: shape)

        case .offOff_NoFlap:
            return nil

        case .border_MountainFold, .border_ValleyFold, .border_NoFold:
            guard isBoundary else { return nil }
            return makeTab(face: face, edgeIdx: edgeIdx, p0: p0, p1: p1,
                           depth: depth, angleDeg: angleDeg, shape: shape,
                           borderFoldStyle: mode)

        case .border_NoFlap:
            return nil
        }
    }

    // MARK: - Tab shape builders

    private func makeTab(
        face: UnfoldedFace, edgeIdx: Int,
        p0: SIMD2<Float>, p1: SIMD2<Float>,
        depth: Float, angleDeg: Float,
        shape: AppSettings.PrintSettings.TabShape,
        borderFoldStyle: FlapMode? = nil
    ) -> GlueTab? {
        let edgeLen = simd_length(p1 - p0)
        guard edgeLen > GeometryConstants.degenerateTab else { return nil }

        let dir  = (p1 - p0) / edgeLen
        // Perpendicular pointing toward face interior (inward)
        let rawPerp = dir.perp
        let inward  = simd_dot(rawPerp, face.centroid - p0) > 0 ? rawPerp : -rawPerp
        let perp    = inward

        switch shape {
        case .trapezoid:
            let angle  = max(1, min(90, angleDeg)) * Float.pi / 180
            var inset  = depth / tan(angle)
            inset      = min(inset, edgeLen * 0.45)   // cap at 45% of edge length
            let q0     = p0 + inset * dir + depth * perp
            let q1     = p1 - inset * dir + depth * perp
            return GlueTab(faceId: face.faceId, localEdgeIdx: edgeIdx,
                           p0: p0, p1: p1, p2: q1, p3: q0,
                           borderFoldStyle: borderFoldStyle)

        case .rectangle:
            let q0 = p0 + depth * perp
            let q1 = p1 + depth * perp
            return GlueTab(faceId: face.faceId, localEdgeIdx: edgeIdx,
                           p0: p0, p1: p1, p2: q1, p3: q0,
                           borderFoldStyle: borderFoldStyle)

        case .triangle:
            let tip = (p0 + p1) * 0.5 + depth * perp
            return GlueTab(faceId: face.faceId, localEdgeIdx: edgeIdx,
                           p0: p0, p1: p1, p2: tip, p3: tip,
                           borderFoldStyle: borderFoldStyle)
        }
    }
}

// MARK: - Helpers

private struct FaceEdgeKey: Hashable {
    let faceId: Int
    let edgeIdx: Int
}
