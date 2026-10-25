# Playtest fixes (owner's real-hardware playtest, 2026-10-24)

Each note is mapped to its root cause, its fix, and the test that reproduces it.

Each test failed on the code before its fix, and that failing output is recorded. The tests are in `game/test_input/` and play the game through real input only:
- Every action is an `InputEvent` given to `Input.parse_input_event`, built from the project's own InputMap, or a mouse event at a screen position (`game/test_input/real_input.gd`).
- A test boots from the real title screen and clicks New game, just as the export does.
- A test may READ the game to decide what a person looking at the screen would do next. It never calls a game function to act.

Run them with `tools/run_input_tests.sh`. They play in an invisible display (xvfb) but render on the GPU, so nothing opens on the desktop and the mouse is never taken from whoever is at the machine.

Evidence (logs and screenshots) is in `build/playtest_evidence/`.

## Why the old suite missed the first-pony bug

The suite was green and the game was broken, for four reasons that compound.

1. **Every automated run was a run with "nobody at the keyboard".**
   - The GUT suite, the five playthroughs and the pacing bot all ran `--headless`.
   - The game reads a headless display as "no person here" (`TitleScreen.is_interactive()`, `ranch._interactive`).
   - On that answer it skips the title screen and the creator. It also skips the rule that the beam stays dead until Marigold hands over the Scoop (`ranch._apply_beam_recall`: `no_scoop = _interactive and not has_flag("has_scoop")`).
   - So in every test the beam worked from the first frame. None of them played the game the owner played.
2. **They acted through game functions, not input.**
   - The playthrough called `set_flag("has_scoop")` itself (`scenes/test/playthrough.gd:316`) and drove conversations, menus and catches by method.
   - The human-paced bot pressed actions with `Input.action_press` and turned the camera with `add_look_delta()`. Neither is a key or a mouse.
   - A test that grants the Scoop cannot find a Scoop the player never got. A test that presses the action cannot find a prompt that names no key.
3. **Nothing read the prompts.**
   - The onboarding tip a new player sees first read "Hold  on a pony to Scoop her up", with no button named.
   - No test looked at that text; they knew the button.
4. **`Input.is_action_just_pressed` is not the event.**
   - The bug that trapped a player in Tumble's chatter (below) only exists when the same E keypress reaches both the talk box (an input event) and the ranch's interact poll (`Input` state) in one frame.
   - Calling the talk box's `_accept()` directly, as the old bot did, never sends that second half.

## The playthrough driver, rewritten (rule 2)

Full write-up: `docs/playtest_fixes/playthrough.md`. It lists all 17 shortcuts the old driver took, from forcing the Scoop flag to calling the collection day itself.

**The new driver** is `game/test_input/playthrough_input.gd`, run by `tools/playthrough.sh`, which now calls `tools/playthrough_input.sh`. It starts a fresh game from the title screen for each ending, plays only through RealInput, and reads the game only to decide what a player would do next:
- the keys from the InputMap to walk, sneak, gallop and jump;
- mouse motion to look;
- the right mouse button held for the Scoop;
- E to interact, and number keys for talk choices;
- arrows, Enter and Escape for the menus;
- mouse clicks for the title screen and the creator.

There is no bed, so it waits for nights and collection days by playing through them.

The old function-call driver is kept as `tools/smoke_endings.sh`. It only checks the ending table quickly, and it does not count as a playthrough.

**Results:** all five endings reached from a new game by real input, each with its own fresh save folder.

| Ending | Game time | Wall time |
|---|---|---|
| brightest_rainbow | 0:56 | 32 min |
| gray_gold | 0:41 | 24 min |
| lights_out | 0:50 | 31 min |
| half_light | 0:42 | 25 min |
| placement | 1:08 | 43 min |

The five ran as separate runs, not as one `PLAYTHROUGHS_OK 5` sweep.

