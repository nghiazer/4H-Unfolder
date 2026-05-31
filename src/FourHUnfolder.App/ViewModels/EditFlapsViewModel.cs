using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using FourHUnfolder.Domain.Models;

namespace FourHUnfolder.App.ViewModels;

/// <summary>
/// ViewModel for the modeless Edit Flaps dialog.
/// Shape(S) tab: edit global tab height/angle.
/// Position(Q) tab: per-edge flap placement applied by clicking edges on the canvas.
/// </summary>
public partial class EditFlapsViewModel : ObservableObject
{
    private readonly MainViewModel _mainVm;

    // ── Mode (tab index: 0 = Shape, 1 = Position) ────────────────────────────
    [ObservableProperty] private int  _activeTabIndex = 0;
    [ObservableProperty] private bool _flapEditActive = false;

    // ── Shape(S) tab ──────────────────────────────────────────────────────────
    [ObservableProperty] private bool   _setHeight  = true;
    [ObservableProperty] private double _heightMm   = 5.0;
    [ObservableProperty] private bool   _setAngle   = false;
    [ObservableProperty] private bool   _angleAuto  = true;
    [ObservableProperty] private double _leftAngle  = 45.0;
    [ObservableProperty] private double _rightAngle = 45.0;

    // ── Position(Q) tab ───────────────────────────────────────────────────────
    [ObservableProperty] private FlapOptionItem _selectedInnerMode;
    [ObservableProperty] private FlapOptionItem _selectedBorderMode;

    public static IReadOnlyList<FlapOptionItem> InnerEdgeOptions { get; } =
    [
        new(FlapMode.SwitchPosition,  "Switch Flap Position"),
        new(FlapMode.OnOn_ThisSide,   "ON-ON (Place Flap on This Side)"),
        new(FlapMode.OffOn_OtherSide, "OFF-ON (Place Flap on the Other Side)"),
        new(FlapMode.OffOff_NoFlap,   "OFF-OFF (No Flap)"),
        new(FlapMode.OnOn_BothSides,  "ON-ON (Place Flaps on Both Sides)"),
        new(FlapMode.Default,         "Do Nothing"),
    ];

    public static IReadOnlyList<FlapOptionItem> BorderEdgeOptions { get; } =
    [
        new(FlapMode.Default,             "Do Nothing"),
        new(FlapMode.Border_MountainFold, "Flap with Mountain Fold"),
        new(FlapMode.Border_ValleyFold,   "Flap with Valley Fold"),
        new(FlapMode.Border_NoFold,       "Flap without Fold"),
        new(FlapMode.Border_NoFlap,       "No Flap"),
    ];

    public EditFlapsViewModel(MainViewModel mainVm)
    {
        _mainVm              = mainVm;
        HeightMm             = mainVm.CurrentPrintSettings.GlueTabDepthMm;
        LeftAngle            = mainVm.CurrentPrintSettings.GlueTabSideAngleDeg;
        RightAngle           = mainVm.CurrentPrintSettings.GlueTabSideAngleDeg;
        SelectedInnerMode    = InnerEdgeOptions[^1];   // "Do Nothing"
        SelectedBorderMode   = BorderEdgeOptions[0];   // "Do Nothing"
    }

    partial void OnActiveTabIndexChanged(int value)
    {
        FlapEditActive = (value == 1);
    }

    /// Called by PatternCanvasControl when an edge is clicked while FlapEditActive.
    public void ApplyToEdge(int meshEdgeId, bool isBoundaryEdge, int faceId)
    {
        FlapMode mode = isBoundaryEdge
            ? SelectedBorderMode.Mode
            : SelectedInnerMode.Mode;

        if (mode == FlapMode.Default)
        {
            _mainVm.SetFlapOverride(meshEdgeId, null);
        }
        else
        {
            _mainVm.SetFlapOverride(meshEdgeId, new FlapOverride(mode, faceId));
        }
    }

    [RelayCommand]
    private void ApplyShapeToAll()
    {
        double depth = SetHeight ? HeightMm  : _mainVm.CurrentPrintSettings.GlueTabDepthMm;
        double angle = SetAngle  ? LeftAngle : _mainVm.CurrentPrintSettings.GlueTabSideAngleDeg;
        _mainVm.ApplyGlobalTabShape(depth, angle);
    }

    [RelayCommand]
    private void ResetToDefault() => _mainVm.ResetAllFlapOverrides();
}

/// Item for ComboBox binding — WPF requires named properties, not value tuples.
public sealed record FlapOptionItem(FlapMode Mode, string Label);
