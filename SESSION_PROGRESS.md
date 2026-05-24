# 4H-Unfolder — Session Progress Log

> **Last updated:** 2026-05-24 (session 27 — Fix ModelOrientationDialog crash + ComputeRotation math; TD-25-2/27-1/27-2/27-3; publish v0.0.2.F)
> **Branch:** `feat/paper-model-unfolder`  (PR #1 open against `main`)
> **Target framework:** .NET 8 / WPF
> **SDK required:** `winget install Microsoft.DotNet.SDK.8`
> **History archive:** see [`BUGS_HISTORY.md`](BUGS_HISTORY.md) for all prior bug/tech-debt records

---

## Quick-start

```bash
cd D:\CODING\UNFOLD
dotnet restore
dotnet build
dotnet run --project src/FourHUnfolder.App
dotnet test tests/FourHUnfolder.Tests
```

---

## Architecture

```
Domain → Geometry → Application → Infrastructure → App
```
No circular dependencies. Domain has zero external dependencies.

---

## Complete Feature List

### Core pipeline
| Step | Class | Notes |
|------|-------|-------|
| OBJ load | `ObjMeshLoader` | v/vt/f, multi-material MTL (newmtl/usemtl/map_Kd), fan-triangulation |
| Multi-format | `AssimpMeshLoader` + `MultiFormatMeshLoader` | 3DS, STL, DXF, LWO/LWS, FBX, COLLADA, PLY via AssimpNet 5 |
| Dual graph | `DualGraphBuilder` | Dihedral-angle weights; zero-area face guard |
| MST | `KruskalMstBuilder` | Kruskal + path-compressed Union-Find |
| Edge marking | `EdgeMarker` | Fold / Cut / Boundary |
| Unfold | `UnfoldEngine` | BFS circle-circle apex; disconnected components |
| Overlap | `OverlapDetector` | AABB pre-check + SAT |
| Tabs | `GlueTabGenerator` | Trapezoid/Rectangle/Triangle; side-angle param; alternate-flap |
| Pieces | `PieceComputer` | Union-Find connected components |
| SVG | `SvgExporter` | Per-face affine texture; edge-dedup; grayscale |
| PDF | `PdfExporter` | Multi-page; fold/cut/tab lines; page labels via PdfSharp.Standard |

### UI features
- Split 3D/2D viewport; 3D picking; right-click Detach/Attach
- Bidirectional 3D↔2D sync
- Interactive 2D canvas: drag, rotate ±90°, flip H, lasso multi-select
- Middle-mouse pan, scroll zoom, snap-to-grid
- **Piece outline merging** — boundary polygon per piece replaces individual triangle silhouettes
- **Edge-Edit mode** (✏): hover highlight, LMB attach/detach; color in Settings
- **Rotate-by-Point mode** (⊙): pivot → handle → live rotation; undoable
- **Auto-align edge** — double-click edge → snap to nearest 90°; undoable
- **Parts alignment** — 6 toolbar buttons: Align L/R/T/B/Center-H/V; undoable
- **Edge ID labels + glue arrows** on cut edges (pair numbers 1,2,3…); color in Settings
- **Multi-texture** — per-material texture slots; TextureDialog with material list; per-face texture in 2D
- **Save/Load `.4hu`** — self-contained ZIP bundle (mesh + texture + state)
- **Unsaved changes warning** on Load/Open/Close
- **Strip-packing auto-arrange** — sort by area desc, try 90° rotation
- Export SVG + Export PDF (📑 toolbar button)
- Undo/Redo (Ctrl+Z/Y) for all edit operations
- **Assembly animation** (🎬) — step-by-step fold guide with:
  - Phase 1: true paper-fold — faces rotate around shared fold edges (BFS spanning tree + accumulated Matrix4x4)
  - Phase 2: fly-in — folded shape translates to final 3-D position
  - Per-material texture display (assembled + current piece)
  - Amber emissive overlay on current piece; ghost translucent for upcoming pieces
  - Play/Pause auto-animation; step controls ⏮ ◀ ▶ ⏭

### Settings (4-panel dialog)
| Section | Key options |
|---------|------------|
| 3D View | Background, display mode, face/back color, opacity, edge overlay, lighting, camera |
| 2D View | Canvas/paper color, grid, fold/cut lines, glue tabs, face numbers, edge IDs, snap |
| Print | Margin, bleed, SVG scale, tab shape + angle + depth, alternate flaps, grayscale |
| General | Display unit: mm / inch |

---

## Build & Test Status

| Item | Result |
|------|--------|
| `dotnet build 4H-Unfolder.sln` | ✅ 0 errors, 7 warnings (NuGet NU1603 only) |
| `dotnet test` | ✅ 34 / 34 passed |
| `dotnet run --project src/FourHUnfolder.App` | ✅ App mở, load mesh không crash |
| Published `4H-Unfolder.exe` v0.0.2.F (win-x64, self-contained) | ✅ Session 27 |

---

## Session 27 — Changes

| Item | Detail |
|------|--------|
| **Bug — ModelOrientationDialog crash on load** | `ResizeMode="CanMinResize"` không tồn tại trong WPF `ResizeMode` enum → `TypeConverterMarkupExtension` exception khi BAML load dialog; đã fix → `CanMinimize` |
| **Bug — `ComputeRotation` reflection matrix** | Cross product sai thứ tự: `Cross(front, up)` → right = (-1,0,0) với default +Y/+Z → reflection matrix flip X → mesh bị mirror + texture biến mất; fix: `Cross(up, front)` + `Cross(front, right)` → identity cho default |
| **Bug — `BillboardTextVisual3D` removed** | 6 axis label elements dùng HelixToolkit `BillboardTextVisual3D` bị xóa để tránh compat risk trên .NET 8; thay bằng 2D Canvas overlay (TD-27-2) |
| **Diagnostics — `Error()` inner exception** | `MainViewModel.Error()` trước chỉ show `ex.Message` (outer); nay walk `InnerException` chain → message hữu ích hơn |
| **TD-25-2 — Edge hover O(n) → O(1)** | `MainWindow.xaml.cs`: `BuildEdgeGrid()` rasterize tất cả edges vào `Dictionary<(int,int), List<int>>` (cell 24px); `FindNearestEdge` chỉ test 3×3 cells (~90 candidates); grid invalidated on camera move + mesh change |
| **TD-27-1 — Camera auto-fit** | `ModelOrientationDialog`: `ZoomExtents(0)` qua `Dispatcher.BeginInvoke(DispatcherPriority.Loaded)` sau khi mesh được add vào viewport |
| **TD-27-2 — Axis labels 2D overlay** | `ModelOrientationDialog`: Canvas overlay với 3 `TextBlock` (+X/#ff5555, +Y/#44cc44, +Z/#5599ff); `Viewport3DHelper.Point3DtoPoint2D(CubeViewport.Viewport, pt)` cập nhật vị trí trên mỗi `CameraChanged` |
| **TD-27-3 — Parallel-axes validation** | `ModelOrientationViewModel`: `AxesAreParallel` computed property + `[NotifyPropertyChangedFor]`; XAML: warning TextBlock (DataTrigger) + OK button Style trigger `IsEnabled=False, Opacity=0.35` khi parallel |
| **Build/Test** | ✅ 0 errors / 34 tests passed / app loads mesh clean |
| **Release v0.0.2.F** | Published win-x64 self-contained EXE |

## Session 26 — Changes

| Item | Detail |
|------|--------|
| **TD-22-1 — Assimp material support** | `AssimpMeshLoader` now reads `scene.Materials` → populates `mesh.MaterialNames`, `mesh.MaterialTexturePaths`, `mesh.SuggestedTexturePath`; each sub-mesh uses `aMesh.MaterialIndex` → every face gets correct `MaterialId`; texture paths resolved relative to model file |
| **TD-22-2 — Multi-texture project persistence** | `ProjectState` +`MaterialTexturePaths` + `BundledMaterialTextureExts`; `ProjectSerializer.SaveBundle` embeds per-material textures as `texture_<matId>.<ext>` entries; `LoadBundle` reconstructs paths from temp dir; `Save`/`Load` relativizes/resolves paths; `MainViewModel.BuildProjectState` + `RestoreProjectState` updated |
| **TD-22-3 — Multi-material SVG export** | `UnfoldedFace` +`MaterialId` param; `UnfoldEngine` passes `mesh.Faces[faceId].MaterialId`; `IExporter.Export` adds `perMaterialTextures` param; `SvgExporter` builds per-material data URIs, resolves per-face URI by `face.MaterialId` → fallback `-1`; `MainViewModel.BuildExportLayout` passes `fd.MaterialId`; `ExportSvg` passes `GetMaterialTexturePaths()` |
| **TD-22-4 — Float edge-dedup fix** | `SvgExporter` + `PdfExporter`: replaced raw `(float,float,float,float)` tuple with `EdgeKey(a,b)` helper that rounds to 3 decimal places and canonicalises order → reliable dedup |
| **TD-22-5 — UV double-flip removed** | Removed `PostProcessSteps.FlipUVs` from `AssimpMeshLoader`; `ToWpfUV` in `MainViewModel` already flips V (`1.0 - uv.Y`); single flip is correct for WPF top-left UV convention |
| **`Mesh.AddFace`** | Added optional `materialId = -1` parameter; sets `face.MaterialId` |
| **`MainViewModel`** | +`GetMaterialTexturePaths()` helper; `RestoreProjectState` restores per-material slots before building 3D model |
| **Build/Test** | ✅ 0 errors / 34 tests passed / app starts clean |
| **Release v0.0.2.E** | Published win-x64 self-contained EXE |

---

## Remaining Tech Debt

| ID | Priority | Description |
|----|----------|-------------|
| TD-24-1 | 🟡 Medium | `PieceFoldTree` fold animation: angles computed from 3D normals applied in flat space — fold direction may be wrong for non-trivial pieces |
| TD-25-1 | 🟢 Low | `ModelOrientationDialog` shown on every mesh load; add "don't ask again" setting for users who always use Y-up Z-front models |
| Performance | 🟢 Low | O(n²) overlap check → spatial grid for meshes > 2000 faces |

---

## File Inventory (~67 source files, ~5 900 lines)

```
Domain/Models/          Vertex Edge EdgeType Face Mesh PaperSizeModel ModelScale
Domain/DualGraph/       DualGraph GraphNode GraphEdge
Domain/Results/         UnfoldedFace GlueTab UnfoldResult AssemblyStep
Domain/Settings/        AppSettings (View3D View2D Print General)
Domain/Persistence/     ProjectState

Geometry/Algorithms/    DualGraphBuilder KruskalMstBuilder EdgeMarker
                        UnfoldEngine OverlapDetector GlueTabGenerator PieceComputer
                        AssemblyPlanner PieceFoldTree

Application/Interfaces/ IMeshLoader IExporter
Application/Services/   MeshService UnfoldService ProjectSerializer SettingsService

Infrastructure/         ObjMeshLoader AssimpMeshLoader MultiFormatMeshLoader
                        SvgExporter PdfExporter AffineTransformHelper

App/ViewModels/         MainViewModel PieceViewModel SettingsViewModel
                        MaterialTextureViewModel AssemblyViewModel ModelOrientationViewModel
App/Controls/           PatternCanvasControl
App/Dialogs/            UnfoldSetupDialog SettingsDialog TextureDialog
                        AssemblyAnimationWindow ModelOrientationDialog
App/Converters/         HexColorBrushConverter
App/                    MainWindow App

Tests/                  MstAlgorithmTests (6)  UnfoldEngineTests (9)
                        GeometryAlgorithmTests (13)  SvgExporterTests (5: AffineTransform)
App/Assets/             app.ico (6 sizes) logo.png
```

---

## Recommended Next Steps

1. **Merge PR #1**: <https://github.com/nghiazer/4H-Unfolder/pull/1>
2. Fix TD-24-1: PieceFoldTree fold animation direction accuracy
3. Fix TD-25-1: "don't ask again" for ModelOrientationDialog
4. Performance: spatial grid for overlap check (>2000 face meshes)
5. PDO import (Pepakura native format — reverse-engineered, complex)
