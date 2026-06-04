/// Kruskal MST over the face-adjacency (dual) graph.
/// Edges are weighted by dihedral angle (radians) — flat faces first.
/// Also provides `compute_dihedral_angle`, `compute_face_normal`, and `mark_edges`.
use crate::models::mesh::{EdgeType, Mesh, MeshEdge};
use std::collections::HashSet;

// ---------------------------------------------------------------------------
// Union-Find (path-compressed + union-by-rank)
// ---------------------------------------------------------------------------

struct UnionFind {
    parent: Vec<usize>,
    rank:   Vec<usize>,
}

impl UnionFind {
    fn new(n: usize) -> Self {
        Self { parent: (0..n).collect(), rank: vec![0; n] }
    }

    fn find(&mut self, mut x: usize) -> usize {
        while self.parent[x] != x {
            self.parent[x] = self.parent[self.parent[x]]; // path halving
            x = self.parent[x];
        }
        x
    }

    fn union(&mut self, a: usize, b: usize) -> bool {
        let ra = self.find(a);
        let rb = self.find(b);
        if ra == rb { return false; }
        match self.rank[ra].cmp(&self.rank[rb]) {
            std::cmp::Ordering::Less    => self.parent[ra] = rb,
            std::cmp::Ordering::Greater => self.parent[rb] = ra,
            std::cmp::Ordering::Equal   => { self.parent[rb] = ra; self.rank[ra] += 1; }
        }
        true
    }
}

// ---------------------------------------------------------------------------
// Face normal
// ---------------------------------------------------------------------------

/// Compute the unit normal of a mesh face.
/// Returns `[0, 1, 0]` for degenerate (zero-area) triangles,
/// matching C# `DualGraphBuilder.ComputeFaceNormal` behaviour.
pub fn compute_face_normal(mesh: &Mesh, face_id: usize) -> [f64; 3] {
    use crate::algorithms::constants::DEGENERATE_FACE;

    let f = &mesh.faces[face_id];
    let a = &mesh.vertices[f.vertices[0]];
    let b = &mesh.vertices[f.vertices[1]];
    let c = &mesh.vertices[f.vertices[2]];

    let ab = [b.x - a.x, b.y - a.y, b.z - a.z];
    let ac = [c.x - a.x, c.y - a.y, c.z - a.z];

    let n = cross3(ab, ac);
    let len_sq = dot3(n, n);

    if len_sq.sqrt() < DEGENERATE_FACE {
        return [0.0, 1.0, 0.0];
    }
    let len = len_sq.sqrt();
    [n[0] / len, n[1] / len, n[2] / len]
}

// ---------------------------------------------------------------------------
// Dihedral angle
// ---------------------------------------------------------------------------

/// Dihedral angle between the two faces sharing `edge` (radians).
/// Matching C# `DualGraphBuilder.ComputeDihedralAngle`.
pub fn compute_dihedral_angle(mesh: &Mesh, edge: &MeshEdge) -> f64 {
    let face_b = match edge.face_b { Some(fb) => fb, None => return 0.0 };
    let n1 = compute_face_normal(mesh, edge.face_a);
    let n2 = compute_face_normal(mesh, face_b);
    let d  = dot3(n1, n2).clamp(-1.0, 1.0);
    d.acos()
}

// ---------------------------------------------------------------------------
// Edge marker
// ---------------------------------------------------------------------------

/// Stamp `EdgeType` on every edge in the mesh, matching C# `EdgeMarker.Mark`.
pub fn mark_edges(mesh: &mut Mesh, fold_set: &HashSet<usize>) {
    for edge in &mut mesh.edges {
        edge.edge_type = match (edge.face_b.is_none(), fold_set.contains(&edge.id)) {
            (true,  _   ) => EdgeType::Boundary,
            (false, true ) => EdgeType::Fold,
            (false, false) => EdgeType::Cut,
        };
    }
}

// ---------------------------------------------------------------------------
// Spanning tree result
// ---------------------------------------------------------------------------

pub struct SpanningTree {
    /// Edge IDs that form the MST (= fold lines).
    pub fold_edge_ids: Vec<usize>,
    /// Interior edge IDs not in the MST (= cut lines).
    pub cut_edge_ids:  Vec<usize>,
}

// ---------------------------------------------------------------------------
// Kruskal MST
// ---------------------------------------------------------------------------

