use serde::{Deserialize, Serialize};

/// Application settings — mirrors TypeScript `AppSettings` and C# `AppSettings`.
/// Persisted to `~/Library/Application Support/com.fourh.unfolder/settings.json`
/// on macOS.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct AppSettings {
    // Glue-tab defaults
    pub tab_width_mm:    f64,
    pub tab_angle_deg:   f64,
    /// "Trapezoid" | "Rectangle" | "Triangle"
    pub tab_shape:       String,
    pub alternate_flaps: bool,

    // Paper / layout
    pub sheet_width_mm:  f64,
    pub sheet_height_mm: f64,
    pub pages_wide:      u32,
    pub pages_tall:      u32,
    pub auto_arrange:    bool,

    // View 3D display settings
    pub viewport3d_bg:           String,
    pub viewport3d_wireframe:    bool,
    pub viewport3d_face_opacity: f64,

    // View 2D display toggles
    pub show_fold_lines:   bool,
    pub show_cut_lines:    bool,
    pub show_boundary:     bool,
    pub show_face_labels:  bool,
    pub show_glue_tabs:    bool,
    pub show_page_numbers: bool,
    pub show_fold_angles:  bool,

    // Export / print
    pub fold_line_color:   String,
    pub cut_line_color:    String,
    pub fold_line_width:   f64,
    pub cut_line_width:    f64,
    pub fold_line_dash:    String,
    pub margin_mm:         f64,
    pub scale_factor:      f64,
    pub grayscale_output:  bool,
    pub include_page_label: bool,
    pub export_dpi:        u32,

    // General
    /// "light" | "dark" | "system"
    pub theme:             String,
    /// "mm" | "cm" | "inch"
    pub scale_unit:        String,
    pub outline_padding_mm: f64,
}

impl Default for AppSettings {
    fn default() -> Self {
        Self {
            tab_width_mm:     5.0,
            tab_angle_deg:    45.0,
            tab_shape:        "Trapezoid".to_string(),
            alternate_flaps:  false,

            sheet_width_mm:   210.0,
            sheet_height_mm:  297.0,
            pages_wide:       1,
            pages_tall:       1,
            auto_arrange:     true,

            viewport3d_bg:           "#1a1a2e".to_string(),
            viewport3d_wireframe:    false,
            viewport3d_face_opacity: 1.0,

            show_fold_lines:   true,
            show_cut_lines:    true,
            show_boundary:     true,
            show_face_labels:  false,
            show_glue_tabs:    true,
            show_page_numbers: false,
            show_fold_angles:  false,

            fold_line_color:   "#4169e1".to_string(),
            cut_line_color:    "#ff0000".to_string(),
            fold_line_width:   0.5,
            cut_line_width:    0.8,
            fold_line_dash:    "4,2".to_string(),
            margin_mm:         5.0,
            scale_factor:      1.0,
            grayscale_output:  false,
            include_page_label: true,
            export_dpi:        300,

            theme:             "system".to_string(),
            scale_unit:        "mm".to_string(),
            outline_padding_mm: 0.0,
        }
    }
}
