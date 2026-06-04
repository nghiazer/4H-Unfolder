/// BFS-based mesh unfolding — exact port of C# `UnfoldEngine.Unfold()`.
///
/// Algorithm:
/// 1. Build fold-edge adjacency (face → list of (neighbour, shared_edge_id)).
/// 2. For each unvisited face start a new connected component:
///    - Place root face: A at origin, B on x-axis, C via law-of-cosines apex.
///    - BFS: place each child face by aligning the shared edge and
///      reconstructing the apex on the opposite side from the parent centroid.
/// 3. Build `UnfoldedFace` structs (edge flags, UV, mesh_edge_ids) from the
///    stamped `EdgeType` values on `mesh.edges`.
use crate::algorithms::constants::DEGENERATE_EDGE;
use crate::models::{
    mesh::{EdgeType, Mesh, MeshEdge},
    unfold::{Point2, UnfoldedFace},
};
use std::collections::{HashMap, VecDeque};

// ---------------------------------------------------------------------------
// Public entry point
// ---------------------------------------------------------------------------

/// Unfold every face into 2-D paper space.
/// `mesh.edges` must have `edge_type` already set by `mark_edges()`.
/// `fold_edge_ids` is the set of interior fold edges (spanning-tree result).
pub fn unfold_faces(
    mesh:          &Mesh,
    fold_edge_ids: &std::collections::HashSet<usize>,
) -> Vec<UnfoldedFace> {
    let n       = mesh.faces.len();
    let adj     = build_adjacency(mesh, fold_edge_ids);
    let mut pos = vec![None::<[Point2; 3]>; n];
    let mut visited = vec![false; n];
    let mut result  = Vec::with_capacity(n);
    let mut piece   = 0usize;

    for start in 0..n {
        if visited[start] { continue; }

        // Place root face.
        let root_pos = place_root_face(mesh, start);
        pos[start]   = Some(root_pos);
        visited[start] = true;

        // BFS queue: (face_id, parent_face_id, shared_edge_id).
        // root has no parent — use usize::MAX as sentinel.
        let mut queue: VecDeque<(usize, usize, usize)> = VecDeque::new();
        queue.push_back((start, usize::MAX, usize::MAX));

        while let Some((fid, _parent, _shared)) = queue.pop_front() {
            // Push all unvisited fold-adjacent neighbours.
            if let Some(neighbours) = adj.get(&fid) {
                for &(nb_id, eid) in neighbours {
                    if visited[nb_id] { continue; }
                    visited[nb_id] = true;

                    let parent_pos = pos[fid].unwrap();
                    let nb_pos     = place_child_face(mesh, nb_id, fid, &parent_pos, eid);
                    pos[nb_id]     = Some(nb_pos);
                    queue.push_back((nb_id, fid, eid));
                }
            }

            // Emit the UnfoldedFace for `fid` now that its position is known.
            let verts = pos[fid].unwrap();
            result.push(build_unfolded_face(mesh, fid, verts, piece));
        }

        piece += 1;
    }

    result
}

// ---------------------------------------------------------------------------
// Adjacency
// ---------------------------------------------------------------------------

/// face_id → list of (neighbour_face_id, shared_edge_id)
/// Built only from fold edges.
fn build_adjacency(
    mesh:          &Mesh,
    fold_edge_ids: &std::collections::HashSet<usize>,
) -> HashMap<usize, Vec<(usize, usize)>> {
    let mut adj: HashMap<usize, Vec<(usize, usize)>> = HashMap::new();
    for &eid in fold_edge_ids {
        let e = &mesh.edges[eid];
        if let Some(fb) = e.face_b {
            adj.entry(e.face_a).or_default().push((fb, eid));
            adj.entry(fb).or_default().push((e.face_a, eid));
        }
    }
    adj
}

// ---------------------------------------------------------------------------
// Root face placement
// ---------------------------------------------------------------------------

/// Place triangle ABC flat: A at origin, B on the positive x-axis, C via apex.
fn place_root_face(mesh: &Mesh, face_id: usize) -> [Point2; 3] {
    let f   = &mesh.faces[face_id];
    let va  = &mesh.vertices[f.vertices[0]];
    let vb  = &mesh.vertices[f.vertices[1]];
    let vc  = &mesh.vertices[f.vertices[2]];

    let ab = dist3(va, vb);
    let ac = dist3(va, vc);
    let bc = dist3(vb, vc);

    let p0 = Point2::ZERO;
    let p1 = Point2::new(ab, 0.0);
    let p2 = triangle_apex(p0, p1, ac, bc, true);

    [p0, p1, p2]
}

