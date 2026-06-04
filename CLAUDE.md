# 4H-Unfolder — Claude Code Guide

## Repo layout

```
4H-Unfolder/
├── 4h-unfolder-win/   ← WPF / .NET 8 (Windows)
│   ├── src/           ← C# projects (Domain → Geometry → Application → Infrastructure → App)
│   ├── tests/         ← xUnit tests
│   ├── installer/     ← Inno Setup script
│   ├── scripts/       ← PowerShell helpers
│   ├── docs/          ← Screenshots, assets
│   └── 4H-Unfolder.sln
├── 4h-unfolder-mac/   ← Tauri 2 + React 18 + Rust (macOS)
│   ├── src/           ← TypeScript frontend (React/Konva/R3F)
│   ├── src-tauri/     ← Rust backend (algorithms + Tauri commands)
│   └── README.md / PROGRESS.md
├── CLAUDE.md          ← This file (root guide, kept at root)
├── .mcp-project.json  ← Code-graph MCP index config
└── .editorconfig
```

---

## Windows Build & Run

```powershell
cd 4h-unfolder-win
dotnet restore
dotnet build                                    # 0 errors, 7 NuGet NU1603 warnings only
dotnet run --project src/FourHUnfolder.App
dotnet test tests/FourHUnfolder.Tests           # 56/56 pass
```

## macOS Build & Run

```bash
cd 4h-unfolder-mac
npm install
npm run tauri:dev                               # hot-reload dev mode
npm run tauri:build                             # → .app + .dmg
cargo test --manifest-path src-tauri/Cargo.toml # 67/67 pass
```

---

## Windows Architecture

```
Domain → Geometry → Application → Infrastructure → App
```

No circular dependencies. Domain has **zero** external deps.

| Layer | Project | Key classes |
|-------|---------|-------------|
| Domain | `FourHUnfolder.Domain` | `Mesh`, `Face`, `Edge`, `UnfoldResult`, `AppSettings`, `EmbeddedTextureData`, `FlapMode`, `FlapOverride` |
| Geometry | `FourHUnfolder.Geometry` | `UnfoldEngine`, `KruskalMstBuilder`, `DualGraphBuilder`, `GlueTabGenerator`, `PieceFoldTree` |
| Application | `FourHUnfolder.Application` | `MeshService`, `UnfoldService`, `ProjectSerializer`, `SettingsService` |
| Infrastructure | `FourHUnfolder.Infrastructure` | `ObjMeshLoader`, `PdoMeshLoader`, `AssimpMeshLoader`, `SvgExporter`, `PdfExporter` |
| App (WPF) | `FourHUnfolder.App` | `MainViewModel`, `PatternCanvasControl`, `AssemblyViewModel`, `EditFlapsViewModel` |

---

## Code-Graph MCP Tools — Use These First

A local MCP server (`code-graph`) indexes this project.
**Always query it before opening source files** — it saves 5–15× tokens.

### Recommended workflow

```
1. get_project_map()                    → orient yourself at session start
2. find_definition("SymbolName")        → file + exact line, never grep manually
3. get_class_members("ClassName")       → full member list without reading the file
4. get_file_outline("FileName.cs")      → structure of one file (all symbols + lines)
5. find_usages("SymbolName")            → who references this?
6. search_code("pattern", "*.cs")       → grep with context
7. reindex()                            → only if you added/renamed files this session
```

### Token-cost comparison

| Task | Without MCP | With MCP |
|------|------------|---------|
| Find where `BuildWpfModel` is defined | Read `MainViewModel.cs` ≈ 6 000 tok | `find_definition` ≈ 30 tok |
| Understand `UnfoldResult` class | Read file ≈ 400 tok | `get_class_members` ≈ 60 tok |
| Find all usages of `IExporter` | Grep 61 files ≈ 1 500 tok | `find_usages` ≈ 80 tok |
| Session orientation | Read 5 overview files ≈ 10 000 tok | `get_project_map` ≈ 200 tok |

### When to Read actual files

Only open a source file when you need the **implementation body** — logic, algorithm,
or code you intend to edit. Use line-range reads (`:offset` + `:limit`) once you know
the exact line from `find_definition`.

---

## Windows — Key locations (quick reference)

