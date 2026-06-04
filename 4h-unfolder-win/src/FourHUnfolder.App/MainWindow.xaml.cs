using System.ComponentModel;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Media.Media3D;
using HelixToolkit.Wpf;
using Microsoft.Extensions.DependencyInjection;
using FourHUnfolder.App.Dialogs;
using FourHUnfolder.App.ViewModels;

namespace FourHUnfolder.App;

public partial class MainWindow : Window
{
    private MainViewModel Vm => (MainViewModel)DataContext;
    private TextureDialog?    _textureDialog;
    private EditFlapsDialog?  _editFlapsDialog;

    // ── Dimension line visuals added to Viewport3D ────────────────────────────
    private readonly List<Visual3D> _dimensionVisuals = new();

    // ── Feature B: 3D edge hover state ────────────────────────────────────────
    private int   _hoveredEdgeId = -1;
    private Point _rmbDownPos;
    private const double HoverThresholdPx = 8.0;

    // TD-25-2: screen-space edge grid for O(1) hover lookup
    private const int GridCellPx = 24;
    private readonly Dictionary<(int, int), List<int>> _edgeScreenGrid = new();
    private bool _edgeGridDirty = true;

    public MainWindow()
    {
        InitializeComponent();
        DataContext = App.Services.GetRequiredService<MainViewModel>();
        Loaded     += OnLoaded;
        Closing    += OnClosing;
        Vm.PropertyChanged        += OnVmPropertyChanged;
        Vm.FitPageRequested        += () => PatternCanvas.FitPageToWindow();
        Vm.ZoomToSelectedRequested += () => PatternCanvas.ZoomToSelected();
        Vm.FindRequested           += () => { FindBar.Visibility = Visibility.Visible; FindTextBox.Focus(); };
        Vm.DimensionLinesChanged   += OnDimensionLinesChanged;
    }

    private void OnClosing(object? sender, System.ComponentModel.CancelEventArgs e)
    {
        if (!Vm.ConfirmDiscardIfDirty("exit"))
            e.Cancel = true;
    }

    // ── startup ───────────────────────────────────────────────────────────────

    private void OnLoaded(object s, RoutedEventArgs e)
    {
        ApplyCameraSettings();
        // TD-25-2: invalidate edge grid whenever the camera moves
        Viewport3D.CameraChanged += (_, _) => _edgeGridDirty = true;
    }

    private void OnVmPropertyChanged(object? s, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(MainViewModel.CameraSettingsVersion))
            ApplyCameraSettings();

