# Export & Printing

Once your pattern has no overlaps and the pieces are laid out on pages, export it for cutting.

---

## SVG vs PDF vs PNG

| Format | Use it when… |
|--------|--------------|
| **PDF** | You'll print at home and cut by hand. Page-accurate, print-ready. |
| **SVG** | You'll edit the vectors (Illustrator / Inkscape) or feed a **cutting machine** that reads vector paths (Cricut, Silhouette, laser). |
| **PNG** | Your cutting-machine software only imports **bitmaps**, not vectors. One image is written per page, at a configurable DPI. |

All three preserve the true millimetre scale of the pattern. A **grayscale** toggle is available
for printing without color (or to save ink) — it applies to fills, fold/cut lines, and edge labels
in all three formats.

### SVG cutting-machine layers

SVG exports group fold lines, cut lines, edge labels, glue tabs, and outline padding into separate
Inkscape-style `<g inkscape:groupmode="layer">` groups. Software that understands Inkscape layers
(LightBurn, Inkscape itself, some Cricut Design Space imports) lets you show/hide each group or
assign different cut/engrave settings per layer — for example, cutting the outer silhouette while
only *scoring* (not cutting) the fold lines.

---

## Page layout

Before exporting:

- **Auto-Arrange** packs pieces onto pages without overlap.
- Pick a **paper size** — A4 / A3 / A2 / A1 / Letter / Legal — and **portrait / landscape**.
- Multi-page patterns split automatically across sheets.

---

## Printing at the correct size ⚠️

This is the single most common mistake. The pattern is measured in real millimetres, so it
**must be printed without scaling**:

1. In the print dialog, set scale to **100%** / **"Actual size"**.
2. **Disable** any "Fit to page", "Shrink to fit", or "Scale to fit" option.
3. Print **one** page first as a test.
4. Measure a known edge on paper against the on-screen dimension. If it matches, print the rest.

If the printed model comes out too big or too small, a fit-to-page setting is almost always the
cause — see [FAQ → wrong print size](FAQ-and-Troubleshooting#my-printed-model-is-the-wrong-size).

---

## Assembly tips

- **Fold lines** are dashed; **cut lines** are solid — cut only the solid outlines.
- Fold each **tab** under and glue it beneath the neighbouring face.
- Mountain vs valley fold annotations (from [border flap modes](Editing-Edges-and-Flaps#per-edge-flap-modes))
  tell you which way to fold.
- Number-match seams by eye, or keep the 3D viewport open for reference while assembling.
