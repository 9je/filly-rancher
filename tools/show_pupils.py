#!/usr/bin/env python3
"""Redraw every pony eye texture with the show's pupil (face close-ups, 2026-11-05).

A PonySFM eye texture draws a pupil three quarters to nine tenths the width of its iris, so
on screen a pony looked out through two black discs ringed in colour. The show draws a big
coloured iris with a pupil about half its width (the idea from home-equestria's show iris,
which draws its pupil as a fitted ellipse at that size).

For each texture: the pupil is the black run nearest the middle of the coloured disc, the iris
the not-white run around it (the sclera's white, or the cap's transparency, stops it). Inside
the iris ellipse, centred on the pupil, the pupil is redrawn SHOW_PUPIL of the way out and her
own iris ring is stretched outward over the room it leaves, so canon colours and gradients
stay hers. The highlights stay where and as big as they were drawn (over the iris now as
well as the pupil, as the show has them). A pupil already at or under SHOW_PUPIL is left
alone, so a second run changes nothing. game/test/test_eye_frame.gd holds every shipped
eye to it.

    python3 tools/show_pupils.py [files...]   (default: every eye texture of the roster)
"""
import glob
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

SHOW_PUPIL = 0.55
PONIES = os.path.join(os.path.dirname(__file__), "..", "game", "assets", "converted", "ponies")
PATTERNS = ["*_pupil_l.png", "*_pupil_r.png", "*_Eye.png", "*_Eye_R.png", "*_eyeball_l.png", "*_eyeball_r.png"]


def frame(a):
    """(centre, pupil_radius, disc_radius) in pixels, as (x, y) arrays, or None."""
    rgb, alpha = a[..., :3], a[..., 3]
    mx, mn = rgb.max(-1), rgb.min(-1)
    disc = (alpha >= 0.5) & (mn < 0.86)
    pupil = disc & (mx < 0.14)
    if not pupil.any():
        return None
    ys, xs = np.nonzero(disc)
    mid = np.array([xs.mean(), ys.mean()])
    py, px = np.nonzero(pupil)
    k = np.argmin((px - mid[0]) ** 2 + (py - mid[1]) ** 2)
    seed = (py[k], px[k])
    pl, _ = ndimage.label(pupil)
    dl, _ = ndimage.label(disc)
    pys, pxs = np.nonzero(pl == pl[seed])
    dys, dxs = np.nonzero(dl == dl[seed])
    centre = np.array([(pxs.min() + pxs.max() + 1) / 2.0, (pys.min() + pys.max() + 1) / 2.0])
    pr = np.array([(pxs.max() - pxs.min() + 1) / 2.0, (pys.max() - pys.min() + 1) / 2.0])
    dr = np.array([(dxs.max() - dxs.min() + 1) / 2.0, (dys.max() - dys.min() + 1) / 2.0])
    if dr[0] <= pr[0] * 1.01 or dr[1] <= pr[1] * 1.01:
        return None
    return centre, pr, dr


def bilinear(a, x, y):
    h, w = a.shape[:2]
    x = np.clip(x - 0.5, 0, w - 1.001)
    y = np.clip(y - 0.5, 0, h - 1.001)
    x0, y0 = np.floor(x).astype(int), np.floor(y).astype(int)
    fx, fy = (x - x0)[..., None], (y - y0)[..., None]
    return (a[y0, x0] * (1 - fx) * (1 - fy) + a[y0, x0 + 1] * fx * (1 - fy)
            + a[y0 + 1, x0] * (1 - fx) * fy + a[y0 + 1, x0 + 1] * fx * fy)


def redraw(path):
    im = Image.open(path).convert("RGBA")
    a = np.asarray(im).astype(np.float32) / 255.0
    f = frame(a)
    if f is None:
        return "no pupil found, left"
    centre, pr, dr = f
    was = float(np.mean(pr / dr))
    if was <= SHOW_PUPIL + 0.01:
        return "pupil %.2f of the iris, left" % was
    now = SHOW_PUPIL
    h, w = a.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32) + 0.5
    qx, qy = (xx - centre[0]) / dr[0], (yy - centre[1]) / dr[1]
    r = np.sqrt(qx * qx + qy * qy)
    inside = r < 1.0
    r2 = np.where(r < now, r * was / now, was + (r - now) * (1.0 - was) / (1.0 - now))
    s = np.where(r > 1e-6, r2 / np.maximum(r, 1e-6), 0.0)
    sx, sy = centre[0] + qx * s * dr[0], centre[1] + qy * s * dr[1]
    out = a.copy()
    moved = bilinear(a, sx[inside], sy[inside])
    # The shrunk pupil carries no shrunk copy of the highlights.
    pupil_zone = (r < now)[inside]
    whiteness = np.clip((moved[:, :3].min(-1) - 0.3) / 0.3, 0.0, 1.0)
    moved[:, :3] *= np.where(pupil_zone, 1.0 - whiteness, 1.0)[:, None]
    out[inside] = moved
    # The drawn highlights, where and as big as they were.
    orig = a[inside]
    was_pupil = (r < was)[inside]
    shine = np.clip((orig[:, :3].min(-1) - 0.80) / 0.12, 0.0, 1.0) * was_pupil * (orig[:, 3] >= 0.5)
    out_in = out[inside]
    out_in[:, :3] = out_in[:, :3] * (1 - shine[:, None]) + orig[:, :3] * shine[:, None]
    out[inside] = out_in
    Image.fromarray((np.clip(out, 0, 1) * 255.0 + 0.5).astype(np.uint8), "RGBA").save(path)
    return "pupil %.2f -> %.2f of the iris" % (was, now)


def main():
    files = sys.argv[1:]
    if not files:
        for p in PATTERNS:
            files += glob.glob(os.path.join(PONIES, p))
    for path in sorted(files):
        print("%-34s %s" % (os.path.basename(path), redraw(path)))


if __name__ == "__main__":
    main()
