# PepakuraClone

A Pepakura-style paper model unfolder built with **WPF / .NET 8**.  
Load a 3-D OBJ mesh, unfold it into a printable 2-D pattern, customise the layout, and export to SVG.

---

## Screenshots

> _Run the app and load `tetrahedron.obj` (sample at the bottom of this file) to see the split viewport._

---

## Prerequisites

| Requirement | Download |
|-------------|---------|
| .NET 8 **SDK** | <https://dotnet.microsoft.com/download/dotnet/8.0> |
| Windows 10/11 (WPF) | — |

> The machine may already have the .NET 8 *runtime*; the **SDK** is also needed to compile.

---

## Build & Run

```bash
# from the solution root
dotnet restore
dotnet build
dotnet run --project src/PepakuraClone.App
```

### Run tests

```bash
dotnet test tests/PepakuraClone.Tests
```

---

## Features

### Load & display
- Import **Wavefront OBJ** files (v, vt, f with v/vt/vn tokens, n-gon fan-triangulation)
- Auto-loads associated **texture** from the companion `.mtl` file (`map_Kd`)
- Interactive **HelixToolkit 3-D viewport** — LMB orbit, MMB pan, scroll zoom

### Texture management
- Load / replace / remove texture with **live preview** before committing
- Preview shown in both the 3-D viewport and a thumbnail strip
- Orange border + badge indicates active preview mode; **Apply / Cancel** to confirm

### Unfold
- Click **Unfold** → **setup dialog** appears first:
  - Choose the real-world target size (axis + value + unit: mm/cm/inch)
  - Choose paper size (A4 / A3 / A2 / A1 / Letter / Legal / Custom, Portrait or Landscape)
- Unfold algorithm: dual-graph MST (Kruskal) → BFS triangle flattening
- MST edges = **Fold** (dashed blue), non-MST = **Cut** (solid red)
- Trapezoidal **glue tabs** generated on every cut edge

### Interactive 2-D layout canvas
| Action | Result |
|--------|--------|
| Drag piece | Moves the piece on the paper |
| Right-click edge | Context menu: **Join pieces** (Cut→Fold) or **Split piece** (Fold→Cut) |
| Select piece | Highlights the corresponding faces in the 3-D viewport |
| Toolbar: Rotate ±90° / Flip H | Rotates or mirrors selected piece |
| Toolbar: Auto-arrange | Row-packs all pieces onto the paper using the configured gap |

### 3-D face selection + Detach / Attach
| Action | Result |
|--------|--------|
| Left-click face (3-D) | Selects face; highlights its piece (yellow overlay) + matching 2-D piece |
| Right-click face (3-D) | Context menu: **Detach this face** / **Detach entire piece** / **Attach to face N** |
| Click piece (2-D) | Updates 3-D selection overlay — bidirectional sync |

### Settings (`⚙ Settings` button)
Three sections, all persisted to `%AppData%\PepakuraClone\settings.json`:

| Section | Notable options |
|---------|----------------|
| **3D View** | Background color · Display mode (Solid / SolidEdges / Wireframe) · Face & back-face color · Face opacity · Edge overlay · Ambient/directional light · **Camera FOV + near/far clip planes** |
| **2D View** | Canvas & paper color · Grid show/size/color · Face fill · Fold/cut line color+width+dash · Glue tab color · Show face numbers · **Piece gap (mm)** · Default zoom |
| **Print/Export** | Page margin · Bleed · SVG scale factor · Include tabs/fold lines/cut lines · Page label · Grayscale · Print-specific line colors & widths |

### Save / Load project (`.pmc`)
- Saves: mesh path, texture path, real-world scale, paper size, all edge overrides, piece positions & rotations
- Paths stored as `relative|absolute` for portability
- On load: re-runs unfold with saved overrides, then restores piece layout

### Export SVG
- Produces a standalone `.svg` with face fills, dashed fold lines, solid cut lines, and green glue tabs
- All colors, line widths, margins, and content switches driven by **Print Settings**

---

## Architecture

