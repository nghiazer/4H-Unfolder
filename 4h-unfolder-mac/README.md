# 4H-Unfolder — macOS

Native macOS port of [4H-Unfolder](https://github.com/nghiazer/4H-Unfolder) (Windows/WPF).  
Built with **Tauri 2 + React 18 + TypeScript** frontend and a pure-**Rust** algorithm backend.

---

## Features

### Mesh Loading
- **OBJ** (tobj — full UV + MTL + texture path resolution)
- **PDO** (Pepakura v3 binary parser — unlocked files, fan-triangulated geometry, embedded zlib textures)
- **FBX / DAE / STL / PLY / 3DS** dispatch hook (Assimp integration placeholder)
- Drag-and-drop or ⌘O file open

### 3D Viewport
- React Three Fiber + Drei — OrbitControls, camera fit-to-mesh
- Per-material `MeshStandardMaterial` with texture support (`convertFileSrc`)
- Face hover + multi-select (shared state with 2D canvas)
- Toggle 3D / 2D split layout

### 2D Pattern Canvas (Konva)
- Separate `<Line>` per edge: fold (blue dashed), cut (red solid), boundary (grey)
- Piece drag (mode: select) + right-mouse rotate
- Lasso multi-select with Cmd modifier
- Cut-edge pair labels from `cutEdgePairIds`
- Multi-page grid background (dashed page-break lines + page number labels)

### Unfold Pipeline (Rust)
| Step | File | Notes |
|------|------|-------|
| Kruskal MST | `spanning_tree.rs` | Dihedral-angle weights; `acos(dot(n1,n2))` |
| BFS face unfold | `face_unfold.rs` | Apex reconstruction; cross-product side test |
| Glue tab gen | `glue_tabs.rs` | Trapezoid / Rectangle / Triangle; all 10 FlapMode overrides |
| Auto layout | `layout.rs` | Row-based piece arrange |
| Assembly order | `assembly.rs` | BFS from largest fold-component via cut edges |
| PDO unfold | `pdo_unfold.rs` | Direct 2D coords from PdoFace.a/b/c |

### Edit Flaps Dialog
- Position tab: 6 interior modes + 5 border modes (auto-detected from edge.faceB)
- Shape tab: SVG tab preview + global settings
- `FlapOverride` serialized as `"{Mode},{PrimaryFaceId}"` — matches C# format

### Export
- **SVG** — face fills, fold/cut/boundary lines, glue tabs, cut-edge pair labels, edge dedup (1 μm rounding), multi-page (`_p{r}_{c}` suffix)
- **PDF** — pure-Rust PDF 1.4 writer (no external PDF crate); Y-flip, dash patterns, multi-page

### Project Bundle (`.4hu`)
- ZIP: `mesh` + `textures/` + `state.json`
- State includes: edge overrides, flap overrides, piece layouts, scale, paper settings
- Security: `Path::file_name()` on all ZIP entry names (path traversal protection), extension whitelist

### Settings
- 4-tab dialog: General / View 3D / View 2D / Print
- Persisted to `~/Library/Application Support/4H-Unfolder/settings.json`
- All print settings: tab depth, side angle, tab shape, alternate flaps, line colors, page size, multi-page dims

### Undo / Redo
- Snapshot-based: edge overrides + flap overrides + piece layouts
- ⌘Z / ⌘⇧Z

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI framework | React 18 + TypeScript |
| Desktop shell | Tauri 2 (macOS-only, Apple Silicon + Intel) |
| 2D canvas | react-konva 18 / Konva 9 |
| 3D viewport | @react-three/fiber 8 + @react-three/drei 9 + Three.js 0.167 |
| State | Zustand 4 + Immer |
| Styling | Tailwind CSS 3 |
| Backend | Rust 1.77+ |
| IPC | Tauri `invoke()` with typed wrappers |
| OBJ parsing | tobj 4 |
| ZIP | zip 2 |
| zlib (PDO textures) | flate2 1 |
| Geometry math | nalgebra 0.33 + glam 0.29 |
| Parallelism | rayon 1 |

---

## Quick Start

### Prerequisites

```bash
# Xcode CLT
xcode-select --install

# Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Node.js LTS
brew install node

# Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env
```

### Install & Run

```bash
cd 4h-unfolder-mac
npm install
npm run tauri:dev        # dev server with hot-reload
```

### Production Build

```bash
npm run tauri:build
# → src-tauri/target/release/bundle/macos/4H Unfolder.app
# → src-tauri/target/release/bundle/dmg/4H Unfolder_*.dmg
```

---

## Architecture

```
Frontend (React/TS)          Backend (Rust)
─────────────────────        ──────────────────────────────────────
App.tsx                      lib.rs  (17 registered commands)
  AppLayout                    models/
    Toolbar                      mesh.rs       Mesh, Face, MeshEdge, EdgeType
    PatternCanvas                unfold.rs     UnfoldedFace, GlueTab, FlapMode
      PieceGroup                 settings.rs   AppSettings
        FaceShape              algorithms/
        GlueTabShape             spanning_tree.rs  Kruskal MST + dihedral weights
      LassoOverlay               face_unfold.rs    BFS apex reconstruction
      SheetBackground            glue_tabs.rs      10-mode FlapMode dispatch
    MeshViewer (3D)              layout.rs         auto-arrange pieces
    AssemblyPanel                assembly.rs       BFS assembly order
    EditFlapsDialog              pdo_unfold.rs     PDO 2D-coord path
    SettingsDialog             loaders/
    ScaleDialog                  pdo_loader.rs     Pepakura v3 binary parser
    ModelOrientationDialog     commands/
  state/                         mesh.rs           load_obj, load_mesh, transform
    meshStore (Zustand)          unfold.rs         unfold_mesh
    unfoldStore                  export.rs         SVG + PDF
    uiStore                      project.rs        .4hu bundle
    settingsStore                assembly.rs       get_assembly_steps
    historyStore (undo)          settings.rs       load/save settings
```

---

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| ⌘O | Open mesh |
| ⌘S | Export SVG |
| ⌘⇧S | Export PDF |
| U | Unfold |
| ⌘Z | Undo |
| ⌘⇧Z | Redo |
| ⌘, | Settings |
| Esc | Clear selection |
| Scroll | Zoom canvas |
| Drag | Pan canvas |
| E | Edit flaps mode |

---

## Test Suite

```bash
cd src-tauri
cargo test        # 67 tests, 0 failures
```

Coverage across: MST, face unfold, glue tabs, assembly, FlapOverride serialization, export utilities (edge_key, page_path, PDF ops), PDO loader (signature/lock/Reader robustness).

---

## Status

This is **v0.0.0.1-alpha** — all core Phases 1–6B are implemented. Not yet feature-complete vs. the WPF version (see [PROGRESS.md](PROGRESS.md)).
