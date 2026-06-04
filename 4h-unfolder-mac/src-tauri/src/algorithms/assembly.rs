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
