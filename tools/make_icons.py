#!/usr/bin/env python3
"""THE ICON SET (P8 S5; docs/aaa-review-2026-11-08.md section 3).

One hand for every icon in the game: each icon is a short list of shapes on a 64 px grid, and
this file applies the house style to all of them alike, so no icon can drift from the set:

- a cream plate (a circle with the same outline) under every icon, so it reads on grass, on
  plum and on a wooden sign;
- each shape filled flat, with one hard shadow crescent on its lower right (the shape drawn in
  its shade colour, then again in its fill moved up and left, clipped to itself) and one small
  highlight at its upper left;
- a 3 px outline in the fill's own hue darkened, never black.

Writes game/assets/ui/icons/<name>.svg (and plate-less <name>_bare.svg). Godot imports SVG
natively; game/scenes/test/icon_sheet.gd renders the contact sheet.

  python3 tools/make_icons.py
"""
import colorsys
import math
import os
import sys

OUT = os.path.join(os.path.dirname(__file__), "..", "game", "assets", "ui", "icons")

# The 14 swatches (art bible): one hue per family.
SW = {
    "gold": "#F5C542", "leaf": "#7CC46A", "pink": "#F4A2C4", "sky": "#86CDEB",
    "violet": "#A98BE3", "red": "#E8574F", "lake": "#4C9FDB", "forest": "#4F8F4B",
    "indigo": "#4D4BA0", "wood": "#C08550", "cream": "#FFF3D6", "white": "#FFFFFF",
    "stone": "#ABA6B6", "orange": "#F2913D", "ink": "#4A3358", "rose": "#E8768F",
}
PLATE = "#FFF3D6"
STROKE = 3.0


