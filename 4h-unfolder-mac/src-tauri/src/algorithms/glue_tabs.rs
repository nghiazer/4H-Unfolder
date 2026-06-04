/// Glue-tab generation — exact port of C# `GlueTabGenerator.Generate()`.
///
/// Supports all 10 `FlapMode` variants and three tab shapes
/// (Trapezoid / Rectangle / Triangle).
use crate::algorithms::constants::DEGENERATE_TAB;
use crate::models::{
    mesh::Mesh,
    unfold::{FlapMode, FlapOverride, GlueTab, Point2, TabShape, UnfoldedFace},
};
use std::collections::{HashMap, HashSet};

// ---------------------------------------------------------------------------
// Public entry point
// ---------------------------------------------------------------------------

/// Generate glue tabs for all `faces`.
///
/// * `depth_mm` / `side_angle_deg` — global defaults from PrintSettings.
/// * `tab_shape` — Trapezoid | Rectangle | Triangle.
/// * `alternate_flaps` — when true, only the lower-id face of each cut edge
///   receives a tab (matches C# `AlternateFlaps` flag).
/// * `overrides` — per-edge `FlapOverride` map (from `EditFlapsDialog`).
pub fn generate_glue_tabs(
    faces:           &[UnfoldedFace],
    depth_mm:        f64,
    side_angle_deg:  f64,
    tab_shape:       TabShape,
    alternate_flaps: bool,
    mesh:            &Mesh,
    overrides:       &HashMap<usize, FlapOverride>,
) -> Vec<GlueTab> {
    // Build the alternateFlaps deny-set: for each cut edge, the face with
    // higher id is denied a tab (only the lower-id face wins).
    let deny_set: HashSet<(usize, usize)> = if alternate_flaps {
        build_alternate_deny_set(faces, mesh)
    } else {
        HashSet::new()
    };

    let mut tabs = Vec::new();

    for face in faces {
        for local_idx in 0..3usize {
            let eid = face.mesh_edge_ids[local_idx];
            if eid < 0 { continue; }
            let eid = eid as usize;

            let edge      = &mesh.edges[eid];
            let is_border = face.edge_is_boundary[local_idx];
            let is_fold   = face.edge_is_fold[local_idx];

            // Determine effective flap mode.
            let flap_mode = overrides.get(&eid).map(|o| o.mode).unwrap_or(FlapMode::Default);
            let primary   = overrides.get(&eid).map(|o| o.primary_face_id).unwrap_or(-1);

            // Default mode: skip fold edges and boundary edges (unless border mode below).
            if flap_mode == FlapMode::Default {
                if is_fold    { continue; }
                if is_border  { continue; } // boundary handled by Border_* modes only
                // AlternateFlaps: skip if this face is the "denied" side.
                if alternate_flaps && deny_set.contains(&(face.face_id, local_idx)) { continue; }
            }

            let p0 = face.vertex(local_idx);
            let p1 = face.vertex((local_idx + 1) % 3);
            let centroid = face.centroid();

            match flap_mode {
                FlapMode::Default => {
                    // Already handled above for fold/boundary.
                    if let Some(tab) = create_tab(face.face_id, local_idx, p0, p1, centroid, depth_mm, side_angle_deg, tab_shape, None) {
                        tabs.push(tab);
                    }
                }
                FlapMode::SwitchPosition => {
                    // Tab goes on the OTHER face — handled when we iterate that face.
                    // On THIS face: skip.
                    let _ = (edge, primary);
                }
                FlapMode::OnOnThisSide => {
                    if primary < 0 || face.face_id == primary as usize {
                        if let Some(tab) = create_tab(face.face_id, local_idx, p0, p1, centroid, depth_mm, side_angle_deg, tab_shape, None) {
                            tabs.push(tab);
                        }
                    }
                }
                FlapMode::OffOnOtherSide => {
                    // Tab only on the face that is NOT primary.
                    if primary >= 0 && face.face_id != primary as usize {
                        if let Some(tab) = create_tab(face.face_id, local_idx, p0, p1, centroid, depth_mm, side_angle_deg, tab_shape, None) {
                            tabs.push(tab);
                        }
                    }
                }
                FlapMode::OffOffNoFlap => {
                    // No tab on either face.
                }
                FlapMode::OnOnBothSides => {
                    // Tab on every face that has this edge (both sides).
                    if let Some(tab) = create_tab(face.face_id, local_idx, p0, p1, centroid, depth_mm, side_angle_deg, tab_shape, None) {
                        tabs.push(tab);
                    }
                }
                // Border modes — add tab to boundary edge with fold-style annotation.
                FlapMode::BorderMountainFold => {
                    if is_border {
                        if let Some(tab) = create_tab(face.face_id, local_idx, p0, p1, centroid, depth_mm, side_angle_deg, tab_shape, Some(FlapMode::BorderMountainFold)) {
                            tabs.push(tab);
                        }
                    }
                }
                FlapMode::BorderValleyFold => {
                    if is_border {
                        if let Some(tab) = create_tab(face.face_id, local_idx, p0, p1, centroid, depth_mm, side_angle_deg, tab_shape, Some(FlapMode::BorderValleyFold)) {
                            tabs.push(tab);
                        }
                    }
                }
                FlapMode::BorderNoFold => {
                    if is_border {
                        if let Some(tab) = create_tab(face.face_id, local_idx, p0, p1, centroid, depth_mm, side_angle_deg, tab_shape, Some(FlapMode::BorderNoFold)) {
                            tabs.push(tab);
                        }
                    }
                }
                FlapMode::BorderNoFlap => {
                    // Explicit no-tab for this border edge.
                }
            }
        }
    }

    tabs
}

