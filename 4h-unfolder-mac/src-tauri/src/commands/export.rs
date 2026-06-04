use crate::models::unfold::{GlueTab, UnfoldResponse, UnfoldedFace};
use serde::Deserialize;
use tauri::command;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ExportOptions {
    pub output_path:        String,
    pub show_fold_lines:    bool,
    pub show_cut_lines:     bool,
    pub show_boundary:      bool,
    pub show_labels:        bool,
    pub include_glue_tabs:  bool,
    pub grayscale_output:   bool,
    pub include_page_label: bool,
    pub dpi:                u32,
    pub fold_line_color:    String,
    pub cut_line_color:     String,
    pub fold_line_width:    f64,
    pub cut_line_width:     f64,
    pub fold_line_dash:     String,
    pub margin_mm:          f64,
    pub scale_factor:       f64,
    pub pages_wide:         u32,
    pub pages_tall:         u32,
}

/// Export the unfolded pattern as SVG.
#[command]
pub async fn export_svg(response: UnfoldResponse, opts: ExportOptions) -> Result<(), String> {
    let content = render_svg(&response, &opts);
    std::fs::write(&opts.output_path, content).map_err(|e| e.to_string())
}

/// Export as PDF (stub — Phase 5 adds `printpdf`).
#[command]
pub async fn export_pdf(response: UnfoldResponse, opts: ExportOptions) -> Result<(), String> {
    let content = render_svg(&response, &opts);
    std::fs::write(&opts.output_path, content).map_err(|e| e.to_string())
}

// ---------------------------------------------------------------------------
// SVG renderer
// ---------------------------------------------------------------------------

fn render_svg(resp: &UnfoldResponse, opts: &ExportOptions) -> String {
    let w  = resp.sheet_width_mm  * opts.scale_factor;
    let h  = resp.sheet_height_mm * opts.scale_factor;
    let sf = opts.scale_factor;

    let mut body = String::new();

    // Paper background.
    body.push_str(&format!(
        "<rect x=\"0\" y=\"0\" width=\"{w:.3}\" height=\"{h:.3}\" fill=\"white\" stroke=\"#cccccc\" stroke-width=\"0.5\"/>"
    ));

    let result = &resp.unfold_result;

    for layout in &resp.piece_layouts {
        let ox = layout.offset.x * sf;
        let oy = layout.offset.y * sf;

        let piece_faces: Vec<&UnfoldedFace> = result.faces.iter()
            .filter(|f| f.piece_id == layout.piece_id)
            .collect();

        for face in &piece_faces {
            let fill = if opts.grayscale_output { "#eeeeee" } else { "#fffde7" };
            body.push_str(&face_polygon(face, ox, oy, sf, fill));

            if opts.show_fold_lines || opts.show_cut_lines || opts.show_boundary {
                body.push_str(&edge_lines(face, ox, oy, sf, opts, result));
            }

            if opts.show_labels {
                let cx = (face.v0.x + face.v1.x + face.v2.x) / 3.0 * sf + ox;
                let cy = (face.v0.y + face.v1.y + face.v2.y) / 3.0 * sf + oy;
                body.push_str(&format!(
                    "<text x=\"{cx:.3}\" y=\"{cy:.3}\" font-size=\"2\" text-anchor=\"middle\" fill=\"#555\">{}</text>",
                    face.face_id
                ));
            }
        }

        if opts.include_glue_tabs {
            let piece_fids: std::collections::HashSet<usize> = piece_faces.iter().map(|f| f.face_id).collect();
            for tab in result.glue_tabs.iter().filter(|t| piece_fids.contains(&t.face_id)) {
                body.push_str(&tab_polygon(tab, ox, oy, sf));
            }
        }
    }

    format!(
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
         <svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 {w:.3} {h:.3}\" width=\"{w:.3}mm\" height=\"{h:.3}mm\">\n\
         {body}\n\
         </svg>"
    )
}

fn face_polygon(face: &UnfoldedFace, ox: f64, oy: f64, sf: f64, fill: &str) -> String {
    let pts = format!(
        "{:.3},{:.3} {:.3},{:.3} {:.3},{:.3}",
        face.v0.x * sf + ox, face.v0.y * sf + oy,
        face.v1.x * sf + ox, face.v1.y * sf + oy,
        face.v2.x * sf + ox, face.v2.y * sf + oy,
    );
    format!("<polygon points=\"{pts}\" fill=\"{fill}\" stroke=\"none\"/>")
}

fn edge_lines(
    face:   &UnfoldedFace,
    ox:     f64,
    oy:     f64,
    sf:     f64,
    opts:   &ExportOptions,
    result: &crate::models::unfold::UnfoldResult,
) -> String {
    let verts = [face.v0, face.v1, face.v2];
    let mut out = String::new();

    for i in 0..3usize {
        let p0 = verts[i];
        let p1 = verts[(i + 1) % 3];

        let (color, width, dash): (&str, f64, Option<&str>) =
            if face.edge_is_fold[i] {
                if !opts.show_fold_lines { continue; }
                (&opts.fold_line_color, opts.fold_line_width, Some(&opts.fold_line_dash))
            } else if face.edge_is_boundary[i] {
                if !opts.show_boundary { continue; }
                ("#505050", 0.4, None)
            } else {
                if !opts.show_cut_lines { continue; }
                let eid = face.mesh_edge_ids[i];
                if eid >= 0 {
                    if let Some(&pair) = result.cut_edge_pair_ids.get(&(eid as usize)) {
                        let mx = (p0.x + p1.x) * 0.5 * sf + ox;
                        let my = (p0.y + p1.y) * 0.5 * sf + oy;
                        out.push_str(&format!(
                            "<text x=\"{mx:.3}\" y=\"{my:.3}\" font-size=\"1.5\" text-anchor=\"middle\" fill=\"{c}\">{pair}</text>",
                            c = opts.cut_line_color,
                        ));
                    }
                }
                (&opts.cut_line_color, opts.cut_line_width, None)
            };

        let x1 = p0.x * sf + ox;
        let y1 = p0.y * sf + oy;
        let x2 = p1.x * sf + ox;
        let y2 = p1.y * sf + oy;

        let dash_attr = dash
            .map(|d| format!(" stroke-dasharray=\"{d}\""))
            .unwrap_or_default();

        out.push_str(&format!(
            "<line x1=\"{x1:.3}\" y1=\"{y1:.3}\" x2=\"{x2:.3}\" y2=\"{y2:.3}\" stroke=\"{color}\" stroke-width=\"{width}\"{dash_attr}/>"
        ));
    }
    out
}

fn tab_polygon(tab: &GlueTab, ox: f64, oy: f64, sf: f64) -> String {
    let pts = format!(
        "{:.3},{:.3} {:.3},{:.3} {:.3},{:.3} {:.3},{:.3}",
        tab.p0.x * sf + ox, tab.p0.y * sf + oy,
        tab.p1.x * sf + ox, tab.p1.y * sf + oy,
        tab.p2.x * sf + ox, tab.p2.y * sf + oy,
        tab.p3.x * sf + ox, tab.p3.y * sf + oy,
    );
    format!("<polygon points=\"{pts}\" fill=\"rgba(80,200,80,0.4)\" stroke=\"#2e7d32\" stroke-width=\"0.3\"/>")
}
