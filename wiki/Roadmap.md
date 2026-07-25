# Roadmap

Where 4H-Unfolder is headed. Items are drawn from the internal tech-debt log; this page is the
public version. Priorities: 🔴 High · 🟡 Medium · 🟢 Low.

> Want to help with any of these? See
> [CONTRIBUTING](https://github.com/nghiazer/4H-Unfolder/blob/main/4h-unfolder-win/CONTRIBUTING.md)
> and open an issue to claim it.

---

## Recently shipped

Backlog-clearing pass (2026-07-25), both platforms unless noted:

- ✅ **Outline padding wired into export/canvas on macOS** — the offset math (`PolygonOffset`)
  existed since GĐ1 but had no piece-boundary tracer to hand it a polygon; ported Windows'
  `BoundaryPolygonComputer` to close the gap. SVG + canvas only, matching Windows (no PDF on
  either platform)
- ✅ **Configurable overlap-retry budget** — was fixed at 8 attempts on both platforms, now a
  setting (`OverlapRetrySeedCount` / `overlapRetrySeedCount`)
- ✅ **`FlapOverride.Deserialize` corrupt-data warning** (Windows) — surfaces through the existing
  project-load warnings pipeline instead of only a debug-only log line
- ✅ **`EditFlapsViewModel` settings wiring cleanup** (Windows) — cosmetic; the dialog already read
  live defaults from `AppSettings`, this just removed the misleading duplicate hardcoded values
- ✅ **Undo now covers piece layout on macOS** — drag, pivot-rotate, and Align Selected are all
  undoable, matching Windows' unified `EditSnapshot`/`PushDragUndo`
- ✅ **`PNGExporter` now honors the `svgScaleFactor` print-calibration setting on macOS** — matches
  SVG/PDF; PNG's physical page size stays fixed to the real paper dimensions, only content scales
- ✅ **STL import on macOS** — first non-OBJ/PDO format, dependency-free (binary + ASCII)
- ✅ **Select Symmetrical Pair (Windows)** — pick 1 piece, auto-selects its mirror-image
  counterpart. Scoped to axis-aligned mirror symmetry (cardinal-axis plane through the mesh's
  bounding-box center) rather than arbitrary-orientation detection

Delivered in **v0.4.0.A** (Windows) / **v0.0.0.7-alpha** (macOS) — GĐ4 + GĐ3.3 of the
papercraft-parity effort:

- ✅ **PNG export** — one raster image per page, configurable DPI, for cutting-machine software
  that only imports bitmaps
- ✅ **SVG cutting-machine layers** — Inkscape-style `<g>` groups (Fold Lines / Cut Lines / Edge
  Labels / Glue Tabs / Outline Padding) so LightBurn / Cricut Design Space / Inkscape can
  show/hide or assign per-operation settings by layer
- ✅ **Join connected cut edges on macOS** — ⌥-click a cut edge to join the whole connected chain
  in one action (Windows already had this via a right-click context menu, from v0.1.1.A)
- ✅ **Align pieces on macOS** — 6-way toolbar alignment (left/right/center-H/top/bottom/center-V)
  for ≥2 selected pieces (Windows already had this)

Delivered in **v0.3.0.A** (Windows) / **v0.0.0.6-alpha** (macOS) — the earlier papercraft-parity
phases, learned from studying [rodrigorc/papercraft](https://github.com/rodrigorc/papercraft) and
[osresearch/papercraft](https://github.com/osresearch/papercraft); on **both** platforms unless noted:

- ✅ **Coplanar fold-line hide** — suppress fold lines between near-flat faces
- ✅ **Edge-matching labels** — cut-edge pair numbers on canvas + export, for assembly guidance
- ✅ **Merge adjacent flaps on macOS** — ported without Clipper2 (dependency-free polygon union)
- ✅ **Auto-arrange tries a 90° rotation per piece on macOS** — already on Windows, now matched
- ✅ **Overlap-reducing unfold retry** — automatically tries alternate near-minimal spanning trees
  when the default unfold overlaps, keeping the least-overlap result (epsilon-bounded tie-break —
  real meshes almost never have exact-tied dihedral angles, so this needed care to be effective;
  see [`PARITY-PROGRESS.md`](https://github.com/nghiazer/4H-Unfolder/blob/main/PARITY-PROGRESS.md))

Delivered in **Windows v0.1.1.A**:

- ✅ **Outline padding** — polygon-offset outline around pieces
- ✅ **Merge adjacent flaps** — union of neighbouring tab polygons
- ✅ **Join connected cut edges** — reconnect adjacent isolated cut edges

---

## Windows

| Priority | Item | Notes |
|:---:|------|-------|
| 🟢 | Split window | Detachable / side-by-side 3D + 2D panes |
| 🟢 | Change coordinates | Re-origin / re-orient the model interactively |

---

## macOS

Goal: reach **feature parity with Windows**, then graduate from alpha → beta.

| Priority | Item |
|:---:|------|
| 🟡 | More import formats beyond OBJ/PDO/STL (Assimp covers 3DS/DXF/LWO/FBX/DAE/PLY/X on Windows) |
| 🟡 | Notarized, signed distribution (Developer ID) — `build-release.sh` now supports this via `APPLE_DEVELOPER_ID`/`APPLE_NOTARY_PROFILE` env vars (see script header), just needs a maintainer with a paid Developer account to actually run it |

---

## Cross-cutting

| Priority | Item | Notes |
|:---:|------|-------|
| 🟢 | Performance | Profiled (3200-face synthetic mesh, both platforms): the overlap-retry loop costs 33-56× a single unfold pass — worse than its 8-attempt budget suggests, because `CountOverlaps` (used to compare retry candidates) has no early exit unlike the cheaper `HasOverlaps`. See `PARITY-PROGRESS.md` for numbers and a fix direction |
| 🟢 | Docs | [Glossary](Glossary) is already complete. Still open: 1 demo GIF (`Home.md`) + 3 screenshots (`Quick-Start.md`, steps 1/2/4) — needs interactive capture from a running session (load a model, unfold, arrange pages), attempted in backlog Phase 8 but genuinely blocked: this environment's screen capture doesn't correspond to the actual app window (captures the IDE instead) — needs a maintainer with a normal desktop session, see `PARITY-PROGRESS.md` |

---

## Version history

For released versions and their changes, see the git tags
([`v0.0.1.A` … `v0.4.0.A`](https://github.com/nghiazer/4H-Unfolder/tags)) and
`4h-unfolder-win/BUGS_HISTORY.md` in the repo.

> This roadmap reflects intent, not commitment — priorities may shift.
