# 4H-Unfolder macOS — Progress Tracker

## Build

```bash
# Requires Xcode 15+ (NOT just Command Line Tools)
cd 4h-unfolder-mac-swift
swift build                  # debug
swift build -c release       # release

# Publish build (creates .app bundle + ZIP):
./scripts/build-release.sh v0.0.0.1-alpha

# Tests — must use Xcode (swift test fails, XCTest needs full SDK):
# Product → Test (⌘U) or Test Navigator (⌘5)
```

---

## Phase Completion

| Phase | Description | Status | Commit |
|-------|-------------|--------|--------|
| 1 | Core algorithm layer — UnionFind, DualGraph, Kruskal MST, UnfoldEngine (BFS + ReconstructApex), GlueTabGenerator, OverlapDetector (SAT), EdgeMarker, PieceComputer | ✅ Done | `5294cc8` |
| 2 | PDO binary parser — v3 format, subtraction cipher, embedded zlib textures | ✅ Done | `5294cc8` |
| 3 | UnfoldService actor + ProjectSerializer (.4hu ZIP bundle) | ✅ Done | `5294cc8` |
| 4 | PatternCanvasView (interactive 2D canvas) + SceneKitView (Metal 3D viewport) | ✅ Done | `5294cc8` |
| 5 | SVGExporter + PDFExporter + ObjMeshLoader (MTL parsing, UV coordinates) | ✅ Done | `5294cc8` |
| 6 | FourHUnfolderCore library target (SPM split) + 53 unit tests | ✅ Done | `773504d` |
| 7 | Native menus (CommandGroup/CommandMenu), paper size picker, auto-arrange, status bar | ✅ Done | `c0a66a4` |
| 8 | Multi-material + UV texture rendering — 3D viewport (SCNGeometry multi-element) + 2D canvas (affine UV-mapped triangles) | ✅ Done | `bf8d014` |
| 9 | Per-piece manual drag (non-destructive pieceOffsets), 4-tab Preferences window, onOpenURL, onDrop, Settings scene (⌘,) | ✅ Done | `7f5adab` |
| 10 | Tech debt sprint — `includeGlueTabs` typo fix, `selectAll()` impl, `pieceOffsets` project persistence, 10 new unit tests | ✅ Done | `5965900` |
| CR | Cross-review — fix 7 CRITICAL/HIGH/MEDIUM issues (force-unwraps, CGContext leak, epsilon, temp-dir defer, isFinite guard) + 16 new tests | ✅ Done | `9ad99d7` `078ff78` |
| PUB | Release packaging — `Resources/Info.plist` (file types .obj/.pdo/.4hu), `scripts/build-release.sh` (ad-hoc signed .app + ZIP) | ✅ Done | `ef4b3d1` |

---

## Feature Status vs Windows Version

| Feature | Windows (WPF) | macOS (Swift) |
|---------|---------------|---------------|
| OBJ mesh loading (+ MTL textures) | ✅ | ✅ |
| PDO mesh loading (v3) | ✅ | ✅ |
| Kruskal MST unfold pipeline | ✅ | ✅ |
| Edge toggle fold ↔ cut | ✅ | ✅ |
| Glue tabs (Trapezoid / Rectangle / Triangle) | ✅ | ✅ |
| 10 FlapMode variants per edge | ✅ | ✅ |
| Overlap detection (spatial grid + SAT) | ✅ | ✅ |
| SVG export | ✅ | ✅ |
| PDF export | ✅ | ✅ |
| Project save / load (.4hu ZIP bundle) | ✅ | ✅ |
| Undo / redo (edge + flap overrides) | ✅ | ✅ |
| Interactive 2D canvas (zoom, pan, tap) | ✅ | ✅ |
| Per-piece manual drag | ✅ | ✅ |
| Auto-arrange pieces on paper | ✅ | ✅ |
| Paper size picker (A4/A3/A2/A1/Letter/Legal) | ✅ | ✅ |
| Portrait / Landscape toggle | ✅ | ✅ |
| pieceOffsets persisted in .4hu bundle | ✅ | ✅ |
| UV texture in 3D viewport | ✅ | ✅ |
| UV texture fill in 2D canvas | ✅ | ✅ |
| Preferences window (4 tabs) | ✅ | ✅ |
| Drag-and-drop mesh onto app window | ✅ | ✅ |
| File associations (.obj / .pdo / .4hu in Info.plist) | ✅ | ✅ |
| Select all / cycle faces | ✅ | ✅ |
| Native macOS menus (⌘O, ⌘S, ⌘U …) | N/A | ✅ |
| Status bar (face count, pieces, overlaps) | N/A | ✅ |
| UV texture in SVG / PDF export | ✅ | ❌ Not planned |
| Multi-page PDF layout | ✅ | ❌ Not planned |
| PDO v4 / PD6 format | ✅ | ❌ Not planned |
| Assembly 3D viewer | ✅ | ❌ Not planned |

