# Plan

Milestones run in order. Each ends with the full suite, a screenshot capture reviewed against GDD.md section 8, a PROGRESS.md update, and a commit. An acceptance criterion is a thing a test, a gate or a screenshot can show; "feels good" items are backed by the feel checklist (RESEARCH.md section 3) and a captured clip or frame sequence.

Conventions:
- **Tests:** `tools/run_tests.sh` (GUT). Targeted runs: `GUT_TEST_DIR`, or a single file via `-gtest`.
- **Gates:** scenes under `game/scenes/test/` print `<NAME>_OK` / `<NAME>_FAILED`.
- **Shots:** `tools/capture_shots.sh` (added in M0) renders the key-scene list into `build/shots/`.

---

## M0. Foundation

Everything the slice stands on.

1. **Engine to 4.7.2.**
   - Fetch the editor and export templates (checksummed, as `tools/setup_env.sh` does today) and `--import`.
   - Fix whatever breaks.
   - *Accept:* `godot --version` reads 4.7.2; templates are installed; the full suite and the parse sweep are green; RANCH_OK.
2. **Events autoload** (`systems/events.gd`): typed signals for delivered, bloomed, day_passed, flag_set, dread_changed, talk_started and talk_ended, path_chosen.
   - *Accept:* unit test emits and receives each.
3. **Toon shading.**
   - `shaders/toon.gdshader` (two-tone, cool shadow tint, rim) and `shaders/outline.gdshader` (inverted hull, screen-constant width, albedo-derived color).
   - `shaders/pony_eye.gdshader` (iris replace).
   - `systems/toon_styler.gd`, which converts every StandardMaterial3D under a node (albedo color and texture kept), with a `outline` flag per node category.
   - Applied to ponies, props, buildings and terrain (the terrain shader is rewritten to the same light model).
   - Tonemap moves to Filmic or AgX.
   - *Accept:* tests confirm every MeshInstance in the ranch uses toon materials after styling and no StandardMaterial3D remains on ponies or props. Shots show a pony next to a barn under the same shading.
4. **Generator v2.**
   - `systems/pony_look.gd` (the PonyLook record), `systems/pony_generator.gd` (seeded), and `data/donors.tres` (38 SFM donors with race, two-tone flag and hidden-part lists).
   - Pattern role matcher in StockTint (coat, mane, mane2, tail, eye, horn, wing, brow, lash).
   - Show-plausible palette `.tres`, name generator, talent list, generated marks (stamps composited to a texture).
   - *Accept:*
     - the same seed gives the same look;
     - all 38 donors tint every role, measured by a test that loads each glb;
     - no hat, clip or clothes mesh is visible on any generated pony;
     - foals scale correctly;
     - a 40-pony batch sheet renders (shots).
5. **Canon stays** (owner direction): the named roster keeps its real characters and places; generated Drifters fill the world around them.

6. **Shot tool** (`tools/capture_shots.sh`): key scenes, both tones (a `--dread=` arg), a generated batch, the customizer.
   - *Accept:* the script writes the listed PNGs and exits nonzero on a missing one.

## M1. Vertical slice: Act One in Sunny Acres and Ponyville

The cozy loop, fully polished, in one area.

1. **Animations.** New clips authored on both rig families via `tools/author_anims.py`:
   - locomotion: trot, jump and land, turn;
   - idle variants: look around, ear flick, tail swish;
   - ground actions: graze, sit, lie down, sleep;
   - reactions: startle, cower, happy hop, held struggle;
   - talking: talk, nod, shake;
   - emotes: sad, laugh, rear.

   Face bones: blink, plus jaw and brows for talk. Played through an AnimationTree (locomotion blend space plus a one-shot layer), with ponies roster-converted again.
   - *Accept:*
     - every donor glb carries every clip (test);
     - every AI state maps to a non-idle clip where specified;
     - a frame-sheet render of each clip (shots).
2. **Pony expression and AI:** blink timer, head-track the player, ear flicks, flee startle, sleep at night, graze, happy hop on favorite food.
   - *Accept:* unit tests on the state-to-animation mapping and the timers.
3. **Bloom:** the meter, the ceremony (rear, sparkle VFX, fanfare, mark decal, name card), the name and talent, the gem tier upgrade, the Depot refusal.
   - *Accept:* tests on the meter math, mark determinism, refusal and save round-trip.
