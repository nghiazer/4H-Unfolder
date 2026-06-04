/// SVG + PDF export — Phase 5.1 / 5.2
///
/// SVG: edge-dedup via sorted-endpoint HashSet, multi-page via viewBox crop
/// PDF: pure-Rust minimal PDF 1.4 writer (no external crate)
use crate::models::unfold::{GlueTab, UnfoldResponse, UnfoldedFace};
use serde::Deserialize;
use std::collections::HashSet;
use tauri::command;

// ---------------------------------------------------------------------------
// Options (mirrors TypeScript ExportOpts)
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Tauri commands
// ---------------------------------------------------------------------------

#[command]
pub async fn export_svg(response: UnfoldResponse, opts: ExportOptions) -> Result<(), String> {
    render_svg_multipage(&response, &opts)
}

#[command]
pub async fn export_pdf(response: UnfoldResponse, opts: ExportOptions) -> Result<(), String> {
    render_pdf_multipage(&response, &opts)
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

/// Edge-dedup set: sorted (x1,y1,x2,y2) endpoints rounded to 1-μm.
type EdgeSet = HashSet<(i64, i64, i64, i64)>;

fn edge_key(x1: f64, y1: f64, x2: f64, y2: f64) -> (i64, i64, i64, i64) {
    let a = ((x1 * 1000.0).round() as i64, (y1 * 1000.0).round() as i64);
    let b = ((x2 * 1000.0).round() as i64, (y2 * 1000.0).round() as i64);
    if a <= b { (a.0, a.1, b.0, b.1) } else { (b.0, b.1, a.0, a.1) }
}

/// Parse "#rrggbb" → (r, g, b) in 0.0–1.0 range.
fn hex_to_rgb01(hex: &str) -> (f64, f64, f64) {
    let hex = hex.trim_start_matches('#');
    if hex.len() < 6 { return (0.0, 0.0, 0.0); }
    let r = u8::from_str_radix(&hex[0..2], 16).unwrap_or(0) as f64 / 255.0;
    let g = u8::from_str_radix(&hex[2..4], 16).unwrap_or(0) as f64 / 255.0;
    let b = u8::from_str_radix(&hex[4..6], 16).unwrap_or(0) as f64 / 255.0;
    (r, g, b)
}

/// Compute the output file path for one page of a multi-page export.
fn page_path(base: &str, r: u32, c: u32, pages_tall: u32, pages_wide: u32) -> String {
    if pages_tall == 1 && pages_wide == 1 { return base.to_string(); }
    let p    = std::path::Path::new(base);
    let stem = p.file_stem().and_then(|s| s.to_str()).unwrap_or("pattern");
    let ext  = p.extension().and_then(|s| s.to_str()).unwrap_or("svg");
    let dir  = p.parent().and_then(|d| d.to_str()).unwrap_or(".");
    format!("{}/{}_p{}_{}.{}", dir, stem, r, c, ext)
}

// ---------------------------------------------------------------------------
// SVG helpers
// ---------------------------------------------------------------------------

/// Build the full SVG body for one page viewport `(vx, vy, pw, ph)` (all in mm).
fn svg_page_body(
    resp:   &UnfoldResponse,
    opts:   &ExportOptions,
    vx:     f64,
    vy:     f64,
    pw:     f64,
    ph:     f64,
) -> String {
    let sf     = opts.scale_factor;
    let result = &resp.unfold_result;
    let mut out = String::new();
    let mut edge_set = EdgeSet::new();

    // Paper background
    out.push_str(&format!(
        "<rect x=\"{vx:.3}\" y=\"{vy:.3}\" width=\"{pw:.3}\" height=\"{ph:.3}\" \
         fill=\"white\" stroke=\"#cccccc\" stroke-width=\"0.3\"/>"
    ));

    // Optional page label
    if opts.include_page_label {
        out.push_str(&format!(
            "<text x=\"{:.3}\" y=\"{:.3}\" font-size=\"3\" fill=\"#aaa\" \
             font-family=\"sans-serif\">p{},{}</text>",
            vx + 2.0, vy + 5.0, vy as u32 / ph as u32 + 1, vx as u32 / pw as u32 + 1
        ));
    }

    let face_fill = if opts.grayscale_output { "#e8e8e8" } else { "#fffde7" };

    for layout in &resp.piece_layouts {
        let ox = layout.offset.x * sf;
        let oy = layout.offset.y * sf;

        let piece_faces: Vec<&UnfoldedFace> = result.faces.iter()
            .filter(|f| f.piece_id == layout.piece_id)
            .collect();

        // 1. Face fill polygons
        for face in &piece_faces {
            let pts = format!(
                "{:.3},{:.3} {:.3},{:.3} {:.3},{:.3}",
                face.v0.x * sf + ox, face.v0.y * sf + oy,
                face.v1.x * sf + ox, face.v1.y * sf + oy,
                face.v2.x * sf + ox, face.v2.y * sf + oy,
            );
            out.push_str(&format!(
                "<polygon points=\"{pts}\" fill=\"{face_fill}\" stroke=\"none\"/>"
            ));
        }

        // 2. Per-edge lines (deduped)
        for face in &piece_faces {
            let verts = [face.v0, face.v1, face.v2];
            for i in 0..3usize {
                let p0 = verts[i];
                let p1 = verts[(i + 1) % 3];

                let ax1 = p0.x * sf + ox;
                let ay1 = p0.y * sf + oy;
                let ax2 = p1.x * sf + ox;
                let ay2 = p1.y * sf + oy;

                let is_fold     = face.edge_is_fold[i];
                let is_boundary = face.edge_is_boundary[i];
                let is_cut      = !is_fold && !is_boundary;

                if is_fold || is_boundary {
                    if !edge_set.insert(edge_key(ax1, ay1, ax2, ay2)) { continue; }
                }
                if is_fold     && !opts.show_fold_lines { continue; }
                if is_boundary && !opts.show_boundary   { continue; }
                if is_cut      && !opts.show_cut_lines  { continue; }

                let (color, width, dash_attr): (&str, f64, String) = if is_fold {
                    let d = format!(" stroke-dasharray=\"{}\"", opts.fold_line_dash);
                    (&opts.fold_line_color, opts.fold_line_width, d)
                } else if is_boundary {
                    ("#505050", 0.4, String::new())
                } else {
                    (&opts.cut_line_color, opts.cut_line_width, String::new())
                };

                out.push_str(&format!(
                    "<line x1=\"{ax1:.3}\" y1=\"{ay1:.3}\" x2=\"{ax2:.3}\" y2=\"{ay2:.3}\" \
                     stroke=\"{color}\" stroke-width=\"{width}\"{dash_attr}/>"
                ));

                // Cut-edge pair label
                if is_cut && opts.show_labels {
                    let eid = face.mesh_edge_ids[i];
                    if eid >= 0 {
                        if let Some(&pair) = result.cut_edge_pair_ids.get(&(eid as usize)) {
                            let mx = (ax1 + ax2) * 0.5;
                            let my = (ay1 + ay2) * 0.5;
                            out.push_str(&format!(
                                "<text x=\"{mx:.3}\" y=\"{my:.3}\" font-size=\"1.5\" \
                                 text-anchor=\"middle\" dominant-baseline=\"middle\" \
                                 fill=\"{color}\">{pair}</text>"
                            ));
                        }
                    }
                }
            }
        }

        // 3. Face ID labels
        if opts.show_labels {
            for face in &piece_faces {
                let cx = (face.v0.x + face.v1.x + face.v2.x) / 3.0 * sf + ox;
                let cy = (face.v0.y + face.v1.y + face.v2.y) / 3.0 * sf + oy;
                out.push_str(&format!(
                    "<text x=\"{cx:.3}\" y=\"{cy:.3}\" font-size=\"2\" \
                     text-anchor=\"middle\" dominant-baseline=\"middle\" \
                     fill=\"#555\" font-family=\"sans-serif\">{}</text>",
                    face.face_id
                ));
            }
        }

        // 4. Glue tabs
        if opts.include_glue_tabs {
            let piece_fids: HashSet<usize> =
                piece_faces.iter().map(|f| f.face_id).collect();
            for tab in result.glue_tabs.iter().filter(|t| piece_fids.contains(&t.face_id)) {
                let pts = format!(
                    "{:.3},{:.3} {:.3},{:.3} {:.3},{:.3} {:.3},{:.3}",
                    tab.p0.x * sf + ox, tab.p0.y * sf + oy,
                    tab.p1.x * sf + ox, tab.p1.y * sf + oy,
                    tab.p2.x * sf + ox, tab.p2.y * sf + oy,
                    tab.p3.x * sf + ox, tab.p3.y * sf + oy,
                );
                out.push_str(&format!(
                    "<polygon points=\"{pts}\" \
                     fill=\"rgba(80,200,80,0.4)\" stroke=\"#2e7d32\" stroke-width=\"0.3\"/>"
                ));
            }
        }
    }

    out
}

fn render_svg_multipage(resp: &UnfoldResponse, opts: &ExportOptions) -> Result<(), String> {
    let sf      = opts.scale_factor;
    let total_w = resp.sheet_width_mm  * sf;
    let total_h = resp.sheet_height_mm * sf;
    let pw      = total_w / opts.pages_wide  as f64;
    let ph      = total_h / opts.pages_tall as f64;

    for pr in 0..opts.pages_tall {
        for pc in 0..opts.pages_wide {
            let vx = pc as f64 * pw;
            let vy = pr as f64 * ph;

            let body = svg_page_body(resp, opts, vx, vy, pw, ph);
            let svg  = format!(
                "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
                 <svg xmlns=\"http://www.w3.org/2000/svg\" \
                 viewBox=\"{vx:.3} {vy:.3} {pw:.3} {ph:.3}\" \
                 width=\"{pw:.3}mm\" height=\"{ph:.3}mm\">\n\
                 {body}\n</svg>"
            );
            let path = page_path(&opts.output_path, pr, pc, opts.pages_tall, opts.pages_wide);
            std::fs::write(&path, svg).map_err(|e| e.to_string())?;
        }
    }
    Ok(())
}

// ---------------------------------------------------------------------------
// Pure-Rust minimal PDF 1.4 writer (no external crate)
// ---------------------------------------------------------------------------

const PTS_PER_MM: f64 = 72.0 / 25.4; // 2.8346 pts/mm

/// Build the PDF content stream for one page viewport.
/// Coordinates are converted from mm (top-left origin) to pts (bottom-left origin).
fn pdf_content_stream(
    resp:   &UnfoldResponse,
    opts:   &ExportOptions,
    vx_mm:  f64,  // page viewport X offset in mm
    vy_mm:  f64,  // page viewport Y offset in mm
    pw_mm:  f64,  // page width in mm
    ph_mm:  f64,  // page height in mm
) -> Vec<u8> {
    let sf      = opts.scale_factor;
    let result  = &resp.unfold_result;
    let mut out = String::new();
    let mut edge_set = EdgeSet::new();

    // Coordinate helpers
    let px = |x_mm: f64| (x_mm - vx_mm) * PTS_PER_MM;
    let py = |y_mm: f64| (ph_mm - (y_mm - vy_mm)) * PTS_PER_MM; // Y-flip

    // White background
    out.push_str("q\n1 1 1 rg\n");
    out.push_str(&format!("0 0 {:.3} {:.3} re f\nQ\n", pw_mm * PTS_PER_MM, ph_mm * PTS_PER_MM));

    let face_fill_op = if opts.grayscale_output {
        "0.910 0.910 0.910 rg\n"
    } else {
        "1.000 0.992 0.906 rg\n" // #fffde7
    };

    for layout in &resp.piece_layouts {
        let ox = layout.offset.x * sf;
        let oy = layout.offset.y * sf;

        let piece_faces: Vec<&UnfoldedFace> = result.faces.iter()
            .filter(|f| f.piece_id == layout.piece_id)
            .collect();

        // Face fills
        out.push_str("q\n0 w\n");
        out.push_str(face_fill_op);
        for face in &piece_faces {
            let verts = [face.v0, face.v1, face.v2];
            out.push_str(&format!(
                "{:.3} {:.3} m {:.3} {:.3} l {:.3} {:.3} l h f\n",
                px(verts[0].x * sf + ox), py(verts[0].y * sf + oy),
                px(verts[1].x * sf + ox), py(verts[1].y * sf + oy),
                px(verts[2].x * sf + ox), py(verts[2].y * sf + oy),
            ));
        }
        out.push_str("Q\n");

        // Edges
        for face in &piece_faces {
            let verts = [face.v0, face.v1, face.v2];
            for i in 0..3usize {
                let p0 = verts[i];
                let p1 = verts[(i + 1) % 3];
                let ax1 = p0.x * sf + ox; let ay1 = p0.y * sf + oy;
                let ax2 = p1.x * sf + ox; let ay2 = p1.y * sf + oy;

                let is_fold     = face.edge_is_fold[i];
                let is_boundary = face.edge_is_boundary[i];
                let is_cut      = !is_fold && !is_boundary;

                if is_fold || is_boundary {
                    if !edge_set.insert(edge_key(ax1, ay1, ax2, ay2)) { continue; }
                }
                if is_fold     && !opts.show_fold_lines { continue; }
                if is_boundary && !opts.show_boundary   { continue; }
                if is_cut      && !opts.show_cut_lines  { continue; }

                let (hex, lw): (&str, f64) = if is_fold {
                    (&opts.fold_line_color, opts.fold_line_width)
                } else if is_boundary {
                    ("#505050", 0.4)
                } else {
                    (&opts.cut_line_color, opts.cut_line_width)
                };

                let (r, g, b) = hex_to_rgb01(hex);
                out.push_str("q\n");
                out.push_str(&format!("{r:.3} {g:.3} {b:.3} RG\n"));
                out.push_str(&format!("{:.3} w\n", lw * PTS_PER_MM));
                if is_fold {
                    out.push_str(&pdf_dash_op(&opts.fold_line_dash));
                } else {
                    out.push_str("[] 0 d\n");
                }
                out.push_str(&format!(
                    "{:.3} {:.3} m {:.3} {:.3} l S\nQ\n",
                    px(ax1), py(ay1), px(ax2), py(ay2)
                ));
            }
        }

        // Glue tabs
        if opts.include_glue_tabs {
            let piece_fids: HashSet<usize> =
                piece_faces.iter().map(|f| f.face_id).collect();
            out.push_str("q\n[] 0 d\n0.314 0.784 0.314 rg\n0.180 0.490 0.196 RG\n");
            out.push_str(&format!("{:.3} w\n", 0.3 * PTS_PER_MM));
            for tab in result.glue_tabs.iter().filter(|t| piece_fids.contains(&t.face_id)) {
                let corners = [tab.p0, tab.p1, tab.p2, tab.p3];
                out.push_str(&format!(
                    "{:.3} {:.3} m\n",
                    px(corners[0].x * sf + ox), py(corners[0].y * sf + oy)
                ));
                for c in &corners[1..] {
                    out.push_str(&format!(
                        "{:.3} {:.3} l\n",
                        px(c.x * sf + ox), py(c.y * sf + oy)
                    ));
                }
                out.push_str("h B\n");
            }
            out.push_str("Q\n");
        }
    }

    out.into_bytes()
}

/// Format a dash string "d,g" (mm) as a PDF content stream dash operator.
fn pdf_dash_op(dash: &str) -> String {
    let parts: Vec<f64> = dash.split(',')
        .filter_map(|s| s.trim().parse().ok())
        .collect();
    match parts.as_slice() {
        [d, g] => format!("[{:.2} {:.2}] 0 d\n", d * PTS_PER_MM, g * PTS_PER_MM),
        [d]    => format!("[{:.2}] 0 d\n", d * PTS_PER_MM),
        _      => "[] 0 d\n".to_string(),
    }
}

/// Build a minimal valid PDF 1.4 document from a single content stream.
fn build_minimal_pdf(pw_mm: f64, ph_mm: f64, content: &[u8]) -> Vec<u8> {
    let pw = pw_mm * PTS_PER_MM;
    let ph = ph_mm * PTS_PER_MM;

    let mut buf: Vec<u8> = Vec::new();
    let push = |buf: &mut Vec<u8>, s: &str| buf.extend_from_slice(s.as_bytes());

    push(&mut buf, "%PDF-1.4\n");

    let off1 = buf.len();
    push(&mut buf, "1 0 obj\n<</Type /Catalog /Pages 2 0 R>>\nendobj\n");

    let off2 = buf.len();
    push(&mut buf, "2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n");

    let off3 = buf.len();
    let page_obj = format!(
        "3 0 obj\n<</Type /Page /Parent 2 0 R \
         /MediaBox [0 0 {pw:.3} {ph:.3}] \
         /Contents 4 0 R /Resources <<>>>>\nendobj\n"
    );
    push(&mut buf, &page_obj);

    let off4 = buf.len();
    let stream_header = format!("4 0 obj\n<</Length {}>>\nstream\n", content.len());
    push(&mut buf, &stream_header);
    buf.extend_from_slice(content);
    push(&mut buf, "\nendstream\nendobj\n");

    let xref_start = buf.len();
    let xref = format!(
        "xref\n0 5\n\
         0000000000 65535 f \n\
         {:010} 00000 n \n\
         {:010} 00000 n \n\
         {:010} 00000 n \n\
         {:010} 00000 n \n",
        off1, off2, off3, off4
    );
    push(&mut buf, &xref);
    let trailer = format!(
        "trailer\n<</Size 5 /Root 1 0 R>>\nstartxref\n{xref_start}\n%%EOF\n"
    );
    push(&mut buf, &trailer);

    buf
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    // edge_key ----------------------------------------------------------------

    #[test]
    fn edge_key_is_symmetric() {
        let k1 = edge_key(1.5, 2.0, 3.0, 4.5);
        let k2 = edge_key(3.0, 4.5, 1.5, 2.0);
        assert_eq!(k1, k2, "edge_key must be symmetric");
    }

    #[test]
    fn edge_key_dedup_with_hashset() {
        let mut set = EdgeSet::new();
        set.insert(edge_key(0.0, 0.0, 1.0, 0.0));
        let inserted = set.insert(edge_key(1.0, 0.0, 0.0, 0.0));
        assert!(!inserted, "reverse endpoint should be deduplicated");
        assert_eq!(set.len(), 1);
    }

    #[test]
    fn edge_key_rounds_to_1_micrometer() {
        // Difference of 0.0000001 mm (0.1 μm) should round to same key
        let k1 = edge_key(1.0000001, 0.0, 2.0, 0.0);
        let k2 = edge_key(1.0,       0.0, 2.0, 0.0);
        assert_eq!(k1, k2, "sub-micrometer difference should be rounded away");
    }

    // page_path ---------------------------------------------------------------

    #[test]
    fn page_path_single_page_returns_base() {
        let p = page_path("/out/pattern.svg", 0, 0, 1, 1);
        assert_eq!(p, "/out/pattern.svg");
    }

    #[test]
    fn page_path_multipage_adds_row_col_suffix() {
        let p = page_path("/out/pattern.svg", 1, 2, 3, 4);
        assert_eq!(p, "/out/pattern_p1_2.svg");
    }

    #[test]
    fn page_path_pdf_extension_preserved() {
        let p = page_path("/tmp/export.pdf", 0, 1, 2, 2);
        assert_eq!(p, "/tmp/export_p0_1.pdf");
    }

    #[test]
    fn page_path_row_zero_col_zero_no_suffix_for_1x1() {
        // 1×1 grid → no suffix regardless of r,c
        assert_eq!(page_path("/a/b.svg", 0, 0, 1, 1), "/a/b.svg");
    }

    // pdf_dash_op -------------------------------------------------------------

    #[test]
    fn pdf_dash_op_two_values() {
        let op = pdf_dash_op("4,2");
        assert!(op.starts_with('['), "should start with '['");
        assert!(op.ends_with("] 0 d\n"), "should end with '] 0 d\\n'");
    }

    #[test]
    fn pdf_dash_op_empty_produces_solid() {
        let op = pdf_dash_op("");
        assert_eq!(op, "[] 0 d\n", "empty dash string → solid");
    }

    #[test]
    fn pdf_dash_op_single_value() {
        let op = pdf_dash_op("5");
        assert!(op.contains('[') && op.ends_with("] 0 d\n"));
    }

    // hex_to_rgb01 ------------------------------------------------------------

    #[test]
    fn hex_white_is_all_ones() {
        let (r, g, b) = hex_to_rgb01("#ffffff");
        assert!((r - 1.0).abs() < 1e-6);
        assert!((g - 1.0).abs() < 1e-6);
        assert!((b - 1.0).abs() < 1e-6);
    }

    #[test]
    fn hex_black_is_all_zeros() {
        let (r, g, b) = hex_to_rgb01("#000000");
        assert_eq!((r, g, b), (0.0, 0.0, 0.0));
    }

    #[test]
    fn hex_red_channel_only() {
        let (r, g, b) = hex_to_rgb01("#ff0000");
        assert!((r - 1.0).abs() < 1e-6);
        assert_eq!((g, b), (0.0, 0.0));
    }
}

fn render_pdf_multipage(resp: &UnfoldResponse, opts: &ExportOptions) -> Result<(), String> {
    let sf      = opts.scale_factor;
    let total_w = resp.sheet_width_mm  * sf;
    let total_h = resp.sheet_height_mm * sf;
    let pw_mm   = total_w / opts.pages_wide  as f64;
    let ph_mm   = total_h / opts.pages_tall as f64;

    for pr in 0..opts.pages_tall {
        for pc in 0..opts.pages_wide {
            let vx = pc as f64 * pw_mm;
            let vy = pr as f64 * ph_mm;

            let content = pdf_content_stream(resp, opts, vx, vy, pw_mm, ph_mm);
            let pdf     = build_minimal_pdf(pw_mm, ph_mm, &content);

            let path = page_path(&opts.output_path, pr, pc, opts.pages_tall, opts.pages_wide);
            std::fs::write(&path, &pdf).map_err(|e| e.to_string())?;
        }
    }
    Ok(())
}