// ---------------------------------------------------------------------------
// Child face placement
// ---------------------------------------------------------------------------

/// Place child face by aligning the shared edge to its already-placed parent
/// position and reconstructing the apex opposite the parent centroid.
fn place_child_face(
    mesh:       &Mesh,
    child_id:   usize,
    parent_id:  usize,
    parent_pos: &[Point2; 3],
    edge_id:    usize,
) -> [Point2; 3] {
    let edge       = &mesh.edges[edge_id];
    let child_face = &mesh.faces[child_id];
    let par_face   = &mesh.faces[parent_id];

    // Local indices of the shared vertices inside the child face.
    let ls = match get_shared_local_indices(child_face.vertices, edge) {
        Some(v) => v,
        None    => return [Point2::ZERO; 3],
    };
    // Local indices inside the parent face.
    let lsp = match get_shared_local_indices(par_face.vertices, edge) {
        Some(v) => v,
        None    => return [Point2::ZERO; 3],
    };

    // Map shared vertices from parent 2-D positions.
    // `ls[0]` child local index corresponds to `edge.vert_a` or `edge.vert_b`;
    // check which one to ensure consistent orientation.
    let (sv1_2d, sv2_2d) = {
        let child_v_ls0 = child_face.vertices[ls[0]];
        let par_v_lsp0  = par_face.vertices[lsp[0]];
        if child_v_ls0 == par_v_lsp0 {
            (parent_pos[lsp[0]], parent_pos[lsp[1]])
        } else {
            (parent_pos[lsp[1]], parent_pos[lsp[0]])
        }
    };

    // 3-D apex index (the local index that is *not* shared).
    let la = 3 - ls[0] - ls[1]; // only works for triangles (0+1+2=3)

    let v_apex = &mesh.vertices[child_face.vertices[la]];
    let v_sv1  = if child_face.vertices[ls[0]] == edge.vert_a {
        &mesh.vertices[edge.vert_a]
    } else {
        &mesh.vertices[edge.vert_b]
    };
    let v_sv2 = if child_face.vertices[ls[1]] == edge.vert_a {
        &mesh.vertices[edge.vert_a]
    } else {
        &mesh.vertices[edge.vert_b]
    };

    let da = dist3(v_apex, v_sv1);
    let db = dist3(v_apex, v_sv2);

    let parent_centroid = Point2::new(
        (parent_pos[0].x + parent_pos[1].x + parent_pos[2].x) / 3.0,
        (parent_pos[0].y + parent_pos[1].y + parent_pos[2].y) / 3.0,
    );

    let apex_2d = reconstruct_apex(sv1_2d, sv2_2d, da, db, parent_centroid);

    // Assemble the result array in child-local order.
    let mut positions = [Point2::ZERO; 3];
    positions[ls[0]] = sv1_2d;
    positions[ls[1]] = sv2_2d;
    positions[la]    = apex_2d;

    positions
}

// ---------------------------------------------------------------------------
// Geometric primitives
// ---------------------------------------------------------------------------

/// Compute the apex of a triangle given base `(p1, p2)` and distances
/// `da` (from apex to p1) and `db` (from apex to p2).
/// Matches C# `UnfoldEngine.TriangleApex`.
fn triangle_apex(p1: Point2, p2: Point2, da: f64, db: f64, apex_above: bool) -> Point2 {
    let ab  = p2 - p1;
    let len = ab.len();

    // Degenerate base edge: fall back to a point along the x direction.
    if len < DEGENERATE_EDGE {
        return p1 + Point2::new(da, 0.0);
    }

    let t  = (da * da - db * db + len * len) / (2.0 * len * len);
    let ft = p1 + ab * t;
    let h  = (da * da - t * t * len * len).max(0.0).sqrt();

    // Perpendicular (left of AB).
    let perp = Point2::new(-ab.y / len, ab.x / len);

    if apex_above { ft + perp * h } else { ft - perp * h }
}

