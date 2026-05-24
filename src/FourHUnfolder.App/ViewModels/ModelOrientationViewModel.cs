using System.Numerics;
using CommunityToolkit.Mvvm.ComponentModel;

namespace FourHUnfolder.App.ViewModels;

/// <summary>
/// Drives the ModelOrientationDialog — lets the user choose which axis of the
/// loaded mesh should point upward (+Y in world space) and which should point
/// toward the camera (+Z in world space), plus an optional UV vertical flip.
/// </summary>
public partial class ModelOrientationViewModel : ObservableObject
{
    // ── available axis options ────────────────────────────────────────────────
    public IReadOnlyList<string> AxisOptions { get; } =
        ["+X", "-X", "+Y", "-Y", "+Z", "-Z"];

    // ── selections ────────────────────────────────────────────────────────────

    /// Which axis of the mesh model should face upward in the world (+Y).
    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(AxesAreParallel))]
    private string _upAxis = "+Y";

    /// Which axis of the mesh model should face forward / toward the camera (+Z).
    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(AxesAreParallel))]
    private string _frontAxis = "+Z";

    /// When true, flip the V component of all UV coords (mirrors texture vertically).
    [ObservableProperty] private bool _flipUV = false;

    // ── computed transform ────────────────────────────────────────────────────

    /// <summary>
    /// Returns the rotation Matrix4x4 (System.Numerics, row-major) that re-orients
    /// the mesh so that the user's chosen up-axis maps to world +Y and the user's
    /// chosen front-axis maps to world +Z.
    /// If up and front are parallel (invalid), returns Identity.
    /// </summary>
    public Matrix4x4 ComputeRotation()
    {
        var up    = ParseAxis(UpAxis);
        var front = ParseAxis(FrontAxis);

        // Reject degenerate input (parallel axes)
        // Right-handed basis: right = up × front  (Y × Z = X for default +Y/+Z)
        var cross = Vector3.Cross(up, front);
        if (cross.LengthSquared() < 1e-6f)
            return Matrix4x4.Identity;

        var right   = Vector3.Normalize(cross);
        var upOrtho = Vector3.Normalize(Vector3.Cross(front, right)); // front × right = upOrtho (Z × X = Y)

        // Rotation R maps model-space to world-space so that:
        //   user's "up"    → world +Y   (via dot(v, upOrtho) = result.Y)
        //   user's "front" → world +Z   (via dot(v, front)   = result.Z)
        //   user's "right" → world +X   (via dot(v, right)   = result.X)
        //
        // Row-major System.Numerics layout (V3.Transform(v, M) = dot products with rows):
        return new Matrix4x4(
            right.X,   upOrtho.X, front.X,  0f,
            right.Y,   upOrtho.Y, front.Y,  0f,
            right.Z,   upOrtho.Z, front.Z,  0f,
            0f,        0f,        0f,        1f);
    }

    /// <summary>True if no orientation change is needed (up=+Y and front=+Z).</summary>
    public bool IsIdentity =>
        UpAxis == "+Y" && FrontAxis == "+Z" && !FlipUV;

    /// <summary>True when Up and Front axes are parallel — invalid configuration.</summary>
    public bool AxesAreParallel
    {
        get
        {
            var u = ParseAxis(UpAxis);
            var f = ParseAxis(FrontAxis);
            return Vector3.Cross(u, f).LengthSquared() < 1e-6f;
        }
    }

    // ── helpers ───────────────────────────────────────────────────────────────

    private static Vector3 ParseAxis(string s) => s switch
    {
        "+X" => new Vector3( 1, 0, 0),
        "-X" => new Vector3(-1, 0, 0),
        "+Y" => new Vector3( 0, 1, 0),
        "-Y" => new Vector3( 0,-1, 0),
        "+Z" => new Vector3( 0, 0, 1),
        "-Z" => new Vector3( 0, 0,-1),
        _    => Vector3.UnitY
    };
}
