# 4H-Unfolder

Papercraft / pepakura unfolder — loads 3D meshes (`.obj`, `.pdo`) and unfolds them into flat 2D paper patterns with glue tabs, fold-line annotations, and SVG/PDF export.

---

## Platforms

| Platform | Stack | Version | Status |
|----------|-------|---------|--------|
| **Windows** | WPF · .NET 8 · C# | v0.1.0.A | Production |
| **macOS** | Swift 5.9 · SwiftUI · SceneKit · Metal | v0.0.0.1-alpha | Alpha |

---

## Repository Layout

```
4H-Unfolder/
├── 4h-unfolder-win/          WPF / .NET 8 — Windows native (production)
│   ├── src/                  C# projects (Domain → Geometry → Application → Infrastructure → App)
│   ├── tests/                xUnit tests (56 passing)
│   ├── installer/            Inno Setup script
│   └── 4H-Unfolder.sln
├── 4h-unfolder-mac-swift/    Swift / SwiftUI / SceneKit — macOS native (alpha)
│   ├── Package.swift         SPM manifest
│   ├── Sources/
│   │   ├── FourHUnfolderCore/   Pure-Swift library (algorithms, IO, services)
│   │   └── FourHUnfolder/       SwiftUI app target
│   ├── Tests/                87 XCTest cases
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
- **Auto-Unfold** — Kruskal MST on face-adjacency dual graph → BFS face placement
- **Edge Control** — click any edge to toggle fold ↔ cut; per-edge FlapMode (10 variants)
- **Glue Tabs** — Trapezoid / Rectangle / Triangle shapes, alternate-flap mode
- **Interactive 2D Canvas** — zoom/pan, piece drag (non-destructive), grid snap
- **UV Texture Rendering** — affine UV-mapped triangle fill in both 3D (SceneKit) and 2D canvas
- **3D Viewer** — SceneKit (Metal), multi-material, UV textures, face selection highlight
- **Export** — SVG (vector) and PDF (print-ready), grayscale option
- **Project Bundles** — `.4hu` self-contained ZIP (mesh + textures + overrides + piece positions), cross-platform
- **Undo / Redo** — lightweight override snapshots
- **Preferences** — 4-tab settings window (macOS) / settings panel (Windows)

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
dotnet test tests/FourHUnfolder.Tests    # 56 tests
```

See [4h-unfolder-win/](4h-unfolder-win/) for full documentation.

---

## macOS Build & Run

> **Requires Xcode 15+** — open `Package.swift` in Xcode, then press ⌘R.

```bash
cd 4h-unfolder-mac-swift
swift build -c release

# Build distributable .app bundle + ZIP:
./scripts/build-release.sh v0.0.0.1-alpha
```

See [4h-unfolder-mac-swift/README.md](4h-unfolder-mac-swift/README.md) and [PROGRESS.md](4h-unfolder-mac-swift/PROGRESS.md) for full documentation.

---

## Releases

| Version | Platform | Download |
|---------|----------|---------|
| v0.0.0.1-alpha | macOS 13+ | `publish/mac/v0.0.0.1-alpha/4H-Unfolder_v0.0.0.1-alpha_mac.zip` |
| v0.1.0.A | Windows 10+ | `publish/win/v0.1.0.A/` |

---

## License

[MIT](LICENSE)
