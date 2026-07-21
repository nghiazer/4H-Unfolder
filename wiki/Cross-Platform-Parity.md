# Cross-Platform Parity

4H-Unfolder ships as two native apps. The **Windows** build is production; the **macOS** build
is a native Swift port catching up to it. This page tracks where they match and where they differ.

| | Windows | macOS |
|--|---------|-------|
| **Status** | ✅ Production `v0.2.0.A` | 🚧 Alpha `v0.0.0.5-alpha` |
| **Stack** | WPF · .NET 8 · C# | SwiftUI · SceneKit · Swift |
| **Distribution** | Inno Setup installer + portable ZIP | Ad-hoc signed `.app` (notarization pending) |

---

## Feature matrix

| Feature | Windows | macOS |
|---------|:------:|:-----:|
| OBJ import (+ MTL + UV textures) | ✅ | ✅ |
| PDO v3 import | ✅ | ✅ |
| Extra mesh formats (Assimp) | ✅ | ❌ |
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
| SVG + PDF export (grayscale option) | ✅ | ✅ |
| `.4hu` project bundles (cross-platform) | ✅ | ✅ |
| Undo / redo | ✅ | ✅ |
| Preferences panel | ✅ | ✅ |
| **Outline padding** | ✅ (v0.1.1.A) | ❔ |
| **Merge adjacent flaps** | ✅ (v0.1.1.A) | ❔ |
| **Join connected cut edges** | ✅ (v0.1.1.A) | ❔ |

✅ present · ❌ not implemented · ❔ not yet verified on macOS

> The core feature set is at parity. Windows leads on **extra import formats** (Assimp) and the
> **v0.1.1.A layout refinements** (outline padding, merged flaps, joined cut edges) — bringing
> those to macOS is tracked on the [Roadmap](Roadmap).

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
