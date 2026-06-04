/// Save / load the `.4hu` project bundle (ZIP: mesh bytes + state JSON).
/// Security: all asset entry names are stripped with `Path::file_name()`.
use serde::{Deserialize, Serialize};
use std::io::{Read, Write};
use tauri::command;

const ALLOWED_ASSET_EXTS: &[&str] = &[
    "obj", "pdo", "fbx", "stl", "ply", "dae", "3ds", "glb", "gltf",
    "png", "jpg", "jpeg", "bmp", "tga", "tiff", "webp",
];

fn is_allowed_ext(name: &str) -> bool {
    let ext = std::path::Path::new(name)
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or("")
        .to_lowercase();
    ALLOWED_ASSET_EXTS.contains(&ext.as_str())
}

fn safe_filename(name: &str) -> Option<String> {
    let p = std::path::Path::new(name);
    let filename = p.file_name()?.to_str()?.to_owned();
    if is_allowed_ext(&filename) { Some(filename) } else { None }
}

// ---------------------------------------------------------------------------
// DTOs
// ---------------------------------------------------------------------------

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PieceLayoutDto {
    pub group_id:    usize,
    pub position_x:  f64,
    pub position_y:  f64,
    pub rotation:    f64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub user_group_id: Option<usize>,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PaperDto {
    pub name:       String,
    pub width_mm:   f64,
    pub height_mm:  f64,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ProjectState {
    pub version:           u32,
    pub mesh_filename:     String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub texture_ext:       Option<String>,
    pub scale_mm_per_unit: f64,
    pub mirror_x:          bool,
    pub paper:             PaperDto,
    pub pages_wide:        u32,
    pub pages_tall:        u32,
    pub edge_overrides:    std::collections::HashMap<String, String>,
    pub flap_overrides:    std::collections::HashMap<String, String>,
    pub piece_layouts:     Vec<PieceLayoutDto>,
    pub material_texture_exts: std::collections::HashMap<String, Option<String>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub inserted_image_ext: Option<String>,
    /// Not persisted.
    #[serde(skip)]
    pub warnings:          Vec<String>,
}

// ---------------------------------------------------------------------------
// Commands
// ---------------------------------------------------------------------------

#[command]
pub async fn save_project(
    path:       String,
    state:      ProjectState,
    mesh_bytes: Vec<u8>,
) -> Result<(), String> {
    let file = std::fs::File::create(&path).map_err(|e| e.to_string())?;
    let mut zip = zip::ZipWriter::new(file);
    let opts: zip::write::FileOptions<()> = zip::write::FileOptions::default()
        .compression_method(zip::CompressionMethod::Deflated);

    // Write mesh bytes (use safe filename only).
    let mesh_name = safe_filename(&state.mesh_filename)
        .ok_or_else(|| format!("Invalid mesh filename: {}", state.mesh_filename))?;
    zip.start_file(&mesh_name, opts).map_err(|e| e.to_string())?;
    zip.write_all(&mesh_bytes).map_err(|e| e.to_string())?;

    // Write state JSON.
    let state_json = serde_json::to_string_pretty(&state).map_err(|e| e.to_string())?;
    zip.start_file("state.json", opts).map_err(|e| e.to_string())?;
    zip.write_all(state_json.as_bytes()).map_err(|e| e.to_string())?;

    zip.finish().map_err(|e| e.to_string())?;
    Ok(())
}

#[command]
pub async fn load_project(path: String) -> Result<(ProjectState, Vec<u8>), String> {
    let file = std::fs::File::open(&path).map_err(|e| e.to_string())?;
    let mut zip = zip::ZipArchive::new(file).map_err(|e| e.to_string())?;

    // Read state.json first.
    let state_json = {
        let mut entry = zip.by_name("state.json").map_err(|e| e.to_string())?;
        let mut buf = String::new();
        entry.read_to_string(&mut buf).map_err(|e| e.to_string())?;
        buf
    };
    let mut state: ProjectState = serde_json::from_str(&state_json).map_err(|e| e.to_string())?;

    // Version check.
    if state.version > 2 {
        return Err(format!("Project version {} is too new (max supported: 2)", state.version));
    }

    // Read mesh bytes.
    let mesh_name = safe_filename(&state.mesh_filename)
        .ok_or_else(|| format!("Unsafe mesh filename in bundle: {}", state.mesh_filename))?;

    let mesh_bytes = {
        let mut entry = zip.by_name(&mesh_name).map_err(|e| e.to_string())?;
        let mut buf = Vec::new();
        entry.read_to_end(&mut buf).map_err(|e| e.to_string())?;
        buf
    };

    state.mesh_filename = mesh_name;
    Ok((state, mesh_bytes))
}
