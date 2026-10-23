#!/usr/bin/env bash
# Record trailer takes with Godot Movie Maker (game/scenes/test/trailer.gd), one process a shot:
#   tools/trailer/capture.sh [--res 3840x2160] [--take N] shot [shot ...]
# Each take lands in build/trailer/takes/<shot>_t<N>.avi with its log beside it (the log holds
# TRAILER_SHOT_START, the frame the edit trims to).
set -uo pipefail
cd "$(dirname "$0")/../.."
RES=3840x2160
TAKE=1
shots=()
while [ $# -gt 0 ]; do
  case "$1" in
    --res) RES="$2"; shift 2 ;;
    --take) TAKE="$2"; shift 2 ;;
    *) shots+=("$1"); shift ;;
  esac
done
W="${RES%x*}"; H="${RES#*x}"
mkdir -p build/trailer/takes
# THE CAPTURE SIZE IS THE ROOT VIEWPORT'S, NOT THE WINDOW'S: the window manager clamps a window
# to the work area (a 3840x2160 request came back 1920x1019, and even exclusive fullscreen lost
# the panel's strip), so the root viewport is pinned to the capture size with the "viewport"
# stretch mode and only scaled onto whatever window the desktop allows. Movie Maker records the
# root viewport, so every frame is exactly WxH, rendered on the GPU. For this run only.
printf '[display]\nwindow/size/viewport_width=%s\nwindow/size/viewport_height=%s\nwindow/size/window_width_override=1920\nwindow/size/window_height_override=1080\nwindow/stretch/mode="viewport"\nwindow/stretch/aspect="keep"\n' "$W" "$H" > game/override.cfg
trap 'rm -f game/override.cfg' EXIT
fail=0
for s in "${shots[@]}"; do
  out="build/trailer/takes/${s}_t${TAKE}.avi"
  export FILLY_TEST_SAVE_DIR="$(mktemp -d)"
  timeout 1200 tools/bin/godot --path game --write-movie "$(pwd)/$out" --fixed-fps 60 \
    -s res://scenes/test/trailer.gd -- --shot="$s" --take="$TAKE" > "${out%.avi}.log" 2>&1
  rm -rf "$FILLY_TEST_SAVE_DIR"
  if grep -q "TRAILER_SHOT_END" "${out%.avi}.log"; then echo "TAKE_OK $s t$TAKE"; else echo "TAKE_FAILED $s (see ${out%.avi}.log)"; fail=1; fi
done
exit $fail
