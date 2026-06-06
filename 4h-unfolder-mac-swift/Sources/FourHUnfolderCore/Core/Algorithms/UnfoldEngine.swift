import simd

// MARK: - Core BFS face-unfolding algorithm
//
// Mirrors C# UnfoldEngine exactly:
//   1. Build fold-edge adjacency (only edges in foldEdgeIds)
//   2. Iterate unvisited faces as new component roots
//   3. Place root face: first edge A→B along X, C via triangleApex(above)
//   4. BFS children: placeChildFace via reconstructApex (law-of-cosines disambiguation)
//   5. Build UnfoldedFace with edge type flags, UV coords, dihedral angles

struct UnfoldEngine {

    struct Result {
        var faces: [UnfoldedFace]
        var dihedralAngles: [Int: Float]   // meshEdgeId → degrees
    }

    func unfold(mesh: Mesh, foldEdgeIds: Set<Int>, meshScaleMm: Float = 1) -> Result {
        guard mesh.isValid else { return Result(faces: [], dihedralAngles: [:]) }

        // Build fold adjacency: faceId → [(neighborFaceId, sharedMeshEdge)]
        var foldAdj: [Int: [(neighbor: Int, edgeId: Int)]] = [:]
        for edge in mesh.edges where foldEdgeIds.contains(edge.id) && edge.connectsFaces {
            foldAdj[edge.faceA, default: []].append((edge.faceB, edge.id))
            foldAdj[edge.faceB, default: []].append((edge.faceA, edge.id))
        }

        // Pre-compute dihedral angles (for all interior edges)
        var dihedralAngles: [Int: Float] = [:]
        for edge in mesh.edges where edge.connectsFaces {
            let nA = mesh.faceNormal(edge.faceA)
            let nB = mesh.faceNormal(edge.faceB)
            let angle = dihedralAngle(nA: nA, nB: nB)
            dihedralAngles[edge.id] = angle * 180 / .pi
        }

        // BFS state
        var placed = [Int: PlacedFace]()
        placed.reserveCapacity(mesh.faces.count)

        // Process each connected component
        for startFace in 0..<mesh.faces.count where placed[startFace] == nil {
            placeRoot(faceId: startFace, mesh: mesh, placed: &placed, meshScaleMm: meshScaleMm)
            bfs(from: startFace, mesh: mesh, foldAdj: foldAdj, placed: &placed, meshScaleMm: meshScaleMm)
        }

        // Assemble result
        let faces = (0..<mesh.faces.count).compactMap { fi -> UnfoldedFace? in
            guard let p = placed[fi] else { return nil }
            let mf = mesh.faces[fi]

            func edgeType(_ eid: Int, _ isFold: Bool, _ isBoundary: Bool) -> (Bool, Bool) {
                (isFold, isBoundary)
            }

            let e0id = mf.edgeIds.0
            let e1id = mf.edgeIds.1
            let e2id = mf.edgeIds.2
            let e0 = e0id >= 0 ? mesh.edges[e0id] : nil
            let e1 = e1id >= 0 ? mesh.edges[e1id] : nil
            let e2 = e2id >= 0 ? mesh.edges[e2id] : nil

            let (uv0, uv1, uv2): (SIMD2<Float>?, SIMD2<Float>?, SIMD2<Float>?) = {
                guard fi < mesh.faceUVs.count else { return (nil, nil, nil) }
                let uvIdx = mesh.faceUVs[fi]
                return (
                    uvIdx.ua >= 0 && uvIdx.ua < mesh.uvs.count ? mesh.uvs[uvIdx.ua] : nil,
                    uvIdx.ub >= 0 && uvIdx.ub < mesh.uvs.count ? mesh.uvs[uvIdx.ub] : nil,
                    uvIdx.uc >= 0 && uvIdx.uc < mesh.uvs.count ? mesh.uvs[uvIdx.uc] : nil
                )
            }()

            return UnfoldedFace(
                faceId: fi, materialId: mf.materialId,
                v0: p.v0, v1: p.v1, v2: p.v2,
                edge0IsFold: e0.map { foldEdgeIds.contains($0.id) } ?? false,
                edge1IsFold: e1.map { foldEdgeIds.contains($0.id) } ?? false,
                edge2IsFold: e2.map { foldEdgeIds.contains($0.id) } ?? false,
                edge0IsBoundary: e0.map { $0.isBoundary } ?? true,
                edge1IsBoundary: e1.map { $0.isBoundary } ?? true,
                edge2IsBoundary: e2.map { $0.isBoundary } ?? true,
                uv0: uv0, uv1: uv1, uv2: uv2,
                meshEdge0: e0id, meshEdge1: e1id, meshEdge2: e2id
            )
        }

        return Result(faces: faces, dihedralAngles: dihedralAngles)
    }

    // MARK: - Placement types

    private struct PlacedFace {
        let v0: SIMD2<Float>
        let v1: SIMD2<Float>
        let v2: SIMD2<Float>

        var centroid: SIMD2<Float> { (v0 + v1 + v2) / 3 }
        func vertex(_ i: Int) -> SIMD2<Float> { i == 0 ? v0 : i == 1 ? v1 : v2 }

