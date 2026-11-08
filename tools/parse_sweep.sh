#!/usr/bin/env bash
# The test runner's parse sweep on its own, four at a time (P8: a signal named `ready` broke
# ranch.gd while every focused test passed). Prints each file the engine refuses; exits 1 if any.
# Runs Godot sandboxed: XDG_DATA_HOME points at a temp dir, so nothing reaches the owner's folder.
set -uo pipefail
cd "$(dirname "$0")/.."
TMP="$(mktemp -d)"
export XDG_DATA_HOME="$TMP"
check() {
  if ! tools/bin/godot --headless --audio-driver Dummy --log-file "$XDG_DATA_HOME/c_$$_$RANDOM.log" \
      --path game --check-only --script "res://${1#game/}" >/dev/null 2>&1; then
    echo "PARSE_FAIL res://${1#game/}"
  fi
}
export -f check
fails=$(find game -name '*.gd' -not -path 'game/addons/*' | sort | xargs -P 4 -I{} bash -c 'check "$@"' _ {})
rm -rf "$TMP"
if [ -n "$fails" ]; then
  echo "$fails"
  exit 1
fi
echo "PARSE_OK"
