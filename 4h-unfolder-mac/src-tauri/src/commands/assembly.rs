use crate::algorithms::assembly::{compute_assembly_steps, AssemblyStep};
use crate::models::mesh::Mesh;
use tauri::command;

/// Return ordered assembly steps for the given mesh.
/// The mesh must have had its edges stamped (via `unfold_mesh` or `build_edges`).
#[command]
pub async fn get_assembly_steps(mesh: Mesh) -> Result<Vec<AssemblyStep>, String> {
    if mesh.edges.is_empty() {
        return Err("Mesh has no edges — run Unfold first".to_string());
    }
    Ok(compute_assembly_steps(&mesh))
}
