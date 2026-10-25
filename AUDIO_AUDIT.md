# Audio audit, 2026-10-24

The owner's playtest note: "The running sound is noisy and bad. Other sounds were bad too."
Every audio file in `game/` was measured with ffmpeg by `tools/audio_audit.py`, before and
after the fix. This file lists every one of them. Re-run it any time with
`python3 -I tools/audio_audit.py` (exit 0 = every file passes); `game/test/test_audio_audit.gd`
runs it as part of the GUT suite.

## What is measured, and the pass rules

| Column | What it is | Fails when |
|---|---|---|
| peak / TP | sample peak dBFS / true peak dBTP (ffmpeg ebur128 peak=true, 4x oversampled) | either is over -1.0 |
| clip | samples at or above 0.999 of full scale | any |
| floor | broadband noise floor, dBFS: per frequency bin the 10th percentile of its power over time (minimum statistics), each bin capped at its octave's median so a ringing partial is not counted as noise, summed over 100 Hz to 16 kHz. Calibrated with `--selftest`: white noise at -50 dBFS RMS reads -51.7, a clean two partial tone at -6 dBFS reads -67, a decaying knock -130. Fades (the last 15%) and digital silence are left out. n/a for a tick too short to have room around it (under about 12 frames). | over -60 dBFS for a one shot. Beds and music are noise by design and only report it. Two one shots whose whole body IS a sustained noise texture (the beam's charge hum, the race cheer) are listed in the script's `TEXTURES` table and are exempt from this rule only. |
| loud | one shots: max EBU momentary (400 ms) loudness of the file padded with a second of silence; beds and music: integrated LUFS | over -12 (one shot), -22 (bed), -17 (music) |
| flat tops | runs of 3+ samples pinned at the file's own peak (a limiter or a clip squaring off the wave), in the script's console output | more than 4 in a one shot |

Mix targets (tools/sound_manifest.txt): beds -24 LUFS, world and casino SFX -18, UI -20,
music -20 to -23.

## Summary

- **Before: 58 files, 23 fail. After: 70 files, 0 fail.**
- **The hoofsteps (the "running sound").** All eight (`hoofsteps_grass_1..4`,
  `hoofsteps_hard_1..4`) failed on noise: floors of -35 to -39 dBFS (grass) and -31 to -49
  (hard). They were BBC field recordings cut at a silence threshold that sat UNDER the take's
  own room tone, wind and traffic (so several "strikes" were windows of background with no
  hoof in them: `hoofsteps_grass_4` is 0.35 s of flat -24 dB envelope, peak only 14 dB over
  its median), then lifted by up to 17 dB, noise and all. Removed. Replaced by twenty clean
  Kenney Impact Sounds takes (CC0), four per surface: grass, dirt, wood, stone, metal, with
  floors of -74 to -143 dBFS, triggered on the animation's footfalls (see
  `docs/playtest_fixes/audio.md`).
- **The same mistake in nine more one shots.** Every BBC one shot cut out of a long take and
  lifted with gain_db failed the floor rule (gate creak, letterbox, letter fold, stamp,
  bucket thud, cash register coins, fruit machine tick and stop, roulette settle; the
  roulette ratchet is too short to measure but is a 30 ms window lifted 27 dB of the same
  take). All replaced with clean CC0 Kenney recordings.
- **Three Kenney interface ticks were noisy synth textures** (`ui_back` -59, `ui_open` -52,
  `ui_denied` -45 dBFS floors): swapped for clean siblings in the same pack.
- **The one sanctioned neigh** was the loudest one shot in the game (momentary -11.6 LUFS)
  over a -55 dBFS floor: kept (owner directive), levelled to -17 and gated, floor now -66.
- **Too loud, everywhere: a pipeline bug.** Every bed and every music track measured 1.4 to
  1.6 LU over its own loudness target (beds -22.6 against -24; the race crowd and gallop
  over the bed ceiling). Cause: `tools/fetch_sounds.sh` ended every chain with
  `alimiter=limit=0.84`, and alimiter's default `level=true` rescales its output so the
  limit lands at full scale, which adds 20*log10(1/0.84) = +1.5 dB to every file AFTER the
  loudness pass. Fixed (`level=false`), every file re-processed from source: beds now land on
  -24.0 to -24.3, music on its targets. This is the "ambience is too loud" note in a number.
