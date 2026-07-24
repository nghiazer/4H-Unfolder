# 4H-Unfolder

Papercraft / pepakura unfolder — loads 3D meshes (`.obj`, `.pdo`) and unfolds them into flat 2D paper patterns with glue tabs, fold-line annotations, and SVG/PDF/PNG export.

---

## Platforms

| Platform | Stack | Version | Status |
|----------|-------|---------|--------|
| **Windows** | WPF · .NET 8 · C# | v0.4.0.A | Production |
| **macOS** | Swift 5.9 · SwiftUI · SceneKit · Metal | v0.0.0.7-alpha | Alpha |

---

## Repository Layout

```
4H-Unfolder/
├── 4h-unfolder-win/          WPF / .NET 8 — Windows native (production)
│   ├── src/                  C# projects (Domain → Geometry → Application → Infrastructure → App)
│   ├── tests/                xUnit tests (121 passing)
│   ├── installer/            Inno Setup script
│   └── 4H-Unfolder.sln
├── 4h-unfolder-mac-swift/    Swift / SwiftUI / SceneKit — macOS native (alpha)
│   ├── Package.swift         SPM manifest
│   ├── Sources/
│   │   ├── FourHUnfolderCore/   Pure-Swift library (algorithms, IO, services)
│   │   └── FourHUnfolder/       SwiftUI app target
│   ├── Tests/                128 XCTest cases
│   ├── Resources/Info.plist  App bundle metadata + file-type associations
│   └── scripts/              build-release.sh
├── publish/
│   ├── win/                  Windows installers + portable ZIPs
│   └── mac/                  macOS .app bundles + ZIPs
├── CLAUDE.md                 Architecture + development guide
└── README.md                 This file
```

---

## Features

- **3D Mesh Import** — `.obj` (Wavefront OBJ + MTL + UV textures) and Pepakura `.pdo` v3
- **Auto-Unfold** — Kruskal MST on face-adjacency dual graph → BFS face placement; real-world target size dialog
- **Overlap-Reducing Retry** — when the default unfold overlaps, automatically retries alternate near-minimal spanning trees (epsilon-bounded tie-break) and keeps the least-overlap result
- **Edge Control** — click any edge to toggle fold ↔ cut; join/disjoin edges with preview arrow; join a whole connected chain of cut edges in one action; per-edge FlapMode (10 variants)
- **Glue Tabs** — Trapezoid / Rectangle / Triangle shapes, alternate-flap mode, merge adjacent flaps into one polygon, outline padding (seam allowance)
- **Coplanar Fold-Line Hide** — suppress fold lines between near-flat faces (configurable threshold) for cleaner patterns
- **Edge-Matching Labels** — optional cut-edge pair numbers on canvas and export, for assembly guidance
- **Interactive 2D Canvas** — zoom/pan, lasso multi-select (Shift = additive), piece drag, piece rotate (handle), right-drag pan, group/ungroup, 6-way piece alignment (left/right/center/top/bottom/center)
- **Auto-Arrange** — strip-packs pieces onto pages, trying a 90° rotation per piece to reduce paper waste
- **UV Texture Rendering** — affine UV-mapped triangle fill in both 3D (SceneKit) and 2D canvas
- **3D Viewer** — SceneKit (Metal), multi-material, UV textures, face selection highlight
- **Export** — SVG (vector, with Inkscape-style cutting-machine layers for LightBurn/Cricut/Inkscape), PDF (print-ready), PNG (one raster image per page, for bitmap-only cutting software), grayscale option
- **Project Bundles** — `.4hu` self-contained ZIP (mesh + textures + overrides + piece positions + groups), cross-platform
- **Undo / Redo** — lightweight override snapshots
- **Preferences** — 4-tab settings window (macOS) / settings panel (Windows)

> macOS note: outline padding is computed but not yet wired into export/canvas rendering — tracked on the [Roadmap](https://github.com/nghiazer/4H-Unfolder/wiki/Roadmap).

---

## Algorithm

```
Load Mesh (.obj / .pdo)
    ↓
Build Dual Graph          face nodes; edge weight = dihedral angle
    ↓
Kruskal MST               sort edges by curvature; prefer flat surfaces
    ↓
Apply Edge Overrides      user-toggled fold ↔ cut
    ↓
Mark Edge Types           Fold / Cut / Boundary
    ↓
BFS Unfold                root face at origin; children via ReconstructApex
    ↓
Generate Glue Tabs        Trapezoid / Rectangle / Triangle + FlapMode
    ↓
Detect Overlaps           spatial grid + AABB + SAT
    ↓
Compute Pieces            Union-Find over fold edges
    ↓
UnfoldResult              2D faces (mm) · tabs · overlap flag · piece groups
```

---

## Windows Build & Run

```powershell
cd 4h-unfolder-win
dotnet restore
dotnet build
dotnet run --project src/FourHUnfolder.App
dotnet test tests/FourHUnfolder.Tests    # 121 tests
```

See [4h-unfolder-win/](4h-unfolder-win/) for full documentation.

---

## macOS Build & Run

> **Requires Xcode 15+** — open `Package.swift` in Xcode, then press ⌘R.

```bash
cd 4h-unfolder-mac-swift
swift build -c release

# Build distributable .app bundle + ZIP:
./scripts/build-release.sh v0.0.0.7-alpha
```

See [4h-unfolder-mac-swift/README.md](4h-unfolder-mac-swift/README.md) and [PROGRESS.md](4h-unfolder-mac-swift/PROGRESS.md) for full documentation.

---

## Releases

| Version | Platform | Download |
|---------|----------|---------|
| v0.0.0.7-alpha | macOS 13+ | `publish/mac/v0.0.0.7-alpha/4H-Unfolder_v0.0.0.7-alpha_mac.zip` |
| v0.4.0.A | Windows 10+ | `publish/win/v0.4.0.A/` |

> Both platforms are packaged and released together under the shared git tag `v0.4.0.A`
> (triggers the CI release pipeline for both) — each platform's *own* version number above is
> what's shown in its About dialog / bundle metadata.

See the [Releases page](https://github.com/nghiazer/4H-Unfolder/releases) for signed downloads.

---

## License

[MIT](LICENSE)
