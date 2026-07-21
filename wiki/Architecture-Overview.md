# Architecture Overview

Two native codebases share one design: a **dependency-ordered core** of pure geometry/IO logic
with **zero UI knowledge**, wrapped by a platform-native UI. This keeps the unfold algorithm
identical across platforms and independently testable.

> For build commands and the project table, see the
> [README](https://github.com/nghiazer/4H-Unfolder/blob/main/README.md); this page explains the
> *shape* of the code.

---

## Windows — layered .NET

Five projects in a strict one-way dependency chain. **Domain has zero external dependencies.**

```mermaid
flowchart LR
    Domain --> Geometry --> Application --> Infrastructure --> App
```

| Layer | Project | Responsibility | Key types |
|-------|---------|----------------|-----------|
| Domain | `FourHUnfolder.Domain` | Pure data model, no deps | `Mesh`, `Face`, `Edge`, `UnfoldResult`, `AppSettings`, `FlapMode`, `FlapOverride` |
| Geometry | `FourHUnfolder.Geometry` | The unfold pipeline | `UnfoldEngine`, `KruskalMstBuilder`, `DualGraphBuilder`, `GlueTabGenerator` |
| Application | `FourHUnfolder.Application` | Use-case services | `MeshService`, `UnfoldService`, `ProjectSerializer`, `SettingsService` |
| Infrastructure | `FourHUnfolder.Infrastructure` | File IO / export | `ObjMeshLoader`, `PdoMeshLoader`, `AssimpMeshLoader`, `SvgExporter`, `PdfExporter` |
| App (WPF) | `FourHUnfolder.App` | MVVM UI | `MainViewModel`, `PatternCanvasControl`, `AssemblyViewModel`, `EditFlapsViewModel` |

No circular dependencies. UI (App) never reaches past Application into Geometry directly.

---

## macOS — shared core + SwiftUI app

Two Swift Package targets. The heavy lifting lives in a **UI-free library** that mirrors the
Windows Domain+Geometry+Application+Infrastructure layers; the app target is thin SwiftUI.

```mermaid
flowchart LR
    Core["FourHUnfolderCore<br/>(pure Swift, no UI)"] --> App["FourHUnfolder<br/>(SwiftUI app)"]
```

| Target | Folder | Contents |
|--------|--------|----------|
| `FourHUnfolderCore` | `Core/` | `Algorithms`, `Graph`, `Math`, `Models` |
| | `IO/` | `Loaders` (OBJ, PDO), `Exporters` (SVG, PDF) |
| | `Services/` | `UnfoldService`, `ProjectSerializer` |
| `FourHUnfolder` (app) | `Models/`, `State/` | `AppState` (ObservableObject), view models |
| | `Views/` | `MainView`, `SceneKitView`, `PatternCanvasView`, `SidebarView` |

Keeping algorithms in `FourHUnfolderCore` means they're covered by XCTest without spinning up
any UI — the same discipline as the Windows Geometry project.

---

## Why the split matters

- **Testability** — the unfold pipeline and IO are pure functions of their inputs; both
  platforms unit-test them directly (Windows xUnit, macOS XCTest).
- **Parity** — the [unfold algorithm](The-Unfold-Algorithm) is implemented once per language
  against the same design, so results match.
- **Portability of data** — because state and serialization live in the core, the
  [`.4hu` bundle](Project-Files) is cross-platform.

---

## Rendering differs by platform

The **only** deliberately platform-specific area is rendering, mapped to each OS's native stack:

| Concern | Windows | macOS |
|---------|---------|-------|
| 3D viewport | WPF 3D / DirectX | SceneKit (Metal) |
| 2D canvas | WPF `Canvas` (`PatternCanvasControl`) | SwiftUI `Canvas` (`PatternCanvasView`) |
| PDF export | `PdfExporter` | Core Graphics |
| Extra mesh formats | Assimp (`assimp.dll`) | — |