```
PepakuraClone.sln
├── src/
│   ├── PepakuraClone.Domain          # Pure models — no external deps
│   │   ├── Models/        Vertex, Edge (EdgeType), Face, Mesh
│   │   │                  PaperSizeModel, ModelScale
│   │   ├── DualGraph/     DualGraph, GraphNode, GraphEdge
│   │   ├── Results/       UnfoldedFace, GlueTab, UnfoldResult
│   │   ├── Settings/      AppSettings (View3D + View2D + Print)
│   │   └── Persistence/   ProjectState (JSON DTO)
│   │
│   ├── PepakuraClone.Geometry        # Algorithms (→ Domain)
│   │   └── Algorithms/    DualGraphBuilder, KruskalMstBuilder, EdgeMarker,
│   │                       UnfoldEngine, OverlapDetector,
│   │                       GlueTabGenerator, PieceComputer
│   │
│   ├── PepakuraClone.Application     # Use-case services (→ Domain, Geometry)
│   │   ├── Interfaces/    IMeshLoader, IExporter
│   │   └── Services/      MeshService, UnfoldService,
│   │                       ProjectSerializer, SettingsService
│   │
│   ├── PepakuraClone.Infrastructure  # I/O (→ Domain, Application)
│   │   ├── Loaders/       ObjMeshLoader
│   │   └── Exporters/     SvgExporter
│   │
│   └── PepakuraClone.App             # WPF UI (→ Application, Infrastructure)
│       ├── ViewModels/    MainViewModel, PieceViewModel, SettingsViewModel
│       ├── Controls/      PatternCanvasControl
│       ├── Dialogs/       UnfoldSetupDialog, SettingsDialog
│       ├── Converters/    HexColorBrushConverter
│       └── MainWindow.xaml
│
└── tests/
    └── PepakuraClone.Tests           # xunit + FluentAssertions
        ├── MstAlgorithmTests.cs      (6 tests)
        └── UnfoldEngineTests.cs      (9 tests)
```

### Dependency graph

```
Domain ─→ Geometry ─→ Application ─→ Infrastructure ─→ App
                                                        ↑
                                            HelixToolkit.WPF
                                            CommunityToolkit.Mvvm
                                            Microsoft.Extensions.DependencyInjection
```

---

## Unfold pipeline

| Step | Class | What it does |
|------|-------|-------------|
| 1 | `ObjMeshLoader` | Parse `.obj`, build `Mesh` with canonical edge-adjacency map, read MTL texture path |
| 2 | `DualGraphBuilder` | One node per face; one edge per shared interior mesh edge, weighted by dihedral angle |
| 3 | `KruskalMstBuilder` | Kruskal + path-compressed Union-Find → minimum spanning tree |
| 4 | `EdgeMarker` | MST → Fold; non-MST interior → Cut; boundary → Boundary |
| 5 | `UnfoldEngine` | BFS flattening; circle–circle apex reconstruction; supports multiple disconnected pieces |
| 6 | `OverlapDetector` | O(n²) SAT — sets `UnfoldResult.HasOverlaps` |
| 7 | `GlueTabGenerator` | Trapezoidal tabs on cut edges (tagged with `FaceId + LocalEdgeIdx`) |
| 8 | `PieceComputer` | Union-Find on fold graph → connected components (pieces) |
| 9 | `SvgExporter` | Scaled SVG driven entirely by `AppSettings.PrintSettings` |

---

## NuGet packages (App project)

| Package | Version | Purpose |
|---------|---------|---------|
| `HelixToolkit.WPF` | 2.25.0 | 3-D viewport with built-in orbit/pan/zoom |
| `CommunityToolkit.Mvvm` | 8.3.2 | Source-generated `[ObservableProperty]` / `[RelayCommand]` |
| `Microsoft.Extensions.DependencyInjection` | 8.0.1 | Constructor injection for all services |

---

## File formats

| Format | Role |
|--------|------|
| `.obj` | Input — Wavefront OBJ mesh (v, vt, f) |
| `.mtl` | Optional companion — diffuse texture path (`map_Kd`) |
| `.png/.jpg/.bmp` | Texture images |
| `.pmc` | PepakuraClone project — JSON snapshot of the full editing session |
| `.svg` | Export — printable 2-D pattern |

---

## Quick test — tetrahedron

Save the following as `tetrahedron.obj` and open it with **Load Mesh**:

```
# Simple tetrahedron
v  0.0  0.0  0.0
v  1.0  0.0  0.0
v  0.5  1.0  0.0
v  0.5  0.5  1.0
f 1 2 3
f 1 2 4
f 2 3 4
f 1 3 4
```

Expected result after **Unfold** (A4, 200 mm longest axis):
- 4 triangular faces unfolded flat
- 3 fold edges (dashed blue), 3 cut edges (solid red) across the 4-face pattern
- 3 glue tabs visible in the 2-D canvas

---

## Known limitations

- Overlap detection is O(n²) — may be slow on meshes with > 500 faces
- Unfolding does not auto-resolve overlaps; manual piece repositioning is required
- OBJ negative vertex indices (relative indexing) are treated as absent
- Texture is not embedded in the SVG export