**Game bugs the real-input run found:**
- **Fixed: no ordinary Drifter could ever count as vivid.**
  - `PathRules.VIVID` was 0.55, but every coat swatch is at saturation 0.45 or below.
  - So the vivid contract and the Jubilee order could only be filled by the rare starry Nightmeadow variant.
  - The old driver hid this by forcing caught coats to saturation 0.85.
  - The threshold is now 0.37, which the brightest five swatches meet.
- **Fixed: a new steward's first catch could be wrenched away** (note 1, cause 4).
- **Not fixed:**
  - The Dye Vat sits inside the Market's 6 m E radius, so over most of its reach the prompt says "E: Market".
  - A named pony delivered on the Factory path is judged by stock swatch 0, not her real coat.
  - On the Factory path a Bloomed pony can never leave a pen.
  - Placement only works if you raid on the night before a collection dawn.
  - Once, Marigold at the Depot was out of reach for about 3 minutes; the cause is unknown.

## 1. "I could not collect the first pony."

**Test:** `game/test_input/test_first_pony.gd`. A fresh save, played from the title screen with keyboard and mouse, following only the onboarding prompts:
- The bot reads the tip to find out which button to hold, and fails if the tip names none.
- The first beam attempt on the first pony must put her in the bag.

**Root causes (three, all on the path a new player takes):**
1. **The first prompt named no button.**
   - `InputDevice.GLYPHS` had entries for only five actions.
   - `Onboarding.current()` filled `{beam}`, `{launch}` and `{sprint}` from it, and they printed as nothing.
   - "Hold  on a pony to Scoop her up" was the only instruction for the first catch.
   - Two tips also promised keys for things that do not exist: "fire a pony back out of the Scoop", and "Hold {sprint} to gallop" when running is already the default.
2. **The E that closed a conversation opened the next one.**
   - The talk box marks the key EVENT handled, but `ranch._update_interaction()` polls `Input.is_action_just_pressed("interact")` later in the same frame.
   - That poll still says yes, and with the talk box now closed it starts a new talk with whoever is in reach.
   - Tumble follows the player from her first meeting, so every E that ended one of her lines began another: an endless chatter loop on the very spot where the first catch happens.
3. **Before the Scoop, the beam failed silently** (fixed earlier the same day, 877d56d).
   - The horn is locked until Marigold's welcome.
   - A right-click did nothing and said nothing, and Marigold stayed wherever the player had left her.
4. **Her first hold could be torn away by chance** (found after the merges, when `test_first_pony` failed 2 runs in 4 with "she got out of the beam after 0.8s").
   - A new player's nearest pony can be bold. Bold ponies are graded HARD, and a HARD hold wrenches free half the time, about 0.85 s in.
   - So the one catch the tips teach was a coin toss, however well the player did.

**Fixes:**
- `InputDevice.hint()` names any action from its live InputMap binding ("Right Mouse", "E", "F", "Ctrl"), with gamepad names when a pad is in use. The dead `launch` and `sprint` tips are replaced or removed, and the feed tip names the treat key.
- `ranch._fresh_interact()`: the press that ended a conversation is spent until the key comes back up.
- A beam press before the Scoop shows a toast, and Marigold walks back over (877d56d).
- `MagicBeam.first_catch_grace`: while the steward has never caught anyone (story var `catches` is 0), no hold wrenches. The ranch sets it, and it lifts on the first catch. This uses the same rule the wrench falloff already reaches on a pony's third grab.

**Failing before** (`build/playtest_evidence/`):
- With the GLYPHS change reverted: `INPUT_TEST_FAILED test_first_pony the Scoop prompt names no button: 'Hold  on a pony to Scoop her up'` (`fp_glyph.log`).
- With the talk latch removed: `INPUT_TEST_FAILED test_first_pony timed out after 300s`. The bot was stuck in Tumble's chatter (`fp_loop.log`; the first run, `first_pony_before.log`, shows the same).

