# 4H-Unfolder macOS — Setup Guide

## Prerequisites

```bash
# 1. Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. Install Node.js (LTS)
brew install node

# 3. Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env

# 4. Install Tauri CLI (v2)
cargo install tauri-cli --version "^2.0"
# OR via npm (faster):
npm install -g @tauri-apps/cli@^2.0

# 5. macOS system dependencies (Xcode Command Line Tools)
xcode-select --install
```

## First-time install

```bash
cd 4h-unfolder-mac
npm install
```

## Development

```bash
npm run tauri:dev
# Opens the app with hot-reload for both React and Rust changes.
```

## Production build (.app + .dmg)

```bash
npm run tauri:build
# Output: src-tauri/target/release/bundle/dmg/4H\ Unfolder_0.1.0_x64.dmg
#         src-tauri/target/release/bundle/macos/4H\ Unfolder.app
```

## Project structure

```
4h-unfolder-mac/
├── src/                         # React + TypeScript frontend
│   ├── components/
│   │   ├── Canvas/              # Pattern canvas (Konva)
│   │   │   ├── PatternCanvas    # Stage + zoom/pan
│   │   │   ├── FaceShape        # Unfolded face polygon
│   │   │   ├── GlueTabShape     # Glue tab polygon
│   │   │   ├── SheetBackground  # A4 sheet rect
│   │   │   └── DropZone         # Empty-state drag target
│   │   ├── Toolbar/             # Top toolbar
│   │   ├── Sidebar/             # Properties panel
│   │   ├── Dialogs/             # Settings dialog
│   │   └── Layout/              # Root app layout
│   ├── state/                   # Zustand stores
│   │   ├── meshStore            # Loaded mesh + loading state
│   │   ├── unfoldStore          # UnfoldResult + flap overrides
│   │   ├── uiStore              # Mode, selection, viewport, dialogs
│   │   └── settingsStore        # AppSettings + persistence
│   ├── services/
│   │   ├── meshLoader           # File dialog + drop handler
│   │   └── exportService        # SVG / PDF export dialogs
│   ├── hooks/
│   │   ├── useCanvas            # Zoom/pan + multi-select key
│   │   └── useKeyboard          # Global keyboard shortcuts
│   └── types/
│       ├── mesh.ts              # Mesh / Vertex / Edge types
│       ├── unfold.ts            # UnfoldResult / GlueTab types
│       ├── settings.ts          # AppSettings + defaults
│       └── tauri.ts             # Typed invoke() wrappers
│
└── src-tauri/                   # Rust backend
    └── src/
        ├── models/              # Serialisable data types
        │   ├── mesh.rs
        │   ├── unfold.rs
        │   └── settings.rs
        ├── algorithms/          # Core geometry algorithms
        │   ├── spanning_tree    # Kruskal MST over face-dual graph
        │   ├── face_unfold      # Recursive 3D→2D projection
        │   ├── glue_tabs        # Trapezoid tab generation
        │   └── layout           # Row-based auto-arrange
        └── commands/            # Tauri IPC commands
            ├── mesh             # load_obj / load_obj_from_bytes
            ├── unfold           # unfold_mesh / get_face_adjacency
            ├── export           # export_svg / export_pdf
            ├── project          # save_project / load_project (.4hu)
            └── settings         # load_settings / save_settings
```

## Keyboard shortcuts

| Key   | Action             |
|-------|--------------------|
| ⌘O    | Open mesh file     |
| ⌘S    | Export SVG         |
| ⌘,    | Settings           |
| U     | Unfold             |
| Esc   | Clear selection    |
| Scroll| Zoom in/out        |
| Drag  | Pan canvas         |
