#!/usr/bin/env bash
# Regenerate game/ui/theme/filly_theme.tres from game/ui/menu_style.gd's constants.
# The Theme is OUTPUT: edit menu_style.gd, run this, commit both files.
# --audio-driver Dummy on principle; every scripted invocation of this game is silent.
set -uo pipefail
cd "$(dirname "$0")/.."

tools/bin/godot --headless --audio-driver Dummy --path game -s scripts/make_theme.gd
rc=$?
if [ "$rc" -ne 0 ]; then
  echo "FAIL: the theme generator exited $rc" >&2
  exit 1
fi
echo "OK: game/ui/theme/filly_theme.tres regenerated"