4. **The Scoop:** a Blender-built device on the player, beam VFX restyled (rainbow-white stream, a stretch on the pony), pop squash, hit pause on rare catches, rising pitch, the launch action, the Sparkle gauge.
   - *Accept:* the existing capture tests stay green, plus new tests for launch and the gauge value.
5. **Player feel:** acceleration curves, coyote time, jump buffer, landing squash, camera lag, look-ahead, sprint FOV kick, a trauma-based shake setting.
   - *Accept:* tests on the coyote and buffer windows; a camera gate (no clipping in the customizer or at buildings).
6. **People:**
   - the talk box (world-space bubble, text reveal with babble, up to two choices, dialogue `.tres`);
   - NPCs: Marigold, Fennel, Bramble, Pip, plus 8 townsfolk, all generated;
   - Tumble (companion follow, Drifter pointing, Depot refusal);
   - Act One dialogue and beats 1.1 to 1.8.
   - *Accept:*
     - dialogue tests (conditions, choices, flags);
     - a headless script plays Act One to the first collection day;
     - every NPC is generator-built (test).
7. **Onboarding:** contextual prompts (shown at need, retired after two uses), the Arrival cart ride, Fennel's lessons.
   - *Accept:* the scripted first-ten-minutes run hits first catch, pen, feed, gem, sale and purchase within simulated time targets.
8. **The look of the area:**
   - existing props restyled;
   - new Blender props: the Depot crate (with lid scratches), postbox, Tumble's porch, town signage, and blob trees in the show style (replacing the Kenney trees);
   - the sky with the Rainbow and the Works on the ridge.
   - *Accept:* shots of the ranch, town, Depot and sky are reviewed and fixed until nothing reads as primitive or off-style; zero Kenney low-poly trees left in the slice area.
9. **Audio:**
   - music system (layered stems, crossfades, dread low-pass);
   - the cozy theme in place;
   - every BBC row replaced with CC0 or CC-BY (CREDITS.md updated);
   - babble voices;
   - layered SFX for catch, pop, gem, coin, Bloom, and the UI.
   - *Accept:*
     - no BBC-sourced file remains (manifest test);
     - every action event in the feel table has a sound id (test);
     - a loudness gate within the existing true-peak floor.
10. **UI restyle:** show-style theme (rounded, cream, outlined, a bubbly font under the OFL licence), the HUD rebuilt (bag slots, counters with fly-in, an objective chip, the prompt), and the market, build and depot panels made visual-first.
    - *Accept:* shots of each panel are reviewed; mouse, keyboard and controller navigation work in each (input tests).

**M1 exit:** full suite green; Act One playable start to the first collection day; shots reviewed; PROGRESS.md updated.

## M2. The reveal and the branching choice

1. **Act Two content:** clues 1 to 18 wired (postcards, Fennel's wall interior, Dye names from the delivery log, night carts, Tumble's avoidance, vivid requests, rotating tips, the Survey kept, a Collector who checks a flank), new regions open as now.
   - *Accept:* a test per clue that its trigger produces its effect.
2. **Dread system:**
   - the WorldTone node (grading, fog, sun, ambient), driven by the `dread` scalar;
   - music layers and ambience variants;
   - the town population tied to dread.
   - *Accept:*
     - unit tests on the dread function;
     - shots at dread 0, 0.3, 0.8 and the free grade.
3. **The Works interior:** a Blender-built kit (cloud-white and gold rooms turning to gray metal); the lift; the tour script with Marigold; the stealth walkway (a light-cone detector component); the window set piece (silhouette line, color ring, pipe); the choice; the escape (the Tumble catch, the chase, the lift).
   - *Accept:*
     - a headless playthrough script reaches the choice and completes both branches;
     - the stealth component tests (cone hit, reset to checkpoint);
     - shots of every room.
4. **Path state:** the choice sets the path, and Static appears on Rescue. Each path's first systems are playable: Factory gets a stipend change, the Supply Desk with a Calm Lamp, and contracts; Rescue gets Heat, the first corral raid and the first pylon.
   - *Accept:* tests on path effects; a playthrough script on each path completes its first task.

**M2 exit:** full suite green; reveal shots reviewed; both paths playable past their first task.

## M3. Content and both paths complete

1. **Factory path:** ranks, the full gear set (Calm Lamp, Express Chute, Yield Lens, Lure Post), contracts, the town fade, the franchise, Tumble's porch behavior, the Jubilee climax in the Works.
2. **Rescue path:**
   - Heat thresholds and Collector visits;
   - a corral per region;
   - four pylons (the rainbow bands drop);
   - the Dye Vat (the customizer reused);
   - the Lantern Line;
   - ally recruitment (Pip, Bramble, Fennel with the ledger page);
   - Clover in holding;
   - the Lights Out climax.
