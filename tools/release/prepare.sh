#!/usr/bin/env bash
# Readies a fresh checkout for an export, on a build machine only:
#
#   tools/release/prepare.sh <godot binary> <MAJOR.MINOR.PATCH> [run mode]
#
# 1. Stamps the version into project.godot as `config/version`, which is what
#    the exe's file version and the .app's Info.plist read. It is the numeric
#    core (0.2.0, never 0.2.0-beta.1): both of those fields refuse anything
#    else. The game's own menu reads VERSION itself (release_check.gd), so this
#    is never committed and the repository keeps ONE place the number lives.
# 2. On a deploy to dev (mode `dev`), adds the custom feature `dev` to every
#    export preset, so a dev build can tell it is one - `OS.has_feature("dev")`
#    - and talk to dev's own signaling rather than the live one. And renames
#    it: "The New Hire (dev)" and its own macOS bundle id, so to the OS it is
#    a different app from the game - the name is also what names `user://`,
#    so a dev build keeps its settings (and one day its saves) in a folder of
#    its own. The dev name REPLACES the packaged one rather than adding a
#    `config/name.dev` beside it: a build carrying both features matches both
#    overrides, and Godot takes whichever line comes first in the file. Never
#    committed either: in the repository, every build is a release build.
# 3. Runs the import pass. A fresh clone has no .godot/ at all - nothing
#    imported, and no extension_list.cfg naming webrtc_native - and an export
#    without it either fails or ships a game that cannot play online.

set -euo pipefail

godot="$1"
core="$2"
mode="${3:-}"

if grep -q '^config/version=' project.godot; then
  echo "project.godot already has a config/version; refusing to guess" >&2
  exit 1
fi
awk -v v="$core" '{ print } /^\[application\]$/ { print "config/version=\"" v "\"" }' \
  project.godot > project.godot.stamped
mv project.godot.stamped project.godot
grep -n '^config/version=' project.godot

if [ "$mode" = "dev" ]; then
  # `t` ends the line's script once the first has matched, or an empty list
  # made "dev" would then match the second and come out "dev,dev".
  sed -E -e 's/^custom_features=""$/custom_features="dev"/' -e 't' \
    -e 's/^custom_features="(.+)"$/custom_features="\1,dev"/' \
    export_presets.cfg > export_presets.cfg.stamped
  mv export_presets.cfg.stamped export_presets.cfg
  grep -n '^custom_features=' export_presets.cfg

  # Every field that holds the game's exact name - the packaged name in
  # project.godot, the Windows exe's product name and description - and the
  # bundle id. The Windows installer's half is `/DDev` (installer.iss).
  sed -E 's/="The New Hire"$/="The New Hire (dev)"/' project.godot > project.godot.stamped
  mv project.godot.stamped project.godot
  sed -E -e 's/="The New Hire"$/="The New Hire (dev)"/' \
    -e 's/^(application\/bundle_identifier="[^"]+)"$/\1.dev"/' \
    export_presets.cfg > export_presets.cfg.stamped
  mv export_presets.cfg.stamped export_presets.cfg
  # Refuse rather than ship a dev build wearing the game's identity: a
  # renamed game or bundle id would otherwise slip past both seds silently.
  if ! grep -q '^config/name.packaged="The New Hire (dev)"$' project.godot \
    || ! grep -q '^application/product_name="The New Hire (dev)"$' export_presets.cfg \
    || ! grep -q '^application/bundle_identifier="[^"]*\.dev"$' export_presets.cfg; then
    echo "::error::prepare.sh could not give the dev build its own name and bundle id" >&2
    exit 1
  fi
  grep -nE '\(dev\)|bundle_identifier' project.godot export_presets.cfg
fi

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
