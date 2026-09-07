#!/usr/bin/env bash
## The owner's launch button. Run from anywhere:
##
##   ./play.sh          fresh start -- stashes the current save, then launches
##   ./play.sh keep     continue the existing save untouched
##
## "Fresh" never deletes: the saves folder is MOVED to
## scratchpad/save-backups/auto/<timestamp>/ (the newest 10 are kept), so any
## run can be restored by copying its slot_*.json back into the live saves dir.
## settings.cfg lives outside the saves folder and is never touched -- volume
## and other knobs survive a fresh start.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIVE_SAVES="$HOME/.local/share/godot/app_userdata/Filly Rancher/saves"
BACKUPS="$ROOT/scratchpad/save-backups/auto"

MODE="${1:-fresh}"
case "$MODE" in
	fresh)
		if [ -d "$LIVE_SAVES" ] && [ -n "$(ls -A "$LIVE_SAVES" 2>/dev/null)" ]; then
			STAMP="$(date +%Y-%m-%d_%H%M%S)"
			mkdir -p "$BACKUPS"
			mv "$LIVE_SAVES" "$BACKUPS/$STAMP"
			echo "Save stashed to scratchpad/save-backups/auto/$STAMP (starting fresh)"
			# Keep the newest 10 stashes; the rest age out.
			ls -1d "$BACKUPS"/*/ 2>/dev/null | sort | head -n -10 | xargs -r rm -rf
		else
			echo "No existing save -- starting fresh"
		fi
		;;
	keep)
		echo "Keeping the existing save"
		;;
	*)
		echo "usage: $(basename "$0") [fresh|keep]   (default: fresh)" >&2
		exit 2
		;;
esac

exec "$ROOT/tools/bin/godot" --path "$ROOT/game"
