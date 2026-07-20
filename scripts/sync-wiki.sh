#!/usr/bin/env bash
#
# sync-wiki.sh — publish the in-repo wiki/ draft to the GitHub Wiki repo.
#
# Workflow "A" (see PR #52): wiki/ in this repo is the reviewable source of
# truth; this script pushes it to nghiazer/4H-Unfolder.wiki.git so the two
# never drift by hand.
#
# Usage:
#   ./scripts/sync-wiki.sh                 # sync with an auto message
#   ./scripts/sync-wiki.sh "your message"  # sync with a custom commit message
#
# Requires: the GitHub Wiki must already be initialized (create the first page
# once via the web UI) or the .wiki.git repo won't exist yet.

set -euo pipefail

WIKI_REMOTE="https://github.com/nghiazer/4H-Unfolder.wiki.git"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$REPO_ROOT/wiki"
WORK_DIR="$(mktemp -d)"
MSG="${1:-Sync wiki from repo wiki/ ($(date +%Y-%m-%d))}"

trap 'rm -rf "$WORK_DIR"' EXIT

if [ ! -d "$SRC_DIR" ]; then
  echo "error: source dir not found: $SRC_DIR" >&2
  exit 1
fi

echo "→ Cloning wiki repo…"
if ! git clone --quiet "$WIKI_REMOTE" "$WORK_DIR/wiki"; then
  echo "error: could not clone $WIKI_REMOTE" >&2
  echo "       Has the wiki been initialized? Create the first page once at" >&2
  echo "       https://github.com/nghiazer/4H-Unfolder/wiki then re-run." >&2
  exit 1
fi

echo "→ Copying pages from wiki/ …"
# Remove tracked .md pages first so deletions in wiki/ propagate, then copy.
find "$WORK_DIR/wiki" -maxdepth 1 -name '*.md' -delete
cp "$SRC_DIR"/*.md "$WORK_DIR/wiki/"

cd "$WORK_DIR/wiki"
git add -A

if git diff --cached --quiet; then
  echo "✓ Wiki already up to date — nothing to push."
  exit 0
fi

echo "→ Changed pages:"
git diff --cached --name-status | sed 's/^/    /'

git commit --quiet -m "$MSG"
# GitHub wiki repos use the 'master' default branch.
git push --quiet origin HEAD
echo "✓ Wiki published: https://github.com/nghiazer/4H-Unfolder/wiki"
