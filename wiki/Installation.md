# Installation

4H-Unfolder ships as a native app on both platforms. Pick your OS below.

---

## Windows (Production)

**Requirements:** Windows 10 or 11 (x64). No .NET runtime needed — builds are fully self-contained.

### Option A — Installer (recommended)
1. Go to the [Releases page](https://github.com/nghiazer/4H-Unfolder/releases).
2. Download the latest `4H-Unfolder-vX.X.X.X-setup.exe`.
3. Run it and follow the wizard. A Start Menu shortcut is created.

### Option B — Portable ZIP
1. Download `4H-Unfolder-vX.X.X.X-portable.zip`.
2. Extract the **entire** folder somewhere (e.g. `C:\Tools\4H-Unfolder`).
3. Run `4H-Unfolder.exe`.

> ⚠️ **Keep every file in the ZIP together.** The `.exe` depends on native DLLs shipped
> alongside it (`wpfgfx_cor3.dll`, `PresentationNative_cor3.dll`, `assimp.dll`, and others).
> Moving the `.exe` out on its own will make it fail to launch — see
> [FAQ → "The app doesn't open"](FAQ-and-Troubleshooting#the-app-doesnt-open-on-windows).

---

## macOS (Alpha)

**Requirements:** macOS 13 (Ventura) or later. Apple Silicon or Intel.

1. Download the latest `4H-Unfolder_vX.X.X.X_mac.zip` from [Releases](https://github.com/nghiazer/4H-Unfolder/releases).
2. Unzip it and drag **`4H Unfolder.app`** into `/Applications`.
3. **First launch:** right-click the app → **Open** → confirm **Open** in the dialog.

> ℹ️ Alpha builds are ad-hoc signed, not notarized. Double-clicking shows
> _"cannot be opened because the developer cannot be verified."_ The right-click → Open
> step tells Gatekeeper to trust it — you only need to do this once. See
> [FAQ → macOS Gatekeeper](FAQ-and-Troubleshooting#macos-says-the-developer-cannot-be-verified).

---

## Build from source

Not covered here — see the
[README](https://github.com/nghiazer/4H-Unfolder/blob/main/README.md) (build commands)
and [CONTRIBUTING](https://github.com/nghiazer/4H-Unfolder/blob/main/4h-unfolder-win/CONTRIBUTING.md)
(full dev setup) instead.
