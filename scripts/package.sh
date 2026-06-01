#!/usr/bin/env bash
#
# Build a CurseForge-ready zip of the SoloQ addon.
#
# Bundles only the runtime files (the .lua sources, the .toc, and assets) under
# a top-level SoloQ/ folder so the archive extracts straight into
# Interface/AddOns/SoloQ. Dev-only files (tools/, tests/, docs/, scripts/) are
# left out. Output lands in dist/.
#
# Usage: scripts/package.sh
set -euo pipefail

ADDON="SoloQ"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Read the version from the .toc. The .toc uses the @project-version@ token so
# the CurseForge packager can stamp the release tag; for local builds that token
# (or a missing version) falls back to a git-derived version.
VERSION="$(grep -E '^## Version:' "$ADDON.toc" | head -1 | sed 's/^## Version:[[:space:]]*//' | tr -d '\r')"
case "$VERSION" in
    ""|*@project-version@*)
        VERSION="$(git describe --tags --always 2>/dev/null || echo dev)"
        ;;
esac

OUT="$ROOT/dist"
STAGE="$OUT/$ADDON"
ZIPNAME="${ADDON}-${VERSION}.zip"

rm -rf "$STAGE" "$OUT/$ZIPNAME"
mkdir -p "$STAGE/assets"

# Runtime files only.
cp -- *.lua "$ADDON.toc" "$STAGE"/
[ -f README.md ] && cp -- README.md "$STAGE"/
cp -- assets/* "$STAGE/assets"/

# Zip with the top-level SoloQ/ folder preserved.
( cd "$OUT" && zip -r -q "$ZIPNAME" "$ADDON" )
rm -rf "$STAGE"

echo "Built $OUT/$ZIPNAME"
