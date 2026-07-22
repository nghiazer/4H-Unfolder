# Roadmap

Where 4H-Unfolder is headed. Items are drawn from the internal tech-debt log; this page is the
public version. Priorities: 🔴 High · 🟡 Medium · 🟢 Low.

> Want to help with any of these? See
> [CONTRIBUTING](https://github.com/nghiazer/4H-Unfolder/blob/main/4h-unfolder-win/CONTRIBUTING.md)
> and open an issue to claim it.

---

## Recently shipped

Delivered in **v0.3.0.A** (Windows) / **v0.0.0.6-alpha** (macOS) — the "papercraft-parity" effort,
learned from studying [rodrigorc/papercraft](https://github.com/rodrigorc/papercraft) and
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

_(macOS outline padding is computed but not yet wired to export/canvas; join connected cut edges
isn't ported yet — tracked under [macOS parity](#macos) below.)_

---

## Windows

| Priority | Item | Notes |
|:---:|------|-------|
| 🟢 | Select symmetrical pair | Pick an edge/piece and auto-select its mirror |
| 🟢 | Split window | Detachable / side-by-side 3D + 2D panes |
| 🟢 | Change coordinates | Re-origin / re-orient the model interactively |
| 🟢 | Settings wiring | `EditFlapsViewModel` hardcodes 5 mm / 45° — fall back to `AppSettings` |
| 🟢 | Corrupt-data warning | `FlapOverride.Deserialize` silently ignores bad data — surface a warning |
| 🟢 | Configurable retry budget | Overlap-reducing unfold retry currently fixed at 8 attempts — consider exposing as a setting for very large meshes |

---

## macOS

Goal: reach **feature parity with Windows**, then graduate from alpha → beta.

| Priority | Item |
|:---:|------|
| 🔴 | Wire outline padding into export/canvas (the offset math already exists — `PolygonOffset`) |
| 🟡 | Port "join connected cut edges" from Windows v0.1.1.A |
| 🟡 | Verify full [feature parity](Cross-Platform-Parity#feature-matrix) — resolve the ❔ rows |
| 🟡 | Extra import formats (Assimp equivalent) |
| 🟡 | Notarized, signed distribution (Developer ID) |

---

## Cross-cutting

| Priority | Item | Notes |
|:---:|------|-------|
| 🟢 | Performance | Overlap detection now uses a spatial grid; profile meshes > 2000 faces for remaining hotspots |
| 🟢 | Docs | Fill wiki placeholders (demo GIF, per-step screenshots); add a Glossary — see [Glossary](Glossary) |
| 🟡 | Interactive Edge/Face mode | rodrigorc-style: click edge to cut/join, drag/rotate piece, all in one polished 2D workflow — both platforms already have partial edge-toggle + drag/rotate; this unifies them. Large item, own task. |

---

## Version history

For released versions and their changes, see the git tags
([`v0.0.1.A` … `v0.3.0.A`](https://github.com/nghiazer/4H-Unfolder/tags)) and
`4h-unfolder-win/BUGS_HISTORY.md` in the repo.

> This roadmap reflects intent, not commitment — priorities may shift.
