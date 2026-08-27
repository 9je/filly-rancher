#!/usr/bin/env bash
# Runs the GUT (Godot Unit Test) suite headlessly against game/test/ and
# propagates its exit code. Every later gameplay task's tests live under
# game/test/ (files named test_*.gd, GUT's default convention) and run
# through this script -- see docs/testing.md for the full harness writeup.
#
# GUT_TEST_DIR overrides the res:// directory scanned for tests (default
# res://test) -- exists mainly so this script's zero-tests-ran guard below
# can be exercised against an empty/nonexistent directory without having to
# touch the real game/test/ to prove it.
set -uo pipefail
cd "$(dirname "$0")/.."

GUT_TEST_DIR="${GUT_TEST_DIR:-res://test}"

if [ ! -f game/addons/gut/plugin.cfg ]; then
  echo "ERROR: GUT addon not found at game/addons/gut/ -- run 'bash tools/setup_env.sh' first." >&2
  exit 1
fi

out="$(mktemp)"
trap 'rm -f "$out"' EXIT

tools/bin/godot --headless --path game \
  -s addons/gut/gut_cmdln.gd \
  -gdir="$GUT_TEST_DIR" -gprefix=test_ -gsuffix=.gd \
  -gexit 2>&1 | tee "$out"
gut_exit="${PIPESTATUS[0]}"

# INVARIANT, not string-matching: a real GUT run always ends with a "Totals"
# summary block containing a "Tests   <N>" line -- the count of tests it
# actually executed, whether they passed or failed. GUT's own process exit
# code is NOT trustworthy on its own: it calls quit(0) -- success -- in more
# than one situation where zero tests actually ran. Two confirmed so far:
#   1. Its class_names aren't registered in the Godot import cache yet (a
#      fresh checkout, or right after this addon is installed/updated).
#   2. -gdir points at an empty or nonexistent directory -- GUT prints
#      "Nothing was run. / On the one hand nothing failed, on the other
#      hand nothing did anything." and still exits 0. A future path typo,
#      an emptied game/test/, or a renamed test file all reach this.
# Enumerating each such message as it's discovered is a losing game -- the
# next unknown variant slips through the same way. Parsing the actual
# tests-run count and hard-failing when it's zero or unparseable subsumes
# every zero-tests-executed failure mode, known or not, in one check.
tests_run="$(grep -oP '^Tests\s+\K[0-9]+' "$out" | tail -1 || true)"

if [ -z "$tests_run" ] || [ "$tests_run" -eq 0 ]; then
  echo "ERROR: GUT ran zero tests (or its output could not be parsed for a test count) -- treating this as a hard failure regardless of GUT's own exit code ($gut_exit)." >&2
  # Best-effort extra diagnostic on top of the invariant check above, for
  # the two known causes -- purely cosmetic, not load-bearing for safety.
  if grep -q "have not been imported" "$out"; then
    echo "  Likely cause: GUT's GDScript classes are not registered in the Godot import cache yet." >&2
    echo "  Fix: run 'tools/bin/godot --headless --path game --import' once, then retry." >&2
  elif grep -q "Nothing was run" "$out"; then
    echo "  Likely cause: no test scripts matched in '$GUT_TEST_DIR' (empty/nonexistent dir, or a naming/glob mismatch)." >&2
  fi
  exit 1
fi

exit "$gut_exit"
