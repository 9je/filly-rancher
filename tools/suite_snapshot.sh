#!/usr/bin/env bash
# Run the full GUT suite on a detached snapshot of a commit (default HEAD), so the working tree
# can keep changing while it runs. Prints the suite's summary; the snapshot is removed after.
set -euo pipefail
cd "$(dirname "$0")/.."
REV="${1:-HEAD}"
SHA=$(git rev-parse --short "$REV")
DIR="${TMPDIR:-/tmp}/filly_suite_$SHA"
git worktree remove --force "$DIR" 2>/dev/null || true
git worktree add -q --detach "$DIR" "$SHA"
# The engine, GUT and the converted models are gitignored: link them in.
mkdir -p "$DIR/tools/bin" "$DIR/game/addons" "$DIR/game/assets"
ln -sf "$PWD/tools/bin/godot" "$DIR/tools/bin/godot"
ln -sfn "$PWD/game/addons/gut" "$DIR/game/addons/gut"
ln -sfn "$PWD/game/assets/converted" "$DIR/game/assets/converted"
# Reuse the main tree's import cache so the snapshot doesn't re-import every asset.
if [ -d game/.godot ] && [ ! -d "$DIR/game/.godot" ]; then cp -r game/.godot "$DIR/game/.godot"; fi
echo "suite on $SHA in $DIR"
set +e
LOG="${TMPDIR:-/tmp}/filly_suite_$SHA.log"
( cd "$DIR" && tools/run_tests.sh ) > "$LOG" 2>&1
CODE=$?
# The summary, and every failing test by name (the full log stays at $LOG).
grep -a -E "^(Tests|Passing Tests|Failing Tests) " "$LOG"
grep -a -B1 -E "\[Failed\]" "$LOG" | grep -a -E "^\* test_|res://test/|\[Failed\]" | head -40
echo "full log: $LOG"
set -e
git worktree remove --force "$DIR"
exit $CODE
