# Roadmap

Where 4H-Unfolder is headed. Items are drawn from the internal tech-debt log; this page is the
public version. Priorities: 🔴 High · 🟡 Medium · 🟢 Low.

> Want to help with any of these? See
> [CONTRIBUTING](https://github.com/nghiazer/4H-Unfolder/blob/main/4h-unfolder-win/CONTRIBUTING.md)
> and open an issue to claim it.

---

## Recently shipped

Fixed after **v1.1.0.A** (2026-08-18):

- ✅ **macOS glue tabs were generated on the wrong side of every cut edge**
  ([#70](https://github.com/nghiazer/4H-Unfolder/issues/70)) — `GlueTabGenerator`'s
  outward-direction check had its branches swapped relative to the Windows reference, so every tab
  folded into the piece's own interior instead of away from it. Found by comparing directly against
  the Windows implementation (the issue itself had no repro mesh attached).

Delivered in **v1.1.0.A** (Windows) — full-codebase cross-review pass (2026-07-26):

- ✅ **Grouping fixed** — `RerunUnfold` was silently clearing `UserGroupId` on almost every edge/flap
  edit, and group-drag didn't move ungrouped-but-linked siblings; both fixed together
- ✅ **Auto-Arrange is now undoable**
- ✅ **`MainViewModel` lifetime leak on exit fixed** — was disposing a throwaway instance instead of
  the live one, leaking `.4hu` temp-extraction directories on every normal app exit
- ✅ **Release-build settings-save failures are no longer silent** — surfaced via `StatusText`
- ✅ **`.pdo` loader hardened** against unbounded counts/indices read from untrusted file content;
  `.4hu` bundle loader gained a zip-bomb guard
- ✅ **PDF export no longer crashes** on a malformed color string in settings
- ✅ **Quick-Start screenshots captured** — closes the item below that was blocked in backlog Phase 8

Delivered in **v1.0.0.A** (Windows) / **v1.0.0-beta** (macOS) — 8-phase backlog-clearing pass
(2026-07-25), both platforms unless noted:

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
| 🟡 | [Piece with a hole gets wrong outline padding](https://github.com/nghiazer/4H-Unfolder/issues/72) | `TD-44-1` — `BoundaryPolygonComputer` only traces one boundary loop |
| 🟢 | [Non-manifold mesh → wrong assembly fold angle](https://github.com/nghiazer/4H-Unfolder/issues/73) | `TD-44-2` |
| 🟢 | [Inconsistent snap-tolerance constants](https://github.com/nghiazer/4H-Unfolder/issues/74) | `TD-44-3` — `FlapMerger` vs `BoundaryPolygonComputer`, 10× apart |
| 🟢 | [Mirror-X undo incomplete](https://github.com/nghiazer/4H-Unfolder/issues/75) | `TD-44-4` |
| 🟢 | [Lasso selection scroll-jump](https://github.com/nghiazer/4H-Unfolder/issues/76) | `TD-44-5` |
| 🟢 | [Edit Flaps "R =" angle field discarded](https://github.com/nghiazer/4H-Unfolder/issues/77) | `TD-44-6` — needs a domain-model left/right angle concept |
| 🟢 | [Edit Flaps stale settings if Settings dialog left open](https://github.com/nghiazer/4H-Unfolder/issues/78) | `TD-44-7` |

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
| 🟢 | Performance (unfold pipeline) | Profiled (3200-face synthetic mesh, both platforms): the overlap-retry loop costs 33-56× a single unfold pass — worse than its 8-attempt budget suggests, because `CountOverlaps` (used to compare retry candidates) has no early exit unlike the cheaper `HasOverlaps`. See `PARITY-PROGRESS.md` for numbers and a fix direction |
| 🟡 | [Performance (2D canvas interaction)](https://github.com/nghiazer/4H-Unfolder/issues/71) | Feels slow/laggy during pan/zoom/drag on moderately complex models (~600-700 faces); confirmed on both macOS (SwiftUI `Canvas`) and Windows. Not yet profiled — needs a proper pass (Instruments on macOS, or checking `PatternCanvasControl`'s render/hit-test path on Windows) to find root cause |
| 🟢 | Docs | [Glossary](Glossary) is already complete. Quick-Start screenshots (steps 1/2/4) captured 2026-07-26 by driving a real running build via UI Automation — see `PARITY-PROGRESS.md` for the approach. Still open: 1 demo GIF for `Home.md` |

---

## Version history

For released versions and their changes, see the git tags
([`v0.0.1.A` … `v1.1.0.A`](https://github.com/nghiazer/4H-Unfolder/tags)) and
`4h-unfolder-win/BUGS_HISTORY.md` in the repo.

> This roadmap reflects intent, not commitment — priorities may shift.
