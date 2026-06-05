# 4H-Unfolder — macOS

Native macOS port of 4H-Unfolder, built with Swift 5.9 + SwiftUI + SceneKit (Metal). Unfolds 3D meshes into 2D printable papercraft patterns.

> **Status: Alpha (v0.0.0.1)** — core pipeline complete, texture rendering in progress.
> See [PROGRESS.md](PROGRESS.md) for detailed phase tracking.

---

## Features

- **Load** OBJ (with MTL textures) and PDO v3 files
- **Unfold** via Kruskal MST spanning tree + BFS layout — produces flat 2D pattern
- **Interactive 2D canvas** — zoom/pan, click edges to toggle fold ↔ cut, tap faces to select
- **Glue tabs** — Trapezoid / Rectangle / Triangle shapes; 10 FlapMode variants per edge
- **Overlap detection** — spatial grid + SAT algorithm
- **Auto-arrange** pieces within selected paper size (A4 / A3 / A2 / A1 / Letter / Legal)
- **Export** SVG and PDF
- **Save / load** project as `.4hu` ZIP bundle (compatible with Windows version)
- **Undo / redo** edge and flap overrides
- **Metal-accelerated** 3D viewport via SceneKit

---

## Requirements

| Requirement | Version |
|-------------|---------|
| macOS | 13 Ventura or later |
| Xcode | 15 or later (full install — not just Command Line Tools) |
| Swift | 5.9 (bundled with Xcode 15) |

> `swift build` from terminal also works for a non-GUI build, but **running tests requires Xcode** (`swift test` fails — XCTest framework is only in the full Xcode SDK).

---

## Build & Run

### Xcode (recommended)

```bash
# 1. Open project
open 4h-unfolder-mac-swift/Package.swift
# Xcode opens the SPM package automatically

# 2. Select scheme "FourHUnfolder" → Run (⌘R)
```

### Command line (build only, no GUI)

```bash
cd 4h-unfolder-mac-swift
swift build                   # debug
swift build -c release        # release
```

### Run tests

Open in Xcode → **Product → Test (⌘U)** or use the Test Navigator (⌘5).

---

## Usage

| Action | How |
|--------|-----|
| Open mesh | ⌘O or File → Open Mesh… |
| Unfold | ⌘U or Pattern → Run Unfold |
| Toggle fold/cut edge | Click edge in 2D canvas |
| Auto-arrange pieces | ⌘⇧A or sidebar "Auto-Arrange Pieces" button |
| Fit canvas to window | ⌘0 or View → Fit Pattern to Window |
| Export SVG | ⌘⇧E |
| Export PDF | ⌘P |
| Save project | ⌘S → saves as `.4hu` bundle |
| Open project | ⌘⇧O |
| Undo override | ⌘Z |
| Redo | ⌘⇧Z |
| Preferences | ⌘, (Phase 9) |

---

## Project Structure

```
4h-unfolder-mac-swift/
├── Package.swift                    ← SPM manifest
├── README.md                        ← This file
├── PROGRESS.md                      ← Phase tracker + feature status
├── Sources/
│   ├── FourHUnfolderCore/           ← Pure Swift library (zero UI deps)
│   │   ├── Core/Models/             ← Mesh, UnfoldResult, AppSettings, FlapOverride
│   │   ├── Core/Graph/              ← DualGraph, UnionFind, KruskalMSTBuilder
│   │   ├── Core/Algorithms/         ← UnfoldEngine, GlueTabGenerator, OverlapDetector
│   │   ├── IO/Loaders/              ← ObjMeshLoader, PdoMeshLoader
│   │   ├── IO/Exporters/            ← SVGExporter, PDFExporter
│   │   └── Services/                ← UnfoldService (actor), ProjectSerializer
│   └── FourHUnfolder/               ← SwiftUI app target
│       ├── App.swift                ← @main entry, native menus
│       ├── AppState.swift           ← Observable state, unfold pipeline, file I/O
│       └── Views/                   ← MainView, SidebarView, SceneKitView, PatternCanvasView
└── Tests/FourHUnfolderTests/        ← 53 XCTest cases
```

### Architecture

```
FourHUnfolderCore (library)
    ├── Core          ← pure algorithms, zero external deps
    ├── IO            ← file loading + export
    └── Services      ← pipeline orchestration (UnfoldService actor)

FourHUnfolder (app)
    └── depends on FourHUnfolderCore
        uses @testable import to access internal types
        (library compiled with -enable-testing)

FourHUnfolderTests (test target)
    └── depends on FourHUnfolderCore
```

---

## Supported File Formats

| Format | Load | Save |
|--------|------|------|
| `.obj` (Wavefront OBJ + MTL) | ✅ | — |
| `.pdo` (Pepakura Designer v3) | ✅ | — |
| `.svg` (Scalable Vector Graphics) | — | ✅ |
| `.pdf` (Portable Document Format) | — | ✅ |
| `.4hu` (4H-Unfolder project bundle) | ✅ | ✅ |

> **PDO support**: version 3 only. PD6/v4 format not supported.

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘O | Open mesh file |
| ⌘⇧O | Open project (.4hu) |
| ⌘S | Save project |
| ⌘U | Run unfold |
| ⌘⇧A | Auto-arrange pieces |
| ⌘0 | Fit pattern to window |
| ⌘⇧E | Export SVG |
| ⌘P | Export PDF |
| ⌘Z | Undo edge/flap override |
| ⌘⇧Z | Redo |
| ⌘, | Preferences (Phase 9) |

---

## Roadmap

See [PROGRESS.md](PROGRESS.md) for the full phase breakdown.

**Next up:**
- **Phase 8** — Multi-material + UV texture rendering in 3D viewport and 2D canvas
- **Phase 9** — Per-piece drag, Preferences window, file associations
- **Phase 10** — Tech debt (stubs, typo fixes, test coverage expansion)

---

## Related

- **Windows version**: [`4h-unfolder-win/`](../4h-unfolder-win/) — WPF / .NET 8, feature-complete reference implementation
- **Project guide**: [`CLAUDE.md`](../CLAUDE.md) — architecture overview and development guide
