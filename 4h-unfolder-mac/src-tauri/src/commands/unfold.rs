/// Full unfold pipeline — mirrors C# `UnfoldService.Unfold()`.
///
/// Steps (matching C# order):
///   1. Build dihedral-weighted spanning tree  →  fold edge set
///   2. Apply user edge overrides (force Fold / Cut)
///   3. Stamp EdgeType on all mesh edges
///   4. BFS unfold  →  Vec<UnfoldedFace>
///   5. Overlap detection  (always false for now; OverlapDetector added later)
///   6. Glue-tab generation
///   7. Assign sequential 1-based cut-edge pair IDs
///   8. Build dihedral-angle map (fold edges, radians → degrees)
///   9. Compute connected components (pieces)
///  10. Auto-arrange pieces
///  11. Return `UnfoldResponse`
use crate::algorithms::{
    face_unfold::unfold_faces,
    glue_tabs::generate_glue_tabs,
    layout,
    spanning_tree::{build_spanning_tree, compute_dihedral_angle, mark_edges},
};
use crate::models::{
    mesh::Mesh,
    unfold::{FlapOverride, PieceLayout, Point2, TabShape, UnfoldResponse, UnfoldResult},
};
use serde::Deserialize;
use std::collections::{HashMap, HashSet};
use tauri::command;

// ---------------------------------------------------------------------------
// Options passed from the frontend
// ---------------------------------------------------------------------------

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UnfoldOptions {
    pub tab_width_mm:    f64,
    pub tab_angle_deg:   f64,
    pub sheet_width_mm:  f64,
    pub sheet_height_mm: f64,
    pub auto_arrange:    bool,
    pub alternate_flaps: bool,
    /// "Trapezoid" | "Rectangle" | "Triangle"
    pub tab_shape:       String,
    /// mesh_edge_id (string key) → "Fold" | "Cut"
    pub edge_overrides:  HashMap<String, String>,
    /// mesh_edge_id (string key) → serialized FlapOverride ("{Mode},{PrimaryFaceId}")
    pub flap_overrides:  HashMap<String, String>,
}

// ---------------------------------------------------------------------------
// Tauri commands
// ---------------------------------------------------------------------------

/// Main unfold command — runs the full pipeline and returns `UnfoldResponse`.
#[command]
pub async fn unfold_mesh(
    mut mesh: Mesh,
    options:  UnfoldOptions,
) -> Result<UnfoldResponse, String> {
    // 1. Dihedral-weighted MST.
    let tree = build_spanning_tree(&mesh, |e| compute_dihedral_angle(&mesh, e));
    let mut fold_set: HashSet<usize> = tree.fold_edge_ids.iter().cloned().collect();

    // 2. Apply user edge overrides.
    for (k, v) in &options.edge_overrides {
        if let Ok(eid) = k.parse::<usize>() {
            match v.as_str() {
                "Fold" => { fold_set.insert(eid); }
                "Cut"  => { fold_set.remove(&eid); }
                _      => {}
            }
        }
    }

    // 3. Stamp EdgeType.
    mark_edges(&mut mesh, &fold_set);

    // 4. BFS unfold.
    let unfolded_faces = unfold_faces(&mesh, &fold_set);

    // 5. Overlap detection (stub — always false until OverlapDetector is ported).
    let has_overlaps = false;

    // 6. Glue tabs.
    let tab_shape = match options.tab_shape.as_str() {
        "Rectangle" => TabShape::Rectangle,
        "Triangle"  => TabShape::Triangle,
        _           => TabShape::Trapezoid,
    };
    let flap_overrides = parse_flap_overrides(&options.flap_overrides);
    let glue_tabs = generate_glue_tabs(
        &unfolded_faces,
        options.tab_width_mm,
        options.tab_angle_deg,
        tab_shape,
        options.alternate_flaps,
        &mesh,
        &flap_overrides,
    );

    // 7. Cut-edge pair IDs (1-based sequential).
    let cut_edge_pair_ids = build_cut_edge_pair_ids(&unfolded_faces, &mesh);

    // 8. Dihedral-angle map (fold edges only, radians → degrees).
    let edge_dihedral_angles: HashMap<usize, f64> = fold_set
        .iter()
        .filter_map(|&eid| {
            let e = &mesh.edges[eid];
            if e.face_b.is_some() {
                let deg = compute_dihedral_angle(&mesh, e).to_degrees();
                Some((eid, deg))
            } else {
                None
            }
        })
        .collect();

    // 9. Connected components.
    let pieces = compute_pieces(&unfolded_faces);

    // 10. Build PieceLayout list + optional auto-arrange.
    let mut piece_layouts: Vec<PieceLayout> = pieces
        .iter()
        .enumerate()
        .map(|(pid, face_ids)| PieceLayout {
            piece_id: pid,
            face_ids: face_ids.clone(),
            offset:   Point2::ZERO,
            rotation: 0.0,
        })
        .collect();

    if options.auto_arrange {
        layout::auto_arrange(&unfolded_faces, &mut piece_layouts, options.sheet_width_mm, 5.0);
    }

    // 11. Assemble response.
    Ok(UnfoldResponse {
        unfold_result: UnfoldResult {
            faces: unfolded_faces,
            glue_tabs,
            has_overlaps,
            cut_edge_pair_ids,
            edge_dihedral_angles,
        },
        piece_layouts,
        sheet_width_mm:  options.sheet_width_mm,
        sheet_height_mm: options.sheet_height_mm,
    })
}

/// Return the face-adjacency list for the frontend (e.g. for the dual-graph view).
#[command]
pub async fn get_face_adjacency(
    mesh: Mesh,
) -> Result<Vec<(usize, usize, Option<usize>)>, String> {
    Ok(mesh.edges.iter().map(|e| (e.id, e.face_a, e.face_b)).collect())
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Parse `HashMap<String, String>` flap-override map from the frontend.
fn parse_flap_overrides(raw: &HashMap<String, String>) -> HashMap<usize, FlapOverride> {
    raw.iter()
        .filter_map(|(k, v)| {
            let eid = k.parse::<usize>().ok()?;
            let ov  = FlapOverride::deserialize(v)?;
            Some((eid, ov))
        })
        .collect()
}

/// Assign sequential 1-based pair IDs to every cut edge (both faces of the
/// same cut edge get the same number).  Matches C# pairing logic.
fn build_cut_edge_pair_ids(
    faces: &[crate::models::unfold::UnfoldedFace],
    _mesh: &Mesh,
) -> HashMap<usize, usize> {
    let mut pair_map: HashMap<usize, usize> = HashMap::new();
    let mut counter = 1usize;

    for face in faces {
        for i in 0..3usize {
            if face.edge_is_fold[i] || face.edge_is_boundary[i] { continue; }
            let eid = face.mesh_edge_ids[i];
            if eid < 0 { continue; }
            let eid = eid as usize;
            if !pair_map.contains_key(&eid) {
                pair_map.insert(eid, counter);
                counter += 1;
            }
        }
    }
    pair_map
}

/// Group unfolded faces into connected components (pieces) by piece_id.
fn compute_pieces(faces: &[crate::models::unfold::UnfoldedFace]) -> Vec<Vec<usize>> {
    if faces.is_empty() { return vec![]; }
    let max_piece = faces.iter().map(|f| f.piece_id).max().unwrap_or(0);
    let mut pieces: Vec<Vec<usize>> = vec![Vec::new(); max_piece + 1];
    for face in faces {
        pieces[face.piece_id].push(face.face_id);
    }
    pieces.retain(|p| !p.is_empty());
    pieces
}

