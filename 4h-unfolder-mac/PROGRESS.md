# 4H-Unfolder macOS — Implementation Progress

Last updated: 2026-06-05 | Current version: v0.0.0.1-alpha

---

## Summary

| Phase | Description | Status | Commit |
|-------|-------------|--------|--------|
| Phase 1 | Rust algorithm core (data model, MST, unfold, glue tabs) | ✅ Complete | `9322b33` |
| Phase 2 | OBJ loader completion + `get_mesh_info` command | ✅ Complete | `fd774f7` |
| Phase 3 | Interactive 2D canvas (drag, lasso, edge toggle, flap edit) | ✅ Complete | `8a1250c` |
| Phase 4 | 3D viewport (React Three Fiber) | ✅ Complete | `5e61f3b` |
| Phase 5 | Export (SVG/PDF), project bundle (.4hu), settings | ✅ Complete | `daf01c9` |
| Phase 6 | PDO loader, EditFlaps, Assembly panel, multi-page UI | ✅ Complete | `a6e5c83` |
| Phase 6B | Test coverage (67 tests) | ✅ Complete | `6d7a6e8` |

---

## Phase 1 — Rust Algorithm Core

**Goal:** Pipeline Rust output matches C# for any test mesh.

- [x] `models/mesh.rs` — `Mesh`, `Face` with `edge_ids[3]`, `MeshEdge` with `EdgeType` (Unknown/Fold/Cut/Boundary)
- [x] `models/unfold.rs` — `UnfoldedFace` (`edge_is_fold[3]`, `edge_is_boundary[3]`, `mesh_edge_ids[3]`, `piece_id`), `GlueTab` (P0/P1/P2/P3), `FlapMode` (10 variants), `FlapOverride`, `UnfoldResult`, `PieceLayout`, `UnfoldResponse`
- [x] `algorithms/spanning_tree.rs` — Kruskal MST with dihedral-angle weights; `mark_edges()` stamps Fold/Cut/Boundary
- [x] `algorithms/face_unfold.rs` — BFS apex reconstruction; `place_root_face`, `triangle_apex`, `reconstruct_apex`, `place_child_face`
- [x] `algorithms/glue_tabs.rs` — `generate_glue_tabs()` with full 10-mode `FlapMode` dispatch; Trapezoid/Rectangle/Triangle shapes
- [x] `algorithms/layout.rs` — row-based auto-arrange pieces
- [x] `algorithms/constants.rs` — `DEGENERATE_EDGE/FACE/TAB`, `SAT_TOUCH_EPSILON`
- [x] `commands/unfold.rs` — full pipeline: build spanning tree → mark edges → unfold faces → glue tabs → cut-pair IDs → dihedral angles → piece layouts
- [x] `commands/mesh.rs` — `build_edges()` stamps `face.edge_ids` winding-order (A→B, B→C, C→A); non-manifold guard

---

## Phase 2 — OBJ Loader + Mesh Info

- [x] Full UV extraction via tobj `texcoords` → `mesh.uvs`, `face.uvs`
- [x] Material names + `diffuse_texture` path resolution (MTL)
- [x] `suggested_texture_path` = first non-null material texture
- [x] MTL security: `Path::file_name()` to prevent path traversal
- [x] `get_mesh_info` command — returns `face_count`, `vertex_count`, `edge_count`, `material_count`, `bounds`, `has_uvs`, `suggested_texture_path`
- [x] `get_texture_as_base64` command — file → base64 for embedded texture display
- [x] `transform_mesh` command — scale + mirror_x
- [x] TypeScript `MeshInfoDto` type + `tauriCommands.getMeshInfo()`

---

## Phase 3 — Interactive 2D Canvas

- [x] `FaceShape.tsx` — 3 separate `<Line>` per edge (fold=blue-dashed, cut=red-solid, boundary=grey); `hitStrokeWidth=6` for interaction
- [x] `PieceGroup.tsx` — Konva `Group` with `draggable` (select mode); RMB drag = rotate; rotation handle circle
- [x] `LassoOverlay.tsx` — Konva `<Line>` track; ray-cast centroid test on mouse-up; Cmd modifier for multi-select
- [x] Edge toggle: click fold↔cut → `setEdgeOverride()` → re-run unfold
- [x] Edit flaps mode: edge click → `openEditFlaps(edgeId, faceId)` → opens `EditFlapsDialog`
- [x] Cut-edge pair labels from `unfoldResult.cutEdgePairIds`
- [x] `historyStore.ts` — snapshot-based undo/redo (edge overrides + flap overrides + piece layouts)
- [x] ⌘Z / ⌘⇧Z keyboard shortcuts in `useKeyboard.ts`
- [x] `SheetBackground.tsx` — multi-page grid (dashed lines + page number labels)

