/// Pepakura Designer PDO v3 binary parser.
///
/// Format overview (reverse-engineered):
///   - ASCII signature "version 3\n" (10 bytes)
///   - Settings block (cipher-encoded UTF-16LE strings, various settings)
///   - Geometry block(s): each has a name, 3D vertices, and 2D paper-space faces
///   - Texture block: optional embedded PNG/JPG textures (zlib-compressed RGB24)
///
/// Cipher: `decoded_byte = raw_byte.wrapping_sub(key_byte)`
/// For unlocked (no password) PDO files the key is all-zeros, making it a no-op.
/// Locked files use a key derived from the password; not supported here.
use crate::models::mesh::{
    BoundingBox, EmbeddedTexture, Face, MeshEdge, Mesh, PdoFace, PdoLayout, Vertex,
};
use crate::commands::mesh::build_edges;
use flate2::read::ZlibDecoder;
use std::io::Read;

// ---------------------------------------------------------------------------
// Internal reader helpers
// ---------------------------------------------------------------------------

struct Reader<'a> {
    data:    &'a [u8],
    pos:     usize,
    key:     Vec<u8>,
    key_pos: usize,
}

impl<'a> Reader<'a> {
    fn new(data: &'a [u8]) -> Self {
        Self { data, pos: 0, key: vec![0u8], key_pos: 0 }
    }

    fn remaining(&self) -> usize {
        self.data.len().saturating_sub(self.pos)
    }

    fn read_u8(&mut self) -> Option<u8> {
        if self.pos >= self.data.len() { return None; }
        let v = self.data[self.pos];
        self.pos += 1;
        Some(v)
    }

    fn read_u32(&mut self) -> Option<u32> {
        if self.pos + 4 > self.data.len() { return None; }
        let v = u32::from_le_bytes(self.data[self.pos..self.pos + 4].try_into().ok()?);
        self.pos += 4;
        Some(v)
    }

    fn read_i32(&mut self) -> Option<i32> {
        self.read_u32().map(|v| v as i32)
    }

    fn read_f64(&mut self) -> Option<f64> {
        if self.pos + 8 > self.data.len() { return None; }
        let v = f64::from_le_bytes(self.data[self.pos..self.pos + 8].try_into().ok()?);
        self.pos += 8;
        Some(v)
    }

    fn skip(&mut self, n: usize) {
        self.pos = (self.pos + n).min(self.data.len());
    }

    fn read_bytes(&mut self, n: usize) -> Option<&[u8]> {
        if self.pos + n > self.data.len() { return None; }
        let slice = &self.data[self.pos..self.pos + n];
        self.pos += n;
        Some(slice)
    }

    /// Read a cipher-encoded UTF-16LE string.
    /// Length prefix is u32 (number of UTF-16 code units, not bytes).
    fn read_wstr(&mut self) -> Option<String> {
        let char_count = self.read_u32()? as usize;
        let byte_count = char_count * 2;
        if self.pos + byte_count > self.data.len() { return None; }

        let mut buf = Vec::with_capacity(byte_count);
        for i in 0..byte_count {
            let raw  = self.data[self.pos + i];
            let kbyt = self.key[self.key_pos % self.key.len()];
            buf.push(raw.wrapping_sub(kbyt));
            self.key_pos += 1;
        }
        self.pos += byte_count;

        let chars: Vec<u16> = buf
            .chunks_exact(2)
            .map(|b| u16::from_le_bytes([b[0], b[1]]))
            .collect();
        String::from_utf16(&chars).ok()
    }
}

// ---------------------------------------------------------------------------
// Public entry point
// ---------------------------------------------------------------------------

/// Load a Pepakura v3 PDO file from raw bytes.
pub fn load_pdo(data: &[u8]) -> Result<Mesh, String> {
    // Validate signature
    let sig = b"version 3\n";
    if data.len() < sig.len() || &data[..sig.len()] != sig {
        return Err("Not a Pepakura v3 PDO file".to_string());
    }

    let mut r = Reader::new(data);
    r.skip(sig.len());

    parse_pdo(&mut r)
}

