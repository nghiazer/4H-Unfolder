use crate::models::mesh::{BoundingBox, EdgeType, Face, Mesh, MeshEdge, Vertex};
use serde::Serialize;
use std::collections::HashMap;
use tauri::command;

// ---------------------------------------------------------------------------
// DTOs
// ---------------------------------------------------------------------------

/// Summary of a loaded mesh — returned by `get_mesh_info` without the full
/// vertex/edge/face payload.  Mirrors the `MeshInfoDto` TypeScript interface.
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct MeshInfoDto {
    pub face_count:             usize,
    pub vertex_count:           usize,
    pub edge_count:             usize,
    pub material_count:         usize,
    pub has_uvs:                bool,
    pub bounds:                 BoundingBox,
    pub suggested_texture_path: Option<String>,
    pub material_names:         Vec<String>,
    /// True when every face has `edge_ids` stamped (i.e. build_edges ran).
    pub edges_stamped:          bool,
}

// ---------------------------------------------------------------------------
// Public Tauri commands
// ---------------------------------------------------------------------------

/// Load an OBJ file from a filesystem path.
#[command]
pub async fn load_obj(path: String) -> Result<Mesh, String> {
    let bytes = std::fs::read(&path).map_err(|e| e.to_string())?;
    let dir   = std::path::Path::new(&path)
        .parent()
        .map(|p| p.to_string_lossy().into_owned());
    parse_obj_bytes(&bytes, dir.as_deref())
}

/// Load an OBJ from raw bytes (used when the frontend passes file content directly).
#[command]
pub async fn load_obj_from_bytes(bytes: Vec<u8>) -> Result<Mesh, String> {
    parse_obj_bytes(&bytes, None)
}

/// Return metadata about an already-loaded mesh without re-sending the full payload.
#[command]
pub async fn get_mesh_info(mesh: Mesh) -> Result<MeshInfoDto, String> {
    let edges_stamped = mesh.faces.iter().all(|f| {
        // After build_edges(), at least one edge_id must be non-zero
        // (for any mesh with more than 0 edges).
        mesh.edges.len() == 0 || f.edge_ids.iter().any(|&e| e < mesh.edges.len())
    });

    Ok(MeshInfoDto {
        face_count:             mesh.faces.len(),
        vertex_count:           mesh.vertices.len(),
        edge_count:             mesh.edges.len(),
        material_count:         mesh.material_names.len(),
        has_uvs:                !mesh.uvs.is_empty(),
        bounds:                 mesh.bounds.clone(),
        suggested_texture_path: mesh.suggested_texture_path.clone(),
        material_names:         mesh.material_names.clone(),
        edges_stamped,
    })
}

// ---------------------------------------------------------------------------
// OBJ parsing
// ---------------------------------------------------------------------------

