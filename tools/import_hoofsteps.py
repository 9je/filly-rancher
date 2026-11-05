#!/usr/bin/env python3
"""Build the five hoofstep sets from recorded takes (owner, 2026-11-05: "hoof sounds could
be used ... a bit loud and not perfect tho, but anything is better than we got").

The takes are home-equestria's world/audio/hooves (soft_01..10, hard_01..10) and
world/audio/footsteps (grass_1..8), github.com/homedevanon/home-equestria at e90cf52.
They replace the synthesised taps of tools/make_hoofsteps.py.

Each take is made mono 44.1 kHz, its lead-in silence trimmed, high-passed at 90 Hz,
low-passed at 7.5 kHz (the click on the front of a recorded hoof is what read as loud),
brought to TARGET_RMS (3 dB under the synthesised set it replaces) with its peak held
under PEAK_CEILING, and faded out over the last 25 ms.

    python3 tools/import_hoofsteps.py <home-equestria checkout>
"""
import os
import re
import subprocess

import numpy as np
import sys

OUT = os.path.join(os.path.dirname(__file__), "..", "game", "assets", "audio", "world")
TARGET_RMS = -25.0
PEAK_CEILING = -6.0

# surface -> four (hoof take, optional grass layer, pitch) in order of the _1.._4 files.
SETS = {
    "grass": [("hooves/soft_01", "footsteps/grass_1", 1.0), ("hooves/soft_02", "footsteps/grass_2", 1.0),
              ("hooves/soft_03", "footsteps/grass_3", 1.0), ("hooves/soft_04", "footsteps/grass_4", 1.0)],
    "dirt": [("hooves/soft_05", None, 1.0), ("hooves/soft_06", None, 1.0),
             ("hooves/soft_07", None, 1.0), ("hooves/soft_08", None, 1.0)],
    "wood": [("hooves/hard_01", None, 0.94), ("hooves/hard_02", None, 0.94),
             ("hooves/hard_03", None, 0.94), ("hooves/hard_04", None, 0.94)],
    "stone": [("hooves/hard_05", None, 1.0), ("hooves/hard_06", None, 1.0),
              ("hooves/hard_07", None, 1.0), ("hooves/hard_08", None, 1.0)],
    "metal": [("hooves/hard_09", None, 1.12), ("hooves/hard_03", None, 1.12),
              ("hooves/hard_01", None, 1.15), ("hooves/hard_02", None, 1.15)],
}
# The grass layer sits this far under the hoof.
GRASS_LAYER_DB = -8.0


def ffmpeg(args):
    return subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y"] + args,
                          check=True, capture_output=True, text=True)


def levels(path):
    r = subprocess.run(["ffmpeg", "-hide_banner", "-i", path, "-af", "astats", "-f", "null", "-"],
                       capture_output=True, text=True)
    overall = r.stderr.split("Overall")[-1]
    rms = float(re.search(r"RMS level dB:\s*(-?[\d.]+)", overall).group(1))
    peak = float(re.search(r"Peak level dB:\s*(-?[\d.]+)", overall).group(1))
    return rms, peak


def duration(path):
    r = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path],
                       capture_output=True, text=True, check=True)
    return float(r.stdout)


def build(src, take, layer, pitch, out):
    tmp = out + ".tmp.wav"
    shape = ("aresample=44100,silenceremove=start_periods=1:start_threshold=-50dB,"
             "highpass=f=90,lowpass=f=7500")
    if pitch != 1.0:
        shape = "asetrate=%d,%s" % (int(44100 * pitch), shape)
    if layer is None:
        ffmpeg(["-i", os.path.join(src, take + ".ogg"), "-ac", "1", "-af", shape, tmp])
    else:
        ffmpeg(["-i", os.path.join(src, take + ".ogg"), "-i", os.path.join(src, layer + ".ogg"),
                "-filter_complex",
                "[0:a]aformat=channel_layouts=mono,%s[h];"
                "[1:a]aformat=channel_layouts=mono,%s,volume=%sdB[g];"
                "[h][g]amix=inputs=2:duration=longest:normalize=0" % (shape, shape, GRASS_LAYER_DB),
                "-ac", "1", tmp])
    rms, peak = levels(tmp)
    gain = min(TARGET_RMS - rms, PEAK_CEILING - peak)
    fade_at = max(0.0, duration(tmp) - 0.025)
    ffmpeg(["-i", tmp, "-af", "volume=%.2fdB,afade=t=out:st=%.3f:d=0.025" % (gain, fade_at),
            "-ar", "44100", "-ac", "1", "-c:a", "pcm_s16le", out])
    os.remove(tmp)
    if layer is not None:
        decay_tail(out, *GRASS_TAIL)
    else:
        decay_tail(out)
    return levels(out)


# The recordings carry room tone under the strike's decay; tools/audio_audit.py holds a one
# shot's noise floor under -60 dBFS. Past TAIL_AFTER of the loudest moment the take dies away
# on an exponential of TAIL_TAU, to digital silence, the way a struck hoof does in the open.
TAIL_AFTER = 0.012
TAIL_TAU = 0.010
# Grass keeps its rustle a little longer.
GRASS_TAIL = (0.05, 0.024)


def decay_tail(path, after=TAIL_AFTER, tau=TAIL_TAU):
    import wave
    with wave.open(path, "rb") as w:
        rate, n = w.getframerate(), w.getnframes()
        x = np.frombuffer(w.readframes(n), dtype=np.int16).astype(np.float64)
    start = int(np.argmax(np.abs(x))) + int(after * rate)
    t = np.arange(len(x)) - start
    env = np.where(t > 0, np.exp(-np.maximum(t, 0) / (tau * rate)), 1.0)
    y = x * env
    y[np.abs(y) < 1.0] = 0.0
    end = int(np.max(np.nonzero(y)[0])) + 1 if np.any(y) else len(y)
    y = y[:max(end, int(0.03 * rate))]
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(np.round(y).astype(np.int16).tobytes())


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    src = os.path.join(sys.argv[1], "world", "audio")
    for surface, takes in SETS.items():
        for i, (take, layer, pitch) in enumerate(takes, 1):
            out = os.path.join(OUT, "hoof_%s_%d.wav" % (surface, i))
            rms, peak = build(src, take, layer, pitch, out)
            print("%-18s rms %6.1f  peak %5.1f  %.3fs" % (os.path.basename(out), rms, peak, duration(out)))


if __name__ == "__main__":
    main()
