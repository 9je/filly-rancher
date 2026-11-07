#!/usr/bin/env python3
"""G9 (FS5.1): hoofstep loudness against the score, from two movie-writer takes of
game/scenes/test/hoof_capture.gd (music alone; hoofsteps alone, at the player's camera).

    tools/measure_hooves.py MUSIC_DIR HOOFS_DIR [start_s end_s]

Prints the score's RMS, each hoofstep's level (the RMS of 60 ms round each onset), their
median, and the median against the score. The target is hoofs 10 to 16 dB under the music.
"""
import sys
import wave

import numpy as np


def load(path):
    with wave.open(path, "rb") as w:
        n = w.getnframes()
        ch = w.getnchannels()
        rate = w.getframerate()
        width = w.getsampwidth()
        raw = w.readframes(n)
    dtype = {2: np.int16, 4: np.int32}[width]
    a = np.frombuffer(raw, dtype=dtype).astype(np.float64) / float(np.iinfo(dtype).max)
    a = a.reshape(-1, ch).mean(axis=1)
    return a, rate


def db(x):
    return 20.0 * np.log10(max(x, 1e-9))


def main():
    music_dir, hoof_dir = sys.argv[1], sys.argv[2]
    start, end = (float(sys.argv[3]), float(sys.argv[4])) if len(sys.argv) > 4 else (11.1, 23.0)
    m, rate = load(music_dir + "/f.wav")
    h, rate2 = load(hoof_dir + "/f.wav")
    m = m[int(start * rate):int(end * rate)]
    h = h[int(start * rate2):int(end * rate2)]
    music_rms = np.sqrt(np.mean(m ** 2))
    win = int(0.01 * rate2)
    env = np.sqrt(np.convolve(h ** 2, np.ones(win) / win, mode="same"))
    floor = np.median(env)
    peaks = []
    i = 0
    gap = int(0.12 * rate2)
    while i < len(env):
        if env[i] > max(floor * 4.0, 1e-4):
            j = min(len(env), i + gap)
            k = i + int(np.argmax(env[i:j]))
            lo, hi = max(0, k - int(0.02 * rate2)), min(len(h), k + int(0.04 * rate2))
            peaks.append(np.sqrt(np.mean(h[lo:hi] ** 2)))
            i = j
        else:
            i += 1
    print("score RMS %.1f dBFS over %.1f s" % (db(music_rms), end - start))
    if not peaks:
        print("no hoofsteps found")
        return
    levels = [db(p) for p in peaks]
    med = float(np.median(levels))
    print("hoofsteps: %d, median %.1f dBFS (range %.1f to %.1f)" % (len(levels), med, min(levels), max(levels)))
    print("hoofs against the score: %+.1f dB (target -16 to -10)" % (med - db(music_rms)))


if __name__ == "__main__":
    main()
