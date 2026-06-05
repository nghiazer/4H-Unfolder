# 4H-Unfolder macOS — Progress Tracker

## Build

```bash
# Requires Xcode 15+ installed (NOT just Command Line Tools)
cd 4h-unfolder-mac-swift
swift build

# Open in Xcode (recommended):
# File → Open → select Package.swift → Product → Run (⌘R)

# Tests: run in Xcode → Product → Test (⌘U)
# Note: swift test does NOT work (XCTest requires full Xcode SDK)
```

---

## Phase Completion

| Phase | Description | Status | Commit |
|-------|-------------|--------|--------|
| 1 | Core architecture + algorithm layer (UnionFind, DualGraph, Kruskal, UnfoldEngine, GlueTabGenerator, OverlapDetector, EdgeMarker, PieceComputer) | ✅ Done | `5294cc8` |
| 2 | PDO binary parser (v3 format, embedded zlib textures, subtraction cipher) | ✅ Done | `5294cc8` |
| 3 | UnfoldService actor + ProjectSerializer (.4hu ZIP bundle) | ✅ Done | `5294cc8` |
| 4 | PatternCanvasView (interactive 2D canvas) + SceneKitView (Metal 3D viewport) | ✅ Done | `5294cc8` |
| 5 | SVGExporter + PDFExporter + ObjMeshLoader (MTL parsing, UV coords) | ✅ Done | `5294cc8` |
| 6 | FourHUnfolderCore library target (SPM split) + 53 unit tests | ✅ Done | `773504d` |
| 7 | Native menus, paper size picker, auto-arrange pieces, status bar | ✅ Done | `c0a66a4` |
| 8 | Multi-material + UV texture rendering (3D viewport + 2D canvas) | ⏳ Planned | — |
| 9 | Piece drag (manual positioning), Preferences window, app polish | ⏳ Planned | — |
| 10 | Tech debt sprint (stubs, typo fixes, test coverage, code split) | ⏳ Planned | — |

---

## Feature Status vs Windows Version

| Feature | Windows (WPF) | macOS (Swift) |
|---------|---------------|---------------|
| OBJ mesh loading | ✅ | ✅ |
| PDO mesh loading (v3) | ✅ | ✅ |
| Kruskal MST unfold pipeline | ✅ | ✅ |
| Edge toggle fold ↔ cut | ✅ | ✅ |
| Glue tabs (Trapezoid / Rectangle / Triangle) | ✅ | ✅ |
| 10 FlapMode variants per edge | ✅ | ✅ |
| Overlap detection (spatial grid + SAT) | ✅ | ✅ |
| SVG export | ✅ | ✅ (solid fill, no texture) |
| PDF export | ✅ | ✅ (solid fill, no texture) |
| Project save / load (.4hu ZIP bundle) | ✅ | ✅ |
| Undo / redo (edge + flap overrides) | ✅ | ✅ |
| Interactive 2D canvas (zoom, pan, tap) | ✅ | ✅ |
| Auto-arrange pieces on paper | ✅ | ✅ |
| Paper size picker (A4/A3/A2/A1/Letter/Legal) | ✅ | ✅ |
| Portrait / Landscape toggle | ✅ | ✅ |
| Native macOS menus (⌘O, ⌘S, ⌘U …) | N/A | ✅ |
| Status bar (face count, pieces, overlaps) | N/A | ✅ |
| UV texture in 3D viewport | ✅ | ⏳ Phase 8 |
| UV texture fill in 2D canvas | ✅ | ⏳ Phase 8 |
| UV texture in SVG / PDF export | ✅ | ❌ Not planned |
| Per-piece manual drag | ✅ | ⏳ Phase 9 |
| Preferences window | ✅ | ⏳ Phase 9 |
| File associations (.obj / .pdo / .4hu) | ✅ | ⏳ Phase 9 |
| Drag-and-drop onto app window | ✅ | ⏳ Phase 9 |
| Multi-page PDF layout | ✅ | ❌ Not planned |
| PDO v4 / PD6 format | ✅ | ❌ Not planned |
| Select all faces | ✅ | ⏳ Phase 10 |
| Assembly 3D viewer | ✅ | ❌ Not planned |

---

## Known Issues / Tech Debt

