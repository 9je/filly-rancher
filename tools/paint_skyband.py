"""THE PAINTED HORIZON (Fable AAA round 1, #2: "behind the first row of houses the world is
three untextured lime domes ... no Canterlot on its mountain, no daytime clouds"). Paints the
two equirectangular bands the sky dome (shaders/sky_dome.gdshader) wraps round the world:

  skyband.png  a ring of far mountains, the show's way: flat fill plus one hard shadow shape,
               snow on the tall ones, and Canterlot clinging to the tallest with its
               waterfalls, a little north-west of the plaza's view up the street;
  clouds.png   flat cartoon clouds, white with one hard lilac underside, alpha elsewhere.

Both cover the full 360 degrees across their width and ELEV_LO..ELEV_HI degrees of elevation
down their height (top row = ELEV_HI). Deterministic (seeded), so a re-run is a no-op.

  python3 tools/paint_skyband.py
"""
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "game", "assets", "sky")
W, H = 8192, 1024
ELEV_LO, ELEV_HI = -6.0, 39.0
SS = 2  # paint at twice the size, then downsample: clean edges without blur
PX_DEG = W / 360.0

# Azimuth in degrees, 0 = world -Z (north, up the street from the plaza), growing clockwise
# seen from above (toward +X). Canterlot sits a little west of north.
CANTERLOT_AZ = -24.0


def x_of(az):
    return ((az / 360.0) + 0.5) * W * SS


def y_of(elev):
    return (ELEV_HI - elev) / (ELEV_HI - ELEV_LO) * H * SS


def rgb(r, g, b):
    return (int(r * 255), int(g * 255), int(b * 255), 255)


FAR = rgb(0.74, 0.78, 0.93)
FAR_SHADE = rgb(0.64, 0.68, 0.88)
MID = rgb(0.60, 0.66, 0.88)
MID_SHADE = rgb(0.48, 0.53, 0.80)
SNOW = rgb(0.98, 0.98, 1.0)
SNOW_SHADE = rgb(0.80, 0.85, 0.98)
WALL = rgb(0.98, 0.96, 1.0)
WALL_SHADE = rgb(0.78, 0.76, 0.93)
ROOF = rgb(0.56, 0.36, 0.78)
ROOF_SHADE = rgb(0.40, 0.24, 0.62)
GOLD = rgb(1.0, 0.82, 0.30)
FALLS = rgb(0.80, 0.92, 1.0)


def wrapped(draw_fn, *args):
    """Draw a shape three times so anything near the seam crosses it cleanly."""
    for shift in (-W * SS, 0, W * SS):
        draw_fn(shift, *args)


def peak(d, rng, az, h, wl, wr, fill, shade, snow):
    def one(shift):
        x = x_of(az) + shift
        base = y_of(-6.0)
        top = y_of(h)
        l = x - wl * PX_DEG * SS
        r = x + wr * PX_DEG * SS
        # A lumpy ridge line, not a ruler-straight triangle.
        left = [(l, base)]
        for k in range(1, 6):
            t = k / 6.0
            left.append((l + (x - l) * t + rng_j[k] * 6 * SS, base + (top - base) * (t ** 0.9) + rng_j[k + 6] * 5 * SS))
        right = []
        for k in range(1, 6):
            t = k / 6.0
            right.append((x + (r - x) * t + rng_j[k + 12] * 6 * SS, top + (base - top) * (t ** 1.1) + rng_j[k + 18] * 5 * SS))
        poly = left + [(x, top)] + right + [(r, base)]
        d.polygon(poly, fill=fill)
        # The one hard shadow shape: the far face, from the peak down to a fold right of centre.
        fold = x + (r - x) * 0.18
        d.polygon([(x, top)] + right + [(r, base), (fold, base)], fill=shade)
        if snow:
            sh = (base - top) * 0.24
            zig = [(x, top)]
            n = 7
            for k in range(n + 1):
                t = k / n
                px = x - (x - l) * 0.24 + ((r - x) * 0.24 + (x - l) * 0.24) * t
                py = top + sh * (0.75 + 0.25 * ((k % 2) * 2 - 1) * 0.6)
                zig.append((px, py))
            d.polygon(zig, fill=SNOW)
            d.polygon([(x, top)] + [p for p in zig[1:] if p[0] >= x], fill=SNOW_SHADE)
    rng_j = [rng.uniform(-1, 1) for _ in range(30)]
    wrapped(one)


