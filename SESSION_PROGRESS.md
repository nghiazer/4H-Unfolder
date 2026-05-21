# PepakuraClone — Session Progress Log

> **Last updated:** 2026-05-22  
> **Branch:** `feat/paper-model-unfolder`  (PR #1 open against `main`)
> **Target framework:** .NET 8 / WPF  
> **SDK required:** `winget install Microsoft.DotNet.SDK.8`

---

## Quick-start

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
Domain → Geometry → Application → Infrastructure → App
```
No circular dependencies. Domain has zero external dependencies.

---

## Complete Feature List

### Core pipeline
| Step | Class | Notes |
|------|-------|-------|
| OBJ load | `ObjMeshLoader` | v/vt/f, MTL map_Kd, fan-triangulation, negative-index guard |
| Dual graph | `DualGraphBuilder` | Dihedral-angle weights; zero-area face guard |
| MST | `KruskalMstBuilder` | Kruskal + path-compressed Union-Find |
| Edge marking | `EdgeMarker` | Fold / Cut / Boundary |
| Unfold | `UnfoldEngine` | BFS circle-circle apex; disconnected components |
| Overlap | `OverlapDetector` | AABB pre-check + SAT |
| Tabs | `GlueTabGenerator` | Trapezoidal, tagged with FaceId |
| Pieces | `PieceComputer` | Union-Find connected components |
| SVG | `SvgExporter` | Edge-deduplicated; settings-driven; grayscale support |

### UI features
- Split 3D/2D viewport (2D hidden until after first Unfold)
- 3D mouse picking: left-click face → selection overlay (yellow, z-offset) + 2D highlight
- Right-click 3D face → Detach face / Detach piece / Attach to neighbour
- Bidirectional 3D↔2D sync (clicking 2D piece updates 3D overlay)
- Interactive 2D canvas: drag pieces, rotate ±90°, flip H, auto-arrange
- Grid toggle (fast-path, no rebuild) + Snap to grid
- Texture load/replace/remove with live preview (Apply/Cancel)
- Unfold setup dialog: real-world scale + paper size
- Save/Load `.pmc` project (edge overrides + piece layouts + scale)
- Export SVG

### Settings (4-panel dialog)
| Section | Key options |
|---------|------------|
| 3D View | Background, display mode, face/back color, opacity, edge overlay, lighting, camera FOV/clip |
| 2D View | Canvas/paper color, grid show+size+color, fold/cut colors+widths+dash, glue tabs, face numbers, piece gap, snap-to-grid, default zoom |
| Print | Margin, bleed, SVG scale, include tabs/fold/cut/label, grayscale, print line colors |
| General | **Display unit: mm / inch** |

---

## All Bugs Fixed (cumulative)

| Session | Severity | Bug | Fix |
|---------|----------|-----|-----|
| 1 | Critical | `PatternCanvasControl` drag broken — wrong mouse-capture element | `RootCanvas.CaptureMouse()` |
| 1 | Critical | Project save wrote `ScaleMmPerUnit = 1.0` hardcoded | Use `_currentScaleMmPerUnit` |
| 1 | High | Compile error — `MainWindow.xaml.cs` missing `using System.Linq` | Added import |
| 1 | High | `UnfoldSetupDialog` custom-size boxes always disabled (self-ref binding) | Code-behind only |
| 1 | Medium | `CommitPreview` had identical ternary branches | Clarified logic |
| 1 | Low | Degenerate triangles produced NaN normals → poisoned MST weights | Guard in `DualGraphBuilder` |
| 1 | Low | OBJ negative vertex indices not handled | Return -1 |
| 2 | Critical | `SettingsDialog.xaml` — 4 StackPanels as direct children of ScrollViewer (ContentControl allows only one) | Wrapped in `<Grid>` |
| 2 | High | `SettingsViewModel.DisplayUnits` contained `"mm (millimetre)"` but stored value is `"mm"` → ComboBox always blank | Changed list to `["mm", "inch"]` |
| 2 | Medium | `PatternCanvasControl._vm!.GridVisible` — null-forgiving could throw | Replaced with null-conditional guard |
| 2 | Low | `SvgExporter` face fill not greyed when `GrayscaleOutput = true` | CSS fill driven by setting |

---

## Tech Debt Status

### Resolved this session
| ID | Was | Resolution |
|----|-----|-----------|
| TD-2 | Shared edges drawn twice in 2D canvas | `HashSet<int>` dedup by mesh edge ID |
| TD-3 | O(n²) SAT — slow on large meshes | AABB pre-check rejects non-overlapping pairs |
| TD-4 | Memory leak in PatternCanvasControl (dangling PropertyChanged handlers) | Explicit subscription dict + unsubscribe on rebuild |
| TD-5 | Selection overlay rebuilt on every click | Frozen `Model3DGroup` cache per group ID |
| TD-6 | SVG fold/cut lines drawn twice per shared edge | Canonical-key HashSet dedup |

### Still open (LOW priority)
| ID | Location | Description |
|----|----------|-------------|
| TD-1 | `UnfoldService` | Fold-edge cycles from user overrides don't affect correctness (BFS skips visited), but are displayed as fold in 2D even though they don't contribute to connectivity |
| TD-7 | `PatternCanvasControl` | Pieces rendered as individual triangles, not merged outlines → interior edges visible on solid pieces |
| TD-8 | `SvgExporter` | Texture not embedded in SVG |
| TD-9 | App-wide | No undo/redo stack for join/split/detach |

---

## File Inventory (57 source files, ~4 700 lines)

```
Domain/Models/          Vertex Edge EdgeType Face Mesh PaperSizeModel ModelScale
Domain/DualGraph/       DualGraph GraphNode GraphEdge
Domain/Results/         UnfoldedFace GlueTab UnfoldResult
Domain/Settings/        AppSettings (View3D View2D Print General)
Domain/Persistence/     ProjectState

Geometry/Algorithms/    DualGraphBuilder KruskalMstBuilder EdgeMarker
                        UnfoldEngine OverlapDetector GlueTabGenerator PieceComputer

Application/Interfaces/ IMeshLoader IExporter
Application/Services/   MeshService UnfoldService ProjectSerializer SettingsService

Infrastructure/         ObjMeshLoader SvgExporter

App/ViewModels/         MainViewModel PieceViewModel SettingsViewModel
App/Controls/           PatternCanvasControl
App/Dialogs/            UnfoldSetupDialog SettingsDialog
App/Converters/         HexColorBrushConverter
App/                    MainWindow App

Tests/                  MstAlgorithmTests (6) UnfoldEngineTests (9)
```

---

## Recommended Next Steps

1. **Install .NET 8 SDK** and verify `dotnet build` passes
2. **Merge PR #1** on GitHub: <https://github.com/nghiazer/PepakuraClone/pull/1>
3. Fix **TD-7** (merged piece outlines) — biggest visual quality win
4. Add **PDF export** via `PdfSharp`
5. Add **undo/redo** using `ICommand` history stack
6. Performance: replace O(n²) overlap check with spatial grid for meshes > 2 000 faces
7. Add **auto-unfolding heuristic** (strip-packing aware piece placement)
