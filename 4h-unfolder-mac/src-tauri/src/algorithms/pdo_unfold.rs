/// Build `Vec<UnfoldedFace>` directly from a PDO layout, bypassing the BFS
/// unfolding algorithm.  The PDO file already stores the 2D paper-space
/// coordinates for every face, so we just convert them.
use crate::models::{
    mesh::{EdgeType, Mesh},
    unfold::{Point2, UnfoldedFace},
};
use std::collections::HashSet;

/// Convert PDO layout faces into `UnfoldedFace` records suitable for rendering
/// and export.  Returns `Err` if the mesh has no PDO layout attached.
pub fn build_from_pdo(mesh: &Mesh) -> Result<Vec<UnfoldedFace>, String> {
    let layout = mesh
        .pdo_layout
        .as_ref()
        .ok_or("Mesh has no PDO layout")?;

    let mut result = Vec::with_capacity(layout.faces.len());

    for pf in &layout.faces {
        // Determine edge types from the mesh adjacency (built by build_edges).
        // Edges shared within the same part_index are fold edges;
        // edges crossing different part_index values are cut edges;
        // boundary edges (face_b = None) stay as boundary.
        let face = mesh.faces.get(pf.face_id).ok_or("PDO face_id out of range")?;

        let edge_is_fold:     [bool; 3] = std::array::from_fn(|i| {
            let eid = face.edge_ids[i];
            if let Some(e) = mesh.edges.get(eid) {
                e.edge_type == EdgeType::Fold
            } else {
                false
            }
        });
        let edge_is_boundary: [bool; 3] = std::array::from_fn(|i| {
            let eid = face.edge_ids[i];
            if let Some(e) = mesh.edges.get(eid) { e.face_b.is_none() } else { false }
        });
        let mesh_edge_ids: [i32; 3] = std::array::from_fn(|i| face.edge_ids[i] as i32);

        result.push(UnfoldedFace {
            face_id:          pf.face_id,
            v0:               Point2::new(pf.a[0], pf.a[1]),
            v1:               Point2::new(pf.b[0], pf.b[1]),
            v2:               Point2::new(pf.c[0], pf.c[1]),
            edge_is_fold,
            edge_is_boundary,
            uv_coords:        None,
            material_id:      face.material_id,
            mesh_edge_ids,
            piece_id:         pf.part_index as usize,
        });
    }

    Ok(result)
}

/// Mark edges as Fold/Cut/Boundary based on PDO part_index grouping.
/// Edges shared by two faces with the same part_index → Fold.
/// Edges crossing different part_index values → Cut.
/// Boundary edges (face_b = None) → Boundary.
pub fn mark_pdo_edges(mesh: &mut Mesh) {
    let layout = match &mesh.pdo_layout {
        Some(l) => l.clone(),
        None    => return,
    };

    // Build face_id → part_index map
    let part_of: std::collections::HashMap<usize, i32> = layout
        .faces
        .iter()
        .map(|pf| (pf.face_id, pf.part_index))
        .collect();

    for edge in &mut mesh.edges {
        edge.edge_type = if edge.face_b.is_none() {
            crate::models::mesh::EdgeType::Boundary
        } else {
            let pa = part_of.get(&edge.face_a).copied().unwrap_or(-999);
            let pb = part_of.get(&edge.face_b.unwrap()).copied().unwrap_or(-998);
            if pa == pb {
                crate::models::mesh::EdgeType::Fold
            } else {
                crate::models::mesh::EdgeType::Cut
            }
        };
    }
}