/// Build a minimum spanning tree weighted by the provided `weight_fn`.
/// Pass `|e| compute_dihedral_angle(mesh, e)` for the standard pipeline.
pub fn build_spanning_tree(
    mesh:      &Mesh,
    weight_fn: impl Fn(&MeshEdge) -> f64,
) -> SpanningTree {
    let n_faces = mesh.faces.len();
    let mut uf  = UnionFind::new(n_faces);

    // Only interior edges participate in the MST.
    let mut interior: Vec<(f64, usize)> = mesh.edges.iter()
        .filter(|e| e.face_b.is_some())
        .map(|e| (weight_fn(e), e.id))
        .collect();

    // Sort ascending: flat dihedral angle (≈ 0) → preferred as fold.
    interior.sort_by(|a, b| a.0.partial_cmp(&b.0)
        .unwrap_or(std::cmp::Ordering::Equal));

    let mut fold_edge_ids = Vec::new();
    let mut cut_edge_ids  = Vec::new();

    for (_w, eid) in &interior {
        let e  = &mesh.edges[*eid];
        let fb = e.face_b.unwrap();
        if uf.union(e.face_a, fb) {
            fold_edge_ids.push(*eid);
        } else {
            cut_edge_ids.push(*eid);
        }
    }

    // Boundary edges are always cut edges (perimeter of the mesh).
    for e in &mesh.edges {
        if e.face_b.is_none() {
            cut_edge_ids.push(e.id);
        }
    }

    SpanningTree { fold_edge_ids, cut_edge_ids }
}

// ---------------------------------------------------------------------------
// Math helpers
// ---------------------------------------------------------------------------

#[inline]
pub fn cross3(a: [f64; 3], b: [f64; 3]) -> [f64; 3] {
    [
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    ]
}

#[inline]
pub fn dot3(a: [f64; 3], b: [f64; 3]) -> f64 {
    a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::mesh::{BoundingBox, Face, Mesh, MeshEdge, Vertex};

    /// Two flat coplanar triangles sharing edge 0-1.
    fn two_flat_triangles() -> Mesh {
        Mesh {
            name:     "two_flat".into(),
            vertices: vec![
                Vertex { x: 0.0, y: 0.0, z: 0.0 },
                Vertex { x: 1.0, y: 0.0, z: 0.0 },
                Vertex { x: 0.5, y: 1.0, z: 0.0 },
                Vertex { x: 1.5, y: 1.0, z: 0.0 },
            ],
            faces: vec![
                Face { id: 0, vertices: [0, 1, 2], edge_ids: [0, 1, 2], material_id: -1, uvs: None },
                Face { id: 1, vertices: [1, 3, 2], edge_ids: [3, 4, 0], material_id: -1, uvs: None },
            ],
            edges: vec![
                MeshEdge { id: 0, face_a: 0, face_b: Some(1), vert_a: 1, vert_b: 2, edge_type: EdgeType::Unknown },
                MeshEdge { id: 1, face_a: 0, face_b: None,    vert_a: 1, vert_b: 2, edge_type: EdgeType::Unknown },
                MeshEdge { id: 2, face_a: 0, face_b: None,    vert_a: 0, vert_b: 2, edge_type: EdgeType::Unknown },
                MeshEdge { id: 3, face_a: 1, face_b: None,    vert_a: 1, vert_b: 3, edge_type: EdgeType::Unknown },
                MeshEdge { id: 4, face_a: 1, face_b: None,    vert_a: 2, vert_b: 3, edge_type: EdgeType::Unknown },
            ],
            uvs: vec![],
            material_names: vec![],
            material_texture_paths: vec![],
            suggested_texture_path: None,
            pdo_layout: None,
            embedded_textures: vec![],
            bounds: BoundingBox::default(),
        }
    }

    #[test]
    fn flat_triangles_have_zero_dihedral() {
        let mesh = two_flat_triangles();
        let angle = compute_dihedral_angle(&mesh, &mesh.edges[0]);
        assert!(angle.abs() < 1e-10, "coplanar faces should have 0 dihedral, got {angle}");
    }

    #[test]
    fn mst_two_triangles_has_one_fold_edge() {
        let mesh = two_flat_triangles();
        let tree = build_spanning_tree(&mesh, |e| compute_dihedral_angle(&mesh, e));
        assert_eq!(tree.fold_edge_ids.len(), 1);
    }

    #[test]
    fn mark_edges_stamps_types() {
        let mut mesh = two_flat_triangles();
        let tree = build_spanning_tree(&mesh, |e| compute_dihedral_angle(&mesh, e));
        let fold_set: std::collections::HashSet<usize> = tree.fold_edge_ids.iter().cloned().collect();
        mark_edges(&mut mesh, &fold_set);
        assert_eq!(mesh.edges[0].edge_type, EdgeType::Fold);
        assert_eq!(mesh.edges[1].edge_type, EdgeType::Boundary);
    }
}
