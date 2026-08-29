#!/usr/bin/env bash
# Render the ranch once for every one of the sixteen (phase, weather) pairs and tile them
# into build/sky_sheet.png, so a person can judge the whole of slice 4's sky in one image
# instead of launching sixteen sessions. Rows are the phases (dawn, day, dusk, night),
# columns are the weathers (clear, rain, fog, storm).
#
# NOT A GATE ON THE SKY, BUT IT IS A GATE ON ITSELF. Nothing here can say whether a stormy
# dusk LOOKS like a stormy dusk; game/scenes/test/world_test.tscn is what asserts the sky
# rig is wired to the clock, and it asserts it in numbers. What this script CAN say is
# whether the sheet it just wrote is a whole sheet: a failed render or a missing cell exits
# 1, because a sheet with a hole in it that exited 0 is a sheet somebody signs off by eye
# without noticing the hole. Slow (a minute or two a cell under xvfb, so most of an hour for
# all sixteen).
#
# Each run is world/ranch.tscn itself, pinned with --phase= and --weather= and pointed at a
# screenshot directory, which is exactly the invocation documented at the top of
# game/world/ranch.gd. A pinned run never writes a moved clock into anybody's save, and a
# screenshot run is not interactive, so it autosaves nothing either.
#
# ranch.gd's _capture_all() takes eight or so shots per run; only the first, the wide
# establishing view named 01_establishing, is about the sky. The rest are kept in the shots
# directory (they cost nothing and they are already rendered) and ignored by the tiler.
#
# Usage: tools/sky_sheet.sh [--keep] [--only=<phase>_<weather>] [shots-directory]
#
#   --keep    Reuse whatever cells are already rendered in the shots directory instead of
#             clearing them first. Reused cells are counted as kept=, never as rendered=,
#             so the summary never claims credit for a picture of an older build.
#   --only=   Render and tile ONE cell (for instance --only=night_storm), which is what to
#             use after tuning a single number rather than sitting through the sixteen.
#             The sheet it writes is that one cell.
#
# Neither build/ nor anything under it is committed; see .gitignore.
set -uo pipefail
cd "$(dirname "$0")/.."

PHASES="dawn day dusk night"
WEATHERS="clear rain fog storm"
SHOT="01_establishing"

KEEP=0
ONLY=""
OUT=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --keep) KEEP=1 ;;
    --only=*) ONLY="${1#--only=}" ;;
    -*) echo "sky_sheet: unknown option '$1'; see the usage note at the top of this file." >&2; exit 2 ;;
    *) OUT="$1" ;;
  esac
  shift
done

if [ -n "$ONLY" ]; then
  only_phase="${ONLY%%_*}"
  only_weather="${ONLY#*_}"
  case " $PHASES " in *" $only_phase "*) ;; *)
    echo "sky_sheet: --only=$ONLY names no phase; expected one of $PHASES" >&2; exit 2 ;;
  esac
  case " $WEATHERS " in *" $only_weather "*) ;; *)
    echo "sky_sheet: --only=$ONLY names no weather; expected one of $WEATHERS" >&2; exit 2 ;;
  esac
  PHASES="$only_phase"
  WEATHERS="$only_weather"
fi

OUT="${OUT:-build/sky_shots}"
mkdir -p "$OUT" build
# Resolve to an absolute path: Godot runs with --path game, so a relative --screenshot-dir
# would land under game/build instead of this script's own build/ directory.
OUT="$(cd "$OUT" && pwd)" || { echo "cannot enter shots directory '$OUT'" >&2; exit 1; }

# CLEARED BY THE GRID, NOT BY EMPTYING THE DIRECTORY. Every cell this run is about to
# render has its png, its log and its per-run shot directory removed first, so the sheet is
# sixteen pictures of the build in front of you rather than a silent mix of today's renders
# and last week's. Deleting the cells rather than the whole directory is what lets --only
# re-render one square without throwing away the fifteen good ones beside it, and means the
# script never removes a file it did not write.
if [ "$KEEP" -eq 0 ]; then
  for phase in $PHASES; do
    for weather in $WEATHERS; do
      rm -rf "$OUT/${phase}_${weather}" "$OUT/${phase}_${weather}.png" "$OUT/${phase}_${weather}.log"
    done
  done
fi

