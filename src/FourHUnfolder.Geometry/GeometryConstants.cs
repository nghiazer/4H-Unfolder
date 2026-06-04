namespace FourHUnfolder.Geometry;

/// <summary>
/// Centralised floating-point tolerances for geometry algorithms.
/// All values are in model units (before mm scaling) unless noted.
///
/// Threshold rationale (assuming typical mm-scale models, 1 unit ≈ 1 mm):
///   DegenerateEdge  1e-6 ≈ 1 nm  — vertices within 1 nm are physically coincident
///   DegenerateFace  1e-10          — face normal near-zero → collapsed triangle; skip in graph
///   DegenerateTab   1e-4 ≈ 0.1 mm  — tab edge shorter than line width; not printable
///   SatTouchEpsilon 1e-5           — adjacent unfolded faces share an edge and project
///                                    to within float rounding; treat as non-overlapping
/// </summary>
internal static class GeometryConstants
{
    /// Vertices closer than 1e-6 model units apart are considered coincident.
    internal const float DegenerateEdge = 1e-6f;

    /// Face normal magnitude below 1e-10 indicates a collapsed (zero-area) triangle;
    /// such faces are excluded from the dual graph to prevent division by zero.
    internal const float DegenerateFace = 1e-10f;

    /// Glue-tab base edge shorter than 1e-4 model units produces an invisible tab;
    /// skip generation to avoid degenerate polygon output.
    internal const float DegenerateTab = 1e-4f;

    /// SAT projection gap below this value (scaled by edge length) means the triangles
    /// are touching along a shared fold edge rather than truly overlapping.
    /// Keeps adjacent unfolded faces from being falsely reported as overlapping.
    internal const float SatTouchEpsilon = 1e-5f;
}