- **No file anywhere clips** (0 clipped samples before and after), and every file is under
  -1 dBFS sample and true peak. The new `mgain=` loudness pass never drives the limiter: it
  stops the gain at -3 dBTP, so no transient is squared off.

## Mix knobs that moved (game/systems/sound.gd LIBRARY volume_db)

The replaced one shots carry no room tone, so the old files' measured loudness overstated
the event under it. These put the event back near where the owner tuned it:
gate_open 0 -> +3, mail_open 0 -> +2, mail_stamp 0 -> -3, coins_grant 0 -> +6, reel_tick
-14 -> -10, reel_stop -4 -> 0, wheel_settle -3 -> +3. Hoofsteps: grass -8, dirt, wood and
metal -9, stone -6 (the sharpest tap stops 4 to 6 LU under its loudness target at the -3 dBTP
cap, so the mix lifts it instead), each play rolling +/-1.5 dB and pitch 0.94 to 1.07, never
the same take twice running. Every unchanged gain_db row is 1.5 dB quieter than before (the
limiter fix); the owner's ear knobs are otherwise untouched.

## Sources and licences

Kenney (kenney.nl) Impact Sounds, RPG Audio, Casino Audio, Interface Sounds: CC0.
OpenGameArt pop and PositiveChoice jingle: CC0. Kevin MacLeod (incompetech.com) music:
CC-BY 4.0. BBC Sound Effects (beds, beam hum, race crowd/gallop/cheer, the neigh): RemArc
licence, private build only (DECISIONS.md 2026-10-22). Exact URLs and pack members per file
are in `tools/sound_manifest.txt`; credits in `CREDITS.md`.

## Every file

Before = the files at 512241a; After = this commit. "verdict" is the audit's under the
rules above. Times in seconds are in the console output of the script, not repeated here.

### Ambient beds

| File | Source (licence) | Before: peak / TP | clip | floor | loud | verdict | After: peak / TP | clip | floor | loud | verdict | Action |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `ambient/bed_casino_room.ogg` | BBC SFX `07044043` (BBC RemArc (private build)) | -9.8 / -9.8 | 0 | -32.7 | -22.6 | PASS | -11.2 / -11.2 | 0 | -34.2 | -24.1 | PASS | kept; re-processed with the limiter fix (alimiter level=false: 1.5 dB under the old auto level) |
| `ambient/bed_dawn_chorus.ogg` | BBC SFX `NHU05104268` (BBC RemArc (private build)) | -9.9 / -9.9 | 0 | -40.1 | -22.7 | PASS | -11.7 / -11.7 | 0 | -41.6 | -24.3 | PASS | kept; re-processed with the limiter fix (alimiter level=false: 1.5 dB under the old auto level) |
| `ambient/bed_day_meadow.ogg` | BBC SFX `07013003` (BBC RemArc (private build)) | -10.1 / -10.1 | 0 | -35.9 | -22.6 | PASS | -11.4 / -11.3 | 0 | -37.5 | -24.1 | PASS | kept; re-processed with the limiter fix (alimiter level=false: 1.5 dB under the old auto level) |
| `ambient/bed_dusk_calm.ogg` | BBC SFX `07030055` (BBC RemArc (private build)) | -6.2 / -6.2 | 0 | -31.0 | -22.6 | PASS | -7.2 / -7.1 | 0 | -32.6 | -24.1 | PASS | kept; re-processed with the limiter fix (alimiter level=false: 1.5 dB under the old auto level) |
| `ambient/bed_night_insects.ogg` | BBC SFX `NHU05035029` (BBC RemArc (private build)) | -10.2 / -10.2 | 0 | -46.9 | -22.8 | PASS | -11.9 / -11.9 | 0 | -48.4 | -24.3 | PASS | kept; re-processed with the limiter fix (alimiter level=false: 1.5 dB under the old auto level) |
| `ambient/bed_night_owl.ogg` | BBC SFX `NHU05053051` (BBC RemArc (private build)) | -3.2 / -2.3 | 0 | -36.8 | -28.9 | PASS | -4.5 / -3.8 | 0 | -38.3 | -30.4 | PASS | kept; re-processed with the limiter fix (alimiter level=false: 1.5 dB under the old auto level) |
| `ambient/bed_strip_crowd.ogg` | BBC SFX `07072151` (BBC RemArc (private build)) | -7.4 / -7.4 | 0 | -31.8 | -22.6 | PASS | -9.1 / -9.1 | 0 | -33.3 | -24.1 | PASS | kept; re-processed with the limiter fix (alimiter level=false: 1.5 dB under the old auto level) |
| `ambient/bed_strip_hum.ogg` | BBC SFX `07059070` (BBC RemArc (private build)) | -13.3 / -13.3 | 0 | -28.5 | -22.5 | PASS | -14.6 / -14.6 | 0 | -30.0 | -24.0 | PASS | kept; re-processed with the limiter fix (alimiter level=false: 1.5 dB under the old auto level) |
| `ambient/bed_wind_soft.ogg` | BBC SFX `07027032` (BBC RemArc (private build)) | -3.7 / -3.7 | 0 | -29.0 | -22.6 | PASS | -5.3 / -5.3 | 0 | -30.6 | -24.1 | PASS | kept; re-processed with the limiter fix (alimiter level=false: 1.5 dB under the old auto level) |