// ---------------------------------------------------------------------------
// AlternateFlaps deny-set
// ---------------------------------------------------------------------------

/// For each interior cut edge, build the set of (face_id, local_edge_idx)
/// pairs that should *not* receive a tab (the higher-id face loses).
fn build_alternate_deny_set(
    faces: &[UnfoldedFace],
    mesh:  &Mesh,
) -> HashSet<(usize, usize)> {
    let mut deny = HashSet::new();

    for face in faces {
        for local_idx in 0..3usize {
            let eid = face.mesh_edge_ids[local_idx];
            if eid < 0 { continue; }
            let eid  = eid as usize;
            let edge = &mesh.edges[eid];

            // Only interior cut edges.
            if edge.face_b.is_none() { continue; }
            if face.edge_is_fold[local_idx] { continue; }

            let other_face = if edge.face_a == face.face_id { edge.face_b.unwrap() } else { edge.face_a };
            // The face with the higher id is denied.
            if face.face_id > other_face {
                deny.insert((face.face_id, local_idx));
            }
        }
    }
    deny
}

// ---------------------------------------------------------------------------
// Tab creation
// ---------------------------------------------------------------------------

fn create_tab(
    face_id:       usize,
    local_idx:     usize,
    p0:            Point2,
    p1:            Point2,
    centroid:      Point2,
    depth_mm:      f64,
    angle_deg:     f64,
    shape:         TabShape,
    border_style:  Option<FlapMode>,
) -> Option<GlueTab> {
    match shape {
        TabShape::Trapezoid => create_trapezoid(face_id, local_idx, p0, p1, centroid, depth_mm, angle_deg, border_style),
        TabShape::Rectangle => create_rect(face_id, local_idx, p0, p1, centroid, depth_mm, border_style),
        TabShape::Triangle  => create_triangle(face_id, local_idx, p0, p1, centroid, depth_mm, border_style),
    }
}