fn parse_obj_bytes(bytes: &[u8], obj_dir: Option<&str>) -> Result<Mesh, String> {
    let mut cursor = std::io::Cursor::new(bytes);
    let (models, materials) = tobj::load_obj_buf(
        &mut cursor,
        &tobj::LoadOptions {
            triangulate:  true,
            single_index: true,
            ..Default::default()
        },
        |mtl_path| {
            // Try to resolve MTL relative to the OBJ directory.
            if let Some(dir) = obj_dir {
                let full = std::path::Path::new(dir)
                    .join(mtl_path.file_name().unwrap_or(mtl_path.as_os_str()));
                if let Ok(data) = std::fs::read_to_string(full) {
                    return tobj::load_mtl_buf(&mut data.as_bytes());
                }
            }
            Ok((vec![], Default::default()))
        },
    )
    .map_err(|e| e.to_string())?;

    // -----------------------------------------------------------------------
    // Build material name + texture-path lists
    // -----------------------------------------------------------------------
    let mats = materials.unwrap_or_default();
    let material_names: Vec<String> = mats.iter().map(|m| m.name.clone()).collect();
    let material_texture_paths: Vec<Option<String>> = mats.iter().map(|m| {
        m.diffuse_texture.as_ref().and_then(|t| {
            if t.is_empty() { return None; }
            // Security: strip directory components from MTL-relative texture path.
            let file_name = std::path::Path::new(t)
                .file_name()?
                .to_str()?
                .to_owned();
            // Resolve against OBJ directory if we know it.
            obj_dir.map(|d| format!("{}/{}", d, file_name))
        })
    }).collect();
    let suggested_texture_path = material_texture_paths.iter()
        .find_map(|p| p.clone());

    // -----------------------------------------------------------------------
    // Build vertices, faces (with UVs + material IDs), edges
    // -----------------------------------------------------------------------
    let mut vertices:    Vec<Vertex>  = Vec::new();
    let mut faces:       Vec<Face>    = Vec::new();
    let mut uvs:         Vec<[f64;2]> = Vec::new();
    let mut vert_offset  = 0usize;
    let mut uv_offset    = 0usize;

    for model in &models {
        let m = &model.mesh;

        // Global material id for this model (all faces share it).
        let mat_id: i32 = m.material_id.map(|id| id as i32).unwrap_or(-1);

        // Vertices.
        for i in (0..m.positions.len()).step_by(3) {
            vertices.push(Vertex {
                x: m.positions[i]     as f64,
                y: m.positions[i + 1] as f64,
                z: m.positions[i + 2] as f64,
            });
        }

        // UV coordinates (may be empty).
        let has_uvs = !m.texcoords.is_empty();
        for i in (0..m.texcoords.len()).step_by(2) {
            uvs.push([m.texcoords[i] as f64, m.texcoords[i + 1] as f64]);
        }

        // Faces (already triangulated by tobj).
        let nv = 3usize;
        for f in 0..(m.indices.len() / nv) {
            let base  = f * nv;
            let verts = [
                vert_offset + m.indices[base    ] as usize,
                vert_offset + m.indices[base + 1] as usize,
                vert_offset + m.indices[base + 2] as usize,
            ];
            let face_uvs: Option<[usize; 3]> = if has_uvs {
                Some([
                    uv_offset + m.indices[base    ] as usize,
                    uv_offset + m.indices[base + 1] as usize,
                    uv_offset + m.indices[base + 2] as usize,
                ])
            } else {
                None
            };
            faces.push(Face {
                id:          faces.len(),
                vertices:    verts,
                edge_ids:    [0, 0, 0], // filled by build_edges below
                material_id: mat_id,
                uvs:         face_uvs,
            });
        }

        vert_offset += m.positions.len() / 3;
        if has_uvs {
            uv_offset += m.texcoords.len() / 2;
        }
    }

    let edges = build_edges(&mut faces);

    let mut mesh = Mesh {
        name:     "mesh".to_string(),
        vertices,
        faces,
        edges,
        uvs,
        material_names,
        material_texture_paths,
        suggested_texture_path,
        pdo_layout:        None,
        embedded_textures: vec![],
        bounds:            BoundingBox::default(),
    };
    mesh.recompute_bounds();
    Ok(mesh)
}

// ---------------------------------------------------------------------------
// Edge builder
// ---------------------------------------------------------------------------