---

## Phase 4 — 3D Viewport

- [x] `MeshViewer.tsx` — React Three Fiber `<Canvas>` + `<OrbitControls>`
- [x] `MeshGeometry.tsx` — TypeScript `Mesh` → Three.js `BufferGeometry` (position + UV + per-material groups)
- [x] Per-material `MeshStandardMaterial` with texture via `convertFileSrc(path)`
- [x] Face selection overlay — amber emissive `BufferGeometry` for `selectedFaceIds`
- [x] Camera fit-to-mesh using `mesh.bounds` diagonal
- [x] Toggle 3D/2D split in `AppLayout.tsx` (resizable layout)
- [x] `@react-three/fiber ^8`, `@react-three/drei ^9`, `three ^0.167` in package.json

---

## Phase 5 — Export, Project, Settings

### SVG Export
- [x] Face fills (`#fffde7`)
- [x] Edge dedup via `HashSet<(i64,i64,i64,i64)>` rounded to 1 μm
- [x] Fold lines (blue dashed), cut lines (red solid), boundary lines (grey)
- [x] Glue tab polygons (green semi-transparent fill + stroke)
- [x] Cut-edge pair labels (`<text>` at edge midpoint)
- [x] Multi-page: `_p{r}_{c}` suffix, per-page viewBox clipping
- [x] `ExportOptions` fields: colors, widths, dash, include_glue_tabs, grayscale, pages_wide/tall, margin_mm, scale_factor

### PDF Export
- [x] Pure-Rust PDF 1.4 writer (no external PDF crate)
- [x] Y-flip: `pdf_y = ph_pt - (svg_y_mm * PTS_PER_MM)`
- [x] Dash patterns via `d` operator, fill + stroke operators
- [x] `build_minimal_pdf()` — 4-object PDF: Catalog, Pages, Page, content stream

### Project Bundle
- [x] `.4hu` = ZIP(mesh + textures + `state.json`)
- [x] `ProjectState` v2: edge_overrides, flap_overrides, piece_layouts, scale, mirror_x, paper, pages_wide/tall, material_texture_exts
- [x] Security: `Path::file_name()` on all ZIP entries; extension whitelist; `version <= 2` validation

### Settings
- [x] `SettingsDialog.tsx` — 4 tabs: General / View 3D / View 2D / Print
- [x] `ScaleDialog.tsx` — target mm, unit, axis; updates `scale_mm_per_unit` → re-unfold
- [x] `ModelOrientationDialog.tsx` — mirror X checkbox
- [x] `AppSettings` Rust model + `settings.rs` serialize/load from `~/Library/Application Support/`

---

## Phase 6 — Advanced Features

### PDO Loader
- [x] `loaders/pdo_loader.rs` — Pepakura v3 binary parser
- [x] Signature validation: `"version 3\n"`
- [x] `Reader` struct: `read_u8/u32/f64/wstr/bytes/skip` with cipher (`wrapping_sub(key_byte)`)
- [x] Lock flag detection: `lock_flag == 1` → error with descriptive message
- [x] Geometry: vertices (raw f64), fan-triangulated shapes (85 bytes/point: vertex_idx + paper_xy + uv[v=1-v] + 49-byte skip)
- [x] Texture section: name (wstr) + 80 skip + has_image + w/h/csize + flate2 zlib decompress RGB24
- [x] `load_mesh` dispatch command: `.obj` → tobj, `.pdo` → pdo_loader, others → error

### PDO Unfold Builder
- [x] `algorithms/pdo_unfold.rs` — `build_from_pdo()`: direct 2D coords from `PdoFace.a/b/c`
- [x] `mark_pdo_edges()`: same `part_index` → Fold, different → Cut, boundary → Boundary