| What | File | Approx line |
|------|------|-------------|
| Main WPF entry | `4h-unfolder-win/src/FourHUnfolder.App/App.xaml.cs` | — |
| Load mesh | `MainViewModel.cs` | ~120 |
| Build 3-D model | `MainViewModel.cs` → `BuildWpfModel` | ~1 500 |
| Unfold pipeline | `UnfoldEngine.cs` | ~13 |
| PDO parser | `PdoMeshLoader.cs` | ~52 |
| SVG export | `SvgExporter.cs` | — |
| Settings model | `AppSettings.cs` | — |
| Project state | `ProjectState.cs` | — |
| Flap override domain | `FlapMode.cs`, `FlapOverride.cs` | — |
| Edit Flaps dialog | `EditFlapsDialog.xaml`, `EditFlapsViewModel.cs` | — |
| Flap tab generation | `GlueTabGenerator.cs` | ~1 |

> Line numbers shift as code is edited — always confirm with `find_definition`.

---

## macOS — Key locations (quick reference)

| What | File |
|------|------|
| Tauri commands | `4h-unfolder-mac/src-tauri/src/lib.rs` |
| Rust algorithms | `4h-unfolder-mac/src-tauri/src/algorithms/` |
| Unfold pipeline | `face_unfold.rs`, `spanning_tree.rs`, `glue_tabs.rs` |
| PDO loader | `4h-unfolder-mac/src-tauri/src/loaders/pdo_loader.rs` |
| React app root | `4h-unfolder-mac/src/components/Layout/AppLayout.tsx` |
| Zustand stores | `4h-unfolder-mac/src/state/` |
| Tauri command types | `4h-unfolder-mac/src/types/tauri.ts` |

---

## Current branch: `feat/mac-port` (v0.0.0.1-alpha)

### Windows tech debt open (session 38)
| ID | Priority | Description |
|----|----------|-------------|
| TD-38-1 | 🔴 High | Add Outline Padding — needs Clipper2 polygon offset library |
| TD-38-2 | 🔴 High | Merge Adjacent Flaps — complex tab polygon union geometry |
| TD-38-3 | 🟡 Med | Join Adjacent Isolated Edges — connectivity graph needed |
| TD-38-4/5/6 | 🟢 Low | Select Symmetrical Pair / Split Window / Change Coordinates |

### Windows tech debt open (session 36)
| ID | Priority | Description |
|----|----------|-------------|
| TD-36-1 | 🟡 Med | No unit tests for `FlapOverride` serialization + `GlueTabGenerator` border modes |
| TD-36-2 | 🟢 Low | `EditFlapsViewModel` hardcodes defaults (5mm/45°) — not wired to `AppSettings` fallback |
| TD-36-3 | 🟢 Low | `FlapOverride.Deserialize`: silent-ignore on corrupt data — add warning |
| Performance | 🟢 Low | O(n²) AABB+SAT overlap; spatial grid needed for meshes > 2000 faces |

---

## Conventions

### Windows
- **No tool calls** before checking code-graph MCP first
- **Targeted reads**: use `offset` + `limit` once line number is known
- Tests live in `4h-unfolder-win/tests/FourHUnfolder.Tests/` — run after every change
- Settings persisted to `%AppData%\4H-Unfolder\settings.json`
- Project bundle: `.4hu` = ZIP(mesh + textures + state JSON incl. FlapOverrides)
- MVVM: use generated property names (`HeightMm`, not `_heightMm`) — MVVMTK0034

### macOS
- Rust tests: `cargo test` in `4h-unfolder-mac/src-tauri/` — 67 tests, 0 failures
- TypeScript: `npx tsc --noEmit` from `4h-unfolder-mac/` — 0 errors
- Settings persisted to `~/Library/Application Support/4H-Unfolder/settings.json`

---

## Publish & Archive

### Windows — WPF native DLL rule

WPF self-contained single-file apps do **NOT** bundle native DLLs into the exe.
Required DLLs alongside exe:

```
wpfgfx_cor3.dll  PresentationNative_cor3.dll  D3DCompiler_47_cor3.dll
PenImc_cor3.dll  vcruntime140_cor3.dll  assimp.dll
```

**Archive command:**
```powershell
cd 4h-unfolder-win
New-Item -ItemType Directory -Path "..\publish\win\vX.X.X.Y" -Force
Copy-Item "publish\4H-Unfolder.exe" "..\publish\win\vX.X.X.Y\"
Copy-Item "publish\*.dll"           "..\publish\win\vX.X.X.Y\"
```

**Installer:** `.\scripts\prepare-installer.ps1` → then `iscc installer\4H-Unfolder.iss` (Inno Setup 6)

**Symptom of missing DLLs:** process shows as Suspended in Task Manager; no window; Event Log `DllNotFoundException`.

### macOS

```bash
cd 4h-unfolder-mac
npm run tauri:build
# Output: src-tauri/target/release/bundle/dmg/4H Unfolder_*.dmg
```

Archive: `publish/mac/vX.X.X.X/4H-Unfolder_vX.X.X.X_mac_x64.dmg`
