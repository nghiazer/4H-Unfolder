use crate::models::settings::AppSettings;
use tauri::command;

fn settings_path() -> std::path::PathBuf {
    let base = dirs::config_dir()
        .unwrap_or_else(|| std::path::PathBuf::from("."));
    base.join("4H-Unfolder").join("settings.json")
}

#[command]
pub async fn load_settings() -> Result<AppSettings, String> {
    let path = settings_path();
    if !path.exists() {
        return Ok(AppSettings::default());
    }
    let bytes = std::fs::read(&path).map_err(|e| e.to_string())?;
    serde_json::from_slice(&bytes).map_err(|e| e.to_string())
}

#[command]
pub async fn save_settings(settings: AppSettings) -> Result<(), String> {
    let path = settings_path();
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).map_err(|e| e.to_string())?;
    }
    let json = serde_json::to_string_pretty(&settings).map_err(|e| e.to_string())?;
    std::fs::write(&path, json).map_err(|e| e.to_string())
}