### World

| File | Source (licence) | Before: peak / TP | clip | floor | loud | verdict | After: peak / TP | clip | floor | loud | verdict | Action |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `world/bloom_fanfare.wav` | OpenGameArt `PositiveChoice.ogg` (CC0) | -5.1 / -5.1 | 0 | -87.2 | -12.8 | PASS | -6.6 / -6.6 | 0 | -88.7 | -14.3 | PASS | kept; re-processed with the limiter fix (alimiter level=false: 1.5 dB under the old auto level) |
| `world/capture_charge.ogg` | BBC SFX `07043314` (BBC RemArc (private build)) | -8.4 / -8.4 | 0 | -19.0 | -19.2 | PASS | -10.1 / -10.1 | 0 | -20.6 | -20.7 | PASS | kept; re-processed with the limiter fix (alimiter level=false: 1.5 dB under the old auto level) Noise floor not gated: a held generator hum under the beam (BBC 07043314, sped up): the hum is the sound, and it plays on a loop voice |
| `world/capture_success.wav` | Kenney Interface Sounds `confirmation_001.ogg` (CC0) | -5.6 / -5.6 | 0 | -72.5 | -17.9 | PASS | -7.1 / -7.1 | 0 | -74.0 | -19.5 | PASS | kept; re-processed with the limiter fix (alimiter level=false: 1.5 dB under the old auto level) |
| `world/coins_grant.wav` | Kenney Casino Audio `chips-handle-1.ogg` (CC0) | -2.5 / -2.4 | 0 | -26.0 | -16.3 | FAIL | -3.3 / -3.0 | 0 | -71.3 | -27.6 | PASS | REPLACED/FIXED: floor -26 dBFS: the register take's shop room under the coins. Kenney Casino Audio chips-handle-1 (CC0), a handful of coin chips. |
| `world/delivery_thud.wav` | Kenney Impact Sounds `impactSoft_heavy_003.ogg` (CC0) | -9.4 / -9.4 | 0 | -39.4 | -22.4 | FAIL | -4.1 / -4.1 | 0 | -97.5 | -22.0 | PASS | REPLACED/FIXED: floor -39 dBFS (the bucket take's room). Kenney Impact Sounds impactSoft_heavy_003 (CC0), a crate set down. |
| `world/gate_open.wav` | Kenney Rpg Audio `creak1.ogg` (CC0) | -7.2 / -7.2 | 0 | -32.4 | -14.1 | FAIL | -6.6 / -6.6 | 0 | -66.9 | -20.0 | PASS | REPLACED/FIXED: broadband noise floor -32 dBFS (the creak take's room). Kenney RPG Audio creak1 (CC0). |
| `world/hoof_dirt_1.wav` | Kenney Impact Sounds `footstep_snow_000.ogg` (CC0) | -- | -- | -- | -- | -- | -4.9 / -4.9 | 0 | -142.3 | -27.0 | PASS | NEW: per surface hoofstep, triggered on the clip's footfalls |
| `world/hoof_dirt_2.wav` | Kenney Impact Sounds `footstep_snow_001.ogg` (CC0) | -- | -- | -- | -- | -- | -8.0 / -8.0 | 0 | -143.4 | -27.0 | PASS | NEW: per surface hoofstep, triggered on the clip's footfalls |
| `world/hoof_dirt_3.wav` | Kenney Impact Sounds `footstep_snow_002.ogg` (CC0) | -- | -- | -- | -- | -- | -7.7 / -7.7 | 0 | -140.5 | -27.0 | PASS | NEW: per surface hoofstep, triggered on the clip's footfalls |
| `world/hoof_dirt_4.wav` | Kenney Impact Sounds `footstep_snow_004.ogg` (CC0) | -- | -- | -- | -- | -- | -4.0 / -4.0 | 0 | -138.1 | -27.0 | PASS | NEW: per surface hoofstep, triggered on the clip's footfalls |
| `world/hoof_grass_1.wav` | Kenney Impact Sounds `footstep_grass_000.ogg` (CC0) | -- | -- | -- | -- | -- | -3.0 / -3.0 | 0 | -94.5 | -30.6 | PASS | NEW: per surface hoofstep, triggered on the clip's footfalls |
| `world/hoof_grass_2.wav` | Kenney Impact Sounds `footstep_grass_001.ogg` (CC0) | -- | -- | -- | -- | -- | -3.1 / -3.0 | 0 | -96.2 | -29.8 | PASS | NEW: per surface hoofstep, triggered on the clip's footfalls |
| `world/hoof_grass_3.wav` | Kenney Impact Sounds `footstep_grass_002.ogg` (CC0) | -- | -- | -- | -- | -- | -3.0 / -3.0 | 0 | -95.4 | -30.3 | PASS | NEW: per surface hoofstep, triggered on the clip's footfalls |
| `world/hoof_grass_4.wav` | Kenney Impact Sounds `footstep_grass_004.ogg` (CC0) | -- | -- | -- | -- | -- | -3.0 / -3.0 | 0 | -99.2 | -30.4 | PASS | NEW: per surface hoofstep, triggered on the clip's footfalls |
| `world/hoof_metal_1.wav` | Kenney Impact Sounds `impactMetal_light_000.ogg` (CC0) | -- | -- | -- | -- | -- | -8.1 / -8.1 | 0 | -97.8 | -26.0 | PASS | NEW: per surface hoofstep, triggered on the clip's footfalls |
| `world/hoof_metal_2.wav` | Kenney Impact Sounds `impactMetal_light_001.ogg` (CC0) | -- | -- | -- | -- | -- | -7.2 / -7.2 | 0 | -98.7 | -26.0 | PASS | NEW: per surface hoofstep, triggered on the clip's footfalls |
| `world/hoof_metal_3.wav` | Kenney Impact Sounds `impactMetal_light_002.ogg` (CC0) | -- | -- | -- | -- | -- | -7.0 / -6.9 | 0 | -98.9 | -26.0 | PASS | NEW: per surface hoofstep, triggered on the clip's footfalls |
| `world/hoof_metal_4.wav` | Kenney Impact Sounds `impactMetal_light_004.ogg` (CC0) | -- | -- | -- | -- | -- | -6.2 / -6.0 | 0 | -97.7 | -26.0 | PASS | NEW: per surface hoofstep, triggered on the clip's footfalls |
| `world/hoof_stone_1.wav` | Kenney Impact Sounds `footstep_concrete_000.ogg` (CC0) | -- | -- | -- | -- | -- | -3.0 / -3.0 | 0 | -80.2 | -30.6 | PASS | NEW: per surface hoofstep, triggered on the clip's footfalls |
| `world/hoof_stone_2.wav` | Kenney Impact Sounds `footstep_concrete_001.ogg` (CC0) | -- | -- | -- | -- | -- | -3.1 / -3.0 | 0 | -74.9 | -31.9 | PASS | NEW: per surface hoofstep, triggered on the clip's footfalls |
| `world/hoof_stone_3.wav` | Kenney Impact Sounds `footstep_concrete_002.ogg` (CC0) | -- | -- | -- | -- | -- | -3.0 / -3.0 | 0 | -74.4 | -32.0 | PASS | NEW: per surface hoofstep, triggered on the clip's footfalls |
| `world/hoof_stone_4.wav` | Kenney Impact Sounds `footstep_concrete_003.ogg` (CC0) | -- | -- | -- | -- | -- | -3.0 / -3.0 | 0 | -84.2 | -31.1 | PASS | NEW: per surface hoofstep, triggered on the clip's footfalls |
| `world/hoof_wood_1.wav` | Kenney Impact Sounds `impactWood_light_000.ogg` (CC0) | -- | -- | -- | -- | -- | -3.0 / -3.0 | 0 | -84.1 | -26.9 | PASS | NEW: per surface hoofstep, triggered on the clip's footfalls |
| `world/hoof_wood_2.wav` | Kenney Impact Sounds `impactWood_light_002.ogg` (CC0) | -- | -- | -- | -- | -- | -3.0 / -3.0 | 0 | -87.3 | -26.7 | PASS | NEW: per surface hoofstep, triggered on the clip's footfalls |
| `world/hoof_wood_3.wav` | Kenney Impact Sounds `impactWood_light_003.ogg` (CC0) | -- | -- | -- | -- | -- | -3.0 / -3.0 | 0 | -94.9 | -29.0 | PASS | NEW: per surface hoofstep, triggered on the clip's footfalls |
| `world/hoof_wood_4.wav` | Kenney Impact Sounds `impactWood_light_004.ogg` (CC0) | -- | -- | -- | -- | -- | -3.0 / -3.0 | 0 | -91.9 | -29.4 | PASS | NEW: per surface hoofstep, triggered on the clip's footfalls |
| `world/hoofsteps_grass_1.wav` | BBC SFX (removed) | -12.7 / -12.7 | 0 | -39.3 | -31.6 | FAIL | -- | -- | -- | -- | -- | REMOVED: replaced by the per surface hoof_* sets (noise floor, see the hoofsteps block in tools/sound_manifest.txt) |
| `world/hoofsteps_grass_2.wav` | BBC SFX (removed) | -13.6 / -13.3 | 0 | -35.1 | -31.4 | FAIL | -- | -- | -- | -- | -- | REMOVED: replaced by the per surface hoof_* sets (noise floor, see the hoofsteps block in tools/sound_manifest.txt) |
| `world/hoofsteps_grass_3.wav` | BBC SFX (removed) | -14.9 / -14.9 | 0 | -37.8 | -29.4 | FAIL | -- | -- | -- | -- | -- | REMOVED: replaced by the per surface hoof_* sets (noise floor, see the hoofsteps block in tools/sound_manifest.txt) |
| `world/hoofsteps_grass_4.wav` | BBC SFX (removed) | -12.4 / -12.4 | 0 | -36.3 | -27.1 | FAIL | -- | -- | -- | -- | -- | REMOVED: replaced by the per surface hoof_* sets (noise floor, see the hoofsteps block in tools/sound_manifest.txt) |
| `world/hoofsteps_hard_1.wav` | BBC SFX (removed) | -7.6 / -7.6 | 0 | -48.6 | -30.8 | FAIL | -- | -- | -- | -- | -- | REMOVED: replaced by the per surface hoof_* sets (noise floor, see the hoofsteps block in tools/sound_manifest.txt) |
| `world/hoofsteps_hard_2.wav` | BBC SFX (removed) | -7.9 / -7.9 | 0 | -31.1 | -24.9 | FAIL | -- | -- | -- | -- | -- | REMOVED: replaced by the per surface hoof_* sets (noise floor, see the hoofsteps block in tools/sound_manifest.txt) |
| `world/hoofsteps_hard_3.wav` | BBC SFX (removed) | -7.7 / -7.7 | 0 | -38.6 | -28.0 | FAIL | -- | -- | -- | -- | -- | REMOVED: replaced by the per surface hoof_* sets (noise floor, see the hoofsteps block in tools/sound_manifest.txt) |
| `world/hoofsteps_hard_4.wav` | BBC SFX (removed) | -8.0 / -8.0 | 0 | -46.0 | -32.5 | FAIL | -- | -- | -- | -- | -- | REMOVED: replaced by the per surface hoof_* sets (noise floor, see the hoofsteps block in tools/sound_manifest.txt) |
| `world/mail_arrive.wav` | Kenney Rpg Audio `metalClick.ogg` (CC0) | -12.6 / -12.6 | 0 | -40.0 | -27.5 | FAIL | -3.1 / -3.0 | 0 | -60.4 | -26.6 | PASS | REPLACED/FIXED: floor -40 dBFS: the BBC take was cut at a threshold under its own room tone and lifted 7 dB. Kenney RPG Audio metalClick (CC0), a latch clack. |
| `world/mail_open.wav` | Kenney Rpg Audio `bookFlip1.ogg` (CC0) | -1.9 / -1.6 | 0 | -39.3 | -24.3 | FAIL | -3.4 / -3.0 | 0 | -72.3 | -27.6 | PASS | REPLACED/FIXED: floor -39 dBFS (the sanding take's own bed under the fold). Kenney RPG Audio bookFlip1 (CC0), a paper turn. |
| `world/mail_stamp.wav` | Kenney Impact Sounds `impactGeneric_light_000.ogg` (CC0) | -10.6 / -10.2 | 0 | -57.9 | -34.6 | FAIL | -3.0 / -3.0 | 0 | -73.7 | -27.8 | PASS | REPLACED/FIXED: floor -58 dBFS (the ticket machine take lifted from a -40 dB window). Kenney Impact Sounds impactGeneric_light_000 (CC0), a dry thunk. |
| `world/neigh_real.wav` | BBC SFX `NHU05078167` (BBC RemArc (private build)) | -2.6 / -2.6 | 0 | -55.4 | -11.6 | FAIL | -8.0 / -8.0 | 0 | -65.9 | -17.0 | PASS | REPLACED/FIXED: the one sanctioned neigh stays (owner directive), but it was the loudest one shot in the game (max momentary -11.6 LUFS) over a -55 floor: levelled to -17 and gated. |
| `world/scoop_pop.wav` | OpenGameArt `pop.ogg` (CC0) | -3.3 / -3.3 | 0 | -64.7 | -23.0 | PASS | -4.8 / -4.8 | 0 | -66.2 | -24.5 | PASS | kept; re-processed with the limiter fix (alimiter level=false: 1.5 dB under the old auto level) |
| `world/sparkle.wav` | Kenney Interface Sounds `glass_001.ogg` (CC0) | -5.5 / -5.5 | 0 | -93.9 | -24.0 | PASS | -7.0 / -7.0 | 0 | -96.1 | -25.5 | PASS | kept; re-processed with the limiter fix (alimiter level=false: 1.5 dB under the old auto level) |

### Casino

| File | Source (licence) | Before: peak / TP | clip | floor | loud | verdict | After: peak / TP | clip | floor | loud | verdict | Action |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `casino/card_flip.wav` | Kenney Casino Audio `card-place-1.ogg` (CC0) | -3.2 / -3.1 | 0 | -66.9 | -26.8 | PASS | -4.7 / -4.6 | 0 | -68.4 | -28.3 | PASS | kept; re-processed with the limiter fix (alimiter level=false: 1.5 dB under the old auto level) |
| `casino/card_slide_1.wav` | Kenney Casino Audio `card-slide-1.ogg` (CC0) | -4.0 / -4.0 | 0 | -66.2 | -27.7 | PASS | -5.5 / -5.5 | 0 | -67.7 | -29.2 | PASS | kept; re-processed with the limiter fix (alimiter level=false: 1.5 dB under the old auto level) |
| `casino/card_slide_2.wav` | Kenney Casino Audio `card-slide-2.ogg` (CC0) | -3.2 / -3.2 | 0 | -62.9 | -27.7 | PASS | -4.7 / -4.7 | 0 | -64.4 | -29.2 | PASS | kept; re-processed with the limiter fix (alimiter level=false: 1.5 dB under the old auto level) |
| `casino/chip_clink_1.wav` | Kenney Casino Audio `chip-lay-1.ogg` (CC0) | -3.9 / -3.3 | 0 | -67.7 | -28.2 | PASS | -5.4 / -4.9 | 0 | -69.2 | -29.7 | PASS | kept; re-processed with the limiter fix (alimiter level=false: 1.5 dB under the old auto level) |
| `casino/chip_clink_2.wav` | Kenney Casino Audio `chip-lay-2.ogg` (CC0) | -4.8 / -3.1 | 0 | -64.1 | -32.5 | PASS | -6.3 / -4.7 | 0 | -65.6 | -34.0 | PASS | kept; re-processed with the limiter fix (alimiter level=false: 1.5 dB under the old auto level) |
| `casino/chip_clink_3.wav` | Kenney Casino Audio `chip-lay-3.ogg` (CC0) | -4.2 / -4.2 | 0 | -61.1 | -29.9 | PASS | -5.7 / -5.7 | 0 | -62.7 | -31.4 | PASS | kept; re-processed with the limiter fix (alimiter level=false: 1.5 dB under the old auto level) |
| `casino/race_cheer.wav` | BBC SFX `07035069` (BBC RemArc (private build)) | -5.2 / -5.2 | 0 | -43.9 | -13.4 | PASS | -6.7 / -6.7 | 0 | -45.4 | -14.9 | PASS | kept; re-processed with the limiter fix (alimiter level=false: 1.5 dB under the old auto level) Noise floor not gated: a grandstand cheering (BBC 07035069): a crowd is broadband noise by nature |
| `casino/race_crowd_loop.ogg` | BBC SFX `07035148` (BBC RemArc (private build)) | -7.5 / -7.5 | 0 | -26.9 | -20.6 | FAIL | -9.1 / -9.1 | 0 | -28.4 | -22.1 | PASS | kept; re-processed with the limiter fix (alimiter level=false: 1.5 dB under the old auto level) |
| `casino/race_gallop.ogg` | BBC SFX `07039304` (BBC RemArc (private build)) | -9.8 / -9.8 | 0 | -25.2 | -20.5 | FAIL | -11.5 / -11.5 | 0 | -26.8 | -22.0 | PASS | kept; re-processed with the limiter fix (alimiter level=false: 1.5 dB under the old auto level) |
| `casino/reel_stop.wav` | Kenney Impact Sounds `impactGeneric_light_002.ogg` (CC0) | -5.6 / -5.6 | 0 | -36.3 | -19.5 | FAIL | -3.0 / -3.0 | 0 | -77.5 | -28.9 | PASS | REPLACED/FIXED: floor -36 dBFS, the same take lifted 17 dB. Kenney Impact Sounds impactGeneric_light_002 (CC0). |
| `casino/reel_tick.wav` | Kenney Interface Sounds `click_001.ogg` (CC0) | -5.9 / -5.8 | 0 | -34.5 | -21.0 | FAIL | -3.2 / -3.0 | 0 | -134.6 | -33.7 | PASS | REPLACED/FIXED: floor -35 dBFS: a 0.2 s window of the fruit machine take lifted 24 dB, its motor and room with it. Kenney Interface Sounds click_001 (CC0). |
| `casino/slots_win.wav` | Kenney Interface Sounds `confirmation_002.ogg` (CC0) | -5.7 / -5.7 | 0 | -88.0 | -16.6 | PASS | -7.3 / -7.2 | 0 | -89.7 | -18.1 | PASS | kept; re-processed with the limiter fix (alimiter level=false: 1.5 dB under the old auto level) |
| `casino/wheel_ratchet.wav` | Kenney Interface Sounds `click_003.ogg` (CC0) | -2.9 / -2.9 | 0 | n/a | -27.8 | PASS | -3.0 / -3.0 | 0 | n/a | -31.5 | PASS | REPLACED/FIXED: a 30 ms window of the roulette take lifted 27 dB (too short to have a floor, but every one of its siblings is noise). Kenney Interface Sounds click_003 (CC0). |
| `casino/wheel_settle.wav` | Kenney Casino Audio `die-throw-1.ogg` (CC0) | -5.6 / -5.6 | 0 | -21.1 | -18.8 | FAIL | -3.0 / -3.0 | 0 | -67.5 | -32.6 | PASS | REPLACED/FIXED: floor -21 dBFS: the roulette take lifted 27 dB. Kenney Casino Audio die-throw-1 (CC0), a ball rattling to rest. |

### UI

| File | Source (licence) | Before: peak / TP | clip | floor | loud | verdict | After: peak / TP | clip | floor | loud | verdict | Action |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `ui/ui_back.wav` | Kenney Interface Sounds `minimize_007.ogg` (CC0) | -7.5 / -7.5 | 0 | -59.1 | -31.0 | FAIL | -20.6 / -20.6 | 0 | -95.9 | -30.1 | PASS | REPLACED/FIXED: back_002 measures a -59 dBFS floor, a buzz at the edge of the rule. minimize_007, the same pack's clean falling blip. |
| `ui/ui_confirm.wav` | Kenney Interface Sounds `select_003.ogg` (CC0) | -7.3 / -7.3 | 0 | -155.0 | -22.5 | PASS | -8.8 / -8.8 | 0 | -156.6 | -24.0 | PASS | kept; re-processed with the limiter fix (alimiter level=false: 1.5 dB under the old auto level) |
| `ui/ui_denied.wav` | Kenney Interface Sounds `error_006.ogg` (CC0) | -3.7 / -3.7 | 0 | -45.4 | -24.6 | FAIL | -7.4 / -7.4 | 0 | -102.3 | -25.0 | PASS | REPLACED/FIXED: error_004 is a noise burst (floor -45 dBFS). error_006, a clean two note no. |
| `ui/ui_move.wav` | Kenney Interface Sounds `click_002.ogg` (CC0) | -5.4 / -5.3 | 0 | n/a | -34.2 | PASS | -6.9 / -6.9 | 0 | n/a | -35.8 | PASS | kept; re-processed with the limiter fix (alimiter level=false: 1.5 dB under the old auto level) |
| `ui/ui_open.wav` | Kenney Interface Sounds `maximize_007.ogg` (CC0) | -14.0 / -13.8 | 0 | -52.4 | -25.2 | FAIL | -11.6 / -11.6 | 0 | -89.9 | -25.0 | PASS | REPLACED/FIXED: open_004 floor -52 dBFS. maximize_007, ui_back's rising twin. |
| `ui/ui_page.wav` | Kenney Interface Sounds `scratch_003.ogg` (CC0) | -8.5 / -7.5 | 0 | -87.1 | -29.6 | PASS | -10.0 / -9.1 | 0 | -88.4 | -31.2 | PASS | kept; re-processed with the limiter fix (alimiter level=false: 1.5 dB under the old auto level) |

### Music

| File | Source (licence) | Before: peak / TP | clip | floor | loud | verdict | After: peak / TP | clip | floor | loud | verdict | Action |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `music/casino_backbay.ogg` | Kevin MacLeod "Backbay Lounge" (CC-BY 4.0) | -4.8 / -4.8 | 0 | -38.3 | -20.4 | PASS | -6.5 / -6.5 | 0 | -39.8 | -22.0 | PASS | kept; re-processed with the limiter fix (alimiter level=false: 1.5 dB under the old auto level) |
| `music/day_morning.ogg` | Kevin MacLeod "Morning" (CC-BY 4.0) | -4.8 / -4.8 | 0 | -43.2 | -18.5 | PASS | -6.2 / -6.2 | 0 | -44.6 | -20.0 | PASS | kept; re-processed with the limiter fix (alimiter level=false: 1.5 dB under the old auto level) |
| `music/dread_ossuary.ogg` | Kevin MacLeod "Ossuary 6 - Air" (CC-BY 4.0) | -4.6 / -4.6 | 0 | -42.0 | -20.5 | PASS | -5.9 / -5.9 | 0 | -43.6 | -22.0 | PASS | kept; re-processed with the limiter fix (alimiter level=false: 1.5 dB under the old auto level) |
| `music/ending_lost_time.ogg` | Kevin MacLeod "Lost Time" (CC-BY 4.0) | -4.8 / -4.8 | 0 | -35.9 | -18.5 | PASS | -6.4 / -6.4 | 0 | -37.3 | -20.0 | PASS | kept; re-processed with the limiter fix (alimiter level=false: 1.5 dB under the old auto level) |
| `music/ending_promises.ogg` | Kevin MacLeod "Promises to Keep" (CC-BY 4.0) | -1.8 / -1.8 | 0 | -74.2 | -21.5 | PASS | -3.3 / -3.3 | 0 | -75.8 | -23.0 | PASS | kept; re-processed with the limiter fix (alimiter level=false: 1.5 dB under the old auto level) |
| `music/night_evening.ogg` | Kevin MacLeod "Evening" (CC-BY 4.0) | -7.4 / -6.9 | 0 | -33.7 | -19.4 | PASS | -8.7 / -8.7 | 0 | -35.3 | -20.9 | PASS | kept; re-processed with the limiter fix (alimiter level=false: 1.5 dB under the old auto level) |
| `music/stealth_stay_the_course.ogg` | Kevin MacLeod "Stay the Course" (CC-BY 4.0) | -8.0 / -8.0 | 0 | -31.8 | -19.5 | PASS | -9.5 / -9.5 | 0 | -33.4 | -21.0 | PASS | kept; re-processed with the limiter fix (alimiter level=false: 1.5 dB under the old auto level) |
| `music/town_carefree.ogg` | Kevin MacLeod "Carefree" (CC-BY 4.0) | -2.6 / -2.5 | 0 | -43.5 | -19.5 | PASS | -4.0 / -3.9 | 0 | -45.0 | -21.0 | PASS | kept; re-processed with the limiter fix (alimiter level=false: 1.5 dB under the old auto level) |
| `music/works_gone_beyond.ogg` | Kevin MacLeod "Gone Beyond" (CC-BY 4.0) | -8.0 / -7.9 | 0 | -53.1 | -19.4 | PASS | -9.4 / -9.3 | 0 | -54.7 | -21.0 | PASS | kept; re-processed with the limiter fix (alimiter level=false: 1.5 dB under the old auto level) |
