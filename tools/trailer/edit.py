#!/usr/bin/env python3
"""The trailer edit (TRAILER_PLAN.md), as a script so every cut is reproducible.

    tools/.venv/bin/python tools/trailer/edit.py [--cut N] [--only-audio]

Reads tools/trailer/cut.json (the shot list: which take, where in it, how long, any callout),
snaps every cut to a beat of the music (librosa), renders the callouts and the title card in
the game's own font and card style (PIL), assembles picture and sound with ffmpeg, normalises
to -14 LUFS integrated (two-pass loudnorm, true peak -1 dBTP) and writes:

    TRAILER_4K.mp4     3840x2160, 60 fps, H.264 + AAC (the goal; see DECISIONS.md)
    TRAILER_1080p.mp4  1920x1080, 60 fps, H.264 + AAC
    build/trailer/review/cut<N>/  a contact sheet of a frame every 0.5 s, for TRAILER_REVIEW.md
"""
import argparse
import json
import os
import re
import subprocess
import sys

import librosa
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MUSIC = os.path.join(ROOT, "game", "assets", "audio", "music")
FONT = os.path.join(ROOT, "game", "assets", "fonts", "Fredoka.ttf")
BUILD = os.path.join(ROOT, "build", "trailer")
TAKES = os.path.join(BUILD, "takes")
W, H, FPS = 3840, 2160, 60
# Card and title sizes were laid out at 1440p; everything drawn scales by this.
K = H / 1440.0

# The game's HUD card (game/ui/hud.gd CARD_FILL / CARD_LINE / INK).
CARD_FILL = (255, 247, 232, 240)
CARD_LINE = (120, 79, 163, 255)
INK = (61, 43, 77, 255)


def run(cmd, **kw):
    print("+", " ".join(cmd) if isinstance(cmd, list) else cmd, flush=True)
    return subprocess.run(cmd, check=True, **kw)


def shot_start(take):
    """The frame a take's shot proper begins on (trailer.gd prints it into the .log)."""
    log = os.path.join(TAKES, take.replace(".avi", ".log"))
    with open(log) as f:
        text = f.read()
    # The camera's first move when the take has one (set-up is trimmed off), else the start.
    m = re.search(r"TRAILER_ACTION (\d+)", text) or re.search(r"TRAILER_SHOT_START (\d+)", text)
    return int(m.group(1)) / FPS if m else 0.0


def beats_of(path, offset=0.0, duration=None):
    y, sr = librosa.load(path, sr=22050, mono=True, offset=offset, duration=duration)
    _, frames = librosa.beat.beat_track(y=y, sr=sr)
    return librosa.frames_to_time(frames, sr=sr) + 0.0


def snap(t, grid):
    i = int(np.argmin(np.abs(grid - t)))
    return float(grid[i])