---

## Known Issues / Tech Debt

All issues from Phases 1–10 and the cross-review audit have been resolved.

| ID | Priority | Description |
|----|----------|-------------|
| CQ-M-1 | 🟢 Low | PatternCanvasView is ~470 lines — consider splitting into CanvasRenderer + CanvasHelpers sub-files when adding more render layers |
| PERF | 🟢 Low | SVG/PDF export does not include UV texture rendering — solid fill only |

---

## Test Summary (87 tests across 8 files)

| File | Tests | Covers |
|------|-------|--------|
| `UnionFindTests` | 5 | Path compression, union by rank, single-element |
| `KruskalMSTTests` | 8 | Edge count (n-1), uniqueness, flat mesh, disconnected |
| `UnfoldEngineTests` | 14 | Edge-length preservation, dihedral angles, single-face, edge overrides, empty mesh |
| `GlueTabGeneratorTests` | 17 | All 3 shapes, inset cap at 45%, border FlapMode variants, extreme angles, alternateFlaps |
| `OverlapDetectorTests` | 9 | SAT epsilon, shared-edge false-positive guard, spatial grid |
| `ObjMeshLoaderTests` | 14 | Euler V−E+F=2, boundary edges, error cases, missing MTL graceful load |
| `ProjectSerializerTests` | 3 | Round-trip edge/flap overrides, pieceOffsets, missing state.json error |
| `SVGExporterTests` | 17 | XML structure, polygon count, dimensions, fold/cut/tab flags, grayscale, empty result, coordinate origin |

---

## Architecture

```
4h-unfolder-mac-swift/
├── Package.swift                         ← SPM manifest (3 targets, -enable-testing)
├── Resources/
│   └── Info.plist                        ← App bundle metadata + document types
├── scripts/
│   └── build-release.sh                  ← Release packaging script
├── Sources/
│   ├── FourHUnfolderCore/                ← Pure Swift library (no UI deps)
│   │   ├── Core/
│   │   │   ├── Math/                     ← SIMDExtensions (triangleApex, reconstructApex)
│   │   │   ├── Models/                   ← Mesh, Face, Edge, UnfoldResult, GlueTab,
│   │   │   │                               AppSettings, FlapOverride, ProjectState
│   │   │   ├── Graph/                    ← DualGraph, DualGraphBuilder, UnionFind
│   │   │   └── Algorithms/               ← UnfoldEngine, KruskalMSTBuilder,
│   │   │                                   GlueTabGenerator, OverlapDetector,
│   │   │                                   EdgeMarker, PieceComputer
│   │   ├── IO/
│   │   │   ├── Loaders/                  ← ObjMeshLoader, PdoMeshLoader, MeshLoaderFactory
│   │   │   └── Exporters/                ← SVGExporter, PDFExporter
│   │   └── Services/                     ← UnfoldService (actor), ProjectSerializer
│   └── FourHUnfolder/                    ← SwiftUI app (macOS 13+)
│       ├── App.swift                     ← @main, CommandGroup, Settings scene
│       ├── AppState.swift                ← @MainActor ObservableObject
│       ├── ContentView.swift
│       └── Views/
│           ├── MainView.swift            ← NavigationSplitView + status bar + onDrop
│           ├── SidebarView.swift         ← Settings form
│           ├── SceneKitView.swift        ← Metal 3D viewport (multi-material UV)
│           ├── PatternCanvasView.swift   ← 9-layer SwiftUI Canvas + piece drag
│           └── PreferencesView.swift     ← 4-tab Preferences (General/Print/Canvas/3D)
└── Tests/FourHUnfolderTests/             ← 87 XCTest cases
    ├── Helpers/TestMeshBuilders.swift
    ├── UnionFindTests.swift
    ├── KruskalMSTTests.swift
    ├── UnfoldEngineTests.swift
    ├── GlueTabGeneratorTests.swift
    ├── OverlapDetectorTests.swift
    ├── ObjMeshLoaderTests.swift
    ├── ProjectSerializerTests.swift
    └── SVGExporterTests.swift
```

### SPM target layout

| Target | Type | Key flag |
|--------|------|----------|
| `FourHUnfolderCore` | library | `-enable-testing` (internal types accessible via `@testable`) |
| `FourHUnfolder` | executableTarget | depends on FourHUnfolderCore |
| `FourHUnfolderTests` | testTarget | depends on FourHUnfolderCore |