fn parse_pdo(r: &mut Reader<'_>) -> Result<Mesh, String> {
    // -----------------------------------------------------------------------
    // Settings / header block (variable-length, skip most fields)
    // -----------------------------------------------------------------------
    // These are version-specific fields. We read what we need and skip the rest.

    // Author / locale strings (4 strings: author, comment, copyright, webpage)
    let _author    = r.read_wstr();
    let _comment   = r.read_wstr();
    let _copyright = r.read_wstr();
    let _webpage   = r.read_wstr();

    // Various settings flags (we skip most)
    // lock_flag (u32): 0 = unlocked
    let lock_flag = r.read_u32().unwrap_or(0);
    if lock_flag != 0 {
        // Locked file — need password key to decode; return error
        return Err("PDO file is password-locked; open in Pepakura Designer first".to_string());
    }

    // Skip known fixed-size settings (approximate — may vary by sub-version)
    // These include: show_flap, show_fold_lines, page counts, paper size, etc.
    // We skip a conservative amount and rely on geometry block markers.
    // 60 bytes covers most common settings fields for v3 PDO.
    r.skip(60);

    // -----------------------------------------------------------------------
    // Geometry block
    // -----------------------------------------------------------------------
    let geom_count = r.read_u32().unwrap_or(0);

    let mut all_vertices: Vec<Vertex> = Vec::new();
    let mut all_faces:    Vec<Face>   = Vec::new();
    let mut pdo_faces:    Vec<PdoFace> = Vec::new();
    let mut vert_offset   = 0usize;

    for _g in 0..geom_count {
        let _name = r.read_wstr(); // geometry name (unused)

        let vert_count = r.read_u32().unwrap_or(0) as usize;
        for _ in 0..vert_count {
            let x = r.read_f64().unwrap_or(0.0);
            let y = r.read_f64().unwrap_or(0.0);
            let z = r.read_f64().unwrap_or(0.0);
            all_vertices.push(Vertex { x, y, z });
        }

        let shape_count = r.read_u32().unwrap_or(0) as usize;
        for _s in 0..shape_count {
            let mat_id   = r.read_i32().unwrap_or(-1);
            let pt_count = r.read_u32().unwrap_or(0) as usize;

            // Each point is 85 bytes: vertex_idx(4) + paper_xy(16) + uv(16) + skip(49)
            // Fan triangulate polygon: tris = (pt_count - 2) triangles from pt[0]
            let mut pts: Vec<(usize, [f64; 2], [f64; 2])> = Vec::new();
            for _p in 0..pt_count {
                let start = r.pos;
                let vi  = r.read_u32().unwrap_or(0) as usize + vert_offset;
                let px  = r.read_f64().unwrap_or(0.0);
                let py  = r.read_f64().unwrap_or(0.0);
                let uv0 = r.read_f64().unwrap_or(0.0);
                let uv1 = 1.0 - r.read_f64().unwrap_or(0.0); // v = 1 - v
                // Pad to 85 bytes total
                let consumed = r.pos - start;
                if consumed < 85 { r.skip(85 - consumed); }
                pts.push((vi, [px, py], [uv0, uv1]));
            }

            // Fan triangulation
            for i in 1..pts.len().saturating_sub(1) {
                let (va, pa, _) = pts[0];
                let (vb, pb, _) = pts[i];
                let (vc, pc, _) = pts[i + 1];

                let face_id = all_faces.len();
                all_faces.push(Face {
                    id:          face_id,
                    vertices:    [vert_offset + va, vert_offset + vb, vert_offset + vc],
                    edge_ids:    [0, 0, 0],
                    material_id: mat_id,
                    uvs:         None,
                });
                pdo_faces.push(PdoFace {
                    face_id,
                    part_index: _g as i32,
                    a: pa,
                    b: pb,
                    c: pc,
                });
            }
        }

        vert_offset += all_vertices.len();
    }

    // -----------------------------------------------------------------------
    // Build edges
    // -----------------------------------------------------------------------
    let edges = build_edges(&mut all_faces);

    // -----------------------------------------------------------------------
    // Texture block
    // -----------------------------------------------------------------------
    let mut embedded_textures: Vec<EmbeddedTexture> = Vec::new();
    let mut material_names: Vec<String> = Vec::new();

    let tex_count = r.read_u32().unwrap_or(0) as usize;
    for _t in 0..tex_count {
        let name = r.read_wstr().unwrap_or_default();
        material_names.push(name.clone());

        r.skip(80); // skip misc texture metadata

        let has_image = r.read_u8().unwrap_or(0);
        if has_image != 0 {
            let width  = r.read_u32().unwrap_or(0);
            let height = r.read_u32().unwrap_or(0);
            let csize  = r.read_u32().unwrap_or(0) as usize;

            if let Some(compressed) = r.read_bytes(csize) {
                let mut decoder = ZlibDecoder::new(compressed);
                let mut rgb24 = Vec::new();
                if decoder.read_to_end(&mut rgb24).is_ok() {
                    embedded_textures.push(EmbeddedTexture {
                        name,
                        width,
                        height,
                        rgb24_bytes: rgb24,
                    });
                }
            }
        }
    }

    // -----------------------------------------------------------------------
    // Build Mesh
    // -----------------------------------------------------------------------
    let mut mesh = Mesh {
        name:                  "pdo_mesh".to_string(),
        vertices:              all_vertices,
        faces:                 all_faces,
        edges,
        uvs:                   vec![],
        material_names,
        material_texture_paths: vec![],
        suggested_texture_path: None,
        pdo_layout:             Some(PdoLayout { faces: pdo_faces }),
        embedded_textures,
        bounds:                 BoundingBox::default(),
    };
    mesh.recompute_bounds();

    Ok(mesh)
}
