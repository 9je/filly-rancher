#!/usr/bin/env python3
"""The penning sound, synthesised (owner playtest 2026-10-25: "sound on paddock is pretty bad").

Moving a pony into a pen used to play a wooden door creak at +3 dB, fifteen times in a first
ten minutes. Now: a small wooden latch "clack" and a soft two-note marimba rise (a fifth),
warm and short. Writes game/assets/audio/world/pen_in.wav (44.1 kHz, 16 bit, mono, peak
-6 dBFS, silence at both ends).
"""
import os, wave
import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "game", "assets", "audio", "world", "pen_in.wav")


def marimba(f, n, t0):
    t = np.arange(n) / SR
    x = np.zeros(n)
    s = int(t0 * SR)
    tt = t[: n - s]
    # A bar's partials: the fundamental, the 4th and the 10th, the upper ones dying fast.
    tone = (np.sin(2 * np.pi * f * tt) * np.exp(-tt / 0.32)
            + 0.35 * np.sin(2 * np.pi * f * 3.93 * tt) * np.exp(-tt / 0.06)
            + 0.12 * np.sin(2 * np.pi * f * 9.2 * tt) * np.exp(-tt / 0.015))
    attack = np.clip(tt / 0.003, 0, 1)
    x[s:] = tone * attack
    return x


def latch(n, rng):
    t = np.arange(n) / SR
    x = (np.sin(2 * np.pi * 620 * t) * np.exp(-t / 0.02) + 0.5 * np.sin(2 * np.pi * 1480 * t) * np.exp(-t / 0.01))
    x += 0.4 * rng.standard_normal(n) * np.exp(-t / 0.002)
    return x


rng = np.random.default_rng(7)
n = int(SR * 0.9)
x = 0.6 * latch(n, rng) + 0.55 * marimba(659.25, n, 0.07) + 0.6 * marimba(987.77, n, 0.19)
fade = int(n * 0.5)
x[-fade:] *= np.cos(np.linspace(0, np.pi / 2, fade)) ** 3
x = np.concatenate([np.zeros(10), x, np.zeros(int(SR * 0.04))])
x *= 10 ** (-6 / 20) / np.abs(x).max()
with wave.open(OUT, "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes((x * 32767).astype("<i2").tobytes())
print(OUT)
