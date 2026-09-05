#!/usr/bin/env bash
# Proves that a headless gate boot with FILLY_TEST_SAVE_DIR set leaves the player's own save
# directory byte-identical -- by booting a real gate and looking. See game/systems/save_io.gd
# for the switch and docs/testing.md for the writeup.
#
#   bash tools/prove_save_safety.sh                     # the proof
#   bash tools/prove_save_safety.sh --negative-control  # prove the proof can fail
#
# NEITHER RUN CAN REACH THE REAL user://saves. Both point XDG_DATA_HOME at a temporary
# directory, which is where Godot resolves user:// from on Linux, so the "live" directory this
# script measures is a sandboxed copy seeded with one decoy slot. That matters most for the
# negative control, whose whole job is to WRITE the live directory: running that against the
# owner's own saves to prove a point would be the exact accident this slice exists to prevent.
#
# THE PROOF: seed a decoy slot in the sandboxed user://saves, take a checksum manifest of it,
# boot scenes/test/market_test.tscn with FILLY_TEST_SAVE_DIR pointed elsewhere, and require
# three things -- the gate passed, the manifest did not move, and the redirected directory
# actually received files. That third one is not decoration: without it a gate that wrote
# nothing anywhere would look exactly like a redirect that worked.
#
# THE NEGATIVE CONTROL: the same boot with FILLY_TEST_SAVE_DIR unset. The manifest MUST move.
# Without this half, a comparison that passed on anything at all would look like a passing
# proof -- which is the failure mode this project keeps finding in its own gates.
#
# --audio-driver Dummy on every run: this is an automated invocation and must never make noise
# on whatever machine runs it (see docs/pipeline.md and game/systems/audio_safety.gd).
set -uo pipefail
cd "$(dirname "$0")/.."

GODOT=tools/bin/godot
GATE=scenes/test/market_test.tscn
NEGATIVE=0
[ "${1:-}" = "--negative-control" ] && NEGATIVE=1

SANDBOX_HOME="$(mktemp -d)"
REDIRECT_DIR="$(mktemp -d)"
trap 'rm -rf "$SANDBOX_HOME" "$REDIRECT_DIR"' EXIT

# Where Godot puts user:// on Linux, given XDG_DATA_HOME. The project name comes from
# game/project.godot's application/config/name.
LIVE="$SANDBOX_HOME/godot/app_userdata/Filly Rancher/saves"
mkdir -p "$LIVE"
# A decoy that stands in for the owner's ranch. "Untouched" is only a claim worth making about
# a directory that had something in it to touch.
printf '{\n  "bits": 4242,\n  "marker": "OWNER_SAVE",\n  "version": 5\n}\n' > "$LIVE/slot_0.json"

manifest() {
  ( cd "$LIVE" && find . -type f -print0 | sort -z | xargs -0 -r sha256sum )
}

before="$(manifest)"

if [ "$NEGATIVE" -eq 1 ]; then
  echo "== NEGATIVE CONTROL: booting the gate with no redirect at all =="
  XDG_DATA_HOME="$SANDBOX_HOME" \
    "$GODOT" --headless --audio-driver Dummy --path game "$GATE" > "$SANDBOX_HOME/gate.log" 2>&1
else
  echo "== booting the gate with FILLY_TEST_SAVE_DIR=$REDIRECT_DIR =="
  XDG_DATA_HOME="$SANDBOX_HOME" FILLY_TEST_SAVE_DIR="$REDIRECT_DIR" \
    "$GODOT" --headless --audio-driver Dummy --path game "$GATE" > "$SANDBOX_HOME/gate.log" 2>&1
fi
gate_rc=$?

# A gate that crashed may have written nothing for reasons that have nothing to do with the
# redirect, so its verdict is a precondition of this proof and not an afterthought.
if [ "$gate_rc" -ne 0 ]; then
  echo "FAIL: the gate exited $gate_rc, so this run measured a broken build rather than the redirect." >&2
  tail -20 "$SANDBOX_HOME/gate.log" >&2
  exit 1
fi

after="$(manifest)"
redirected_files="$(find "$REDIRECT_DIR" -type f | wc -l)"
live_files="$(find "$LIVE" -type f | wc -l)"
echo "PROOF live_dir='$LIVE' files_before=1 files_after=$live_files redirected_files=$redirected_files"

if [ "$NEGATIVE" -eq 1 ]; then
  if [ "$before" = "$after" ]; then
    echo "FAIL: an unredirected gate boot left the live save directory identical -- this harness cannot tell a written save from an untouched one, so its positive result would mean nothing." >&2
    exit 1
  fi
  echo "SAVE_SAFETY_PROOF_NEGATIVE_CONTROL_OK -- an unredirected gate boot DOES write the live save directory, and this harness catches it."
  exit 0
fi

if [ "$before" != "$after" ]; then
  echo "FAIL: a redirected gate boot changed the live save directory." >&2
  diff <(printf '%s\n' "$before") <(printf '%s\n' "$after") >&2
  exit 1
fi
if [ "$redirected_files" -eq 0 ]; then
  echo "FAIL: the live directory is untouched but nothing was written to $REDIRECT_DIR either -- the gate wrote no save at all, so this proves nothing about the redirect." >&2
  exit 1
fi
echo "SAVE_SAFETY_PROOF_OK -- a gate boot with FILLY_TEST_SAVE_DIR set wrote $redirected_files file(s) there and left the live save directory byte-identical."
