# PepakuraClone — Session Progress Log

> **Last updated:** 2026-05-21  
> **Branch:** `main`  
> **Target framework:** .NET 8 / WPF  
> **SDK required:** .NET 8 SDK (`winget install Microsoft.DotNet.SDK.8`)

---

## Quick-start (after installing .NET 8 SDK)

```bash
cd D:\CODING\UNFOLD
dotnet restore
dotnet build
dotnet run --project src/PepakuraClone.App
dotnet test tests/PepakuraClone.Tests
```

---

## Architecture

```
PepakuraClone.sln
├── src/
│   ├── Domain          – Pure models, no external deps
│   ├── Geometry        – Algorithms (→ Domain)
│   ├── Application     – Use-case services (→ Domain, Geometry)
│   ├── Infrastructure  – OBJ loader, SVG exporter (→ Domain, Application)
│   └── App (WPF)       – MVVM UI (→ Application, Infrastructure + NuGet)
└── tests/
    └── PepakuraClone.Tests   – xunit + FluentAssertions
```

**Dependency order (no circular deps):**
```
Domain → Geometry → Application → Infrastructure → App
```

---

## Features Implemented (this session)

### Step 1 — Domain Models
- `Vertex`, `Edge` (EdgeType: Unknown/Fold/Cut/Boundary), `Face`, `Mesh`
- `Mesh.AddFace()` auto-builds edge adjacency via canonical `(min,max)` key dict
- `DualGraph` (GraphNode, GraphEdge) for face adjacency

### Step 2 — Core Algorithms (Geometry layer)
- `DualGraphBuilder` — weighted by dihedral angle
- `KruskalMstBuilder` — Kruskal + path-compressed Union-Find
- `EdgeMarker` — stamps Fold/Cut/Boundary on all mesh edges
- `UnfoldEngine` — BFS triangle flattening; supports disconnected components (multiple pieces)
- `OverlapDetector` — O(n²) SAT check
- `GlueTabGenerator` — trapezoid tabs on cut edges, each tagged with `FaceId + LocalEdgeIdx`
- `PieceComputer` — Union-Find connected components from fold graph

### Step 3 — OBJ Loader & SVG Exporter
- `ObjMeshLoader` — parses `v`, `vt`, `f` (v/vt/vn), `mtllib`/`map_Kd`; fan-triangulates n-gons
- UV coordinates stored in `Mesh.UVs` + per-face `FaceUVs`
- `SvgExporter` — reads `AppSettings.PrintSettings` for all line/color/margin options

### Step 4 — Application Services
- `MeshService` — file-exists guard + load
- `UnfoldService` — full pipeline with optional `edgeOverrides` + scale computation
- `ProjectSerializer` — JSON `.pmc` with relative + absolute path storage
- `SettingsService` — singleton, persists to `%AppData%\PepakuraClone\settings.json`

### Step 5 — WPF UI
| Component | Description |
|-----------|-------------|
| `MainWindow.xaml` | Split 3D/2D layout; column widths driven by `IsUnfolded` |
| `HelixViewport3D` | 3D mesh display; left-click = select face, right-click = detach/attach menu |
| `PatternCanvasControl` | Interactive 2D canvas: drag pieces, right-click edge = join/split, rotate, auto-arrange |
| `UnfoldSetupDialog` | Scale target (axis + value + unit) + paper size before unfold |
| `SettingsDialog` | 3-panel nav (3D View / 2D View / Print); 30+ settings with live color preview |

### Step 6 — Settings System
Three settings groups (persisted JSON, applied on `SettingsService.SettingsChanged`):

| Group | Key settings |
|-------|-------------|
| **3D View** | Background color, display mode (Solid/SolidEdges/Wireframe), face/back-face color + opacity, edge overlay, ambient/directional intensity, **camera FOV + near/far clip planes** |
| **2D View** | Canvas/paper color, grid show/size/color, face fill, fold/cut line color+width+dash, glue tab color, face numbers, **piece gap (mm)**, default zoom |
| **Print/Export** | Page margin, bleed, SVG scale, include tabs/fold/cut/page-label, grayscale, print-specific line colors+widths |

### Step 7 — 3D Face Selection + Detach/Attach
- `HitTestFace()` — `VisualTreeHelper.HitTest` on inner `Viewport3D`, face ID = `minVertexIndex / 3`
- Selection overlay — semi-transparent yellow `Model3DGroup` offset 0.015 units along normal (prevents z-fighting)
- 2D ↔ 3D sync: selecting in 3D highlights the 2D piece; clicking a 2D piece updates the 3D overlay
- **Detach face** — cuts all fold edges of that face
- **Detach piece** — cuts all fold edges of the entire connected component
- **Attach faces** — finds shared edge, changes Cut → Fold

### Step 8 — Save / Load Project (`.pmc`)
Saves and restores:
- Mesh file path (relative + absolute fallback)
- Texture file path
- Real-world scale (`_currentScaleMmPerUnit`)
- Paper size
- Edge overrides (user join/split history)
- Per-piece position + rotation

---

## Bugs Fixed This Session

