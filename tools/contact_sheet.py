#!/usr/bin/env python3
"""Tile images into a labelled contact sheet.
   python3 -I tools/contact_sheet.py OUT.jpg [--cols 3] [--width 800] img1.png img2.png ...
"""
import sys
from PIL import Image, ImageDraw, ImageFont

def main(argv):
    out = argv[0]
    cols, width = 3, 800
    files = []
    i = 1
    while i < len(argv):
        a = argv[i]
        if a == "--cols":
            cols = int(argv[i + 1]); i += 2; continue
        if a == "--width":
            width = int(argv[i + 1]); i += 2; continue
        files.append(a); i += 1
    if not files:
        return 1
    thumbs = []
    for f in files:
        im = Image.open(f).convert("RGB")
        h = int(im.height * width / im.width)
        thumbs.append((f.rsplit("/", 1)[-1].rsplit(".", 1)[0], im.resize((width, h))))
    th = max(t[1].height for t in thumbs)
    rows = (len(thumbs) + cols - 1) // cols
    label_h = 30
    sheet = Image.new("RGB", (cols * (width + 8) + 8, rows * (th + label_h + 8) + 8), (24, 24, 28))
    d = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 20)
    except OSError:
        font = ImageFont.load_default()
    for n, (name, im) in enumerate(thumbs):
        x = 8 + (n % cols) * (width + 8)
        y = 8 + (n // cols) * (th + label_h + 8)
        d.text((x + 4, y + 4), name, fill=(235, 235, 235), font=font)
        sheet.paste(im, (x, y + label_h))
    sheet.save(out, quality=88)
    print(out, sheet.size)
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
