#!/usr/bin/env bash
# Runs the GUT (Godot Unit Test) suite headlessly against game/test/ and
# propagates its exit code. Every later gameplay task's tests live under
# game/test/ (files named test_*.gd, GUT's default convention) and run
# through this script -- see docs/testing.md for the full harness writeup.
set -uo pipefail
cd "$(dirname "$0")/.."

if [ ! -f game/addons/gut/plugin.cfg ]; then
  echo "ERROR: GUT addon not found at game/addons/gut/ -- run 'bash tools/setup_env.sh' first." >&2
  exit 1
fi

out="$(mktemp)"
trap 'rm -f "$out"' EXIT

tools/bin/godot --headless --path game \
  -s addons/gut/gut_cmdln.gd \
  -gdir=res://test -gprefix=test_ -gsuffix=.gd \
  -gexit 2>&1 | tee "$out"
gut_exit="${PIPESTATUS[0]}"

# GUT's own entry script (gut_cmdln.gd) calls `quit(0)` -- exit 0, not 1 -- when
# its class_names haven't been registered yet (a fresh checkout, or right after
# tools/setup_env.sh installs/updates the addon, has no game/.godot/ import cache).
# That would make this script report success while having run zero tests, so it
# is explicitly checked for and hard-failed here rather than trusted to the
# (wrong, in this one case) exit code -- see docs/testing.md for the fix.
if grep -q "have not been imported" "$out"; then
  echo "ERROR: GUT's GDScript classes are not registered in the Godot import cache yet." >&2
  echo "  Run 'tools/bin/godot --headless --path game --import' once, then retry." >&2
  exit 1
fi

exit "$gut_exit"
