#!/usr/bin/env bash
# Puts the Godot editor and the ONE export template a platform needs into a
# cache folder, checked against Godot's own SHA-512 list, and prints the path
# of the editor binary. Run by .github/workflows/release.yml on each build
# machine, inside an actions/cache of the same folder - so the 1.3 GB template
# archive is downloaded once per Godot version, not once per release.
#
#   tools/release/fetch_godot.sh windows|macos <cache dir>
#
# The version is the one the project is built with (CLAUDE.md's Workflow).
# Changing it here is how CI moves to a new Godot, and the cache key in the
# workflow names it too, so the old download is never reused for the new one.

set -euo pipefail

GODOT_VERSION="4.7.2"
TAG="${GODOT_VERSION}-stable"
BASE="https://github.com/godotengine/godot/releases/download/${TAG}"
TPZ="Godot_v${TAG}_export_templates.tpz"

platform="$1"
cache="$2"

case "$platform" in
  windows)
    editor_zip="Godot_v${TAG}_win64.exe.zip"
    binary="editor/Godot_v${TAG}_win64_console.exe"
    templates=(templates/windows_release_x86_64.exe templates/version.txt)
    ;;
  macos)
    editor_zip="Godot_v${TAG}_macos.universal.zip"
    binary="editor/Godot.app/Contents/MacOS/Godot"
    templates=(templates/macos.zip templates/version.txt)
    ;;
  *)
    echo "usage: $0 windows|macos <cache dir>" >&2
    exit 2
    ;;
esac

verify() {
  if command -v sha512sum >/dev/null; then sha512sum -c -; else shasum -a 512 -c -; fi
}

mkdir -p "$cache"
cd "$cache"
if [ ! -f .complete ]; then
  rm -rf editor templates
  curl -fsSL --retry 3 -o SHA512-SUMS.txt "$BASE/SHA512-SUMS.txt"
  for file in "$editor_zip" "$TPZ"; do
    echo "downloading $file" >&2
    curl -fsSL --retry 3 -o "$file" "$BASE/$file"
    grep "  ${file}\$" SHA512-SUMS.txt | verify >&2
  done
  unzip -q "$editor_zip" -d editor
  unzip -q -o "$TPZ" "${templates[@]}"
  rm -f "$editor_zip" "$TPZ"
  touch .complete
fi

# Where the editor looks for templates on this OS - every run, because a cache
# restores this folder and not the user's application data.
case "$platform" in
  windows) dest="$(cygpath -u "$APPDATA")/Godot/export_templates/${GODOT_VERSION}.stable" ;;
  macos)   dest="$HOME/Library/Application Support/Godot/export_templates/${GODOT_VERSION}.stable" ;;
esac
mkdir -p "$dest"
cp templates/* "$dest/"

echo "$(pwd)/$binary"
