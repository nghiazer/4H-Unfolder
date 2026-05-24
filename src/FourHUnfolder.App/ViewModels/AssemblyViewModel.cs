using System.Windows.Media;
using System.Windows.Media.Media3D;
using System.Windows.Threading;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using FourHUnfolder.Domain.Models;
using FourHUnfolder.Domain.Results;
using FourHUnfolder.Geometry.Algorithms;

namespace FourHUnfolder.App.ViewModels;

/// <summary>
/// ViewModel for the Assembly Animation window.
///
/// Approach A — "flat → 3D":
///   • All pieces start laid flat on a horizontal plane below the model,
///     positioned according to the 2-D unfolded layout (scaled back to
///     model units).
///   • Each step animates one piece from that flat position to its final
///     3-D mesh position using a smooth-step lerp.
///   • Already-assembled pieces are shown in their final 3-D positions
///     (neutral blue-grey).
///   • The piece currently being assembled is highlighted in amber and
///     transitions from flat to 3-D.
///   • Future pieces are shown as a faint ghost so the user can see the
///     target shape.
/// </summary>
public sealed partial class AssemblyViewModel : ObservableObject, IDisposable
{
    // ── inner types ───────────────────────────────────────────────────────────

    /// Pre-computed per-piece geometry for both the flat and final states.
    private sealed class PieceAnimData
    {
        public required int GroupId    { get; init; }
        public required int StepIndex  { get; init; }

        /// Each entry = one triangle.
        /// (FA,FB,FC) = flat 3-D positions; (TA,TB,TC) = final 3-D positions.
        public required (Point3D FA, Point3D FB, Point3D FC,
                         Point3D TA, Point3D TB, Point3D TC)[] Tris { get; init; }
    }

    private sealed class StepInfo
    {
        public required int StepIndex     { get; init; }
        public required int GroupId       { get; init; }
        public required int ParentGroupId { get; init; }
        public required int FaceCount     { get; init; }
    }

    // ── constants ─────────────────────────────────────────────────────────────
    private const double AnimDurationMs  = 700;   // ms to lerp from flat → 3-D
    private const double PauseDurationMs = 500;   // ms pause between auto-play steps

    // ── fields ────────────────────────────────────────────────────────────────
    private readonly PieceAnimData[] _pieceData;   // one entry per step, indexed by step
    private readonly StepInfo[]      _stepInfos;

    private readonly DispatcherTimer _timer;
    private DateTime _lastTick;
    private double   _animT          = 1.0;        // [0..1] animation progress for current step
    private double   _pauseRemaining = 0;

    // ── observable properties ─────────────────────────────────────────────────
    [ObservableProperty] [NotifyPropertyChangedFor(nameof(StepDescription))]
    [NotifyPropertyChangedFor(nameof(StepCountText))]
    [NotifyPropertyChangedFor(nameof(StepProgress))]
    [NotifyCanExecuteChangedFor(nameof(PrevStepCommand))]
    [NotifyCanExecuteChangedFor(nameof(NextStepCommand))]
    [NotifyCanExecuteChangedFor(nameof(GoToStartCommand))]
    [NotifyCanExecuteChangedFor(nameof(GoToEndCommand))]
    private int _currentStep = 0;

    [ObservableProperty] [NotifyPropertyChangedFor(nameof(PlayPauseLabel))]
    private bool _isPlaying = false;

    [ObservableProperty] private Model3DGroup? _assemblyModel;

    // ── computed properties ───────────────────────────────────────────────────
    public int    StepCount    => _stepInfos.Length;
    public double StepProgress => StepCount > 1 ? (double)CurrentStep / (StepCount - 1) * 100.0 : 100.0;
    public string PlayPauseLabel => IsPlaying ? "⏸ Pause" : "▶ Play";

    public string StepDescription
    {
        get
        {
            if (_stepInfos.Length == 0) return "No steps computed.";
            var s = _stepInfos[CurrentStep];
            return s.ParentGroupId < 0
                ? $"Step {CurrentStep + 1} / {_stepInfos.Length}  —  Place root piece #{s.GroupId} ({s.FaceCount} faces)"
                : $"Step {CurrentStep + 1} / {_stepInfos.Length}  —  Attach piece #{s.GroupId} ({s.FaceCount} faces) onto piece #{s.ParentGroupId}";
        }
    }