/// Reconstruct the apex on the side *opposite* to `parent_centroid`.
/// Matches C# `UnfoldEngine.ReconstructApex`.
fn reconstruct_apex(
    sv1:             Point2,
    sv2:             Point2,
    da:              f64,
    db:              f64,
    parent_centroid: Point2,
) -> Point2 {
    let ab  = sv2 - sv1;
    let len = ab.len();

    if len < DEGENERATE_EDGE {
        return sv1 + Point2::new(da, 0.0);
    }

    let t    = (da * da - db * db + len * len) / (2.0 * len * len);
    let ft   = sv1 + ab * t;
    let h    = (da * da - t * t * len * len).max(0.0).sqrt();
    let perp = Point2::new(-ab.y / len, ab.x / len);

    let c1 = ft + perp * h;
    let c2 = ft - perp * h;

    // Cross-product sign test: choose the candidate on the OPPOSITE side
    // from parent_centroid relative to edge sv1→sv2.
    let cross_sign = |p: Point2| -> f64 {
        (sv2.x - sv1.x) * (p.y - sv1.y) - (sv2.y - sv1.y) * (p.x - sv1.x)
    };

    let sign_parent = cross_sign(parent_centroid);
    let sign_c1     = cross_sign(c1);

    // If c1 is on the same side as the parent, return c2 (opposite), else c1.
    if sign_parent * sign_c1 > 0.0 { c2 } else { c1 }
}

/// Local indices (0, 1, or 2) of the two shared vertices inside `face_verts`.
/// Returns `None` if fewer than 2 shared vertices are found (topology error).
fn get_shared_local_indices(face_verts: [usize; 3], edge: &MeshEdge) -> Option<[usize; 2]> {
    let mut indices = [0usize; 2];
    let mut count   = 0;
    for (i, &v) in face_verts.iter().enumerate() {
        if v == edge.vert_a || v == edge.vert_b {
            if count >= 2 { return None; } // more than 2 shared — degenerate
            indices[count] = i;
            count += 1;
        }
    }
    if count == 2 { Some(indices) } else { None }
}

// ---------------------------------------------------------------------------
// UnfoldedFace builder
// ---------------------------------------------------------------------------

/// Construct the `UnfoldedFace` struct from the placed 2-D positions and the
/// `EdgeType` values that `mark_edges()` stamped on `mesh.edges`.
fn build_unfolded_face(
    mesh:     &Mesh,
    face_id:  usize,
    verts:    [Point2; 3],
    piece_id: usize,
) -> UnfoldedFace {
    let face = &mesh.faces[face_id];

    let mut edge_is_fold     = [false; 3];
    let mut edge_is_boundary = [false; 3];
    let mut mesh_edge_ids    = [-1i32; 3];

    for i in 0..3 {
        let eid = face.edge_ids[i];
        let edge = &mesh.edges[eid];
        edge_is_fold[i]     = edge.edge_type == EdgeType::Fold;
        edge_is_boundary[i] = edge.face_b.is_none();
        mesh_edge_ids[i]    = eid as i32;
    }

    // UV coords: take from mesh.uvs if face has UV indices.
    let uv_coords = face.uvs.map(|uv_idx| {
        [
            mesh.uvs[uv_idx[0]],
            mesh.uvs[uv_idx[1]],
            mesh.uvs[uv_idx[2]],
        ]
    });

    UnfoldedFace {
        face_id,
        v0: verts[0],
        v1: verts[1],
        v2: verts[2],
        edge_is_fold,
        edge_is_boundary,
        uv_coords,
        material_id: face.material_id,
        mesh_edge_ids,
        piece_id,
    }
}

// ---------------------------------------------------------------------------
// Math helpers
// ---------------------------------------------------------------------------

