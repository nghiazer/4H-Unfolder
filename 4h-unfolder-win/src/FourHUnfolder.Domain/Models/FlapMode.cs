namespace FourHUnfolder.Domain.Models;

/// <summary>
/// Per-edge override for glue tab placement, keyed by mesh edge ID in
/// MainViewModel._flapOverrides and ProjectState.FlapOverrides.
/// </summary>
public enum FlapMode
{
    // ── Inner edge (cut edge shared between two faces) ────────────────────
    Default,           // follow global AlternateFlaps logic
    SwitchPosition,    // swap which face currently has the tab
    OnOn_ThisSide,     // tab on the face the user designated as "this side"
    OffOn_OtherSide,   // tab on the partner face only (suppress this face)
    OffOff_NoFlap,     // no tab on either side of this edge
    OnOn_BothSides,    // tabs on both faces of this cut edge

    // ── Border edge (mesh boundary — no adjacent face) ────────────────────
    Border_MountainFold,    // add tab with mountain fold annotation
    Border_ValleyFold,      // add tab with valley fold annotation
    Border_NoFold,          // add tab without fold annotation
    Border_NoFlap           // explicit no-tab (same as Default for border edges)
}
