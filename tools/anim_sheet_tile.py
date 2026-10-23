#!/usr/bin/env python3
"""Tile tools/anim_sheet.py output (DIR/<clip>_<n>.png) into one labelled sheet.

    python3 -I tools/anim_sheet_tile.py DIR OUT.png
"""
import os
import re
import sys

from PIL import Image, ImageDraw

src, out = sys.argv[1], sys.argv[2]
rows = {}
for fn in os.listdir(src):
    m = re.match(r"(.+)_(\d+)\.png$", fn)
    if m:
        rows.setdefault(m.group(1), {})[int(m.group(2))] = os.path.join(src, fn)
names = sorted(rows)
cols = max(len(v) for v in rows.values())
first = Image.open(next(iter(rows[names[0]].values())))
w, h = first.size
label = 90
sheet = Image.new("RGB", (label + cols * w, len(names) * h), (30, 30, 34))
d = ImageDraw.Draw(sheet)
for r, name in enumerate(names):
    d.text((6, r * h + h // 2 - 6), name, fill=(240, 240, 240))
    for c, path in sorted(rows[name].items()):
        sheet.paste(Image.open(path).convert("RGB"), (label + c * w, r * h))
sheet.save(out)
print("TILED", len(names), "clips", cols, "frames ->", out)
