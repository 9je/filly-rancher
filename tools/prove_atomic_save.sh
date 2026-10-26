#!/usr/bin/env bash
# Proves that an interrupted save cannot destroy the previous one -- by interrupting a
# real one. See game/scripts/prove_atomic_save.gd for the phases and
# game/systems/save_io.gd for the guarantee being tested.
#
#   bash tools/prove_atomic_save.sh                     # the proof
#   bash tools/prove_atomic_save.sh --negative-control  # prove the proof can fail
#
# THE PROOF: seed an OLD save, then start writing a NEW one and SIGKILL the process
# between stage() and commit(). A third process then loads the slot and must find the OLD
# save, complete. A unit test cannot do this -- it can only decline to call commit(),
# which demonstrates the shape of the code rather than the behaviour of the filesystem.
#
# THE NEGATIVE CONTROL: the same interruption applied to a naive save that writes straight
# over the live file. The verification step must FAIL there. Without this half, a
# verification that passed on anything at all would look exactly like a passing proof --
# which is the failure mode this project keeps finding in its own gates.
#
# --audio-driver Dummy on every run: this is an automated invocation and must never make
# noise on whatever machine runs it (see docs/pipeline.md and game/systems/audio_safety.gd).
set -uo pipefail
cd "$(dirname "$0")/.."

GODOT=tools/bin/godot
SCRIPT=scripts/prove_atomic_save.gd
NEGATIVE=0
[ "${1:-}" = "--negative-control" ] && NEGATIVE=1

# Belt and braces: the script under test assigns SaveIO.save_dir itself (PROOF_DIR, below),
# so this redirect is not what keeps it off the player's saves -- but every godot boot this
# project documents carries it, and there is no reason for this one to be the exception.
FILLY_TEST_SAVE_DIR="$(mktemp -d)"
export FILLY_TEST_SAVE_DIR
# PROOF_DIR is "user://atomic_write_proof", which Godot resolves under the real app_userdata
# directory regardless of FILLY_TEST_SAVE_DIR, so this script leaves that folder behind in the
# player's own data dir unless it is swept up here.
PROOF_APPDATA="${XDG_DATA_HOME:-$HOME/.local/share}/godot/app_userdata/Filly Rancher/atomic_write_proof"
trap 'rm -rf "$FILLY_TEST_SAVE_DIR" "$PROOF_APPDATA"' EXIT

run_phase() {
  local phase="$1"
  "$GODOT" --headless --audio-driver Dummy --log-file "$(mktemp -d)/godot.log" --path game -s "$SCRIPT" -- "--phase=$phase"
  return $?
}

echo "== phase 1: seed the save that must survive =="
run_phase seed || { echo "FAIL: could not write the seed save" >&2; exit 1; }

if [ "$NEGATIVE" -eq 1 ]; then
  echo "== phase 2 (NEGATIVE CONTROL): half-write straight over the live save, then SIGKILL =="
  run_phase kill-unsafe
else
  echo "== phase 2: stage a new save, then SIGKILL before commit =="
  run_phase kill
fi
kill_rc=$?
# 137 = 128 + SIGKILL(9). Anything else means the process exited on its own, so nothing
# was interrupted and whatever the verify step says afterwards is meaningless.
if [ "$kill_rc" -ne 137 ]; then
  echo "FAIL: the write phase exited $kill_rc, not 137 (SIGKILL) -- the process was never actually interrupted, so this proof measured nothing." >&2
  exit 1
fi
echo "   (process died with rc=$kill_rc == 128+SIGKILL, as intended)"

echo "== phase 3: a fresh process loads the slot =="
run_phase verify
verify_rc=$?

if [ "$NEGATIVE" -eq 1 ]; then
  if [ "$verify_rc" -eq 0 ]; then
    echo "FAIL: the verification passed even though the live save was half-overwritten -- this proof cannot tell a surviving save from a destroyed one." >&2
    exit 1
  fi
  echo "ATOMIC_SAVE_PROOF_NEGATIVE_CONTROL_OK -- a non-atomic write killed mid-flight DOES destroy the save, and phase 3 catches it (rc=$verify_rc)."
  exit 0
fi

if [ "$verify_rc" -ne 0 ]; then
  echo "FAIL: the previous save did not survive an interrupted write (verify rc=$verify_rc)." >&2
  exit 1
fi
echo "ATOMIC_SAVE_PROOF_OK -- a save interrupted by SIGKILL between stage() and commit() left the previous save complete and loadable."