### EditFlaps Dialog
- [x] `EditFlapsDialog.tsx` — 2 tabs: Position + Shape
- [x] Position tab: auto-detect interior vs. border edge (from `mesh.edges[id].faceB`)
- [x] Interior modes (6): Default, SwitchPosition, OnOnThisSide, OffOnOtherSide, OffOffNoFlap, OnOnBothSides
- [x] Border modes (5): Default, BorderMountainFold, BorderValleyFold, BorderNoFold, BorderNoFlap
- [x] Shape tab: SVG `TabPreview` component + global settings display
- [x] `handleApply()` → snapshot → setFlapOverride → re-unfold → close
- [x] `uiStore.openEditFlaps(edgeId, faceId)` — atomic action (avoids race condition)

### Assembly Panel
- [x] `commands/assembly.rs` — `get_assembly_steps(mesh)` via BFS fold-components → piece adjacency via cut edges → BFS from largest piece
- [x] `AssemblyPanel.tsx` — step list, Prev/Next/Play/Pause/First/Last controls, 1.5s auto-play, face highlight

### Multi-page UI
- [x] `SheetBackground.tsx` — `pagesWide × pagesTall` grid, dashed page-break lines, page number labels
- [x] `settingsStore` exposes `pagesWide`, `pagesTall`, `showPageNumbers`

---

## Phase 6B — Test Coverage

**67 tests, 0 failures**

| Module | Tests | What's covered |
|--------|-------|----------------|
| `spanning_tree.rs` | 8 | Dihedral angle 90°, tetrahedron fold count (3), flat-over-steep MST preference, boundary marking |
| `face_unfold.rs` | 11 | Tetrahedron 4-face unfold, piece_id consistency, fold/boundary flags, edge length tolerance 1e-6, mesh_edge_ids stamped |
| `glue_tabs.rs` | 9 | BorderMountainFold, BorderNoFlap, OnOnBothSides, alternateFlaps, Rectangle tab no-inset |
| `assembly.rs` | 5 | Single/two-piece steps, root=largest, all faces covered exactly once |
| `models/unfold.rs` | 8 | FlapMode to_str/from_str (all 10 variants), FlapOverride serialize/deserialize round-trip |
| `commands/export.rs` | 12 | edge_key symmetry+dedup+μm rounding, page_path (4 variants), pdf_dash_op (3 variants), hex_to_rgb01 (3 variants) |
| `loaders/pdo_loader.rs` | 7 | Invalid signature, empty/truncated data, locked PDO, case-sensitivity, Reader skip+read robustness |
| `commands/mesh.rs` | 7 | build_edges winding order, non-manifold guard, tetrahedron topology, mesh bounds |

---

## Known Gaps vs. WPF Version

| Feature | Status | Notes |
|---------|--------|-------|
| Outline padding (Clipper2) | ❌ Not implemented | Requires polygon offset library |
| Merge adjacent flaps | ❌ Not implemented | Complex tab polygon union |
| Join adjacent isolated edges | ❌ Not implemented | Connectivity graph needed |
| Select symmetrical pair | ❌ Not implemented | Low priority |
| 3D Assembly animation | ⚠️ Partial | Steps computed but no fold animation |
| Assimp multi-format loader | ⚠️ Stub | Dispatch exists; loader not implemented |
| Overlap detection | ⚠️ Stub | Returns `false`; AABB+SAT not ported yet |
| Embedded texture display | ⚠️ Partial | PDO textures decoded but not wired to canvas |
| FlapOverride: silent-ignore warning | ⚠️ Partial | Corrupt data silently returns None (TD-36-3) |
| EditFlapsViewModel settings wiring | ⚠️ Partial | Hardcodes 5mm/45° defaults (TD-36-2) |

---

## Tauri Commands (17 registered)

```
load_obj                  load_obj_from_bytes       get_mesh_info
get_texture_as_base64     transform_mesh            load_mesh
get_assembly_steps        unfold_mesh               get_face_adjacency
export_svg                export_pdf                save_project
load_project              load_settings             save_settings
```

---

## Build

```bash
cd 4h-unfolder-mac
npm install
npm run tauri:build
```

Output:
- `src-tauri/target/release/bundle/macos/4H Unfolder.app`
- `src-tauri/target/release/bundle/dmg/4H Unfolder_0.1.0_*.dmg`
