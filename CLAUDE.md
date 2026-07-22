# 4H-Unfolder — Claude Code Guide

## Repo layout

```
4H-Unfolder/
├── 4h-unfolder-win/         ← WPF / .NET 8 (Windows)
│   ├── src/                 ← C# projects (Domain → Geometry → Application → Infrastructure → App)
│   ├── tests/               ← xUnit tests
│   ├── installer/           ← Inno Setup script
│   ├── scripts/             ← PowerShell helpers
│   ├── docs/                ← Screenshots, assets
│   └── 4H-Unfolder.sln
├── 4h-unfolder-mac-swift/   ← Native Swift + SwiftUI (macOS) — requires Xcode 15+
│   ├── Package.swift        ← SPM manifest — open this in Xcode
│   ├── Sources/FourHUnfolder/
│   │   ├── App.swift        ← @main entry, SwiftUI App protocol
│   │   ├── AppState.swift   ← ObservableObject: mesh, result, settings
│   │   ├── ContentView.swift
│   │   ├── Models/          ← Mesh, UnfoldResult, AppSettings
│   │   ├── Services/        ← ObjMeshLoader, UnfoldEngine, GlueTabGenerator
│   │   └── Views/           ← MainView, SceneKitView, PatternCanvasView, SidebarView
│   └── Tests/FourHUnfolderTests/
├── CLAUDE.md                ← This file (root guide, kept at root)
├── .mcp-project.json        ← Code-graph MCP index config
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

**Requires Xcode 15+ installed.**

```bash
# Open in Xcode:  File → Open → select 4h-unfolder-mac-swift/Package.swift
# Then: Product → Run  (⌘R)

# Or build from command line (no GUI):
cd 4h-unfolder-mac-swift
swift build
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
| App entry (`@main`) | `4h-unfolder-mac-swift/Sources/FourHUnfolder/App.swift` |
| Global state | `4h-unfolder-mac-swift/Sources/FourHUnfolder/AppState.swift` |
| Mesh data types | `4h-unfolder-mac-swift/Sources/FourHUnfolder/Models/Mesh.swift` |
| Unfold result types | `4h-unfolder-mac-swift/Sources/FourHUnfolder/Models/UnfoldResult.swift` |
| OBJ loader | `4h-unfolder-mac-swift/Sources/FourHUnfolder/Services/ObjMeshLoader.swift` |
| Unfold algorithm (BFS+spanning tree) | `4h-unfolder-mac-swift/Sources/FourHUnfolder/Services/UnfoldEngine.swift` |
| Glue tab generator | `4h-unfolder-mac-swift/Sources/FourHUnfolder/Services/GlueTabGenerator.swift` |
| 3D SceneKit viewport | `4h-unfolder-mac-swift/Sources/FourHUnfolder/Views/SceneKitView.swift` |
| 2D pattern canvas | `4h-unfolder-mac-swift/Sources/FourHUnfolder/Views/PatternCanvasView.swift` |
| Sidebar controls | `4h-unfolder-mac-swift/Sources/FourHUnfolder/Views/SidebarView.swift` |

---

## Current release: `v0.3.0.A` (Windows) / `v0.0.0.6-alpha` (macOS) — branch `main`

> Public-facing plan + status live in the [wiki Roadmap](https://github.com/nghiazer/4H-Unfolder/wiki/Roadmap).
> Full papercraft-parity plan, per-item status, and verification log: [`PARITY-PROGRESS.md`](PARITY-PROGRESS.md).

### Windows tech debt open
| ID | Priority | Description |
|----|----------|-------------|
| TD-38-4/5/6 | 🟢 Low | Select Symmetrical Pair / Split Window / Change Coordinates |
| TD-36-2 | 🟢 Low | `EditFlapsViewModel` hardcodes defaults (5mm/45°) — not wired to `AppSettings` fallback |
| TD-36-3 | 🟢 Low | `FlapOverride.Deserialize`: silent-ignore on corrupt data — add warning |
| Performance | 🟢 Low | O(n²) AABB+SAT overlap; spatial grid used, but the overlap-reducing retry (v0.3.0.A) multiplies unfold cost up to 9× when a mesh has an unavoidable overlap — profile meshes > 2000 faces |

Resolved this release: TD-38-1 (Outline Padding), TD-38-2 (Merge Adjacent Flaps), TD-38-3 (Join
Adjacent Isolated Edges) were already done on Windows before v0.3.0.A; TD-36-1 (FlapOverride/
GlueTabGenerator test coverage) confirmed already covered by `FlapOverrideTests.cs` /
`GlueTabGeneratorTests.cs`.

### macOS tech debt open
| ID | Priority | Description |
|----|----------|-------------|
| — | 🔴 High | Wire outline padding (`PolygonOffset`) into export/canvas — math exists, not consumed yet |
| — | 🟡 Med | Port "join connected cut edges" from Windows |
| — | 🟢 Low | Configurable overlap-retry budget (fixed at 8 attempts) for very large meshes |

---

## Conventions

### Windows
- **No tool calls** before checking code-graph MCP first
- **Targeted reads**: use `offset` + `limit` once line number is known
- Tests live in `4h-unfolder-win/tests/FourHUnfolder.Tests/` — run after every change
- Settings persisted to `%AppData%\4H-Unfolder\settings.json`
- Project bundle: `.4hu` = ZIP(mesh + textures + state JSON incl. FlapOverrides)
- MVVM: use generated property names (`HeightMm`, not `_heightMm`) — MVVMTK0034

### macOS (Swift)
- Build: open `Package.swift` in Xcode 15+ — no npm/Rust toolchain needed
- Tests: Xcode Test Navigator (⌘5) — tests live in `Tests/FourHUnfolderTests/`
- Settings persisted to `~/Library/Application Support/4H-Unfolder/settings.json` via `UserDefaults`
- 3D rendering: SceneKit (Metal-backed, `SCNView`) via `NSViewRepresentable`
- 2D rendering: SwiftUI `Canvas` API in `PatternCanvasView`
- SVG export: inline in `AppState.SVGExporter` — expand for PDF in a future `PDFExporter.swift`

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

### macOS (Swift)

In Xcode: **Product → Archive** → Distribute App → Developer ID

```bash
# CLI build (no signing):
cd 4h-unfolder-mac-swift
swift build -c release
```

Archive: `publish/mac/vX.X.X.X/4H-Unfolder_vX.X.X.X_mac.dmg`
