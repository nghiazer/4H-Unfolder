# 4H-Unfolder

Papercraft / pepakura unfolder — unfolds 3D meshes to flat paper patterns with glue tabs, cut-edge labels, and SVG/PDF export.

---

## Repository layout

```
4H-Unfolder/
├── 4h-unfolder-win/   WPF / .NET 8 — Windows native app
└── 4h-unfolder-mac/   Tauri 2 + React + Rust — macOS native app
```

---

## Platforms

| Platform | Tech | Version | Status |
|----------|------|---------|--------|
| Windows | WPF / .NET 8 / C# | v0.1.0.A | Production |
| macOS | Tauri 2 / React 18 / Rust | v0.0.0.1-alpha | Alpha |

---

## Windows

See [4h-unfolder-win/README.md](4h-unfolder-win/README.md) for full documentation.

```powershell
cd 4h-unfolder-win
dotnet restore && dotnet build
dotnet run --project src/FourHUnfolder.App
```

## macOS

See [4h-unfolder-mac/README.md](4h-unfolder-mac/README.md) and [4h-unfolder-mac/PROGRESS.md](4h-unfolder-mac/PROGRESS.md).

```bash
cd 4h-unfolder-mac
npm install && npm run tauri:dev
```

---

## License

[MIT](LICENSE)