def _rgb(hexc):
    hexc = hexc.lstrip("#")
    return tuple(int(hexc[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def _hex(rgb):
    return "#%02X%02X%02X" % tuple(max(0, min(255, round(c * 255))) for c in rgb)


def shade(hexc, v=0.78, s=1.12):
    """The shadow tone: same hue, darker, a touch richer."""
    h, ss, vv = colorsys.rgb_to_hsv(*_rgb(hexc))
    return _hex(colorsys.hsv_to_rgb(h, min(1.0, ss * s + 0.04), vv * v))


def line(hexc):
    """The outline: the fill's hue darkened about 55%, never black."""
    h, ss, vv = colorsys.rgb_to_hsv(*_rgb(hexc))
    return _hex(colorsys.hsv_to_rgb(h, min(1.0, ss * 1.1 + 0.25), vv * 0.42))


# ---- shape builders: each returns (svg path d, bbox (x0, y0, x1, y1)) ----------------------

def circle(cx, cy, r):
    d = "M%g,%g a%g,%g 0 1,0 %g,0 a%g,%g 0 1,0 %g,0 Z" % (cx - r, cy, r, r, 2 * r, r, r, -2 * r)
    return d, (cx - r, cy - r, cx + r, cy + r)


def ellipse(cx, cy, rx, ry):
    d = "M%g,%g a%g,%g 0 1,0 %g,0 a%g,%g 0 1,0 %g,0 Z" % (cx - rx, cy, rx, ry, 2 * rx, rx, ry, -2 * rx)
    return d, (cx - rx, cy - ry, cx + rx, cy + ry)


def rrect(x, y, w, h, r=3):
    r = min(r, w / 2, h / 2)
    d = ("M%g,%g h%g a%g,%g 0 0 1 %g,%g v%g a%g,%g 0 0 1 %g,%g h%g a%g,%g 0 0 1 %g,%g v%g "
         "a%g,%g 0 0 1 %g,%g Z") % (x + r, y, w - 2 * r, r, r, r, r, h - 2 * r, r, r, -r, r,
                                    -(w - 2 * r), r, r, -r, -r, -(h - 2 * r), r, r, r, -r)
    return d, (x, y, x + w, y + h)


def poly(pts):
    d = "M" + " L".join("%g,%g" % p for p in pts) + " Z"
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    return d, (min(xs), min(ys), max(xs), max(ys))


def star_pts(cx, cy, r, inner=0.45, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        rr = r if i % 2 == 0 else r * inner
        a = math.radians(rot + i * 180.0 / n)
        pts.append((round(cx + rr * math.cos(a), 2), round(cy + rr * math.sin(a), 2)))
    return pts


def star(cx, cy, r, inner=0.45, n=5, rot=-90):
    return poly(star_pts(cx, cy, r, inner, n, rot))


def path(d, bbox):
    return d, bbox


def heart(cx, cy, s):
    """A heart about 2s wide, centred on (cx, cy)."""
    d = ("M%g,%g C%g,%g %g,%g %g,%g C%g,%g %g,%g %g,%g C%g,%g %g,%g %g,%g C%g,%g %g,%g %g,%g Z" % (
        cx, cy + s * 0.95,
        cx - s * 0.2, cy + s * 0.7, cx - s, cy + s * 0.25, cx - s, cy - s * 0.25,
        cx - s, cy - s * 0.85, cx - s * 0.25, cy - s * 1.0, cx, cy - s * 0.45,
        cx + s * 0.25, cy - s * 1.0, cx + s, cy - s * 0.85, cx + s, cy - s * 0.25,
        cx + s, cy + s * 0.25, cx + s * 0.2, cy + s * 0.7, cx, cy + s * 0.95))
    return d, (cx - s, cy - s, cx + s, cy + s)


# ---- the style ---------------------------------------------------------------------------

class Icon:
    def __init__(self, name):
        self.name = name
        self.parts = []   # svg fragments, in draw order
        self.n = 0

    def fill(self, shape, color, hl=True, sh=True, offset=2.6, stroke=STROKE, outline=None):
        d, (x0, y0, x1, y1) = shape
        self.n += 1
        cid = "%s_c%d" % (self.name, self.n)
        col = SW.get(color, color)
        out = [f'<clipPath id="{cid}"><path d="{d}"/></clipPath>']
        if sh:
            out.append(f'<path d="{d}" fill="{shade(col)}"/>')
            out.append(f'<g clip-path="url(#{cid})"><path d="{d}" fill="{col}" '
                       f'transform="translate({-offset},{-offset})"/></g>')
        else:
            out.append(f'<path d="{d}" fill="{col}"/>')
        if hl and (x1 - x0) > 7 and (y1 - y0) > 7:
            w, h = x1 - x0, y1 - y0
            hx, hy = x0 + w * 0.3, y0 + h * 0.27
            rx, ry = max(1.4, w * 0.11), max(1.1, h * 0.07)
            out.append(f'<g clip-path="url(#{cid})"><ellipse cx="{hx:.1f}" cy="{hy:.1f}" '
                       f'rx="{rx:.1f}" ry="{ry:.1f}" fill="#FFFFFF" fill-opacity="0.75" '
                       f'transform="rotate(-30 {hx:.1f} {hy:.1f})"/></g>')
        if stroke:
            out.append(f'<path d="{d}" fill="none" stroke="{outline or line(col)}" '
                       f'stroke-width="{stroke}" stroke-linejoin="round"/>')
        self.parts.append("".join(out))
        return self

    def group(self, shapes, color, offset=2.6, stroke=STROKE, outline=None, hl=None):
        """Several shapes filled as ONE: a single outline round their union (each stroked
        twice as wide first, the fills then cover the inner half), one shade crescent on the
        union's lower right and one highlight at `hl` (x, y), if given. For a figure built of
        parts (a pony in stone, a bush of lobes) that must not show a seam at every join."""
        self.n += 1
        cid = "%s_g%d" % (self.name, self.n)
        col = SW.get(color, color)
        ds = [s[0] for s in shapes]
        clip = "".join(f'<path d="{d}"/>' for d in ds)
        out = [f'<clipPath id="{cid}">{clip}</clipPath>']
        if stroke:
            for d in ds:
                out.append(f'<path d="{d}" fill="none" stroke="{outline or line(col)}" '
                           f'stroke-width="{stroke * 2}" stroke-linejoin="round"/>')
        for d in ds:
            out.append(f'<path d="{d}" fill="{shade(col)}"/>')
        out.append(f'<g clip-path="url(#{cid})"><g transform="translate({-offset},{-offset})">')
        for d in ds:
            out.append(f'<path d="{d}" fill="{col}"/>')
        out.append("</g></g>")
        if hl:
            out.append(f'<g clip-path="url(#{cid})"><ellipse cx="{hl[0]}" cy="{hl[1]}" rx="3.2" '
                       f'ry="1.8" fill="#FFFFFF" fill-opacity="0.75" '
                       f'transform="rotate(-30 {hl[0]} {hl[1]})"/></g>')
        self.parts.append("".join(out))
        return self

    def flat(self, shape, color, stroke=STROKE, outline=None):
        return self.fill(shape, color, hl=False, sh=False, stroke=stroke, outline=outline)

    def stroke(self, d, color, width=STROKE, cap="round"):
        col = SW.get(color, color)
        self.parts.append(f'<path d="{d}" fill="none" stroke="{col}" stroke-width="{width}" '
                          f'stroke-linecap="{cap}" stroke-linejoin="round"/>')
        return self

    def ink(self, d, base, width=STROKE):
        """A detail line in a fill's own outline colour."""
        return self.stroke(d, line(SW.get(base, base)), width)

    def svg(self, plate=True):
        body = "".join(self.parts)
        p = ""
        if plate:
            p = (f'<circle cx="32" cy="32" r="29" fill="{PLATE}"/>'
                 f'<circle cx="32" cy="32" r="29" fill="none" stroke="{line("#E9D3A0")}" '
                 f'stroke-width="{STROKE}"/>')
        return ('<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" '
                f'viewBox="0 0 64 64">{p}{body}</svg>\n')


ICONS = {}


def icon(name):
    def wrap(fn):
        ICONS[name] = fn
        return fn
    return wrap


# ---- places and HUD ----------------------------------------------------------------------

@icon("coin")
def _coin(i):
    i.fill(circle(32, 32, 18), "gold")
    i.ink(circle(32, 32, 12.5)[0], "gold", 2)
    i.flat(star(32, 32.5, 7.5, 0.5), shade(SW["gold"], 0.85), stroke=0)


@icon("crate")
def _crate(i):
    i.fill(rrect(15, 17, 34, 31, 3), "wood")
    i.ink("M15,27.5 H49 M15,37.5 H49", "wood", 2.2)
    i.ink("M19,44 L45,21", "wood", 2.6)


@icon("house")
def _house(i):
    i.fill(rrect(18, 29, 28, 21, 2), "pink")
    i.fill(poly([(11, 31), (32, 13), (53, 31)]), "red")
    i.fill(rrect(28, 37, 9, 13, 2), "wood", hl=False)
    i.fill(rrect(39, 34, 5, 5, 1), "sky", hl=False, stroke=2)


@icon("letter")
def _letter(i):
    i.fill(rrect(12, 19, 40, 28, 3), "white")
    i.ink("M13.5,21 L32,35 L50.5,21", "white", 2.4)
    i.fill(heart(32, 34, 5.2), "red", hl=False, stroke=2)


@icon("fence")
def _fence(i):
    i.fill(rrect(12, 26, 40, 6, 2), "wood", hl=False)
    i.fill(rrect(12, 37, 40, 6, 2), "wood", hl=False)
    for x in (16, 29, 42):
        i.fill(poly([(x, 22), (x + 3, 17), (x + 6, 22), (x + 6, 50), (x, 50)]), "wood")


@icon("star")
def _star(i):
    i.fill(star(32, 33, 20, 0.48), "violet")


@icon("arrow")
def _arrow(i):
    i.fill(poly([(14, 27), (34, 27), (34, 17), (51, 32), (34, 47), (34, 37), (14, 37)]), "sky")


@icon("market")
def _market(i):
    i.fill(rrect(15, 32, 34, 17, 2), "wood")
    i.fill(rrect(12, 17, 40, 12, 3), "white", hl=False)
    for x in (12, 28):
        i.flat(rrect(x + 3, 17, 7, 12, 0), "red", stroke=0)
    i.ink(rrect(12, 17, 40, 12, 3)[0], "red", 3)
    i.fill(circle(26, 39, 4.5), "red", stroke=2)
    i.fill(circle(37, 39, 4.5), "leaf", stroke=2)


@icon("palace")
def _palace(i):
    # The Spectra Palace's games: a fan of two cards with a star.
    i.parts.append('<g transform="rotate(-14 32 36)">')
    i.fill(rrect(15, 15, 22, 31, 3), "white", hl=False, outline=line("#B9B0C8"))
    i.parts.append("</g>")
    i.parts.append('<g transform="rotate(12 32 36)">')
    i.fill(rrect(27, 15, 22, 31, 3), "white", outline=line("#B9B0C8"))
    i.fill(heart(38, 30, 6.5), "red", hl=False, stroke=2)
    i.parts.append("</g>")
    i.flat(star(18, 48, 6, 0.42, 4), "gold", stroke=1.8)


@icon("board")
def _board(i):
    i.fill(rrect(13, 15, 38, 28, 3), "wood")
    i.fill(rrect(18, 19, 13, 15, 1), "white", hl=False, stroke=2)
    i.fill(rrect(34, 20, 12, 11, 1), "sky", hl=False, stroke=2)
    i.fill(rrect(20, 43, 5, 8, 1), "wood", hl=False)
    i.fill(rrect(39, 43, 5, 8, 1), "wood", hl=False)


@icon("bag")
def _bag(i):
    i.fill(path("M14,28 Q14,22 20,22 H44 Q50,22 50,28 V44 Q50,50 44,50 H20 Q14,50 14,44 Z",
                (14, 22, 50, 50)), "wood")
    i.fill(path("M14,28 Q14,22 20,22 H44 Q50,22 50,28 V33 Q32,40 14,33 Z", (14, 22, 50, 38)),
           shade(SW["wood"], 0.9), hl=False)
    i.fill(circle(32, 35, 3.2), "gold", hl=False, stroke=2)
    i.ink("M24,22 Q24,13 32,13 Q40,13 40,22", "wood", 3)


@icon("pantry")
def _pantry(i):
    i.fill(path("M13,30 H51 L46,50 H18 Z", (13, 30, 51, 50)), "wood")
    i.fill(circle(24, 27, 6.5), "red", stroke=2.5)
    i.fill(circle(38, 26, 6.5), "leaf", stroke=2.5)
    i.fill(rrect(26, 19, 12, 9, 3), "gold", hl=False, stroke=2.5)
    i.ink("M17,39 H47", "wood", 2)


@icon("objective")
def _objective(i):
    i.fill(path("M22,12 V52", (20, 12, 24, 52)), "wood")
    i.ink("M22,12 V52", "wood", 4)
    i.fill(path("M23,14 L48,20 L23,28 Z", (23, 14, 48, 28)), "red")


@icon("hint")
def _hint(i):
    i.fill(circle(32, 28, 13), "gold")
    i.fill(rrect(26, 39, 12, 10, 3), "stone", hl=False)
    i.ink("M27,44 H37", "stone", 2)


@icon("news")
def _news(i):
    # A townspony has something new to say: a gold speech bubble with an ink "!".
    i.fill(path("M32,8 C46,8 56,17 56,28 C56,39 46,47 34,47 L26,57 L26,46 C15,44 8,37 8,28 "
                "C8,17 18,8 32,8 Z", (8, 8, 56, 57)), "gold")
    i.fill(rrect(28.5, 15, 7, 19, 3.5), "ink", hl=False, stroke=0)
    i.fill(circle(32, 40, 3.8), "ink", hl=False, stroke=0)


# ---- pony kinds ---------------------------------------------------------------------------

@icon("unicorn")
def _unicorn(i):
    i.fill(poly([(25, 51), (39, 51), (32, 11)]), "violet")
    i.ink("M27.5,42 L36.5,38 M29,33 L35.5,30 M30.5,24 L34.5,22", "violet", 2.2)
    i.flat(star(46, 19, 5, 0.42, 4), "gold", stroke=1.5)
    i.flat(star(18, 25, 3.5, 0.42, 4), "gold", stroke=1.5)


@icon("pegasus")
def _pegasus(i):
    # A wing raised up and back: a rounded arm along the top and three scalloped feather tips.
    i.fill(path("M12,40 C14,24 30,13 52,12 C53,17 50,20 46,21 C50,24 49,29 43,30 "
                "C46,34 43,39 37,39 C38,44 33,47 27,46 C21,47 15,45 12,40 Z", (12, 12, 53, 47)), "sky")
    i.ink("M17,40 C25,37 33,31 40,22", "sky", 2.2)
    i.ink("M46,21 C41,22 37,23 34,25 M43,30 C38,31 34,32 31,33 M37,39 C33,39 30,40 27,41", "sky", 2)


@icon("earth")
def _earth(i):
    i.fill(path("M17,48 V31 A15,15 0 0 1 47,31 V48 H39 V32 A7,7 0 0 0 25,32 V48 Z",
                (17, 16, 47, 48)), "stone")
    for x, y in ((21, 34), (21, 43), (43, 34), (43, 43), (26, 22), (38, 22)):
        i.flat(circle(x, y, 1.4), "ink", stroke=0)


# ---- foods ---------------------------------------------------------------------------------

@icon("hay")
def _hay(i):
    i.fill(rrect(12, 21, 40, 26, 5), "gold")
    i.ink("M17,28 L22,26 M28,33 L34,31 M40,27 L45,25 M18,40 L24,38 M38,41 L44,39", "gold", 1.8)
    i.fill(rrect(21, 20, 5, 28, 1), "wood", hl=False, stroke=2)
    i.fill(rrect(38, 20, 5, 28, 1), "wood", hl=False, stroke=2)


@icon("carrot")
def _carrot(i):
    i.fill(path("M37,20 C44,24 44,29 40,33 L19,51 C17,52 15,50 16,48 L31,24 C33,20 35,19 37,20 Z",
                (15, 19, 44, 52)), "orange")
    i.ink("M27,35 L31,38 M23,42 L26,44 M33,28 L37,31", "orange", 2)
    i.fill(path("M38,22 C38,14 41,10 44,10 C44,15 42,19 40,22 Z", (38, 10, 44, 22)), "leaf",
           hl=False, stroke=2.2)
    i.fill(path("M40,23 C45,17 50,16 53,18 C50,22 46,24 41,25 Z", (40, 16, 53, 25)), "leaf",
           hl=False, stroke=2.2)


@icon("apple")
def _apple(i):
    i.fill(path("M32,22 C38,16 50,18 50,32 C50,44 41,52 35,49 C33,48 31,48 29,49 "
                "C23,52 14,44 14,32 C14,18 26,16 32,22 Z", (14, 16, 50, 52)), "red")
    i.ink("M32,22 C32,17 33,14 35,12", "wood", 3)
    i.fill(path("M34,17 C37,11 44,10 46,12 C44,17 38,19 34,17 Z", (34, 10, 46, 19)), "leaf",
           hl=False, stroke=2)


@icon("daisy")
def _daisy(i):
    for k in range(8):
        a = k * 45
        i.parts.append(f'<g transform="rotate({a} 32 32)">')
        i.fill(ellipse(32, 19, 5, 9.5), "white", hl=False, stroke=2.2, outline=line("#C9C3B8"))
        i.parts.append("</g>")
    i.fill(circle(32, 32, 7.5), "gold", stroke=2.2)


@icon("daffodil")
def _daffodil(i):
    for k in range(6):
        i.parts.append(f'<g transform="rotate({k * 60} 32 32)">')
        i.fill(ellipse(32, 19, 6.5, 11), "gold", hl=False, stroke=2.2)
        i.parts.append("</g>")
    i.fill(circle(32, 32, 8.5), "orange", stroke=2.2)
    i.ink(circle(32, 32, 4.5)[0], "orange", 1.8)


# ---- the Market's pictures of the foods --------------------------------------------------
# Fable AAA round 2, #8: on a Market tile the food icons above read as placeholders (a gold
# box for hay, one flower for a posy). A tile shows its picture at 100 px and more, where an
# icon built to read at 24 px looks bare, so the Market draws these instead: the same style,
# more of the thing (a bale in three quarter view, a bunch of carrots, a posy with a bow).
# The small icons stay as they are for chips and markers.

def _vcarrot(cx, top, ln, w):
    d = ("M%g,%g C%g,%g %g,%g %g,%g C%g,%g %g,%g %g,%g C%g,%g %g,%g %g,%g Z" % (
        cx - w, top, cx - w, top + ln * 0.5, cx - 1.2, top + ln * 0.92, cx, top + ln,
        cx + 1.2, top + ln * 0.92, cx + w, top + ln * 0.5, cx + w, top,
        cx + w, top - 3.5, cx - w, top - 3.5, cx - w, top))
    return d, (cx - w, top - 3, cx + w, top + ln)


@icon("hay_art")
def _hay_art(i):
    # A bale in three quarter view: lit top, front, shaded side, straw drawn in short strokes,
    # two thin twine bands and loose straws, so it reads as hay and not as a crate.
    i.stroke("M13,24 L7,16 M17,21 L14,11 M21,19 L22,10 M50,19 L57,12 M53,24 L61,22", "#D9AE3E", 2.2)
    i.fill(path("M10,28 C14,23 18,20 23,17 L55,17 C51,21 47,24 43,28 Z", (10, 17, 55, 28)),
           "#FBE38E", hl=False, sh=False)
    i.fill(path("M43,28 L55,17 C56,25 56,33 55,40 L43,52 C44,44 44,36 43,28 Z", (43, 17, 56, 52)),
           shade("#F5CF55", 0.82), hl=False, sh=False)
    i.fill(rrect(9, 28, 34, 24, 6), "#F5CF55")
    straw = shade("#F5CF55", 0.62)
    i.stroke("M13,33 L19,32 M23,36 L30,35 M33,31 L39,30 M12,40 L17,39 M26,43 L33,42 "
             "M35,39 L40,38 M14,47 L21,46 M31,48 L38,47 M20,30 L24,29", straw, 1.5)
    i.stroke("M22,22 L29,20 M35,23 L42,21 M44,20 L50,19 M28,25 L33,24", straw, 1.4)
    i.stroke("M47,30 L51,27 M46,38 L52,33 M47,46 L52,41", shade(straw, 0.85), 1.4)
    twine = "#9A5B2A"
    for x in (18, 33):
        i.stroke("M%g,52 L%g,28 L%g,17" % (x, x, x + 12), twine, 2.6)
    i.stroke("M43,%g L55,%g" % (31, 20), twine, 2.4)
    i.stroke("M43,%g L55,%g" % (45, 34), twine, 2.4)
    i.stroke("M11,52 L7,58 M24,52 L22,59 M37,52 L40,58", "#D9AE3E", 2)


@icon("carrot_art")
def _carrot_art(i):
    # A bunch of three, tops gathered, leaves fanned over them.
    for a in (-48, 48, -22, 22, 0):
        i.parts.append(f'<g transform="rotate({a} 32 18)">')
        i.fill(ellipse(32, 9, 4.2, 10), "leaf", hl=False, stroke=2)
        i.parts.append("</g>")
    for a, ln in ((-30, 36), (30, 36), (0, 41)):
        i.parts.append(f'<g transform="rotate({a} 32 17)">')
        i.fill(_vcarrot(32, 19, ln, 6.2), "orange")
        i.ink("M27.5,28 L31,29.5 M33,35 L36.5,34 M28.5,42 L31.5,43", "orange", 1.8)
        i.parts.append("</g>")
    i.flat(rrect(26, 15, 12, 6, 3), "red", stroke=2)


@icon("apple_art")
def _apple_art(i):
    # Two apples, the back one a shade deeper, a leaf on the front one's stalk.
    i.fill(path("M40,16 C45,11 55,13 55,25 C55,35 48,41 43,39 C41,38 40,38 38,39 "
                "C33,41 26,35 26,25 C26,13 35,11 40,16 Z", (26, 11, 55, 41)), "#C93A3A")
    i.ink("M40,16 C40,12 41,10 42,8", "wood", 2.6)
    i.fill(path("M30,24 C37,17 51,19 51,36 C51,50 40,59 33,56 C31,55 29,55 27,56 "
                "C20,59 9,50 9,36 C9,19 23,17 30,24 Z", (9, 17, 51, 59)), "red")
    i.ink("M30,24 C30,18 31,14 34,11", "wood", 3)
    i.fill(path("M33,16 C37,8 46,7 49,10 C46,16 39,19 33,16 Z", (33, 7, 49, 19)), "leaf",
           hl=False, stroke=2)
    i.ink("M35,15 C39,13 43,11 46,10", "leaf", 1.4)


def _small_daisy(i, cx, cy, r, centre="gold"):
    for k in range(8):
        i.parts.append(f'<g transform="rotate({k * 45} {cx} {cy})">')
        i.fill(ellipse(cx, cy - r * 0.62, r * 0.27, r * 0.5), "white", hl=False, stroke=1.8,
               outline=line("#C9C3B8"))
        i.parts.append("</g>")
    i.fill(circle(cx, cy, r * 0.36), centre, stroke=1.8)


@icon("daisy_art")
def _daisy_art(i):
    # A posy: three daisies on stems, tied with a pink bow.
    i.stroke("M20,22 C24,34 29,44 31,56 M44,20 C40,34 34,44 32,56 M32,36 L32,56", "forest", 3)
    i.fill(ellipse(24, 44, 5, 2.4), "leaf", hl=False, stroke=1.6)
    i.fill(ellipse(41, 46, 5, 2.4), "leaf", hl=False, stroke=1.6)
    _small_daisy(i, 19, 20, 13)
    _small_daisy(i, 45, 18, 13)
    _small_daisy(i, 32, 33, 14)
    i.fill(path("M32,50 C26,44 20,47 22,52 C24,56 29,53 32,50 Z", (20, 44, 32, 56)), "pink",
           hl=False, stroke=1.8)
    i.fill(path("M32,50 C38,44 44,47 42,52 C40,56 35,53 32,50 Z", (32, 44, 44, 56)), "pink",
           hl=False, stroke=1.8)
    i.fill(circle(32, 50, 2.6), "rose", hl=False, stroke=1.6)
    i.stroke("M31,52 L27,60 M33,52 L37,60", "rose", 2.2)


@icon("daffodil_art")
def _daffodil_art(i):
    # One daffodil in three quarter view: six petals, the trumpet with its frilled rim, a stem
    # and two long leaves.
    i.stroke("M33,38 C34,46 33,52 31,60", "forest", 3.4)
    i.fill(path("M31,60 C24,52 20,44 21,36 C26,42 29,50 31,60 Z", (20, 36, 31, 60)), "leaf",
           hl=False, stroke=2)
    i.fill(path("M33,60 C40,54 46,48 48,40 C42,44 37,50 33,60 Z", (33, 40, 48, 60)), "leaf",
           hl=False, stroke=2)
    for k in range(6):
        i.parts.append(f'<g transform="rotate({k * 60 + 30} 32 26)">')
        i.fill(ellipse(32, 15, 6, 10), "gold", hl=False, stroke=2)
        i.parts.append("</g>")
    i.fill(circle(32, 26, 9.5), "orange", stroke=2)
    frill = " ".join("L%.1f,%.1f" % (32 + (9.5 if k % 2 else 11.2) * math.cos(math.radians(k * 20)),
                                     26 + (9.5 if k % 2 else 11.2) * math.sin(math.radians(k * 20)))
                     for k in range(1, 18))
    i.ink("M43.2,26 " + frill + " Z", "orange", 1.8)
    i.fill(circle(32, 26, 5), shade(SW["orange"], 0.75), hl=False, sh=False, stroke=1.6)


# ---- quirks ------------------------------------------------------------------------------

@icon("glutton")
def _glutton(i):
    i.fill(path("M12,33 H52 C52,44 43,51 32,51 C21,51 12,44 12,33 Z", (12, 33, 52, 51)), "sky")
    i.fill(circle(23, 29, 6), "red", stroke=2.2)
    i.fill(circle(33, 26, 7), "orange", stroke=2.2)
    i.fill(circle(42, 29, 6), "leaf", stroke=2.2)
    i.fill(rrect(12, 31, 40, 5, 2), "sky", hl=False)


@icon("night_owl")
def _night_owl(i):
    i.fill(path("M38,12 A20,20 0 1 0 52,40 A15,15 0 1 1 38,12 Z", (12, 12, 52, 52)), "indigo")
    i.flat(star(44, 20, 4.5, 0.42, 4), "gold", stroke=1.5)
    i.flat(star(48, 31, 2.8, 0.42, 4), "gold", stroke=1.2)


@icon("social")
def _social(i):
    i.fill(heart(25, 32, 10), "pink")
    i.fill(heart(40, 30, 10), "rose")


@icon("loner")
def _loner(i):
    i.fill(rrect(29, 34, 6, 16, 2), "wood", hl=False)
    i.fill(circle(32, 26, 14), "forest")
    i.flat(path("M12,50 H52", (12, 49, 52, 51)), "leaf", stroke=0)
    i.ink("M12,50 H52", "leaf", 3)


@icon("sparkler")
def _sparkler(i):
    i.fill(star(28, 34, 16, 0.3, 4), "gold")
    i.fill(star(45, 19, 8, 0.32, 4), "pink", hl=False, stroke=2.2)
    i.fill(star(46, 45, 5, 0.34, 4), "sky", hl=False, stroke=2)


@icon("skittish")
def _skittish(i):
    i.fill(star(32, 32, 21, 0.68, 10), "orange", hl=False)
    i.fill(rrect(29, 18, 6, 17, 3), "white", hl=False, stroke=2.2)
    i.fill(circle(32, 42, 3.4), "white", hl=False, stroke=2.2)


@icon("escapee")
def _escapee(i):
    # Over the fence: two rails and posts, and a hop arrow arcing over them.
    i.fill(rrect(12, 38, 40, 5, 2), "wood", hl=False, stroke=2.4)
    i.fill(rrect(12, 46, 40, 5, 2), "wood", hl=False, stroke=2.4)
    for x in (16, 43):
        i.fill(rrect(x, 33, 5, 21, 1.5), "wood", hl=False, stroke=2.4)
    i.ink("M14,32 C18,12 40,10 47,24", "leaf", 3.4)
    i.fill(poly([(42, 24), (52, 20), (50, 31)]), "leaf", hl=False, stroke=2.4)


@icon("sleepy")
def _sleepy(i):
    i.fill(path("M14,24 H30 V29 L21,40 H30 V46 H14 V41 L23,30 H14 Z", (14, 24, 30, 46)), "sky",
           hl=False)
    i.fill(path("M35,16 H50 V21 L42,30 H50 V35 H35 V30 L43,21 H35 Z", (35, 16, 50, 35)), "lake",
           hl=False, stroke=2.4)


@icon("showoff")
def _showoff(i):
    i.fill(poly([(22, 34), (17, 52), (24, 48), (28, 54), (32, 38)]), "red", hl=False, stroke=2.4)
    i.fill(poly([(42, 34), (47, 52), (40, 48), (36, 54), (32, 38)]), "lake", hl=False, stroke=2.4)
    i.fill(circle(32, 27, 14), "gold")
    i.flat(star(32, 27.5, 8, 0.48), shade(SW["gold"], 0.85), stroke=0)


# ---- rarity ------------------------------------------------------------------------------

@icon("rarity_common")
def _common(i):
    i.fill(circle(32, 32, 14), "stone")


@icon("rarity_uncommon")
def _uncommon(i):
    i.fill(poly([(32, 13), (49, 32), (32, 51), (15, 32)]), "leaf")


@icon("rarity_rare")
def _rare(i):
    i.fill(star(32, 33, 19, 0.46), "lake")


@icon("rarity_legendary")
def _legendary(i):
    i.fill(poly([(13, 22), (23, 31), (32, 15), (41, 31), (51, 22), (47, 47), (17, 47)]), "gold")
    for x in (22, 32, 42):
        i.flat(circle(x, 41, 2.6), "red", stroke=1.5)


# ---- events and time ----------------------------------------------------------------------

@icon("sun")
def _sun(i):
    i.fill(star(32, 32, 23, 0.72, 12), "orange", hl=False)
    i.fill(circle(32, 32, 13), "gold")


@icon("moon")
def _moon(i):
    i.fill(path("M38,12 A20,20 0 1 0 52,40 A15,15 0 1 1 38,12 Z", (12, 12, 52, 52)), "indigo")


@icon("rain")
def _rain(i):
    i.fill(path("M17,36 A8,8 0 0 1 19,20 A11,11 0 0 1 40,17 A9,9 0 0 1 49,34 Q49,36 46,36 Z",
                (11, 11, 51, 36)), "stone")
    i.ink("M22,42 L20,48 M32,42 L30,48 M42,42 L40,48", "lake", 3)


@icon("bloom")
def _bloom(i):
    i.fill(rrect(30, 34, 4, 17, 2), "leaf", hl=False, stroke=2)
    i.fill(path("M36,46 C42,40 48,40 50,42 C46,47 41,48 36,46 Z", (36, 40, 50, 48)), "leaf",
           hl=False, stroke=2)
    i.fill(path("M18,22 L25,28 L32,16 L39,28 L46,22 C47,34 41,40 32,40 C23,40 17,34 18,22 Z",
                (17, 16, 47, 40)), "pink")
    i.flat(star(48, 14, 4.5, 0.4, 4), "gold", stroke=1.5)
    i.flat(star(15, 13, 3.2, 0.4, 4), "gold", stroke=1.2)


@icon("catch")
def _catch(i):
    i.fill(path("M13,46 C20,30 30,22 46,16 L50,20 C38,28 30,36 18,50 Z", (13, 16, 50, 50)),
           "violet", hl=False)
    i.fill(star(44, 21, 10, 0.4, 4), "gold")
    i.flat(star(22, 22, 4, 0.4, 4), "pink", stroke=1.5)


@icon("full")
def _full(i):
    _fence(i)
    i.fill(circle(46, 18, 9), "red", hl=False, stroke=2.4)
    i.stroke("M42,18 H50", "white", 3)


@icon("sold")
def _sold(i):
    i.fill(circle(26, 36, 14), "gold")
    i.flat(star(26, 36.5, 6.5, 0.5), shade(SW["gold"], 0.85), stroke=0)
    i.fill(poly([(38, 12), (52, 12), (52, 26), (47, 21), (40, 28), (36, 24), (43, 17)]), "leaf",
           hl=False, stroke=2.4)


@icon("sighting")
def _sighting(i):
    i.fill(path("M10,32 C18,19 46,19 54,32 C46,45 18,45 10,32 Z", (10, 22, 54, 42)), "white")
    i.fill(circle(32, 32, 9), "lake")
    i.fill(circle(32, 32, 4.2), "ink", hl=False, stroke=0)
    i.flat(circle(29, 29, 2), "white", stroke=0)


@icon("lake_open")
def _lake_open(i):
    i.fill(ellipse(32, 38, 21, 11), "lake")
    i.ink("M20,38 Q24,35 28,38 M36,41 Q40,38 44,41", "lake", 2)
    i.fill(rrect(24, 14, 16, 14, 4), "gold", hl=False)
    i.ink("M27,14 V10 Q32,6 37,10", "gold", 3)


# ---- gear and shop -------------------------------------------------------------------------

@icon("bigger_saddlebag")
def _bigbag(i):
    _bag(i)
    i.fill(circle(47, 17, 8), "leaf", hl=False, stroke=2.2)
    i.stroke("M43,17 H51 M47,13 V21", "white", 2.8)


@icon("calm_lamp")
def _lamp(i):
    i.fill(rrect(20, 20, 24, 26, 5), "gold")
    i.fill(rrect(25, 24, 14, 18, 3), "cream", hl=False, stroke=2, outline=line(SW["gold"]))
    i.fill(circle(32, 34, 3.6), "orange", hl=False, stroke=0)
    i.fill(rrect(18, 45, 28, 6, 2), "wood", hl=False)
    i.ink("M26,20 Q32,10 38,20", "wood", 3)


@icon("depot_cart")
def _cart(i):
    i.fill(path("M12,22 H52 L48,40 H16 Z", (12, 22, 52, 40)), "wood")
    i.fill(circle(22, 44, 6.5), "stone")
    i.fill(circle(42, 44, 6.5), "stone")
    i.flat(circle(22, 44, 2), "ink", stroke=0)
    i.flat(circle(42, 44, 2), "ink", stroke=0)


@icon("express_chute")
def _chute(i):
    i.fill(path("M14,14 H34 L46,40 V52 H36 V44 L26,24 H14 Z", (14, 14, 46, 52)), "stone")
    i.fill(poly([(43, 12), (54, 12), (54, 23)]), "leaf", hl=False, stroke=2.2)


@icon("gallop_shoes")
def _gallop(i):
    i.ink("M8,22 H17 M6,30 H15 M8,38 H17", "sky", 3)
    _earth_shoe(i, 6)


def _earth_shoe(i, dx):
    i.fill(path("M%g,48 V31 A15,15 0 0 1 %g,31 V48 H%g V32 A7,7 0 0 0 %g,32 V48 Z" % (
        17 + dx, 47 + dx, 39 + dx, 25 + dx), (17 + dx, 16, 47 + dx, 48)), "gold")


@icon("long_beam")
def _beam(i):
    # A unicorn's horn (Fable AAA round 6: the old one read as a stick) throwing a long beam of
    # violet magic, with a gold reach arrow along it: "your magic reaches further".
    i.stroke("M22,42 L55,9", "#C9B5F5", 11)
    i.stroke("M22,42 L55,9", "violet", 6.5)
    i.stroke("M22,42 L55,9", "#FFFFFF", 2.4)
    i.fill(star(55, 9, 8, 0.36, 4), "white", hl=False, stroke=2, outline=line(SW["violet"]))
    i.flat(star(47, 23, 3.4, 0.3, 4), "white", stroke=1.2, outline=line(SW["violet"]))
    i.fill(poly([(4, 51), (13, 60), (27, 37)]), "pink")
    i.ink("M8.5,49 L14,54.5 M13.5,44.5 L18.6,49.2 M18.5,40 L22.6,43.6", "pink", 1.8)
    i.stroke("M36,48 L54,30", line(SW["gold"]), 5)
    i.stroke("M36,48 L54,30", "gold", 2.6)
    i.fill(poly([(57, 27), (49.5, 29.5), (54.5, 34.5)]), "gold", hl=False, sh=False, stroke=1.8)


@icon("lure_post")
def _lure(i):
    i.fill(rrect(18, 12, 6, 40, 2), "wood", hl=False)
    i.fill(rrect(18, 12, 26, 6, 2), "wood", hl=False)
    i.ink("M40,18 V26", "wood", 2)
    i.fill(circle(40, 33, 7.5), "red", stroke=2.4)


@icon("pony_whistle")
def _whistle(i):
    i.fill(path("M14,26 H38 A11,11 0 1 1 27,37 V34 H14 Z", (14, 26, 49, 48)), "stone")
    i.fill(rrect(12, 24, 6, 12, 2), "stone", hl=False)
    i.ink("M44,16 Q48,12 52,16 M48,8 Q54,4 58,10", "sky", 2.4)


@icon("scoop_launcher")
def _scoop(i):
    i.fill(path("M12,40 C12,24 30,16 50,22 L48,32 C34,28 22,32 22,42 Z", (12, 18, 50, 42)),
           "violet")
    i.fill(circle(18, 44, 7), "stone")
    i.fill(star(51, 17, 6, 0.42, 4), "gold", hl=False, stroke=1.8)


@icon("steward_monocle")
def _monocle(i):
    i.fill(circle(28, 28, 15), "gold", hl=False)
    i.fill(circle(28, 28, 10.5), "sky")
    i.ink("M38,39 Q44,46 40,53", "gold", 2.4)


@icon("yield_lens")
def _lens(i):
    i.fill(rrect(36, 37, 8, 20, 3), "wood", hl=False)
    i.parts.append('<g transform="rotate(-45 40 47)"></g>')
    i.fill(circle(28, 28, 15), "stone", hl=False)
    i.fill(circle(28, 28, 10.5), "sky")
    i.fill(poly([(28, 22), (33, 28), (28, 34), (23, 28)]), "pink", hl=False, stroke=2)


@icon("pen_small")
def _pen_s(i):
    _fence(i)


@icon("pen_large")
def _pen_l(i):
    _fence(i)
    i.fill(circle(47, 47, 8), "leaf", hl=False, stroke=2.2)
    i.stroke("M43,47 H51 M47,43 V51", "white", 2.8)


@icon("pen_grand")
def _pen_g(i):
    _fence(i)
    i.fill(star(47, 46, 10, 0.46), "gold", hl=False, stroke=2.2)


@icon("upgrade")
def _upgrade(i):
    i.fill(poly([(32, 11), (51, 32), (40, 32), (40, 52), (24, 52), (24, 32), (13, 32)]), "leaf")


@icon("clear")
def _clear(i):
    i.fill(rrect(28, 10, 7, 28, 2), "wood", hl=False)
    i.fill(path("M21,36 H43 L49,54 H15 Z", (15, 36, 49, 54)), "gold")
    i.ink("M24,40 L21,53 M32,40 V53 M40,40 L43,53", "gold", 2)


@icon("sell_all")
def _sell_all(i):
    for y in (44, 36, 28):
        i.fill(ellipse(30, y, 15, 6), "gold", hl=(y == 28))
    i.fill(poly([(40, 12), (54, 12), (54, 26), (49, 21), (42, 28), (38, 24), (45, 17)]), "leaf",
           hl=False, stroke=2.4)


# ---- the decorations (Fable AAA round 6, #1) -----------------------------------------------
# The Market's decor tiles were baked 3D cut-outs (game/scenes/test/decor_icons.gd) and read as
# a second set beside the drawn foods and gear: a green blob, a beige blob, grey silhouettes.
# Each is drawn here in the foods' "_art" hand instead: three quarter view (lit top, front,
# shaded right side), the set's outline and shade crescent, more of the thing.

def _lit(hexc, k=0.35):
    r, g, b = _rgb(hexc)
    return _hex((r + (1 - r) * k, g + (1 - g) * k, b + (1 - b) * k))


def _box(i, x, y, w, h, dx, dy, col, top=None, side=None, hl=True):
    """A box in three quarter view: front face x..x+w, y..y+h; its top and right side run
    back (dx, -dy). Top lit, side in shade."""
    c = SW.get(col, col)
    i.fill(poly([(x + w, y), (x + w + dx, y - dy), (x + w + dx, y + h - dy), (x + w, y + h)]),
           side or shade(c, 0.8), hl=False, sh=False)
    i.fill(poly([(x, y), (x + dx, y - dy), (x + w + dx, y - dy), (x + w, y)]),
           top or _lit(c), hl=False, sh=False)
    i.fill(rrect(x, y, w, h, 1.5), col, hl=hl)


def _blossom(i, cx, cy, r, col, centre="gold"):
    for k in range(5):
        a = math.radians(k * 72 - 90)
        i.flat(circle(cx + r * 0.62 * math.cos(a), cy + r * 0.62 * math.sin(a), r * 0.5), col,
               stroke=1.4)
    i.flat(circle(cx, cy, r * 0.36), centre, stroke=1.2)


@icon("decor_flower_bushes")
def _d_bushes(i):
    i.flat(ellipse(32, 53, 25, 5), shade(SW["forest"], 0.9), stroke=0)
    i.group([circle(17, 40, 11), circle(30, 29, 14), circle(45, 33, 12), circle(52, 44, 8),
             rrect(8, 38, 50, 15, 6)], "#6DBB5C", hl=(24, 22))
    i.ink("M15,44 C18,41 21,41 23,43 M33,36 C36,33 40,33 42,35 M44,46 C47,43 50,43 52,45 "
          "M24,30 C26,27 29,27 31,28", "#6DBB5C", 1.8)
    for x, y, c in ((19, 34, "pink"), (34, 22, "rose"), (45, 30, "pink"), (28, 42, "white"),
                    (50, 41, "rose"), (12, 44, "white"), (38, 40, "pink")):
        _blossom(i, x, y, 5.2, c, "gold")


def _bale(i, x, y, w, h, d):
    hay = "#F5CF55"
    _box(i, x, y, w, h, d, d * 0.75, hay, top="#FBE38E", side=shade(hay, 0.8))
    straw = shade(hay, 0.62)
    i.stroke("M%g,%g l5,-1 M%g,%g l6,-1 M%g,%g l5,-1 M%g,%g l5,-1" % (
        x + 3, y + 5, x + w * 0.45, y + h * 0.4, x + 4, y + h * 0.7, x + w * 0.55, y + h * 0.82),
        straw, 1.3)
    twine = "#9A5B2A"
    for t in (0.3, 0.7):
        bx = x + w * t
        i.stroke("M%g,%g L%g,%g L%g,%g" % (bx, y + h, bx, y, bx + d, y - d * 0.75), twine, 2.2)


@icon("decor_hay_bales")
def _d_hay(i):
    i.stroke("M6,52 L2,57 M58,46 L62,50 M30,22 L27,15 M42,20 L46,13", "#D9AE3E", 2)
    _bale(i, 4, 38, 26, 15, 8)
    _bale(i, 30, 38, 22, 15, 8)
    _bale(i, 15, 23, 26, 15, 8)
    i.stroke("M10,53 L8,59 M24,53 L26,59 M40,53 L39,59", "#D9AE3E", 1.8)


@icon("decor_picnic_table")
def _d_picnic(i):
    wood = "#DDA062"
    # the far bench, peeking over the top
    i.fill(poly([(12, 24), (38, 15), (41, 17), (15, 26)]), wood, hl=False, sh=False, stroke=2.4)
    # A-frame legs
    for a, b in (((14, 36), (9, 54)), ((20, 38), (24, 56)), ((46, 28), (42, 47)),
                 ((52, 27), (56, 45))):
        i.ink("M%g,%g L%g,%g" % (a + b), wood, 4.6)
        i.stroke("M%g,%g L%g,%g" % (a + b), shade(wood, 0.8), 2.2)
    # the top, its front edges thick
    i.fill(poly([(4, 31), (26, 40), (26, 44), (4, 35)]), shade(wood, 0.8), hl=False, sh=False)
    i.fill(poly([(26, 40), (58, 27), (58, 31), (26, 44)]), shade(wood, 0.66), hl=False, sh=False)
    i.fill(poly([(4, 31), (36, 18), (58, 27), (26, 40)]), wood, hl=False)
    i.ink("M11.3,34 L43.3,21 M18.7,37 L50.7,24", wood, 1.4)
    # a gingham cloth and a basket
    i.fill(poly([(16, 30), (34, 23), (44, 27.5), (26, 35)]), "red", hl=False, sh=False, stroke=2)
    i.stroke("M21,28 L31,32.5 M27,25.5 L37,30 M20.5,32 L38.5,24.6", "#FFFFFF", 1.4)
    i.fill(path("M27,22 H39 L37,29 H29 Z", (27, 22, 39, 29)), "wood", hl=False, stroke=2)
    i.ink("M29,22 Q33,15 37,22", "wood", 2)
    i.fill(circle(31, 21, 2.4), "red", hl=False, stroke=1.4)
    # the near bench
    i.fill(poly([(14, 47), (48, 34), (48, 37), (14, 50)]), shade(wood, 0.72), hl=False, sh=False,
           stroke=2.2)
    i.fill(poly([(10, 45), (44, 32), (48, 34), (14, 47)]), wood, hl=False, sh=False, stroke=2.2)
    i.ink("M17,50 L17,57 M45,37 L45,44", wood, 3)


@icon("decor_wagon")
def _d_wagon(i):
    wood = "#C08550"
    i.ink("M8,40 L1,47", "wood", 3)
    i.fill(circle(51, 41, 7), "wood", hl=False)
    # the bed: hay heaped over the open top
    i.fill(poly([(8, 27), (18, 19), (57, 19), (47, 27)]), shade(wood, 0.55), hl=False, sh=False)
    i.group([circle(18, 22, 6), circle(28, 18, 7), circle(39, 19, 7), circle(48, 18, 5.5)],
            "#F5CF55", stroke=2.4, hl=(26, 14))
    i.stroke("M22,18 l4,-1 M35,16 l4,-1 M44,17 l3,-1", shade("#F5CF55", 0.62), 1.3)
    _box(i, 8, 27, 39, 14, 10, 8, wood)
    i.ink("M8,33.5 H47 M18,27 V41 M37,27 V41", wood, 1.6)
    for cx in (17, 39):
        i.fill(circle(cx, 44, 9), "#8C5A33", hl=False)
        i.flat(circle(cx, 44, 6), _lit("#8C5A33", 0.25), stroke=0)
        for k in range(6):
            a = math.radians(k * 60 + 15)
            i.stroke("M%g,%g L%g,%g" % (cx, 44, cx + 6 * math.cos(a), 44 + 6 * math.sin(a)),
                     line("#8C5A33"), 1.6)
        i.fill(circle(cx, 44, 2.4), "gold", hl=False, stroke=1.4)


@icon("decor_well")
def _d_well(i):
    stone = "#B8B1C6"
    # posts and the crank
    i.fill(rrect(13, 14, 5, 30, 1.5), "wood", hl=False)
    i.fill(rrect(46, 14, 5, 30, 1.5), "wood", hl=False)
    i.ink("M17,22 H47", "wood", 3.2)
    i.stroke("M51,22 H56 V27", "#8C8597", 2.4)
    i.stroke("M32,22 V31", "#9A5B2A", 1.6)
    # the roof, two slopes
    i.fill(poly([(4, 19), (32, 3), (32, 9), (9, 22)]), "red", hl=False, sh=False)
    i.fill(poly([(32, 3), (60, 19), (55, 22), (32, 9)]), shade(SW["red"], 0.75), hl=False, sh=False)
    i.ink("M11,15 L32,4 M18,12 L23,15 M40,8 L45,11 M49,13 L53,16", "red", 1.4)
    # the round wall: rim, water, stone body with courses
    i.fill(path("M12,38 V51 A20,6 0 0 0 52,51 V38 Z", (12, 38, 52, 57)), stone)
    i.ink("M12,44.5 A20,6 0 0 0 52,44.5 M20,39 V45 M33,44.5 V51 M44,39 V45 M24,50 V56 M42,50 V55",
          stone, 1.5)
    i.fill(ellipse(32, 38, 20, 6), _lit(stone, 0.3), hl=False, sh=False)
    i.flat(ellipse(32, 38, 15, 3.8), "lake", stroke=1.6)
    i.flat(ellipse(28, 37.4, 4, 1), "#BFE6FF", stroke=0)
    i.fill(path("M28,30 H36 L35,35 H29 Z", (28, 30, 36, 35)), "wood", hl=False, stroke=1.8)


@icon("decor_tetherball")
def _d_tether(i):
    i.fill(ellipse(26, 54, 12, 4), "stone", hl=False)
    i.fill(rrect(23, 8, 6, 46, 2.5), "white", outline=line("#C9C3B8"))
    for y in (12, 22, 32, 42):
        i.flat(poly([(23, y + 4), (29, y), (29, y + 4), (23, y + 8)]), "red", stroke=0)
    i.ink(rrect(23, 8, 6, 46, 2.5)[0], "#C9C3B8", 2.4)
    i.fill(circle(26, 8, 3.4), "gold", hl=False, stroke=1.8)
    i.stroke("M27,10 Q38,14 41,24", "#7B6A5A", 1.8)
    i.fill(circle(44, 32, 10), "gold")
    i.ink("M35,30 C39,34 47,36 53,33 M42,22.5 C40,28 41,36 46,41.6", "gold", 1.8)
    i.stroke("M52,22 L56,19 M55,27 L60,26", "sky", 2.2)


@icon("decor_garden_arch")
def _d_arch(i):
    arch = "M10,57 V30 A22,22 0 0 1 54,30 V57 H48 V30 A16,16 0 0 0 16,30 V57 Z"
    i.parts.append('<g transform="translate(5,-4)">')
    i.fill(path(arch, (10, 8, 54, 57)), "#C9C3D3", hl=False, sh=False)
    i.parts.append("</g>")
    i.fill(path(arch, (10, 8, 54, 57)), "white", outline=line("#B9B0C8"))
    i.ink("M10,36 H16 M10,44 H16 M10,52 H16 M48,36 H54 M48,44 H54 M48,52 H54 "
          "M13,22 L18,25 M22,12 L25,17 M32,8 V14 M42,12 L39,17 M51,22 L46,25", "#B9B0C8", 1.4)
    i.stroke("M13,57 C10,48 18,44 13,36 C9,28 16,22 18,16 C22,9 30,8 34,9 C42,10 46,14 49,20 "
             "C53,27 47,33 51,40 C55,47 48,51 51,57", "forest", 2.6)
    for x, y, a in ((12, 47, 30), (16, 30, -30), (24, 11, 20), (42, 11, -20), (51, 31, 30),
                    (50, 48, -30), (14, 40, 10), (52, 40, -10)):
        i.parts.append(f'<g transform="rotate({a} {x} {y})">')
        i.fill(ellipse(x, y, 3.6, 2), "leaf", hl=False, sh=False, stroke=1.4)
        i.parts.append("</g>")
    for x, y in ((14, 24), (33, 9), (50, 25), (51, 44), (13, 52), (27, 10)):
        i.fill(circle(x, y, 3.8), "rose", hl=False, stroke=1.6)
        i.stroke("M%g,%g a1.8,1.8 0 1,1 1.6,1.6" % (x - 1, y - 0.6), line(SW["rose"]), 1.2)


@icon("decor_apple_tree")
def _d_tree(i):
    i.flat(ellipse(32, 56, 18, 3.5), shade(SW["forest"], 0.9), stroke=0)
    i.fill(path("M27,56 C29,48 29,40 28,34 L36,34 C35,40 35,48 37,56 C34,55 30,55 27,56 Z",
                (27, 34, 37, 56)), "wood", hl=False)
    i.ink("M32,42 L37,37 M31,48 L28,45", "wood", 1.6)
    i.group([circle(19, 27, 12), circle(45, 27, 12), circle(32, 15, 13), circle(32, 32, 13),
             circle(24, 19, 10), circle(41, 19, 10)], "#6DBB5C", hl=(24, 11))
    i.ink("M17,30 C20,27 24,27 26,29 M37,25 C40,22 44,22 46,24 M28,15 C31,12 35,12 37,14",
          "#6DBB5C", 1.7)
    for x, y in ((17, 22), (29, 24), (42, 15), (47, 31), (35, 35), (22, 34), (34, 8)):
        i.fill(circle(x, y, 3.4), "red", hl=False, stroke=1.6)
        i.flat(circle(x - 1, y - 1.2, 0.9), "#FFFFFF", stroke=0)


@icon("decor_lemonade_stand")
def _d_lemonade(i):
    wood = "#C08550"
    i.fill(rrect(10, 14, 4, 24, 1), "wood", hl=False)
    i.fill(rrect(42, 14, 4, 24, 1), "wood", hl=False)
    _box(i, 8, 36, 36, 18, 10, 7, wood)
    i.fill(rrect(13, 39, 26, 12, 2), "cream", hl=False, sh=False, stroke=2, outline=line(SW["wood"]))
    i.fill(ellipse(26, 45, 6, 4), "gold", hl=False, stroke=1.6)
    i.ink("M22,45 H30 M26,42 V48", "gold", 1)
    # a pitcher and two glasses on the counter
    i.fill(path("M17,24 H27 L28,35 H16 Z", (16, 24, 28, 35)), "#FFF7C2", hl=False, sh=False,
           stroke=2, outline=line("#B9B0C8"))
    i.flat(path("M16.6,28 H27.4 L28,35 H16 Z", (16, 28, 28, 35)), "gold", stroke=0)
    i.ink("M27,26 C31,26 31,32 27.6,32", "#B9B0C8", 1.8)
    for gx in (33, 40):
        i.fill(rrect(gx, 28, 5, 7, 1), "gold", hl=False, sh=False, stroke=1.6,
               outline=line("#B9B0C8"))
    # the striped awning, scalloped
    stripes = ("#FFFFFF", "#F5C542")
    for k in range(6):
        x0 = 4 + k * 8.5
        i.flat(poly([(x0 + 4, 6), (x0 + 12.5, 6), (x0 + 8.5, 18), (x0, 18)]), stripes[k % 2],
               stroke=0)
        i.flat(path("M%g,18 A4.25,4.25 0 0 0 %g,18 Z" % (x0, x0 + 8.5), (x0, 18, x0 + 8.5, 22)),
               stripes[k % 2], stroke=0)
    edge = line(SW["gold"])
    i.stroke("M4,18 L8,6 H59 L55,18 " + " ".join("A4.25,4.25 0 0 1 %g,18" % (55 - (k + 1) * 8.5)
                                               for k in range(6)), edge, 2.6)
    i.stroke("M59,6 L60,14 L55,18", edge, 2.2)


@icon("decor_chicken_coop")
def _d_coop(i):
    red = "#D9534B"
    # side wall, roof, then the gable end in front
    i.fill(poly([(38, 30), (56, 21), (56, 41), (38, 50)]), shade(red, 0.75), hl=False, sh=False)
    i.ink("M42,33 V48 M47,30.5 V45.5 M52,28 V43", red, 1.2)
    i.fill(poly([(24, 16), (42, 7), (59, 21), (40, 31)]), "#7E5AA6", hl=False, sh=False)
    i.ink("M30,13 L46,26 M36,10 L52,23.5", "#7E5AA6", 1.2)
    i.fill(poly([(9, 31), (24, 17), (39, 31), (39, 51), (9, 51)]), red)
    i.ink("M9,36 H39 M9,43 H39", red, 1.2)
    i.stroke("M6,33 L24,15 L42,32", "#FFFFFF", 3.2)
    i.stroke("M6,33 L24,15 L42,32", line(red), 1.0)
    i.fill(path("M17,51 V42 A7,7 0 0 1 31,42 V51 Z", (17, 35, 31, 51)), "ink", hl=False, sh=False,
           stroke=2)
    i.fill(circle(24, 26, 3.4), "gold", hl=False, stroke=1.6)
    i.fill(poly([(17, 51), (31, 51), (26, 59), (10, 59)]), "wood", hl=False, sh=False, stroke=2)
    i.ink("M15,55 H28", "wood", 1.4)
    # a hen by the door
    i.fill(path("M44,56 C40,56 39,50 42,47 C43,44 46,43 48,44 C50,41 54,42 54,46 "
                "C57,45 59,47 58,50 C57,54 52,57 44,56 Z", (39, 41, 59, 57)), "white",
           outline=line("#C9C3B8"), stroke=2.2)
    i.fill(poly([(48, 41), (50, 38.5), (51, 41), (53, 39), (53, 42)]), "red", hl=False, sh=False,
           stroke=1.4)
    i.fill(poly([(45, 45), (41.5, 46.5), (45, 47.5)]), "orange", hl=False, sh=False, stroke=1.2)
    i.flat(circle(47.5, 45, 0.9), "ink", stroke=0)


MARBLE = "#ECE7F2"


def _statue(i, pony, plaque):
    """A pony in carved marble on a stone plinth with a gold plaque; her mane and tail in a
    pale stone of her own colour, her mark inlaid on her flank and on the plaque."""
    stone = "#B9B2C9"
    _box(i, 10, 45, 36, 12, 8, 6, stone)
    i.ink("M10,49 H46", stone, 1.2)
    i.fill(rrect(20, 48.5, 16, 6.5, 1.5), "gold", hl=False, sh=False, stroke=1.6)
    pony(i)
    plaque(i)


def _pony(i, head, mane, tail, mane_col, extra=()):
    """A pony standing on the plinth (hooves at y 45), facing left. `head` is the head's centre;
    `mane` and `tail` are paths drawn over her in `mane_col`; `extra` shapes join her body
    (a raised wing)."""
    hx, hy = head
    body = [ellipse(35, 32, 12, 7.5),
            poly([(hx - 2, hy + 4), (hx + 6, hy + 2), (31, 30), (24, 34)]),
            circle(hx, hy, 8.2), ellipse(hx - 7, hy + 4.5, 5.2, 4.2),
            poly([(hx + 1, hy - 6), (hx + 4, hy - 14), (hx + 7, hy - 4)]),
            rrect(24.5, 33, 4, 12, 1.8), rrect(29.5, 34, 4, 11, 1.8),
            rrect(39, 34, 4, 11, 1.8), rrect(43.5, 33, 4, 12, 1.8)] + list(extra)
    i.group(body, MARBLE, stroke=STROKE, hl=(36, 27))
    # the near legs a touch lighter than the far ones
    i.ink("M29.5,44 H33.5 M24.5,44.5 H28.5 M39,44 H43 M43.5,44.5 H47.5", MARBLE, 1.4)
    i.group([path(tail, (0, 0, 64, 64))], mane_col, stroke=STROKE)
    i.group([path(mane, (0, 0, 64, 64))], mane_col, stroke=STROKE)
    # her big eye, carved: socket, iris, catch-light; a smile on the muzzle
    i.flat(ellipse(hx - 3, hy + 0.5, 2.5, 3.3), shade(MARBLE, 0.55), stroke=0)
    i.flat(ellipse(hx - 3.5, hy - 0.6, 1.0, 1.3), "#FFFFFF", stroke=0)
    i.ink("M%g,%g q1.4,0.8 2.6,0" % (hx - 10, hy + 6), MARBLE, 1.1)


@icon("decor_statue_fluttershy")
def _d_flutter(i):
    def pony(i):
        # Fluttershy, head a little bowed, her long mane over her eye and down past her neck,
        # her tail to the plinth, her wing folded.
        _pony(i, (20, 19),
              "M14,13 C16,7 25,6 29,11 C32,16 32,25 30,33 C28,35 25,34 25,31 C27,26 26,20 22,16 "
              "C20,14 17,14 14,13 Z",
              "M46,28 C53,27 56,35 53,44 C51,45 49,44 50,41 C51,36 50,33 46,31.5 Z",
              "#F6E3EC")
        i.fill(path("M30,30 C34,25 41,25 44,28 C41,33 35,34 30,30 Z", (30, 25, 44, 34)), MARBLE,
               hl=False, stroke=1.8)
        i.ink("M33,30 C36,28 39,28 41,29", MARBLE, 1.2)
        for x, y in ((38, 36), (42.5, 34.5)):
            i.flat(ellipse(x - 1.3, y, 1.5, 2.0), "pink", stroke=0.9)
            i.flat(ellipse(x + 1.3, y, 1.5, 2.0), "pink", stroke=0.9)

    def plaque(i):
        i.flat(ellipse(26.6, 51.7, 2, 1.8), "pink", stroke=1)
        i.flat(ellipse(29.4, 51.7, 2, 1.8), "pink", stroke=1)
    _statue(i, pony, plaque)


@icon("decor_statue_rainbowdash")
def _d_dash(i):
    def pony(i):
        # Rainbow Dash, head high, wings raised, her mane and tail streaming back.
        wing = path("M30,28 C27,18 30,8 37,3 C37,8 40,9 43,8 C42,12 44,14 48,13 C46,17 47,20 "
                    "50,21 C46,24 42,27 38,29 Z", (27, 3, 50, 29))
        _pony(i, (19, 15),
              "M13,9 C15,3 24,2 28,6 C32,5 35,8 33,11 C36,13 35,17 32,17 C33,21 31,24 28,25 "
              "C28,20 26,16 22,13 C19,12 16,11 13,9 Z",
              "M46,28 C51,26 55,28 60,25 C60,30 57,33 52,33.5 C54,37 51,40 48,39 C49,36 48,34 "
              "45.5,32.5 Z",
              "#DCEBF7", extra=[wing])
        i.ink("M33,26 C33,19 36,12 39,8 M37,27 C38,21 42,17 46,15", MARBLE, 1.3)
        i.flat(path("M38.5,37 L42.5,32.5 L41,36 L44.5,35.5 L39,40.5 L40.5,37.3 Z",
                    (38, 32, 45, 41)), "red", stroke=0.9)
        i.flat(circle(40.6, 33, 2.1), "sky", stroke=1)

    def plaque(i):
        for k, c in enumerate(("#D93D42", "#F2D147", "#4585DB")):
            i.stroke("M%g,53.5 A%g,%g 0 0 1 %g,53.5" % (22.5 + k * 1.5, 5.5 - k * 1.5,
                                                        4.5 - k * 1.2, 33.5 - k * 1.5), c, 1.3)
    _statue(i, pony, plaque)


# ---- the creator's mark tools (Fable AAA round 4: an icon legend, not a help paragraph) ----

@icon("tool_draw")
def _tool_draw(i):
    # A paintbrush laid on the diagonal, its tip wet with violet.
    i.fill(poly([(40, 12), (52, 24), (30, 46), (18, 34)]), "wood", hl=False)
    i.fill(poly([(18, 34), (30, 46), (26, 50), (14, 38)]), "stone", hl=False, stroke=2.4)
    i.fill(path("M14,38 L26,50 C20,56 12,56 9,55 C8,52 8,44 14,38 Z", (8, 38, 26, 56)), "violet",
           hl=False, stroke=2.4)


@icon("tool_move")
def _tool_move(i):
    # Four arrows from a centre dot.
    for a in range(4):
        rad = math.radians(a * 90)
        cx, cy = 32 + 17 * math.cos(rad), 32 + 17 * math.sin(rad)
        px, py = -math.sin(rad), math.cos(rad)
        tip = (32 + 25 * math.cos(rad), 32 + 25 * math.sin(rad))
        i.fill(poly([tip, (cx + px * 8, cy + py * 8), (cx - px * 8, cy - py * 8)]), "sky",
               hl=False, stroke=2.4)
    i.ink("M32,18 V46 M18,32 H46", "sky", 4.5)
    i.fill(circle(32, 32, 5), "sky", hl=False, stroke=2.4)


@icon("tool_size")
def _tool_size(i):
    # A square with a handle at its corner and an arrow pulling it out.
    i.fill(rrect(12, 24, 26, 26, 3), "cream", hl=False, stroke=2.6)
    i.fill(rrect(33, 19, 10, 10, 2), "gold", hl=False, stroke=2.4)
    i.ink("M40,24 L50,14", "orange", 4)
    i.fill(poly([(53, 11), (52, 22), (42, 12)]), "orange", hl=False, stroke=2.2)


@icon("tool_turn")
def _tool_turn(i):
    # A round arrow.
    i.ink("M47,36 A16,16 0 1,1 40,19", "leaf", 6)
    i.fill(poly([(36, 10), (50, 16), (38, 27)]), "leaf", hl=False, stroke=2.4)


@icon("tool_undo")
def _tool_undo(i):
    i.ink("M22,26 H38 C46,26 50,32 50,38 C50,45 45,50 38,50 H26", "lake", 6)
    i.fill(poly([(10, 26), (24, 15), (24, 37)]), "lake", hl=False, stroke=2.4)


@icon("tool_clear")
def _tool_clear(i):
    # A wash bucket tipping out a splash.
    i.fill(poly([(14, 22), (40, 22), (36, 50), (18, 50)]), "stone", hl=False)
    i.ink("M14,22 H40", "stone", 3)
    i.ink("M17,30 H38", "stone", 2)
    i.fill(path("M42,26 C50,22 56,28 52,34 C56,38 50,46 45,42 C42,46 36,42 40,36 C36,32 38,26 42,26 Z",
                (36, 22, 56, 46)), "sky", hl=False, stroke=2.2)


@icon("tool_eraser")
def _tool_eraser(i):
    i.fill(poly([(30, 12), (52, 34), (36, 50), (14, 28)]), "pink", hl=False)
    i.fill(poly([(14, 28), (24, 38), (16, 46), (8, 38)]), "white", hl=False, stroke=2.4)
    i.ink("M12,52 H52", "stone", 3)


@icon("tool_unstamp")
def _tool_unstamp(i):
    # A stamp's star with a cross over it.
    i.fill(star(30, 34, 17, 0.48), "gold", hl=False)
    i.fill(circle(45, 18, 9), "red", hl=False, stroke=2.4)
    i.stroke("M41,14 L49,22 M49,14 L41,22", "#FFFFFF", 3)


# ---- casino ----------------------------------------------------------------------------

@icon("suit_hearts")
def _hearts(i):
    i.fill(heart(32, 33, 17), "red")


@icon("suit_diamonds")
def _diamonds(i):
    i.fill(poly([(32, 11), (48, 32), (32, 53), (16, 32)]), "red")


@icon("suit_spades")
def _spades(i):
    i.fill(path("M32,11 C40,22 50,26 50,36 C50,43 43,46 36,42 L39,52 H25 L28,42 "
                "C21,46 14,43 14,36 C14,26 24,22 32,11 Z", (14, 11, 50, 52)), "ink")


@icon("suit_clubs")
def _clubs(i):
    i.fill(path("M29,52 L31,40 H33 L35,52 Z", (29, 40, 35, 52)), "ink", hl=False)
    i.fill(circle(32, 21, 9), "ink")
    i.fill(circle(22, 36, 9), "ink")
    i.fill(circle(42, 36, 9), "ink")


# ---- the slot reels ------------------------------------------------------------------------
# Fable AAA round 3, #6: the reels read as stock emoji (an apple, a bell, a gem, a star) beside
# the Market's tiles. They are drawn now in the Market pictures' hand and vocabulary: more of
# the thing, a three quarter view where it helps, the valley's own objects. The apple IS the
# Market's apples; the bell is gone for a Cloudsdale cloud; the star is the Spectra Palace's.

@icon("reel_apple")
def _reel_apple(i):
    _apple_art(i)


@icon("reel_horseshoe")
def _reel_shoe(i):
    # A lucky shoe, open end down and tilted, gold with a lit face, seven nail holes and a
    # glint, so it reads as forged and not as a magnet.
    i.parts.append('<g transform="rotate(-12 32 34)">')
    i.fill(path("M15,52 V31 C15,19 22,11 32,11 C42,11 49,19 49,31 V52 H39 V32 "
                "C39,26 36,22 32,22 C28,22 25,26 25,32 V52 Z", (15, 11, 49, 52)), "gold")
    i.fill(rrect(13.5, 47, 13, 7, 2), shade(SW["gold"], 0.86), hl=False)
    i.fill(rrect(37.5, 47, 13, 7, 2), shade(SW["gold"], 0.86), hl=False)
    nail = line(SW["gold"])
    for x, y in ((20, 42), (19.6, 33), (22, 24), (32, 16.5), (42, 24), (44.4, 33), (44, 42)):
        i.parts.append(f'<rect x="{x - 1.3:.1f}" y="{y - 1.9:.1f}" width="2.6" height="3.8" '
                       f'rx="0.9" fill="{nail}"/>')
    i.parts.append("</g>")
    i.flat(star(50, 13, 6, 0.32, 4), "white", stroke=1.6, outline=line(SW["gold"]))


@icon("reel_cloud")
def _reel_cloud(i):
    # A Cloudsdale cloud: three puffs on a flat underside, lavender shade beneath, a little
    # bolt peeking out under it (a pegasus is never far from one).
    i.fill(poly([(36, 40), (30, 50), (35, 50), (31, 60), (43, 46), (37, 46), (41, 40)]), "gold",
           hl=False, stroke=2.2)
    i.fill(path("M10,42 C5,42 4,33 11,31 C10,22 20,18 25,23 C28,13 43,12 46,22 "
                "C53,19 60,26 56,32 C62,35 59,44 53,43 Z", (4, 13, 61, 44)), "#F4F1FF",
           outline=line("#A6A2D8"))
    i.ink("M16,32 C17,28 21,27 23,29 M35,24 C37,21 41,21 43,24", "#C7C3EE", 2)


@icon("reel_gem")
def _gem(i):
    # A cut gem in three quarter view: the table lit, the crown's facets in three tones, the
    # pavilion deeper, a glint on the table; violet-blue, the Carousel's own.
    base = "#7FA8F0"
    i.fill(poly([(18, 14), (46, 14), (56, 26), (32, 56), (8, 26)]), base, hl=False)
    i.flat(poly([(18, 14), (46, 14), (40, 26), (24, 26)]), "#CFE0FF", stroke=0)
    i.flat(poly([(18, 14), (24, 26), (8, 26)]), "#A9C4F8", stroke=0)
    i.flat(poly([(46, 14), (56, 26), (40, 26)]), shade(base, 0.86), stroke=0)
    i.flat(poly([(8, 26), (24, 26), (32, 56)]), "#9DBAF4", stroke=0)
    i.flat(poly([(24, 26), (40, 26), (32, 56)]), base, stroke=0)
    i.flat(poly([(40, 26), (56, 26), (32, 56)]), shade(base, 0.72), stroke=0)
    i.ink("M8,26 H56 M18,14 L24,26 L32,56 L40,26 L46,14", base, 1.6)
    i.stroke(poly([(18, 14), (46, 14), (56, 26), (32, 56), (8, 26)])[0], line(base), STROKE)
    i.flat(star(25, 19, 4.5, 0.3, 4), "white", stroke=0)
    i.flat(star(51, 11, 4, 0.3, 4), "white", stroke=1.2, outline=line(base))


@icon("reel_star")
def _reel_star(i):
    # The Spectra Palace's star: gold, bevelled (a lighter inner star), on a plum rosette with
    # gold beads, the sign over the Palace door.
    for k in range(10):
        a = math.radians(k * 36 + 18)
        i.flat(circle(32 + 25 * math.cos(a), 33 + 25 * math.sin(a), 2.2), "gold", stroke=1.2)
    i.fill(circle(32, 33, 21), "#6A3E86", hl=False)
    i.fill(star(32, 33, 19, 0.47), "gold", hl=False)
    i.flat(star(32, 33.5, 10, 0.47), "#FFE58F", stroke=0)
    i.flat(star(25, 25, 3.2, 0.3, 4), "white", stroke=0)


@icon("reel_rainbow")
def _rainbow(i):
    # The six bands of the casino's own rainbow (casino_paint BAND_COLORS), ending in two clouds.
    bands = ("#D93D42", "#ED8C33", "#F2D147", "#55AD5C", "#4585DB", "#9961D1")
    for k, c in enumerate(bands):
        r = 25 - k * 3.6
        i.stroke("M%g,44 A%g,%g 0 0 1 %g,44" % (32 - r + 1.8, r - 1.8, r - 1.8, 32 + r - 1.8), c, 3.9,
                 cap="butt")
    i.ink("M7,44 A25,25 0 0 1 57,44 M14.4,44 A17.6,17.6 0 0 1 49.6,44", "#9961D1", 1.4)
    for cx in (12, 52):
        i.fill(path("M%g,50 C%g,50 %g,43 %g,42 C%g,36 %g,35 %g,38 C%g,35 %g,37 %g,42 "
                    "C%g,43 %g,50 %g,50 Z" % (cx - 9, cx - 13, cx - 11, cx - 8, cx - 7, cx - 2,
                                              cx, cx + 3, cx + 8, cx + 8, cx + 12, cx + 12,
                                              cx + 9), (cx - 13, 35, cx + 12, 50)),
               "#F4F1FF", outline=line("#A6A2D8"), stroke=2.4)


def _chip(i, col):
    i.fill(circle(32, 32, 19), col, hl=False)
    for k in range(8):
        a = math.radians(k * 45 + 22.5)
        cx, cy = 32 + 15.5 * math.cos(a), 32 + 15.5 * math.sin(a)
        i.flat(rrect(cx - 2.4, cy - 2.4, 4.8, 4.8, 1.2), "white", stroke=0)
    i.fill(circle(32, 32, 10), col, stroke=2)


@icon("chip_red")
def _chip_r(i):
    _chip(i, "red")


@icon("chip_blue")
def _chip_b(i):
    _chip(i, "lake")


@icon("chip_gold")
def _chip_g(i):
    _chip(i, "gold")


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, fn in ICONS.items():
        ic = Icon(name)
        fn(ic)
        with open(os.path.join(OUT, name + ".svg"), "w") as f:
            f.write(ic.svg(True))
        with open(os.path.join(OUT, name + "_bare.svg"), "w") as f:
            f.write(ic.svg(False))
    print("ICONS_OK %d" % len(ICONS))


if __name__ == "__main__":
    sys.exit(main())
