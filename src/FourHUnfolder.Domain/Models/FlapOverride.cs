namespace FourHUnfolder.Domain.Models;

/// <summary>
/// Per-mesh-edge override for glue tab placement.
/// Keyed by meshEdgeId in MainViewModel._flapOverrides and ProjectState.FlapOverrides.
/// PrimaryFaceId is the mesh face ID the user designated as "this side" when clicking.
/// Required for OnOn_ThisSide, OffOn_OtherSide, and SwitchPosition semantics.
/// </summary>
public sealed record FlapOverride(FlapMode Mode, int PrimaryFaceId = -1)
{
    /// Serialize to string for ProjectState storage: "{Mode},{PrimaryFaceId}"
    public string Serialize() => $"{Mode},{PrimaryFaceId}";

    /// Deserialize from ProjectState string. Returns null on parse failure.
    public static FlapOverride? Deserialize(string s)
    {
        var parts = s.Split(',');
        if (parts.Length < 1) return null;
        if (!Enum.TryParse<FlapMode>(parts[0], out var mode)) return null;
        int primaryFaceId = parts.Length >= 2 && int.TryParse(parts[1], out int pid) ? pid : -1;
        return new FlapOverride(mode, primaryFaceId);
    }
}
