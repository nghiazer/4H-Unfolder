# 4H-Unfolder — Session Progress Log

> **Last updated:** 2026-05-24 (session 29 — TD-28-1/3/4 + TD-24-1 resolved; publish v0.0.2.H)
> **Branch:** `feat/animation-fold-texture`
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
| `dotnet build 4H-Unfolder.sln` | ✅ 0 errors, 4 warnings (NuGet NU1603 only) |
| `dotnet test` | ✅ 34 / 34 passed |
| `dotnet run --project src/FourHUnfolder.App` | ✅ App mở, Light mode, all dialogs theme-aware |
| Published `4H-Unfolder.exe` v0.0.2.H (win-x64, self-contained) | ✅ Session 29 |

---

## Session 29 — Changes

| Item | Detail |
|------|--------|
| **TD-28-4 — 3D viewport background auto-update** | `MainViewModel`: thêm `LightView3DBg="#e8ecf4"` / `DarkView3DBg="#0d0d1a"`; `OnSettingsChanged` auto-switch `View3D.BackgroundColor` khi đổi theme nếu còn ở default cũ; `AppSettings.View3DSettings.BackgroundColor` default → `"#e8ecf4"` (Light) |
| **TD-28-1 — SettingsDialog footer buttons** | Thêm 9 semantic keys vào LightTheme + DarkTheme: `BtnOkBg/Fg/Border`, `BtnApplyBg/Fg/Border`, `BtnCancelBg/Fg/Border`, `BtnResetBg/Fg/Border`; SettingsDialog footer buttons → DynamicResource |
| **TD-28-3 — 4 dialogs theme-aware** | Thêm 5 keys mới: `AssemblyStepBg`, `AssemblyCtrlBg`, `CtrlBtnBg/Fg/Border`; tất cả 4 dialogs dùng DynamicResource cho Window bg, text, inputs, borders, buttons |
| **AssemblyAnimationWindow** | Window bg → `DialogBg`; step bar → `AssemblyStepBg`/`TextAccent`; control bar → `AssemblyCtrlBg`; CtrlBtn/PlayBtn style → DynamicResource; separators/text → DynamicResource. 3D viewport giữ `#0d0d1a` (intentional cinema mode) |
| **TextureDialog** | Window bg → `DialogBg`; left nav → `DialogNavBg`/`BorderLight`; list hover/selected → `NavSelectedBg`/`NavHoverBg`; text → `TextPrimary`/`TextMuted`; borders → `BorderNormal`; buttons → `BtnApply/BtnCancel/BtnOk` |
| **UnfoldSetupDialog** | Window bg → `DialogBg`; Label/TextBox/ComboBox/GroupBox styles → DynamicResource; RadioButton → `TextPrimary`; bbox label → `TextMuted`; OK/Cancel → `BtnOk/BtnCancel` |
| **ModelOrientationDialog** | Window bg → `DialogBg`; Label/ComboBox/CheckBox styles → DynamicResource; preview border → `BorderNormal`; title/subtitle/separator → DynamicResource; Flip UV box → `DialogNavBg`; OK → `BtnOk`, Skip → `CtrlBtnBg`. Axis label colors (RGB) và parallel warning (red) giữ nguyên semantic colors |
| **TD-24-1 — PieceFoldTree fold direction** | `FoldNode` thêm `EdgeDir3D` property; `Build()` populate `EdgeDir3D = Normalize(vB_3D - vA_3D)`; `ComputeFoldTransforms` thêm `signCorr = dot(axis, node.EdgeDir3D) >= 0 ? 1f : -1f` → fix fold direction khi flat-space axis antiparallel với 3D edge direction |
| **Build/Test** | ✅ 0 errors / 34 tests passed / app opens clean |
| **Release v0.0.2.H** | Published win-x64 self-contained EXE |

---

## Session 28 — Changes

| Item | Detail |
|------|--------|
| **Light/Dark theme system** | `Themes/LightTheme.xaml` + `DarkTheme.xaml`; `ThemeService.Apply()`; `AppSettings.General.ThemeMode`; `SettingsViewModel.ThemeMode` |
| **MainWindow/PatternCanvas/SettingsDialog** | All hardcoded colors → DynamicResource; Appearance GroupBox in General panel |
| **Icon resize ×1.4 + rounded buttons** | `IconBtn`/`Icon2D`/`Toggle2D` FontSize up; ControlTemplate CornerRadius=5 |
| **Canvas 2D auto-switch** | `OnSettingsChanged` auto-updates canvas bg default when theme changes |
| **Installer** | `installer/4H-Unfolder.iss` + `installer/build-installer.ps1`; 48.3 MB EXE |
| **Release v0.0.2.G** | Published win-x64 self-contained EXE |

## Remaining Tech Debt

| ID | Priority | Description |
|----|----------|-------------|
| TD-25-1 | 🟢 Low | `ModelOrientationDialog` shown on every mesh load; add "don't ask again" setting |
| Performance | 🟢 Low | O(n²) overlap check → spatial grid for meshes > 2000 faces |

---

## File Inventory (~70 source files, ~6 200 lines)

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
App/Services/           ThemeService
App/Themes/             LightTheme.xaml DarkTheme.xaml
App/                    MainWindow App

Tests/                  MstAlgorithmTests (6)  UnfoldEngineTests (9)
                        GeometryAlgorithmTests (13)  SvgExporterTests (5: AffineTransform)
App/Assets/             app.ico (6 sizes) logo.png
```

---

## Recommended Next Steps

1. Fix TD-28-1/3: Theme-aware footer buttons + other dialogs (AssemblyAnimationWindow, TextureDialog, etc.)
2. Fix TD-24-1: PieceFoldTree fold animation direction accuracy
3. Fix TD-25-1: "don't ask again" for ModelOrientationDialog
4. Performance: spatial grid for overlap check (>2000 face meshes)
5. PDO import (Pepakura native format — reverse-engineered, complex)
