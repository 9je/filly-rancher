#!/usr/bin/env bash
# Render every registered character's face and tile them into build/roster_sheet.png,
# so the owner can review the whole roster in one image rather than opening 44 files.
# Slow (about 20 s per character under xvfb, so roughly 15 to 20 minutes total). Not a
# gate: it renders, a person looks. Use `tools/bin/godot`, xvfb-run and the exact
# `mode=face` invocation documented at the top of game/scenes/test/visual_review.gd.
#
# Also writes build/roster_sheet_large.png (4 columns, bigger tiles) from the same
# rendered shots, in case the default 8 column sheet is too small to judge by eye.
set -uo pipefail
cd "$(dirname "$0")/.."

OUT="${1:-build/roster_shots}"
mkdir -p "$OUT" build
# Resolve to an absolute path: Godot runs with --path game, so a relative out= would
# land under game/build instead of this script's own build/ directory.
OUT="$(cd "$OUT" && pwd)"

rendered=0
failed=0
failed_ids=""
for f in game/data/ponies/*.tres; do
  id=$(basename "$f" .tres)
  if [ -f "$OUT/${id}_face_front.png" ]; then
    rendered=$((rendered + 1))
    continue
  fi
  if timeout 300 xvfb-run -a tools/bin/godot --path game --audio-driver Dummy \
      --resolution 1280x720 scenes/test/visual_review.tscn -- \
      mode=face character="$id" out="$OUT" > /dev/null 2>&1; then
    rendered=$((rendered + 1))
  else
    failed=$((failed + 1))
    failed_ids="$failed_ids $id"
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

files = sorted(glob.glob(os.path.join(out, "*_face_front.png")))


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

print("ROSTER_SHEET characters=%d file=%s large_file=%s" % (len(files), small_path, large_path))
PY
