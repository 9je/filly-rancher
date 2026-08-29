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
#
# FILLY_MIN_TESTS overrides the floor on how many tests must run (default
# below, kept at the suite's current size). Same purpose: it lets the floor
# guard be exercised without removing real tests.
#
# THREE THINGS ARE CHECKED BEYOND GUT'S OWN EXIT CODE, because that exit code
# has now twice reported success for a run that verified far less than it
# claimed: that some tests ran at all, that EVERY test_*.gd file on disk was
# actually executed (a script that fails to parse is silently skipped), and
# that the number of tests has not fallen below a floor. See docs/testing.md.
#
# --audio-driver Dummy is explicit and not just implied by --headless (which already
# maps to it) so this stays quiet even if that mapping ever changes -- this is an
# automated, non-interactive run and must never make noise on whatever machine runs
# it. See docs/pipeline.md and the incident note in game/systems/audio_safety.gd.
set -uo pipefail
cd "$(dirname "$0")/.."

GUT_TEST_DIR="${GUT_TEST_DIR:-res://test}"

if [ ! -f game/addons/gut/plugin.cfg ]; then
  echo "ERROR: GUT addon not found at game/addons/gut/ -- run 'bash tools/setup_env.sh' first." >&2
  exit 1
fi

out="$(mktemp)"
trap 'rm -f "$out"' EXIT

tools/bin/godot --headless --audio-driver Dummy --path game \
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

# SECOND INVARIANT -- THE FLOOR. The guard above only fires at ZERO tests, and the
# failure that actually shipped is not zero: two test scripts failed to PARSE (a
# preload of a file that did not exist yet), GUT logged "Ignoring script ... because
# it does not extend GutTest", ran the other eleven, and printed
#   Scripts 11 / Tests 119 / Passing 119 / ---- All tests passed! ----
# with exit 0. Twelve tests and two whole scripts vanished from the suite while it
# claimed success. That is the same family of hole as the zero-tests case -- a success
# claim outrunning what was actually verified -- so it gets the same treatment: assert
# the invariant, do not enumerate the messages.
#
# The invariant that has teeth is COUNTING THE SCRIPTS ON DISK. Every file matching
# test_*.gd in the test directory is a script GUT is supposed to run, so the number it
# reports in its Totals block must equal the number of files that are sitting there.
# Anything less means a script was skipped -- parse error, wrong base class, a rename
# GUT's prefix no longer matches -- whatever the cause, known or not. This number
# maintains itself: adding a test file raises both sides at once, so nobody has to
# remember to bump a constant.
#
# -maxdepth 1 matches GUT's own default: it does not descend into subdirectories
# unless -ginclude_subdirs is passed, and this script does not pass it. (game/test/
# has a fixtures/ subdirectory with no test scripts in it, which is why that matters.)
test_fs_dir=""
case "$GUT_TEST_DIR" in
  res://*) test_fs_dir="game/${GUT_TEST_DIR#res://}" ;;
esac

scripts_run="$(grep -oP '^Scripts\s+\K[0-9]+' "$out" | tail -1 || true)"

if [ -n "$test_fs_dir" ] && [ -d "$test_fs_dir" ]; then
  expected_scripts="$(find "$test_fs_dir" -maxdepth 1 -type f -name 'test_*.gd' | wc -l)"
  if [ -z "$scripts_run" ]; then
    echo "ERROR: GUT's output could not be parsed for a script count -- treating this as a hard failure regardless of GUT's own exit code ($gut_exit)." >&2
    exit 1
  fi
  if [ "$scripts_run" -ne "$expected_scripts" ]; then
    echo "ERROR: GUT ran $scripts_run test script(s) but $expected_scripts test_*.gd file(s) exist in $test_fs_dir/ -- $((expected_scripts - scripts_run)) script(s) were SILENTLY SKIPPED and their tests did not run. Failing regardless of GUT's own exit code ($gut_exit)." >&2
    # Best-effort diagnostic, exactly like the cosmetic hints below: name the files GUT
    # said it was ignoring, and the parse errors it printed above them.
    grep -E "Ignoring script|Failed to load script|Parse Error" "$out" | sed 's/^/  /' >&2 || true
    echo "  Fix: the named script(s) failed to load -- usually a parse error (a preload of a file that does not exist, a syntax error, or a script that does not extend GutTest)." >&2
    exit 1
  fi
fi

# THIRD INVARIANT -- a floor on the number of tests, for the half of the failure above
# that the script count cannot see: a test file that still parses but has lost most of
# its tests (a bad merge, a mass rename, a `func test_x` that became `func x`). This one
# is a hand-maintained number, deliberately a FLOOR rather than an exact count so adding
# tests never breaks the build -- raise it when the suite grows, and never lower it
# without saying in a commit message which tests went away and why.
MIN_TESTS="${FILLY_MIN_TESTS:-467}"
if [ "$tests_run" -lt "$MIN_TESTS" ]; then
  echo "ERROR: GUT ran $tests_run tests, below this suite's floor of $MIN_TESTS -- tests have gone missing. Failing regardless of GUT's own exit code ($gut_exit)." >&2
  echo "  If tests were deliberately removed, lower MIN_TESTS in tools/run_tests.sh in the same commit and say why." >&2
  exit 1
fi

# A FOURTH known cause reaches this point instead of the zero-tests guard above:
# tests actually ran (GDScript class_names were registered fine) but a chunk of
# them fail because a .glb the pipeline regenerated was never reimported --
# same root cause as cause 1 above (docs/pipeline.md section 7's "first .glb
# import needs an editor pass" quirk), just caught later because it only breaks
# resources that fail to load, not GUT's own bootstrap. Two people have now lost
# time to this exact symptom (~19 red tests, e.g. "the player's body must build
# with a reachable AnimationPlayer") with no hint printed at all -- the guard
# above only fires on zero tests, and this is never zero. Same best-effort,
# cosmetic-only diagnostic as above, gated on the one engine message every
# variant of this failure shares regardless of which pony/prop/model it hits.
if [ "$gut_exit" -ne 0 ] && grep -q "did not load as a PackedScene" "$out"; then
  echo "NOTE: at least one resource failed to load as a PackedScene -- if the failures above include '... must build with a reachable AnimationPlayer' or similar, this is very likely a stale glb-import cache, not a real regression." >&2
  echo "  Likely cause: a .glb was (re)generated by the asset pipeline since the last import pass -- same root cause as the zero-tests case above." >&2
  echo "  Fix: run 'tools/bin/godot --headless --path game --import' once, then retry." >&2
fi

exit "$gut_exit"
