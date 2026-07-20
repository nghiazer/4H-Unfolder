# 4H-Unfolder — Session Progress Log

> **Last updated:** 2026-06-04 (session 42 — macOS port Phase 1; branch `feat/mac-port`)
> **Branch:** `feat/mac-port`
> **Target framework:** .NET 8 / WPF (Windows) + Tauri 2 / React 18 / Rust (macOS)
> **SDK required (Windows):** `winget install Microsoft.DotNet.SDK.8`
> **SDK required (macOS):** See [`4h-unfolder-mac/SETUP.md`](4h-unfolder-mac/SETUP.md)
> **History archive:** see [`BUGS_HISTORY.md`](BUGS_HISTORY.md) for all prior bug/tech-debt records

---

## macOS Port — `4h-unfolder-mac/` (Tauri 2 + React 18 + Rust)

### Migration Plan
Full plan: [`~/.claude/plans/quiet-squishing-beaver.md`] — 6 phases, ~27–30 sessions total.

### Phase 1 — Rust Algorithm Core ✅ COMPLETE (session 42)

**Goal:** Rust pipeline produces bit-for-bit equivalent output to C# for all test meshes.

#### Data model fixes (critical divergences resolved)
| Component | Fix |
|-----------|-----|
| `models/mesh.rs` | Added `EdgeType` enum, `Face.edge_ids [AB,BC,CA]`, `Face.material_id`, `MeshEdge.edge_type`, `PdoLayout`, `EmbeddedTexture` |
| `models/unfold.rs` | Full rewrite: `FlapMode` (10 variants), `FlapOverride` serialize/deserialize matching C#, `UnfoldedFace` with `bool[3]` edge arrays, `GlueTab` P0/P1/P2/P3, `TabShape`, `UnfoldResult`, `PieceLayout`, `UnfoldResponse`, `AssemblyStep` |
| `models/settings.rs` | Expanded with all print/view/general settings fields |

#### Algorithm fixes
| File | Fix |
|------|-----|
| `algorithms/constants.rs` | New: `DEGENERATE_EDGE/FACE/TAB` (1e-6/1e-10/1e-4), `SAT_TOUCH_EPSILON` (1e-5) |
| `algorithms/spanning_tree.rs` | Added `compute_face_normal`, `compute_dihedral_angle` (acos weighted MST), `mark_edges` |
| `algorithms/face_unfold.rs` | **Full rewrite** — BFS + `place_root_face` (law-of-cosines) + `triangle_apex` + `reconstruct_apex` (cross-product side test) + `place_child_face`; replaces wrong DFS+face-normal-basis approach |
| `algorithms/glue_tabs.rs` | **Full rewrite** — 10-mode FlapMode dispatch, Trapezoid/Rect/Triangle shapes, AlternateFlaps deny-set, proper `face.mesh_edge_ids[i]` edge lookup (replaces wrong `edge_id % n`) |
| `algorithms/layout.rs` | Updated to use new `PieceLayout` + `UnfoldedFace` structs |

#### Command fixes
| File | Fix |
|------|-----|
| `commands/mesh.rs` | `build_edges()` stamps `face.edge_ids` in winding order [AB,BC,CA]; non-manifold guard; `tobj` parse with UVs + materials + MTL texture paths |
| `commands/unfold.rs` | **Full rewrite** — 11-step pipeline matching `UnfoldService.Unfold()`: dihedral MST → edge overrides → mark edges → BFS unfold → overlap stub → glue tabs → cut pair IDs → dihedral angles → pieces → auto-arrange → `UnfoldResponse` |
| `commands/export.rs` | Updated to use `UnfoldResponse` instead of old `UnfoldResult` |
| `commands/project.rs` | Expanded `ProjectState`; security hardening (asset whitelist, `Path::file_name()`, version check ≤ 2) |
| `commands/settings.rs` | Updated for expanded `AppSettings` |
| `src-tauri/tauri.conf.json` | Fixed: removed invalid fields (`fileDropEnabled`, `category`), RGBA placeholder icons |