- The wrench: `test_magic_beam.gd`, `test_a_new_stewards_first_catch_never_wrenches`, sweeps 64 seeds on a fresh bold pony. Without the grace: `[26] expected to equal [0]: a new steward's first catch must never be torn away (26 of 64 were)`.

**Passing after:** `INPUT_TEST_OK test_first_pony caught on the first try` (on the GPU in the invisible display; 1 attempt, at 5.7 m). After the wrench fix it passed 6 runs of 6, and the sweep reads 0 of 64.

## 2. "Beam selection feels weird." (rule 4: forgiving, readable targeting)

**Test:** `game/test_input/test_beam_targeting.gd`. With the Scoop in hand, through real input:
- Aim at empty grass: nobody may be highlighted.
- Aim 0.9 m BESIDE a pony (not on her): she must be the highlighted one before the press.
- Press the right mouse button: the beam must take exactly her.

**Root cause:**
- The beam cast one thin ray from the screen centre. If that missed, it looked for a pony only within 0.5 m of where the RAY LANDED (`GRAB_ASSIST_RADIUS`).
- A crosshair a hair beside a pony 6 m away sends the ray on to the grass 8 m out, so being half a pony off took nothing, and the result depended on what lay behind her.
- Nothing showed what the beam would take: the reticle only changed colour.

**Fix** (`actors/player/magic_beam.gd`, `shaders/outline.gdshader`):
- **Aim assist:** every pony within reach, inside a 12 degree cone round the crosshair and within 1.6 m of its line, that the lens has a clear line to, is a candidate. The one nearest the crosshair wins, and ties go to the nearer pony.
- **Ray priority:** a pony the ray hits directly still wins outright. The old 0.5 m pass remains for loose props.
- **Highlight:** the target is lit before the press:
  - her outline turns gold and thick (a new `highlight` instance uniform on the outline shader, never distance-faded);
  - a pulsing ring sits at her hooves;
  - a gold chevron floats over her head and is drawn over everything, so the pick reads even with the player's own pony or a fence in the way.
- **Grab:** the press takes exactly the lit pony, and the highlight clears once she is held.

**Failing before:** `INPUT_TEST_FAILED test_beam_targeting aimed 0.9 m beside a pony 2.0 m away: she is not highlighted ([])` (`beam_targeting_before.log`).

**Passing after:** `INPUT_TEST_OK test_beam_targeting highlight before the press, aim assist 0.9 m, and the press took her`. Screenshot: `beam_highlight_after.png`.

## 3. "Weird shadows, especially on distant hills."

Full write-up: `docs/playtest_fixes/shadows.md`. Screenshots before, after and side by side, at near, mid and three far views, are in `build/playtest_evidence/shadows/`.

**Test:** `game/test_input/test_shadows.gd`. It starts a new game through the title, creator, letter and welcome, then walks by real input to five viewpoints: near, mid, and three looking out over the valley. It judges each at dawn, noon and dusk, 15 frames in all.

Two steps are not player input, and the doc explains why: the test sets the hour on the world clock, and it reads a second copy of each frame with shadows off as the reference.

The measure is speckle: shadowed pixels isolated from all their neighbours, counted only on surfaces that are smooth in the shadowless frame. It is summed per distance band. The ceilings are near 0.001, mid 0.0015 and far 0.0025.

**Root cause** (the Sun in `world/ranch.tscn`):
- **`light_angular_distance` 0.9** turned on PCSS soft shadows, which sample with per-pixel noise. Through the toon shading step that noise became salt-and-pepper grain on ponies at low sun, and a grainy smear on every shadow edge out on the hills.
- **The shadow range ended at 85 m with a 7 m fade,** which the toon step turned into a hard arc that moved with the player.
- **`shadow_blur` 1.1** widened the same noisy filter.
- **The biases were slightly too low** for the longer far cascades.

