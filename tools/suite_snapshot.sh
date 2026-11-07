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
# The engine is gitignored: link it in.
mkdir -p "$DIR/tools/bin" && ln -sf "$PWD/tools/bin/godot" "$DIR/tools/bin/godot"
# Reuse the main tree's import cache so the snapshot doesn't re-import every asset.
if [ -d game/.godot ] && [ ! -d "$DIR/game/.godot" ]; then cp -r game/.godot "$DIR/game/.godot"; fi
echo "suite on $SHA in $DIR"
set +e
( cd "$DIR" && tools/run_tests.sh )
CODE=$?
set -e
git worktree remove --force "$DIR"
exit $CODE
