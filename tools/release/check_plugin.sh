#!/usr/bin/env bash
# Fails the build if a desktop export came out without the WebRTC library -
# a game without it starts, plays solo, and cannot play online, and nothing
# else in a build says so:
#
#   tools/release/check_plugin.sh windows build/windows
#   tools/release/check_plugin.sh macos build/macos/TheNewHire.dmg
#
# Which file each platform takes is read off the .gdextension, the same line
# Godot's export copies by, so a vendored update that renames the libraries is
# followed here rather than fought. tests/test_release.gd checks the same lines
# against the files on disk; this looks inside the real builds.

set -euo pipefail

platform="$1"
built="$2"
ext=addons/webrtc_native/webrtc_native.gdextension

# `macos.release = "lib/x.framework"` -> x.framework
library() {
  local line
  line="$(grep -E "^$1 *=" "$ext" | head -n 1)"
  if [ -z "$line" ]; then
    echo "::error::$ext has no $1 line" >&2
    exit 1
  fi
  basename "$(echo "$line" | sed -E 's/^[^"]*"([^"]+)".*$/\1/')"
}

case "$platform" in
  windows)
    lib="$(library windows.release.x86_64)"
    if [ ! -s "$built/$lib" ]; then
      echo "::error::the Windows build has no $lib beside the exe - it could not play online"
      ls -la "$built"
      exit 1
    fi
    echo "Windows: $lib ships beside the exe ($(wc -c < "$built/$lib") bytes)"
    ;;
  macos)
    lib="$(library macos.release)"
    mount="$(mktemp -d)"
    hdiutil attach -nobrowse -readonly -mountpoint "$mount" "$built" > /dev/null
    trap 'hdiutil detach "$mount" > /dev/null || true' EXIT
    found="$(find "$mount" -maxdepth 6 -path "*.app/Contents/Frameworks/$lib" -type d | head -n 1)"
    if [ -z "$found" ]; then
      echo "::error::the macOS app has no Contents/Frameworks/$lib - it could not play online"
      find "$mount" -maxdepth 4 | head -n 40
      exit 1
    fi
    echo "macOS: $found"
    # Signed with the app (ad hoc: codesign/codesign=1 in the preset), or macOS
    # refuses to load it. Said rather than enforced until a Mac has played a
    # packaged build online (DESIGN.md's Multiplayer, M6).
    if ! codesign --verify --verbose "$found"; then
      echo "::warning::$lib does not verify: $(codesign -dv "$found" 2>&1 | tr '\n' ' ')"
    fi
    ;;
  *)
    echo "usage: $0 windows|macos <build>" >&2
    exit 2
    ;;
esac
