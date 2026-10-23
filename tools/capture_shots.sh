#!/usr/bin/env bash
# Render the review frames (game/scenes/test/shots.gd) offscreen into build/shots/ (or $1).
#   tools/capture_shots.sh [out_dir] [--set=lineup,face,dread,rigprobe] [--seed=N]
# Exits nonzero if the stage did not print SHOTS_OK or a listed frame is missing.
set -uo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-build/shots}"
shift || true
mkdir -p "$OUT"
export FILLY_TEST_SAVE_DIR="$(mktemp -d)"
trap 'rm -rf "$FILLY_TEST_SAVE_DIR"' EXIT
log="$OUT/capture.log"
timeout 600 xvfb-run -a -s "-screen 0 1600x900x24" tools/bin/godot --path game --audio-driver Dummy \
  scenes/test/shots.tscn -- --out="$(realpath "$OUT")" "$@" > "$log" 2>&1
grep -q "^SHOTS_OK" "$log" || { echo "SHOTS_FAILED (see $log)"; exit 1; }
missing=0
for f in $(grep "^SHOT " "$log" | awk '{print $2}'); do [ -s "$f" ] || { echo "missing: $f"; missing=1; }; done
[ "$missing" = 0 ] || exit 1
grep "^SHOTS_OK" "$log"
