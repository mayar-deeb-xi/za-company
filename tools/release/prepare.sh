#!/usr/bin/env bash
# Readies a fresh checkout for an export, on a build machine only:
#
#   tools/release/prepare.sh <godot binary> <MAJOR.MINOR.PATCH>
#
# 1. Stamps the version into project.godot as `config/version`, which is what
#    the exe's file version and the .app's Info.plist read. It is the numeric
#    core (0.2.0, never 0.2.0-beta.1): both of those fields refuse anything
#    else. The game's own menu reads VERSION itself (release_check.gd), so this
#    is never committed and the repository keeps ONE place the number lives.
# 2. Runs the import pass. A fresh clone has no .godot/ at all - nothing
#    imported, and no extension_list.cfg naming webrtc_native - and an export
#    without it either fails or ships a game that cannot play online.

set -euo pipefail

godot="$1"
core="$2"

if grep -q '^config/version=' project.godot; then
  echo "project.godot already has a config/version; refusing to guess" >&2
  exit 1
fi
awk -v v="$core" '{ print } /^\[application\]$/ { print "config/version=\"" v "\"" }' \
  project.godot > project.godot.stamped
mv project.godot.stamped project.godot
grep -n '^config/version=' project.godot

# --import exits when the pass is done. Its output is long and almost all
# progress; errors are what is worth surfacing in the run's summary.
"$godot" --headless --path . --import > import.log 2>&1 || {
  echo "::error::the import pass failed: $(grep -E 'ERROR|error' import.log | tail -n 5 | tr '\n' ' ')"
  exit 1
}
grep -q webrtc_native .godot/extension_list.cfg || {
  echo "::error::the import pass did not register webrtc_native"
  exit 1
}
echo "imported; extensions: $(tr '\n' ' ' < .godot/extension_list.cfg)"