    public string StepCountText => $"{CurrentStep + 1} / {_stepInfos.Length}";

    // ── constructor ───────────────────────────────────────────────────────────

    public AssemblyViewModel(
        Mesh                          mesh,
        UnfoldResult                  unfoldResult,
        IReadOnlyList<PieceViewModel> pieces,
        double                        scaleMmPerUnit)
    {
        (_pieceData, _stepInfos) = BuildAssemblyData(mesh, unfoldResult, pieces, scaleMmPerUnit);

        _timer = new DispatcherTimer(DispatcherPriority.Render)
        {
            Interval = TimeSpan.FromMilliseconds(16)   // ≈60 fps
        };
        _timer.Tick += OnTimerTick;

        // Show step 0 fully assembled (flat position visible immediately)
        if (_stepInfos.Length > 0)
        {
            _animT = 0.0;
            RefreshModel();
        }
    }

    // ── commands ──────────────────────────────────────────────────────────────

    private bool CanGoBack()    => CurrentStep > 0;
    private bool CanGoForward() => CurrentStep < _stepInfos.Length - 1;

    [RelayCommand(CanExecute = nameof(CanGoBack))]
    private void GoToStart()
    {
        StopAnimation();
        CurrentStep = 0;
        _animT = 0.0;
        RefreshModel();
    }

    [RelayCommand(CanExecute = nameof(CanGoBack))]
    private void PrevStep()
    {
        StopAnimation();
        if (CurrentStep > 0) CurrentStep--;
        _animT = 1.0;
        RefreshModel();
    }

    [RelayCommand(CanExecute = nameof(CanGoForward))]
    private void NextStep()
    {
        StopAnimation();
        if (CurrentStep < _stepInfos.Length - 1) CurrentStep++;
        _animT = 0.0;
        RefreshModel();
    }

    [RelayCommand(CanExecute = nameof(CanGoForward))]
    private void GoToEnd()
    {
        StopAnimation();
        CurrentStep = _stepInfos.Length - 1;
        _animT = 1.0;
        RefreshModel();
    }

    [RelayCommand]
    private void PlayPause()
    {
        if (IsPlaying) StopAnimation();
        else           StartAnimation();
    }

    // ── animation loop ────────────────────────────────────────────────────────

    private void StartAnimation()
    {
        // If already at end, restart from beginning
        if (CurrentStep >= _stepInfos.Length - 1 && _animT >= 1.0)
        {
            CurrentStep = 0;
            _animT = 0.0;
        }

        IsPlaying        = true;
        _pauseRemaining  = 0;
        _lastTick        = DateTime.Now;
        _timer.Start();
    }

    private void StopAnimation()
    {
        IsPlaying = false;
        _timer.Stop();
    }

    private void OnTimerTick(object? sender, EventArgs e)
    {
        var now = DateTime.Now;
        double dtMs = (now - _lastTick).TotalMilliseconds;
        _lastTick = now;

        if (_pauseRemaining > 0)
        {
            _pauseRemaining -= dtMs;
            return;
        }

        _animT += dtMs / AnimDurationMs;

        if (_animT >= 1.0)
        {
            _animT = 1.0;
            RefreshModel();

            if (CurrentStep < _stepInfos.Length - 1)
            {
                _pauseRemaining = PauseDurationMs;
                CurrentStep++;
                _animT = 0.0;
            }
            else
            {
                // Reached the end — stop
                StopAnimation();
            }
            return;
        }

        RefreshModel();
    }

    // ── model building ────────────────────────────────────────────────────────

    private void RefreshModel()
    {
        OnPropertyChanged(nameof(StepDescription));
        OnPropertyChanged(nameof(StepCountText));
        OnPropertyChanged(nameof(StepProgress));
        AssemblyModel = BuildFrame(CurrentStep, SmoothStep(_animT));
    }

