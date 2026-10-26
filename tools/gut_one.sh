#!/usr/bin/env bash
# Iteration helper: run one or more GUT test files headlessly, saves isolated.
#   tools/gut_one.sh test_events [test_pony_look ...]
# The full suite (tools/run_tests.sh) is still the gate at milestone boundaries.
set -uo pipefail
cd "$(dirname "$0")/.."
export FILLY_TEST_SAVE_DIR="$(mktemp -d)"
trap 'rm -rf "$FILLY_TEST_SAVE_DIR"' EXIT
GODOT="${GODOT:-tools/bin/godot}"
args=()
for t in "$@"; do args+=("-gtest=res://test/${t%.gd}.gd"); done
"$GODOT" --headless --audio-driver Dummy --log-file "$FILLY_TEST_SAVE_DIR/godot.log" --path game -s addons/gut/gut_cmdln.gd \
  "${args[@]}" -gexit 2>&1 | grep -vE "^\s*$" | grep -E "FAILED|Failing|Passing|Tests |SCRIPT ERROR|Parse Error|ERROR|\[Failed\]|^\s+at|expected|got" | head -60
exit "${PIPESTATUS[0]}"
