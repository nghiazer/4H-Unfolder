#!/usr/bin/env bash
# build-release.sh — Build a distributable .app bundle + ZIP for 4H Unfolder (macOS)
#
# Usage:
#   ./scripts/build-release.sh [version]
#   ./scripts/build-release.sh v0.0.0.1-alpha
#
# Output:
#   publish/mac/<version>/4H-Unfolder_<version>_mac.zip   (ad-hoc signed, unsigned-OK for local use)
#   publish/mac/<version>/4H-Unfolder_<version>_mac.app   (bundle, for reference)
#
# Requires: Xcode 15+ (swift, codesign, zip in PATH)
set -euo pipefail

# ── Version ──────────────────────────────────────────────────────────────────
VERSION="${1:-v0.0.0.1-alpha}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/.."           # 4h-unfolder-mac-swift/
REPO_ROOT="$ROOT/.."            # 4H-Unfolder/

APP_NAME="4H Unfolder"
BINARY_NAME="FourHUnfolder"
BUNDLE_NAME="${APP_NAME}.app"
PUBLISH_DIR="$REPO_ROOT/publish/mac/$VERSION"
STAGE="$ROOT/.build/stage"

echo "=== 4H Unfolder macOS Release Build ==="
echo "    Version : $VERSION"
echo "    Output  : $PUBLISH_DIR"
echo ""

# ── Step 1: Release build ─────────────────────────────────────────────────────
echo "[1/5] Building release binary..."
cd "$ROOT"
swift build -c release --product "$BINARY_NAME"
BINARY="$ROOT/.build/release/$BINARY_NAME"

if [ ! -f "$BINARY" ]; then
    echo "ERROR: Binary not found at $BINARY"; exit 1
fi

# ── Step 2: Assemble .app bundle ─────────────────────────────────────────────
echo "[2/5] Assembling .app bundle..."
BUNDLE="$STAGE/$BUNDLE_NAME"
rm -rf "$STAGE"
mkdir -p "$BUNDLE/Contents/MacOS"
mkdir -p "$BUNDLE/Contents/Resources"

# Binary
cp "$BINARY" "$BUNDLE/Contents/MacOS/$BINARY_NAME"

# Info.plist (embedded in source tree)
PLIST_SRC="$ROOT/Resources/Info.plist"
if [ -f "$PLIST_SRC" ]; then
    cp "$PLIST_SRC" "$BUNDLE/Contents/Info.plist"
else
    echo "WARNING: Info.plist not found at $PLIST_SRC — generating minimal fallback"
    cat > "$BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>$BINARY_NAME</string>
  <key>CFBundleIdentifier</key><string>com.4h-unfolder.app</string>
  <key>CFBundleName</key><string>4H Unfolder</string>
  <key>CFBundleShortVersionString</key><string>${VERSION#v}</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>13.0</key>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
fi

# PkgInfo (required for proper Finder recognition)
echo -n "APPL????" > "$BUNDLE/Contents/PkgInfo"

# ── Step 3: Ad-hoc code signing ──────────────────────────────────────────────
echo "[3/5] Ad-hoc code signing (no Developer ID — for local / dev use only)..."
codesign --force --deep --sign - "$BUNDLE"

# Verify
codesign --verify --deep --strict "$BUNDLE" && echo "    Signature: OK"

# ── Step 4: Package as ZIP ───────────────────────────────────────────────────
echo "[4/5] Packaging as ZIP..."
mkdir -p "$PUBLISH_DIR"
ZIP_NAME="4H-Unfolder_${VERSION}_mac.zip"
ZIP_PATH="$PUBLISH_DIR/$ZIP_NAME"

# Remove old zip if present
rm -f "$ZIP_PATH"

cd "$STAGE"
zip -r --symlinks "$ZIP_PATH" "$BUNDLE_NAME"
echo "    Created : $ZIP_PATH  ($(du -sh "$ZIP_PATH" | cut -f1))"

# Also copy the raw .app for convenience
APP_DEST="$PUBLISH_DIR/$BUNDLE_NAME"
rm -rf "$APP_DEST"
cp -R "$BUNDLE" "$APP_DEST"

# ── Step 5: Verify ───────────────────────────────────────────────────────────
echo "[5/5] Verification..."
spctl --assess --type execute "$APP_DEST" 2>&1 || echo "    (Gatekeeper: unsigned — expected without Developer ID, use Ctrl+click → Open)"
echo ""
echo "=== Build complete ==="
echo "    App    : $APP_DEST"
echo "    ZIP    : $ZIP_PATH"
echo ""
echo "NOTE: Without a Developer ID certificate, macOS Gatekeeper will block"
echo "      double-click launch. Right-click the .app → Open to bypass once."
echo "      For signed distribution, run 'Product → Archive' in Xcode."