3. **Endings:** the selector, five epilogue scenes, closing letters, credits, the post-game world states, endings remembered on the title screen.
4. **Regions:** all seven dressed in the show style, with rare variants per region and conditions.
5. **Writing:** all letters, postcards and dialogue for every act and path.

*Accept:*
- unit tests for every path system;
- the ending selector tested against a truth table;
- **headless playthrough scripts reach all five endings without softlock**, using a scripted player that drives systems through their public API with accelerated time;
- shots of each ending.

**M3 status (done):** both paths, all five endings, epilogues, credits and post-game, with `tools/playthrough.sh` reaching every ending headless. Deferred: per-ending shots (the epilogue orbit is not yet reviewed in a rendered capture), and the full seven-region show-style dressing pass beyond the regions Act Three uses.

## M4. Menus, settings, save and load, onboarding

1. **Title** (New, Continue, Load, Settings, Credits, Quit), **pause** (Resume, Journal, Settings, Save, Load, Quit), and **save/load** slot UI with thumbnails and play time.
2. **Settings:**
   - **Graphics:** a quality preset (Low, Medium, High, Ultra) with overrides for resolution scale and FSR, window mode, vsync, shadows, SSAO, glow, fog, outlines and max FPS.
   - **Audio:** six buses.
   - **Controls:** full rebinding for keyboard and mouse and for controller, sensitivity, invert and deadzone, persisted.
   - **Accessibility:** shake, text speed, and colorblind-friendly cues.
3. **Controller:** every screen navigable, with device-aware glyphs.
4. **Onboarding review:** every prompt's trigger and retirement checked.

*Accept:*
- tests on settings persistence and applying a preset;
- rebind conflicts handled;
- a controller-only navigation test per screen (simulated joypad events);
- save/load round-trip from the UI path.

**M4 status (partly done):** done: six buses; a three-step quality preset (Low, Medium, High) with fullscreen and vsync; keyboard rebinding with conflict swap and defaults; settings persistence tests. Deferred to after v1: an Ultra preset and per-effect overrides, controller rebinding, accessibility options, and save-slot thumbnails. See DECISIONS.md.

## M5. Polish, performance, bug bash, ship

1. **Performance:**
   - profile the ranch with 60 ponies on screen, then fix the hot spots: LOD and impostor distance for ponies, animation update throttling off screen, shared materials per look, and outlines culled by distance;
   - a perf gate prints frame time over a fixed camera path.
   - *Accept:* at most 16.6 ms average on the High preset on this machine in the 60-pony scene, with Low as the fallback for weaker hardware.
2. **Bug bash:** play every path by script and by hand-driven capture review; fix everything found.
3. **Exports:**
   - `export_presets.cfg` for Linux and Windows;
   - `godot --headless --export-release` for both;
   - the Linux build launches with `--headless --quit-after` with no errors;
   - the Windows build is smoke-run under Proton (`tools/run_windows_build.sh`).
4. **Documentation:** README.md (build, run, regenerate assets) and CREDITS.md (every third-party source and its licence).
5. **REVIEW.md:** a skeptical player and reviewer critique; fix the top issues and mark them fixed.

*Accept:* every item in the MISSION.md Definition of Done, with transcript evidence of the suite, the ending playthroughs, both exports and the Linux launch.

**M5 status (done for v1):** both exports, the clean `--quit-after` launch of the Linux build, README.md, CREDITS.md, and REVIEW.md with every high and medium finding fixed. Deferred: the 60-pony perf gate, and a Proton smoke run of the Windows build.

---

## M6. Sharpening: fun, performance, the exit hang, the visual review (owner brief, 2026-10-23)

MISSION.md's "Fun and anti-repetition rules" are part of the Definition of Done. The baseline is in docs/early_game_audit.md:
- no verb-changing upgrade before the reveal (0 of 8);
- generated traits are cosmetic;
- the first real clue arrives at 20-30 min;
- the invitation is a grind of 8 deliveries plus 3 Blooms.

