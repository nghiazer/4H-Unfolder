# Roadmap

Where 4H-Unfolder is headed. Items are drawn from the internal tech-debt log; this page is the
public version. Priorities: 🔴 High · 🟡 Medium · 🟢 Low.

> Want to help with any of these? See
> [CONTRIBUTING](https://github.com/nghiazer/4H-Unfolder/blob/main/4h-unfolder-win/CONTRIBUTING.md)
> and open an issue to claim it.

---

## Recently shipped

Delivered in **Windows v0.1.1.A**:

- ✅ **Outline padding** — polygon-offset outline around pieces
- ✅ **Merge adjacent flaps** — union of neighbouring tab polygons
- ✅ **Join connected cut edges** — reconnect adjacent isolated cut edges

_(Bringing these three to macOS is tracked under [macOS parity](#macos) below.)_

---

## Windows

| Priority | Item | Notes |
|:---:|------|-------|
| 🟢 | Select symmetrical pair | Pick an edge/piece and auto-select its mirror |
| 🟢 | Split window | Detachable / side-by-side 3D + 2D panes |
| 🟢 | Change coordinates | Re-origin / re-orient the model interactively |
| 🟡 | Test coverage | Unit tests for `FlapOverride` serialization + `GlueTabGenerator` border modes |
| 🟢 | Settings wiring | `EditFlapsViewModel` hardcodes 5 mm / 45° — fall back to `AppSettings` |
| 🟢 | Corrupt-data warning | `FlapOverride.Deserialize` silently ignores bad data — surface a warning |

---

## macOS

Goal: reach **feature parity with Windows**, then graduate from alpha → beta.

| Priority | Item |
|:---:|------|
| 🔴 | Port the v0.1.1.A layout features (outline padding, merge flaps, join cut edges) |
| 🔴 | Verify full [feature parity](Cross-Platform-Parity#feature-matrix) — resolve the ❔ rows |
| 🟡 | Extra import formats (Assimp equivalent) |
| 🟡 | Notarized, signed distribution (Developer ID) |

---

## Cross-cutting

| Priority | Item | Notes |
|:---:|------|-------|
| 🟢 | Performance | Overlap detection now uses a spatial grid; profile meshes > 2000 faces for remaining hotspots |
| 🟢 | Docs | Fill wiki placeholders (demo GIF, per-step screenshots); add a Glossary — see [Glossary](Glossary) |

---

## Version history

For released versions and their changes, see the git tags
([`v0.0.1.A` … `v0.2.0.A`](https://github.com/nghiazer/4H-Unfolder/tags)) and
`4h-unfolder-win/BUGS_HISTORY.md` in the repo.

> This roadmap reflects intent, not commitment — priorities may shift.
