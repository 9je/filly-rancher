#!/usr/bin/env python3
"""Soft cartoon hoofsteps, synthesised (owner playtest 2026-10-25: "walking sound is AWFUL").

The Kenney takes they replace were a person's shoes on gravel. These are small, round and
short: a muffled thump on grass and dirt, a little wooden "clop" on boards, a "tock" on
stone and a faint ring on metal. Four takes per surface, each a different seed and a few
percent of pitch apart. Writes game/assets/audio/world/hoof_<surface>_<n>.wav (44.1 kHz,
16 bit, mono, peak -6 dBFS, true silence at both ends).
"""
import os, wave
import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "game", "assets", "audio", "world")


def lowpass(x, hz):
    a = np.exp(-2 * np.pi * hz / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def env(n, attack_ms, tau_ms):
    t = np.arange(n) / SR
    a = np.clip(t / (attack_ms / 1000.0), 0, 1)
    return a * np.exp(-t / (tau_ms / 1000.0))


def modes(n, freqs, taus, amps, pitch):
    t = np.arange(n) / SR
    out = np.zeros(n)
    for f, tau, amp in zip(freqs, taus, amps):
        out += amp * np.sin(2 * np.pi * f * pitch * t) * np.exp(-t / (tau / 1000.0))
    return out


def thump(rng, n, cutoff, sweep, pitch, body):
    noise = lowpass(lowpass(rng.standard_normal(n), cutoff * pitch), cutoff * pitch)
    noise *= env(n, 2.5, 16)
    t = np.arange(n) / SR
    f = sweep[0] * pitch * np.exp(-t * 18) + sweep[1] * pitch
    low = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(n, 1.5, 22)
    return noise / (np.abs(noise).max() + 1e-9) + body * low


def make(surface, k):
    rng = np.random.default_rng(1000 * k + ["grass", "dirt", "wood", "stone", "metal"].index(surface))
    pitch = [1.0, 0.95, 1.05, 0.98][k]
    n = int(SR * (0.22 if surface == "metal" else 0.12))
    if surface == "grass":
        x = thump(rng, n, 700, (70, 85), pitch, 0.7)
    elif surface == "dirt":
        x = thump(rng, n, 1300, (80, 95), pitch, 0.55)
        x += 0.25 * rng.standard_normal(n) * env(n, 0.3, 2.0)
    elif surface == "wood":
        x = modes(n, [480, 1150, 2250], [34, 18, 8], [1.0, 0.55, 0.25], pitch)
        x += 0.35 * lowpass(rng.standard_normal(n), 3000) * env(n, 0.2, 2.5)
    elif surface == "stone":
        x = modes(n, [820, 1900, 3300], [16, 9, 5], [1.0, 0.5, 0.3], pitch)
        x += 0.45 * lowpass(rng.standard_normal(n), 5000) * env(n, 0.2, 3.0)
    else:  # metal
        x = modes(n, [1450, 2620, 4050], [70, 45, 28], [0.7, 0.5, 0.3], pitch)
        x += 0.4 * lowpass(rng.standard_normal(n), 6000) * env(n, 0.2, 2.0)
    # The decay is shaped to true silence (the audit reads the quietest 10 ms windows of the
    # body as its noise floor), then a little digital silence after it.
    fade = int(n * 0.6)
    x[-fade:] *= np.cos(np.linspace(0, np.pi / 2, fade)) ** 3
    x[:2] = 0
    x = np.concatenate([x, np.zeros(int(SR * 0.04))])
    x *= 10 ** (-6 / 20) / np.abs(x).max()
    pcm = (x * 32767).astype("<i2")
    path = os.path.join(OUT, "hoof_%s_%d.wav" % (surface, k + 1))
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    return path


if __name__ == "__main__":
    for s in ["grass", "dirt", "wood", "stone", "metal"]:
        for k in range(4):
            print(make(s, k))
