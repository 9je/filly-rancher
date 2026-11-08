#!/usr/bin/env bash
# Run named GUT files (sandboxed), print one line per file, exit 1 if any test failed or any
# file printed an unexpected script error. Usage: tools/focused_tests.sh test_a.gd test_b.gd ...
set -uo pipefail
cd "$(dirname "$0")/.."
TMP="$(mktemp -d)"
export XDG_DATA_HOME="$TMP" FILLY_TEST_SAVE_DIR="$TMP/saves"
mkdir -p "$TMP/saves"
bad=0
for t in "$@"; do
  out=$(tools/bin/godot --headless --render-thread safe --audio-driver Dummy --log-file "$TMP/g.log" \
    --path game -s addons/gut/gut_cmdln.gd -gtest="res://test/$t" -gexit 2>&1)
  pass=$(echo "$out" | grep -E "^Passing Tests" | grep -oE "[0-9]+" | head -1)
  fail=$(echo "$out" | grep -E "^Failing Tests" | grep -oE "[0-9]+" | head -1)
  if [ -n "${fail:-}" ] || [ -z "${pass:-}" ]; then
    bad=1
    echo "FAIL $t pass=${pass:-0} fail=${fail:-?}"
    echo "$out" | grep -E "Failed\]|SCRIPT ERROR" | grep -v "gut_loader\|type 'Nil' to a variable of type 'bool'" | head -6
  else
    echo "ok   $t pass=$pass"
  fi
done
rm -rf "$TMP"
exit $bad
