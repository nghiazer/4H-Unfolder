# 4H-Unfolder

Papercraft / pepakura unfolder — unfolds 3D meshes (.obj, .pdo) to flat paper patterns with glue tabs, fold-line annotations, and SVG/PDF export.

---

## Repository Layout

```
4H-Unfolder/
├── 4h-unfolder-win/          WPF / .NET 8 — Windows native app (production)
└── 4h-unfolder-mac-swift/    Swift / SwiftUI / SceneKit — macOS native app (in development)
```

---

## Platforms

| Platform | Tech Stack | Version | Status |
|----------|------------|---------|--------|
| Windows | WPF · .NET 8 · C# | v0.1.0.A | Production |
| macOS | Swift 5.9 · SwiftUI · SceneKit · Metal | v0.1.0-alpha | In Development |

---

## Features

- **3D Mesh Import** — `.obj` (with MTL materials) and Pepakura `.pdo` format
- **Auto-Unfold** — Kruskal MST on face-adjacency dual graph → BFS face placement in 2D
- **Glue Tabs** — Trapezoid / Rectangle / Triangle, per-edge FlapMode overrides
- **Interactive 2D Canvas** — edge toggle (fold ↔ cut), piece drag, zoom/pan, grid snap
- **3D Viewer** — SceneKit (Metal) with UV texture mapping, multi-material support
- **Export** — SVG (vector, with UV texture overlay), PDF (multi-page, print-ready)
- **Project Bundles** — `.4hu` self-contained ZIP (mesh + textures + overrides)

---

## Windows Build & Run

```powershell
cd 4h-unfolder-win
dotnet restore
dotnet build
dotnet run --project src/FourHUnfolder.App
dotnet test tests/FourHUnfolder.Tests    # 56 tests
```

See [4h-unfolder-win/README.md](4h-unfolder-win/README.md) for full documentation.

---

## macOS Build & Run

> **Requires Xcode 15+** — open `Package.swift` via `File → Open` in Xcode, then press ⌘R.

```bash
# Command-line build (no GUI):
cd 4h-unfolder-mac-swift
swift build
```

### macOS Architecture

```
Sources/FourHUnfolder/
├── Core/
│   ├── Math/         SIMD geometry utilities (TriangleApex, ReconstructApex, dihedral angle)
│   ├── Models/       Mesh, Face, Edge, UnfoldResult, GlueTab, FlapOverride, AppSettings
│   ├── Graph/        DualGraph, GraphNode, GraphEdge, UnionFind
│   └── Algorithms/   UnfoldEngine, KruskalMSTBuilder, GlueTabGenerator, OverlapDetector
├── IO/
│   ├── Loaders/      ObjMeshLoader, PdoMeshLoader (binary, zlib textures)
│   └── Exporters/    SVGExporter, PDFExporter
├── Services/         UnfoldService (actor), ProjectSerializer (.4hu ZIP)
├── State/            AppState (@MainActor), undo/redo stack
└── Views/
    ├── Canvas2D/     PatternCanvasView (10-layer SwiftUI Canvas, edge interaction)
    ├── Viewport3D/   SceneKitView + SceneBuilder (multi-material, UV textures)
    └── Sidebar/      SidebarView, settings controls
```

---

## Algorithm Overview

```
Load Mesh (.obj / .pdo)
    ↓
Build Dual Graph       ← one node per face; edge weight = dihedral angle
    ↓
Kruskal MST            ← sort edges by curvature; Union-Find; prefer flat surfaces
    ↓
Apply Edge Overrides   ← user can manually toggle fold ↔ cut per edge
    ↓
Mark Edge Types        ← Fold / Cut / Boundary
    ↓
BFS Unfold             ← place root face; unfold children via TriangleApex / ReconstructApex
    ↓
Generate Glue Tabs     ← Trapezoid / Rectangle / Triangle; FlapMode per edge
    ↓
Detect Overlaps        ← spatial grid + AABB + SAT
    ↓
Compute Pieces         ← Union-Find over fold edges → paper piece groups
    ↓
UnfoldResult           ← 2D faces (mm) · tabs · overlap flag · piece lists
```

---

## License

[MIT](LICENSE)
