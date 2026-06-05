use serde::{Deserialize, Serialize};

/// Classification of a mesh edge after the spanning-tree / edge-marking step.
/// Matches C# `EdgeType` enum exactly.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub enum EdgeType {
    #[default]
    Unknown,
    Fold,
    Cut,
    Boundary,
}

/// Immutable 3-D vertex.  `id` equals its index in `Mesh.vertices`.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Vertex {
    pub x: f64,
    pub y: f64,
    pub z: f64,
}

/// A triangular face referencing three vertex indices (winding order preserved).
/// `edge_ids[i]` is the mesh edge between `vertices[i]` and `vertices[(i+1)%3]`,
/// matching C# Face.EdgeIds order [AB, BC, CA].
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Face {
    pub id:          usize,
    /// Vertex indices [A, B, C].
    pub vertices:    [usize; 3],
    /// Edge ids in winding order [AB, BC, CA].  Populated by `build_edges()`.
    pub edge_ids:    [usize; 3],
    /// -1 = no material.
    pub material_id: i32,
    /// Optional texture-UV indices parallel to `vertices`.  None = no UV.
    pub uvs:         Option<[usize; 3]>,
}

/// An undirected edge between two faces.
/// `vert_a ≤ vert_b` (canonical form).
/// `face_b = None` means boundary edge.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MeshEdge {
    pub id:        usize,
    pub face_a:    usize,
    pub face_b:    Option<usize>,
    pub vert_a:    usize,
    pub vert_b:    usize,
    /// Set by `mark_edges()` after the spanning-tree is built.
    pub edge_type: EdgeType,
}

/// Pre-computed 2-D paper-space layout embedded in a PDO file.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PdoFace {
    pub face_id:    usize,
    pub part_index: i32,
    /// Paper-space 2-D coordinates (mm) for vertices A, B, C.
    pub a: [f64; 2],
    pub b: [f64; 2],
    pub c: [f64; 2],
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PdoLayout {
    pub faces: Vec<PdoFace>,
}

/// An embedded texture decoded from a PDO file (uncompressed RGB24).
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct EmbeddedTexture {
    pub name:       String,
    pub width:      u32,
    pub height:     u32,
    /// Raw RGB24 bytes (row-major, top-to-bottom).
    pub rgb24_bytes: Vec<u8>,
}

/// Axis-aligned bounding box in 3-D model space.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BoundingBox {
    pub min: [f64; 3],
    pub max: [f64; 3],
}

impl Default for BoundingBox {
    fn default() -> Self {
        Self {
            min: [f64::INFINITY;     3],
            max: [f64::NEG_INFINITY; 3],
        }
    }
}

/// Complete loaded mesh.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Mesh {
    pub name:      String,
    pub vertices:  Vec<Vertex>,
    pub faces:     Vec<Face>,
    pub edges:     Vec<MeshEdge>,
    /// Flat list of UV coordinates; indexed via `Face.uvs`.
    pub uvs:       Vec<[f64; 2]>,
    /// Material names (index == material_id).
    pub material_names:         Vec<String>,
    /// Per-material texture file paths (parallel to `material_names`).
    pub material_texture_paths: Vec<Option<String>>,
    /// First non-null material texture path (convenience).
    pub suggested_texture_path: Option<String>,
    /// Pre-computed 2-D layout from a PDO file (None for OBJ / Assimp).
    pub pdo_layout:         Option<PdoLayout>,
    /// RGB24 textures embedded in a PDO file.
    pub embedded_textures:  Vec<EmbeddedTexture>,
    pub bounds: BoundingBox,
}

impl Mesh {
    /// Recompute AABB from the current vertex list.
    pub fn recompute_bounds(&mut self) {
        self.bounds = BoundingBox::default();
        for v in &self.vertices {
            let c = [v.x, v.y, v.z];
            for i in 0..3 {
                if c[i] < self.bounds.min[i] { self.bounds.min[i] = c[i]; }
                if c[i] > self.bounds.max[i] { self.bounds.max[i] = c[i]; }
            }
        }
    }
}
