#!/usr/bin/env python3
"""THE UI KIT'S SURFACES (P8 S5; docs/aaa-review-2026-11-08.md 2.4).

Every panel and button in the game is one of a few painted surfaces, drawn here once as
nine-patch PNGs and stretched by Godot's StyleBoxTexture, instead of a flat rounded rectangle:

  paper    cream stock with a faint grain, a soft ink border that wobbles a little like the
           show's linework, and a drop shadow. HUD cards, letters, the catch card, tooltips.
  wood     a plank frame with brass corner studs round a paper inset. The ranch's menus:
           Market, Depot, build, pause.
  velvet   plum with a fine diagonal nap and gold piping. The Spectra Palace only.
  button   a cream pill with an ink edge, in idle, hover (gold rim, lifted) and pressed
           (pushed down a pixel, darker) states; plus a gold "primary" button.
  chip     a small round tag; tab_on / tab_off.
  card     the HUD's paper at a tight radius, for pills and small cards.

Writes game/assets/ui/kit/*.png at 2x (margins doubled) so it stays crisp under canvas
stretch; make_theme.gd reads the margins from MARGINS below via ui_kit.gd.

  python3 tools/make_ui_kit.py
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "game", "assets", "ui", "kit")
INK = (74, 51, 88)
CREAM = (255, 246, 227)
CREAM_DARK = (240, 226, 196)
GOLD = (245, 197, 66)
GOLD_DARK = (176, 128, 30)
PLUM = (68, 38, 88)
WOOD = (176, 120, 72)
WOOD_DARK = (122, 78, 44)
BRASS = (222, 180, 92)


def rounded_mask(w, h, r, inset=0, wobble=0.0, seed=1):
    """An anti-aliased rounded-rect mask, its edge nudged by `wobble` px of low noise."""
    s = 4
    m = Image.new("L", (w * s, h * s), 0)
    d = ImageDraw.Draw(m)
    if wobble <= 0:
        d.rounded_rectangle((inset * s, inset * s, (w - inset) * s - 1, (h - inset) * s - 1),
                            radius=r * s, fill=255)
    else:
        rnd = random.Random(seed)
        pts = []
        x0, y0, x1, y1 = inset, inset, w - inset, h - inset
        per = 2 * (x1 - x0 + y1 - y0)
        n = 220
        phase = [rnd.random() * 6.28 for _ in range(3)]
        for k in range(n):
            t = k / n
            px, py, nx, ny = _rr_point(x0, y0, x1, y1, r, t)
            off = wobble * (0.6 * math.sin(t * 6.28 * 3 + phase[0]) + 0.4 * math.sin(t * 6.28 * 7 + phase[1]))
            pts.append(((px + nx * off) * s, (py + ny * off) * s))
        d.polygon(pts, fill=255)
    return m.resize((w, h), Image.LANCZOS)


def _rr_point(x0, y0, x1, y1, r, t):
    """A point at fraction t round a rounded rect, with its outward normal."""
    w, h = x1 - x0, y1 - y0
    straight = [w - 2 * r, h - 2 * r, w - 2 * r, h - 2 * r]
    arc = math.pi * r / 2
    total = sum(straight) + 4 * arc
    dist = t * total
    corners = [(x1 - r, y0 + r, -90), (x1 - r, y1 - r, 0), (x0 + r, y1 - r, 90), (x0 + r, y0 + r, 180)]
    starts = [(x0 + r, y0, 1, 0, 0, -1), (x1, y0 + r, 0, 1, 1, 0), (x1 - r, y1, -1, 0, 0, 1),
              (x0, y1 - r, 0, -1, -1, 0)]
    for i in range(4):
        sx, sy, dx, dy, nx, ny = starts[i]
        if dist <= straight[i]:
            return sx + dx * dist, sy + dy * dist, nx, ny
        dist -= straight[i]
        if dist <= arc:
            cx, cy, a0 = corners[i]
            a = math.radians(a0 + 90 * dist / arc)
            return cx + r * math.cos(a), cy + r * math.sin(a), math.cos(a), math.sin(a)
        dist -= arc
    return x0 + r, y0, 0, -1


def grain(img, amount=6, seed=3):
    rnd = random.Random(seed)
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            n = rnd.randint(-amount, amount)
            px[x, y] = (max(0, min(255, r + n)), max(0, min(255, g + n)), max(0, min(255, b + n)), a)
    return img


def fill_mask(size, colour, mask):
    layer = Image.new("RGBA", size, colour + (255,))
    layer.putalpha(mask)
    return layer


def shadow(size, mask, offset=(0, 6), blur=6, alpha=90):
    sh = Image.new("RGBA", size, (40, 20, 50, 0))
    m = Image.new("L", size, 0)
    m.paste(mask, offset)
    m = m.filter(ImageFilter.GaussianBlur(blur)).point(lambda v: v * alpha // 255)
    sh.putalpha(m)
    return sh


def border(size, outer, inner, colour):
    """The ring between two masks, in `colour`."""
    ring = Image.new("L", size, 0)
    ring.paste(outer)
    inv = inner.point(lambda v: 255 - v)
    ring = Image.composite(ring, Image.new("L", size, 0), inv)
    return fill_mask(size, colour, ring)


def paper(name="paper", fill=CREAM, ink=INK, size=128, r=26, pad=10, seed=1):
    W = H = size
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    wob = 1.2 if size > 96 else 0.5
    edge = 4 if size > 96 else 3
    outer = rounded_mask(W, H, r, pad, wob, seed)
    inner = rounded_mask(W, H, r - edge, pad + edge, wob, seed)
    img.alpha_composite(shadow((W, H), outer, (0, 5 if size > 96 else 3), 5 if size > 96 else 3, 80))
    body = grain(fill_mask((W, H), fill, outer), 5, seed)
    img.alpha_composite(body)
    img.alpha_composite(border((W, H), outer, inner, ink))
    # A faint inner rule, the printed edge of good stationery.
    if size > 96:
        rule_o = rounded_mask(W, H, r - 8, pad + 9)
        rule_i = rounded_mask(W, H, r - 9, pad + 10)
        img.alpha_composite(border((W, H), rule_o, rule_i, CREAM_DARK))
    img.save(os.path.join(OUT, name + ".png"))


def wood(size=160, r=24, pad=8):
    W = H = size
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    outer = rounded_mask(W, H, r, pad, 0.8, 5)
    img.alpha_composite(shadow((W, H), outer, (0, 6), 6, 100))
    frame = Image.new("RGBA", (W, H), WOOD + (255,))
    d = ImageDraw.Draw(frame)
    rnd = random.Random(7)
    for y in range(0, H, 3):
        c = tuple(max(0, v - rnd.randint(0, 22)) for v in WOOD)
        d.line([(0, y), (W, y + rnd.randint(-1, 1))], fill=c + (255,), width=2)
    frame.putalpha(outer)
    img.alpha_composite(frame)
    inner_edge = rounded_mask(W, H, r - 4, pad + 4)
    img.alpha_composite(border((W, H), outer, inner_edge, WOOD_DARK))
    inset_o = rounded_mask(W, H, r - 12, pad + 18, 0.8, 9)
    inset_i = rounded_mask(W, H, r - 15, pad + 21, 0.8, 9)
    img.alpha_composite(grain(fill_mask((W, H), CREAM, inset_o), 4, 2))
    img.alpha_composite(border((W, H), inset_o, inset_i, INK))
    for cx, cy in ((pad + 12, pad + 12), (W - pad - 12, pad + 12), (pad + 12, H - pad - 12),
                   (W - pad - 12, H - pad - 12)):
        d2 = ImageDraw.Draw(img)
        d2.ellipse((cx - 5, cy - 5, cx + 5, cy + 5), fill=BRASS + (255,), outline=WOOD_DARK + (255,), width=2)
        d2.ellipse((cx - 2.5, cy - 3, cx, cy - 0.5), fill=(255, 240, 200, 255))
    img.save(os.path.join(OUT, "wood.png"))


def velvet(size=128, r=22, pad=8):
    W = H = size
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    outer = rounded_mask(W, H, r, pad)
    img.alpha_composite(shadow((W, H), outer, (0, 6), 6, 110))
    body = Image.new("RGBA", (W, H), PLUM + (255,))
    d = ImageDraw.Draw(body)
    for k in range(-H, W, 4):
        d.line([(k, 0), (k + H, H)], fill=(78, 46, 100, 255), width=1)
    body.putalpha(outer)
    img.alpha_composite(body)
    inner = rounded_mask(W, H, r - 3, pad + 3)
    img.alpha_composite(border((W, H), outer, inner, GOLD))
    p_o = rounded_mask(W, H, r - 7, pad + 7)
    p_i = rounded_mask(W, H, r - 8, pad + 8)
    img.alpha_composite(border((W, H), p_o, p_i, GOLD_DARK))
    img.save(os.path.join(OUT, "velvet.png"))


def button(name, fill, edge, lift, glow=None, size=(96, 64), r=22, pad=6):
    W, H = size
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    outer = rounded_mask(W, H, r, pad)
    body_mask = Image.new("L", (W, H), 0)
    body_mask.paste(outer, (0, -lift))
    # The base: the button's own depth, darker, sitting under it.
    base = fill_mask((W, H), tuple(int(v * 0.72) for v in edge), outer)
    if glow:
        g = Image.new("L", (W, H), 0)
        g.paste(outer.filter(ImageFilter.GaussianBlur(4)), (0, -lift))
        img.alpha_composite(fill_mask((W, H), glow, g.point(lambda v: v * 160 // 255)))
    img.alpha_composite(base)
    img.alpha_composite(fill_mask((W, H), fill, body_mask))
    inner = Image.new("L", (W, H), 0)
    inner.paste(rounded_mask(W, H, r - 3, pad + 3), (0, -lift))
    img.alpha_composite(border((W, H), body_mask, inner, edge))
    # A highlight band on the upper half.
    hl = Image.new("L", (W, H), 0)
    hl.paste(rounded_mask(W, H // 2, r // 2, pad + 6), (0, pad + 2 - lift))
    hl = Image.composite(hl, Image.new("L", (W, H), 0), inner).point(lambda v: v * 70 // 255)
    img.alpha_composite(fill_mask((W, H), (255, 255, 255), hl))
    img.save(os.path.join(OUT, name + ".png"))


def main():
    os.makedirs(OUT, exist_ok=True)
    paper()
    paper("paper_dark", (78, 52, 96), (36, 22, 48), seed=4)
    # The HUD's small cards and pills: the same paper at a tighter radius, so a 44 px pill
    # still has room for its corners.
    paper("card", size=64, r=14, pad=5, seed=6)
    wood()
    velvet()
    button("button", CREAM, INK, 3)
    button("button_hover", (255, 251, 238), GOLD_DARK, 4, glow=GOLD)
    button("button_pressed", CREAM_DARK, INK, 0)
    button("button_disabled", (226, 220, 210), (150, 140, 150), 2)
    button("button_primary", GOLD, GOLD_DARK, 3)
    button("button_primary_hover", (255, 214, 102), (150, 100, 20), 4, glow=(255, 236, 160))
    button("chip", CREAM, INK, 0, size=(48, 40), r=16, pad=3)
    button("tab_on", GOLD, GOLD_DARK, 2, size=(96, 56), r=18)
    button("tab_off", (236, 226, 206), (150, 130, 150), 0, size=(96, 56), r=18)
    print("UI_KIT_OK")


if __name__ == "__main__":
    main()
