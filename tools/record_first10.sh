#!/usr/bin/env bash
# FIRST_10_MINUTES.mp4: an uncut recording of a fresh save, played by the human-paced bot
# (game/scenes/test/human_bot.gd), captured with Godot Movie Maker at a pinned 1920x1080
# root viewport (see tools/trailer/capture.sh for why the viewport, not the window) and
# encoded to 1080p60 H.264 + AAC. No editing: what the bot played is what is on screen.
#   tools/record_first10.sh [minutes] [seed]
set -uo pipefail
cd "$(dirname "$0")/.."
MIN="${1:-10.1}"
SEED="${2:-7}"
mkdir -p build/first10
printf '[display]\nwindow/size/viewport_width=1920\nwindow/size/viewport_height=1080\nwindow/size/window_width_override=1920\nwindow/size/window_height_override=1080\nwindow/stretch/mode="viewport"\nwindow/stretch/aspect="keep"\n' > game/override.cfg
trap 'rm -f game/override.cfg' EXIT
export FILLY_TEST_SAVE_DIR="$(mktemp -d)"
tools/bin/godot --log-file "$(mktemp -d)/godot.log" --path game --write-movie "$(pwd)/build/first10/raw.avi" --fixed-fps 60 \
  -s res://scenes/test/human_bot.gd -- --minutes="$MIN" --seed="$SEED" --video > build/first10/record.log 2>&1
grep -E "^BOT_OK" build/first10/record.log || { echo "RECORD_FAILED (see build/first10/record.log)"; exit 1; }
ffmpeg -v error -y -i build/first10/raw.avi -t 600 -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p -r 60 \
  -c:a aac -b:a 192k -movflags +faststart FIRST_10_MINUTES.mp4
ffprobe -v error -show_entries stream=codec_name,width,height,r_frame_rate -show_entries format=duration -of compact FIRST_10_MINUTES.mp4
echo FIRST10_OK
