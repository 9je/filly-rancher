#!/usr/bin/env bash
# THE PONY TURNTABLE CONTACT SHEETS (docs/playtest_fixes/ponies.md). Renders every roster
# model, Spike, the story cast and 50 generated Drifters through
# game/scenes/test/pony_turntable.gd (front, side, three-quarter, eye close-up, and the
# three-quarter at 16 m, and at the FAR detail tier), on the invisible display with the real GPU, then
# tiles them into sheets: one row per pony, eight ponies a sheet, plus an eyes-only sheet.
#   tools/pony_turntable.sh OUT_DIR [extra args for the scene, e.g. only=fluttershy,gen03]
# Renders, does not assert: a person looks at the sheets.
set -uo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-build/playtest_evidence/ponies/now}"
shift || true
mkdir -p "$OUT/shots"
OUT="$(cd "$OUT" && pwd)"
export FILLY_TEST_SAVE_DIR="$(mktemp -d)"
trap 'rm -rf "$FILLY_TEST_SAVE_DIR"' EXIT
env -u WAYLAND_DISPLAY MESA_VK_WSI_DEBUG=sw xvfb-run -a -s "-screen 0 800x800x24" \
  nice -n 19 tools/bin/godot --display-driver x11 --gpu-index 0 --resolution 800x800 \
  --fixed-fps 60 --log-file "$(mktemp -d)/godot.log" --path game --audio-driver Dummy -s res://scenes/test/pony_turntable.gd -- \
  out="$OUT/shots" "$@" > "$OUT/render.log" 2>&1
grep -E "Using Device" "$OUT/render.log" | head -1
grep -E "^TURNTABLE_(PROBLEM|DONE)|SCRIPT ERROR" "$OUT/render.log"

python3 - "$OUT" <<'PY'
import glob, os, sys
from PIL import Image, ImageDraw
out = sys.argv[1]
shots = os.path.join(out, "shots")
views = ["front", "side", "threequarter", "eyes", "mid", "far"]
tags = sorted({os.path.basename(p).rsplit("_", 1)[0] for p in glob.glob(shots + "/*_front.png")},
              key=lambda t: (["roster", "spike", "cast", "gen"].index(t.split("_")[0]), t))
T, L, PER = 300, 22, 8
for n in range(0, len(tags), PER):
    chunk = tags[n:n + PER]
    sheet = Image.new("RGB", (T * len(views), (T + L) * len(chunk)), (28, 28, 28))
    d = ImageDraw.Draw(sheet)
    for r, tag in enumerate(chunk):
        for c, v in enumerate(views):
            p = os.path.join(shots, "%s_%s.png" % (tag, v))
            if os.path.exists(p):
                sheet.paste(Image.open(p).convert("RGB").resize((T, T)), (c * T, r * (T + L) + L))
        d.text((6, r * (T + L) + 4), tag + "   (front | side | three-quarter | eyes | 16 m | far tier)", fill=(240, 240, 240))
    sheet.save(os.path.join(out, "sheet_%02d.png" % (n // PER)))
# Eyes only, bigger, six across.
E, C = 400, 5
rows = (len(tags) + C - 1) // C
for n in range(0, rows, 4):
    part = tags[n * C:(n + 4) * C]
    sheet = Image.new("RGB", (E * C, (E + L) * ((len(part) + C - 1) // C)), (28, 28, 28))
    d = ImageDraw.Draw(sheet)
    for i, tag in enumerate(part):
        p = os.path.join(shots, "%s_eyes.png" % tag)
        x, y = (i % C) * E, (i // C) * (E + L)
        if os.path.exists(p):
            sheet.paste(Image.open(p).convert("RGB").resize((E, E)), (x, y + L))
        d.text((x + 6, y + 4), tag, fill=(240, 240, 240))
    sheet.save(os.path.join(out, "eyes_%02d.png" % (n // 4)))
print("TURNTABLE_SHEETS ponies=%d dir=%s" % (len(tags), out))
PY
