mod algorithms;
mod commands;
mod models;

use tauri::Manager;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    env_logger::init();

    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_fs::init())
        .plugin(tauri_plugin_shell::init())
        .setup(|app| {
            #[cfg(debug_assertions)]
            {
                if let Some(window) = app.get_webview_window("main") {
                    window.open_devtools();
                }
            }
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            // Mesh loading
            commands::mesh::load_obj,
            commands::mesh::load_obj_from_bytes,
            // Unfolding
            commands::unfold::unfold_mesh,
            commands::unfold::get_face_adjacency,
            // Export
            commands::export::export_svg,
            commands::export::export_pdf,
            // Project persistence
            commands::project::save_project,
            commands::project::load_project,
            // Settings
            commands::settings::load_settings,
            commands::settings::save_settings,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
