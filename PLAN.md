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

- [x] **FS1.1 Objective rules.** Done 2026-11-05 (c633776). Test first, one assertion per chapter of STORY.md: chapter 0 before the Scoop "talk to Marigold"; SUNNY after the lessons "deliver ponies to the Depot (n/3)"; WEATHER with the invitation "meet Marigold at the Depot"; COMPANY "fill the contract (got/want)"; RESISTANCE per path; every unnamed state (the Review Focus case, including `ending != ""`) returns `{}`. Implement as a table, not branches scattered through ranch.gd. Commit.
- [x] **FS1.2 The main path on the trail.** Done 2026-11-05 (9921242). `Guide.pick` falls through to `Objective.current(s).goal` when nothing is waiting on her, so the trail and the compass ring point at the story's next place mid-game. Test: a SUNNY state with no mail and no news picks `&"depot"`. Commit.
- [x] **FS1.3 The objective card.** Done 2026-11-05 (cc00f25). A small casino-tile card under the compass: the goal's PlaceSign icon, the words, the metres to it, sliding in on change with the existing `MenuStyle` panel style; hidden when `{}`. Real-input test `test_objective_card`: after the first catch the card names the pens; after penning, the Depot; its distance falls as the bot walks toward it. Commit.
- [ ] **FS1.4 The checklist as chips.** PARTLY DONE 2026-11-05 (8119735); missing: the chips carry no hover tooltip with the sentence (review 2026-11-06). `hud.set_tasks` draws each tutorial row as an icon chip (the action's icon, lit when done, its bit reward on the chip), no sentences; the sentence moves to a hover tooltip. Test in `test_hud.gd`: three rows give three chips, a done row is lit. Commit.
- [x] **FS1.5 Trail at play distance.** Done 2026-11-06 (scenes/test/trail_shot.gd, frames in build/playtest_evidence/fs1/): past 8 m the motes were specks; they now grow 7% a metre along the run in richer colour, and the beacon starts at 45% strength. Original: Render the bot's first five minutes (`--shots`) and inspect the frames with a goal set; if the motes do not read at 8 to 15 m, raise `GuideTrail` quad size and core brightness until they do. Record the frames in `build/playtest_evidence/fs1/`. Commit.

### FS2. One look across the world (gap 2)

**Files:** modify `game/shaders/toon.gdshader`, `game/systems/toon_styler.gd`, `game/world/terrain.gd` and its shader, `game/world/ranch.tscn` (environment), `game/world/props.gd`; test `game/test/test_toon_styler.gd`, render script `game/scenes/test/look_sheet.gd` (new).

- [x] **FS2.1 Pale coats keep their shape.** DROPPED 2026-11-05 on evidence: in the game's own light a white pony shows full shading and no pure-white pixels (bot frame t01_30); the blow-out was the face-render harness's lighting (scenes/test/roster_eyes.gd, ambient 0.75 and no tonemap), not the game's. Original task: Root cause first: measure which term pushes a white coat to pure white (ambient plus sun plus rim, or the tonemap). Fix with a highlight shoulder in the toon light (lit colour capped below 0.96 of white, shadow band kept visible on luminance above 0.85). Test: for an albedo of 0.97 the lit side stays under 0.96 and the shadow side differs from it by at least 0.12. Render the roster faces (`scenes/test/roster_eyes.gd`) before and after. Commit.
- [ ] **FS2.2 Ground with life.** PARTLY DONE 2026-11-05 (7ab9308); missing: the fine painted noise and the darker grass at prop and fence bases (review 2026-11-06). The terrain shader gets a large-scale hue drift (two greens), a fine painted noise and darker grass at prop and fence bases (a contact term from the prop footprint mask). Test: two samples 40 m apart differ in hue; a sample under a fence base is darker than open grass. Render spawn views. Commit.
- [x] **FS2.3 One palette for the kit.** Done 2026-11-06: measured every placed family's mean albedo (test/test_kit_palette.gd); seven were near black (corn 0.15, swing frame 0.17, dead trees 0.18 to 0.26, picnic table, bare apple tree, bush) and get ToonStyler.FAMILY_LIFT; none was over-saturated. Before/after in build/playtest_evidence/fs2/ (scenes/test/look_sheet.gd). Original: `look_sheet.gd` renders one tile per prop family and building beside a pony under the game's light; any family whose albedo falls outside the show palette's saturation and value bands gets a per-family tint in `ToonStyler.PRESETS`. Test: every family's mean albedo is inside the bands. Commit with the sheet.

### FS3. Faces and bodies (gap 3)

**Files:** modify `game/actors/pony/pony_face.gd`, `game/actors/pony/pony_visuals.gd`, `game/actors/pony/pony.gd`, `game/actors/player/player.gd`, `game/world/spawner.gd`; create `game/actors/pony/body_space.gd`; tests `game/test/test_pony_face.gd`, `game/test/test_body_space.gd`.

**Interfaces:**
- `PonyFace` gains `const RIG_NAMES := {&"lid_l": ["LeftEyeLidUpper", "CON_UpperEyelid.L"], ...}` so both rigs resolve; `PonyVisuals.build` attaches one to every body.
- `Pony.set_mood(m: PonyFace.Mood)`; moods driven by state: fleeing SCARED, held SCARED, penned and fed HAPPY, hungry SAD.
- `BodySpace.push(self_pos: Vector3, others: Array, reach: float) -> Vector3` (the townsfolk separation, made shared).

- [ ] **FS3.1 Every pony blinks and emotes.** PARTLY DONE 2026-11-05 (da94ec4); missing: no hungry SAD mood; penned reads HAPPY whether fed or not (review 2026-11-06). Tests: a built Fluttershy and a built Apple Bloom both resolve lid, ear and jaw bones; a pony set to SCARED drops her ears; a FAR-tier pony's face does not process (the Review Focus perf case). Run `tools/perf.sh` and keep p99 at or under 16.6 ms. Commit.
- [x] **FS3.2 Eyes that look.** Done 2026-11-05 (da0a3ba). The eye shader's `gaze` (added for Derpy) follows the player when she is within 6 m and the pony is idle or penned, clamped to 0.08 UV; Derpy keeps her offset on top. Test: gaze points toward a target on the left for both eyes. Commit.
- [x] **FS3.3 Bodies do not pass through bodies.** Done for townsfolk 2026-11-05: a townspony steps out of a player or wild pony at REST inside 1.3 m and never from one on the move (test_npc_separation; test_find_market passes). Wild pony against wild pony is not done. (Tried twice on 2026-11-05 and reverted: townsfolk stepping out of the player's way were herded ahead of her into the Market wall, and a wider townsfolk capsule stopped a player walking straight at Old Fennel; both broke test_find_market. The fix has to keep the road passable: a soft push applied to the overlapping body that is NOT moving, never a wider solid.) `BodySpace` replaces the NPC-only push and is applied to wild ponies (against each other and the player) and to the player (a soft slide out of any pony body she is inside, never a hard stop). Test: two wild ponies spawned 0.3 m apart are over 1.2 m apart after 4 s; the player walked into a standing pony ends clear of her capsule plus body length. Commit.

### FS4. Animation feel (gap 4)

**Files:** create `tools/retarget_clips.py`, `game/actors/pony/gait_blend.gd`; modify `tools/convert_roster.sh`, `game/actors/pony/pony.gd`, `game/actors/player/player.gd`, `game/actors/player/magic_beam.gd`; tests `game/test/test_retarget.gd`, `game/test/test_gait_blend.gd`.

- [x] **FS4.1 The Mane Six get the full clip set.** Done 2026-11-05 (73c3ae0). They ship idle, walk and gallop only; the PonySFM cast has 20 (cower, graze, hop, jump, laugh, lie, look, nod, rear, sad, shake, sit, sleep, startle, struggle, talk, trot). `retarget_clips.py` maps SFM bone names to the DEF_ rig (a name table, rest-pose corrected) and writes the clips into each Mane Six glb, run by `convert_roster.sh` after export. Test: every Mane Six glb carries all 20 clip names; a retargeted `sit` puts the hips lower than `idle` does. Commit.
- [x] **FS4.2 Starts, stops and turns.** Done 2026-11-06 as systems/gait_blend.gd over the AnimationPlayer (not an AnimationTree: two rigs, same result): shown speed falls at 12 m/s2, one rung down per unbroken 0.12 s, a bank up to 10 deg above 90 deg/s; player, ponies and NPCs. Original: `GaitBlend` blends idle, walk, trot and gallop by speed (AnimationTree blend space), plays a short lean into a turn above 90 deg/s, and a settle step on stopping. Test: speed 0.5 m/s gives walk weight over 0.5; a stop from gallop passes through trot. Commit.
- [ ] **FS4.3 Reactions.** PARTLY DONE 2026-11-05 (6ee4981); missing: a stumble on a hard landing (startle and hop added; struggle was there) (review 2026-11-06). `startle` when a pony first notices the player, `struggle` while held in the beam, `hop` on landing in a pen (with the bounce), a stumble when the player lands hard. Test per trigger in `test_pony.gd` / `test_magic_beam.gd`. Commit.

### FS5. Sound in play (gap 5)

**Files:** modify `game/systems/music.gd`, `game/systems/sound.gd`; create `game/scenes/test/sound_capture.gd`; tests `game/test/test_music.gd`.

- [ ] **FS5.1 Hear the hoofs.** Tried 2026-11-05, INCONCLUSIVE: a Movie Maker capture of the bot's first two minutes shows no hoof onsets while walking, and raising every hoof set 6 dB changed the walking stretch's level by nothing, so the capture is not hearing them at all (test_footsteps confirms 80 steps play on 143 footfalls in the real game). Levels left as they were; needs a capture that records the 3D mix, or the owner's ear. Original task: `sound_capture.gd` records the bot's first two minutes with audio (Movie Maker, a real audio driver into a file); measure hoofstep loudness against the beds (hoofs 10 to 16 dB under the music at the listener) and fix the levels if not. Commit the measurement in PROGRESS.md.
- [ ] **FS5.2 Music that follows the moment.** PARTLY DONE 2026-11-05 (247becc); missing: no Market or Depot music contexts; the duck is 5 dB, not 4 (review 2026-11-06). `Music.stinger(id)` plays a short sting on a first catch, a rare catch, a delivery and a Bloom (the existing bus, ducking the bed 4 dB for the sting); contexts for the Market and the Depot. Test: a stinger ducks the bed and restores it within 2.5 s. Commit.

### FS6. The loop's menus (gap 6)

**Files:** modify `game/ui/market_menu.gd`, `game/ui/depot_menu.gd`, `game/ui/build_menu.gd`, `game/ui/menu_style.gd`; tests in their existing test files.

- [ ] **FS6.1 Motion.** PARTLY DONE 2026-11-05 (d381fce); missing: the 30 ms tile stagger, no coin flying to the wallet (review 2026-11-06). Every tile menu opens with a 0.18 s scale-and-fade, tiles stagger in 30 ms apart, the hovered tile lifts 4 px, and a purchase flies a coin from the tile to the wallet. Test: a menu's panel reaches full scale within 0.25 s; a buy emits `purchased` and spawns the coin. Commit.
- [ ] **FS6.2 The Depot as a payout.** PARTLY DONE 2026-11-05 (f12fbe4); missing: a per-tile roll-up with a counter sound landing on the balance (review 2026-11-06). Delivering rolls each pony's pay up on her tile one by one with a counter sound, and the total lands on the balance with the receipt toast. Test: three deliveries give three roll-ups and one balance change of their sum. Commit.

### FS7. Something to spend on later (gap 7)

**Files:** create `game/data/decor/*.tres` (DecorItem), `game/systems/decor.gd`, `game/world/decor_layer.gd`; modify `game/systems/shop_item.gd` (Kind.DECOR), `game/ui/market_menu.gd` (a DECOR tab), `game/systems/save_io.gd`; tests `game/test/test_decor.gd`.

**Interfaces:** `Decor.place(id: StringName, at: Vector3, yaw: float) -> bool`, `Decor.saved() -> Array[Dictionary]`, `Decor.restore(rows: Array)`.

- [x] **FS7.1 Decorate the ranch.** Done 2026-11-05 (6257d80). Twelve decorations from the existing prop kits (flower beds, lanterns, a fountain, bunting, a gazebo, and stone statues of the Mane Six: their own bodies in a stone material), 200 to 20,000 bits, placed with the plot ghost (green or red) anywhere on the homestead except pen gates, roads and NPC spots (the Review Focus case). Tests: a placement on a road is refused; placed decor survives save and load; a 20,000-bit item is affordable on a finished bot save. Commit.
- [x] **FS7.2 Collection goals.** Done 2026-11-05 (2a4891f). The compendium pays a bonus and unlocks one decoration for each full set (all of a rarity, all of a region, all the Mane Six). Test: completing a set grants once, never twice. Commit.

### FS8. Accessibility (gap 10)

**Files:** modify `game/systems/settings.gd`, `game/ui/settings_menu.gd`, `game/ui/catch_card.gd`, `game/ui/catch_icon.gd`, `game/ui/menu_style.gd`; tests `game/test/test_settings.gd`, `game/test/test_settings_menu.gd`, `game/test/test_catch_card.gd`.

- [x] **FS8.1 Rebinding.** Found already built (twelve actions, keyboard, saved, a taken key swapped onto the other action); 2026-11-05 added the menu naming the action that moved. 2026-11-06: gamepad rebinding by the same rules (the eight actions with a button; B, Guide and the zoom D-pad reserved; sticks fixed). Original task: A Controls tab lists every action in `project.godot [input]` with its key and pad button; click and press to rebind; a key already bound elsewhere is refused with the other action named; binds save under `[binds]` in the settings file and an old file without it loads defaults (the Review Focus case). Tests for each. Commit.
- [x] **FS8.2 Text size.** Done 2026-11-05 (ea28035 (the ranch applies it too since the 2026-11-06 review)). A Text size setting (100, 125, 150 percent) scales the theme's font sizes; at 150 percent at 1280x720 every menu fits on screen (the Review Focus case: each panel's rect inside the viewport, its last label unclipped). Commit.
- [ ] **FS8.3 Not colour alone.** PARTLY DONE 2026-11-05 (49c1c43); missing: the Depot tiles (the shapes are in the saddlebag pips and the compendium) (review 2026-11-06). Rarity on the catch card, the compendium and the Depot tiles carries a shape as well as a colour (common circle, uncommon diamond, rare star, legendary crown); trait chips keep their icons. Test: every rarity has a distinct shape glyph. Commit.

### FS9. Gates

- [ ] Full GUT; all real-input tests; ~~the five endings~~ (retired as a gate 2026-11-06, see DECISIONS.md; real-input loading, pen_upgrade and sprint fail in one batch and pass alone, cause not yet found); both exports; owner logs untouched; PROGRESS.md and DECISIONS.md updated.

---

## PT. The playtest sweep (2026-11-05): 70 items, fixed at the root

> **2026-11-06: these ticks were wrong.** They were set because a commit cited the item, not because the item was checked. An audit found items 3, 6, 29, 32, 36, 44, 55, 64 and 69 not met and 17, 37, 40, 56 unverified. Superseded by section PS below, which re-opens all 70.

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

## PS. The playtest sweep, no exceptions (planned 2026-11-06)

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (owner rule: at most one subagent at a time, Opus 5.5 only; Fable only for the acceptance review; never Sonnet, Haiku or an older Opus (owner 2026-11-06)). Steps use checkbox (`- [ ]`) syntax.

**Goal:** every one of the 70 items in docs/playtest-2026-11-05.md is met as the owner worded it, plus every known open gap, and each one is proven by evidence somebody other than the implementer has judged.

**Architecture:** a ledger (`docs/playtest-2026-11-05-ledger.md`) holds one row per item: the owner's words, its state, the evidence and who judged it. A render harness (`scenes/test/playtest_shots.gd`) frames the owner's screenshot spots. Each item follows the same loop: render or test the item as it is now, fix the cause, then render or test it again. An acceptance reviewer then reads only the owner's text and the evidence. The previous sweep's ticks (section PT) count for nothing; all 70 start open.

**Tech stack:** Godot 4.7.2, typed GDScript, GUT (`tools/gut_one.sh`, `tools/run_tests.sh`), real-input tests (`tools/run_input_tests.sh`), invisible xvfb renders.

**Spec:** docs/playtest-2026-11-05.md (the owner's 70 items and screenshots in the session images folder it names), plus the gaps listed in task PS12.

### Global constraints (every task; breaking one fails the task)

- Never push. Stay on v1-overhaul. Stage only my own files.
- No em dashes; the house dash is " -- ". Canon MLP names stay. No realistic pony vocals (the rare capture neigh is the one exception). AI voices are on hold.
- Never open a visible window or take the mouse or the screen. Every Godot launch is an invisible xvfb launch with FILLY_TEST_SAVE_DIR and --log-file set. Run `git checkout -q build/playtest_evidence` after input tests.
- **No bot playthroughs** (`tools/playthrough*.sh`), not as a gate and not as a check.
- At most one subagent at a time, on Opus 5.5 (never Sonnet, Haiku or an older Opus; owner 2026-11-06). Fable only for PS13's acceptance review.
- Root cause and a failing test first. No game-file edits while a test run is going.
- Never raise IP, Hasbro or a store release.
- **An item is ticked in the ledger only when its evidence exists and has been looked at**, never because a commit names it. A render is opened and looked at before it counts. Report test results exactly, flakes included. No "all done" report: the report is the ledger.

### The item loop (every item row below runs this)

0. **Items already claimed fixed** (marked `claimed` in the tables) are not re-worked. One batched pass takes a single render or test of each, and I look at it. Only the ones that fail go through the loop below; the ones that pass get state `FIXED-UNREVIEWED` with that evidence. The owner asked that this not eat hours.
1. **Before:** render the item's spot (`playtest_shots.gd --item=N`) or run its test, and confirm the problem shows. If it doesn't show, write down why and keep the render as evidence; the item is not skipped.
2. **Test:** write a test that asserts the owner's words as directly as code can. It must fail.
3. **Fix:** fix the cause, then search for the same cause elsewhere (the owner's standing ask) and fix that too.
4. **After:** the test passes; render the same frame again and look at it.
5. **Ledger:** the row gets the commit, the test name, the before and after render paths, and state `FIXED-UNREVIEWED`. Only PS13 sets `MET`.

### Review focus (cases the items imply but no single row tests)

1. A save made before this sweep loads cleanly after it: no placed prop, pen or pony lost, and nobody duplicated.
2. Every fix also holds at 1280x720 and at 150% text size.
3. Every fix also holds at night and in rain (the owner played through both).
4. Every fix also holds on the Mane Six rig as well as the PonySFM rig.
5. A gamepad-only player can reach every new control (creator tools, area preview, pantry).

Each of these is covered by a test in the task that owns the code: PS0 (1), PS6 (2), PS4 (3), PS1 (4), PS6 and PS10 (5).

---

### Task PS0: The ledger and the shot harness

**Files:** create `docs/playtest-2026-11-05-ledger.md`, `game/scenes/test/playtest_shots.gd`. Test `game/test/test_ledger_complete.gd`.

- [x] Ledger: 71 rows (56 is two items: the coat line and the walk-by). Columns: item, the owner's words verbatim, screenshot, state (`OPEN`, `FIXED-UNREVIEWED`, `MET`, `NOT-MET`), evidence (test name, render paths), commit, judged by.
- [x] `test_ledger_complete.gd` parses the ledger and fails unless every number from 1 to 70 has a row and every row has a state. It also fails when a row says `MET` but its evidence column is empty.
- [x] `playtest_shots.gd --item=N --out=DIR` loads a seeded save and puts the camera and the player at the pose that matches screenshot N. The pose table lives in the script, one pose per screenshot the doc references, estimated by eye from the owner's image. It writes `itemN_<label>.png` with a day and a night/rain variant where the item is about the world. For each pose, a render is taken and compared by eye with the owner's screenshot until they show the same place.
- [x] Old-save check (review focus 1): `test_old_save_loads.gd` loads a save from 13d0c11 with placed decor, penned ponies, an escapee and a full bag, and asserts the counts survive.
- [ ] Commit: "PS0: ledger and shot harness".

**PS0 notes (2026-11-06):** the ledger has 84 rows: items 1 to 70 (17 split into 17/17b, 19/23 one row, 56 split into 56a/56b), Marigold (M) and the known gaps G1 to G12. The harness has 16 poses for the owner's world screenshots ([21] [24] [25] [27] [29] [30] [31] [32] [33] [34] [35] [37] [45] [48] [49] [52]), each looked at beside the owner's image; the before renders are in build/ps_evidence/before/. UI screenshots are PS6's (hud_shot), and the pony shots [19] [53] [54] are PS1's (they need posed ponies, not a camera spot). The old save is a fixture written by `scenes/test/make_old_save.gd` on the pre-sweep code. Loading it found a real bug: an Escape Artist home on a load (or at dawn) was missing from `_owned_named_ids()`, so the wild could spawn a second of her (items 39, 63, 70). The same cause sat in the Survey's picker (`owned_rows()`, item 51). Both now read the pens and the bag (`_owned_named_ids()` directly, the picker and its answer through the new `_owned_instances()`); tests `test_old_save_loads`, `test_ranch_mail.test_the_survey_can_name_a_pony_caught_since_the_last_save`.

### Task PS1: Pony bodies (items 7, 9, 10, 13, 17, 19/23, 21, 54, 65, 67)

**Files:** likely `actors/pony/pony.gd`, `pony_visuals.gd`, `pony_face.gd`, `world/pen.gd`, `systems/body_space.gd`, `actors/player/player.gd`, `ui/creation_screen.gd`.

| Item | What it needs (owner's words, short) | Known state | Evidence that closes it |
|---|---|---|---|
| 17 | Twilight twisted at a broken angle (top priority) [21][52] | UNVERIFIED. The fix assumed overlap, but [52] shows her rolled on her side | First, a render reproduces it (Twilight in a full Paddock, dropped from the beam, landing, bounced). Then a test asserts her root and hip roll stay under 25° through the pen landing turn, the bounce, HoofPlanter and the lean. Rendered for every Mane Six pony |
| 17b | Ponies merge (wild vs wild) [19][54] | claimed, unverified | Render of 8 wild ponies in one clearing after 60 s: no visible overlap. test_body_space covers wild vs wild |
| 65 | Full pen piles in a corner, overlaps, pushes through the fence; "moved into the pen" while the prompt says full [52] | partly | Render of a full Grand Pen after 120 s: spread out, nobody outside the fence. The toast for the pony that fills the pen says she moved in *and* the pen is now full |
| 10, 13 | A pony walks through a conversation; Tumble spawns inside the player mid-talk | claimed | Tests: a conversation ring clears; Tumble's spawn point is at least 1.5 m from the player |
| 19/23, 21 | The bounce is barely seen; a drop from the beam at height bounces | claimed | A gait_shot frame strip of a drop from 3 m and a pen landing, with the bounce visible from the default camera |
| 54, 67 | Far ponies have no eyes; the half-lidded look switches off up close | claimed | An eye_shot strip at 4, 12, 30 and 60 m: eyes present and the same shape; the half-lidded look is held at 2 m |
| 9 | The player's tail stutters | claimed | A 60-frame strip at 144 Hz physics/render mismatch: tail positions change smoothly from frame to frame (test on the delta) |
| 7 | Creator spin flings the mane; the tail clips the body | claimed | A turntable render at full spin speed: no spikes, no tail inside the body |

- [ ] Run the item loop for each row. Commit per row: "PS1 item N: ...".

### Task PS2: A solid world (items 31, 41, 43, 57, 58, 61, 68)

| Item | Needs | Known state | Evidence |
|---|---|---|---|
| 41, 68 | Can't walk into the Depot; no rain inside; never soft-locked | claimed | Real-input test walking into every building door; render at the Depot [35][55] |
| 31 | The camera never enters the Market | claimed | Camera-terrain input test orbiting every building; render [29] |
| 43 | Nobody stuck in the Palace plinth | claimed | Test: every townspony's spot is outside every collider; render [37] |
| 61 | Lake: no walking under the water, no half-sunk ponies, no grass through the water, real banks | claimed for floor and walls; banks unverified | Render at [48][49], day and night: banks visible, water opaque. Existing lake tests |
| 57 | No pony spawns inside a haystack | claimed | Spawner test across 500 seeds |
| 58 | Tumble never stuck on the Orchard fence | claimed | Companion catch-up test at the Orchard fence |

### Task PS3: Pens, ownership, the Depot (items 15, 39, 53, 62, 63, 70)

| Item | Needs | Known state | Evidence |
|---|---|---|---|
| 39, 63, 70 | No duplicates of a named pony anywhere; no escapes from upgraded pens; the "one of a kind" tag is right | escapee recatch fixed 72e9736 | One test runs 10 in-game nights with upgraded pens, a recatch, save and load, and asserts no duplicate data_id. The Deliver list tags only unique ponies |
| 53 | The trail stops pointing at an upgraded paddock ("0/2") [45] | claimed | Guide test after an upgrade, and a render of the trail |
| 62 | The Depot statement is right: quota, cycle, collections [50] | claimed | Test after 3 cycles; render of the statement |
| 15 | Old Fennel's bag line matches the bag | claimed | Test with an empty bag and with a full bag |

### Task PS4: The world looks right (items 14, 25, 26, 27, 29, 32, 36, 37, 40)

**Files:** `world/building.gd`, `world/props.gd`, `world/region_dressing.gd`, `world/strip.gd`, `world/terrain.gd`, `world/sky_rig.gd`, SCALE.md; a new `world/street.gd` for the Ponyville row.

| Item | Needs | Known state | Fix decided | Evidence |
|---|---|---|---|---|
| 29 | Doors to pony scale; no oversized porches and ramps [27][31] | **NOT DONE** | Owner-approved: scale buildings up, not ponies down. Each building model gets a measured door height in a table in building.gd. Its scale is set so the door is at least 1.25 times the player's standing height, and layout spacing is adjusted where bigger buildings now crowd. A ramp is never longer than 1.5 m | `test_doors_fit` sweeps every building; renders [27][31] beside the player |
| 32 | Barn yard: barn not on a plinth, ramp size, mismatched shed, wagon, hay and seed bags, scattered [30] | **plinth only** | The yard props are laid out on a grid by the barn door, scaled by SCALE.md's one rule; the shed is swapped for a kit match | Render [30] |
| 36 | Ponyville row: houses lean and sink, lamps lean, no streets or yards, the road junction [33] | **sinking only** | Buildings and lamps stay upright (no tilt to the ground normal). A paved street runs along the row's frontage (`street.gd`, the Strip's paving reused), with a fenced yard per house and a blended join where the grey road meets the dirt road | `test_upright` (every building and lamp has up within 2° of world up); render [33] |
| 37 | The Strip: tilted cabinets, floating track, leaning lamps, dirt across the paving [34] | **paving and slabs only** | The track is seated on the terrain; cabinets and lamps are upright | `test_upright` covers them; render [34] |
| 40 | Rain too heavy and cheap; night plus rain too dark [45] | rain softened; darkness unverified | Night and rain together keep the scene's mean luminance at or above a floor measured from a lit night | Luminance test on a night-plus-rain render; render [45] |
| 25, 26, 27 | Brambles, the CLEAR ME board, the yellow blob [24][25] | claimed | -- | Renders [24][25] |
| 14 | Signs flicker [32] | claimed | -- | A 120-frame render walking past the fingerpost: every board is lit in every frame |

### Task PS5: The casino (items 44 to 49)

| Item | Needs | Known state | Fix decided | Evidence |
|---|---|---|---|---|
| 44 | Patrons not frozen [38] | **NOT DONE** | Attendants get a PonyFace (blinks, moods) and a cycle of clips: a slot pull, cheer, sit and look around, with their timing staggered. Regulars move between free machines every 30 to 90 s | Test: each regular plays at least 3 clips in 120 s, and one changes machine; a palace_shot strip |
| 45, 46, 47, 48, 49 | Wheel, slots, blackjack rebuilt as specified [39][40][41][42] | claimed | -- | A casino_shot render of each table checked against each item's words (tiers, no tabs, no log, three different symbols, working chips, a lever, Hit/Stand/Double, a banner that fits) |

### Task PS6: Menus and HUD (items 8, 20, 22, 24, 30, 42, 51, 59, 60, 66)

All claimed in 5a57c38 and e560489; all unverified as renders. For each item: a hud_shot render at 1280x720 and at 1920x1080, at 100% and 150% text (review focus 2), plus pad-only navigation of every menu (review focus 5, a real-input test). Items: the welcome letter (8), thick text (20), the catch card over the strip (22), the objective card over the chips (24), every menu's key hints, Back and scroll bar, and the Compendium's "0 of 0" and "???" rows (30), the giant toast (42), the mailbox and the survey (51), toasts too fast and cleared by pausing (59), pips at 18 slots (60), the compass (66).

Also in PS6: fullscreen chosen during loading stays fullscreen (1; `test_fullscreen_kept` plus a window-size check after load), and pausing works mid conversation and returns to the same line (12; `test_pause_in_talk`). And what the owner liked must survive the sweep: the rare capture neigh still plays (a sound test), and the half-lidded look is unchanged (PS1's item 67 render).

### Task PS7: The creator (items 2 to 6)

| Item | Needs | Known state | Fix decided | Evidence |
|---|---|---|---|---|
| 2 | A Random button | done (Surprise me) | -- | creation render |
| 3 | Better cutie mark creation | **gallery only** | Owner-approved: the mark canvas gets stamps: up to three symbols from the 24 talents plus 12 shapes, each moved, scaled, rotated and recoloured by drag, with undo | Test of the stamp operations; a render of a composed mark on the flank |
| 4, 5 | Mane style under Mane and tail; the streak row only when used | claimed | -- | creation render |
| 6 | More customisation | **NOT DONE** | Owner-approved, all three: coat markings (socks, blaze, dapples, a star) as masks in the coat shader with their own colour; six new accessories from the kit; eye shape (round, almond, sleepy) | Test: each option survives save and load; a turntable render of each |

### Task PS8: Knowing where to go, and the people (items 11, 16, 18, 28, 34, 35, 38, 50, 56a, 56b, Marigold)

| Item | Needs | Known state | Fix decided | Evidence |
|---|---|---|---|---|
| 56a | The coat stallion: the dialogue says coat but there's no coat | **reworded, and the new toast names a clipboard he doesn't hold** | The Collector wears a grey coat (a coat mesh on the pony rig, from the accessory kit) and carries a clipboard prop. Every narrating toast is removed; the walk-by is shown | Render of him at the fence; test: no toast fires during the walk-by |
| 56b | A mysterious walk-by, not a slow shuffle | claimed | -- | A frame strip of the walk-by |
| Marigold | She walks in front of the camera when she greets you | **NOT DONE** | Greeting townsfolk stop on the side of the player away from the camera | Test: during a greeting, no NPC stands within 1 m of the camera-to-player segment |
| 16 | The first catch's place is shown | claimed | -- | Render at the start: the trail points at a Drifter |
| 18 | Tumble is not in front of the camera, and her prompt doesn't steal E at catch time | claimed | -- | heel_shot strip; input test |
| 34, 35, 38 | Townsfolk read as not catchable; Spike has a purpose; sightings light the compass | claimed | -- | Renders and the existing tests named in the ledger |
| 11, 28, 50 | Pip's line, Fennel's lines, the Rainbow Factory hints | claimed | -- | The ledger quotes the new text beside the owner's complaint |

### Task PS9: Economy and difficulty (items 33, 52, 55, 64, 69)

**Files:** `actors/player/magic_beam.gd`, `actors/pony/pony.gd`, `world/spawner.gd`, `systems/ledger.gd`, `data/shop/*.tres`, `ui/market_menu.gd`, a HUD pantry chip, `tools/pacing.sh`.

| Item | Needs | Known state | Fix decided | Evidence |
|---|---|---|---|---|
| 69 | Catching too easy apart from the toughest, and repetitive; 49 deliveries came fast; ~800 gems per Market trip | **only uncommon and rarer ponies weave** | Owner-approved 2026-11-06: (a) **Every rarity weaves**, scaled: Drifter 0.35, common 0.55, uncommon 0.8, rare 1.0, legendary 1.2. (b) **Smarter fleeing**: ponies notice the player from further away and flee in curves, cutting behind trees and props, so you sneak or corner them. (No catch-behaviour types and no beam stamina; the owner declined both.) (c) **Pacing, both halfway**: the owner's money came from selling every pony that wasn't one of a kind and keeping the best earners. So the sale price of a repeat falls with each sale of the same pony in a cycle (full, then 70%, 50%, floor 35%, reset each cycle), other earnings are trimmed by about 15%, and pens, permits, gear and decor cost about 15% more. Bands enforced by the pacing sim, which replays the owner's sell-the-repeats strategy: under 20 deliveries in the first hour, 250 to 400 gems per mid-game Market trip, and the debt still paid within the story's 3 cycles | `test_beam_weave` per rarity; a flee test (the first noticing distance grows, and the path bends around an obstacle); a repeat-sale test (the falling price, and the reset at a new cycle). `tools/pacing.sh` writes the numbers to PACING.md and fails outside the bands. A common catch takes at least 2 s of tracking in the beam probe |
| 55 | An area shows its ponies and their times before you buy; it opens with a guaranteed rare | **rare done; preview NOT DONE** | The permit tile in the Market lists the region's ponies (portrait, rarity shape, the time of day they come out) | Test on the tile's rows; render of the tile |
| 64 | Feeding is automatic and nothing says so: show the pantry stock and the hungry state | **NOT DONE (Spike only)** | A pantry chip by each pen's sign shows the food count and how many residents are hungry. A hungry pony wears a small food bubble and the SAD mood (FS3.1's missing part) | Test: an empty pantry lights the chip; a hungry pony is SAD; render |
| 33 | The debt is explained; a delivery shows pay | claimed | -- | Render of the Depot tile and the toast |
| 52 | The Market buy screen is easy to find; food is easy to buy | claimed | -- | Render of the Market opening on Buy |

**PS9 implementation notes (2026-11-06, before coding):**
- Weave: `MagicBeam.WEAVE_BY_RARITY` becomes [0.55, 0.8, 1.0, 1.2] by rarity and a Drifter (stock) weaves at 0.35; a common needs at least 2 s on the crosshair (beam probe).
- Fleeing: the notice radius grows by a quarter; a fleeing pony probes ahead and bends toward the open side of a tree or prop rather than running straight into it.
- Repeat deliveries: `Ledger` counts deliveries per kind per cycle (every Drifter is one kind) and scales the credit and the handler share by 1.0, 0.7, 0.5, then 0.35; the count resets at a new cycle.
- Halfway: gem sales pay 0.85 of today; pens, permits, gear and decor cost 1.15 of today, rounded to 5.
- The pacing check is a model, not the bot: `tools/pacing.sh` is a bot playthrough (banned by the owner), so `test_pacing_model.gd` replays the sell-the-repeats strategy from the game's own constants and asserts the three bands.

### Task PS10: The FS parts built short (from the review on 2026-11-06)

- [ ] FS1.4: hovering a lesson chip shows its sentence as a tooltip (the chips take the mouse).
- [ ] FS2.2: the ground's fine painted grain, and darker grass at prop and fence bases.
- [ ] FS3.1: a hungry pony is SAD (shared with PS9's item 64).
- [ ] FS4.3: a stumble when the player lands hard.
- [ ] FS5.2: Market and Depot music contexts; the duck set to 4 dB.
- [ ] FS6.1: tiles stagger in 30 ms apart, and a purchase flies a coin to the wallet.
- [ ] FS6.2: the Depot pays out per tile, one by one, with a counter sound, and the total lands on the balance.
- [ ] FS8.3: rarity shapes on the Depot tiles.
- [ ] FS5.1: hoof loudness. A capture that records the 3D mix (a Movie Maker run at the listener), measured against the beds. If it still can't be measured, the ledger says so and the owner's ear decides it.

Each part gets a test and a render under the item loop.

### Task PS11: The test bench itself

- [ ] Find out why loading, pen_upgrade and sprint fail in a full `run_input_tests.sh` batch but pass alone. Fix the cause (shared save directory, leftover state, or timing), then run the whole batch twice with every test passing.
- [ ] The 60-pony performance check (`tools/perf.sh`, p99 at or under 16.6 ms) and a Proton smoke run of the Windows build.

### Task PS12: Gaps outside the owner's list (known on 2026-11-06)

Marigold (in PS8), the FS parts (PS10), the batch flake and perf/Proton (PS11). Anything new found while working is added to the ledger as a row; nothing is fixed off the books.

### Task PS13: Acceptance (the gate)

- [ ] A Fable reviewer gets **only** docs/playtest-2026-11-05.md, the owner's screenshots, the ledger's evidence column (renders and test names) and read access to the code. It does **not** get commit messages or my notes. For each of the 71 rows it answers MET or NOT-MET, with a sentence citing the evidence. It is told to treat a missing render or a test that doesn't assert the owner's words as NOT-MET.
- [ ] Every NOT-MET goes back through the item loop, then to a fresh acceptance pass on those rows only.
- [ ] Gates: full GUT; the full real-input batch twice (PS11); both exports built and the Linux build booted; owner logs untouched; PROGRESS.md and DECISIONS.md updated.
- [ ] The report to the owner is the ledger itself: per item, MET with its evidence or NOT-MET with the reason. No summary claims beyond it.

### Order

PS0 first: no fix starts before the ledger and the harness exist. Then PS1 (item 17 is the top priority), PS9 (69 is the biggest complaint), PS4, PS5, PS7, PS8, PS3, PS2, PS6, PS10 and PS11. PS13 last.
