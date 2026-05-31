# 4H-Unfolder — Session Progress Log

> **Last updated:** 2026-06-01 (session 38 — Remaining Pepakura features; branch `feat/pepakura-features`)
> **Branch:** `feat/pepakura-features`  (base: `feat/glue-tab-editor` @ v0.0.5.A → current: v0.0.7.A)
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
| PDO load | `PdoMeshLoader` | Pepakura Designer v3/PD6: header, cipher, vertices, UV, shapes, zlib texture |
| Multi-format | `AssimpMeshLoader` + `MultiFormatMeshLoader` | 3DS, STL, DXF, LWO/LWS, FBX, COLLADA, PLY via AssimpNet 5 |
| Dual graph | `DualGraphBuilder` | Dihedral-angle weights; zero-area face guard |
| MST | `KruskalMstBuilder` | Kruskal + path-compressed Union-Find |
| Edge marking | `EdgeMarker` | Fold / Cut / Boundary |
| Unfold | `UnfoldEngine` | BFS circle-circle apex; disconnected components; populates `UnfoldedFace.MeshEdgeIds` |
| Overlap | `OverlapDetector` | AABB pre-check + SAT |
| Tabs | `GlueTabGenerator` | Trapezoid/Rectangle/Triangle; side-angle param; alternate-flap; **per-edge `FlapOverride` support (NEW)** |
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
- **Edit Flaps dialog** (✂) — modeless, per-edge glue tab placement (NEW, v0.0.4.H / released v0.0.5.A):
  - **Shape(S) tab**: Set Height (mm), Set Angle (Auto/Manual, L/R degrees), [to all] applies globally
  - **Position(Q) tab**: inner cut edges (Switch / OnThisSide / OtherSide / NoFlap / BothSides / DoNothing) + border edges (DoNothing / MountainFold / ValleyFold / NoFold / NoFlap)
  - Canvas click-to-apply; overrides persist in `.4hu` project bundle
  - Full undo/redo integration via expanded `EditSnapshot` (3-field: EdgeOverrides + FlapOverrides + PieceLayouts)

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
| `dotnet test` | ✅ 56 / 56 passed |
| `dotnet run --project src/FourHUnfolder.App` | ✅ App opens; all features accessible |
| Published `4H-Unfolder.exe` **v0.0.7.A** (win-x64, self-contained) | ✅ Session 38 |

---

## Session 38 — Changes (v0.0.7.A)

### Branch `feat/pepakura-features` (continued from s37)

9 remaining Pepakura Designer features implemented, identified from 3D Model / 2D Layout / Others menus.