#### TypeScript sync
| File | Fix |
|------|-----|
| `src/types/mesh.ts` | `EdgeType`, `Face.edgeIds[3]`, `Face.materialId`, `MeshEdge.edgeType`, `PdoLayout`, `EmbeddedTexture` |
| `src/types/unfold.ts` | All 10 `FlapMode` variants, `UnfoldedFace` with `edgeIsFold/edgeIsBoundary/meshEdgeIds [3]`, `GlueTab` P0/P1/P2/P3, `UnfoldResponse`, `PieceLayout`, `AssemblyStep`, `UnfoldOptions` |
| `src/types/settings.ts` | Expanded with all print/view settings; `DEFAULT_SETTINGS` updated |
| `src/types/tauri.ts` | Typed wrappers for all commands including new `UnfoldResponse`, `ExportOpts`, `ProjectStateDto` |
| `src/state/unfoldStore.ts` | `edgeOverrides`, `pieceLayouts`, `getEffectivePieceLayouts()`, serialize overrides to Rust format |
| `src/state/settingsStore.ts` | `resetToDefaults()`, uses new `DEFAULT_SETTINGS` |

#### Test results
```
cargo check  → 0 errors, 9 warnings (dead code, used in later phases)
cargo test   → 12/12 pass
  - algorithms::spanning_tree: 3 tests (dihedral angle, MST, edge marking)
  - algorithms::face_unfold:   4 tests (root placement, edge lengths, count, piece_id)
  - algorithms::glue_tabs:     3 tests (Default mode, depth bounds, OffOffNoFlap)
  - commands::mesh:            2 tests (edge_ids winding order, non-manifold guard)
```

#### Test fixtures added
- `src-tauri/tests/fixtures/tetrahedron.obj` — 4 vertices, 4 faces, 6 edges
- `src-tauri/tests/fixtures/cube.obj` — 8 vertices, 12 faces, 18 edges

### Phase 2–6 — Pending
See migration plan for full breakdown. Next: **Phase 2** — OBJ loader completion (UVs, materials, MTL) + `get_mesh_info` command.

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
| `dotnet test` | ✅ 95 / 95 passed (s43: +0 new tests; fixed duplicate class + test helper bug) |
| `dotnet run --project src/FourHUnfolder.App` | ✅ App opens; all features accessible |
| Published `4H-Unfolder.exe` **v0.1.0.A** (win-x64, self-contained) + installer | ✅ Session 40 |

---

## Session 43 — Changes (v0.1.1.A, tech debt cleanup)

### Branch `main` — all remaining open tech debt closed

**Build & Test:** 0 errors · 95/95 tests pass (duplicate `GlueTabGeneratorTests` class removed + test helpers fixed)

#### Bug fix on session start
| File | Fix |
|------|-----|
| `GeometryAlgorithmTests.cs` | Removed duplicate `GlueTabGeneratorTests` class (was shadowing the newer `GlueTabGeneratorTests.cs`; caused CS0101 compile error) |
| `GlueTabGeneratorTests.cs` | Fixed helper `BorderFace`/`CutFace`: edges 1&2 were incorrectly cut instead of fold, causing 7 tests to fail (expected 0–1 tabs but got 2–3) |

#### TD-38-1 — Outline Padding (Clipper2) ✅

