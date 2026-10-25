# Playtest fix: the running sound (and the rest of the audio)

## The note

> "The running sound is noisy and bad. Other sounds were bad too."

## Root cause, measured

There is no separate running loop: the "running sound" is the hoofstep the player plays
while she gallops (`game/actors/player/player.gd`, `Sound.play_at(&"hoofsteps_grass")`).
Three things were wrong with it, and the test below fails on each of them at 512241a.

1. **The samples were noise.** `hoofsteps_grass_1..4` came from BBC 07024157/07024158 ("Horse
   on turf: walking"), cut by `fetch_sounds.sh`'s `pick=` silence detector at a -25 dB
   threshold that sat *under* the takes' own room tone and wind, so several "strikes" were
   just windows of background (`hoofsteps_grass_4`: 0.35 s of flat -24 dB envelope, peak only
   14 dB over its own median). Each was then lifted by gain_db +9 to +17 dB, room and all,
   into an alimiter. `tools/audio_audit.py` measures their broadband noise floor at **-35 to
   -39 dBFS** (the hard set: -31 to -49), against -60 for a clean one shot; Kenney's studio
   takes measure -74 to -143.
2. **One sound per cycle, not per footfall.** Since slice R3 the step fired once per clip
   cycle, at the loop point. The gallop has four footfalls a cycle and the walk two (the
   diagonal pairs), so the run sounded like ONE noisy sample repeating at the cycle rate
   (2.9 a second) while four hooves hit on screen. Measured by the test: 95 of 169 visible
   footfalls (56%) made a sound.
3. **No variation and one surface.** Volume never changed (-8.00 dB every step), and the
   dirt path played the grass set (23 of 23 steps on the path).

The "other sounds" had the same disease (nine BBC one shots cut out of long takes and lifted,
floors -21 to -58 dBFS) plus a pipeline bug that made everything 1.5 dB louder than its
target: `alimiter=limit=0.84` with ffmpeg's default `level=true` rescales the output to full
scale after the loudness pass. That is why every bed measured -22.6 LUFS against its -24
target (the earlier "ambience is too loud" note). AUDIO_AUDIT.md has every file.

## The fix

- **Footfalls from the clip itself.** `Player.footfalls_in()` reads each clip's IK hoof
  target position tracks (`IK_FrontHoof.L/R`, `IK_RearHoof.L/R`) through the parent bone's
  frame (CON_Root carries the Z-up to Y-up turn; read raw, a track's .y is fore and aft
  travel, not height -- the first fixed build made exactly that mistake and the test caught
  it, 29 steps landing 50 to 83 ms early), finds each touchdown, merges hooves landing within
  12 ms (the walk's diagonal pairs), and `step_on_clip()` fires when the AnimationPlayer's
  position crosses one. Gallop: four a cycle (hind pair, then fore pair); walk: two. Rear
  hooves land 1.5 dB under front ones.
- **Per surface.** `Player.surface_under()` casts a short ray down at each footfall:
  a collider tagged `step_surface` names itself (`building.gd`: wood; the Factory's floors:
  metal grating or stone tile), the Terrain is dirt on the painted path and the region's open
  ground elsewhere (grass; stone on the Strip, set by `ranch.gd`), and any other prop is wood.
- **New, clean samples.** Twenty Kenney Impact Sounds takes (CC0), four per surface:
  `hoof_grass_*`, `hoof_dirt_*`, `hoof_wood_*`, `hoof_stone_*`, `hoof_metal_*`. Rows and
  reasoning in `tools/sound_manifest.txt`; the old eight files are deleted.
- **Variation.** Each play rolls pitch 0.94 to 1.07 and volume +/-1.5 dB
  (`volume_jitter_db`), and never repeats the previous take (`no_repeat`), in
  `game/systems/sound.gd`.
- **The rest of the audit.** Nine noisy BBC one shots and three noisy synth UI ticks
  replaced with clean CC0 Kenney takes; the neigh gag kept but levelled; the limiter bug
  fixed and every file re-processed from source; a new `mgain=` verb levels one shots on their
  loudest 400 ms and stops at -3 dBTP rather than limiting. Before 23 of 58 files failed the
  audit, after 0 of 70.

## Tests

`game/test_input/test_footsteps.gd` (real input only: title, creator, letter by mouse; W to
run, W + Shift to walk, the mouse to steer). It runs and walks on the dirt path and on the
meadow, watches the four visible hoof bones (`IK_FrontEnd.L/R`, `IK_RearEnd.L/R`, the solved
FK pose on screen) for footfalls (each hoof's local minimum with a real swing around it), and
reads every hoofstep the Sound pool starts. It asserts: every step within 40 ms of a footfall
and at least 85% of footfalls with a step; pitch and volume both vary, slightly; the sample
set matches the ground (judged from the Terrain and the path polyline by the test itself);
none of the old files plays and every played file passes `tools/audio_audit.py`.

Run: `tools/run_input_tests.sh footsteps` (invisible display, GPU, Dummy audio).

**Before (512241a, the test written first):**

```
INPUT_TEST_NOTE recorded 1367 frames, 169 footfalls, 38 hoofsteps (38 while moving)
INPUT_TEST_NOTE step to nearest footfall: mean 2.2 ms, worst 16.7 ms, 0 of 38 over 40 ms
INPUT_TEST_NOTE footfalls with a hoofstep within 40 ms: 95 of 169 (56%)
INPUT_TEST_NOTE pitch 0.902..1.117, volume -8.00..-8.00 dB
INPUT_TEST_NOTE steps by ground: { "dirt": 23, "grass": 15 }, 23 with the wrong sample set
INPUT_TEST_NOTE samples played: ["hoofsteps_grass_1.wav", "hoofsteps_grass_3.wav", "hoofsteps_grass_4.wav", "hoofsteps_grass_2.wav"]
INPUT_TEST_NOTE audit: FAIL world/hoofsteps_grass_1.wav ... noise floor -35.9 dBFS > -60.0
INPUT_TEST_NOTE audit: FAIL world/hoofsteps_grass_3.wav ... noise floor -32.9 dBFS > -60.0
INPUT_TEST_NOTE audit: FAIL world/hoofsteps_grass_4.wav ... noise floor -33.5 dBFS > -60.0
INPUT_TEST_NOTE audit: FAIL world/hoofsteps_grass_2.wav ... noise floor -30.8 dBFS > -60.0
INPUT_TEST_FAILED test_footsteps only 56% of footfalls make a sound (want 85%) | volume range -8.00..-8.00 dB is not a slight variation | 23 steps played another surface's sample set | the old noisy sample hoofsteps_grass_1.wav still plays | the old noisy sample hoofsteps_grass_3.wav still plays | the old noisy sample hoofsteps_grass_4.wav still plays | the old noisy sample hoofsteps_grass_2.wav still plays | the samples that played fail tools/audio_audit.py (exit 1)
```

(The floors in that run come from the audit script's first noise estimator; the final one,
used for AUDIO_AUDIT.md, reads the same four files at -35 to -39 dBFS. Either way, 25 dB or
more over the line.)

**First fixed build (footfalls read from the raw track .y), caught by the same test:**

```
INPUT_TEST_NOTE step to nearest footfall: mean 27.6 ms, worst 83.3 ms, 29 of 113 over 40 ms
INPUT_TEST_FAILED test_footsteps 29 of 113 hoofsteps land more than 40 ms from any footfall (worst 83 ms)
```

**After:**

```
INPUT_TEST_NOTE recorded 1367 frames, 169 footfalls, 124 hoofsteps (113 while moving)
INPUT_TEST_NOTE step to nearest footfall: mean 2.7 ms, worst 16.7 ms, 0 of 113 over 40 ms
INPUT_TEST_NOTE footfalls with a hoofstep within 40 ms: 169 of 169 (100%)
INPUT_TEST_NOTE pitch 0.940..1.069, volume -11.97..-6.52 dB
INPUT_TEST_NOTE steps by ground: { "dirt": 69, "grass": 44 }, 0 with the wrong sample set
INPUT_TEST_NOTE samples played: ["hoof_dirt_4.wav", "hoof_dirt_1.wav", "hoof_dirt_3.wav", "hoof_dirt_2.wav", "hoof_grass_1.wav", "hoof_grass_3.wav", "hoof_grass_2.wav", "hoof_grass_4.wav"]
INPUT_TEST_NOTE audit: AUDIO_AUDIT files=8 failed=0
INPUT_TEST_OK test_footsteps 113 hoofsteps on 169 footfalls, all aligned, varied, on the right surface and clean
```

(76 gallop steps and 37 walk steps judged.)

**The audit**, `python3 -I tools/audio_audit.py` over every file in `game/`: before
`AUDIO_AUDIT files=58 failed=23`, after `AUDIO_AUDIT files=70 failed=0`. Run by
`game/test/test_audio_audit.gd` in the GUT suite.

**GUT, updated honestly:** `test_player_steps.gd` (rewritten: the real clips' footfalls,
two in the walk and four in the gallop; three gallop cycles make twelve steps; the hand
built merge case; the cadence 4.8/s at the sneak and 11.6/s at the run; the surface pick for
tagged, untagged, path and meadow ground), `test_sound.gd` (the five surface sets, volume
jitter within its bound, no take twice running), plus `test_sound_library`,
`test_ranch_sound`, `test_menu_sound`, `test_music`, `test_building_*`,
`test_factory_*`, `test_ranch_world`, `test_ranch_race`, `test_audio_audit`: 121 of 121 pass. Full suite (`tools/run_tests.sh`): 1758 of 1758 pass. `test_first_pony` (real input) still passes.

## What the tests cannot do

They cannot listen. The new samples are clean by measurement and on the footfalls by
measurement; whether a Kenney concrete step reads as a pony's hoof on paving is an ear call
for the owner's next playtest. Every sample is one manifest row: swapping one is editing a
URL and re-running `bash tools/fetch_sounds.sh`.
