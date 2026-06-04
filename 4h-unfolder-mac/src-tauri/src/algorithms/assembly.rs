/// Assembly step planner — port of C# `AssemblyPlanner`.
///
/// Produces an ordered list of steps where each step describes one "piece"
/// (connected component of fold edges) being attached to its parent.
/// Steps are ordered via BFS from the largest piece.
use crate::models::mesh::{EdgeType, Mesh};
use serde::Serialize;
use std::collections::{HashMap, HashSet, VecDeque};

// ---------------------------------------------------------------------------
// Output types
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AssemblyStep {
    pub step_index:      usize,
    /// The piece (connected-fold-component) being attached in this step.
    pub group_id:        usize,
    /// The piece it attaches to (-1 for the root).
    pub parent_group_id: i64,
    /// All face IDs in this piece.
    pub face_ids:        Vec<usize>,
    /// Face IDs of the shared cut edge(s) connecting this piece to its parent.
    pub attach_face_ids: Vec<usize>,
}

// ---------------------------------------------------------------------------
// Algorithm
// ---------------------------------------------------------------------------

/// Compute assembly order for the mesh.
/// Returns one `AssemblyStep` per connected-fold-component (piece).
pub fn compute_assembly_steps(mesh: &Mesh) -> Vec<AssemblyStep> {
    // 1. Find connected components via fold edges (piece groups).
    let pieces = fold_components(mesh);
    if pieces.is_empty() { return vec![]; }

    // 2. Build piece adjacency (which pieces are adjacent via cut edges).
    let face_to_piece: HashMap<usize, usize> = pieces
        .iter()
        .enumerate()
        .flat_map(|(pid, faces)| faces.iter().map(move |&fid| (fid, pid)))
        .collect();

    let mut piece_adj: HashMap<usize, HashSet<(usize, usize, usize)>> = HashMap::new(); // (pid → set of (neighbor_pid, face_a, face_b))

    for edge in &mesh.edges {
        if edge.edge_type != EdgeType::Cut { continue; }
        let Some(fb) = edge.face_b else { continue };
        let pa = face_to_piece.get(&edge.face_a).copied();
        let pb = face_to_piece.get(&fb).copied();
        if let (Some(pa), Some(pb)) = (pa, pb) {
            if pa != pb {
                piece_adj.entry(pa).or_default().insert((pb, edge.face_a, fb));
                piece_adj.entry(pb).or_default().insert((pa, fb, edge.face_a));
            }
        }
    }

    // 3. BFS from the largest piece.
    let root = pieces.iter().enumerate()
        .max_by_key(|(_, v)| v.len())
        .map(|(i, _)| i)
        .unwrap_or(0);

    let mut steps     = Vec::new();
    let mut visited   = HashSet::new();
    let mut queue:    VecDeque<(usize, i64, Vec<usize>)> = VecDeque::new(); // (pid, parent_pid, attach_faces)
    queue.push_back((root, -1, vec![]));

    while let Some((pid, parent_pid, attach_faces)) = queue.pop_front() {
        if !visited.insert(pid) { continue; }

        steps.push(AssemblyStep {
            step_index:      steps.len(),
            group_id:        pid,
            parent_group_id: parent_pid,
            face_ids:        pieces[pid].clone(),
            attach_face_ids: attach_faces,
        });

        if let Some(neighbors) = piece_adj.get(&pid) {
            let mut sorted: Vec<_> = neighbors.iter().collect();
            sorted.sort_by_key(|(npid, _, _)| *npid);
            for &(npid, fa, fb) in sorted {
                if !visited.contains(&npid) {
                    queue.push_back((npid, pid as i64, vec![fa, fb]));
                }
            }
        }
    }

    // Add any isolated pieces (not reachable via cut edges)
    for (pid, _) in pieces.iter().enumerate() {
        if !visited.contains(&pid) {
            steps.push(AssemblyStep {
                step_index:      steps.len(),
                group_id:        pid,
                parent_group_id: -1,
                face_ids:        pieces[pid].clone(),
                attach_face_ids: vec![],
            });
        }
    }

    steps
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::mesh::{BoundingBox, EdgeType, Face, Mesh, MeshEdge, Vertex};

    /// Two flat triangles sharing one Fold edge — one piece.
    fn one_piece_mesh() -> Mesh {
        Mesh {
            name: "one_piece".into(),
            vertices: vec![
                Vertex { x: 0.0, y: 0.0, z: 0.0 },
                Vertex { x: 2.0, y: 0.0, z: 0.0 },
                Vertex { x: 1.0, y: 2.0, z: 0.0 },
                Vertex { x: 3.0, y: 2.0, z: 0.0 },
            ],
            faces: vec![
                Face { id: 0, vertices: [0, 1, 2], edge_ids: [0, 1, 2], material_id: -1, uvs: None },
                Face { id: 1, vertices: [1, 3, 2], edge_ids: [3, 4, 1], material_id: -1, uvs: None },
            ],
            edges: vec![
                MeshEdge { id: 0, face_a: 0, face_b: None,    vert_a: 0, vert_b: 1, edge_type: EdgeType::Boundary },
                MeshEdge { id: 1, face_a: 0, face_b: Some(1), vert_a: 1, vert_b: 2, edge_type: EdgeType::Fold },
                MeshEdge { id: 2, face_a: 0, face_b: None,    vert_a: 0, vert_b: 2, edge_type: EdgeType::Boundary },
                MeshEdge { id: 3, face_a: 1, face_b: None,    vert_a: 1, vert_b: 3, edge_type: EdgeType::Boundary },
                MeshEdge { id: 4, face_a: 1, face_b: None,    vert_a: 2, vert_b: 3, edge_type: EdgeType::Boundary },
            ],
            uvs: vec![], material_names: vec![], material_texture_paths: vec![],
            suggested_texture_path: None, pdo_layout: None, embedded_textures: vec![],
            bounds: BoundingBox::default(),
        }
    }

    /// Two triangles connected by a Cut edge — two separate pieces.
    fn two_piece_mesh() -> Mesh {
        let mut m = one_piece_mesh();
        m.edges[1].edge_type = EdgeType::Cut; // change shared edge to Cut
        m
    }

    /// Four faces: two pairs each connected by Fold edges, pairs connected by Cut.
    fn four_face_two_piece_mesh() -> Mesh {
        Mesh {
            name: "four_two".into(),
            vertices: vec![
                Vertex { x: 0.0, y: 0.0, z: 0.0 }, // 0
                Vertex { x: 1.0, y: 0.0, z: 0.0 }, // 1
                Vertex { x: 2.0, y: 0.0, z: 0.0 }, // 2
                Vertex { x: 0.5, y: 1.0, z: 0.0 }, // 3
                Vertex { x: 1.5, y: 1.0, z: 0.0 }, // 4
                Vertex { x: 2.5, y: 1.0, z: 0.0 }, // 5
            ],
            faces: vec![
                // Piece A: F0 and F1, connected by fold edge 1
                Face { id: 0, vertices: [0, 1, 3], edge_ids: [0, 1, 2], material_id: -1, uvs: None },
                Face { id: 1, vertices: [1, 4, 3], edge_ids: [3, 4, 1], material_id: -1, uvs: None },
                // Piece B: F2 and F3, connected by fold edge 8
                Face { id: 2, vertices: [1, 2, 4], edge_ids: [5, 6, 3], material_id: -1, uvs: None },
                Face { id: 3, vertices: [2, 5, 4], edge_ids: [7, 9, 6], material_id: -1, uvs: None },
            ],
            edges: vec![
                // Piece A internal
                MeshEdge { id: 0, face_a: 0, face_b: None,    vert_a: 0, vert_b: 1, edge_type: EdgeType::Boundary },
                MeshEdge { id: 1, face_a: 0, face_b: Some(1), vert_a: 1, vert_b: 3, edge_type: EdgeType::Fold },
                MeshEdge { id: 2, face_a: 0, face_b: None,    vert_a: 0, vert_b: 3, edge_type: EdgeType::Boundary },
                // Cut edge between pieces
                MeshEdge { id: 3, face_a: 1, face_b: Some(2), vert_a: 1, vert_b: 4, edge_type: EdgeType::Cut },
                MeshEdge { id: 4, face_a: 1, face_b: None,    vert_a: 3, vert_b: 4, edge_type: EdgeType::Boundary },
                // Piece B internal
                MeshEdge { id: 5, face_a: 2, face_b: None,    vert_a: 1, vert_b: 2, edge_type: EdgeType::Boundary },
                MeshEdge { id: 6, face_a: 2, face_b: Some(3), vert_a: 2, vert_b: 4, edge_type: EdgeType::Fold },
                MeshEdge { id: 7, face_a: 3, face_b: None,    vert_a: 2, vert_b: 5, edge_type: EdgeType::Boundary },
                MeshEdge { id: 8, face_a: 3, face_b: None,    vert_a: 4, vert_b: 5, edge_type: EdgeType::Boundary },
                MeshEdge { id: 9, face_a: 3, face_b: None,    vert_a: 2, vert_b: 4, edge_type: EdgeType::Boundary },
            ],
            uvs: vec![], material_names: vec![], material_texture_paths: vec![],
            suggested_texture_path: None, pdo_layout: None, embedded_textures: vec![],
            bounds: BoundingBox::default(),
        }
    }

    #[test]
    fn single_piece_yields_one_step() {
        let mesh  = one_piece_mesh();
        let steps = compute_assembly_steps(&mesh);
        assert_eq!(steps.len(), 1, "one fold-connected component → one step");
        assert_eq!(steps[0].parent_group_id, -1, "sole piece is the root");
    }

    #[test]
    fn two_cut_pieces_yield_two_steps() {
        let mesh  = two_piece_mesh();
        let steps = compute_assembly_steps(&mesh);
        assert_eq!(steps.len(), 2, "two separate pieces → two steps");
    }

    #[test]
    fn root_step_has_no_parent() {
        let mesh  = four_face_two_piece_mesh();
        let steps = compute_assembly_steps(&mesh);
        let root  = steps.iter().find(|s| s.parent_group_id == -1);
        assert!(root.is_some(), "there must be exactly one root step");
    }

    #[test]
    fn all_faces_covered_exactly_once() {
        let mesh   = four_face_two_piece_mesh();
        let steps  = compute_assembly_steps(&mesh);
        let mut seen: std::collections::HashSet<usize> = std::collections::HashSet::new();
        for step in &steps {
            for &fid in &step.face_ids {
                assert!(seen.insert(fid), "face {fid} appears in more than one step");
            }
        }
        let total_faces: usize = mesh.faces.len();
        assert_eq!(seen.len(), total_faces, "not all faces appear in assembly steps");
    }

    #[test]
    fn root_piece_is_the_largest() {
        let mesh    = four_face_two_piece_mesh();
        let steps   = compute_assembly_steps(&mesh);
        let root    = steps.iter().find(|s| s.parent_group_id == -1).unwrap();
        let max_len = steps.iter().map(|s| s.face_ids.len()).max().unwrap_or(0);
        assert_eq!(
            root.face_ids.len(), max_len,
            "root piece should be the largest (most faces)"
        );
    }
}

/// Find connected components of the mesh using fold edges only.
/// Returns `Vec<Vec<face_id>>` — one inner vec per component.
fn fold_components(mesh: &Mesh) -> Vec<Vec<usize>> {
    let n = mesh.faces.len();
    let mut comp = vec![usize::MAX; n];
    let mut comp_id = 0usize;

    // Build fold adjacency list
    let mut adj: Vec<Vec<usize>> = vec![vec![]; n];
    for edge in &mesh.edges {
        if edge.edge_type != EdgeType::Fold { continue; }
        if let Some(fb) = edge.face_b {
            adj[edge.face_a].push(fb);
            adj[fb].push(edge.face_a);
        }
    }

    // BFS
    let mut result = Vec::new();
    for start in 0..n {
        if comp[start] != usize::MAX { continue; }
        let mut group  = Vec::new();
        let mut queue  = VecDeque::new();
        queue.push_back(start);
        comp[start] = comp_id;
        while let Some(fid) = queue.pop_front() {
            group.push(fid);
            for &nb in &adj[fid] {
                if comp[nb] == usize::MAX {
                    comp[nb] = comp_id;
                    queue.push_back(nb);
                }
            }
        }
        result.push(group);
        comp_id += 1;
    }
    result
}
