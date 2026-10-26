#!/usr/bin/env bash
# The pacing test (MISSION.md, "Fun and anti-repetition rules"): a fresh save, from the title
# screen, played by the human-paced bot (game/scenes/test/human_bot.gd, the real-input
# playthrough's brain: every action is Input.parse_input_event) in an INVISIBLE window on the
# GPU at a fixed 60 fps, so the play clock is simulated real time. Writes PACING.md and exits
# nonzero if any gap is over the cadence limits or the first clue is late.
#   tools/pacing.sh [minutes] [seed]
set -uo pipefail
cd "$(dirname "$0")/.."
MIN="${1:-70}"
SEED="${2:-7}"
export FILLY_TEST_SAVE_DIR="$(mktemp -d)"
trap 'rm -rf "$FILLY_TEST_SAVE_DIR"' EXIT
log="build/pacing.log"
mkdir -p build
env -u WAYLAND_DISPLAY MESA_VK_WSI_DEBUG=sw xvfb-run -a -s "-screen 0 1280x720x24" \
  nice -n 19 tools/bin/godot --display-driver x11 --gpu-index 0 --resolution 1280x720 --fixed-fps 60 \
  --log-file "$(mktemp -d)/godot.log" --path game --audio-driver Dummy \
  -s res://scenes/test/human_bot.gd -- --minutes="$MIN" --seed="$SEED" --pacing="$(pwd)/PACING.md" \
  > "$log" 2>&1
grep -E "^PACING_|^BOT_OK|^PLAYTHROUGH_BUG|SCRIPT ERROR" "$log" | head -20
grep -q "^PACING_OK" "$log"
