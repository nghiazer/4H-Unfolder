# Security Policy

4H-Unfolder is an offline **desktop application** for both Windows and macOS. It
has no server component and makes no network requests during normal use. The most
security-relevant part of the code is the set of **mesh file parsers** — the app
opens untrusted `.obj`, `.pdo`, and other model files, and the
[`.4hu`](https://github.com/nghiazer/4H-Unfolder/wiki/Project-Files) project
bundle is an unpacked ZIP archive.

## Supported versions

Security fixes land on the latest release of each platform.

| Platform | Version | Supported |
|----------|---------|:---------:|
| Windows | `v0.2.0.A` (latest) | ✅ |
| Windows | older releases | ❌ |
| macOS | `v0.0.0.5-alpha` (latest) | ✅ |
| macOS | older alphas | ❌ |

Please always test against the latest release before reporting.

## What's in scope

- Parsing untrusted mesh files (`.obj`, `.pdo`, formats via Assimp) that could
  cause memory-safety issues, crashes, or unbounded resource use.
- Extraction of `.4hu` / `.pmc` bundles (e.g. path traversal / zip-slip when
  writing embedded entries to a temp directory).
- Any code path that writes outside the intended output location during export.

### Out of scope

- Crashes on malformed files that are cleanly handled (a friendly error is the
  intended behavior — report those as regular [bugs](https://github.com/nghiazer/4H-Unfolder/issues/new/choose)).
- Issues requiring a already-compromised machine or physical access.
- The missing native DLL / Gatekeeper launch behavior — that's documented in the
  [FAQ](https://github.com/nghiazer/4H-Unfolder/wiki/FAQ-and-Troubleshooting), not a vulnerability.

## Reporting a vulnerability

**Please do not open a public issue for security vulnerabilities.**

Report privately using one of:

1. **GitHub Security Advisories** (preferred) — go to the repository's
   [**Security → Report a vulnerability**](https://github.com/nghiazer/4H-Unfolder/security/advisories/new)
   tab to open a private advisory.
2. **Email** — **nghia.zer.7@gmail.com** with the subject line
   `[4H-Unfolder security]`.

Please include:

- affected platform and version,
- a description of the issue and its impact,
- steps to reproduce, and a sample file if the issue is triggered by one.

### What to expect

- Acknowledgement of your report within **7 days**.
- An assessment and, if confirmed, a fix targeting the next release.
- Credit in the release notes for the fix, unless you prefer to remain anonymous.

As a small volunteer-run project we can't offer a bug bounty, but we genuinely
appreciate responsible disclosure.
