#!/usr/bin/env bash
#
# Launch an exported Filly Rancher build and assert it reaches its startup marker.
#
# WHY IT LIVES HERE: GitHub only parses *.yml / *.yaml inside .github/workflows/ as
# workflow definitions -- any other file in this directory is inert -- so keeping the
# script next to the workflow lets the Linux job and the Windows job execute literally
# the same bytes (windows-latest runs it under Git Bash via `shell: bash`). If each
# platform had its own script, a green Windows job would only prove the Windows script
# was the more lenient of the two.
#
# usage: smoke_run.sh <path-to-exported-binary>

set -uo pipefail

BIN="${1:?usage: smoke_run.sh <path-to-exported-binary>}"

# ---------------------------------------------------------------------------
# Accepted startup markers -- enumerated explicitly, on purpose.
#
#   SMOKE_OK  printed by game/scenes/test/smoke_test.gd, the main scene today.
#   RANCH_OK  printed by the ranch scene that Phase 1A Task 7 promotes to main
#             scene. Accepted in advance so the hand-over doesn't need a CI edit.
#
# Both are spelled out rather than matched loosely (e.g. '[A-Z]*_OK'), because a
# loose pattern is exactly how this check would rot into a silent pass: after Task 7
# a scene that prints some *other* _OK line, or prints nothing at all, must fail this
# job. Two literal alternatives can only pass for the two scenes we actually mean.
# When the ranch scene lands and SMOKE_OK is retired, drop SMOKE_OK from this list.
# ---------------------------------------------------------------------------
MARKERS='SMOKE_OK|RANCH_OK'

STDOUT_LOG="ci_smoke_stdout.log"
ENGINE_LOG="ci_smoke_engine.log"
COMBINED_LOG="ci_smoke_combined.log"
rm -f "$STDOUT_LOG" "$ENGINE_LOG" "$COMBINED_LOG"

# The artifact download drops the POSIX exec bit; harmless on Windows, required on Linux.
chmod +x "$BIN" 2>/dev/null || true

echo "== running: $BIN --headless --quit-after 600 =="

# --headless        no GPU/display exists on a runner. Godot falls back to the dummy
#                   rendering driver; scene tree, scripts and print() all still run
#                   (Phase 0 ran the 3D gallery/walk/terrain probes this way), but
#                   nothing is actually rasterised. See docs/ci.md for what that
#                   does and does not prove.
# --quit-after 600  bounded run. The current smoke scene calls get_tree().quit(0)
#                   itself, but a future ranch scene will not -- without this the job
#                   would hang until the runner's timeout instead of reporting a
#                   result. 600 headless iterations take a couple of seconds.
# --log-file        Godot writes its own copy of the log to this path. On Windows the
#                   exported binary is a GUI-subsystem .exe with no console wrapper in
#                   release exports (export_console_wrapper=1 = debug builds only), so
#                   stdout capture depends on handle inheritance from the parent shell;
#                   the engine-written log does not. Both files are searched below, so
#                   the marker is found if EITHER channel carries it.
RUN=("$BIN" --headless --quit-after 600 --log-file "$ENGINE_LOG")

# `timeout` is coreutils; present on ubuntu-latest and in Git Bash on windows-latest.
# Guarded rather than assumed -- if it is missing, --quit-after plus the job's
# timeout-minutes still bound the run.
if command -v timeout >/dev/null 2>&1; then
  timeout 300 "${RUN[@]}" >"$STDOUT_LOG" 2>&1
else
  "${RUN[@]}" >"$STDOUT_LOG" 2>&1
fi
rc=$?

# Merge the two capture channels into one file, tolerating either being absent, and
# search *that*. Grepping `cat a b | grep` instead would be subtly wrong: under
# `pipefail` a missing engine log makes the whole pipeline non-zero even when stdout
# does contain the marker, i.e. a false failure. (Caught by a negative-control run.)
: >"$COMBINED_LOG"
cat "$STDOUT_LOG" >>"$COMBINED_LOG" 2>/dev/null || true
cat "$ENGINE_LOG" >>"$COMBINED_LOG" 2>/dev/null || true

echo "== exit code: $rc =="
echo "== stdout =="
cat "$STDOUT_LOG" 2>/dev/null || echo "(no stdout captured)"
echo "== engine log ($ENGINE_LOG) =="
cat "$ENGINE_LOG" 2>/dev/null || echo "(engine wrote no log file)"
echo "== end of captured output =="

fail=0

if [ "$rc" -ne 0 ]; then
  echo "FAIL: binary exited $rc (expected 0)" >&2
  [ "$rc" -eq 124 ] && echo "  (124 = timed out; the scene never quit)" >&2
  fail=1
fi

if grep -Eq "$MARKERS" "$COMBINED_LOG"; then
  echo "PASS: startup marker matched ($MARKERS)"
else
  echo "FAIL: no startup marker matching '$MARKERS' in stdout or engine log" >&2
  fail=1
fi

exit "$fail"
