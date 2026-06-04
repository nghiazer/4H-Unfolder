/// Simple row-based strip-packing of unfolded pieces onto a sheet.
/// Used by `commands/unfold.rs` as a post-process step.
use crate::models::unfold::{PieceLayout, Point2, UnfoldedFace};
use std::collections::HashMap;

/// Arrange `layouts` left-to-right, wrapping when the row width exceeds
/// `sheet_width_mm`.  Updates each layout's `offset` in-place.
///
/// `faces` is needed to compute each piece's bounding box.
pub fn auto_arrange(
    faces:          &[UnfoldedFace],
    layouts:        &mut Vec<PieceLayout>,
    sheet_width_mm: f64,
    margin_mm:      f64,
) {
    // Build per-piece bounding boxes from the unfolded face vertices.
    let mut bounds: HashMap<usize, [f64; 4]> = HashMap::new();
    for face in faces {
        let b = bounds.entry(face.piece_id).or_insert([
            f64::INFINITY, f64::INFINITY, f64::NEG_INFINITY, f64::NEG_INFINITY,
        ]);
        for v in [face.v0, face.v1, face.v2] {
            if v.x < b[0] { b[0] = v.x; }
            if v.y < b[1] { b[1] = v.y; }
            if v.x > b[2] { b[2] = v.x; }
            if v.y > b[3] { b[3] = v.y; }
        }
    }

    let mut cursor_x = margin_mm;
    let mut cursor_y = margin_mm;
    let mut row_h    = 0.0_f64;

    for layout in layouts.iter_mut() {
        let b = match bounds.get(&layout.piece_id) {
            Some(b) => *b,
            None    => continue,
        };
        let pw = b[2] - b[0];
        let ph = b[3] - b[1];

        if cursor_x + pw + margin_mm > sheet_width_mm && cursor_x > margin_mm {
            cursor_x  = margin_mm;
            cursor_y += row_h + margin_mm;
            row_h     = 0.0;
        }

        layout.offset = Point2::new(cursor_x - b[0], cursor_y - b[1]);
        cursor_x += pw + margin_mm;
        row_h     = row_h.max(ph);
    }
}