1. **The pacing test.**
   - **The Novelty log:** GameState records each first-time unlock, discovery or story beat (kind, id, label) with play-clock seconds.
   - **The human bot:** `scenes/test/human_bot.gd`, run by `tools/pacing.sh`. It plays a fresh save headless at `--fixed-fps 60`, so the play clock is simulated real time. It uses real verbs: walking with the camera, aiming and holding the Scoop, interact prompts, and menus through their own keyboard APIs. It shops from a priority list and takes natural pauses.
   - **The report:** `tools/pacing.sh` writes PACING.md with the gaps, and fails if any gap in the first hour exceeds 8 min, any later gap exceeds 15 min, or the first clue comes after 15 min.
2. **The redesign:**
   - **Verb-changing upgrades:**
     - Gallop Shoes: sprint and a dash.
     - Treat Pouch: throw a favorite food to lure or calm a pony.
     - Scoop Launcher: shoot bagged ponies into a pen from range.
     - Pony Whistle: freezes nearby wild ponies.
     - Gem Chute: pens sell their own gems.
     - Depot Pen: a pen that sends its unmarked ponies at dawn.
     - Lure Post and Yield Lens made real.
   - **Traits that matter:**
     - Race abilities: pegasi flutter away, unicorns blink, earth ponies Bloom faster.
     - One generated quirk per Drifter, with a generated favorite food.
   - **The first clue at about 10 min:** the first delivery adds a band of her colour to the rainbow, Tumble reacts, and the postcard arrives at once.
   - **A shorter invitation gate.**
   - **Timed NPC events:** rare sightings, a race night, the Strip's flyer.
3. **60-pony performance** (`scenes/test/perf.gd`, `tools/perf.sh`): real GPU rendering, 60 ponies in view; the target is p99 at 16.6 ms or less and a worst second of 60 fps or better.
4. **The exit hang:** the full suite in a loop under a gdb watchdog, in a detached worktree.
5. **Rendered visual review** of every major scene, then fixes.
6. **Videos:**
   - FIRST_10_MINUTES.mp4 (the bot, Movie Maker, 1080p60).
   - The trailer: TRAILER_PLAN.md, staged shots at 4K, a scripted edit, beat-cut, -14 LUFS, at least three reviewed iterations in TRAILER_REVIEW.md.
   - Deliverables: TRAILER_4K.mp4 and TRAILER_1080p.mp4.

---

