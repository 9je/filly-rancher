#!/usr/bin/env bash
# Render every registered character's face and tile them into build/roster_sheet.png,
# so the owner can review the whole roster in one image rather than opening one file per
# character. The roster is game/data/ponies/*.tres, which is what "registered" means
# here: a shot left over from a character who has since been dropped is not in it.
# Slow (about 20 s per character under xvfb, so roughly 15 to 20 minutes total). Not a
# gate: it renders, a person looks. Use `tools/bin/godot`, xvfb-run and the exact
# `mode=face` invocation documented at the top of game/scenes/test/visual_review.gd.
#
# Also writes build/roster_sheet_large.png (4 columns, bigger tiles) from the same
# rendered shots, in case the default 8 column sheet is too small to judge by eye.
set -uo pipefail
cd "$(dirname "$0")/.."

# Every render boots a scene out of this project, and a boot can write a save. Redirected off
# own boot probe. Redirected off the player's slots the same way tools/run_tests.sh does it; see
# game/systems/save_io.gd. A sheet is not worth somebody's ranch.
FILLY_TEST_SAVE_DIR="${FILLY_TEST_SAVE_DIR:-$(mktemp -d)}"
export FILLY_TEST_SAVE_DIR

OUT="${1:-build/roster_shots}"
mkdir -p "$OUT" build
# Resolve to an absolute path: Godot runs with --path game, so a relative out= would
# land under game/build instead of this script's own build/ directory.
OUT="$(cd "$OUT" && pwd)" || { echo "cannot enter shots directory '${1:-build/roster_shots}'" >&2; exit 1; }

rendered=0
failed=0
failed_ids=""
for f in game/data/ponies/*.tres; do
  id=$(basename "$f" .tres)
  if [ -f "$OUT/${id}_face_front.png" ]; then
    rendered=$((rendered + 1))
    continue
  fi
  timeout 300 xvfb-run -a tools/bin/godot --path game --audio-driver Dummy \
      --resolution 1280x720 scenes/test/visual_review.tscn -- \
      mode=face character="$id" out="$OUT" > /dev/null 2>&1
  # THE VERDICT IS THE PNG, NOT THE EXIT CODE. Godot returns 0 from plenty of runs that
  # rendered nothing (a scene that pushed an error and quit) and non-zero from runs that
  # wrote every shot before something unrelated complained on the way out. The file
  # either exists or the sheet has a hole in it, and that is the only question here.
  if [ -f "$OUT/${id}_face_front.png" ]; then
    rendered=$((rendered + 1))
  else
    failed=$((failed + 1))
    if [ -z "$failed_ids" ]; then failed_ids="$id"; else failed_ids="$failed_ids $id"; fi
    echo "render failed: $id"
  fi
done
echo "ROSTER_RENDER rendered=$rendered failed=$failed ids_failed=[$failed_ids]"

python3 - "$OUT" <<'PY'
import glob
import os
import re
import sys

from PIL import Image, ImageDraw

out = sys.argv[1]
data_dir = "game/data/ponies"

# THE ROSTER DRIVES THE SHEET, NOT THE SHOTS DIRECTORY. Globbing the shots would tile
# whatever happens to be lying in it, which is how a character dropped from the roster
# (songbirdserenade) went on appearing in a sheet that is supposed to be a picture of
# what ships. Missing shots are counted and named instead of quietly changing the sheet.
ids = sorted(
    os.path.basename(p)[: -len(".tres")]
    for p in glob.glob(os.path.join(data_dir, "*.tres"))
)
files = []
missing = []
for char_id in ids:
    shot = os.path.join(out, char_id + "_face_front.png")
    if os.path.exists(shot):
        files.append(shot)
    else:
        missing.append(char_id)


def display_name(char_id: str) -> str:
    path = os.path.join(data_dir, char_id + ".tres")
    try:
        with open(path, "r", encoding="utf-8") as fh:
            text = fh.read()
    except OSError:
        return char_id
    m = re.search(r'display_name\s*=\s*"([^"]*)"', text)
    return m.group(1) if m else char_id


def build_sheet(files, cols, tile_w, tile_h, label_h, sheet_path):
    rows = (len(files) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * tile_w, rows * tile_h), (30, 30, 30))
    draw = ImageDraw.Draw(sheet)
    for i, f in enumerate(files):
        char_id = os.path.basename(f).replace("_face_front.png", "")
        im = Image.open(f).resize((tile_w, tile_h - label_h))
        x, y = (i % cols) * tile_w, (i // cols) * tile_h
        sheet.paste(im, (x, y))
        draw.text((x + 6, y + tile_h - label_h + 2), display_name(char_id), fill=(240, 240, 240))
    sheet.save(sheet_path)
    return sheet_path


small_path = build_sheet(files, cols=8, tile_w=320, tile_h=200, label_h=20, sheet_path="build/roster_sheet.png")
large_path = build_sheet(files, cols=4, tile_w=560, tile_h=350, label_h=30, sheet_path="build/roster_sheet_large.png")

print(
    "ROSTER_SHEET characters=%d of %d missing=[%s] file=%s large_file=%s"
    % (len(files), len(ids), " ".join(missing), small_path, large_path)
)
PY