def tower(d, x, base_y, w, h, roof_h, tall_tip=False):
    l, r = x - w / 2, x + w / 2
    top = base_y - h
    d.rectangle([l, top, r, base_y], fill=WALL)
    d.rectangle([x + w * 0.15, top, r, base_y], fill=WALL_SHADE)
    # A narrow window band, the city's purple glass.
    for k in range(int(h // (w * 1.6))):
        wy = top + w * 0.9 + k * w * 1.6
        if wy + w * 0.5 < base_y:
            d.rectangle([x - w * 0.12, wy, x + w * 0.05, wy + w * 0.45], fill=ROOF_SHADE)
    d.polygon([(l - w * 0.18, top), (x, top - roof_h), (r + w * 0.18, top)], fill=ROOF)
    d.polygon([(x, top - roof_h), (r + w * 0.18, top), (x + w * 0.1, top)], fill=ROOF_SHADE)
    tip = roof_h * (0.45 if tall_tip else 0.25)
    d.line([(x, top - roof_h), (x, top - roof_h - tip)], fill=GOLD, width=max(2, int(w * 0.14)))
    d.ellipse([x - w * 0.12, top - roof_h - tip * 0.55 - w * 0.12, x + w * 0.12, top - roof_h - tip * 0.55 + w * 0.12], fill=GOLD)


def canterlot(d):
    """The city on the mountain's west shoulder: a ledge, a crowd of white towers with purple
    cones and gold finials, the palace's tall spires in the middle, waterfalls under it."""
    def one(shift):
        cx = x_of(CANTERLOT_AZ - 1.8) + shift
        ledge_y = y_of(14.0)
        span = 9.5 * PX_DEG * SS
        # Falls first, so the ledge sits over their heads.
        for fx, fl in ((-0.30, 7.5), (-0.05, 9.5), (0.22, 8.0), (0.36, 5.5)):
            x0 = cx + fx * span
            d.rectangle([x0 - 5 * SS, ledge_y, x0 + 5 * SS, ledge_y + fl * PX_DEG * SS], fill=FALLS)
            d.rectangle([x0 + 1 * SS, ledge_y, x0 + 5 * SS, ledge_y + fl * PX_DEG * SS], fill=SNOW_SHADE)
            d.ellipse([x0 - 14 * SS, ledge_y + fl * PX_DEG * SS - 8 * SS, x0 + 14 * SS, ledge_y + fl * PX_DEG * SS + 8 * SS], fill=SNOW)
        d.polygon([(cx - span * 0.55, ledge_y + 10 * SS), (cx + span * 0.5, ledge_y + 10 * SS),
                   (cx + span * 0.42, ledge_y + 26 * SS), (cx - span * 0.46, ledge_y + 30 * SS)], fill=MID_SHADE)
        d.rectangle([cx - span * 0.55, ledge_y - 2 * SS, cx + span * 0.5, ledge_y + 12 * SS], fill=WALL_SHADE)
        u = PX_DEG * SS
        # (offset in spans, width deg, height deg, roof deg); back row first.
        back = [(-0.44, 0.5, 2.4, 0.9), (-0.36, 0.6, 3.2, 1.1), (-0.26, 0.5, 2.6, 0.9), (-0.17, 0.7, 4.0, 1.4),
                (0.12, 0.7, 4.2, 1.4), (0.22, 0.5, 2.8, 1.0), (0.31, 0.6, 3.4, 1.1), (0.40, 0.5, 2.2, 0.8)]
        for o, w, h, rh in back:
            tower(d, cx + o * span, ledge_y, w * u, h * u, rh * u)
        # The palace: a broad hall and three tall spires.
        d.rectangle([cx - 1.6 * u, ledge_y - 2.6 * u, cx + 1.6 * u, ledge_y], fill=WALL)
        d.rectangle([cx + 0.3 * u, ledge_y - 2.6 * u, cx + 1.6 * u, ledge_y], fill=WALL_SHADE)
        d.polygon([(cx - 1.75 * u, ledge_y - 2.6 * u), (cx, ledge_y - 3.6 * u), (cx + 1.75 * u, ledge_y - 2.6 * u)], fill=ROOF)
        d.polygon([(cx, ledge_y - 3.6 * u), (cx + 1.75 * u, ledge_y - 2.6 * u), (cx + 0.2 * u, ledge_y - 2.6 * u)], fill=ROOF_SHADE)
        tower(d, cx - 1.0 * u, ledge_y - 2.0 * u, 0.75 * u, 4.2 * u, 1.8 * u, True)
        tower(d, cx + 1.05 * u, ledge_y - 2.0 * u, 0.75 * u, 3.6 * u, 1.6 * u, True)
        tower(d, cx + 0.02 * u, ledge_y - 3.0 * u, 0.95 * u, 5.6 * u, 2.4 * u, True)
        front = [(-0.48, 0.6, 1.6, 0.7), (-0.40, 0.8, 2.0, 0.9), (-0.30, 0.6, 1.4, 0.6), (-0.22, 0.7, 1.8, 0.8),
                 (0.20, 0.7, 1.7, 0.8), (0.28, 0.6, 1.3, 0.6), (0.36, 0.8, 2.0, 0.9), (0.45, 0.6, 1.5, 0.7)]
        for o, w, h, rh in front:
            tower(d, cx + o * span, ledge_y + 4 * SS, w * u, h * u, rh * u)
    wrapped(one)


def paint_mountains():
    img = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rng = random.Random(7)
    # The far range, all the way round: pale, low, many.
    az = -180.0
    while az < 180.0:
        h = rng.uniform(3.5, 8.0)
        peak(d, rng, az, h, rng.uniform(6, 11), rng.uniform(6, 11), FAR, FAR_SHADE, False)
        az += rng.uniform(7, 13)
    # The near range: Canterlot's mountain and its shoulders, plus a few loners round the ring.
    mids = [(CANTERLOT_AZ, 31.0, 15, 17), (CANTERLOT_AZ - 17, 12.5, 10, 9), (CANTERLOT_AZ + 15, 14.0, 9, 11),
            (CANTERLOT_AZ + 29, 9.0, 8, 8), (60, 10.5, 10, 9), (95, 7.5, 9, 8), (150, 11.0, 11, 10),
            (-120, 9.5, 9, 10), (-80, 12.0, 10, 9), (-160, 8.0, 8, 9)]
    for a, h, wl, wr in mids:
        peak(d, rng, a, h, wl, wr, MID, MID_SHADE, h > 11.0)
    canterlot(d)
    return img.resize((W, H), Image.LANCZOS)


def cloud(d_mask, rng, az, elev, size):
    """One flat cloud: a row of puffs on a flat bottom."""
    out = []
    n = rng.randint(4, 7)
    width = size * rng.uniform(2.2, 3.2)
    for k in range(n):
        t = k / (n - 1)
        r = size * (0.55 + 0.45 * math.sin(math.pi * t)) * rng.uniform(0.8, 1.1)
        out.append((az - width / 2 + width * t, elev + r * 0.35, r))
    return out


def paint_clouds():
    rng = random.Random(11)
    fill = np.zeros((H * SS, W * SS), bool)
    clouds = []
    az = -180.0
    while az < 180.0:
        elev = rng.uniform(9.0, 30.0)
        size = rng.uniform(2.2, 4.2) * (1.0 - (elev - 9.0) / 60.0)
        clouds.append(cloud(None, rng, az, elev, size))
        az += rng.uniform(22, 40)
    m = Image.new("L", (W * SS, H * SS), 0)
    d = ImageDraw.Draw(m)
    bottoms = []
    for puffs in clouds:
        bottom = min(e - r * 0.35 for _, e, r in puffs) + 0.2
        bottoms.append(bottom)
        for shift in (-W * SS, 0, W * SS):
            for a, e, r in puffs:
                cx, cy, rr = x_of(a) + shift, y_of(e), r * PX_DEG * SS
                d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=255)
            # A flat underside.
            yb = y_of(bottom)
            a0 = x_of(puffs[0][0]) + shift - puffs[0][2] * PX_DEG * SS
            a1 = x_of(puffs[-1][0]) + shift + puffs[-1][2] * PX_DEG * SS
            d.rectangle([a0, yb, a1, H * SS], fill=0)
    fill = np.asarray(m) > 0
    # The one hard shadow shape: the underside, where the cloud is not also above itself.
    lift = int(0.9 * PX_DEG * SS)
    above = np.zeros_like(fill)
    above[:-lift] = fill[lift:]
    shade = fill & ~above
    out = np.zeros((H * SS, W * SS, 4), np.uint8)
    out[fill] = (255, 255, 255, 255)
    out[shade] = (214, 220, 246, 255)
    return Image.fromarray(out, "RGBA").resize((W, H), Image.LANCZOS)


def main():
    os.makedirs(OUT, exist_ok=True)
    paint_mountains().save(os.path.join(OUT, "skyband.png"))
    paint_clouds().save(os.path.join(OUT, "clouds.png"))
    print("SKYBAND_OK", OUT)


main()