**Fix:**
- `light_angular_distance` 0, so PCSS is off.
- `shadow_blur` 0.6; `shadow_bias` 0.03; `shadow_normal_bias` 1.5.
- Shadow range 160 m, with splits at 8, 24 and 64 m and a fade from 120 m to 160 m.
- The project shadow atlas stays with the Settings quality preset. Soft-shadow filter quality stays at 2: quality 3 cut the leftover grain by about 10 % for 50 % more filter taps.
- Perf: the 60-pony check gives the same frame times at 85 m and 160 m (p99 25.4 ms against 24.4 ms in the invisible display). The commit before this round measures 23.8 ms there, so the round added no cost.

**Failing before:** `INPUT_TEST_FAILED test_shadows 2 checks failed: near speckle 0.00436 > 0.0010; mid speckle 0.00255 > 0.0015`.

**Passing after:** `INPUT_TEST_OK test_shadows shadows clean at every distance and hour (speckle near 0.00018, mid 0.00055, far 0.00077)`.

**Found but not fixed:**
- The big dark faces on the rim hills at dawn and dusk are not shadows. They are the toon lighting on a large smooth mesh, and they look the same with shadows off.
- The race track's dirt sheet depth-fights into stripes from about 40 m away.

## 4. "Some house models are the same size as ponies. Scaling is inconsistent everywhere."

