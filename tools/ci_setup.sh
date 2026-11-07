#!/usr/bin/env bash
# CI setup: download the pinned Godot Linux x86_64 binary (SHA512-verified) and install Python tools.
# Usage: tools/ci_setup.sh [install_dir]   (default: $RUNNER_TEMP/godot or ./build/ci/godot)
# Prints the binary path as the last line and, on GitHub Actions, exports GODOT_BIN.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/tools/GODOT_VERSION")"
if [ "$VERSION" != "4.7.2-stable" ]; then
  echo "tools/GODOT_VERSION is $VERSION but this script pins 4.7.2-stable: update URL and SHA512 together" >&2
  exit 1
fi
# SHA512 of Godot_v4.7.2-stable_linux.x86_64.zip from the release's SHA512-SUMS.txt.
SHA512="9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65"
ASSET="Godot_v${VERSION}_linux.x86_64.zip"
URL="https://github.com/godotengine/godot-builds/releases/download/${VERSION}/${ASSET}"

DEST="${1:-${RUNNER_TEMP:-$ROOT/build/ci}/godot}"
BIN="$DEST/Godot_v${VERSION}_linux.x86_64"
mkdir -p "$DEST"

if [ ! -x "$BIN" ]; then
  echo "Downloading $URL"
  curl -fsSL --retry 3 --retry-delay 5 -o "$DEST/$ASSET" "$URL"
  echo "$SHA512  $DEST/$ASSET" | sha512sum -c -
  unzip -q -o "$DEST/$ASSET" -d "$DEST"
  rm -f "$DEST/$ASSET"
  chmod +x "$BIN"
else
  echo "Godot already present (cache hit): $BIN"
fi

if [ "${SKIP_PIP:-0}" != "1" ]; then
  python -m pip install -q --disable-pip-version-check -r "$ROOT/tools/requirements.txt"
fi

if [ -n "${GITHUB_ENV:-}" ]; then
  echo "GODOT_BIN=$BIN" >> "$GITHUB_ENV"
fi
echo "$BIN"
