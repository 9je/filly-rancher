#!/usr/bin/env bash
# Headless playthroughs to every ending (game/scenes/test/playthrough.gd), saves isolated.
#   tools/playthrough.sh                  all five
#   tools/playthrough.sh lights_out ...   just these
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-tools/bin/godot}"
endings=("$@")
[ ${#endings[@]} -eq 0 ] && endings=(brightest_rainbow gray_gold lights_out half_light placement)
fail=0
for e in "${endings[@]}"; do
  export FILLY_TEST_SAVE_DIR="$(mktemp -d)"
  out="$("$GODOT" --headless --audio-driver Dummy --path game -s res://scenes/test/playthrough.gd \
    -- --ending="$e" --factory-fast --people 2>&1)"
  rc=$?
  echo "$out" | grep -E "^PLAYTHROUGH|^ENDING_REACHED|SCRIPT ERROR" | sed "s/^/[$e] /"
  rm -rf "$FILLY_TEST_SAVE_DIR"
  if [ $rc -ne 0 ] || ! echo "$out" | grep -q "^PLAYTHROUGH_OK $e"; then fail=1; fi
done
[ $fail -eq 0 ] && echo "PLAYTHROUGHS_OK ${#endings[@]}" || echo "PLAYTHROUGHS_FAILED"
exit $fail
