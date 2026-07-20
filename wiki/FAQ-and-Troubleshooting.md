# FAQ & Troubleshooting

Common questions and fixes. If your issue isn't here, please
[open an issue](https://github.com/nghiazer/4H-Unfolder/issues).

---

## Installation & launch

### The app doesn't open on Windows
Almost always a **missing native DLL**. Windows self-contained WPF apps do **not** bundle
their native DLLs into the `.exe`; the following must sit in the **same folder** as it:

```
wpfgfx_cor3.dll   PresentationNative_cor3.dll   D3DCompiler_47_cor3.dll
PenImc_cor3.dll   vcruntime140_cor3.dll         assimp.dll
```

**Symptom:** the process appears as **Suspended** in Task Manager, no window opens, and the
Windows Event Log shows a `DllNotFoundException`.

**Fix:** re-extract the full portable ZIP (don't move the `.exe` out on its own), or use the
installer, which places every file correctly.

### macOS says "the developer cannot be verified"
Alpha builds are ad-hoc signed, not notarized. **Right-click the app → Open → Open** to tell
Gatekeeper to trust it. You only do this once per download. (Double-clicking will keep showing
the warning — you must use right-click → Open the first time.)

---

## Importing models

### My `.obj` loads but has no texture / wrong colors
The `.obj` references its material and images via a `.mtl` file. Make sure the `.mtl` and the
texture image files are next to the `.obj` and named as the `.obj`/`.mtl` expect. Missing
textures fall back to a flat color.

### A `.pdo` won't import
Only **Pepakura Designer v3** files are supported. Files from other/newer Pepakura versions,
or password-locked `.pdo` files, may fail to parse.

---

## Unfolding

### Some pieces are red / flagged as overlapping
Red means two faces of a piece overlap in 2D, so it can't be cut as one flat piece. To fix:

1. Run **Auto-Arrange**, which also tries to reduce overlaps by repositioning.
2. **Cut an edge** inside the offending piece to split it into two smaller pieces.
3. Manually **drag** pieces apart into empty page space.

Highly curved or closed shapes will always need several cuts — that's expected for papercraft.

### The unfolded model is way too big or too small
Set the real-world target size in the **Setup dialog** shown right after you press **Unfold**
(e.g. target height in mm). You can re-unfold to apply a new size.

---

## Export & printing

### My printed model is the wrong size
Print at **100% / "Actual size"**, never **"Fit to page"** or **"Scale to fit"** — those resize
the pattern and break the millimetre scale. In the print dialog, set scale to `100%` and disable
any auto-fit option. Print one test page and measure a known edge against the on-screen dimension
to confirm before printing the whole model.

### SVG vs PDF — which should I use?
- **PDF** — print directly; page-accurate. Best for home printing.
- **SVG** — vector; best if you'll edit in Illustrator/Inkscape or feed a cutting machine
  (Cricut, Silhouette, laser cutter).

---

## Projects

### Can I open a Windows `.4hu` on macOS (or vice-versa)?
Yes. The `.4hu` bundle (mesh + textures + overrides + piece positions + groups) is
cross-platform between the Windows and macOS builds.
