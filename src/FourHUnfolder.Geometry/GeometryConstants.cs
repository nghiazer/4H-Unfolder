namespace FourHUnfolder.Geometry;

/// <summary>
/// Centralised floating-point tolerances for geometry algorithms.
/// All values are in model units (before mm scaling) unless noted.
/// </summary>
internal static class GeometryConstants
{
    /// Minimum edge length below which an edge is treated as degenerate.
    internal const float DegenerateEdge = 1e-6f;

    /// Minimum triangle area (via normal magnitude) below which a face is skipped in dual-graph.
    internal const float DegenerateFace = 1e-10f;

    /// Minimum glue-tab edge length below which tab generation is skipped.
    internal const float DegenerateTab = 1e-4f;

    /// SAT overlap tolerance: two triangles separated by less than this (in normalised
    /// projection units) are considered touching rather than clearly separated.
    internal const float SatTouchEpsilon = 1e-5f;
}