    /// <summary>
    /// Builds the 3-D Model3DGroup for the given step and animation progress t ∈ [0,1].
    /// </summary>
    private Model3DGroup BuildFrame(int stepIdx, double t)
    {
        var group = new Model3DGroup();

        for (int i = 0; i < _pieceData.Length; i++)
        {
            var pd = _pieceData[i];
            if (pd.Tris.Length == 0) continue;

            // Determine role of this piece at the current step
            Color  faceColor;
            Color  backColor;
            bool   doLerp;

            if (pd.StepIndex < stepIdx)
            {
                // Already assembled — neutral blue-grey, fully final position
                faceColor = Color.FromArgb(220, 0x80, 0x98, 0xc8);
                backColor = Color.FromArgb(200, 0x40, 0x50, 0x78);
                doLerp    = false;
            }
            else if (pd.StepIndex == stepIdx)
            {
                // Currently being assembled — amber highlight, lerped flat→3D
                faceColor = Color.FromArgb(255, 0xff, 0xcc, 0x30);
                backColor = Color.FromArgb(255, 0xcc, 0x88, 0x10);
                doLerp    = true;
            }
            else
            {
                // Future piece — ghost (very faint white wireframe-like)
                faceColor = Color.FromArgb(30, 0xcc, 0xdd, 0xff);
                backColor = Color.FromArgb(20, 0x88, 0x99, 0xcc);
                doLerp    = false;
            }

            var positions = new Point3DCollection(pd.Tris.Length * 3);
            var indices   = new Int32Collection(pd.Tris.Length * 3);
            var normals   = new Vector3DCollection(pd.Tris.Length * 3);
            int idx = 0;

            foreach (var (fa, fb, fc, ta, tb, tc) in pd.Tris)
            {
                var pa = doLerp ? Lerp(fa, ta, t) : ta;
                var pb = doLerp ? Lerp(fb, tb, t) : tb;
                var pc = doLerp ? Lerp(fc, tc, t) : tc;

                positions.Add(pa);
                positions.Add(pb);
                positions.Add(pc);
                indices.Add(idx); indices.Add(idx + 1); indices.Add(idx + 2);

                var ab = new Vector3D(pb.X - pa.X, pb.Y - pa.Y, pb.Z - pa.Z);
                var ac = new Vector3D(pc.X - pa.X, pc.Y - pa.Y, pc.Z - pa.Z);
                var n  = Vector3D.CrossProduct(ab, ac);
                if (n.Length > 1e-12) n.Normalize();
                normals.Add(n); normals.Add(n); normals.Add(n);

                idx += 3;
            }

            var geo   = new MeshGeometry3D { Positions = positions, TriangleIndices = indices, Normals = normals };
            var mat   = new DiffuseMaterial(new SolidColorBrush(faceColor));
            var back  = new DiffuseMaterial(new SolidColorBrush(backColor));
            var model = new GeometryModel3D(geo, mat) { BackMaterial = back };
            group.Children.Add(model);
        }

        return group;
    }

    // ── static helpers ────────────────────────────────────────────────────────

    private static double SmoothStep(double t)
    {
        t = Math.Clamp(t, 0.0, 1.0);
        return t * t * (3.0 - 2.0 * t);
    }

    private static Point3D Lerp(Point3D from, Point3D to, double t) =>
        new(from.X + (to.X - from.X) * t,
            from.Y + (to.Y - from.Y) * t,
            from.Z + (to.Z - from.Z) * t);

    // ── assembly data builder ─────────────────────────────────────────────────

