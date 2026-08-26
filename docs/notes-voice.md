# Voice line probe: Twilight Sparkle (Task 9, Phase 0)

## Summary

Generated one Twilight Sparkle voice line — "Welcome to the ranch! I'm so
excited to meet you!" — via a hosted, no-install RVC (Retrieval-based Voice
Conversion) pipeline, using a community-trained Pony Preservation Project
(PPP) model for the voice, and Microsoft Edge neural TTS as the base take.
Output: `game/assets/audio/voice/twilight/greeting_01.wav` (44.1kHz mono,
16-bit PCM, 4.64s).

**Quality verdict: pending owner listen.** Objective observations below;
shippable/usable-but-meh/bad is the owner's call once they've heard it.

## Tool / route used

Docker is available on this machine, but a full Hay Say install
(`hydrusbeta/hay_say_ui`) pulls ~49GB of Docker images and was ruled
out-of-scope for a single-line probe. Per a hosted-first ruling, remote
inference was tried before any local install, and it worked — so no Docker
images and no local RVC install were needed at all.

**Route: Edge TTS (source audio) -> Ultimate RVC hosted Space (voice
conversion) -> ffmpeg (resample).**

- Base take: `edge-tts` (Microsoft neural TTS, pip-installable, no API key),
  voice `en-US-AriaNeural`, generated locally in ~1s.
