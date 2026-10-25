#!/usr/bin/env bash
# A NON-COUNTING SMOKE TEST of the five endings' story wiring (game/scenes/test/smoke_endings.gd):
# headless, through the game's own entry points (set_flag, conversations driven by signal,
# catches stored straight into the bag, --factory-fast). It BYPASSES PLAYER INPUT, so it is
# not a playthrough and proves nothing about what a player can do; the playthroughs that
# count are tools/playthrough.sh (tools/playthrough_input.sh). It is kept because it runs in
# seconds and catches a broken ending table. Saves isolated.
#   tools/smoke_endings.sh                  all five
#   tools/smoke_endings.sh lights_out ...   just these
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-tools/bin/godot}"
endings=("$@")
[ ${#endings[@]} -eq 0 ] && endings=(brightest_rainbow gray_gold lights_out half_light placement)
fail=0
for e in "${endings[@]}"; do
  export FILLY_TEST_SAVE_DIR="$(mktemp -d)"
  out="$("$GODOT" --headless --render-thread safe --audio-driver Dummy --path game -s res://scenes/test/smoke_endings.gd \
    -- --ending="$e" --factory-fast --people 2>&1)"
  rc=$?
  echo "$out" | grep -E "^PLAYTHROUGH|^ENDING_REACHED|SCRIPT ERROR" | sed "s/^PLAYTHROUGH/SMOKE/; s/^/[$e] /"
  rm -rf "$FILLY_TEST_SAVE_DIR"
  if [ $rc -ne 0 ] || ! echo "$out" | grep -q "^PLAYTHROUGH_OK $e"; then fail=1; fi
done
[ $fail -eq 0 ] && echo "SMOKE_ENDINGS_OK ${#endings[@]}" || echo "SMOKE_ENDINGS_FAILED"
exit $fail
