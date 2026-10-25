#!/usr/bin/env python3
"""Measure every audio file in the game and fail on anything noisy, clipped or too loud.

usage: python3 -I tools/audio_audit.py [--root game] [--markdown OUT.md] [--json OUT.json]
                                       [FILE ...]

With no FILE arguments it walks --root (default: game/, skipping .godot/) for every .wav,
.ogg, .mp3 and .flac. Exit status is 0 when every file passes and 1 when any fails, so it
can gate a commit; game/test/test_audio_audit.gd runs it from the suite.

WHAT IS MEASURED, PER FILE (all with ffmpeg; numpy only does arithmetic on decoded samples):
  peak        sample peak, dBFS, the loudest single sample of any channel.
  true peak   ebur128=peak=true, dBTP (4x oversampled, catches intersample overs).
  clipped     samples at or above 0.999 of full scale. Any is a fail: a sample there is a
              sample that hit the rail somewhere upstream.
  flat tops   runs of 3+ consecutive samples pinned within 0.05 dB of the file's own peak.
              That is the fingerprint of a brick wall limiter or a clip: a waveform that
              was squared off. Reported, and a one shot with more than FLAT_TOP_LIMIT of
              them fails as "crushed" -- it is what the old +16 dB hoofsteps did to their
              own transients through fetch_sounds.sh's alimiter.
  noise floor the RMS of the quietest 10% of 10 ms windows inside the sound's own body
              (from its first window within 40 dB of peak to its last, so neither the
              digital silence of a pad nor the last few ms of a fade count), dBFS. This is
              the hiss, hum or room tone you hear UNDER the event. One shots fail above
              NOISE_FLOOR_ONESHOT. Beds and music are noise by design and only report it.
  loudness    integrated LUFS (ebur128). For a one shot shorter than EBU gating handles
              honestly the file is padded and the max momentary (400 ms) loudness is used
              instead; that is what the ear hears when it plays.

KINDS come from the directory (ambient/ = bed, music/ = music, everything else one shot),
and so do the loudness ceilings: a file can be quieter than its target (the mix brings it
up) but never far hotter, which is the "ambience too loud" note in number form.
"""
from __future__ import annotations

import argparse
import json
import math
import re
import subprocess
import sys
from pathlib import Path

import numpy as np

FFMPEG = "/usr/bin/ffmpeg"
EXTS = {".wav", ".ogg", ".mp3", ".flac"}

PEAK_CEILING_DBFS = -1.0
TRUE_PEAK_CEILING_DBTP = -1.0
CLIP_LEVEL = 0.999
FLAT_TOP_RUN = 3
FLAT_TOP_DB = 0.05
FLAT_TOP_LIMIT = 4
NOISE_FLOOR_ONESHOT = -60.0
# Loudness ceilings (the mix targets plus a little headroom; see tools/sound_manifest.txt
# for the targets themselves: beds -24, SFX -18, UI -20, music -20..-23).
LOUDNESS_CEILING = {"bed": -22.0, "music": -17.0, "oneshot": -12.0}
# ONE SHOTS WHOSE NOISE IS THE SOUND. The floor rule measures what sits UNDER an event;
# these two have no "under": the whole file is a sustained broadband texture by design,
# so their floor is their body (crest under 14 dB, i.e. no quiet anywhere). Every other
# rule still applies to them. Listed by path tail, each with the reason it is here; adding
# a file to this table is a decision that belongs in AUDIO_AUDIT.md.
TEXTURES = {
    "world/capture_charge.ogg": "a held generator hum under the beam (BBC 07043314, sped up): "
                                "the hum is the sound, and it plays on a loop voice",
    "casino/race_cheer.wav": "a grandstand cheering (BBC 07035069): a crowd is broadband "
                             "noise by nature",
}
WINDOW_S = 0.010
MIN_WINDOWS = 8
MAX_FRAMES = 2000


def kind_of(path: Path) -> str:
    parts = set(path.parts)
    if "ambient" in parts:
        return "bed"
    if "music" in parts:
        return "music"
    # The two casino held loops (crowd, race gallop) are beds in everything but folder.
    if "casino" in parts and path.suffix == ".ogg":
        return "bed"
    return "oneshot"


