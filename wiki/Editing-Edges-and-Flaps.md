# Editing Edges & Flaps

After you [unfold](Quick-Start#2-unfold), the 2D canvas lets you refine exactly where the
pattern is cut and where glue tabs (flaps) go. This page is the full reference.

---

## Edge types

Every mesh edge becomes one of three kinds in the pattern:

| Type | Meaning | On paper |
|------|---------|----------|
| **Fold** | Interior seam kept attached — the two faces stay in one piece | Dashed fold line |
| **Cut** | Seam separated — the faces belong to different pieces (or the same piece via a tab) | Solid cut outline |
| **Border** | A mesh boundary with no adjacent face | Solid outline; can carry a tab |

**Click an edge** on the canvas to toggle it between **fold** and **cut**. Cutting more edges
splits the pattern into more, smaller pieces; folding edges merges pieces back together.

---

## Joining and disjoining pieces

- **Join** — reattach a piece to a neighbour along a shared edge. A **preview arrow** shows
  where and how the piece will fold in before you commit.
- **Disjoin** — detach along an edge, turning a fold into a cut.

Use this to control how the model breaks apart — e.g. keep a face group together so it folds
as one flap, or split a piece that overlaps itself.

---

## Glue tabs (flaps)

Tabs are the extra paper you fold under and glue. Two things control them: the **shape**
(global) and the **per-edge mode** (override).

### Tab shapes
Choose globally: **Trapezoid** (default, most forgiving), **Rectangle**, or **Triangle**.
There's also an **alternate-flap** mode that automatically staggers tabs from one face to the
other along a seam so two tabs never stack on the same edge.

### Per-edge flap modes
Right-click / open the flap editor on an edge to override the global behaviour. The mode set
depends on whether the edge is an **inner** (shared) edge or a **border** edge.

**Inner edge** (cut edge shared between two faces):

| Mode | Effect |
|------|--------|
| `Default` | Follow the global alternate-flaps logic |
| `SwitchPosition` | Swap which of the two faces carries the tab |
| `OnOn_ThisSide` | Tab on the face you designated as "this side" when clicking |
| `OffOn_OtherSide` | Tab on the partner face only (suppress this side) |
| `OffOff_NoFlap` | No tab on either side of this edge |
| `OnOn_BothSides` | Tabs on **both** faces of the edge |

**Border edge** (mesh boundary, no partner face):

| Mode | Effect |
|------|--------|
| `Border_MountainFold` | Add a tab annotated as a mountain fold |
| `Border_ValleyFold` | Add a tab annotated as a valley fold |
| `Border_NoFold` | Add a tab with no fold annotation |
| `Border_NoFlap` | Explicitly no tab |

> The "this side" / partner distinction (used by `OnOn_ThisSide`, `OffOn_OtherSide`,
> `SwitchPosition`) is set by **which face you click** when choosing the override.

Flap overrides are saved inside the [`.4hu` project bundle](Quick-Start#6-save-your-work-optional),
so your customizations survive a reload — and are cross-platform between Windows and macOS.

---

## Moving, rotating, grouping pieces

- **Drag** a piece to reposition it on the page.
- **Rotate handle** on a selected piece spins it (useful for packing).
- **Lasso-select** multiple pieces with a rubber-band drag; hold **Shift** to add to the selection.
- **Group / Ungroup** — grouped pieces move and rotate as one unit; groups persist in the `.4hu`.
- **Right-drag** pans the canvas; scroll zooms.

---

## Undo / Redo
Edge toggles and flap overrides are captured as lightweight snapshots, so **Undo / Redo**
step through your edits safely.
