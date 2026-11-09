#!/usr/bin/env python3
"""Synthesise the Market's tune (P8 S7, playtest 2026-11-08 item 66: "Market music is a
recognisable NCS track and grating; replace it with something original or obscure"). The Market
and the Depot played Kevin MacLeod's "Carefree", which half of YouTube has heard. This is an
original 32-bar market tune written for the game: a plucked lead over oom-pah marimba chords and
a soft bass, AABA in G major at 100 bpm, the B section on a glockenspiel. Additive synthesis
like tools/make_stings.py, so the file is regenerable and owes nothing to anyone. The end is
folded onto the start, so it loops without a seam.

    python3 tools/make_market_tune.py

Writes game/assets/audio/music/market_stalls.ogg (stereo 44.1 kHz, -21 LUFS like the bed it
replaces; needs ffmpeg).
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

RATE = 44100
BPM = 100.0
EIGHTH = 60.0 / BPM / 2.0
BAR = EIGHTH * 8
OUT = os.path.join(os.path.dirname(__file__), "..", "game", "assets", "audio", "music",
                   "market_stalls.ogg")


def note_hz(name):
    """'C5', 'F#4' -> Hz (A4 = 440)."""
    steps = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    semis = steps[name[0]] + (1 if "#" in name else 0) - (1 if name[1] == "b" else 0)
    octave = int(name[-1])
    return 440.0 * 2 ** ((semis + 12 * (octave - 4)) / 12.0)


def _t(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def pluck(hz, seconds):
    """A bright plucked string, mandolin-ish: a hard attack and a body that rings down."""
    t = _t(seconds + 0.6)
    out = np.zeros_like(t)
    for k in range(1, 9):
        detune = 1.0 + 0.0009 * (k % 3 - 1)
        out += (1.0 / k ** 1.25) * np.sin(2 * np.pi * hz * k * detune * t) * np.exp(-t * (3.2 + k * 1.9))
    return out * np.minimum(t / 0.002, 1.0)


def marimba(hz, seconds):
    """A wooden bar: the fundamental and its fourth partial, short and round."""
    t = _t(seconds + 0.3)
    out = np.sin(2 * np.pi * hz * t) * np.exp(-t * 7.0) + 0.25 * np.sin(2 * np.pi * hz * 3.93 * t) * np.exp(-t * 22.0)
    return out * np.minimum(t / 0.004, 1.0)


def glock(hz, seconds):
    """A glockenspiel: pure, high, long."""
    t = _t(seconds + 0.9)
    out = np.sin(2 * np.pi * hz * t) * np.exp(-t * 2.2) + 0.3 * np.sin(2 * np.pi * hz * 2.76 * t) * np.exp(-t * 6.0)
    return out * np.minimum(t / 0.002, 1.0)


def bass(hz, seconds):
    """A soft upright bass: the fundamental and a little second harmonic, plucked."""
    t = _t(seconds + 0.2)
    out = np.sin(2 * np.pi * hz * t) + 0.35 * np.sin(2 * np.pi * hz * 2 * t)
    return out * np.exp(-t * 3.5) * np.minimum(t / 0.008, 1.0)


def shaker(seconds, rng):
    t = _t(seconds)
    noise = rng.standard_normal(len(t))
    # A crude high pass: the difference of neighbours.
    noise = np.diff(noise, prepend=0.0)
    return noise * np.exp(-t * 60.0) * 0.08


CHORDS = {
    "G": ["G3", "B3", "D4"], "C": ["C4", "E4", "G4"], "D": ["D4", "F#4", "A4"],
    "D7": ["D4", "F#4", "C5"], "Em": ["E4", "G4", "B4"], "Am": ["A3", "C4", "E4"],
}
ROOTS = {"G": ("G2", "D3"), "C": ("C3", "G2"), "D": ("D3", "A2"), "D7": ("D3", "A2"),
         "Em": ("E2", "B2"), "Am": ("A2", "E3")}

A_CHORDS = ["G", "C", "D", "G", "Em", "C", "D7", "G"]
B_CHORDS = ["C", "G", "Am", "D", "C", "G", "D", "G"]
# Each bar: (note or None, length in eighths), eight eighths a bar.
A_TUNE = [
    [("D5", 2), ("B4", 1), ("D5", 1), ("G5", 2), ("F#5", 1), ("E5", 1)],
    [("E5", 2), ("C5", 1), ("E5", 1), ("G5", 3), ("E5", 1)],
    [("F#5", 2), ("A5", 1), ("F#5", 1), ("D5", 2), ("E5", 1), ("F#5", 1)],
    [("G5", 3), ("D5", 1), ("B4", 4)],
    [("E5", 2), ("G5", 1), ("E5", 1), ("B4", 2), ("E5", 2)],
    [("C5", 1), ("D5", 1), ("E5", 1), ("G5", 1), ("E5", 2), ("C5", 2)],
    [("A4", 2), ("C5", 1), ("D5", 1), ("F#5", 2), ("A5", 1), ("F#5", 1)],
    [("G5", 4), (None, 4)],
]
A_END = [("G5", 2), ("D5", 2), ("G4", 4)]
B_TUNE = [
    [("E5", 1), ("G5", 1), ("C6", 2), ("B5", 1), ("A5", 1), ("G5", 2)],
    [("D5", 1), ("G5", 1), ("B5", 2), ("A5", 1), ("G5", 1), ("D5", 2)],
    [("C5", 1), ("E5", 1), ("A5", 2), ("G5", 1), ("E5", 1), ("C5", 2)],
    [("D5", 2), ("F#5", 2), ("A5", 3), (None, 1)],
    [("G5", 2), ("E5", 1), ("G5", 1), ("C6", 2), ("G5", 2)],
    [("B5", 2), ("G5", 1), ("B5", 1), ("D6", 2), ("B5", 2)],
    [("A5", 1), ("G5", 1), ("F#5", 1), ("E5", 1), ("D5", 2), ("F#5", 2)],
    [("G5", 4), (None, 4)],
]


def place(track, sound, at_s, gain, pan):
    i = int(at_s * RATE)
    end = min(track.shape[1], i + len(sound))
    track[0, i:end] += sound[: end - i] * gain * (1.0 - pan) ** 0.5
    track[1, i:end] += sound[: end - i] * gain * (1.0 + pan) ** 0.5


def render():
    sections = [("A", A_CHORDS, A_TUNE), ("A2", A_CHORDS, A_TUNE[:7] + [A_END]),
                ("B", B_CHORDS, B_TUNE), ("A", A_CHORDS, A_TUNE[:7] + [A_END])]
    bars = sum(len(s[1]) for s in sections)
    length = bars * BAR
    track = np.zeros((2, int((length + 3.0) * RATE)))
    rng = np.random.default_rng(7)
    bar_i = 0
    for name, chords, tune in sections:
        lead = glock if name == "B" else pluck
        for chord, line in zip(chords, tune):
            t0 = bar_i * BAR
            root, fifth = ROOTS[chord]
            # Oom: the bass on one and three.
            place(track, bass(note_hz(root), EIGHTH * 2), t0, 0.55, -0.1)
            place(track, bass(note_hz(fifth), EIGHTH * 2), t0 + EIGHTH * 4, 0.5, -0.1)
            # Pah: the chord on two and four.
            for beat in (2, 6):
                for k, n in enumerate(CHORDS[chord]):
                    place(track, marimba(note_hz(n), EIGHTH), t0 + EIGHTH * beat + k * 0.006, 0.16, 0.25)
            for e in range(8):
                place(track, shaker(EIGHTH, rng), t0 + EIGHTH * e, 0.35 if e % 2 else 0.2, 0.4)
            at = t0
            for note, n8 in line:
                if note is not None:
                    gain = 0.42 if lead is pluck else 0.36
                    place(track, lead(note_hz(note), EIGHTH * n8), at, gain, -0.2)
                at += EIGHTH * n8
            bar_i += 1
    # Fold the ring-out past the last bar back onto the start: a seamless loop.
    n = int(length * RATE)
    tail = track[:, n:]
    track = track[:, :n]
    track[:, : tail.shape[1]] += tail
    # A small room, the same idea as the stings'.
    wet = np.zeros_like(track)
    for d in (41, 59, 83):
        k = int(d * RATE / 1000)
        wet[:, k:] += track[:, :-k] * 0.3
    return track + wet * 0.4


def main():
    x = render()
    x = x / np.max(np.abs(x)) * 0.7
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "market.wav")
        with wave.open(wav, "wb") as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes((x.T * 32767).astype(np.int16).tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-af",
                        "loudnorm=I=-21:TP=-4:LRA=11", "-ar", str(RATE), "-c:a", "libvorbis",
                        "-q:a", "6", OUT], check=True)
    print("%s %.1fs" % (os.path.basename(OUT), x.shape[1] / RATE))


if __name__ == "__main__":
    main()
