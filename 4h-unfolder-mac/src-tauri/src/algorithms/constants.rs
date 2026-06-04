/// Floating-point thresholds matching C# GeometryConstants.
/// All values assume 1 model unit ≈ 1 mm.

/// Two vertices closer than this are considered coincident.
pub const DEGENERATE_EDGE: f64 = 1e-6;

/// A triangle with normal length below this is degenerate (zero area).
pub const DEGENERATE_FACE: f64 = 1e-10;

/// A glue-tab edge shorter than this is invisible and should be skipped.
pub const DEGENERATE_TAB: f64 = 1e-4;

/// SAT overlap test epsilon — avoids false positives from adjacent fold edges
/// that share an endpoint (they "touch" but don't intersect).
pub const SAT_TOUCH_EPSILON: f64 = 1e-5;