rendered=0
kept=0
failed=0
failed_cells=""
for phase in $PHASES; do
  for weather in $WEATHERS; do
    cell="${phase}_${weather}"
    if [ -f "$OUT/$cell.png" ]; then
      # Only reachable under --keep, and counted apart from a real render for exactly that
      # reason: "rendered=16" on a run that rendered nothing is the summary lying.
      kept=$((kept + 1))
      continue
    fi
    mkdir -p "$OUT/$cell"
    timeout 300 xvfb-run -a tools/bin/godot --path game --audio-driver Dummy \
        --resolution 960x540 world/ranch.tscn -- \
        "--screenshot-dir=$OUT/$cell" "--phase=$phase" "--weather=$weather" \
        > "$OUT/$cell.log" 2>&1
    # THE VERDICT ON ONE CELL IS ITS PNG, NOT GODOT'S EXIT CODE, for tools/roster_sheet.sh's
    # reason: Godot returns 0 from plenty of runs that rendered nothing and non-zero from
    # runs that wrote every shot before something unrelated complained on the way out. The
    # file either exists or the sheet has a hole in it. The verdict on the SCRIPT is at the
    # bottom, and there a hole is a failure.
    if [ -f "$OUT/$cell/$SHOT.png" ]; then
      mv "$OUT/$cell/$SHOT.png" "$OUT/$cell.png"
      rendered=$((rendered + 1))
    else
      failed=$((failed + 1))
      if [ -z "$failed_cells" ]; then failed_cells="$cell"; else failed_cells="$failed_cells $cell"; fi
      echo "render failed: $cell (see $OUT/$cell.log)"
    fi
  done
done
echo "SKY_RENDER rendered=$rendered kept=$kept failed=$failed cells_failed=[$failed_cells]"

python3 - "$OUT" "$PHASES" "$WEATHERS" <<'PY'
import os
import sys

from PIL import Image, ImageDraw

out = sys.argv[1]
phases = sys.argv[2].split()
weathers = sys.argv[3].split()

TILE_W, TILE_H, LABEL_H = 480, 292, 22
BACKGROUND = (18, 18, 22)
INK = (245, 245, 245)
MISSING_INK = (200, 90, 90)

sheet = Image.new("RGB", (len(weathers) * TILE_W, len(phases) * TILE_H), BACKGROUND)
draw = ImageDraw.Draw(sheet)

# THE GRID DRIVES THE SHEET, NOT THE SHOTS DIRECTORY. A cell whose render failed is drawn
# as an empty labelled box in its own place rather than shuffling every later cell one
# square to the left, which would silently retitle every tile after the hole.
present = 0
missing = []
for row, phase in enumerate(phases):
    for col, weather in enumerate(weathers):
        cell = "%s_%s" % (phase, weather)
        x, y = col * TILE_W, row * TILE_H
        path = os.path.join(out, cell + ".png")
        label = "%s / %s" % (phase.upper(), weather.upper())
        ink = INK
        if os.path.exists(path):
            shot = Image.open(path).convert("RGB").resize((TILE_W, TILE_H - LABEL_H))
            sheet.paste(shot, (x, y))
            present += 1
        else:
            missing.append(cell)
            label += "  (MISSING)"
            ink = MISSING_INK
        draw.text((x + 6, y + TILE_H - LABEL_H + 5), label, fill=ink)
        draw.rectangle([x, y, x + TILE_W - 1, y + TILE_H - 1], outline=(70, 70, 78))

path = "build/sky_sheet.png"
sheet.save(path)
print("SKY_SHEET cells=%d of %d missing=[%s] file=%s"
      % (present, len(phases) * len(weathers), " ".join(missing), path))

# THE HOLE IS THE FAILURE. The sheet is still written, because a person looking at fifteen
# good cells and one red MISSING box learns more than a person looking at nothing. But the
# script must not exit 0 on it, or a CI run or a busy reader takes a partial sheet for a
# whole one.
if missing:
    sys.exit(1)
PY
sheet_status=$?

# EXIT 1 IF ANYTHING AT ALL WENT WRONG, and say which half it was. `failed` is checked as
# well as the tiler's own status because they answer different questions: the tiler sees a
# missing png, this sees a render that fell over, and a --keep run could in principle tile a
# stale png over a cell whose fresh render had just failed.
if [ "$failed" -gt 0 ]; then
  echo "sky_sheet: $failed of the cells failed to render; the sheet is not a whole sheet." >&2
  exit 1
fi
if [ "$sheet_status" -ne 0 ]; then
  echo "sky_sheet: the sheet has missing cells." >&2
  exit 1
fi
exit 0
