#!/usr/bin/env bash
# Render the ranch once for every one of the sixteen (phase, weather) pairs and tile them
# into build/sky_sheet.png, so a person can judge the whole of slice 4's sky in one image
# instead of launching sixteen sessions. Rows are the phases (dawn, day, dusk, night),
# columns are the weathers (clear, rain, fog, storm).
#
# NOT A GATE. Nothing here passes or fails: game/scenes/test/world_test.tscn is what
# asserts the sky rig is wired to the clock, and it asserts it in numbers. This renders
# pixels, and only a person can say whether a stormy dusk LOOKS like a stormy dusk. Slow
# (roughly a minute a cell under xvfb, so about twenty minutes in total).
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
# Neither build/ nor anything under it is committed; see .gitignore.
set -uo pipefail
cd "$(dirname "$0")/.."

PHASES="dawn day dusk night"
WEATHERS="clear rain fog storm"
SHOT="01_establishing"

OUT="${1:-build/sky_shots}"
mkdir -p "$OUT" build
# Resolve to an absolute path: Godot runs with --path game, so a relative --screenshot-dir
# would land under game/build instead of this script's own build/ directory.
OUT="$(cd "$OUT" && pwd)" || { echo "cannot enter shots directory '${1:-build/sky_shots}'" >&2; exit 1; }

rendered=0
failed=0
failed_cells=""
for phase in $PHASES; do
  for weather in $WEATHERS; do
    cell="${phase}_${weather}"
    if [ -f "$OUT/$cell.png" ]; then
      rendered=$((rendered + 1))
      continue
    fi
    mkdir -p "$OUT/$cell"
    timeout 300 xvfb-run -a tools/bin/godot --path game --audio-driver Dummy \
        --resolution 960x540 world/ranch.tscn -- \
        "--screenshot-dir=$OUT/$cell" "--phase=$phase" "--weather=$weather" \
        > "$OUT/$cell.log" 2>&1
    # THE VERDICT IS THE PNG, NOT THE EXIT CODE, for tools/roster_sheet.sh's reason: Godot
    # returns 0 from plenty of runs that rendered nothing and non-zero from runs that wrote
    # every shot before something unrelated complained on the way out. The file either
    # exists or the sheet has a hole in it, and that is the only question here.
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
echo "SKY_RENDER rendered=$rendered failed=$failed cells_failed=[$failed_cells]"

python3 - "$OUT" <<'PY'
import os
import sys

from PIL import Image, ImageDraw

out = sys.argv[1]
phases = ["dawn", "day", "dusk", "night"]
weathers = ["clear", "rain", "fog", "storm"]

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
PY
