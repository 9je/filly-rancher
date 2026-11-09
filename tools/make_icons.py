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
    i.fill(path("M11,47 L40,18 L46,24 L17,53 Z", (11, 18, 46, 53)), "wood", hl=False)
    i.fill(star(44, 20, 10, 0.4, 4), "violet")
    i.ink("M50,10 L54,6 M54,16 L59,15 M48,4 L49,0", "violet", 2.4)


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