def card(text, size=96, pad=(60, 28), out=None):
    size = int(size * K)
    pad = (int(pad[0] * K), int(pad[1] * K))
    """A callout in the game's style: the cream HUD card, purple line, Fredoka ink."""
    font = ImageFont.truetype(FONT, size)
    bbox = font.getbbox(text)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    w, h = tw + pad[0] * 2, th + pad[1] * 2 + size // 5
    img = Image.new("RGBA", (w + 20, h + 20), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((12, 14, w + 12, h + 14), radius=h // 2, fill=(40, 20, 60, 70))
    d.rounded_rectangle((6, 6, w + 6, h + 6), radius=h // 2, fill=CARD_FILL, outline=CARD_LINE, width=int(10 * K))
    d.text((6 + pad[0] - bbox[0], 6 + pad[1] - bbox[1] + size // 10), text, font=font, fill=INK)
    img.save(out)
    return out


def title_card(out):
    """The end card: the wordmark in Fredoka, a thin rainbow under it, a one-line tag."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    big = ImageFont.truetype(FONT, int(220 * K))
    small = ImageFont.truetype(FONT, int(80 * K))
    t = "Filly Rancher"
    bb = big.getbbox(t)
    x = (W - (bb[2] - bb[0])) // 2 - bb[0]
    y = int(H * 0.36)
    for dx, dy, col in [(int(14 * K), int(18 * K), (60, 30, 90, 150)), (0, 0, (255, 249, 236, 255))]:
        d.text((x + dx, y + dy), t, font=big, fill=col, stroke_width=int(16 * K), stroke_fill=(120, 79, 163, 255) if dx == 0 else col)
    cols = [(240, 96, 112), (250, 190, 80), (120, 200, 110), (90, 170, 240), (180, 130, 230)]
    by = y + (bb[3] - bb[1]) + int(120 * K)
    bw = int(1000 * K)
    for i, c in enumerate(cols):
        d.rounded_rectangle(((W - bw) // 2, by + int(i * 22 * K), (W + bw) // 2, by + int((i * 22 + 18) * K)), radius=int(9 * K), fill=c + (255,))
    tag = "Friendship is Magic. Ranching is Business."
    sb = small.getbbox(tag)
    d.text(((W - (sb[2] - sb[0])) // 2 - sb[0], by + int(170 * K)), tag, font=small, fill=(255, 249, 236, 255),
           stroke_width=int(6 * K), stroke_fill=(90, 60, 120, 255))
    img.save(out)
    return out


def build_music(cut, dur, out):
    """The score: Morning to the turn, Gone Beyond under the twist (the dread drone rising),
    Promises under the title. Each crossfade sits on a bar line of the first track."""
    turn = cut["turn"]
    title = cut["title_at"]
    m1 = os.path.join(MUSIC, "day_morning.ogg")
    m2 = os.path.join(MUSIC, "works_gone_beyond.ogg")
    m3 = os.path.join(MUSIC, "ending_promises.ogg")
    drone = os.path.join(MUSIC, "dread_ossuary.ogg")
    f = (
        f"[0:a]atrim=0:{turn + 1.0},asetpts=N/SR/TB,afade=t=out:st={turn - 0.6}:d=1.0[a1];"
        f"[1:a]atrim=0:{title - turn + 1.0},asetpts=N/SR/TB,adelay={int((turn - 0.1) * 1000)}|{int((turn - 0.1) * 1000)},"
        f"afade=t=in:st={turn - 0.1}:d=0.4,afade=t=out:st={title - 0.8}:d=1.2,volume=0.85[a2];"
        f"[2:a]atrim=20:{20 + title - turn + 2},asetpts=N/SR/TB,adelay={int(turn * 1000)}|{int(turn * 1000)},"
        f"afade=t=in:st={turn}:d={title - turn - 1},afade=t=out:st={title - 0.5}:d=1.5,volume=0.7[a3];"
        f"[3:a]atrim=0:{dur - title + 0.5},asetpts=N/SR/TB,adelay={int((title - 0.4) * 1000)}|{int((title - 0.4) * 1000)},"
        f"afade=t=in:st={title - 0.4}:d=0.8,afade=t=out:st={dur - 2.2}:d=2.2[a4];"
        f"[a1][a2][a3][a4]amix=inputs=4:normalize=0,atrim=0:{dur}[m]"
    )
    run(["ffmpeg", "-v", "error", "-y", "-i", m1, "-i", m2, "-i", drone, "-i", m3,
         "-filter_complex", f, "-map", "[m]", "-ar", "48000", "-ac", "2", out])
    return out


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--cut", type=int, default=1)
    ap.add_argument("--list", default=os.path.join(ROOT, "tools", "trailer", "cut.json"))
    args = ap.parse_args(argv)
    with open(args.list) as f:
        cut = json.load(f)
    work = os.path.join(BUILD, "edit%d" % args.cut)
    os.makedirs(work, exist_ok=True)

    # The beat grid the cuts snap to: Morning's beats up to the turn, Gone Beyond's after it.
    grid1 = beats_of(os.path.join(MUSIC, "day_morning.ogg"), 0, cut["turn"] + 2)
    grid2 = beats_of(os.path.join(MUSIC, "works_gone_beyond.ogg"), 0, 40) + cut["turn"]
    grid = np.concatenate([grid1[grid1 < cut["turn"]], grid2])

    # Lay the shots end to end, every boundary on a beat (the title card is held to the end).
    t = 0.0
    shots = []
    for s in cut["shots"]:
        end = snap(t + s["dur"], grid) if not s.get("hold") else t + s["dur"]
        if end <= t + 0.4:
            end = t + s["dur"]
        shots.append(dict(s, at=t, len=end - t))
        t = end
    total = t
    print("TOTAL %.2fs over %d shots" % (total, len(shots)))

    # Picture: each take trimmed, graded the same way, scaled to 4K, then one concat.
    parts = []
    for i, s in enumerate(shots):
        src = os.path.join(TAKES, s["take"])
        start = shot_start(s["take"]) + s.get("in", 0.0)
        part = os.path.join(work, "part%02d.mp4" % i)
        # Held on its last frame if the take runs short of its slot, so every part is exactly
        # its slot long and nothing after it drifts off the beat.
        vf = ("scale=%d:%d:flags=lanczos,fps=%d,tpad=stop_mode=clone:stop_duration=%.3f,"
              "eq=saturation=%.2f:contrast=1.03,format=yuv420p" % (W, H, FPS, s["len"], s.get("sat", 1.06)))
        if s.get("fade_in"):
            vf += ",fade=t=in:st=0:d=%.2f" % s["fade_in"]
        if s.get("fade_out"):
            vf += ",fade=t=out:st=%.3f:d=%.2f" % (s["len"] - s["fade_out"], s["fade_out"])
        run(["ffmpeg", "-v", "error", "-y", "-ss", "%.3f" % start, "-i", src, "-t", "%.3f" % s["len"],
             "-vf", vf, "-an", "-c:v", "libx264", "-preset", "medium", "-crf", "14", part])
        parts.append(part)
    with open(os.path.join(work, "parts.txt"), "w") as f:
        for p in parts:
            f.write("file '%s'\n" % p)
    picture = os.path.join(work, "picture.mp4")
    run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", os.path.join(work, "parts.txt"),
         "-c", "copy", picture])

    # Overlays: the callouts, and the title card.
    overlays = []
    for i, s in enumerate(shots):
        if s.get("callout"):
            png = card(s["callout"], out=os.path.join(work, "callout%02d.png" % i))
            overlays.append((png, s["at"] + 0.25, s["at"] + min(s["len"], 2.6) - 0.1, "callout"))
        if s.get("title"):
            png = title_card(os.path.join(work, "title.png"))
            overlays.append((png, s["at"] + 0.4, total, "title"))
    inputs = ["-i", picture]
    chain = "[0:v]"
    fc = []
    for k, (png, a, b, kind) in enumerate(overlays):
        inputs += ["-loop", "1", "-t", "%.3f" % total, "-i", png]
        fade = "fade=t=in:st=%.2f:d=0.25:alpha=1,fade=t=out:st=%.2f:d=0.25:alpha=1" % (a, b - 0.25) if kind == "callout" \
            else "fade=t=in:st=%.2f:d=0.9:alpha=1" % a
        fc.append("[%d:v]format=rgba,%s[o%d]" % (k + 1, fade, k))
        pos = "x=(W-w)/2:y=H*0.74" if kind == "callout" else "x=0:y=0"
        fc.append("%s[o%d]overlay=%s:enable='between(t,%.2f,%.2f)'[v%d]" % (chain, k, pos, a, b, k))
        chain = "[v%d]" % k
    graded = os.path.join(work, "graded.mp4")
    if overlays:
        run(["ffmpeg", "-v", "error", "-y"] + inputs + ["-filter_complex", ";".join(fc), "-map", chain,
             "-c:v", "libx264", "-preset", "slow", "-crf", "14", "-pix_fmt", "yuv420p", "-r", str(FPS), graded])
    else:
        graded = picture

    # Sound: the score, and each take's own sound effects under it where the shot asks.
    music = build_music(cut, total, os.path.join(work, "music.wav"))
    sfx_inputs = []
    sfx_f = []
    for i, s in enumerate(shots):
        if not s.get("sfx"):
            continue
        src = os.path.join(TAKES, s["take"])
        start = shot_start(s["take"]) + s.get("in", 0.0)
        k = len(sfx_inputs) // 2 + 1
        sfx_inputs += ["-i", src]
        sfx_f.append("[%d:a]atrim=%.3f:%.3f,asetpts=N/SR/TB,volume=%.2f,adelay=%d|%d[s%d]" %
                     (k, start, start + s["len"], s.get("sfx_gain", 0.8), int(s["at"] * 1000), int(s["at"] * 1000), k))
    mix = os.path.join(work, "mix.wav")
    if sfx_f:
        labels = "".join("[s%d]" % (j + 1) for j in range(len(sfx_f)))
        run(["ffmpeg", "-v", "error", "-y", "-i", music] + sfx_inputs + ["-filter_complex",
             ";".join(sfx_f) + ";[0:a]" + labels + "amix=inputs=%d:normalize=0,atrim=0:%.3f[a]" % (len(sfx_f) + 1, total),
             "-map", "[a]", "-ar", "48000", "-ac", "2", mix])
    else:
        mix = music
    # Two-pass loudnorm to -14 LUFS integrated, -1 dBTP.
    p1 = subprocess.run(["ffmpeg", "-hide_banner", "-i", mix, "-af", "loudnorm=I=-14:TP=-1.5:LRA=11:print_format=json",
                         "-f", "null", "-"], capture_output=True, text=True)
    stats = json.loads(p1.stderr[p1.stderr.rindex("{"):p1.stderr.rindex("}") + 1])
    norm = os.path.join(work, "mix_norm.wav")
    run(["ffmpeg", "-v", "error", "-y", "-i", mix, "-af",
         "loudnorm=I=-14:TP=-1.5:LRA=11:measured_I=%s:measured_TP=%s:measured_LRA=%s:measured_thresh=%s:offset=%s:linear=true" %
         (stats["input_i"], stats["input_tp"], stats["input_lra"], stats["input_thresh"], stats["target_offset"]),
         "-ar", "48000", norm])

    out4k = os.path.join(ROOT, "TRAILER_4K.mp4")
    run(["ffmpeg", "-v", "error", "-y", "-i", graded, "-i", norm, "-map", "0:v", "-map", "1:a",
         "-c:v", "libx264", "-preset", "slow", "-crf", "16", "-pix_fmt", "yuv420p", "-r", str(FPS),
         "-c:a", "aac", "-b:a", "320k", "-movflags", "+faststart", "-shortest", out4k])
    out1080 = os.path.join(ROOT, "TRAILER_1080p.mp4")
    run(["ffmpeg", "-v", "error", "-y", "-i", out4k, "-vf", "scale=1920:1080:flags=lanczos", "-c:v", "libx264",
         "-preset", "slow", "-crf", "17", "-pix_fmt", "yuv420p", "-r", str(FPS), "-c:a", "copy", "-movflags", "+faststart", out1080])

    # Verify the loudness, and write the review contact sheet (a frame every 0.5 s).
    e = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", out4k, "-af", "ebur128=peak=true", "-f", "null", "-"],
                       capture_output=True, text=True).stderr
    summary = e[e.rfind("Summary:"):]
    print("EBUR128", " ".join(summary.split()))
    rev = os.path.join(BUILD, "review", "cut%d" % args.cut)
    os.makedirs(rev, exist_ok=True)
    run(["ffmpeg", "-v", "error", "-y", "-i", out1080, "-vf", "fps=2,scale=480:-1", os.path.join(rev, "f%03d.png")])
    with open(os.path.join(rev, "cuts.json"), "w") as f:
        json.dump({"total": total, "shots": [{"shot": s["shot"], "at": round(s["at"], 3), "len": round(s["len"], 3)} for s in shots],
                   "ebur128": " ".join(summary.split())}, f, indent=1)
    print("EDIT_OK %.2fs" % total)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
