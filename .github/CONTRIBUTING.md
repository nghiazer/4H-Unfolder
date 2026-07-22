# Contributing to 4H-Unfolder

Thanks for your interest in contributing! 4H-Unfolder is a papercraft / pepakura
unfolder shipped as **two native apps** from one repository:

| Platform | Folder | Stack |
|----------|--------|-------|
| **Windows** | [`4h-unfolder-win/`](../4h-unfolder-win/) | WPF · .NET 8 · C# |
| **macOS** | [`4h-unfolder-mac-swift/`](../4h-unfolder-mac-swift/) | SwiftUI · SceneKit · Swift |

This is the repo-wide guide. The Windows app has a **more detailed** contributor
guide covering layer rules and coding conventions —
[`4h-unfolder-win/CONTRIBUTING.md`](../4h-unfolder-win/CONTRIBUTING.md).

By participating you agree to abide by our
[Code of Conduct](CODE_OF_CONDUCT.md).

---

## Ways to contribute

- 🐛 **Report a bug** — [open a bug report](https://github.com/nghiazer/4H-Unfolder/issues/new/choose)
- 💡 **Request a feature** — [open a feature request](https://github.com/nghiazer/4H-Unfolder/issues/new/choose)
- 📖 **Improve docs** — the [Wiki](https://github.com/nghiazer/4H-Unfolder/wiki) source lives in
  [`wiki/`](../wiki/); see the [wiki workflow](https://github.com/nghiazer/4H-Unfolder/wiki)
- 🔧 **Fix / build something** — see the [Roadmap](https://github.com/nghiazer/4H-Unfolder/wiki/Roadmap)
  for good starting points

---

## Development setup

### Windows
```powershell
git clone https://github.com/nghiazer/4H-Unfolder.git
cd 4H-Unfolder/4h-unfolder-win
dotnet restore
dotnet build
dotnet run  --project src/FourHUnfolder.App
dotnet test tests/FourHUnfolder.Tests
```
Requires the **.NET 8 SDK** and Windows 10/11 (WPF is Windows-only).

### macOS
```bash
git clone https://github.com/nghiazer/4H-Unfolder.git
cd 4H-Unfolder/4h-unfolder-mac-swift
swift build            # or open Package.swift in Xcode 15+ and press ⌘R
swift test
```
Requires **Xcode 15+**.

See the [Architecture Overview](https://github.com/nghiazer/4H-Unfolder/wiki/Architecture-Overview)
for how the code is organized on each platform.

---

## Branching & workflow

| Branch prefix | Purpose |
|---------------|---------|
| `feat/<topic>` | New features or non-trivial refactors |
| `fix/<topic>` | Bug fixes |
| `docs/<topic>` | Documentation-only changes |
| `chore/<topic>` | Build scripts, CI, tooling |

`main` is always-releasable and protected — no direct pushes.

1. Fork the repo (or branch directly if you have write access).
2. `git checkout -b feat/my-feature`
3. Make changes — commit early and often, with clear messages.
4. **Build and test** the platform(s) you touched — must be clean.
5. Push and open a Pull Request against `main`; fill in the
   [PR template](PULL_REQUEST_TEMPLATE.md).

Keep a PR scoped to **one platform** where possible. A change that affects the
shared algorithm should ideally be mirrored on both — note it in the PR if you
can only do one.

---

## Coding conventions (summary)

- **Windows** — C# 12, `Nullable enable`; MVVM via `CommunityToolkit.Mvvm`;
  respect the one-way layer order `Domain → Geometry → Application →
  Infrastructure → App` (no circular deps). Full detail in the
  [Windows contributor guide](../4h-unfolder-win/CONTRIBUTING.md).
- **macOS** — keep algorithms/IO in the UI-free `FourHUnfolderCore` target;
  the SwiftUI app target stays thin.
- Match the style of the surrounding code; add tests for new behavior.

---

## Commit & PR expectations

- Builds clean and all tests pass on the affected platform(s).
- New behavior is covered by tests.
- Docs / wiki updated if you changed user-facing behavior.
- Don't bump the app version unless coordinated with the maintainer.

---

## License

By contributing, you agree that your contributions will be licensed under the
[MIT License](../LICENSE) that covers this project.
