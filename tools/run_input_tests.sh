#!/usr/bin/env bash
# Real-input tests (game/test_input/test_*.gd), driven only by Input.parse_input_event
# (PLAYTEST_FIXES.md). They need a real window, so they get one on an INVISIBLE display
# (xvfb-run): nothing opens on the desktop and the mouse is never taken from whoever is at
# the machine. The GPU still renders (--gpu-index 0); Mesa's software present path
# (MESA_VK_WSI_DEBUG=sw) copies each frame into the invisible screen, since Xvfb has no DRI3.
# Time runs on --fixed-fps 60 and the tests count game seconds. Saves isolated per test.
#   tools/run_input_tests.sh               all
#   tools/run_input_tests.sh first_pony    just test_first_pony.gd
#   FILLY_INPUT_VERBOSE=1 ...             also print every INPUT_TEST_NOTE line and errors
#   FILLY_INPUT_ON_DESKTOP=1 ...           in a visible window on the GPU instead
# A test may ask for a different frame rate with a header line `## fixed-fps: N`
# (test_camera_terrain.gd runs at 144: a real monitor draws several frames per 60 Hz physics
# tick, and that gap is where its bug lived).
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-tools/bin/godot}"
names=("$@")
if [ ${#names[@]} -eq 0 ]; then
  mapfile -t names < <(ls game/test_input/test_*.gd | xargs -n1 basename | sed 's/^test_//; s/\.gd$//')
fi
pass=0; fail=0
for n in "${names[@]}"; do
  export FILLY_TEST_SAVE_DIR="$(mktemp -d)"
  fps="$(sed -n 's/^## fixed-fps: *\([0-9]\+\).*/\1/p' "game/test_input/test_$n.gd" | head -1)"
  fps="${fps:-60}"
  if [ "${FILLY_INPUT_ON_DESKTOP:-0}" = "1" ]; then
    run=("$GODOT" --resolution 1280x720)
  else
    run=(env -u WAYLAND_DISPLAY MESA_VK_WSI_DEBUG=sw xvfb-run -a -s "-screen 0 1280x720x24" \
      nice -n 19 "$GODOT" --display-driver x11 --gpu-index 0 --resolution 1280x720)
  fi
  # A test that measures wall-clock frame gaps (test_loading.gd) says so on a line of its own
  # and runs in real time; every other test runs on --fixed-fps game seconds (60 unless the
  # test's header says `## fixed-fps: N`).
  if [ "${FILLY_INPUT_ON_DESKTOP:-0}" != "1" ] && ! grep -q "^## INPUT_TEST_REALTIME" "game/test_input/test_$n.gd"; then
    run+=(--fixed-fps "$fps")
  fi
  out="$(timeout 3600 "${run[@]}" --path game --audio-driver Dummy -s "res://test_input/test_$n.gd" 2>&1)"
  rc=$?
  keep="^INPUT_TEST_(OK|FAILED)|SCRIPT ERROR"
  [ "${FILLY_INPUT_VERBOSE:-0}" = "1" ] && keep="^INPUT_TEST_|SCRIPT ERROR"
  echo "$out" | grep -E "$keep" | sed "s/^/[$n] /"
  rm -rf "$FILLY_TEST_SAVE_DIR"
  if [ $rc -eq 0 ] && echo "$out" | grep -q "^INPUT_TEST_OK"; then pass=$((pass+1)); else fail=$((fail+1)); fi
done
echo "INPUT_TESTS passed=$pass failed=$fail"
[ $fail -eq 0 ]