- Voice conversion: [Ultimate RVC](https://huggingface.co/spaces/JackismyShephard/ultimate-rvc),
  a live, free `cpu-basic` Hugging Face Space (185 likes, actively
  maintained) that wraps RVC behind a Gradio app. Its API was driven
  programmatically with the `gradio_client` Python package (no browser
  needed) — Gradio Spaces expose every UI action as a named API endpoint.
- Voice model: **PPP RVC weights** from
  [`therealvul/RVCv2`](https://huggingface.co/therealvul/RVCv2), folder
  `TwilightSparkle-Titan` (`TwilightS1-3_Titan_e200_s48800.pth`, 57MB, +
  matching `.index` file, 31MB — trained on Seasons 1-3 dialogue). This is a
  community fan-trained model, not an official/licensed voice.
- Resample to spec: `ffmpeg -ar 44100 -ac 1`.

Total new software installed: a Python venv with `edge-tts`, `gradio_client`,
`soundfile`, `librosa` (all pip, no sudo, no Docker, no GB-scale downloads).
The only binary weights pulled were the ~88MB Twilight model (`.pth` +
`.index`) from Hugging Face.

## Reproduction steps (for ~100 lines in Phase 4, if this route is chosen)

```bash
# One-time setup
python3 -m venv venv && source venv/bin/activate
pip install edge-tts gradio_client soundfile

# One-time: fetch the voice model (reusable across all lines)
mkdir -p model
curl -sL -o model/Twilight.pth \
  "https://huggingface.co/therealvul/RVCv2/resolve/main/TwilightSparkle-Titan/TwilightS1-3_Titan_e200_s48800.pth"
curl -sL -o model/Twilight.index \
  "https://huggingface.co/therealvul/RVCv2/resolve/main/TwilightSparkle-Titan/added_IVF256_Flat_nprobe_1_TwilightS1-3_Titan_v2.index"
```

```python
# One-time: register the model with the hosted Space (persists across calls
# for the lifetime of the Space instance — but is NOT guaranteed permanent;
# re-check with the "Voice model choices" query below before a big batch run)
from gradio_client import Client, handle_file
client = Client("JackismyShephard/ultimate-rvc")
client.predict([handle_file("model/Twilight.pth"), handle_file("model/Twilight.index")],
                "Twilight", api_name="/_wrapped_fn_9")

# IMPORTANT gotcha: call this once per fresh Client session before converting,
# or the "Voice model" dropdown will validate against an empty choice list
# and error with "Value: Twilight is not in the list of choices: []" even
# though the model is uploaded and persisted server-side.
client.predict(api_name="/_init_dropdowns")

# Per line: generate source TTS, then convert
import subprocess
subprocess.run(["edge-tts", "--voice", "en-US-AriaNeural", "--text", LINE_TEXT,
                 "--write-media", "source.mp3"], check=True)
subprocess.run(["ffmpeg", "-y", "-i", "source.mp3", "-ar", "44100", "-ac", "1",
                 "source.wav"], check=True)

job = client.submit(
    param_0=handle_file("source.wav"), param_2="Twilight",
    param_3=0.0, param_4=0.0, param_5="rmvpe", param_6=0.3, param_7=1.0,
    param_8=0.33, param_9=False, param_10=False, param_11=1.0, param_12=False,
    param_13=155.0, param_14=True, param_15=0.7, param_16="contentvec",
    param_17=None, param_18=0, api_name="/partial_44",
)
# job.result() blocks until done; poll job.status() for queue rank/ETA.
out_path = job.result()
subprocess.run(["ffmpeg", "-y", "-i", out_path, "-ar", "44100", "-ac", "1",
                 f"game/assets/audio/voice/twilight/{category}_{nn:02d}.wav"], check=True)
```

Model-folder options seen under `therealvul/RVCv2` for Twilight: `TwilightS1`
(speaking, larger 427MB index), `TwilightSparkle-Titan` (speaking, trained on
S1-3, smaller 31MB index — used here), `TwilightSingingv2` /
`TwilightSingingv2.1` (singing models, not used).

## Time cost per line

This is the load-bearing number for the go/no-go call, and it was highly
variable — **the RVC inference itself is fast; the bottleneck is the shared
public queue on the free `cpu-basic` Space:**

| Stage | Time |
|---|---|
| edge-tts source generation | ~1s |
| Model upload (one-time, not per-line) | ~35s |
| Actual RVC conversion (once dequeued) | **~15s** (PROCESSING to FINISHED, observed directly) |
| Queue wait before conversion starts | **highly variable — observed 40s, 26.5 min (with a client-side bug), and one run stuck for 40+ min with no resolution before being killed** |
| **Successful end-to-end run (this line)** | **~17.4 minutes wall clock** (queue rank 4-of-5 down to processing) |
| ffmpeg resample | <1s |

Four attempts were made before one succeeded cleanly:
1. Blocking `client.predict()` with no progress visibility — killed after
   ~20 min with zero output; couldn't tell if it was even queued.
2. `client.submit()` + status polling — resolved after 26.5 min, but with
   an error: `Value: Twilight is not in the list of choices: []`. Root
   cause: uploading a model doesn't populate the "Voice model" dropdown's
   validated choice list for a *fresh* client session; you must call the
   `/_init_dropdowns` refresh endpoint first (see gotcha above — this was a
   fixable client-side bug, not a Space defect).
3. Same script with the fix applied, confirmed "Twilight" in the refreshed
   choice list, submitted — sat at queue rank 0 for 40+ minutes with no
   further status updates (via SSE) and was killed. Never resolved either
   way; unclear if it was a stalled worker or a lost status-stream event.
4. Retry of the same, fixed script — queued behind 4 other jobs, succeeded
   in ~17.4 minutes total, with the actual RVC pass taking ~15s once it
   started.

The Space is public (185 likes) and its "Output audio files" listing showed
several other users' completed song-cover conversions from the same
session window, confirming genuine multi-user contention on the shared
`cpu-basic` worker, not a broken Space.

## Objective audio observations (not a shippability call)

- No clipping: peak amplitude 0.52 (of 1.0), RMS 0.036 — reasonable
  headroom, would benefit from normalization/mastering if used in-game.
- Duration held closely to the source take (4.64s converted vs 4.66s
  source) — RVC did not introduce audible time-stretching.
- Pitch (via `librosa.pyin`): voiced-frame mean F0 ≈ 220Hz, range
  132-324Hz — consistent with a young adult female speaking voice and in
  the right register for the character. 4 of 196 voiced frames showed a
  pitch jump >50Hz frame-to-frame; could be natural inflection on the
  exclamations in the line, or a minor RVC pitch-tracking artifact —
  worth a critical listen on the emphasized words ("Welcome", "excited").
- ~0.2s of lead-in silence and ~0.9s of trailing tail/silence in the clip;
  fine as-is but would want trimming in a batch pipeline.
- Similarity to the character: not independently scored here (no reference
  embedding comparison run) — this is exactly the kind of judgment call
  that needs the owner's ear, not an automated metric.

## Go/no-go: ~100 lines in Phase 4 via this route

**No-go on the public Ultimate RVC Space as-is for bulk generation.** The
RVC conversion itself is cheap (~15s/line), but the free shared queue made
a *single* line take anywhere from under a minute to 40+ minutes
unresolved. At even a conservative 15-20 min/line average, ~100 lines is
2.5-3+ days of wall-clock queue-waiting, with real risk of jobs silently
stalling (as seen in attempt 3) and needing manual retries. This is not
something to leave unattended for a batch job.

Options going into Phase 4, roughly in order of likely cost/effort:

1. **Local install of the same pipeline** (no queue): the `ultimate-rvc`
   PyPI package (the same code the Space runs) can run this offline —
   `pip install ultimate-rvc`, CPU-only Torch — sidestepping the shared
   queue entirely. Not attempted here (out of scope for a single-probe
   task and its default dependency set pulls in `onnxruntime-gpu`,
   `audio-separator`, `tensorboard`, etc. that would need pruning/CPU-only
   overrides first) but is the natural next step if the owner likes the
   voice-conversion approach and wants to avoid both Docker and ElevenLabs
   cost. Estimate: multi-hundred-MB to low-GB pip install, one-time.
2. **Full Hay Say Docker stack** (49GB) — only if the above proves
   impractical; explicitly gated behind owner sign-off per this task's
   scope.
3. **ElevenLabs (paid)**: not benchmarked here, but has no queue-congestion
   risk and per-character voice consistency is a solved problem there.
   Worth comparing cost against the engineering time spent taming a local
   RVC pipeline.

The community PPP models (`therealvul/RVCv2`) cover most of the Mane 6
plus many side characters, so voice *coverage* is not blocking — the open
question is entirely about generation *throughput* and *reliability* for
Phase 4's ~100-line volume, which argues for option 1 (local, queue-free)
over repeating this hosted route at scale.
