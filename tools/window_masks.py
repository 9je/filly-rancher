"""WINDOW GLOW MASKS FOR THE PONYVILLE HOUSES (Fable AAA review round 1, #1: "nothing emits
light ... no window is warm"). The pv_* houses carry their windows painted into the base
texture as lavender panes inside a dark lattice. This keys those panes out of each texture by
colour and writes a mask, <glb basename>_win_<image name>.png, beside the .glb; the toon shader
warms masked texels after dark.

  python3 tools/window_masks.py [--sheet out.png]
"""
import glob
import io
import json
import os
import struct
import sys

import numpy as np
from scipy import ndimage
from PIL import Image, ImageFilter

PROPS = os.path.join(os.path.dirname(__file__), "..", "game", "assets", "converted", "props")


def glb_images(path):
    b = open(path, "rb").read()
    n = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20:20 + n])
    off = 20 + n
    bl = struct.unpack("<I", b[off:off + 4])[0]
    blob = b[off + 8:off + 8 + bl]
    out = []
    for i, im in enumerate(j.get("images", [])):
        bv = j["bufferViews"][im["bufferView"]]
        s = bv.get("byteOffset", 0)
        out.append((i, im.get("name", ""), Image.open(io.BytesIO(blob[s:s + bv["byteLength"]])).convert("RGB")))
    return out


def mask_of(img):
    a = np.asarray(img).astype(np.float32) / 255.0
    mx = a.max(axis=2)
    mn = a.min(axis=2)
    s = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0.0)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    d = np.maximum(mx - mn, 1e-6)
    h = np.where(mx == r, ((g - b) / d) % 6.0, np.where(mx == g, (b - r) / d + 2.0, (r - g) / d + 4.0)) * 60.0
    # Lavender glass (the town's house style) and the courtyard's blue glass.
    lav = (h >= 285.0) & (h <= 333.0) & (s >= 0.12) & (s <= 0.40) & (mx >= 0.30) & (mx <= 0.92)
    blue = (h >= 190.0) & (h <= 230.0) & (s >= 0.20) & (s <= 0.65) & (mx >= 0.40)
    glass = lav | blue
    dark = mx < 0.16
    # A PANE SITS IN A LATTICE: a flat pink panel or door is glass-coloured too, but has no
    # dark muntins through it. Close each window across its muntins into one shape, then
    # keep the shapes with muntins in them, whole, so a lit window lights all its panes.
    shut = ndimage.binary_closing(glass, structure=np.ones((9, 9)))
    labels, n = ndimage.label(shut)
    keep = np.zeros_like(glass)
    if n:
        idx = np.arange(1, n + 1)
        area = ndimage.sum(np.ones_like(glass), labels, idx)
        darkness = ndimage.mean(dark, labels, idx)
        limit = glass.size * 0.02
        good = idx[(area >= 80) & (area <= limit) & (darkness > 0.05) & (darkness < 0.72)]
        keep = np.isin(labels, good) & ~dark | (np.isin(labels, good) & dark)
    m = Image.fromarray((keep * 255).astype(np.uint8), "L").filter(ImageFilter.MaxFilter(3))
    return m


def main():
    sheet = sys.argv[sys.argv.index("--sheet") + 1] if "--sheet" in sys.argv else ""
    tiles = []
    for glb in sorted(glob.glob(os.path.join(PROPS, "pv_*.glb"))):
        base = os.path.splitext(glb)[0]
        for i, name, img in glb_images(glb):
            if "normal" in name.lower() or "roof" in name.lower() or "bush" in name.lower():
                continue
            m = mask_of(img)
            if m.getbbox() is None:
                continue
            m.save("%s_win_%s.png" % (base, name))
            print("MASK", os.path.basename(base), i, name, int(np.asarray(m).astype(bool).mean() * 100), "%")
            if sheet:
                t = img.copy()
                t.paste((255, 200, 40), mask=m)
                tiles.append(t.resize((256, 256)))
    if sheet and tiles:
        cols = 6
        rows = (len(tiles) + cols - 1) // cols
        out = Image.new("RGB", (cols * 256, rows * 256))
        for k, t in enumerate(tiles):
            out.paste(t, ((k % cols) * 256, (k // cols) * 256))
        out.save(sheet)


main()