| ID | Priority | Area | Description |
|----|----------|------|-------------|
| TD-M-1 | 🟡 Med | AppState | `selectAll()` is a stub — body is empty |
| TD-M-2 | 🟢 Low | AppSettings / Exporters | Typo: `includGlueTabs` (missing 'e') — appears in `AppSettings.PrintSettings`, `SVGExporter`, `PDFExporter` |
| TD-M-3 | 🟢 Low | AppSettings / PatternCanvasView | `View2DSettings.showTexture` is defined but no renderer reads it — dead code until Phase 8 |
| TD-M-4 | 🟡 Med | ProjectSerializer | `pieceOffsets` (Phase 9) not serialized into `.4hu` bundle — positions lost on project reload |
| TG-M-1 | 🟢 Low | Tests | `FlapMode.border_MountainFold`, `.border_ValleyFold`, `.border_NoFold` variants not unit tested |
| TG-M-2 | 🟡 Med | Tests | No project save / load round-trip test |
| TG-M-3 | 🟢 Low | Tests | Single-face mesh unfolding not covered |
| TG-M-4 | 🟢 Low | Tests | Extreme tab angles (1°, 179°) not tested — potential `depth/tan(angle)` edge case |
| CQ-M-1 | 🟢 Low | PatternCanvasView | File will exceed 500 lines after Phase 8 — split into Renderer + Helpers |
| CQ-M-2 | 🟢 Low | All Views | `@testable import FourHUnfolderCore` on production views — workaround for `internal` visibility; document intent |

---

## Architecture

```
4h-unfolder-mac-swift/
├── Package.swift                    ← SPM manifest (3 targets)
├── Sources/
│   ├── FourHUnfolderCore/           ← Pure Swift library (no UI deps)
│   │   ├── Core/
│   │   │   ├── Math/                ← SIMDExtensions (triangleApex, reconstructApex)
│   │   │   ├── Models/              ← Mesh, Face, Edge, UnfoldResult, GlueTab, AppSettings
│   │   │   ├── Graph/               ← DualGraph, DualGraphBuilder, UnionFind
│   │   │   └── Algorithms/          ← UnfoldEngine, KruskalMSTBuilder, GlueTabGenerator,
│   │   │                               OverlapDetector, EdgeMarker, PieceComputer
│   │   ├── IO/
│   │   │   ├── Loaders/             ← ObjMeshLoader, PdoMeshLoader, MeshLoaderFactory
│   │   │   └── Exporters/           ← SVGExporter, PDFExporter
│   │   └── Services/                ← UnfoldService (actor), ProjectSerializer, ProjectState
│   └── FourHUnfolder/               ← SwiftUI app (macOS 13+)
│       ├── App.swift                ← @main, CommandGroup / CommandMenu
│       ├── AppState.swift           ← @MainActor ObservableObject (mesh, result, overrides)
│       ├── ContentView.swift
│       └── Views/
│           ├── MainView.swift       ← NavigationSplitView + HSplitView + status bar
│           ├── SidebarView.swift    ← Settings form (unfold, print layout, view toggles)
│           ├── SceneKitView.swift   ← Metal-backed 3D viewport (NSViewRepresentable)
│           └── PatternCanvasView.swift ← SwiftUI Canvas 2D interactive pattern
└── Tests/FourHUnfolderTests/        ← 53 XCTest cases
    ├── Helpers/TestMeshBuilders.swift
    ├── UnionFindTests.swift
    ├── KruskalMSTTests.swift
    ├── UnfoldEngineTests.swift
    ├── GlueTabGeneratorTests.swift
    ├── OverlapDetectorTests.swift
    └── ObjMeshLoaderTests.swift
```

### SPM target layout

| Target | Type | Depends on |
|--------|------|-----------|
| `FourHUnfolderCore` | library (`-enable-testing`) | — |
| `FourHUnfolder` | executableTarget | FourHUnfolderCore |
| `FourHUnfolderTests` | testTarget | FourHUnfolderCore |

---

## Test Summary (Phase 6, 53 tests)

| File | Tests | Covers |
|------|-------|--------|
| `UnionFindTests` | 5 | Path compression, union by rank |
| `KruskalMSTTests` | 8 | MST edge count, uniqueness, disconnected mesh |
| `UnfoldEngineTests` | 11 | Edge length preservation, dihedral angles, edge overrides |
| `GlueTabGeneratorTests` | 11 | Inset cap at 45%, all 3 shapes, alternateFlaps |
| `OverlapDetectorTests` | 8 | SAT epsilon, shared-edge false-positive guard |
| `ObjMeshLoaderTests` | 10 | Euler V−E+F=2, boundary edges, error cases |