| Feature | Where | Implementation |
|---------|-------|----------------|
| **Texture On/Off** | Others | `ShowTexture` toggle; canvas skips ImageBrush fill when off |
| **Highlight Fold Lines** | Others | `HighlightFoldLines` toggle; fold width ×3 + blue (#0055FF) |
| **Show Part Name** | 2D Layout | `ShowPartNames` toggle; "P{GroupId}" label at piece centroid |
| **Show Page Number** | 2D Layout | `ShowPageNumbers` toggle; large semi-transparent number inside each page |
| **Separate All Faces** | 3D Model | `SeparateAllFacesCommand`; sets all connecting edges to Cut + auto-arrange |
| **Apply Transparency of Print Setting** | 2D Layout | `ApplyPrintTransparency` toggle; texture polygons rendered at 0.85 opacity |
| **Show Dimension Lines** | 3D Model | `ShowDimensionLines` + event; adds `LinesVisual3D` + 3 `BillboardTextVisual3D` W/H/D labels |
| **Find Text (Ctrl+Shift+F)** | 2D Layout | `OpenFindCommand` + FindBar overlay; type GroupId → select + auto-scroll |
| **Insert Image** | 2D Layout | `InsertImageCommand`; 50%-opacity background image layer; persisted in ProjectState |

#### Domain / persistence changes
- `AppSettings.View2DSettings`: 5 new flags (ShowTexture, HighlightFoldLines, ShowPartNames, ShowPageNumbers, ApplyPrintTransparency)
- `ProjectState`: new `InsertedImagePath: string?`
- `MainViewModel`: 6 new observable properties + 7 new commands + 2 new events + `CurrentScaleMmPerUnit`
- `PatternCanvasControl`: `DrawInsertedImage()`, page-number rendering in `DrawPageAt`, 4 new toolbar toggle buttons
- `MainWindow`: Find bar overlay, dimension-line add/remove from `Viewport3D.Children`

#### Bug fixes in cross-review
- Fixed `InvalidOperationException` in ShowPartNames when piece has no faces (added `piece.Faces.Length > 0` guard)

#### Deferred as too complex (TD-38)
| ID | Description |
|----|-------------|
| TD-38-1 | Add Outline Padding — needs Clipper2 polygon offset library |
| TD-38-2 | Merge Adjacent Flaps — complex tab polygon union |
| TD-38-3 | Join Adjacent Isolated Edges — connectivity graph |
| TD-38-4 | Select Symmetrical Pair — mesh symmetry detection |
| TD-38-5 | Split Window — multi-window WPF management |
| TD-38-6 | Change Coordinates — scope unclear |

---

## Session 37 — Changes (v0.0.6.A)

### Branch `feat/pepakura-features` (off `feat/glue-tab-editor` @ v0.0.5.A)

11 missing Pepakura Designer features implemented, mapped from 3D Model / 2D Layout / Others menus.

| Feature | Shortcut | Files changed |
|---------|----------|---------------|
| **Select All** | `Ctrl+A` | `MainViewModel` + `MainWindow.xaml` KeyBinding |
| **Reset Cutline Edges** | Toolbar ✂ | `MainViewModel.ResetCutlineEdgesCommand` |
| **Show 2D Layout Only** | Toolbar □ | `LeftColumnWidth` col-0 binding; `AppSettings.View2D.Show2DOnly` |
| **Undo Unfold** | Toolbar ↺ | `MainViewModel.UndoUnfoldCommand` — clears edge+flap overrides, re-unfolds, auto-arranges |
| **Copy to Clipboard** | Toolbar 📋 | `MainWindow.CopyToClipboard_Click` — `RenderTargetBitmap` → `Clipboard.SetImage` |
| **Fit Page to Window** | `F3` | `PatternCanvasControl.FitPageToWindow()` — computes px/mm to fill viewport |
| **Zoom to Selected** | `F4` | `PatternCanvasControl.ZoomToSelected()` — union AABB of selected pieces |
| **Show Fold Angle** | `∠` toggle | `UnfoldResult.EdgeDihedralAngles`; labels rendered in `RenderPieceShapes`; `AppSettings.View2D.ShowFoldAngles` |
| **Scale dialog** | Toolbar ⇔ | New `ScaleDialog.xaml` + `MainViewModel.OpenScaleDialogCommand`; reuses `UnfoldService.ComputeScale` |
| **Mirror Inversion** | Toolbar ⇅ | `Matrix4x4.CreateScale(-1,1,1)` toggle; persisted as `ProjectState.MirrorX` |
| **Group / Ungroup** | `Ctrl+G` / `Ctrl+Shift+G` | `PieceViewModel.UserGroupId`; drag expands to all grouped peers; undo snapshot + `.4hu` persistence |

#### Domain / pipeline changes
- `UnfoldResult`: new `EdgeDihedralAngles: IReadOnlyDictionary<int, float>` (meshEdgeId → degrees)
- `UnfoldService`: populates `EdgeDihedralAngles` from `dualGraph.Edges`
- `ProjectState`: new `MirrorX: bool` + `PieceLayoutDto.UserGroupId: int?`
- `AppSettings.View2DSettings`: new `ShowFoldAngles`, `FoldAngleColor`, `Show2DOnly`
- `EditSnapshot`: extended tuple `(X, Y, Rot, int? UserGroupId)` for full undo fidelity

#### New file
- `ScaleDialog.xaml` + `ScaleDialog.xaml.cs`

---

## Session 36 — Changes (archived)

### Branch `feat/glue-tab-editor` (off `main` @ v0.0.3.C)

| Item | Detail |
|------|--------|
| **NEW: `FlapMode` enum** | `Domain/Models/FlapMode.cs` — 10 values: Default, SwitchPosition, OnOn_ThisSide, OffOn_OtherSide, OffOff_NoFlap, OnOn_BothSides, Border_MountainFold, Border_ValleyFold, Border_NoFold, Border_NoFlap |
| **NEW: `FlapOverride` record** | `Domain/Models/FlapOverride.cs` — `(FlapMode Mode, int PrimaryFaceId=-1)` with `Serialize()`/`Deserialize()` |
| **`UnfoldedFace.MeshEdgeIds`** | Optional `int[]` param (last ctor arg) so generator can resolve meshEdgeId; default `[-1,-1,-1]` |
| **`GlueTab.BorderFoldStyle`** | Optional `FlapMode?` for fold annotation on border tabs |
| **`ProjectState.FlapOverrides`** | `Dictionary<int, string>` — key=meshEdgeId, value=`FlapOverride.Serialize()` |
| **`UnfoldEngine`** | Populates `UnfoldedFace.MeshEdgeIds` from `mesh.Faces[faceId].EdgeIds.ToArray()` |
| **`GlueTabGenerator` rewrite** | New `flapOverrides` param; full switch-based override logic; border-edge tab generation via `Border_*` modes; `BuildTab/Trapezoid/Rect/Triangle` gain `FlapMode? borderFoldStyle` |
| **`UnfoldService`** | Both `Unfold()` + `TryBuildFromPdoLayout()` gain optional `flapOverrides` arg |
| **`MainViewModel`** | `_flapOverrides` dict; `EditSnapshot` expanded to 3 fields; `TakeSnapshot`/`RestoreSnapshot`/`PushDragUndo` updated; `RerunUnfold` threads overrides; `RestoreProjectState`/`BuildProjectState` persistence; public API: `SetFlapOverride`, `ResetAllFlapOverrides`, `GetFlapOverride`, `ApplyGlobalTabShape`, `OpenEditFlapsCommand` |
| **NEW: `EditFlapsViewModel`** | `ActiveTabIndex`, `FlapEditActive`, Shape fields (HeightMm/Angles), `InnerEdgeOptions`/`BorderEdgeOptions` static lists; `ApplyToEdge(meshEdgeId, isBoundary, faceId)`; `ApplyShapeToAllCommand`; `ResetToDefaultCommand` |
| **NEW: `EditFlapsDialog`** | Modeless 340×300 window; Shape(S) + Position(Q) tabs; ComboBoxes bound to static `FlapOptionItem` lists (WPF requires named properties, not tuples) |
| **`PatternCanvasControl`** | `EdgeTag.IsBoundary`; `SetFlapEditMode(EditFlapsDialog?)`; boundary edges now get `Edge_LeftClick` handler; `Edge_LeftClick` intercepts to dialog when `FlapEditActive` |
| **`MainWindow`** | ✂ toolbar button (after 🎬); `EditFlapsButton_Click` singleton; closes dialog on unfold reset |
| **UI fixes** | Unfold icon ⚙→📐 (distinct from Settings ⚙); `WindowState="Maximized"` |

### Bug fixes identified in cross-review (session 36)

| ID | Severity | Status | Description |
|----|----------|--------|-------------|
| **TD-36-1** | 🟡 Medium | 🔲 open | No unit tests for `FlapMode`/`FlapOverride` round-trip + `GlueTabGenerator` border-tab modes |
| **TD-36-2** | 🟢 Low | 🔲 open | `EditFlapsViewModel` hardcodes default H=5mm/45° — no fallback read from `AppSettings` when settings load fails |
| **TD-36-3** | 🟢 Low | 🔲 open | `FlapOverride.Deserialize` silently ignores corrupt project file entries; should log warning |
| **Performance** | 🟢 Low | 🔲 open | O(n²) overlap check (AABB + SAT); spatial grid needed for meshes > 2000 faces |

---

## Session 35 — Changes (archived summary)

| Item | Detail |
|------|--------|
| **BUG-PDO-3 fix** | `RunAutoArrange` rot=90 formula: `localX - (-minY)` → `localX + minY + hNat`; PDO pieces no longer placed off-screen |
| **Defensive guard** | `PatternCanvasControl`: `ScrollToShowPiece` centers viewport on selected piece |
| **Published v0.0.3.C** | Self-contained win-x64 exe |

---

## Remaining Tech Debt

| ID | Priority | Status | Description |
|----|----------|--------|-------------|
| **TD-36-1** | 🟡 Med | 🔲 open | No unit tests for FlapMode/FlapOverride serialization + GlueTabGenerator border modes |
| **TD-36-2** | 🟢 Low | 🔲 open | EditFlapsViewModel default values hardcoded (5mm / 45°); not wired to AppSettings fallback |
| **TD-36-3** | 🟢 Low | 🔲 open | FlapOverride.Deserialize: silent ignore on corrupt data — add warning/logging |
| **Performance** | 🟢 Low | 🔲 open | O(n²) AABB+SAT overlap check; spatial grid for meshes > 2000 faces |

---

## File Inventory (~77 source files, ~7 400 lines)

```
Domain/Models/          Vertex Edge EdgeType Face Mesh PaperSizeModel ModelScale
                        EmbeddedTextureData FlapMode FlapOverride             ← NEW s36
Domain/DualGraph/       DualGraph GraphNode GraphEdge
Domain/Results/         UnfoldedFace GlueTab UnfoldResult AssemblyStep        ← MeshEdgeIds, BorderFoldStyle added
Domain/Settings/        AppSettings (View3D View2D Print General)
Domain/Persistence/     ProjectState                                           ← FlapOverrides added

Geometry/Algorithms/    DualGraphBuilder KruskalMstBuilder EdgeMarker
                        UnfoldEngine OverlapDetector GlueTabGenerator          ← rewritten s36
                        PieceComputer AssemblyPlanner PieceFoldTree

Application/Interfaces/ IMeshLoader IExporter
Application/Services/   MeshService UnfoldService ProjectSerializer SettingsService ← flapOverrides threaded s36

Infrastructure/         ObjMeshLoader AssimpMeshLoader MultiFormatMeshLoader
                        PdoMeshLoader SvgExporter PdfExporter AffineTransformHelper

App/ViewModels/         MainViewModel PieceViewModel SettingsViewModel
                        MaterialTextureViewModel AssemblyViewModel ModelOrientationViewModel
                        EditFlapsViewModel                                      ← NEW s36
App/Controls/           PatternCanvasControl                                   ← FlapEditMode s36
App/Dialogs/            UnfoldSetupDialog SettingsDialog TextureDialog
                        AssemblyAnimationWindow ModelOrientationDialog
                        EditFlapsDialog                                         ← NEW s36
App/Converters/         HexColorBrushConverter
App/Services/           ThemeService
App/Themes/             LightTheme.xaml DarkTheme.xaml
App/                    MainWindow App

Tests/                  MstAlgorithmTests (6)  UnfoldEngineTests (9)
                        GeometryAlgorithmTests (13)  SvgExporterTests (5)
                        PdoMeshLoaderTests (7)  PdoUnfoldBuilderTests (11)    ← 56 total
```

---

## PDO Format Reference (PD6) — see BUGS_HISTORY.md

---

## Recommended Next Steps

1. **Merge `feat/pepakura-features` → `feat/glue-tab-editor` → `main`** — stable at v0.0.7.A
2. **TD-38-1/2** — Add Outline Padding + Merge Adjacent Flaps (need Clipper2 library)
3. **TD-36-1** — Add unit tests for FlapOverride serialization + GlueTabGenerator border modes
4. **Performance** — Spatial grid for `OverlapDetector`; bottleneck on meshes > 2000 faces
