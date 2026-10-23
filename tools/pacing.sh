#!/usr/bin/env bash
# The pacing test (MISSION.md, "Fun and anti-repetition rules"): a fresh save played by the
# human-paced bot (game/scenes/test/human_bot.gd), headless at a fixed 60 fps so the play
# clock is simulated real time. Writes PACING.md and exits nonzero if any gap is over the
# cadence limits or the first clue is late.
#   tools/pacing.sh [minutes] [seed]
set -uo pipefail
cd "$(dirname "$0")/.."
MIN="${1:-70}"
SEED="${2:-7}"
export FILLY_TEST_SAVE_DIR="$(mktemp -d)"
trap 'rm -rf "$FILLY_TEST_SAVE_DIR"' EXIT
log="build/pacing.log"
mkdir -p build
tools/bin/godot --headless --fixed-fps 60 --audio-driver Dummy --path game \
  -s res://scenes/test/human_bot.gd -- --minutes="$MIN" --seed="$SEED" --pacing="$(pwd)/PACING.md" \
  > "$log" 2>&1
grep -E "^PACING_|^BOT_OK|SCRIPT ERROR" "$log" | head -20
grep -q "^PACING_OK" "$log"
