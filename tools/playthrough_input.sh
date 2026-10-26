#!/usr/bin/env bash
# THE PLAYTHROUGHS THAT COUNT (docs/playtest_fixes/playthrough.md): a new game from the title
# screen to each ending, played ONLY through real input (Input.parse_input_event with the
# InputMap's own keys and the mouse) by game/test_input/playthrough_input.gd. They need a real
# window, so they get one on an INVISIBLE display (xvfb-run) rendered on the GPU; time runs on
# --fixed-fps 60 (game seconds, faster than real time when the GPU keeps up). One ending at a
# time, saves isolated per run. Logs in build/playthrough_<ending>.log.
#   tools/playthrough_input.sh                    all five
#   tools/playthrough_input.sh lights_out ...     just these
#   PT_ARGS="--seed=3" tools/playthrough_input.sh placement
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-tools/bin/godot}"
endings=("$@")
[ ${#endings[@]} -eq 0 ] && endings=(brightest_rainbow gray_gold lights_out half_light placement)
mkdir -p build
pass=0
fail=0
for e in "${endings[@]}"; do
  export FILLY_TEST_SAVE_DIR="$(mktemp -d)"
  log="build/playthrough_$e.log"
  start=$(date +%s)
  timeout 21600 env -u WAYLAND_DISPLAY MESA_VK_WSI_DEBUG=sw xvfb-run -a -s "-screen 0 1280x720x24" \
    nice -n 19 "$GODOT" --display-driver x11 --gpu-index 0 --resolution 1280x720 --fixed-fps 60 \
    --log-file "$(mktemp -d)/godot.log" --path game --audio-driver Dummy -s res://test_input/playthrough_input.gd \
    -- --ending="$e" --log="$(pwd)/build/playthrough_$e.bot.log" ${PT_ARGS:-} > "$log" 2>&1
  rc=$?
  wall=$(( $(date +%s) - start ))
  grep -E "^PLAYTHROUGH_(OK|FAILED|STEP|BUG)|SCRIPT ERROR" "$log" | sed "s/^/[$e] /"
  rm -rf "$FILLY_TEST_SAVE_DIR"
  if [ $rc -eq 0 ] && grep -q "^PLAYTHROUGH_OK $e" "$log"; then
    echo "PLAYTHROUGH_OK $e (wall ${wall}s)"
    pass=$((pass+1))
  else
    echo "PLAYTHROUGH_FAILED $e (rc $rc, wall ${wall}s, log $log)"
    fail=$((fail+1))
  fi
done
if [ $fail -eq 0 ]; then echo "PLAYTHROUGHS_OK $pass"; else echo "PLAYTHROUGHS_FAILED passed=$pass failed=$fail"; fi
[ $fail -eq 0 ]