/// Build the edge list and stamp `face.edge_ids` in winding order [AB, BC, CA].
///
/// Non-manifold guard (C# behaviour): if a third face tries to claim an edge
/// that already has both `face_a` and `face_b`, the edge is silently ignored
/// for that face (edge_ids entry stays as the existing edge id, but face_b is
/// not overwritten).
pub fn build_edges(faces: &mut Vec<Face>) -> Vec<MeshEdge> {
    // canonical key: (min_vert, max_vert)
    let mut edge_map: HashMap<(usize, usize), usize> = HashMap::new();
    let mut edges:    Vec<MeshEdge> = Vec::new();

    for face in faces.iter_mut() {
        for local in 0..3usize {
            let va   = face.vertices[local];
            let vb   = face.vertices[(local + 1) % 3];
            let key  = if va < vb { (va, vb) } else { (vb, va) };

            let eid = if let Some(&existing) = edge_map.get(&key) {
                // Edge already exists — assign face_b if not yet set.
                if edges[existing].face_b.is_none() {
                    edges[existing].face_b = Some(face.id);
                }
                // (If face_b is already set, silently skip — non-manifold guard.)
                existing
            } else {
                // New edge.
                let eid = edges.len();
                edge_map.insert(key, eid);
                edges.push(MeshEdge {
                    id:        eid,
                    face_a:    face.id,
                    face_b:    None,
                    vert_a:    va,
                    vert_b:    vb,
                    edge_type: EdgeType::Unknown,
                });
                eid
            };

            face.edge_ids[local] = eid;
        }
    }

    edges
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn build_edges_stamps_face_edge_ids() {
        let mut faces = vec![
            Face { id: 0, vertices: [0, 1, 2], edge_ids: [0;3], material_id: -1, uvs: None },
            Face { id: 1, vertices: [1, 3, 2], edge_ids: [0;3], material_id: -1, uvs: None },
        ];
        let edges = build_edges(&mut faces);

        // Shared edge V1-V2 should appear once with both faces set.
        let shared = edges.iter().find(|e| {
            (e.vert_a == 1 && e.vert_b == 2) || (e.vert_a == 2 && e.vert_b == 1)
        }).expect("shared edge 1-2 not found");
        assert!(shared.face_b.is_some(), "shared edge should have both faces");

        // edge_ids[1] of face 0 should point to the shared edge (edge B-C = 1→2).
        let se_id = shared.id;
        assert_eq!(faces[0].edge_ids[1], se_id, "face 0 edge_ids[1] should be shared edge");
    }

    #[test]
    fn non_manifold_third_face_does_not_overwrite_face_b() {
        let mut faces = vec![
            Face { id: 0, vertices: [0, 1, 2], edge_ids: [0;3], material_id: -1, uvs: None },
            Face { id: 1, vertices: [1, 3, 2], edge_ids: [0;3], material_id: -1, uvs: None },
            Face { id: 2, vertices: [1, 4, 2], edge_ids: [0;3], material_id: -1, uvs: None },
        ];
        let edges = build_edges(&mut faces);
        let shared = edges.iter().find(|e| {
            (e.vert_a == 1 && e.vert_b == 2) || (e.vert_a == 2 && e.vert_b == 1)
        }).unwrap();
        assert!(shared.face_b == Some(1) || shared.face_b == Some(0),
            "non-manifold 3rd face should not overwrite face_b");
    }

    // -----------------------------------------------------------------------
    // Integration tests — use fixture OBJ files
    // -----------------------------------------------------------------------

    fn fixture_path(name: &str) -> String {
        std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("tests/fixtures")
            .join(name)
            .to_string_lossy()
            .into_owned()
    }

    #[tokio::test]
    async fn tetrahedron_has_correct_topology() {
        let mesh = load_obj(fixture_path("tetrahedron.obj"))
            .await
            .expect("failed to load tetrahedron.obj");

        assert_eq!(mesh.faces.len(),    4, "tetrahedron: 4 faces");
        assert_eq!(mesh.vertices.len(), 4, "tetrahedron: 4 vertices");
        assert_eq!(mesh.edges.len(),    6, "tetrahedron: 6 edges");
    }

    #[tokio::test]
    async fn tetrahedron_edge_ids_stamped() {
        let mesh = load_obj(fixture_path("tetrahedron.obj"))
            .await
            .expect("failed to load tetrahedron.obj");

        // Every face must have all 3 edge_ids pointing to valid edges.
        for face in &mesh.faces {
            for &eid in &face.edge_ids {
                assert!(eid < mesh.edges.len(),
                    "face {} edge_id {} out of range (edge count {})",
                    face.id, eid, mesh.edges.len());
            }
        }
    }

    #[tokio::test]
    async fn cube_has_correct_topology() {
        let mesh = load_obj(fixture_path("cube.obj"))
            .await
            .expect("failed to load cube.obj");

        assert_eq!(mesh.faces.len(),    12, "cube: 12 triangular faces");
        assert_eq!(mesh.vertices.len(),  8, "cube: 8 vertices");
        // A triangulated cube has 18 edges (12 boundary + 6 internal diagonals).
        assert_eq!(mesh.edges.len(),    18, "cube: 18 edges");
    }

    #[tokio::test]
    async fn cube_interior_edges_have_two_faces() {
        let mesh = load_obj(fixture_path("cube.obj"))
            .await
            .expect("failed to load cube.obj");

        // All 18 edges should have face_b (closed manifold cube).
        for edge in &mesh.edges {
            assert!(edge.face_b.is_some(),
                "cube edge {} (v{}-v{}) should be interior", edge.id, edge.vert_a, edge.vert_b);
        }
    }

    #[tokio::test]
    async fn get_mesh_info_returns_correct_counts() {
        let mesh = load_obj(fixture_path("tetrahedron.obj"))
            .await
            .expect("failed to load tetrahedron.obj");

        let info = get_mesh_info(mesh).await.unwrap();
        assert_eq!(info.face_count,   4);
        assert_eq!(info.vertex_count, 4);
        assert_eq!(info.edge_count,   6);
        assert!(info.edges_stamped,  "edge_ids should be stamped after load");
        assert!(!info.has_uvs,       "tetrahedron.obj has no UVs");
    }

    #[tokio::test]
    async fn mesh_bounds_computed() {
        let mesh = load_obj(fixture_path("cube.obj"))
            .await
            .expect("failed to load cube.obj");

        // Unit cube centred at origin: min ≈ -0.5, max ≈ 0.5.
        for i in 0..3 {
            assert!((mesh.bounds.min[i] + 0.5).abs() < 1e-6,
                "cube min[{i}] should be -0.5, got {}", mesh.bounds.min[i]);
            assert!((mesh.bounds.max[i] - 0.5).abs() < 1e-6,
                "cube max[{i}] should be +0.5, got {}", mesh.bounds.max[i]);
        }
    }
}
