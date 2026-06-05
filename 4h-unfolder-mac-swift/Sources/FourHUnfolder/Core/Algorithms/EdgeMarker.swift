// MARK: - Stamps EdgeType on every mesh edge after MST + overrides are resolved

struct EdgeMarker {
    func mark(mesh: Mesh, foldEdgeIds: Set<Int>) {
        for i in mesh.edges.indices {
            let e = mesh.edges[i]
            if e.connectsFaces {
                mesh.edges[i].type = foldEdgeIds.contains(e.id) ? .fold : .cut
            } else {
                mesh.edges[i].type = .boundary
            }
        }
    }
}
