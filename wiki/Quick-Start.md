# Quick Start

This walkthrough takes a 3D model from import to a printable PDF in five steps.
It assumes you've already [installed the app](Installation).

> 📸 _Screenshot placeholders below — capture one per step and drop them in._

---

## 1. Import a mesh

**Load Mesh** (toolbar) → pick an `.obj` or `.pdo` file.

- `.obj` — Wavefront OBJ, with optional `.mtl` material and UV texture images.
- `.pdo` — Pepakura Designer v3 files (binary, embedded textures).

The model appears in the **3D viewport** on the left. Rotate with drag, zoom with scroll.

> 🖼 _Screenshot: model loaded in 3D viewport._

---

## 2. Unfold

Press **Unfold**. The app:

1. builds a graph of which faces touch which,
2. picks a spanning tree that prefers flat seams (Kruskal MST by fold angle),
3. flattens the faces into 2D paper space,
4. adds glue tabs and marks fold vs. cut edges.

A **Setup dialog** lets you target a real-world size (e.g. "model should be 150 mm tall").
The flat pieces show up in the **2D canvas** on the right, measured in millimetres.

> 🖼 _Screenshot: 2D pattern with tabs and fold lines._

**Red pieces = overlap.** If any piece is flagged as overlapping, see
[step 4](#4-fix-overlaps-and-lay-out-pages) before printing.

---

## 3. Adjust edges and flaps (optional)

On the 2D canvas you can refine the pattern:

- **Click an edge** to toggle it between **fold** and **cut**.
- **Join / disjoin** adjacent pieces — a preview arrow shows where a piece will reattach.
- Change a **glue-tab shape** (trapezoid / rectangle / triangle) or per-edge flap mode.
- **Drag** a piece to move it; use the **rotate handle** to spin it.
- **Lasso-select** multiple pieces (hold **Shift** to add); **group** them so they move together.

_A dedicated **Editing Edges & Flaps** page is planned for the full reference._

---

## 4. Fix overlaps and lay out pages

- Use **Auto-Arrange** to pack pieces onto pages without overlap.
- Pick a **paper size** (A4/A3/Letter…) and **portrait/landscape** in settings.
- Manually drag any remaining red (overlapping) piece to empty space, or cut an edge to split it.

The goal: every piece sits inside a page boundary, nothing red.

> 🖼 _Screenshot: pieces arranged across A4 pages._

---

## 5. Export

- **Export SVG** — vector, best for editing in Illustrator/Inkscape or cutting machines.
- **Export PDF** — print-ready, page-accurate.
- Toggle **grayscale** if you're printing without color.

> ✅ **Print at 100% scale / "Actual size"** — do **not** use "Fit to page", or the model
> will come out the wrong dimensions. See
> [FAQ → wrong print size](FAQ-and-Troubleshooting#my-printed-model-is-the-wrong-size).

---

## 6. Save your work (optional)

**Save Project** writes a `.4hu` file — a self-contained bundle with the mesh, textures,
your edge/flap overrides, piece positions, and groups. It's cross-platform: a `.4hu` saved
on Windows opens on macOS and vice-versa.
