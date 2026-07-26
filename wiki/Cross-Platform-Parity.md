# Cross-Platform Parity

4H-Unfolder ships as two native apps. The **Windows** build is production; the **macOS** build
is a native Swift port catching up to it. This page tracks where they match and where they differ.

| | Windows | macOS |
|--|---------|-------|
| **Status** | ✅ Production `v1.1.0.A` | 🚧 Beta `v1.0.0-beta` |
| **Stack** | WPF · .NET 8 · C# | SwiftUI · SceneKit · Swift |
| **Distribution** | Inno Setup installer + portable ZIP | Ad-hoc signed `.app` (Developer ID + notarize scaffolding ready in `build-release.sh`, pending a maintainer with a paid Apple Developer account) |

---

## Feature matrix

| Feature | Windows | macOS |
|---------|:------:|:-----:|
| OBJ import (+ MTL + UV textures) | ✅ | ✅ |
| PDO v3 import | ✅ | ✅ |
| Extra mesh formats (Assimp: FBX/DAE/3DS/DXF/LWO/PLY, + STL) | ✅ | 🟡 STL only |
| Auto-unfold (Kruskal MST → BFS) | ✅ | ✅ |
| Real-world target-size dialog | ✅ | ✅ |
| Edge fold ↔ cut toggle | ✅ | ✅ |
| Join / disjoin with preview arrow | ✅ | ✅ |
| Per-edge FlapMode (10 variants) | ✅ | ✅ |
| Glue-tab shapes + alternate flaps | ✅ | ✅ |
| 2D canvas: zoom/pan, drag, rotate | ✅ | ✅ |
| Lasso multi-select + group/ungroup | ✅ | ✅ |
| UV texture rendering (2D + 3D) | ✅ | ✅ |
| Overlap detection (spatial grid + SAT) | ✅ | ✅ |
| Auto-arrange + paper sizes | ✅ | ✅ |
| SVG + PDF + PNG export (grayscale option) | ✅ | ✅ |
| `.4hu` project bundles (cross-platform) | ✅ | ✅ |
| Undo / redo | ✅ | ✅ |
| Preferences panel | ✅ | ✅ |
| **Outline padding** | ✅ (v0.1.1.A) | ✅ (v1.0.0-beta) |
| **Merge adjacent flaps** | ✅ (v0.1.1.A) | ✅ (v0.0.0.6-alpha) |
| **Join connected cut edges** | ✅ (v0.1.1.A) | ✅ (v0.0.0.7-alpha) |
| **Coplanar fold-line hide** | ✅ (v0.3.0.A) | ✅ (v0.0.0.6-alpha) |
| **Edge-matching labels** | ✅ (v0.3.0.A) | ✅ (v0.0.0.6-alpha) |
| **Auto-arrange tries 90° rotation** | ✅ | ✅ (v0.0.0.6-alpha) |
| **Overlap-reducing unfold retry** | ✅ (v0.3.0.A) | ✅ (v0.0.0.6-alpha) |
| **Align pieces (6-way)** | ✅ | ✅ (v0.0.0.7-alpha) |
| **PNG export (one image per page)** | ✅ (v0.4.0.A) | ✅ (v0.0.0.7-alpha) |
| **SVG cutting-machine layers (Inkscape `<g>`)** | ✅ (v0.4.0.A) | ✅ (v0.0.0.7-alpha) |
| **Undo covers piece layout (drag/rotate/align)** | ✅ | ✅ (v1.0.0-beta) |
| **PNG export honors print-scale calibration** | ❌ (same latent gap, not yet fixed) | ✅ (v1.0.0-beta) |
| **Configurable overlap-retry budget** | ✅ (v1.0.0.A) | ✅ (v1.0.0-beta) |
| **STL import** | ✅ (via Assimp) | ✅ (v1.0.0-beta) |
| **Select Symmetrical Pair** | ✅ (v1.0.0.A) | ❌ not planned |

✅ present · 🟡 partial · ❌ not implemented · ❔ not yet verified on macOS

> The core feature set is at parity, and the full papercraft-parity effort (coplanar-hide,
> edge-matching labels, merge adjacent flaps, auto-arrange rotation, overlap-reducing retry, join
> connected cut edges, align pieces, PNG export, SVG cutting-machine layers) plus an 8-phase
> backlog-clearing pass (outline padding wired to macOS export/canvas, undo unified to cover piece
> layout, PNG print-scale fix, STL import, notarize scaffolding, Windows Select Symmetrical Pair)
> has now landed. Windows still leads on **extra import formats** (Assimp covers many more formats
> than macOS's OBJ/PDO/STL) — tracked on the [Roadmap](Roadmap). See
> [`PARITY-PROGRESS.md`](https://github.com/nghiazer/4H-Unfolder/blob/main/PARITY-PROGRESS.md) at
> the repo root for the full plan and verification log.

---

## Deliberate platform differences

Some things differ by design because each app uses its OS's native frameworks — not gaps to
close. See [Architecture → rendering differs by platform](Architecture-Overview#rendering-differs-by-platform):

- 3D viewport: WPF 3D/DirectX (Win) vs SceneKit/Metal (mac)
- 2D canvas: WPF `Canvas` vs SwiftUI `Canvas`
- PDF: `PdfExporter` vs Core Graphics
- Settings store: `%AppData%\4H-Unfolder\settings.json` vs `~/Library/Application Support/4H-Unfolder/`

The **unfold algorithm and `.4hu` format are shared by design**, so a project moves between
platforms without conversion.