/// Trapezoid tab — matches C# `GlueTabGenerator.CreateTrapezoid`.
fn create_trapezoid(
    face_id:      usize,
    local_idx:    usize,
    p0:           Point2,
    p1:           Point2,
    centroid:     Point2,
    depth_mm:     f64,
    angle_deg:    f64,
    border_style: Option<FlapMode>,
) -> Option<GlueTab> {
    let ab  = p1 - p0;
    let len = ab.len();
    if len < DEGENERATE_TAB { return None; }

    let dir  = ab / len;
    let perp = outward_perp(p0, p1, centroid, dir);

    // Bevelled inset — clamped to 45 % of edge length (C# clamp).
    let clamped_angle = angle_deg.clamp(1.0, 89.9);
    let inset = (depth_mm / clamped_angle.to_radians().tan()).min(len * 0.45);

    let q0 = p0 + dir * inset + perp * depth_mm;   // P3 in C# order
    let q1 = p1 - dir * inset + perp * depth_mm;   // P2 in C# order

    // C# stores [P0=edge start, P1=edge end, P2=inset near p1, P3=inset near p0].
    Some(GlueTab { face_id, local_edge_idx: local_idx, p0, p1, p2: q1, p3: q0, border_fold_style: border_style })
}

/// Rectangle tab (no bevel).
fn create_rect(
    face_id:      usize,
    local_idx:    usize,
    p0:           Point2,
    p1:           Point2,
    centroid:     Point2,
    depth_mm:     f64,
    border_style: Option<FlapMode>,
) -> Option<GlueTab> {
    let ab  = p1 - p0;
    let len = ab.len();
    if len < DEGENERATE_TAB { return None; }
    let dir  = ab / len;
    let perp = outward_perp(p0, p1, centroid, dir);

    let q0 = p0 + perp * depth_mm;
    let q1 = p1 + perp * depth_mm;
    Some(GlueTab { face_id, local_edge_idx: local_idx, p0, p1, p2: q1, p3: q0, border_fold_style: border_style })
}

