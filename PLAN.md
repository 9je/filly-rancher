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