def decode(path: Path) -> tuple[np.ndarray, int]:
    probe = subprocess.run([FFMPEG, "-nostdin", "-hide_banner", "-i", str(path)],
                           capture_output=True, text=True)
    m = re.search(r"Audio:.*?(\d+) Hz, (mono|stereo|(\d+) channels)", probe.stderr)
    rate = int(m.group(1)) if m else 44100
    chans = 1 if (m and m.group(2) == "mono") else (2 if (m and m.group(2) == "stereo")
                                                   else int(m.group(3)) if m else 2)
    raw = subprocess.run([FFMPEG, "-nostdin", "-v", "error", "-i", str(path), "-f", "f32le",
                          "-acodec", "pcm_f32le", "-"], capture_output=True, check=True).stdout
    data = np.frombuffer(raw, dtype="<f4")
    if chans > 1:
        data = data[: len(data) // chans * chans].reshape(-1, chans)
    else:
        data = data.reshape(-1, 1)
    return data, rate


def db(x: float) -> float:
    return 20.0 * math.log10(x) if x > 1e-12 else -240.0


def ebur128(path: Path, pad: bool) -> tuple[float, float, float]:
    """(integrated LUFS, true peak dBTP, max momentary LUFS)."""
    af = "apad=pad_dur=1," if pad else ""
    out = subprocess.run([FFMPEG, "-nostdin", "-hide_banner", "-nostats", "-i", str(path),
                          "-filter_complex", af + "ebur128=peak=true", "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    momentary = [float(v) for v in re.findall(r"M:\s*(-?[0-9.]+)", out)]
    summary = out[out.rfind("Summary:"):]
    i = re.search(r"I:\s*(-?[0-9.]+) LUFS", summary)
    tp = re.search(r"True peak:\s*Peak:\s*(-?[0-9.]+|-inf)", summary)
    integrated = float(i.group(1)) if i else -70.0
    true_peak = float(tp.group(1)) if tp and tp.group(1) != "-inf" else -240.0
    return integrated, true_peak, max(momentary) if momentary else -120.0


def broadband_floor(mono: np.ndarray, rate: int) -> float | None:
    """The BROADBAND noise floor in dBFS RMS, by minimum statistics.

    STFT (2048 Blackman, hop 512); per frequency bin, the 10th percentile of its power over
    time (stationary noise sits there; an event passes through and is gone); then the
    sum over the bins from 100 Hz to 16 kHz, each first capped to its octave's median so a
    partial ringing through the whole file is not counted as noise (room tone and hiss are
    their neighbours; a chime's partial is a spike over them). Frames of digital silence
    and the last 15% (the fade) are left out. See --selftest for the calibration. None for
    a file too short to have twelve frames.
    """
    # A short one shot gets a short window: a 2048 sample frame is 46 ms, and in a 100 ms
    # hoof tap EVERY such frame overlaps the strike, so its "quietest" frame is still the
    # strike. 512 samples (12 ms) lets the decay after it show.
    x = mono.astype(np.float64)
    nfft, hop = (2048, 512) if len(x) >= rate // 2 else (512, 64)
    if len(x) < nfft:
        x = np.concatenate([x, np.zeros(nfft - len(x))])
    frames = max(1, int((1 + (len(x) - nfft) // hop) * 0.85))
    if frames < 12:
        return None
    w = np.blackman(nfft)
    starts = hop * np.arange(frames)
    if frames > MAX_FRAMES:
        # A four minute track is 20,000 frames; an even spread of MAX_FRAMES of them has the
        # same percentiles to well under a dB, at a tenth of the memory.
        starts = starts[np.linspace(0, frames - 1, MAX_FRAMES).astype(int)]
    idx = np.arange(nfft)[None, :] + starts[:, None]
    seg = x[idx] * w
    keep = (seg ** 2).sum(axis=1) > 1e-10 * (w ** 2).sum()
    seg = seg[keep]
    if len(seg) < 12:
        return None
    spec = np.abs(np.fft.rfft(seg, axis=1)) ** 2
    freqs = np.fft.rfftfreq(nfft, 1.0 / rate)
    band = (freqs >= 100.0) & (freqs <= 16000.0)
    low = np.percentile(spec[:, band], 10, axis=0)
    # TONAL REJECTION. A partial that rings through the whole file survives the percentile,
    # so every bin is capped at the median of the octave around it (21 bins at least): a partial is a
    # spike over its neighbours and is cut back to them, while noise is its neighbours.
    bf = freqs[band]
    capped = low.copy()
    for k in range(len(low)):
        lo_f, hi_f = bf[k] / 2 ** 0.5, bf[k] * 2 ** 0.5
        a, b = np.searchsorted(bf, lo_f), np.searchsorted(bf, hi_f, side="right")
        if b - a < 21:
            a, b = max(0, k - 10), min(len(low), k + 11)
        capped[k] = min(low[k], float(np.median(low[a:b])))
    # White noise of variance s2 gives E|X_k|^2 = s2 * sum(w^2) per bin, and the 10th
    # percentile of that exponential variable is 0.1054 of its mean. Summed over the band's
    # bins times 2/nfft that is the noise POWER inside 100 Hz to 16 kHz: white noise at R
    # dBFS RMS reads R - 1.4 (the band is 72% of the spectrum), a 200 Hz hum reads its own
    # level, a hiss reads its own level.
    per_bin = capped / 0.1054 / (w ** 2).sum()
    total = float(per_bin.sum()) * 2.0 / nfft
    return 10.0 * math.log10(total) if total > 1e-24 else -240.0


def measure(path: Path) -> dict:
    data, rate = decode(path)
    kind = kind_of(path)
    mono = np.abs(data).max(axis=1) if data.size else np.zeros(1)
    peak = float(mono.max()) if mono.size else 0.0
    duration = len(data) / rate
    clipped = int(np.count_nonzero(np.abs(data) >= CLIP_LEVEL))

    # flat tops: runs of FLAT_TOP_RUN samples within FLAT_TOP_DB of the file's own peak
    flat = 0
    if peak > 1e-6:
        thresh = peak * 10 ** (-FLAT_TOP_DB / 20.0)
        for ch in range(data.shape[1]):
            hot = np.abs(data[:, ch]) >= thresh
            if not hot.any():
                continue
            edges = np.diff(np.concatenate(([0], hot.astype(np.int8), [0])))
            starts = np.flatnonzero(edges == 1)
            ends = np.flatnonzero(edges == -1)
            flat += int(np.count_nonzero((ends - starts) >= FLAT_TOP_RUN))

    # Quiet RMS: the quietest 10% of 10 ms windows, leaving out digital silence and the
    # last 15% (the pipeline's fade). Informational: in a sound with no gap in it, its
    # quietest windows are the sound itself, so this alone cannot tell hiss from a chime.
    win = max(1, int(rate * WINDOW_S))
    sq = (data.astype(np.float64) ** 2).mean(axis=1)
    n = len(sq) // win
    quiet = None
    crest = None
    if n >= MIN_WINDOWS:
        rms = np.sqrt(sq[: n * win].reshape(n, win).mean(axis=1))
        all_db = 20.0 * np.log10(np.maximum(rms, 1e-12))
        body = all_db[: max(1, int(n * 0.85))]
        body = body[body > -100.0]
        if body.size:
            k = max(1, int(math.ceil(body.size * 0.10)))
            quiet = float(np.sort(body)[:k].mean())
        # Crest: peak against the MEDIAN window. An impact is a spike over quiet; a
        # "sound" that is mostly background noise has a peak barely over its own middle.
        crest = db(peak) - float(np.median(all_db))
    noise = broadband_floor(data.mean(axis=1), rate)
    snr = db(peak) - noise if noise is not None else None

    short = kind == "oneshot"
    integrated, true_peak, momentary = ebur128(path, pad=short)
    loudness = momentary if short else integrated

    reasons = []
    if clipped > 0:
        reasons.append(f"{clipped} clipped samples")
    if db(peak) > PEAK_CEILING_DBFS:
        reasons.append(f"peak {db(peak):.1f} dBFS > {PEAK_CEILING_DBFS}")
    if true_peak > TRUE_PEAK_CEILING_DBTP:
        reasons.append(f"true peak {true_peak:.1f} dBTP > {TRUE_PEAK_CEILING_DBTP}")
    texture = next((why for tail, why in TEXTURES.items() if str(path).endswith(tail)), None)
    if kind == "oneshot" and noise is not None and noise > NOISE_FLOOR_ONESHOT and not texture:
        reasons.append(f"noise floor {noise:.1f} dBFS > {NOISE_FLOOR_ONESHOT}")
    if kind == "oneshot" and flat > FLAT_TOP_LIMIT:
        reasons.append(f"{flat} flat topped runs (limiter crushed)")
    if loudness > LOUDNESS_CEILING[kind]:
        reasons.append(f"loudness {loudness:.1f} LUFS > {LOUDNESS_CEILING[kind]} ({kind})")
    return {
        "file": str(path), "kind": kind, "duration": round(duration, 3),
        "peak_dbfs": round(db(peak), 1), "true_peak_dbtp": round(true_peak, 1),
        "clipped": clipped, "flat_tops": flat, "noise_floor_dbfs": None if noise is None else round(noise, 1),
        "snr_db": None if snr is None else round(snr, 1),
        "crest_db": None if crest is None else round(crest, 1),
        "quiet_rms_dbfs": None if quiet is None else round(quiet, 1), "integrated_lufs": round(integrated, 1),
        "max_momentary_lufs": round(momentary, 1), "loudness_lufs": round(loudness, 1),
        "verdict": "FAIL" if reasons else "PASS", "reasons": reasons, "exempt": texture,
    }


def fmt(v) -> str:
    return "n/a" if v is None else f"{v:.1f}"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=None)
    ap.add_argument("--json", default=None)
    ap.add_argument("files", nargs="*")
    ap.add_argument("--selftest", action="store_true")
    args = ap.parse_args()
    if args.selftest:
        rng = np.random.default_rng(1)
        for level in (-30.0, -50.0, -70.0):
            noise = rng.standard_normal(44100) * 10 ** (level / 20.0)
            print(f"white noise at {level} dBFS RMS reads {broadband_floor(noise, 44100):.1f}")
        t = np.arange(44100) / 44100.0
        tone = 0.5 * np.sin(2 * np.pi * 880 * t) + 0.3 * np.sin(2 * np.pi * 1760 * t)
        print(f"a clean two partial tone reads {broadband_floor(tone, 44100):.1f}")
        short = rng.standard_normal(4410) * 10 ** (-50.0 / 20.0)
        print(f"0.1 s of white noise at -50.0 dBFS RMS reads {broadband_floor(short, 44100):.1f}")
        hit = np.exp(-t * 40) * np.sin(2 * np.pi * 300 * t) * 0.8
        print(f"a clean decaying knock reads {broadband_floor(hit, 44100):.1f}")
        return 0
    repo = Path(__file__).resolve().parent.parent
    if args.files:
        files = []
        for f in map(Path, args.files):
            if f.is_dir():
                files += sorted(p for p in f.rglob("*") if p.suffix.lower() in EXTS)
            else:
                files.append(f)
    else:
        root = Path(args.root) if args.root else repo / "game"
        files = sorted(p for p in root.rglob("*") if p.suffix.lower() in EXTS
                       and ".godot" not in p.parts and p.is_file())
    rows = [measure(f) for f in files]
    failed = 0
    print(f"{'verdict':7} {'file':48} {'kind':7} {'dur':>6} {'peak':>6} {'TP':>6} "
          f"{'clip':>5} {'flat':>5} {'floor':>7} {'crest':>6} {'LUFS':>6}")
    for r in rows:
        name = r["file"]
        try:
            name = str(Path(name).resolve().relative_to(repo / "game" / "assets" / "audio"))
        except ValueError:
            pass
        print(f"{r['verdict']:7} {name:48} {r['kind']:7} {r['duration']:6.2f} "
              f"{r['peak_dbfs']:6.1f} {r['true_peak_dbtp']:6.1f} {r['clipped']:5d} "
              f"{r['flat_tops']:5d} {fmt(r['noise_floor_dbfs']):>7} {fmt(r['crest_db']):>6} "
              f"{r['loudness_lufs']:6.1f}"
              + (("  <- " + "; ".join(r["reasons"])) if r["reasons"] else ""))
        failed += r["verdict"] == "FAIL"
    print(f"AUDIO_AUDIT files={len(rows)} failed={failed}")
    if args.json:
        Path(args.json).write_text(json.dumps(rows, indent=1))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
