#!/usr/bin/env bash
# One release export, with its failure made readable from the run's summary:
#
#   tools/release/export.sh <godot binary> <preset name> <output path>
#
# Godot prints hundreds of progress lines per export; when it fails, the reason
# is a handful of ERROR lines somewhere in them. Those go up as an annotation,
# which is visible on the run's page without opening the log - and an output
# file that is missing fails the job even if Godot exited 0.

set -euo pipefail

godot="$1"
preset="$2"
out="$3"

mkdir -p "$(dirname "$out")"
status=0
"$godot" --headless --path . --export-release "$preset" "$out" > export.log 2>&1 || status=$?
if [ "$status" -ne 0 ] || [ ! -s "$out" ]; then
  echo "::error::export '$preset' failed (exit $status): $(grep -E 'ERROR|error|Error' export.log | tail -n 8 | tr '\n' ' ')"
  tail -n 40 export.log
  exit 1
fi
echo "exported $preset -> $out"
ls -la "$(dirname "$out")"
