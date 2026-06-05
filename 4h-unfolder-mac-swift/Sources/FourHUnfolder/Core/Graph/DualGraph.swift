import simd

// MARK: - Dual graph node (one per mesh face)

struct GraphNode {
    let faceId: Int
    var graphEdgeIds: [Int] = []
}

// MARK: - Dual graph edge (one per shared interior edge)

struct GraphEdge {
    let id: Int
    let faceA: Int
    let faceB: Int
    let sharedMeshEdgeId: Int
    let weight: Float           // dihedral angle in radians (0 = flat, π = sharp crease)
}

// MARK: - Dual graph

struct DualGraph {
    var nodes: [GraphNode]   // indexed by faceId
    var edges: [GraphEdge]
}

// MARK: - Builder

struct DualGraphBuilder {
    func build(mesh: Mesh) -> DualGraph {
        var nodes = (0..<mesh.faces.count).map { GraphNode(faceId: $0) }
        var edges: [GraphEdge] = []

        for edge in mesh.edges where edge.connectsFaces {
            let fA = edge.faceA
            let fB = edge.faceB

            var nA = mesh.faceNormal(fA)
            var nB = mesh.faceNormal(fB)

            // Guard against degenerate (zero-area) triangles
            if simd_length(nA) < GeometryConstants.degenerateFace { nA = SIMD3.unitY }
            if simd_length(nB) < GeometryConstants.degenerateFace { nB = SIMD3.unitY }

            let weight = dihedralAngle(nA: simd_normalize(nA), nB: simd_normalize(nB))

            let geid = edges.count
            edges.append(GraphEdge(id: geid, faceA: fA, faceB: fB,
                                   sharedMeshEdgeId: edge.id, weight: weight))
            nodes[fA].graphEdgeIds.append(geid)
            nodes[fB].graphEdgeIds.append(geid)
        }

        return DualGraph(nodes: nodes, edges: edges)
    }
}
