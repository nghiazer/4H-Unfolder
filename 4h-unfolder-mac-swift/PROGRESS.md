# 4H-Unfolder macOS — Progress Tracker

## Build

```bash
# Requires Xcode 15+ (NOT just Command Line Tools)
cd 4h-unfolder-mac-swift
swift build                  # debug
swift build -c release       # release

# Publish build (creates .app bundle + ZIP):
./scripts/build-release.sh v0.0.0.5-alpha

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
| 11 | Canvas UX sprint I — Unfold setup dialog (real-world size), scroll-wheel zoom, multi-page canvas, dynamic page grid expansion, canvas mode system (Edit Edges / Edit Flaps / Rotate Pivot), flap direction fix, auto-unfold-on-load removed | ✅ Done | `7a30ce1` `81f8d61` |
| 12 | Canvas UX sprint II — Smart join/disjoin (preview arrow + position-aware reposition), lasso multi-select (Shift = additive), right-drag pan, Group/Ungroup pieces (persisted in .4hu), rotate handle on selected piece/group | ✅ Done | `c60ce99` `b50aeff` `67092db` |

---

## Feature Status vs Windows Version

| Feature | Windows (WPF) | macOS (Swift) |
|---------|---------------|---------------|
| OBJ mesh loading (+ MTL textures) | ✅ | ✅ |
| PDO mesh loading (v3) | ✅ | ✅ |
| Kruskal MST unfold pipeline | ✅ | ✅ |
| Edge toggle fold ↔ cut | ✅ | ✅ |
| Join / disjoin edges with preview | ✅ | ✅ |
| Glue tabs (Trapezoid / Rectangle / Triangle) | ✅ | ✅ |
| 10 FlapMode variants per edge | ✅ | ✅ |
| Overlap detection (spatial grid + SAT) | ✅ | ✅ |
| SVG export | ✅ | ✅ |
| PDF export | ✅ | ✅ |
| Project save / load (.4hu ZIP bundle) | ✅ | ✅ |
| Undo / redo (edge + flap overrides) | ✅ | ✅ |
| Interactive 2D canvas (zoom, pan, tap) | ✅ | ✅ |
| Per-piece manual drag | ✅ | ✅ |
| Piece rotate (handle drag) | ✅ | ✅ |
| Lasso multi-select (Shift = additive) | ✅ | ✅ |
| Group / Ungroup pieces | ✅ | ✅ |
| Right-drag pan | N/A | ✅ |
| Auto-arrange pieces on paper | ✅ | ✅ |
| Paper size picker (A4/A3/A2/A1/Letter/Legal) | ✅ | ✅ |
| Portrait / Landscape toggle | ✅ | ✅ |
| pieceOffsets + userGroups persisted in .4hu | ✅ | ✅ |
| UV texture in 3D viewport | ✅ | ✅ |
| UV texture fill in 2D canvas | ✅ | ✅ |
| Preferences window (4 tabs) | ✅ | ✅ |
| Drag-and-drop mesh onto app window | ✅ | ✅ |
| File associations (.obj / .pdo / .4hu in Info.plist) | ✅ | ✅ |
| Select all / cycle faces | ✅ | ✅ |
| Unfold setup dialog (real-world target size) | N/A | ✅ |
| Native macOS menus (⌘O, ⌘S, ⌘U …) | N/A | ✅ |
| Status bar (face count, pieces, overlaps) | N/A | ✅ |
| UV texture in SVG / PDF export | ✅ | ❌ Not planned |
| Multi-page PDF layout | ✅ | ❌ Not planned |
| PDO v4 / PD6 format | ✅ | ❌ Not planned |
| Assembly 3D viewer | ✅ | ❌ Not planned |

---

## Known Issues / Tech Debt

| ID | Priority | Description |
|----|----------|-------------|
| TD-M-1 | 🟡 Med | `SVGExporter` write uses `try?` — silent failure. Should use `do/catch` and surface `errorMessage` (matches PDF export pattern). |
| TD-M-2 | 🟡 Med | `PatternCanvasView` is ~1 100 lines — split into `CanvasRenderer.swift` (draw* functions) + `CanvasHelpers.swift` (geometry/hit-test) when adding more layers |
| TD-M-3 | 🟢 Low | `.onDrop` in `MainView` accepts any file URL before `loadMesh` validates the extension — user sees an error message on bad drop but no early rejection UI |
| TD-M-4 | 🟢 Low | `@testable import FourHUnfolderCore` used in all production view files; works because `Package.swift` sets `-enable-testing` on the library target, but semantically wrong. Resolve by making public API `public` and switching to plain `import`. |
| PERF | 🟢 Low | SVG/PDF export does not render UV texture — solid fill only |

---

## Cross-Review Audit (2026-06-07)

Findings from automated cross-review after Phase 12:

| # | Severity | Finding | Action |
|---|----------|---------|--------|
| CR2-1 | 🟡 Med | `SVGExporter`: `try? svg.write(...)` silently swallows write errors | → TD-M-1 |
| CR2-2 | 🟡 Med | `PatternCanvasView` exceeds 1 000 lines, hard to navigate | → TD-M-2 |
| CR2-3 | 🟢 Low | `.onDrop` accepts any URL without early type check | → TD-M-3 |
| CR2-4 | 🟢 Low | `@testable import` in production — intentional but semantically wrong | → TD-M-4 |
| CR2-5 | 🟢 Low | Forced unwraps (`min()!`, `max()!`) guarded by `.isEmpty` checks — safe in current flow, but fragile if code is restructured | Monitor — not fixing to avoid churn |
| CR2-6 | 🟢 Low | SceneKit init uses `view.scene!`, `camNode.camera!` etc — standard SceneKit init pattern, nil is impossible after `SCNScene()` | No action |
| CR2-7 | 🟢 Low | `_ = pi` in `drawSelection` to suppress unused-loop-var warning | No action — loop variable needed for group lookup |

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
│           ├── PatternCanvasView.swift   ← 9-layer SwiftUI Canvas + all 2D interactions
│           ├── UnfoldSetupSheet.swift    ← Target-size dialog (mm per model unit)
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
