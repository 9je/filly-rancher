#!/usr/bin/env bash
# The playthroughs to every ending: a new game from the title screen, played ONLY through real
# player input. This is tools/playthrough_input.sh (see it, and
# docs/playtest_fixes/playthrough.md). The old headless driver that called the game's entry
# points directly does not count and lives on, renamed, as tools/smoke_endings.sh.
#   tools/playthrough.sh                  all five
#   tools/playthrough.sh lights_out ...   just these
exec "$(dirname "$0")/playthrough_input.sh" "$@"