| # | Bug | Fix |
|---|-----|-----|
| 1 | `PatternCanvasControl` drag broken — piece captured mouse, move event on `RootCanvas` never fired | `RootCanvas.CaptureMouse()` / `ReleaseMouseCapture()` |
| 2 | `BuildProjectState` always saved `ScaleMmPerUnit = 1.0` → pieces wrong size on restore | Use `_currentScaleMmPerUnit` in save + restore |
| 3 | `MainWindow.xaml.cs` missing `using System.Linq` → compile error on `.ToList()` | Added `using System.Linq;` |
| 4 | `UnfoldSetupDialog.xaml` custom-size TextBoxes had `IsEnabled="{Binding ElementName=..., Path=Tag}"` (self-binding to null Tag → always disabled) | Changed to `IsEnabled="False"` (code-behind sets dynamically) |
| 5 | `CommitPreview` had identical ternary branches + confusing self-assignment | Rewrote with explanatory comment |
| 6 | `EstimateCurrentScale()` dead code after `_currentScaleMmPerUnit` was introduced | Removed |
| 7 | `DualGraphBuilder.ComputeFaceNormal` returned `NaN` for degenerate zero-area triangles → poisoned edge weights / sort behaviour | Guard: return `Vector3.UnitY` when cross-product magnitude < 1e-10 |
| 8 | `ObjMeshLoader` didn't handle negative OBJ indices (valid per spec, count from end) | Return -1 for negative indices |

---

## Tech Debt & Known Issues

### High Priority
| ID | Location | Description |
|----|----------|-------------|
| TD-1 | `UnfoldEngine` | No overlap-aware repositioning — pieces may stack after join/split. MST may not form a true spanning tree when many user overrides conflict. |
| TD-2 | `PatternCanvasControl` | Pieces are rendered as individual triangles (not merged outlines). Shared fold edges inside a piece are drawn twice (once per face), causing visual doubling. |
| TD-3 | `OverlapDetector` | O(n²) SAT — will lag with meshes > ~500 faces. Need spatial index (AABB tree or grid). |

### Medium Priority
| ID | Location | Description |
|----|----------|-------------|
| TD-4 | `PatternCanvasControl` | Memory leak: `piece.PropertyChanged` lambda holds reference to old `Canvas` after `RebuildAll`. No explicit unsubscribe. |
| TD-5 | `MainViewModel.BuildSelectionOverlay` | Rebuilds entire geometry every selection change. Should diff vs. previous selection. |
| TD-6 | `SvgExporter` | Does not embed textures into SVG. Fold/cut lines are emitted per face — shared edges drawn twice. |
| TD-7 | `UnfoldSetupDialog` | No live preview of model at chosen scale. |
| TD-8 | `ProjectSerializer` | Does not store the `ModelScale` struct — only the computed `ScaleMmPerUnit` double. Re-opening settings shows default values. |

### Low Priority
| ID | Location | Description |
|----|----------|-------------|
| TD-9 | `KruskalMstBuilder` | Flat meshes (all weights ≈ 0) produce arbitrary MST. No heuristic for visually clean unfolding. |
| TD-10 | `HitTestFace` | Assumes flat-shaded mesh with unshared vertices. If mesh is ever rebuilt with shared vertices, `minVertexIndex / 3` would give wrong face IDs. |
| TD-11 | `MainWindow.xaml` | `x:Name="Viewport3D"` shadows the `System.Windows.Media.Media3D.Viewport3D` class name in code-behind scope. Works but confusing. |
| TD-12 | `SettingsDialog` | No undo for "Reset to Defaults" once Apply/OK is pressed. |

---

## File Inventory (50 source files)

```
src/PepakuraClone.Domain/
  Models/          Vertex, Edge, EdgeType, Face, Mesh
  DualGraph/       DualGraph, GraphNode, GraphEdge
  Results/         UnfoldedFace, GlueTab, UnfoldResult
  Settings/        AppSettings (View3D + View2D + Print)
  Persistence/     ProjectState (JSON DTO)

src/PepakuraClone.Geometry/
  Algorithms/      DualGraphBuilder, KruskalMstBuilder, EdgeMarker,
                   UnfoldEngine, OverlapDetector, GlueTabGenerator, PieceComputer

src/PepakuraClone.Application/
  Interfaces/      IMeshLoader, IExporter
  Services/        MeshService, UnfoldService, ProjectSerializer, SettingsService

src/PepakuraClone.Infrastructure/
  Loaders/         ObjMeshLoader
  Exporters/       SvgExporter

src/PepakuraClone.App/
  ViewModels/      MainViewModel, PieceViewModel, SettingsViewModel
  Controls/        PatternCanvasControl (interactive 2D canvas)
  Dialogs/         UnfoldSetupDialog, SettingsDialog
  Converters/      HexColorBrushConverter
  App.xaml / MainWindow.xaml + code-behind

tests/PepakuraClone.Tests/
  MstAlgorithmTests.cs   (6 tests)
  UnfoldEngineTests.cs   (9 tests)
```

---

## Recommended Next Steps

1. **Install .NET 8 SDK** and verify `dotnet build` passes
2. **Test with a real OBJ file** (tetrahedron from README is a good start)
3. **Fix TD-2** (merged piece outlines) — improves visual quality significantly
4. **Fix TD-3** (overlap detector) — block for large models
5. **Add PDF export** via a library like `PdfSharp`
6. **Add undo/redo stack** (`ICommand` history) for join/split/detach operations
7. **Auto-unfold re-layout** — run a greedy strip-packing after each join/split

---

## NuGet Dependencies (App project)

| Package | Version | Purpose |
|---------|---------|---------|
| `HelixToolkit.WPF` | 2.25.0 | 3D viewport with orbit controls |
| `CommunityToolkit.Mvvm` | 8.3.2 | `[ObservableProperty]`, `[RelayCommand]` |
| `Microsoft.Extensions.DependencyInjection` | 8.0.1 | DI container |
| `xunit` | 2.7.0 | Unit tests |
| `FluentAssertions` | 6.12.0 | Readable test assertions |
