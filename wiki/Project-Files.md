# Project Files (`.4hu`)

Saving your work writes a **`.4hu`** file — a single, self-contained bundle that captures
everything needed to reopen the project exactly as you left it, on either platform.

---

## What's inside

A `.4hu` is a **ZIP archive** (binary — don't try to open it in a text editor). Its entries:

| Entry | Contents |
|-------|----------|
| `state.json` | The full project state (see below) |
| `mesh.obj` | The source mesh, embedded so the original file isn't needed |
| `texture.<ext>` | Legacy / single fallback texture (optional) |
| `texture_<matId>.<ext>` | One embedded image **per material**, keyed by material ID |

Because the mesh and textures are embedded, a `.4hu` is portable — you can move or share it
without dragging along the original `.obj` and image files.

---

## What `state.json` stores

The project state (currently **version 2**) records everything layered on top of the raw mesh:

- **Import transform** — `ScaleMmPerUnit`, `MirrorX`
- **Page layout** — paper size (`Name`, `WidthMm`, `HeightMm`), `PagesWide`, `PagesTall`
- **Edge overrides** — your manual fold ↔ cut toggles, keyed by mesh edge ID
- **Flap overrides** — per-edge [`FlapMode`](Editing-Edges-and-Flaps#per-edge-flap-modes)
  (+ the "this side" face), keyed by mesh edge ID
- **Piece layouts** — per-piece `PositionX/Y`, `Rotation`, and group membership
  (`GroupId`, `UserGroupId`) so your arrangement and groupings are preserved
- **Texture bookkeeping** — which material maps to which embedded image, and their extensions
- **Warnings** — any non-fatal notes recorded while loading

---

## Cross-platform

A `.4hu` saved on **Windows** opens on **macOS** and vice-versa — the bundle format and
`state.json` schema are shared. This is the intended way to move a project between the two apps.

---

## Legacy `.pmc`

The same project state can also be saved as a plain-JSON **`.pmc`** file. Unlike `.4hu`, a
`.pmc` does **not** embed the mesh or textures — it only references their paths, so it breaks if
those files move. Prefer `.4hu` for anything you want to keep or share.

---

## Source
Windows: `FourHUnfolder.Application/ProjectSerializer.cs`, `ProjectState.cs` ·
macOS: `Sources/FourHUnfolderCore/Services/ProjectSerializer.swift`