fn dist3(a: &crate::models::mesh::Vertex, b: &crate::models::mesh::Vertex) -> f64 {
    let dx = b.x - a.x;
    let dy = b.y - a.y;
    let dz = b.z - a.z;
    (dx * dx + dy * dy + dz * dz).sqrt()
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use crate::algorithms::spanning_tree::{build_spanning_tree, compute_dihedral_angle, mark_edges};
    use crate::models::mesh::{BoundingBox, Face, Mesh, MeshEdge, Vertex};

    /// Two flat coplanar triangles sharing edge V1-V2.
    fn two_flat_triangles() -> Mesh {
        Mesh {
            name:     "two_flat".into(),
            vertices: vec![
                Vertex { x: 0.0, y: 0.0, z: 0.0 }, // 0 A
                Vertex { x: 2.0, y: 0.0, z: 0.0 }, // 1 B (shared)
                Vertex { x: 1.0, y: 2.0, z: 0.0 }, // 2 C (shared)
                Vertex { x: 3.0, y: 2.0, z: 0.0 }, // 3 D
            ],
            faces: vec![
                Face { id: 0, vertices: [0, 1, 2], edge_ids: [0, 1, 2], material_id: -1, uvs: None },
                Face { id: 1, vertices: [1, 3, 2], edge_ids: [3, 4, 1], material_id: -1, uvs: None },
            ],
            // Edge 1 (id=1) is the interior shared edge V1-V2 (indices 1,2).
            edges: vec![
                MeshEdge { id: 0, face_a: 0, face_b: None,    vert_a: 0, vert_b: 1, edge_type: EdgeType::Unknown },
                MeshEdge { id: 1, face_a: 0, face_b: Some(1), vert_a: 1, vert_b: 2, edge_type: EdgeType::Unknown },
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

    fn run_unfold(mesh: &mut Mesh) -> Vec<UnfoldedFace> {
        let tree     = build_spanning_tree(mesh, |e| compute_dihedral_angle(mesh, e));
        let fold_set = tree.fold_edge_ids.iter().cloned().collect();
        mark_edges(mesh, &fold_set);
        unfold_faces(mesh, &fold_set)
    }

    #[test]
    fn root_face_v0_at_origin_v1_on_x_axis() {
        let mut mesh  = two_flat_triangles();
        let faces     = run_unfold(&mut mesh);
        let root      = faces.iter().find(|f| f.face_id == 0).unwrap();
        assert!(root.v0.x.abs() < 1e-9 && root.v0.y.abs() < 1e-9, "V0 should be at origin");
        assert!(root.v1.y.abs() < 1e-9, "V1 should lie on the x-axis");
        assert!(root.v1.x > 0.0, "V1 should have positive x");
    }

    #[test]
    fn edge_lengths_preserved_after_unfold() {
        let mut mesh = two_flat_triangles();
        let faces    = run_unfold(&mut mesh);

        for face in &faces {
            let v  = &mesh.faces[face.face_id].vertices;
            let d3 = |i: usize, j: usize| -> f64 {
                let a = &mesh.vertices[v[i]];
                let b = &mesh.vertices[v[j]];
                dist3(a, b)
            };
            let d2 = |p: Point2, q: Point2| -> f64 { p.dist(q) };

            let tol = 1e-6;
            assert!((d2(face.v0, face.v1) - d3(0,1)).abs() < tol, "edge 0-1 length mismatch");
            assert!((d2(face.v1, face.v2) - d3(1,2)).abs() < tol, "edge 1-2 length mismatch");
            assert!((d2(face.v2, face.v0) - d3(2,0)).abs() < tol, "edge 2-0 length mismatch");
        }
    }

    #[test]
    fn two_triangles_produces_two_unfolded_faces() {
        let mut mesh = two_flat_triangles();
        let faces    = run_unfold(&mut mesh);
        assert_eq!(faces.len(), 2);
    }

    #[test]
    fn flat_triangles_have_one_fold_one_cut_piece() {
        let mut mesh = two_flat_triangles();
        let faces    = run_unfold(&mut mesh);
        // All faces in the same piece (fold edge connects them).
        assert_eq!(faces[0].piece_id, faces[1].piece_id);
    }

    // -----------------------------------------------------------------------
    // Phase 6B additional unfold tests
    // -----------------------------------------------------------------------

    fn regular_tetrahedron() -> Mesh {
        use crate::models::mesh::{BoundingBox, Face, MeshEdge, Vertex};
        let s3 = (3.0_f64).sqrt();
        let s6 = (6.0_f64).sqrt();
        Mesh {
            name: "tet".into(),
            vertices: vec![
                Vertex { x: 0.0, y: 0.0,      z: 0.0      },
                Vertex { x: 1.0, y: 0.0,      z: 0.0      },
                Vertex { x: 0.5, y: s3 / 2.0, z: 0.0      },
                Vertex { x: 0.5, y: s3 / 6.0, z: s6 / 3.0 },
            ],
            faces: vec![
                Face { id: 0, vertices: [0, 1, 2], edge_ids: [0, 1, 2], material_id: -1, uvs: None },
                Face { id: 1, vertices: [0, 1, 3], edge_ids: [0, 4, 3], material_id: -1, uvs: None },
                Face { id: 2, vertices: [1, 2, 3], edge_ids: [1, 5, 4], material_id: -1, uvs: None },
                Face { id: 3, vertices: [0, 2, 3], edge_ids: [2, 5, 3], material_id: -1, uvs: None },
            ],
            edges: vec![
                MeshEdge { id: 0, face_a: 0, face_b: Some(1), vert_a: 0, vert_b: 1, edge_type: EdgeType::Unknown },
                MeshEdge { id: 1, face_a: 0, face_b: Some(2), vert_a: 1, vert_b: 2, edge_type: EdgeType::Unknown },
                MeshEdge { id: 2, face_a: 0, face_b: Some(3), vert_a: 0, vert_b: 2, edge_type: EdgeType::Unknown },
                MeshEdge { id: 3, face_a: 1, face_b: Some(3), vert_a: 0, vert_b: 3, edge_type: EdgeType::Unknown },
                MeshEdge { id: 4, face_a: 1, face_b: Some(2), vert_a: 1, vert_b: 3, edge_type: EdgeType::Unknown },
                MeshEdge { id: 5, face_a: 2, face_b: Some(3), vert_a: 2, vert_b: 3, edge_type: EdgeType::Unknown },
            ],
            uvs: vec![], material_names: vec![], material_texture_paths: vec![],
            suggested_texture_path: None, pdo_layout: None, embedded_textures: vec![],
            bounds: BoundingBox::default(),
        }
    }

    #[test]
    fn tetrahedron_unfolds_to_4_faces() {
        let mut mesh = regular_tetrahedron();
        let faces    = run_unfold(&mut mesh);
        assert_eq!(faces.len(), 4, "tetrahedron should unfold to exactly 4 faces");
    }

    #[test]
    fn tetrahedron_all_faces_in_same_piece() {
        let mut mesh = regular_tetrahedron();
        let faces    = run_unfold(&mut mesh);
        // MST spans all 4 faces → all in same piece (one connected component).
        let piece0 = faces[0].piece_id;
        for f in &faces {
            assert_eq!(f.piece_id, piece0, "all tetrahedron faces should be in piece {piece0}");
        }
    }

    #[test]
    fn tetrahedron_edge_lengths_preserved() {
        let mut mesh = regular_tetrahedron();
        let faces    = run_unfold(&mut mesh);
        for face in &faces {
            let v = &mesh.faces[face.face_id].vertices;
            let d3 = |i: usize, j: usize| -> f64 {
                let a = &mesh.vertices[v[i]]; let b = &mesh.vertices[v[j]];
                ((a.x-b.x).powi(2) + (a.y-b.y).powi(2) + (a.z-b.z).powi(2)).sqrt()
            };
            let tol = 1e-6;
            assert!((face.v0.dist(face.v1) - d3(0,1)).abs() < tol);
            assert!((face.v1.dist(face.v2) - d3(1,2)).abs() < tol);
            assert!((face.v2.dist(face.v0) - d3(2,0)).abs() < tol);
        }
    }

    #[test]
    fn unfolded_faces_have_correct_fold_boundary_flags() {
        let mut mesh = two_flat_triangles();
        let faces    = run_unfold(&mut mesh);
        // The shared edge (eid=1) is the fold → edge_is_fold must be true on that edge.
        let f0 = faces.iter().find(|f| f.face_id == 0).unwrap();
        let f1 = faces.iter().find(|f| f.face_id == 1).unwrap();
        // Exactly one fold edge per face (the shared interior edge).
        let folds0 = f0.edge_is_fold.iter().filter(|&&b| b).count();
        let folds1 = f1.edge_is_fold.iter().filter(|&&b| b).count();
        assert_eq!(folds0, 1, "face 0 should have exactly 1 fold edge");
        assert_eq!(folds1, 1, "face 1 should have exactly 1 fold edge");
        // All other edges are boundary.
        let bounds0 = f0.edge_is_boundary.iter().filter(|&&b| b).count();
        let bounds1 = f1.edge_is_boundary.iter().filter(|&&b| b).count();
        assert_eq!(bounds0, 2, "face 0 should have 2 boundary edges");
        assert_eq!(bounds1, 2, "face 1 should have 2 boundary edges");
    }

    #[test]
    fn root_face_has_no_overlapping_vertices() {
        let mut mesh = two_flat_triangles();
        let faces    = run_unfold(&mut mesh);
        let root     = &faces[0];
        // All three vertices must be distinct.
        assert!(root.v0.dist(root.v1) > 1e-6, "v0 and v1 must not coincide");
        assert!(root.v1.dist(root.v2) > 1e-6, "v1 and v2 must not coincide");
        assert!(root.v0.dist(root.v2) > 1e-6, "v0 and v2 must not coincide");
    }

    #[test]
    fn mesh_edge_ids_stamped_on_unfolded_faces() {
        let mut mesh = two_flat_triangles();
        let faces    = run_unfold(&mut mesh);
        for face in &faces {
            for i in 0..3 {
                // mesh_edge_ids must be valid edge indices (not -1 for a fully connected mesh).
                assert!(
                    face.mesh_edge_ids[i] >= 0,
                    "face {} edge slot {} has mesh_edge_id=-1 (not stamped)",
                    face.face_id, i
                );
            }
        }
    }
}