Full write-up: `docs/playtest_fixes/scale.md`. Reference table: `SCALE.md` (1 PH = 2.19 m, the shipped pony's ear-tip height).

**Test:** `game/test_input/test_scale.gd`. It boots the real game and measures the world-space bounding box of every placed asset (867 placements of 102 assets) against SCALE.md's category table. That table is machine-read, so the numbers live in the doc, not the test.

**Root cause:** nothing was ever sized against the pony. Four conventions met in one valley:
- one family scale derived from a single barn model;
- a Kenney scale derived from the old 4.28-unit pony;
- region dressing at hand-typed multiples of each model's own size;
- door clearance measured from local y = 0, which sits 0.85 m inside the plinth.

So town houses stood 1.6 to 2.2 PH, and every door passed its check while being shorter than the pony walking through it.

**Fix:**
- Per-building `model_scale`: Farmhouse 1.25, Market 1.35, Board 1.85, Depot 1.3.
- Town-row `SCALE_FIX` entries; region dressing sized in PH.
- Doors 3.0 m clear, checked by `Building.door_clearance()`.
- The stall and the pens moved clear of the grown footprints.

**Failing before:** `INPUT_TEST_FAILED test_scale 19 of 102 assets off SCALE.md (1 PH = 2.19 m)`.

**Passing after:** `INPUT_TEST_OK test_scale 867 placements of 102 assets all within SCALE.md (1 PH = 2.19 m)`. Before/after pairs are in `build/playtest_evidence/scale/pairs/`.

## 5. "No loading screen after New Game. I thought it froze."

Full write-up: `docs/playtest_fixes/loading.md`.

**Test:** `game/test_input/test_loading.gd`. It runs in real time, not fixed-fps, and measures every frame gap through New game, Load, Continue and the lift. It fails on any gap over 0.5 s that has no moving loading screen.

**Root cause:**
- `change_scene_to_file` loaded the ranch on the main thread, and the ranch built the whole valley in `_ready()` before the first frame.
- Most of that time was `PonyLod.apply()`, at 0.4 to 1.2 s per pony. It is skipped headless, which is why no gate saw it. Its cache was keyed by instance id and never hit.

**Fix:**
- `game/ui/loading_screen.gd` loads the next scene with `ResourceLoader.load_threaded_request`, instances it on a worker, and shows a progress bar.
- The ranch reports its boot steps and yields between them.
- The LOD cache is keyed by resource path, and LODs are built on a worker pool.

**Failing before:** `INPUT_TEST_FAILED test_loading new game: title -> creator: 4 freeze(s) over 0.5 s with no moving loading screen (worst 11.84 s) | load game ... (worst 9.46 s) | continue ... (worst 9.28 s) | the lift ... (worst 0.68 s)`.

**Passing after:** every transition has 0 stalls over 0.5 s, and the worst frame is 0.35 s. The loading screen was seen with a moving bar on every long transition.

## 6. "Settings UI is awful and hard to navigate."

Full write-up: `docs/playtest_fixes/settings.md`.

**Test:** `game/test_input/test_settings.gd`. It drives Settings from the title screen by keyboard, from the pause menu by controller, and again by mouse. It changes one value on every tab, applies, reverts, and lets the display confirmation time out unanswered.

**Root cause:** there was no settings menu, only two hand-drawn row lists that disagreed:
- the title screen had 5 rows and the pause menu had 23 in one flat list;
- the rows were Labels, so nothing could take keyboard or controller focus;
- a mouse click adjusted a row by which half was clicked;
- every nudge saved at once;
- fullscreen applied with no safety net;
- values were 18 px text at 58 % white.

**Fix:** one `game/ui/settings_menu.tscn`, used by both the title and the pause menu:
- Four tabs: Graphics, Audio, Controls, Gameplay.
- Real focusable controls with a gold focus ring.
- LB/RB and Q/E switch tabs.
- Edits go to a draft, with Apply and Revert.
- A display change asks for confirmation and reverts after 10 s if unanswered.
- Rebindable keys.

**Failing before:** `INPUT_TEST_FAILED test_settings the title screen's Settings opened no tabbed Settings menu (Graphics, Audio, Controls, Gameplay)`.

**Passing after:** `INPUT_TEST_OK test_settings keyboard, controller and mouse all drove every tab; apply, revert and the display timeout hold`.

## 7. "The running sound is noisy and bad. Other sounds were bad too."

Full write-up: `docs/playtest_fixes/audio.md`. Every sound file is listed with its measurements in `AUDIO_AUDIT.md` (`tools/audio_audit.py`, ffmpeg).

**Test:** `game/test_input/test_footsteps.gd`. It walks and gallops by real input over grass and the dirt path, and records every visible footfall and every hoofstep played. It also runs the audit on the samples that played.

**Root cause:**
1. **The hoofstep samples were mostly background.** They were cut from long BBC takes by a silence threshold below the takes' own room tone, then boosted, which gave noise floors of -31 to -39 dBFS.
2. **One step per animation cycle, not per hoof.** The gallop lands four hooves a cycle and only 56 % of footfalls made a sound.
3. **No variation, one surface.** Every step was -8.00 dB, and the dirt path played grass.

Plus a limiter bug: ffmpeg's default `level=true` made every processed file 1.5 dB over its target.

**Fix:**
- Footfalls are read from each clip's IK hoof tracks.
- The surface under each hoof is found by a raycast.
- 20 clean CC0 Kenney samples, four per surface (grass, dirt, wood, stone, metal).
- Pitch varies 0.94 to 1.07 and volume ±1.5 dB, never repeating the last take.
- Nine noisy one-shots replaced, and the limiter fixed.

**Failing before:** `INPUT_TEST_FAILED test_footsteps only 56% of footfalls make a sound (want 85%) | volume range -8.00..-8.00 dB is not a slight variation | 23 steps played another surface's sample set | the old noisy sample ... still plays | the samples that played fail tools/audio_audit.py (exit 1)`.

**Passing after:** `INPUT_TEST_OK test_footsteps 113 hoofsteps on 169 footfalls, all aligned, varied, on the right surface and clean`. The audit went from 23 of 58 files failing to 0 of 70.

## 8. "Bad textures on some pony models, and weird eyes on others."

Full write-up: `docs/playtest_fixes/ponies.md`. Contact sheets for every roster model, Spike, the story cast and 50 generated ponies are in `build/playtest_evidence/ponies/before/` and `after/` (`sheet_*.jpg`, `eyes_*.jpg`). Each row shows front, side, three-quarter, an eye close-up, 16 m and far LOD.

**Test:** `game/test_input/test_pony_materials.gd`, with its rules in `pony_material_audit.gd`. It stands every roster pony, the cast, Spike and the player in the real ranch, near and far, and fails on:
- any placeholder or missing texture;
- an eye surface without its texture;
- a visible mesh that has lost its surfaces.

**Root causes:**
1. **Weird eyes on 37 canon ponies,** every PonySFM/ReVAmped model, including Derpy, Octavia and Trixie. Their brows and lashes are coloured from a Source engine texture (`vgui/white`) that no pack ships. The converter substituted its magenta-black "missing" checker, and that was painted onto the brows and lashes.
2. **Marble Pie's forelock** named a texture her pack never shipped, so it also got the checker.
3. **Applejack's body was invisible.** The runtime LOD rebuild (`pony_lod.gd`) dropped the custom-data format bits, so her body mesh came back with 0 surfaces.
4. **Spike's eyes were blank white.** His iris was mapped through UVs never meant for it.
5. **The grainy, speckled look on ponies** came from the shadows, not the textures. `toon.gdshader`'s hard shadow step turned soft-shadow noise into full-contrast speckle, worst at dawn, which is when a new game starts.

**Fix:**
- `toon_styler.gd` draws lashes near-black and brows a darker shade of her coat, and the converter now ships flat black.
- Marble Pie borrows her ManeSide texture, and the converter warns on unshipped textures.
- `pony_lod.gd` keeps the format bits and falls back to the original mesh if a surface is refused.
- The eye shader projects the iris the way the Source shader did, and Spike's body uses the toon material.
- The toon shadow ramp is `smoothstep(0.2, 0.8)`.

**Failing before:** `INPUT_TEST_FAILED test_pony_materials 368 broken pony materials (first: roster:aloeblossom@FAR ... eyebrow: placeholder texture 'aloeblossom_missing_white.png' ...)`. The same run also reported `roster:applejack@FULL Base_Body: visible mesh with no surfaces`.

**Passing after:** `INPUT_TEST_OK test_pony_materials 93 ponies, cast, Spike and the player: no missing texture or eye, near and far`.

## 9. "The camera showed under the terrain in places."

Full write-up: `docs/playtest_fixes/camera.md`.

**Test:** `game/test_input/test_camera_terrain.gd`. It runs at 144 fps, like a real fast monitor. It visits 27 stops: yard, ramp, every building inside and out, trees, town, Palace, hill top, steepest slope, valley and map edge. At each it sweeps full yaw and pitch at min, default and max zoom by mouse, checking every frame. A companion test, `test_camera_factory.gd`, does the same in the Rainbow Factory.

**Root cause:**
1. **The camera arm was a physics tick late.** SpringArm3D sizes the arm only at 60 Hz, while the mouse turns it every rendered frame. On a fast monitor, a quick look up swung the lens through the ground on the last tick's long arm, up to 1.3 m under. Every older gate drew one frame per tick, which hides this.
2. **The probe was a ray with no size,** so at grazing angles the near plane cut into the grass and walls.
3. **The boundary walls stopped at 3 m,** so on the high east edge the lens hung outside the map.

**Fix** (`camera_rig.gd`):
- A 0.25 m lens ball is swept along the arm on every rendered frame. It handles Jolt's start-inside quirk and starts from her body when her head is under an eave.
- A last guard keeps the lens 0.25 m above the terrain's drawn triangle (`Terrain.surface_height_at()`).
- The boundary walls are now 16 m tall.

**Failing before:** `INPUT_TEST_FAILED 11343 of 198395 frames` bad (worst 1.33 m under the steepest slope). In the Factory, 1,801 of 6,056 frames were bad.

**Passing after:** `INPUT_TEST_OK 172710 frames at 27 stops`, and the lens never got closer than 0.25 m to the ground. The Factory test passes with 5,838 frames.