    private static (PieceAnimData[], StepInfo[]) BuildAssemblyData(
        Mesh                          mesh,
        UnfoldResult                  unfoldResult,
        IReadOnlyList<PieceViewModel> pieces,
        double                        scaleMmPerUnit)
    {
        if (pieces.Count == 0 || scaleMmPerUnit <= 0)
            return ([], []);

        // ── 1. Build assembly step order via AssemblyPlanner ──────────────────
        var pieceGroups = pieces
            .Select(p => (p.GroupId, p.Faces.Select(f => f.FaceId).ToArray()))
            .ToArray();

        var steps = AssemblyPlanner.Build(mesh, pieceGroups);
        if (steps.Count == 0) return ([], []);

        // ── 2. Build faceId → UnfoldedFace lookup ─────────────────────────────
        var unfoldMap = unfoldResult.Faces.ToDictionary(f => f.FaceId);

        // ── 3. Compute flat-plane parameters ──────────────────────────────────
        //   Flat positions are the 2-D unfolded coords scaled back to model units
        //   and placed on a horizontal plane below the 3-D model.

        float modelMinY  = mesh.Vertices.Count > 0 ? mesh.Vertices.Min(v => v.Position.Y) : 0f;
        float modelMaxY  = mesh.Vertices.Count > 0 ? mesh.Vertices.Max(v => v.Position.Y) : 1f;
        float modelCx    = mesh.Vertices.Count > 0 ? mesh.Vertices.Average(v => v.Position.X) : 0f;
        float modelCz    = mesh.Vertices.Count > 0 ? mesh.Vertices.Average(v => v.Position.Z) : 0f;
        float modelH     = Math.Max(modelMaxY - modelMinY, 0.001f);
        float baseY      = modelMinY - modelH * 0.7f;   // flat plane well below the model

        // Pattern centroid in model units (to centre the flat layout under the model)
        double sumX = 0, sumZ = 0;
        int    vtxN = 0;
        foreach (var uf in unfoldResult.Faces)
        {
            sumX += uf.V0.X + uf.V1.X + uf.V2.X;
            sumZ += uf.V0.Y + uf.V1.Y + uf.V2.Y;
            vtxN += 3;
        }
        double patCx = vtxN > 0 ? sumX / vtxN / scaleMmPerUnit : 0;
        double patCz = vtxN > 0 ? sumZ / vtxN / scaleMmPerUnit : 0;

        // Helper: 2-D unfolded coords → 3-D flat position
        Point3D ToFlat(float u, float v) => new(
            u / scaleMmPerUnit - patCx + modelCx,
            baseY,
            v / scaleMmPerUnit - patCz + modelCz);

        // ── 4. Build PieceAnimData and StepInfo for every step ────────────────
        var groupToStep = steps.ToDictionary(s => s.GroupId, s => s.StepIndex);

        var pieceDataList = new List<PieceAnimData>(steps.Count);
        var stepInfoList  = new List<StepInfo>(steps.Count);

        foreach (var step in steps)
        {
            var triList = new List<(Point3D, Point3D, Point3D, Point3D, Point3D, Point3D)>(
                step.FaceIds.Count);

            foreach (var faceId in step.FaceIds)
            {
                if (faceId < 0 || faceId >= mesh.Faces.Count) continue;
                var mf = mesh.Faces[faceId];

                // Final 3-D vertex positions
                var va3 = mesh.Vertices[mf.A].Position;
                var vb3 = mesh.Vertices[mf.B].Position;
                var vc3 = mesh.Vertices[mf.C].Position;
                var ta  = new Point3D(va3.X, va3.Y, va3.Z);
                var tb  = new Point3D(vb3.X, vb3.Y, vb3.Z);
                var tc  = new Point3D(vc3.X, vc3.Y, vc3.Z);

                // Flat positions from 2-D unfolded layout
                Point3D fa, fb, fc;
                if (unfoldMap.TryGetValue(faceId, out var uf))
                {
                    fa = ToFlat(uf.V0.X, uf.V0.Y);
                    fb = ToFlat(uf.V1.X, uf.V1.Y);
                    fc = ToFlat(uf.V2.X, uf.V2.Y);
                }
                else
                {
                    fa = ta; fb = tb; fc = tc;   // fallback: no flat position
                }

                triList.Add((fa, fb, fc, ta, tb, tc));
            }

            pieceDataList.Add(new PieceAnimData
            {
                GroupId   = step.GroupId,
                StepIndex = step.StepIndex,
                Tris      = [.. triList]
            });

            stepInfoList.Add(new StepInfo
            {
                StepIndex     = step.StepIndex,
                GroupId       = step.GroupId,
                ParentGroupId = step.ParentGroupId,
                FaceCount     = step.FaceIds.Count
            });
        }

        return ([.. pieceDataList], [.. stepInfoList]);
    }

    // ── IDisposable ───────────────────────────────────────────────────────────

    public void Dispose()
    {
        _timer.Stop();
        _timer.Tick -= OnTimerTick;
    }
}
