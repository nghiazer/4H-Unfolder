# Glossary

Terms used across 4H-Unfolder and this wiki. Papercraft and geometry vocabulary in one place.

---

### Unfold / unfolding
Flattening a 3D mesh into connected 2D pieces that can be printed, cut, and folded back into the
shape. Also called *unwrapping* or *pepakura*. See [The Unfold Algorithm](The-Unfold-Algorithm).

### Mesh
The 3D model, made of **faces** (triangles), **edges**, and **vertices**. Loaded from `.obj` or
`.pdo`. See [Quick Start → import](Quick-Start#1-import-a-mesh).

### Face
One triangle of the mesh. Each face becomes a flat polygon in the 2D pattern.

### Edge
A boundary between/around faces. In the pattern every edge is a **fold**, a **cut**, or a
**border** — see [Editing Edges & Flaps](Editing-Edges-and-Flaps#edge-types).

### Dihedral angle
The angle between two faces that share an edge — how sharply the model bends there. It's the
**weight** the unfolder uses to decide which seams to keep vs. cut.

### Dual graph
A graph where each **face** is a node and each **shared edge** is a link (weighted by dihedral
angle). The unfolder builds this to reason about connectivity.

### MST (Minimum Spanning Tree) / Kruskal
The set of fold edges chosen to keep the model connected while cutting the fewest / flattest
seams. Built with **Kruskal's algorithm**, adding lowest-angle edges first. See
[the algorithm](The-Unfold-Algorithm#2-choose-seams-with-kruskals-mst).

### BFS (Breadth-First Search)
The traversal that walks the fold tree and lays each face flat in 2D, preserving true edge
lengths. See [placing faces](The-Unfold-Algorithm#4-bfs-unfold--placing-faces-in-2d).

### Piece
A group of faces that stay connected by fold edges — one shape you cut out as a unit. Computed
via **Union-Find** over the fold edges.

### Flap / glue tab
The extra paper along a cut or border edge that you fold under and glue to a neighbouring face.
Shapes: trapezoid / rectangle / triangle. See
[flaps](Editing-Edges-and-Flaps#glue-tabs-flaps).

### FlapMode
A per-edge override deciding whether a tab appears, on which side, or on both. 10 variants
(inner-edge and border-edge sets). See
[per-edge flap modes](Editing-Edges-and-Flaps#per-edge-flap-modes).

### Fold line vs cut line
On the printout, **fold lines** are dashed (crease, don't cut) and **cut lines** are solid
(cut with a knife/scissors).

### Mountain / valley fold
Fold direction. A **mountain** fold points the crease toward you (ridge); a **valley** fold away
(trough). Border flap modes can annotate which.

### Overlap
When a flattened piece folds onto itself in 2D — it can't be cut flat. Detected with a
**spatial grid + SAT** and shown red. See
[fixing overlaps](FAQ-and-Troubleshooting#some-pieces-are-red--flagged-as-overlapping).

### SAT (Separating Axis Theorem)
The geometry test that confirms whether two triangles truly overlap during overlap detection.

### `.4hu`
The project bundle — a ZIP with the mesh, textures, and all your edits. Cross-platform. See
[Project Files](Project-Files).

### UV / UV mapping
Coordinates that map a 2D texture image onto the 3D faces, rendered in both the 3D viewport and
the 2D pattern.