| Item | Detail |
|------|--------|
| NuGet | `Clipper2` v2.0.0 (angusj) added to `FourHUnfolder.Geometry.csproj` |
| `BoundaryPolygonComputer.cs` | New static class in Geometry/Algorithms — chains non-fold edges into ordered boundary polygon; deduplicates by meshEdgeId or coord key |
| `OutlinePaddingGenerator.cs` | New static class — inflates a polygon by `paddingMm` via `Clipper.InflatePaths(JoinType.Round, EndType.Polygon)` |
| `AppSettings.PrintSettings.OutlinePaddingMm` | New double (default 0.0 = disabled) |
| `IExporter.cs` | Added optional `paddingPolygons` param to `Export()` |
| `SvgExporter.cs` | New `.padding` CSS class (dashed #404040); emits `<polygon class="padding">` per piece |
| `PatternCanvasControl.xaml.cs` | Refactored `BuildPieceOutline` → `BuildPieceOutlineMm` + `MmToPixels`; draws dashed padding polygon when `OutlinePaddingMm > 0` |
| `MainViewModel.cs` | `ComputePaddingPolygons(UnfoldResult)` helper; `BuildExportLayout` now passes `MeshEdgeIds`; `ExportSvg` passes padding polygons to exporter |
| `SettingsDialog.xaml` | "Outline padding (mm)" slider + textbox in Print → Page Layout group (row 3) |
| `SettingsViewModel.cs` | `OutlinePaddingMm` property wired in `LoadFrom`/`ToSettings` |

#### TD-38-2 — Merge Adjacent Flaps ✅

| Item | Detail |
|------|--------|
| `FlapMerger.cs` | New static class in Geometry/Algorithms — groups tabs by piece via UnionFind on fold edges; finds adjacent pairs (sharing base vertex); Clipper2 `Union` merges their polygons |
| `GlueTab.cs` | Added `_mergedPolygon` backing field + optional `mergedPolygon` ctor param; `Vertices` returns merged polygon when present |
| `PieceViewModel.TabData` | Added `Point[] points` constructor overload; `Create()` now uses `t.Vertices` (supports variable vertex count) |
| `AppSettings.PrintSettings.MergeAdjacentFlaps` | New bool (default false) |
| `UnfoldService.Unfold()` | Calls `FlapMerger.Merge()` after tab generation when setting is enabled |
| `SettingsDialog.xaml` | "Merge adjacent flaps" checkbox (row 9 in Glue Tab section) |
| `SettingsViewModel.cs` | `MergeAdjacentFlaps` property wired |

#### TD-38-3 — Join Adjacent Isolated Edges ✅

| Item | Detail |
|------|--------|
| `MainViewModel.FindAdjacentCutEdgeGroup(meshEdgeId)` | BFS from a given cut edge through shared 2D vertices; returns all reachable cut mesh edge IDs |
| `MainViewModel.JoinEdgeGroup(meshEdgeId)` | Sets all edges in the group to Fold, pushes undo, re-unfolds |
| `PatternCanvasControl.Edge_RightClick` | Added "🔗🔗 Join connected cut edges" menu item for cut edges |

#### TD-36-2 — EditFlapsViewModel defaults ✅ (already done in s36)

Constructor already reads `GlueTabDepthMm`/`GlueTabSideAngleDeg` from `AppSettings` via `mainVm.CurrentPrintSettings`. Closed as stale entry.

---

## Session 41 — Changes (v0.1.0.A, maintenance)

### Branch `main` — refactoring, security hardening, tech-debt cleanup

No new features. No version bump. Pure code quality improvements and security fixes across all layers.

#### Refactoring — DRY extractions

| New file | Extracted from | Reason |
|----------|---------------|--------|
| `UnionFind.cs` | `KruskalMstBuilder` + `PieceComputer` | Both had identical inline Union-Find (path-compress + union-by-rank); extracted to shared class |
| `EdgeKeyHelper.cs` | `SvgExporter` + `PdfExporter` | Both had identical `EdgeKey()` (TD-22-4 canonical edge key); extracted to shared static helper |

#### Refactoring — renames for clarity

| File | Old name | New name | Reason |
|------|----------|----------|--------|
| `OverlapDetector` | `HasSeparatingAxis` | `IsSeparated` | Name now matches what `true` means (triangles don't overlap) |
| `GlueTabGenerator` | `BuildTab/Trapezoid/Rect/Triangle` | `CreateTab/Trapezoid/Rect/Triangle` | Factory naming convention (`Create*` not `Build*`) |
| `UnfoldEngine` | `FindSharedLocalIndices` | `GetSharedVertexLocalIndices` | Clarifies what indices are returned |
| `MainViewModel` | `_faceToGroup` | `_faceToGroupMap` | Makes type intent explicit (it's a dict/map) |
| `MainViewModel` | `_geoFaceIds` | `_geoFaceIdsMap` | Same reason |

#### Tech-debt resolved

| ID | Fix |
|----|-----|
| **TD-36-1** | ✅ Closed — 26 new tests: `FlapOverrideTests` (10), `GlueTabGeneratorTests` (8), `ProjectSerializerTests` (8) |
| **TD-36-3** | ✅ Closed — `FlapOverride.Deserialize` now logs via `Debug.WriteLine` on unrecognised override values |

#### Security fixes

| File | Fix |
|------|-----|
| `ProjectSerializer.FromRelativePath` | Added `AllowedAssetExtensions` whitelist — crafted `.4hu` bundles can no longer point at arbitrary system files via path traversal |
| `ObjMeshLoader` (mtllib) | `Path.GetFileName()` strips any directory component from the MTL filename — prevents reading files outside the OBJ folder |
| `ObjMeshLoader` (face index) | `int.TryParse` replaces `int.Parse` — malformed OBJ face tokens no longer throw uncaught exceptions |

#### Robustness / diagnostics

| File | Improvement |
|------|-------------|
| `SettingsService.Load/Save` | Split bare `catch {}` into typed `catch (JsonException)` / `catch (IOException)` with `Debug.WriteLine` |
| `UnfoldEngine` | Logs malformed-topology face IDs via `Debug.WriteLine` instead of silently placing at origin |
| `HexColorBrushConverter` | Logs invalid hex color strings instead of bare `catch {}` |
| `GeometryConstants` | Added threshold-rationale comments (nm/mm context) to all 4 constants |
| `MainViewModel.ScaleMmPerUnit` | Promoted from auto-property to full property with `OnPropertyChanged(CurrentScaleMmPerUnit)` |

#### Other

- `.editorconfig` added to repository root — standardises indent style, charset, and trailing-whitespace rules across IDEs

---

## Session 40 — Changes (v0.1.0.A)

### Branch `feat/toolbar-cleanup` (continued from s39)

Full toolbar modernization to Windows 11 Fluent Design. **47 unique Segoe Fluent Icons glyphs** replace all emoji/Unicode symbols across both toolbars. No logic or domain changes — UI-only.

#### What changed

| Scope | Detail |
|-------|--------|
| `IconBtn` style | Added `FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets"`, FontSize 20→16 |
| `Icon2D` style | Added `FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets"`, FontSize 19→16 |
| `Toggle2D` style | Added `FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets"`, FontSize 19→16 |
| Main toolbar (25 buttons) | All emoji/symbols → `&#xNNNN;` Segoe Fluent glyph references |
| 2D toolbar (22 buttons) | All emoji/symbols → `&#xNNNN;` Segoe Fluent glyph references |
| FindBar close button | `✕` (U+2715, not a Fluent glyph) → `&#xE711;` (Cancel) — cross-review fix |
| Version | 0.0.7.2 → 0.1.0.1 (minor bump: visual modernization milestone) |

#### Icon mapping reference (main toolbar)
`E838`=Folder `E9B4`=Ruler `E74E`=Save `E8A5`=Document `E792`=SaveLocal `E8E0`=Import `E713`=Settings `E7A7`=Undo `E7A6`=Redo `E2B1`=Color `E8B2`=Video `E74B`=Cut `E9A9`=Resize `E7B8`=Flip `E8A4`=ZoomFit `E71E`=Zoom `E8B3`=SelectAll `F168`=Group `F169`=Ungroup `E72C`=Refresh `E8CC`=Snip `E8C8`=Copy `E8D5`=ViewAll `E8C4`=Tiles `E81C`=Ruler2

#### Icon mapping reference (2D toolbar)
`E7AD`=RotateCCW `E7AC`=RotateCW `E8C0`=AlignLeft `E8C1`=AlignCenterV `E8C2`=AlignRight `E8C3`=AlignTop `E8C6`=AlignBottom `E8C5`=AlignCenterH `E9B5`=LayoutGrid `E813`=Pin `E70F`=Edit `E80A`=GridView `E8CF`=Magnet `E81B`=Triangle `E8B9`=Photo `E8F3`=Strikethrough `E8D6`=Tag `E9D9`=NumberField `E749`=Print `E721`=Search `EB9F`=AddPhoto `E894`=Remove

---

## Session 39 — Changes (v0.0.7.B)

### Branch `feat/toolbar-cleanup` (off `feat/pepakura-features` @ v0.0.7.A)

Toolbar deduplication and reorganization. No logic/domain changes — UI-only.

#### Problems fixed

| Category | Problem | Fix |
|----------|---------|-----|
| Exact duplicate | 📐 Unfold appeared twice in main toolbar | Removed second occurrence |
| Exact duplicate | 💾 Export SVG appeared twice in main toolbar | Removed second occurrence |
| Exact duplicate | 📑 Export PDF appeared twice in main toolbar | Removed second occurrence |
| Same icon conflict | 📂 = both Load Mesh and Load Project | Load Project → 📥 |
| Same icon conflict | ✂ = both Edit Flaps and Reset Cutline Edges | Edit Flaps → ✄ (U+2704) |
| Same icon conflict | ⊞ = both Fit Page (main) and Grid Toggle (2D) | Fit Page → ⤢ (U+2922) |
| Misplaced in main | ⬛ Apply Print Transparency | Moved to 2D toolbar as ToggleButton |
| Misplaced in main | 🔍 Find Part | Moved to 2D toolbar |
| Misplaced in main | 🗺 Insert Image | Moved to 2D toolbar |
| Misplaced in main | ✕🗺 Remove Inserted Image | Moved to 2D toolbar |

#### Files changed
- `MainWindow.xaml`: 3 duplicates removed, 3 icon conflicts fixed, 4 misplaced buttons removed, Title → v0.0.7.B
- `PatternCanvasControl.xaml`: 4 buttons added at end of 2D toolbar (⬛🔍🗺✕🗺)
- `PatternCanvasControl.xaml.cs`: 4 click handlers added (`PrintTrans_Click`, `Find_Click`, `InsertImage_Click`, `RemoveImage_Click`)
- `FourHUnfolder.App.csproj`: Version → 0.0.7.2

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
| **TD-36-1** | 🟡 Med | ✅ closed (s41) | Unit tests added: FlapOverride (10), GlueTabGenerator (8), ProjectSerializer (8) |
| **TD-36-2** | 🟢 Low | ✅ closed (s43) | Already wired in s36: constructor reads GlueTabDepthMm/GlueTabSideAngleDeg from AppSettings |
| **TD-36-3** | 🟢 Low | ✅ closed (s41) | FlapOverride.Deserialize now logs corrupt entries via Debug.WriteLine |
| **TD-38-1** | 🔴 High | ✅ closed (s43) | Outline Padding: Clipper2Lib NuGet + OutlinePaddingGenerator + BoundaryPolygonComputer + settings + canvas dashed outline + SVG `.padding` class |
| **TD-38-2** | 🔴 High | ✅ closed (s43) | Merge Adjacent Flaps: FlapMerger (Clipper2 union) + GlueTab.MergedPolygon + AppSettings.MergeAdjacentFlaps + Settings UI checkbox |
| **TD-38-3** | 🟡 Med | ✅ closed (s43) | Join Adjacent Isolated Edges: FindAdjacentCutEdgeGroup (BFS) + JoinEdgeGroup in MainViewModel + "Join connected cut edges" right-click menu item |
| **Performance** | 🟢 Low | ✅ closed (s40-old) | Spatial grid OverlapDetector (uniform bucket partition) — already done, stale entry |

---

## File Inventory (~82 source files, ~7 800 lines)

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
                        UnionFind                                              ← NEW s41

Application/Interfaces/ IMeshLoader IExporter
Application/Services/   MeshService UnfoldService ProjectSerializer SettingsService ← flapOverrides threaded s36

Infrastructure/         ObjMeshLoader AssimpMeshLoader MultiFormatMeshLoader
                        PdoMeshLoader SvgExporter PdfExporter AffineTransformHelper
                        EdgeKeyHelper                                          ← NEW s41

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
                        PdoMeshLoaderTests (7)  PdoUnfoldBuilderTests (11)
                        FlapOverrideTests (10)  GlueTabGeneratorTests (8)    ← NEW s41
                        ProjectSerializerTests (8)                            ← NEW s41 — 82 total
```

---

## PDO Format Reference (PD6) — see BUGS_HISTORY.md

---

## Recommended Next Steps

All recorded tech debt is now closed. Possible next directions:
1. **Print-to-PDF padding** — expose `OutlinePaddingMm` in PDF export (currently SVG-only)
2. **Test coverage** — unit tests for FlapMerger, BoundaryPolygonComputer, OutlinePaddingGenerator
3. **Select Symmetrical Pair** (TD-38-4) — mesh symmetry detection
4. **Split Window** (TD-38-5) — multi-viewport WPF layout