## FS. The fix sweep (2026-11-05): gap items 1 to 7 and 10

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (the owner's standing rule is at most one subagent at a time, sonnet or opus). Steps use checkbox (`- [ ]`) syntax.

**Goal:** close the eight gaps the owner picked from the AAA list: mid-game guidance, art unity, faces and life, animation feel, sound, loop polish, late-game depth, accessibility.

**Architecture:** each milestone is a self-contained slice with its own tests and renders, in the order below (the owner's playtest exits first). Pure rule functions (like `Guide.pick`) carry the decisions so they test headless; world and UI nodes only measure and draw. Every visual change is checked in a rendered frame before it is called done (memory: look at renders, not tests).

**Tech stack:** Godot 4.7.2, GDScript, GUT 9.5, the real-input harness (`tools/run_input_tests.sh`), the bot (`tools/playthrough.sh`), Python 3 asset tools.

**Spec:** the owner's request ("plan a fix sweep containing items 1-7 and 10") of the gap list given 2026-11-05: 1 guidance goes quiet mid-game; 2 art reads as a kit-bash, pale coats blow out, flat ground; 3 ponies' faces are frozen and bodies pass through each other; 4 animation is clips sped up, no transitions or reactions; 5 sound unverified in play, no music that follows the moment; 6 menus are lists, not delightful; 7 nothing to spend bits on late; 10 no rebinding, no colourblind-safe marks, no text size.

### Global constraints
- No em dashes anywhere; the house dash is " -- ".
- Canon MLP names, looks and places stay.
- No realistic pony vocals; AI voices are on hold (owner, 2026-11-05).
- Visual-first UI: icons over sentences, no floating text in the world.
- Every Godot launch sets FILLY_TEST_SAVE_DIR and passes --log-file; windows only on an invisible xvfb display.
- Root cause first; a failing test before each fix; real-input tests act only through Input.parse_input_event.
- No game-file edits while a test run is in progress.
- At most one subagent at a time (sonnet or opus); prefer doing the work inline.
- The gates at the end of each milestone: the touched GUT files, the touched real-input tests, and a rendered frame reviewed; at the end of the sweep: full GUT, all real-input tests, the five endings, both exports.

### Review focus
1. An old save or the epilogue has a story state the objective rules never named: the tracker shows nothing rather than a wrong goal or an error (test in FS1.1).
2. A rebound key collides with another action or an old settings file has no binds section: the conflict is refused with the clash named, and the old file loads with defaults (test in FS8.1).
3. The largest text size: no panel runs off the UI canvas (1920x1080 at every window size, project.godot stretch canvas_items) (test in FS8.2).
4. A decoration placed over a pen gate, a road or an NPC's spot: refused by the ghost, and placed decor survives save and load (test in FS7.1).
5. Faces on every wild pony at once: far ponies skip the face (the existing LOD tiers), and 60 ponies stay inside the perf budget (test in FS3.1).

---

### FS1. Guidance that never goes quiet (gap 1)

**Files:** create `game/systems/objective.gd` (class_name Objective), `game/ui/objective_card.gd`, `game/test/test_objective.gd`, `game/test_input/test_objective_card.gd`; modify `game/systems/guide.gd`, `game/world/ranch.gd` (guide section), `game/ui/hud.gd`.

**Interfaces:**
- Produces `static func Objective.current(s: Dictionary) -> Dictionary` returning `{id: StringName, icon: int (PlaceSign.Icon), words: String (3 to 6 words), goal: StringName}` or `{}`. State keys: everything `Guide.pick` takes, plus `chapter: int`, `path: String`, `contract: Dictionary`, `flags: Array[String]`, `ending: String`.
- `Guide.pick` gains goals `&"depot"`, `&"marigold"`, `&"palace"`, `&"lift"`; `ranch._guide_place` maps each to its node.
- `ObjectiveCard.show_objective(o: Dictionary, distance_m: float)`.

- [ ] **FS1.1 Objective rules.** Test first, one assertion per chapter of STORY.md: chapter 0 before the Scoop "talk to Marigold"; SUNNY after the lessons "deliver ponies to the Depot (n/3)"; WEATHER with the invitation "meet Marigold at the Depot"; COMPANY "fill the contract (got/want)"; RESISTANCE per path; every unnamed state (the Review Focus case, including `ending != ""`) returns `{}`. Implement as a table, not branches scattered through ranch.gd. Commit.
- [ ] **FS1.2 The main path on the trail.** `Guide.pick` falls through to `Objective.current(s).goal` when nothing is waiting on her, so the trail and the compass ring point at the story's next place mid-game. Test: a SUNNY state with no mail and no news picks `&"depot"`. Commit.
- [ ] **FS1.3 The objective card.** A small casino-tile card under the compass: the goal's PlaceSign icon, the words, the metres to it, sliding in on change with the existing `MenuStyle` panel style; hidden when `{}`. Real-input test `test_objective_card`: after the first catch the card names the pens; after penning, the Depot; its distance falls as the bot walks toward it. Commit.
- [ ] **FS1.4 The checklist as chips.** `hud.set_tasks` draws each tutorial row as an icon chip (the action's icon, lit when done, its bit reward on the chip), no sentences; the sentence moves to a hover tooltip. Test in `test_hud.gd`: three rows give three chips, a done row is lit. Commit.
- [ ] **FS1.5 Trail at play distance.** Render the bot's first five minutes (`--shots`) and inspect the frames with a goal set; if the motes do not read at 8 to 15 m, raise `GuideTrail` quad size and core brightness until they do. Record the frames in `build/playtest_evidence/fs1/`. Commit.

### FS2. One look across the world (gap 2)

**Files:** modify `game/shaders/toon.gdshader`, `game/systems/toon_styler.gd`, `game/world/terrain.gd` and its shader, `game/world/ranch.tscn` (environment), `game/world/props.gd`; test `game/test/test_toon_styler.gd`, render script `game/scenes/test/look_sheet.gd` (new).

- [x] **FS2.1 Pale coats keep their shape.** DROPPED 2026-11-05 on evidence: in the game's own light a white pony shows full shading and no pure-white pixels (bot frame t01_30); the blow-out was the face-render harness's lighting (scenes/test/roster_eyes.gd, ambient 0.75 and no tonemap), not the game's. Original task: Root cause first: measure which term pushes a white coat to pure white (ambient plus sun plus rim, or the tonemap). Fix with a highlight shoulder in the toon light (lit colour capped below 0.96 of white, shadow band kept visible on luminance above 0.85). Test: for an albedo of 0.97 the lit side stays under 0.96 and the shadow side differs from it by at least 0.12. Render the roster faces (`scenes/test/roster_eyes.gd`) before and after. Commit.
- [ ] **FS2.2 Ground with life.** The terrain shader gets a large-scale hue drift (two greens), a fine painted noise and darker grass at prop and fence bases (a contact term from the prop footprint mask). Test: two samples 40 m apart differ in hue; a sample under a fence base is darker than open grass. Render spawn views. Commit.
- [ ] **FS2.3 One palette for the kit.** `look_sheet.gd` renders one tile per prop family and building beside a pony under the game's light; any family whose albedo falls outside the show palette's saturation and value bands gets a per-family tint in `ToonStyler.PRESETS`. Test: every family's mean albedo is inside the bands. Commit with the sheet.

### FS3. Faces and bodies (gap 3)

**Files:** modify `game/actors/pony/pony_face.gd`, `game/actors/pony/pony_visuals.gd`, `game/actors/pony/pony.gd`, `game/actors/player/player.gd`, `game/world/spawner.gd`; create `game/actors/pony/body_space.gd`; tests `game/test/test_pony_face.gd`, `game/test/test_body_space.gd`.

**Interfaces:**
- `PonyFace` gains `const RIG_NAMES := {&"lid_l": ["LeftEyeLidUpper", "CON_UpperEyelid.L"], ...}` so both rigs resolve; `PonyVisuals.build` attaches one to every body.
- `Pony.set_mood(m: PonyFace.Mood)`; moods driven by state: fleeing SCARED, held SCARED, penned and fed HAPPY, hungry SAD.
- `BodySpace.push(self_pos: Vector3, others: Array, reach: float) -> Vector3` (the townsfolk separation, made shared).

- [ ] **FS3.1 Every pony blinks and emotes.** Tests: a built Fluttershy and a built Apple Bloom both resolve lid, ear and jaw bones; a pony set to SCARED drops her ears; a FAR-tier pony's face does not process (the Review Focus perf case). Run `tools/perf.sh` and keep p99 at or under 16.6 ms. Commit.
- [ ] **FS3.2 Eyes that look.** The eye shader's `gaze` (added for Derpy) follows the player when she is within 6 m and the pony is idle or penned, clamped to 0.08 UV; Derpy keeps her offset on top. Test: gaze points toward a target on the left for both eyes. Commit.
- [x] **FS3.3 Bodies do not pass through bodies.** Done for townsfolk 2026-11-05: a townspony steps out of a player or wild pony at REST inside 1.3 m and never from one on the move (test_npc_separation; test_find_market passes). Wild pony against wild pony is not done. (Tried twice on 2026-11-05 and reverted: townsfolk stepping out of the player's way were herded ahead of her into the Market wall, and a wider townsfolk capsule stopped a player walking straight at Old Fennel; both broke test_find_market. The fix has to keep the road passable: a soft push applied to the overlapping body that is NOT moving, never a wider solid.) `BodySpace` replaces the NPC-only push and is applied to wild ponies (against each other and the player) and to the player (a soft slide out of any pony body she is inside, never a hard stop). Test: two wild ponies spawned 0.3 m apart are over 1.2 m apart after 4 s; the player walked into a standing pony ends clear of her capsule plus body length. Commit.

### FS4. Animation feel (gap 4)

**Files:** create `tools/retarget_clips.py`, `game/actors/pony/gait_blend.gd`; modify `tools/convert_roster.sh`, `game/actors/pony/pony.gd`, `game/actors/player/player.gd`, `game/actors/player/magic_beam.gd`; tests `game/test/test_retarget.gd`, `game/test/test_gait_blend.gd`.

- [ ] **FS4.1 The Mane Six get the full clip set.** They ship idle, walk and gallop only; the PonySFM cast has 20 (cower, graze, hop, jump, laugh, lie, look, nod, rear, sad, shake, sit, sleep, startle, struggle, talk, trot). `retarget_clips.py` maps SFM bone names to the DEF_ rig (a name table, rest-pose corrected) and writes the clips into each Mane Six glb, run by `convert_roster.sh` after export. Test: every Mane Six glb carries all 20 clip names; a retargeted `sit` puts the hips lower than `idle` does. Commit.
- [ ] **FS4.2 Starts, stops and turns.** `GaitBlend` blends idle, walk, trot and gallop by speed (AnimationTree blend space), plays a short lean into a turn above 90 deg/s, and a settle step on stopping. Test: speed 0.5 m/s gives walk weight over 0.5; a stop from gallop passes through trot. Commit.
- [ ] **FS4.3 Reactions.** `startle` when a pony first notices the player, `struggle` while held in the beam, `hop` on landing in a pen (with the bounce), a stumble when the player lands hard. Test per trigger in `test_pony.gd` / `test_magic_beam.gd`. Commit.

### FS5. Sound in play (gap 5)

**Files:** modify `game/systems/music.gd`, `game/systems/sound.gd`; create `game/scenes/test/sound_capture.gd`; tests `game/test/test_music.gd`.

- [ ] **FS5.1 Hear the hoofs.** Tried 2026-11-05, INCONCLUSIVE: a Movie Maker capture of the bot's first two minutes shows no hoof onsets while walking, and raising every hoof set 6 dB changed the walking stretch's level by nothing, so the capture is not hearing them at all (test_footsteps confirms 80 steps play on 143 footfalls in the real game). Levels left as they were; needs a capture that records the 3D mix, or the owner's ear. Original task: `sound_capture.gd` records the bot's first two minutes with audio (Movie Maker, a real audio driver into a file); measure hoofstep loudness against the beds (hoofs 10 to 16 dB under the music at the listener) and fix the levels if not. Commit the measurement in PROGRESS.md.
- [ ] **FS5.2 Music that follows the moment.** `Music.stinger(id)` plays a short sting on a first catch, a rare catch, a delivery and a Bloom (the existing bus, ducking the bed 4 dB for the sting); contexts for the Market and the Depot. Test: a stinger ducks the bed and restores it within 2.5 s. Commit.

### FS6. The loop's menus (gap 6)

**Files:** modify `game/ui/market_menu.gd`, `game/ui/depot_menu.gd`, `game/ui/build_menu.gd`, `game/ui/menu_style.gd`; tests in their existing test files.

- [ ] **FS6.1 Motion.** Every tile menu opens with a 0.18 s scale-and-fade, tiles stagger in 30 ms apart, the hovered tile lifts 4 px, and a purchase flies a coin from the tile to the wallet. Test: a menu's panel reaches full scale within 0.25 s; a buy emits `purchased` and spawns the coin. Commit.
- [ ] **FS6.2 The Depot as a payout.** Delivering rolls each pony's pay up on her tile one by one with a counter sound, and the total lands on the balance with the receipt toast. Test: three deliveries give three roll-ups and one balance change of their sum. Commit.

### FS7. Something to spend on later (gap 7)

**Files:** create `game/data/decor/*.tres` (DecorItem), `game/systems/decor.gd`, `game/world/decor_layer.gd`; modify `game/systems/shop_item.gd` (Kind.DECOR), `game/ui/market_menu.gd` (a DECOR tab), `game/systems/save_io.gd`; tests `game/test/test_decor.gd`.

**Interfaces:** `Decor.place(id: StringName, at: Vector3, yaw: float) -> bool`, `Decor.saved() -> Array[Dictionary]`, `Decor.restore(rows: Array)`.

- [ ] **FS7.1 Decorate the ranch.** Twelve decorations from the existing prop kits (flower beds, lanterns, a fountain, bunting, a gazebo, and stone statues of the Mane Six: their own bodies in a stone material), 200 to 20,000 bits, placed with the plot ghost (green or red) anywhere on the homestead except pen gates, roads and NPC spots (the Review Focus case). Tests: a placement on a road is refused; placed decor survives save and load; a 20,000-bit item is affordable on a finished bot save. Commit.
- [ ] **FS7.2 Collection goals.** The compendium pays a bonus and unlocks one decoration for each full set (all of a rarity, all of a region, all the Mane Six). Test: completing a set grants once, never twice. Commit.

### FS8. Accessibility (gap 10)

**Files:** modify `game/systems/settings.gd`, `game/ui/settings_menu.gd`, `game/ui/catch_card.gd`, `game/ui/catch_icon.gd`, `game/ui/menu_style.gd`; tests `game/test/test_settings.gd`, `game/test/test_settings_menu.gd`, `game/test/test_catch_card.gd`.

- [x] **FS8.1 Rebinding.** Found already built (twelve actions, keyboard, saved, a taken key swapped onto the other action); 2026-11-05 added the menu naming the action that moved. Gamepad rebinding is not done. Original task: A Controls tab lists every action in `project.godot [input]` with its key and pad button; click and press to rebind; a key already bound elsewhere is refused with the other action named; binds save under `[binds]` in the settings file and an old file without it loads defaults (the Review Focus case). Tests for each. Commit.
- [ ] **FS8.2 Text size.** A Text size setting (100, 125, 150 percent) scales the theme's font sizes; at 150 percent at 1280x720 every menu fits on screen (the Review Focus case: each panel's rect inside the viewport, its last label unclipped). Commit.
- [ ] **FS8.3 Not colour alone.** Rarity on the catch card, the compendium and the Depot tiles carries a shape as well as a colour (common circle, uncommon diamond, rare star, legendary crown); trait chips keep their icons. Test: every rarity has a distinct shape glyph. Commit.

### FS9. Gates

- [ ] Full GUT; all real-input tests; the five endings (`tools/playthrough.sh`) in the frozen checkout; both exports; owner logs untouched; PROGRESS.md and DECISIONS.md updated.

---

## PT. The playtest sweep (2026-11-05): 70 items, fixed at the root

> Source: docs/playtest-2026-11-05.md (item numbers below are that list's). Owner: "tackle a lot of these from the root and make sure its not reoccuring similar elsewhere". Every group starts with the cause, gets a failing test that sweeps EVERY instance of that kind (all buildings, all menus, all ponies), then the fix. One subagent at most; no review videos; renders checked by me before a group is called done.

Order (highest pain first):

- [x] **PT1. Pony rigs** (17, 54, 67, 9, 7). Twilight twists; ponies merge; eyes vanish or change with distance; lidded look flips off up close; tail stutter; creator spin. Suspects: FS4.1 retarget and HoofPlanter on the Mane Six rig, PonyFace gaze/mood at range, eye LOD. Sweep test: every roster pony built, every clip played, no bone further than X from its rest relative to the body; eyes present at every LOD tier.
- [x] **PT2. Solid world** (41, 68, 31, 61, 43, 57, 58, 65). Walk-in Depot and soft-lock; camera into the Market; under the lake; stuck in the Palace plinth; spawn in hay; Tumble on the fence; pen crowd through the rails. Root: buildings and props with no collider, spawn points not checked against props, the pen herd not bounded. Sweep test: every building and solid prop has a collider covering its mesh; no spawn or wander point inside any; the player cannot enter any building; an unstuck if she is ever inside one.
- [x] **PT3. Pens, ownership and spawns** (70, 39, 63, 15, 53, 62, 65). Escapes from upgraded pens; owned repeats; "one of a kind" on duplicates; Old Fennel's bag line; the stuck "0/2"; "31 of 2" quota and cycle 1. Root first (does the pen tier survive save and load?).
- [x] **PT4. Bodies keep their space** (17 merge, 10, 13, 18, 3.3 remainder). One BodySpace push for wild vs wild, pen residents, the player, Tumble and townsfolk; conversations clear a ring; the companion never stands between the camera and the aim.
- [x] **PT5. One menu frame, fixed once** (30, 8, 20, 51, 42, 22, 24, 60, 59, 62). No key-hint rows, one Back button, a real scroll bar, real tabs (no "[Tab]"), plain body text (no outline), toasts wrapped and capped, HUD cards that never overlap, readable timings, paused toasts hold. Sweep test over every menu scene and every HUD card at all three text sizes.
- [x] **PT6. The casino rebuilt** (45 to 49). Wheel as tiered 1/3/5/10/20x; Blackjack with Hit/Stand/Double; Slots with a real strip, working bet chips, a lever and spin button; no text logs; nothing clips. 
- [x] **PT7. The world sits right** (29, 32, 36, 37, 25, 26, 14, 27, 40). Doors to pony scale (one scale rule per building), props upright on slopes (no tilt to the ground normal for buildings and posts), roads that meet, bramble art, sign backing, the sign flicker (fade toggling), the yellow blob, rain.
- [x] **PT8. Knowing where to go** (16, 38, 53, 66, 34, 35, 56, 57). Sightings light the compass and trail, never compass words; the compass gets icons, distances, N/E/S/W; townsfolk read as not catchable; Spike has a job; the coat stallion walks past.
- [x] **PT9. Economy that explains itself** (33, 52, 64, 55, 69). Delivery pays visibly against the debt; food is easy to buy and shows its effect; areas show what they hold and open with a rare; catching gets harder by tier.
- [x] **PT10. Words** (11, 28, 50, 56). Fennel rewritten; Rainbow Factory hints later and subtler.
- [x] **PT11. Odds and ends** (1 fullscreen, 12 pause in talk, 21/23 bounce from the beam and side-on landing, 2 to 6 creator).

Gates per group: the new sweep test, the touched GUT files and real-input tests. At the end: full GUT, all real-input tests, the five endings, both exports.
