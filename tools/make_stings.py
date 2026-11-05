#!/usr/bin/env python3
"""Synthesise the four music stings (FS5.2): short, soft bell-and-harp figures that play over
the bed on a first catch, a rare catch, a delivery and a Bloom (game/systems/music.gd,
Music.stinger). Everything is additive synthesis with a struck envelope and a small room, so
the files are regenerable and owe nothing to anyone.

    python3 tools/make_stings.py

Writes game/assets/audio/music/sting_<id>.wav, mono 44.1 kHz, peaks at -6 dBFS.
"""
import os
import wave

import numpy as np

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "game", "assets", "audio", "music")
PEAK_DB = -6.0


def note_hz(name):
    """'C5', 'G#4' -> Hz (A4 = 440)."""
    steps = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    semis = steps[name[0]] + (1 if "#" in name else 0)
    octave = int(name[-1])
    return 440.0 * 2 ** ((semis + 12 * (octave - 4)) / 12.0)


def bell(hz, seconds, bright=0.5):
    """A soft struck bell: a few partials, the upper ones dying first."""
    t = np.arange(int(seconds * RATE)) / RATE
    out = np.zeros_like(t)
    for ratio, amp, tau in [(1.0, 1.0, 0.9), (2.0, 0.35 * bright, 0.45), (3.01, 0.18 * bright, 0.25),
                            (4.2, 0.08 * bright, 0.12)]:
        out += amp * np.sin(2 * np.pi * hz * ratio * t) * np.exp(-t / (tau * seconds))
    attack = np.minimum(t / 0.006, 1.0)
    return out * attack


def harp(hz, seconds):
    """A plucked string: bright attack, warm body."""
    t = np.arange(int(seconds * RATE)) / RATE
    out = np.zeros_like(t)
    for k in range(1, 7):
        out += (1.0 / k ** 1.4) * np.sin(2 * np.pi * hz * k * t) * np.exp(-t * (2.5 + k * 1.6))
    return out * np.minimum(t / 0.003, 1.0)


def place(track, sound, at_s, gain=1.0):
    i = int(at_s * RATE)
    end = min(len(track), i + len(sound))
    track[i:end] += sound[: end - i] * gain


def room(x, delays_ms=(37, 53, 71, 97), fb=0.32):
    """A small room: a few feedback delays mixed in under the dry sound."""
    wet = np.zeros_like(x)
    for d in delays_ms:
        n = int(d * RATE / 1000)
        y = np.copy(x)
        for i in range(n, len(y)):
            y[i] += y[i - n] * fb
        wet += y
    return x + wet * 0.18 / len(delays_ms)


def figure(events, seconds):
    track = np.zeros(int(seconds * RATE))
    for kind, note, at, length, gain in events:
        sound = bell(note_hz(note), length) if kind == "bell" else harp(note_hz(note), length)
        place(track, sound, at, gain)
    track = room(track)
    # Die away to silence over the last 0.3 s.
    fade = int(0.3 * RATE)
    track[-fade:] *= np.linspace(1.0, 0.0, fade) ** 2
    return track


STINGS = {
    # A small rising chime: she caught her first.
    "first_catch": figure([("bell", "C5", 0.0, 1.0, 0.8), ("bell", "E5", 0.12, 1.0, 0.8),
                           ("bell", "G5", 0.24, 1.4, 0.9)], 1.8),
    # A sparkling run and a held chord: somebody special.
    "rare": figure([("harp", n, 0.07 * i, 1.0, 0.7) for i, n in enumerate(["C5", "E5", "G5", "C6", "E6"])]
                   + [("bell", "C5", 0.4, 1.6, 0.6), ("bell", "G5", 0.4, 1.6, 0.5), ("bell", "E6", 0.42, 1.6, 0.4)],
                   2.2),
    # Two notes home: a delivery taken.
    "delivery": figure([("bell", "G4", 0.0, 0.9, 0.8), ("bell", "C5", 0.16, 1.3, 0.9)], 1.5),
    # A harp up the scale into a warm chord: a Bloom.
    "bloom": figure([("harp", n, 0.06 * i, 1.0, 0.6) for i, n in enumerate(["C4", "D4", "E4", "G4", "A4", "C5", "D5", "E5"])]
                    + [("bell", "C5", 0.55, 1.8, 0.6), ("bell", "E5", 0.55, 1.8, 0.5), ("bell", "G5", 0.57, 1.8, 0.45)],
                    2.6),
}


def main():
    for name, x in STINGS.items():
        x = x / np.max(np.abs(x)) * 10 ** (PEAK_DB / 20.0)
        path = os.path.join(OUT, "sting_%s.wav" % name)
        with wave.open(path, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes((x * 32767).astype(np.int16).tobytes())
        print("%-22s %.2fs" % (os.path.basename(path), len(x) / RATE))


if __name__ == "__main__":
    main()