/// Triangle tab (single apex at midpoint).
fn create_triangle(
    face_id:      usize,
    local_idx:    usize,
    p0:           Point2,
    p1:           Point2,
    centroid:     Point2,
    depth_mm:     f64,
    border_style: Option<FlapMode>,
) -> Option<GlueTab> {
    let ab  = p1 - p0;
    let len = ab.len();
    if len < DEGENERATE_TAB { return None; }
    let dir  = ab / len;
    let perp = outward_perp(p0, p1, centroid, dir);

    let apex = (p0 + p1) * 0.5 + perp * depth_mm;
    // Store apex in both P2 and P3 so renderers that expect 4 points still work.
    Some(GlueTab { face_id, local_edge_idx: local_idx, p0, p1, p2: apex, p3: apex, border_fold_style: border_style })
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Perpendicular unit vector pointing *away* from the face centroid.
/// Matches C# "flip if pointing toward centroid" logic.
fn outward_perp(p0: Point2, _p1: Point2, centroid: Point2, dir: Point2) -> Point2 {
    let left = Point2::new(-dir.y, dir.x);  // 90° left of dir
    // Dot with (centroid - p0) to check which side centroid is on.
    let to_c = centroid - p0;
    if to_c.dot(left) > 0.0 { -left } else { left }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use crate::algorithms::spanning_tree::{build_spanning_tree, compute_dihedral_angle, mark_edges};
    use crate::algorithms::face_unfold::unfold_faces;
    use crate::models::mesh::{BoundingBox, Face, Mesh, MeshEdge, Vertex};
    use crate::models::mesh::EdgeType;

    fn two_flat_triangles() -> Mesh {
        Mesh {
            name: "two_flat".into(),
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
                MeshEdge { id: 0, face_a: 0, face_b: None,    vert_a: 0, vert_b: 1, edge_type: EdgeType::Unknown },
                MeshEdge { id: 1, face_a: 0, face_b: Some(1), vert_a: 1, vert_b: 2, edge_type: EdgeType::Unknown },
                MeshEdge { id: 2, face_a: 0, face_b: None,    vert_a: 0, vert_b: 2, edge_type: EdgeType::Unknown },
                MeshEdge { id: 3, face_a: 1, face_b: None,    vert_a: 1, vert_b: 3, edge_type: EdgeType::Unknown },
                MeshEdge { id: 4, face_a: 1, face_b: None,    vert_a: 2, vert_b: 3, edge_type: EdgeType::Unknown },
            ],
            uvs: vec![], material_names: vec![], material_texture_paths: vec![],
            suggested_texture_path: None, pdo_layout: None, embedded_textures: vec![],
            bounds: BoundingBox::default(),
        }
    }

    #[test]
    fn default_mode_produces_tabs_only_on_cut_edges() {
        let mut mesh  = two_flat_triangles();
        let tree      = build_spanning_tree(&mesh, |e| compute_dihedral_angle(&mesh, e));
        let fold_set  = tree.fold_edge_ids.iter().cloned().collect();
        mark_edges(&mut mesh, &fold_set);
        let faces     = unfold_faces(&mesh, &fold_set);
        let tabs      = generate_glue_tabs(&faces, 5.0, 45.0, TabShape::Trapezoid, false, &mesh, &HashMap::new());

        // The one interior edge is the fold edge — only cut edges (boundary here) get tabs in Default mode
        // But boundary edges are skipped by Default mode → 0 tabs expected with only one interior fold edge.
        // (All non-fold edges are boundary in this mesh.)
        assert_eq!(tabs.len(), 0, "No tabs expected: all non-fold edges are boundary");
    }

    #[test]
    fn tab_depth_within_bounds() {
        let mut mesh  = two_flat_triangles();
        let tree      = build_spanning_tree(&mesh, |e| compute_dihedral_angle(&mesh, e));
        let fold_set: std::collections::HashSet<usize> = tree.fold_edge_ids.iter().cloned().collect();
        mark_edges(&mut mesh, &fold_set);
        let faces     = unfold_faces(&mesh, &fold_set);

        // Force all edges to cut (override fold to cut in the faces directly)
        // by using Border_MountainFold override on all boundary edges.
        let mut ov_map: HashMap<usize, FlapOverride> = HashMap::new();
        for face in &faces {
            for i in 0..3usize {
                let eid = face.mesh_edge_ids[i];
                if eid >= 0 && face.edge_is_boundary[i] {
                    ov_map.insert(eid as usize, FlapOverride {
                        mode: FlapMode::BorderMountainFold,
                        primary_face_id: -1,
                    });
                }
            }
        }

        let tabs = generate_glue_tabs(&faces, 5.0, 45.0, TabShape::Trapezoid, false, &mesh, &ov_map);
        for tab in &tabs {
            // For a trapezoid tab, p3 = p0 + dir*inset + perp*depth_mm.
            // The perpendicular component of (p3 - p0) equals depth_mm.
            // The edge direction is (p1 - p0) normalised.
            let edge = tab.p1 - tab.p0;
            let len  = edge.len();
            if len < 1e-9 { continue; }
            let perp = crate::models::unfold::Point2::new(-edge.y / len, edge.x / len);
            let delta = tab.p3 - tab.p0;
            let perp_depth = delta.dot(perp).abs();
            // Accept up to depth_mm + 0.01 tolerance.
            assert!(perp_depth <= 5.0 + 0.01, "perpendicular tab depth {perp_depth} should not exceed depth_mm 5.0");
        }
    }

    #[test]
    fn off_off_no_flap_produces_no_tabs() {
        let mut mesh  = two_flat_triangles();
        let tree      = build_spanning_tree(&mesh, |e| compute_dihedral_angle(&mesh, e));
        let fold_set: std::collections::HashSet<usize> = tree.fold_edge_ids.iter().cloned().collect();
        mark_edges(&mut mesh, &fold_set);
        let faces     = unfold_faces(&mesh, &fold_set);

        let mut ov_map: HashMap<usize, FlapOverride> = HashMap::new();
        for e in &mesh.edges {
            ov_map.insert(e.id, FlapOverride { mode: FlapMode::OffOffNoFlap, primary_face_id: -1 });
        }
        let tabs = generate_glue_tabs(&faces, 5.0, 45.0, TabShape::Trapezoid, false, &mesh, &ov_map);
        assert!(tabs.is_empty(), "OffOffNoFlap should produce zero tabs");
    }
}
