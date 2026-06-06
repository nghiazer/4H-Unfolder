# 4H-Unfolder — macOS

Native macOS port of 4H-Unfolder, built with Swift 5.9 + SwiftUI + SceneKit (Metal). Unfolds 3D meshes into 2D printable papercraft patterns.

> **Status: v0.0.0.5-alpha** — Phases 1–12 complete, 87 unit tests passing.
> See [PROGRESS.md](PROGRESS.md) for detailed phase tracking.

---

## Download

Pre-built ad-hoc signed bundle (macOS 13+, no installer needed):

```
publish/mac/v0.0.0.5-alpha/4H-Unfolder_v0.0.0.5-alpha_mac.zip
```

> **First launch**: Right-click `4H Unfolder.app` → **Open** (Gatekeeper bypass for unsigned builds).
> For a signed build, open in Xcode → Product → Archive → Distribute App.

---

## Features

| Category | Feature |
|----------|---------|
| **Import** | OBJ (+ MTL material + UV textures), PDO v3 (binary, embedded zlib textures) |
| **Unfold** | Kruskal MST on face-adjacency dual graph → BFS face placement in paper-space mm; setup dialog for real-world target size |
| **2D Canvas** | Zoom/pan, click edge to toggle fold ↔ cut, join/disjoin edges with preview arrow, drag piece to reposition, rotate handle on selection |
| **Multi-select** | Lasso rubber-band selection (Shift = additive); right-drag to pan |
| **Group** | Group/Ungroup selected pieces — grouped pieces move and rotate together; persisted in .4hu |
| **3D Viewport** | SceneKit (Metal), multi-material, UV texture mapping, face selection highlight |
| **Glue Tabs** | Trapezoid / Rectangle / Triangle shapes; 10 FlapMode variants per edge |
| **Overlap** | Spatial grid + AABB + SAT detection |
| **Layout** | Auto-arrange pieces on page; paper size picker (A4/A3/A2/A1/Letter/Legal); portrait/landscape |
| **Export** | SVG (vector) and PDF (Core Graphics), grayscale option |
| **Project** | Save/load `.4hu` ZIP bundle — mesh + overrides + piece positions + groups (cross-platform with Windows) |
| **Undo/Redo** | Lightweight snapshot of edge/flap overrides |
| **Preferences** | 4-tab window — General, Print, Canvas, 3D View |

---

## Requirements

| | Version |
|--|---------|
| macOS | 13 Ventura or later |
| Xcode | 15 or later (full install — not just Command Line Tools) |
| Swift | 5.9 (bundled with Xcode 15) |

> `swift build` works for CLI builds, but **running tests requires Xcode** — `swift test` fails because XCTest is only in the full Xcode SDK.

---

## Build & Run

### Xcode (recommended)

```bash
open 4h-unfolder-mac-swift/Package.swift   # Xcode opens the SPM package
# Select scheme "FourHUnfolder" → Run (⌘R)
```

### Command line

```bash
cd 4h-unfolder-mac-swift
swift build                   # debug
swift build -c release        # optimised release
```

### Release package (signed bundle + ZIP)

```bash
cd 4h-unfolder-mac-swift
./scripts/build-release.sh v0.0.0.5-alpha
# → publish/mac/v0.0.0.5-alpha/4H-Unfolder_v0.0.0.5-alpha_mac.zip
```

### Tests

Open in Xcode → **Product → Test (⌘U)**. All 87 tests must pass before release.

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘O | Open mesh file (.obj / .pdo) |
| ⌘⇧O | Open project (.4hu) |
| ⌘S | Save project |
| ⌘U | Run unfold |
| ⌘⇧A | Auto-arrange pieces |
| ⌘0 | Fit pattern to window |
| ⌘⇧E | Export SVG |
| ⌘P | Export PDF |
| ⌘Z / ⌘⇧Z | Undo / Redo |
| ⌘, | Preferences |

---

## 2D Canvas Controls

| Input | Action |
|-------|--------|
| Scroll wheel | Zoom in / out |
| Right-drag | Pan canvas |
| Left-click edge | Toggle fold ↔ cut (Edit Edges mode) |
| Left-click face | Select piece |
| Left-drag on face | Move piece (+ group members) |
| Left-drag on rotate handle (↺) | Rotate selected piece / group around centroid |
| Left-drag on empty space | Rubber-band lasso selection |
| Shift + lasso | Additive selection |
| Left-click cut edge (once) | Preview join arrow |
| Left-click (second) | Confirm join |

---

## Project Structure

```
4h-unfolder-mac-swift/
├── Package.swift                    ← SPM manifest (3 targets)
├── Resources/Info.plist             ← App bundle metadata + file-type associations
├── scripts/build-release.sh         ← Release packaging (ad-hoc sign + ZIP)
├── Sources/
│   ├── FourHUnfolderCore/           ← Pure Swift library (zero UI deps)
│   │   ├── Core/Math/               ← SIMD geometry (triangleApex, reconstructApex)
│   │   ├── Core/Models/             ← Mesh, UnfoldResult, AppSettings, FlapOverride
│   │   ├── Core/Graph/              ← DualGraph, UnionFind, KruskalMSTBuilder
│   │   ├── Core/Algorithms/         ← UnfoldEngine, GlueTabGenerator, OverlapDetector
│   │   ├── IO/Loaders/              ← ObjMeshLoader, PdoMeshLoader
│   │   ├── IO/Exporters/            ← SVGExporter, PDFExporter
│   │   └── Services/                ← UnfoldService (actor), ProjectSerializer
│   └── FourHUnfolder/               ← SwiftUI app target (macOS 13+)
│       ├── App.swift                ← @main, native menus, Settings scene (⌘,)
│       ├── AppState.swift           ← @MainActor ObservableObject, undo stack
│       └── Views/                   ← MainView, SidebarView, SceneKitView,
│                                       PatternCanvasView, UnfoldSetupSheet, PreferencesView
└── Tests/FourHUnfolderTests/        ← 87 XCTest cases (8 files)
```

---

## Supported File Formats

| Format | Load | Save |
|--------|------|------|
| `.obj` (Wavefront OBJ + MTL + UV textures) | ✅ | — |
| `.pdo` (Pepakura Designer v3, embedded textures) | ✅ | — |
| `.svg` (Scalable Vector Graphics) | — | ✅ |
| `.pdf` (Portable Document Format) | — | ✅ |
| `.4hu` (4H-Unfolder project bundle, cross-platform) | ✅ | ✅ |

> PDO v4 / PD6 format not supported.

---

## Related

- **Windows version**: [`4h-unfolder-win/`](../4h-unfolder-win/) — WPF / .NET 8, feature-complete reference implementation
- **Project guide**: [`CLAUDE.md`](../CLAUDE.md) — architecture overview and development guide
- **Phase tracker**: [PROGRESS.md](PROGRESS.md) — all phases, feature parity table, test summary