        // When mesh changes (new unfold or load), reset hover state + invalidate edge grid
        if (e.PropertyName is nameof(MainViewModel.PiecesVersion)
                           or nameof(MainViewModel.IsUnfolded)
                           or nameof(MainViewModel.CurrentMesh))
        {
            _hoveredEdgeId  = -1;
            _edgeGridDirty  = true;   // TD-25-2

            // Close Edit Flaps dialog when project is reset or mesh is reloaded
            if (e.PropertyName == nameof(MainViewModel.IsUnfolded) && !Vm.IsUnfolded)
            {
                _editFlapsDialog?.Close();
            }
        }
    }

    private void ApplyCameraSettings()
    {
        if (MainCamera3D == null) return;
        MainCamera3D.FieldOfView      = Vm.CameraFOV;
        MainCamera3D.NearPlaneDistance = Vm.CameraNearPlane;
        MainCamera3D.FarPlaneDistance  = Vm.CameraFarPlane;
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  3-D PICKING
    // ══════════════════════════════════════════════════════════════════════════

    private void Viewport3D_MouseDown(object sender, MouseButtonEventArgs e)
    {
        if (e.LeftButton != MouseButtonState.Pressed) return;
        if (!Vm.IsUnfolded) return;
        if (_hoveredEdgeId >= 0) return;  // LMB on edge is handled by PreviewLMBDown

        int faceId = HitTestFace(e.GetPosition(Viewport3D.Viewport));
        if (faceId >= 0)
            Vm.SelectFace3D(faceId);
        else
            Vm.ClearSelection();
        // Do NOT set e.Handled — let HelixToolkit keep orbit control
    }

    // ── Feature B: Left-click on hovered edge = toggle fold/cut ──────────────

    private void Viewport3D_PreviewLMBDown(object sender, MouseButtonEventArgs e)
    {
        if (_hoveredEdgeId < 0) return;
        if (!Vm.IsUnfolded) return;

        Vm.ToggleEdge(_hoveredEdgeId);
        _hoveredEdgeId = -1;       // reset hover (edge type just changed)
        Vm.ClearEdgeHover();
        e.Handled = true;          // prevent orbit from starting
    }

    // ── Feature B: Right-click = set rotation pivot (click, not drag) ────────

    private void Viewport3D_RMBDown(object sender, MouseButtonEventArgs e)
    {
        _rmbDownPos = e.GetPosition(Viewport3D);
        // Do NOT handle — let HelixToolkit start its orbit/pan tracking
    }

    private void Viewport3D_RMBUp(object sender, MouseButtonEventArgs e)
    {
        if (!Vm.IsUnfolded) return;

        var upPos     = e.GetPosition(Viewport3D);
        double drag   = (upPos - _rmbDownPos).Length;
        if (drag >= 4.0) return;   // was a drag, not a click

        // Set camera pivot to the 3D point under the cursor
        var hitPos = e.GetPosition(Viewport3D.Viewport);
        if (Viewport3D.FindNearest(hitPos, out Point3D hitPt, out _, out _))
        {
            Viewport3D.LookAt(hitPt, 300);   // 300 ms animation
            e.Handled = true;
        }
    }

    // ── Feature B: Mouse move = edge hover detection ──────────────────────────

    private void Viewport3D_MouseMove(object sender, MouseEventArgs e)
    {
        if (!Vm.IsUnfolded) return;

        var mousePos  = e.GetPosition(Viewport3D);
        int newHover  = FindNearestEdge(mousePos, HoverThresholdPx);

        if (newHover == _hoveredEdgeId) return;   // unchanged

        _hoveredEdgeId = newHover;
        if (newHover < 0)
            Vm.ClearEdgeHover();
        else
            Vm.HoverEdge(newHover, Vm.IsEdgeFold(newHover));
    }

    /// <summary>
    /// TD-25-2: Builds a screen-space grid that buckets each edge into the
    /// grid cells it passes through.  Called once per camera move or mesh change;
    /// subsequent <see cref="FindNearestEdge"/> calls are O(1) on average.
    /// </summary>
    private void BuildEdgeGrid()
    {
        _edgeScreenGrid.Clear();
        var mesh = Vm.CurrentMesh;
        if (mesh == null) { _edgeGridDirty = false; return; }

        foreach (var edge in mesh.Edges)
        {
            if (!edge.ConnectsFaces) continue;

            var pa      = mesh.Vertices[edge.V1].Position;
            var pb      = mesh.Vertices[edge.V2].Position;
            var screenA = ProjectToScreen(new Point3D(pa.X, pa.Y, pa.Z));
            var screenB = ProjectToScreen(new Point3D(pb.X, pb.Y, pb.Z));
            if (double.IsNaN(screenA.X) || double.IsNaN(screenB.X)) continue;

            // Rasterise the screen segment at half-cell-width steps
            double dx    = screenB.X - screenA.X;
            double dy    = screenB.Y - screenA.Y;
            double len   = Math.Sqrt(dx * dx + dy * dy);
            int    steps = Math.Max(1, (int)(len / (GridCellPx / 2.0)));

            var seen = new HashSet<(int, int)>();
            for (int s = 0; s <= steps; s++)
            {
                double t  = (double)s / steps;
                int    cx = (int)Math.Floor((screenA.X + t * dx) / GridCellPx);
                int    cy = (int)Math.Floor((screenA.Y + t * dy) / GridCellPx);
                if (!seen.Add((cx, cy))) continue;

                if (!_edgeScreenGrid.TryGetValue((cx, cy), out var list))
                    _edgeScreenGrid[(cx, cy)] = list = [];
                list.Add(edge.Id);
            }
        }
        _edgeGridDirty = false;
    }

    /// <summary>
    /// Returns the mesh edge closest to <paramref name="mousePos"/> within
    /// <paramref name="threshold"/> pixels, or -1 if none qualifies.
    /// Uses a screen-space grid (TD-25-2) so only ~9 cells (~90 edges) are
    /// tested per call instead of the full edge list.
    /// </summary>
    private int FindNearestEdge(Point mousePos, double threshold)
    {
        if (_edgeGridDirty) BuildEdgeGrid();

        var mesh = Vm.CurrentMesh;
        if (mesh == null) return -1;

        int    mouseCx = (int)Math.Floor(mousePos.X / GridCellPx);
        int    mouseCy = (int)Math.Floor(mousePos.Y / GridCellPx);
        int    bestEdge = -1;
        double bestDist = threshold;

        // Collect candidate edge IDs from 3×3 neighbourhood (avoids edge at cell boundary)
        var candidates = new HashSet<int>();
        for (int dcx = -1; dcx <= 1; dcx++)
        for (int dcy = -1; dcy <= 1; dcy++)
            if (_edgeScreenGrid.TryGetValue((mouseCx + dcx, mouseCy + dcy), out var list))
                foreach (int id in list) candidates.Add(id);

        foreach (int id in candidates)
        {
            if ((uint)id >= (uint)mesh.Edges.Count) continue;
            var edge = mesh.Edges[id];

            var pa      = mesh.Vertices[edge.V1].Position;
            var pb      = mesh.Vertices[edge.V2].Position;
            var screenA = ProjectToScreen(new Point3D(pa.X, pa.Y, pa.Z));
            var screenB = ProjectToScreen(new Point3D(pb.X, pb.Y, pb.Z));
            if (double.IsNaN(screenA.X) || double.IsNaN(screenB.X)) continue;

            double d = DistPointToSegment(mousePos, screenA, screenB);
            if (d < bestDist) { bestDist = d; bestEdge = id; }
        }
        return bestEdge;
    }

    /// <summary>
    /// Projects a world-space 3D point to 2D screen coordinates using the
    /// PerspectiveCamera's current view and projection.
    /// Returns NaN,NaN if the point is behind the camera.
    /// </summary>
    private Point ProjectToScreen(Point3D worldPt)
    {
        var cam = MainCamera3D;
        if (cam == null) return new Point(double.NaN, double.NaN);

        double w = Viewport3D.ActualWidth;
        double h = Viewport3D.ActualHeight;
        if (w <= 0 || h <= 0) return new Point(double.NaN, double.NaN);

        var lookDir = cam.LookDirection;  lookDir.Normalize();
        var upDir   = cam.UpDirection;    upDir.Normalize();

        var rightDir = Vector3D.CrossProduct(lookDir, upDir);
        rightDir.Normalize();
        var trueUp = Vector3D.CrossProduct(rightDir, lookDir);

        var diff   = worldPt - cam.Position;
        double xCam = Vector3D.DotProduct(diff, rightDir);
        double yCam = Vector3D.DotProduct(diff, trueUp);
        double zCam = Vector3D.DotProduct(diff, lookDir);

        if (zCam <= 0) return new Point(double.NaN, double.NaN);   // behind camera

        double fovRad     = cam.FieldOfView * Math.PI / 180.0;
        double tanHalfFov = Math.Tan(fovRad / 2.0);
        double aspect     = w / h;

        double ndcX = xCam / (zCam * tanHalfFov * aspect);
        double ndcY = yCam / (zCam * tanHalfFov);

        return new Point(
            (ndcX + 1.0) / 2.0 * w,
            (1.0 - ndcY) / 2.0 * h);
    }

    /// Minimum distance from point <paramref name="p"/> to line segment AB.
    private static double DistPointToSegment(Point p, Point a, Point b)
    {
        double dx = b.X - a.X, dy = b.Y - a.Y;
        double lenSq = dx * dx + dy * dy;
        if (lenSq < 1e-10)
        {
            double ex = p.X - a.X, ey = p.Y - a.Y;
            return Math.Sqrt(ex * ex + ey * ey);
        }
        double t = Math.Max(0, Math.Min(1, ((p.X - a.X) * dx + (p.Y - a.Y) * dy) / lenSq));
        double projX = a.X + t * dx, projY = a.Y + t * dy;
        double fx = p.X - projX, fy = p.Y - projY;
        return Math.Sqrt(fx * fx + fy * fy);
    }

    // ── Edit Flaps dialog ─────────────────────────────────────────────────────

    private void EditFlapsButton_Click(object sender, RoutedEventArgs e)
    {
        if (_editFlapsDialog == null || !_editFlapsDialog.IsLoaded)
        {
            _editFlapsDialog = new EditFlapsDialog(Vm) { Owner = this };
            _editFlapsDialog.Closed += (_, _) =>
            {
                PatternCanvas.SetFlapEditMode(null);
                _editFlapsDialog = null;
            };
            PatternCanvas.SetFlapEditMode(_editFlapsDialog);
            _editFlapsDialog.Show();
        }
        else
        {
            _editFlapsDialog.Activate();
        }
    }

    // ── copy to clipboard ─────────────────────────────────────────────────────

    private void CopyToClipboard_Click(object sender, RoutedEventArgs e)
    {
        if (!Vm.CanExport) return;
        var rtb = new RenderTargetBitmap(
            (int)PatternCanvas.ActualWidth, (int)PatternCanvas.ActualHeight,
            96, 96, PixelFormats.Pbgra32);
        rtb.Render(PatternCanvas);
        Clipboard.SetImage(rtb);
        Vm.StatusText = "2D layout copied to clipboard.";
    }

    // ── texture dialog ────────────────────────────────────────────────────────

    private void TextureButton_Click(object sender, RoutedEventArgs e)
    {
        if (_textureDialog == null || !_textureDialog.IsLoaded)
        {
            _textureDialog = new TextureDialog { Owner = this, DataContext = DataContext };
            _textureDialog.Closed += (_, _) => _textureDialog = null;
            _textureDialog.Show();
        }
        else
        {
            _textureDialog.Activate();
        }
    }

    // ── Find bar (Ctrl+Shift+F) ───────────────────────────────────────────────

    private void FindTextBox_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Return)
        {
            if (int.TryParse(FindTextBox.Text.Trim(), out int gid))
                Vm.FindPiece(gid);
            else
                Vm.StatusText = "Enter a numeric part ID.";
            FindBar.Visibility = Visibility.Collapsed;
            e.Handled = true;
        }
        else if (e.Key == Key.Escape)
        {
            FindBar.Visibility = Visibility.Collapsed;
            e.Handled = true;
        }
    }

    private void FindClose_Click(object sender, RoutedEventArgs e) =>
        FindBar.Visibility = Visibility.Collapsed;

    // ── Dimension lines in 3D viewport ───────────────────────────────────────

    private void OnDimensionLinesChanged(bool show)
    {
        foreach (var v in _dimensionVisuals)
            Viewport3D.Children.Remove(v);
        _dimensionVisuals.Clear();

        if (!show) return;
        var mesh = Vm.CurrentMesh;
        if (mesh == null || mesh.Vertices.Count == 0) return;

        float minX = float.MaxValue, minY = float.MaxValue, minZ = float.MaxValue;
        float maxX = float.MinValue, maxY = float.MinValue, maxZ = float.MinValue;
        foreach (var v in mesh.Vertices)
        {
            var p = v.Position;
            if (p.X < minX) minX = p.X; if (p.X > maxX) maxX = p.X;
            if (p.Y < minY) minY = p.Y; if (p.Y > maxY) maxY = p.Y;
            if (p.Z < minZ) minZ = p.Z; if (p.Z > maxZ) maxZ = p.Z;
        }

        double scale = Vm.CurrentScaleMmPerUnit;
        double w = (maxX - minX) * scale;
        double h = (maxY - minY) * scale;
        double d = (maxZ - minZ) * scale;

        var lines = new LinesVisual3D
        {
            Color     = Colors.Orange,
            Thickness = 2,
            Points    = new Point3DCollection([
                new(minX, minY - 0.05, minZ), new(maxX, minY - 0.05, minZ),   // width
                new(maxX + 0.05, minY, minZ), new(maxX + 0.05, maxY, minZ),   // height
                new(minX, maxY + 0.05, minZ), new(minX, maxY + 0.05, maxZ),   // depth
            ])
        };
        AddDimVisual(lines);

        AddDimVisual(new BillboardTextVisual3D { Text = $"W: {w:F1}mm",  Position = new((minX+maxX)/2, minY-0.18, minZ),    Foreground = Brushes.Orange, FontSize = 14 });
        AddDimVisual(new BillboardTextVisual3D { Text = $"H: {h:F1}mm",  Position = new(maxX+0.18, (minY+maxY)/2, minZ),    Foreground = Brushes.Orange, FontSize = 14 });
        AddDimVisual(new BillboardTextVisual3D { Text = $"D: {d:F1}mm",  Position = new(minX, maxY+0.18, (minZ+maxZ)/2),    Foreground = Brushes.Orange, FontSize = 14 });
    }

    private void AddDimVisual(Visual3D v)
    {
        Viewport3D.Children.Add(v);
        _dimensionVisuals.Add(v);
    }

    /// <returns>Face index (>= 0) or -1 if nothing was hit.</returns>
    private int HitTestFace(Point pos)
    {
        RayMeshGeometry3DHitTestResult? hit = null;

        VisualTreeHelper.HitTest(
            Viewport3D.Viewport,
            null,
            r =>
            {
                if (r is RayMeshGeometry3DHitTestResult m) hit = m;
                return HitTestResultBehavior.Stop;
            },
            new PointHitTestParameters(pos));

        if (hit == null) return -1;

        return Vm.ResolveHitFaceId(hit.MeshHit, hit.VertexIndex1, hit.VertexIndex2, hit.VertexIndex3);
    }
}