        /// Returns local vertex index (0,1,2) for the given mesh vertex id, or nil.
        func localIdx(for meshVId: Int, in face: Face) -> Int? {
            if face.a == meshVId { return 0 }
            if face.b == meshVId { return 1 }
            if face.c == meshVId { return 2 }
            return nil
        }
    }

    // MARK: - Root face placement

    private func placeRoot(faceId: Int, mesh: Mesh, placed: inout [Int: PlacedFace], meshScaleMm: Float) {
        let f  = mesh.faces[faceId]
        let pA = mesh.vertices[f.a].position
        let pB = mesh.vertices[f.b].position
        let pC = mesh.vertices[f.c].position

        let abLen = simd_length(pB - pA) * meshScaleMm
        let acLen = simd_length(pC - pA) * meshScaleMm
        let bcLen = simd_length(pC - pB) * meshScaleMm

        // A at origin, B along X axis
        let v0 = SIMD2<Float>(0, 0)
        let v1 = SIMD2<Float>(abLen, 0)
        // C via law of cosines (apex above the edge = CCW winding)
        let v2 = triangleApex(p1: v0, p2: v1, da: acLen, db: bcLen, apexAbove: true)

        placed[faceId] = PlacedFace(v0: v0, v1: v1, v2: v2)
    }

    // MARK: - BFS

    private func bfs(
        from start: Int,
        mesh: Mesh,
        foldAdj: [Int: [(neighbor: Int, edgeId: Int)]],
        placed: inout [Int: PlacedFace],
        meshScaleMm: Float
    ) {
        var queue = [start]
        while !queue.isEmpty {
            let parentId = queue.removeFirst()
            guard let parentPlaced = placed[parentId] else { continue }
            let parentFace = mesh.faces[parentId]

            for (childId, sharedEdgeId) in foldAdj[parentId] ?? [] {
                guard placed[childId] == nil else { continue }

                let sharedEdge = mesh.edges[sharedEdgeId]
                let childFace  = mesh.faces[childId]

                // The two shared vertex IDs (mesh global)
                let sv1Id = sharedEdge.v1
                let sv2Id = sharedEdge.v2

                // Map shared vertices to parent's 2D positions
                guard let pLocalSv1 = parentPlaced.localIdx(for: sv1Id, in: parentFace),
                      let pLocalSv2 = parentPlaced.localIdx(for: sv2Id, in: parentFace)
                else { continue }

                let sv1_2D = parentPlaced.vertex(pLocalSv1)
                let sv2_2D = parentPlaced.vertex(pLocalSv2)

                // Apex of child face = the vertex NOT shared
                guard let apexId = childFace.nonSharedVertex(sv1Id: sv1Id, sv2Id: sv2Id) else { continue }
                let apexPos3D = mesh.vertices[apexId].position

                // Distances from apex to shared vertices (scaled to mm)
                let da = simd_length(apexPos3D - mesh.vertices[sv1Id].position) * meshScaleMm
                let db = simd_length(apexPos3D - mesh.vertices[sv2Id].position) * meshScaleMm

                // Reconstruct apex on opposite side from parent centroid
                let apex2D = reconstructApex(
                    sv1: sv1_2D, sv2: sv2_2D,
                    da: da, db: db,
                    parentCentroid: parentPlaced.centroid
                )

                // Map child face vertices in order (a, b, c) → (v0, v1, v2)
                let childV0 = localPosition2D(meshVId: childFace.a,
                                               sv1Id: sv1Id, sv2Id: sv2Id, apexId: apexId,
                                               sv1_2D: sv1_2D, sv2_2D: sv2_2D, apex2D: apex2D)
                let childV1 = localPosition2D(meshVId: childFace.b,
                                               sv1Id: sv1Id, sv2Id: sv2Id, apexId: apexId,
                                               sv1_2D: sv1_2D, sv2_2D: sv2_2D, apex2D: apex2D)
                let childV2 = localPosition2D(meshVId: childFace.c,
                                               sv1Id: sv1Id, sv2Id: sv2Id, apexId: apexId,
                                               sv1_2D: sv1_2D, sv2_2D: sv2_2D, apex2D: apex2D)

                placed[childId] = PlacedFace(v0: childV0, v1: childV1, v2: childV2)
                queue.append(childId)
            }
        }
    }

    // MARK: - Helpers

    /// Returns the 2D position for a given mesh vertex ID during child placement.
    private func localPosition2D(
        meshVId: Int,
        sv1Id: Int, sv2Id: Int, apexId: Int,
        sv1_2D: SIMD2<Float>, sv2_2D: SIMD2<Float>, apex2D: SIMD2<Float>
    ) -> SIMD2<Float> {
        if meshVId == sv1Id  { return sv1_2D  }
        if meshVId == sv2Id  { return sv2_2D  }
        if meshVId == apexId { return apex2D  }
        // Fallback (shouldn't happen for valid triangular mesh)
        return apex2D
    }
}

// MARK: - Face helper

private extension Face {
    /// Returns the vertex ID that is neither sv1Id nor sv2Id.
    func nonSharedVertex(sv1Id: Int, sv2Id: Int) -> Int? {
        let shared = Set([sv1Id, sv2Id])
        if !shared.contains(a) { return a }
        if !shared.contains(b) { return b }
        if !shared.contains(c) { return c }
        return nil
    }
}
