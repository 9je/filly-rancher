# Progress

## Owner direction (2026-10-22)
Canon MLP stays: real names, looks and places ("lean into mlp fully", private build). The roster de-canon was reverted; the Company is the Cloudsdale Weather Corporation, the cloud palace is the Rainbow Factory, the town is Ponyville. The OC story cast lives alongside the canon ponies.

## Done
- Phases 1 to 4: AUDIT.md, RESEARCH.md, GDD.md, STORY.md, PLAN.md.
- **M0 foundation:**
  - Godot 4.7.2 (GUT 9.5.0);
  - Events autoload;
  - toon, outline, eye and rainbow shaders; ToonStyler;
  - generator v2 (38 donors, show-harmony palette, two-tone manes, foals, variants, names, SDF marks for 24 talents);
  - PonyPaint;
  - the shot tool (`tools/capture_shots.sh`, `scenes/test/shots.gd`: lineup, face, dread, cast, factory, rigprobe).
  - Suite at the M0 close: 1667/1667.
- **M1 so far:**
  - **Look pass:** every prop, building, terrain and pony is toon-shaded; Filmic tonemap at exposure 0.8; a show-tan path.
  - **Valley frame:** the rim hills, the Rainbow Factory on its cloud, and the Rainbow arc across the northern sky.
  - **Animations:** 17 new clips on all 38 donors (trot, jump, graze, sit, lie, sleep, startle, cower, hop, struggle, talk, nod, shake, sad, laugh, rear, look). Gait has a trot band; grazing and held ponies play their own clips.
  - **PonyFace:** blinks drawn by the eye shader, ear moods, a talking jaw, head look.
  - **Bloom:** in pens (meter, favorite glow, friends, Calm Lamp hook), the ceremony (rear, sparkles, fanfare, squash), and the Pony Book. The Depot refuses marked ponies.
  - **Delivery feedback:** a coat-colored sparkle flies into the Rainbow, which brightens.
  - **People layer:** dialogue compiler, runner, library; Act One and Act Two scripts (29 conversations); the seven-character OC cast; Npc; People; TalkBox; procedural Babble voice; Interaction.TALK.
  - **Score:** nine Kevin MacLeod tracks via the Music autoload (dread drone, low-pass, pitch sag); Music and Voice buses; new SFX (Bloom fanfare, Scoop pop, sparkle).
  - **Blender props (37):** depot crate, postbox, three trees, bush, straw hat, satchel, sash, goggles, patch, Scoop, valley rim, Rainbow Factory exterior, cloud lift, weather pylon, intake corral, Lantern Line gate, dye vat, Calm Lamp, lure post, and the 15-piece Factory interior kit.
  - **FactoryInterior** level builder (eight rooms).
  - **CREDITS.md.**

- **M1 close:**
  - Customizer rebuilt (race, two-tone mane, tail, marks; three tabs); the player on PonyPaint.
  - Onboarding tips and the Arrival; the player wears her Scoop; capture juice.
  - HUD restyle (Fredoka, cards, controls chip).
  - Act One and Act Two wired: postcards, dye names, the invitation, Color Day.
  - Story.vars (counters survive a save as themselves).
- **M2 (the reveal):**
  - `world/factory.tscn` + FactoryRun: the tour, the walkway (CollectorPatrol lantern cones, a buzzer and reset, never a fail), the window (FactoryWindow: silhouettes, coat-coloured light, the rainbow going up), Marigold's offer, the contract or the escape.
  - The processing hall sits beside the gallery (it used to overlap the holding room).
  - StoryV1: path, tallies, and the dread dial as a pure function; the ranch drives the dial from it.
  - Endings: a tested truth table for all five.
  - Tests: test_endings, test_story_v1, test_factory_run (both choices headless), test_factory_interior.

- **M3 (both paths, the endings):**
  - PathRules: contracts, ranks, the Jubilee order, the Supply Desk (Calm Lamp, Express Chute, Yield Lens, Lure Post); Heat and what it costs, four pylons, corral raids, the Dye Vat, the Lantern Line, allies, Placement.
  - Act3World: the Rescue path's places in the valley.
  - The Jubilee and Lights Out climaxes in the Factory, with Clover in holding.
  - The Epilogue: valley orbit, closing letter, credits; the post-game continues the save.
  - `tools/playthrough.sh` plays a new save to each of the five endings headless.
- **M4 (settings):** six buses, a picture-quality preset, fullscreen, vsync, and rebindable keys on a scrolling settings page.
- **M5 (ship):**
  - Linux and Windows exports (`build/`); the Linux build launches headless with a clean log (Music lets go of its tracks on exit).
  - README.md, CREDITS.md.
  - REVIEW.md: two reviews, 24 findings, every high and medium one fixed and tested. Placement now hands back the morning before.

- **M6, the sharpening (in progress):**
  - **The pacing test:**
    - The novelty log lives in GameState (the play clock plus first-time beats).
    - The human-paced bot plays a fresh save through real verbs, including the Factory reveal; `tools/pacing.sh` writes PACING.md.
    - The baseline failed: a 15-minute gap at 35 to 50 minutes, no Bloom in an hour, and constant pointless Depot and market trips.
  - **The fun redesign:**
    - Pony traits: favorite foods, nine quirks, race abilities.
    - Seven new verb-changing tools (10 of 14 upgrades are verb-changing), with Bramble's restocks announced as beats.
    - Ten timed happenings.
    - Faster Bloom, and a Big Pen that can Bloom.
    - A shorter invitation gate.
    - Talk yields to buildings, so Tumble, Bramble and Pip no longer eat the E for the mailbox, Market and Depot.
  - **The visual review** (`scenes/test/tour.gd`, 43 views on the real GPU):
    - The regions are dressed: a wood, a moonflower meadow, a lake shore, an orchard.
    - Stylised water.
    - The Factory's metal rooms are dressed (new Blender props: spectrum tanks, consoles, canister racks, crates).
    - Fixed: Marigold talking over the creator, empty HUD pills, the outline shader smearing triangles, a talk box over the epilogue, NPCs inside plot slots and inside the Market.
  - **Performance** (`scenes/test/perf.gd`, 60 ponies in view, real GPU):
    - From 47 ms average (about 21 fps) to about 12 to 14 ms, about 75 fps.
    - The changes: the render thread, pony detail tiers, pony and NPC LODs (eyes kept), instance-uniform outlines, staggered tiers, and babble synthesised once per syllable.
    - The GPU is busy only about 3 ms a frame; the remaining cost is main-thread physics and animation.
  - **The exit hang:**
    - Reproduced 2 times in about 31 suite runs, both under heavy machine load.
    - The cause is narrowed to a busy secondary thread (most likely the dummy audio driver's mix thread), joined at exit while still running.
    - A debug-symbol headless build of 4.7.2 is in progress to name the function.
  - **The trailer:**
    - TRAILER_PLAN.md is written; the staging, capture and edit scripts are written.
    - Capture is 2560x1440 GPU Movie Maker through a pinned root viewport (the owner asked for 2K).

## Known issues
- **Factory interior:** still monochrome grey-white; the ring light should read stronger in colour.
- **Apple trees:** the apples sit mostly inside the canopy.
- **Distance fog:** it washes the rim hills pale.
- **Building plinths:** still read as boxes under some houses.
- **Headless runs:** they skip the toon shader swap (a dummy renderer limitation).
- **Epilogue orbit:** not yet reviewed in a rendered capture.
- **Deferred past v1:** see PLAN.md's M4 and M5 status lines.

### 2026-10-23 (afternoon)
- **Exit hang root-caused and fixed (bd6b128):** see DECISIONS.md. A use-after-free of Babble's AudioStreamGenerator during the server's fade-out mix. The 10-run loaded proof loop is running.
- **Pacing bot fixes:**
  - The talk guard regression, reverted.
  - Depot trips count only the bag's Drifters, and rest after an empty trip.
  - Ponies are shipped only when they show no Bloom progress.
  - Stray menus are named and escaped.
- **Game fixes:**
  - Tumble's pointing marker is freed by id (176 errors a run).
  - The creator no longer counts as a visit to the Strip.
- **Visual:** the Palace and the mailbox are modelled. A real Spike model (PonySFM, BeardedDoomGuy) is downloaded; its conversion awaits the owner's approval.
- **Trailer pipeline:** 4K (TRAILER_4K.mp4 at 3840x2160), with captions scaled.

### 2026-10-24
- **TRAILER_4K.mp4 and TRAILER_1080p.mp4, cut 6:** 64.8 s, 60 fps, -14.0 LUFS. Re-shot after the owner's review (eyes, text, movement); see TRAILER_REVIEW.md iterations 5 and 6 and DECISIONS.md.
- **Pacing passes:** PACING.md, 72:26 of play, longest gap 6:01 (limit 8:00), first clue 5:34. The Rainboom, Derpy and Trixie happenings closed the old 11:59 hole at 50-62 min.
- **60 ponies at 60 FPS:** the rendered 60-pony check passes, 4 runs of 4 at p99 15.0-15.6 ms (budget 16.6), worst second 87-100 fps, average about 8.7 ms. The changes are listed in DECISIONS.md, "60 ponies at 60 FPS, measured honestly": Jolt; a herd that settles instead of running in place near the player; outline-free far ponies; one mesh per region fence; a corrected benchmark.
- **FIRST_10_MINUTES.mp4:** H.264 1920x1080 60 fps, 600 s, uncut. The bot plays a fresh save on the GPU under Movie Maker. Sampled every 15 s: creator, opening talks, the Scoop, pens, market, Depot, mail, with no stuck spans now that the bot has a stuck detector.
- **Final-code gates:** all 5 headless playthroughs reach their endings (PLAYTHROUGHS_OK 5). Ten consecutive full-suite runs each passed 1752 of 1752 and exited cleanly, with no hang. That closes the exit-hang proof.
- **Treetops solid to the camera again:** the re-run visual review on the final code found canopies filling the homestead views; they now sit on their own CANOPY layer, which only the camera probes. After the fix: suite 1752 of 1752 (clean exit), PLAYTHROUGHS_OK 5, and the 60-pony check 3 of 3 OK.
- **Beam before the Scoop explains itself:** owner report "i cant get the beam to work". The horn is locked until Marigold's welcome, and a press now says so and brings her over. The export is rebuilt.

### 2026-10-24 (evening): owner's real-hardware playtest round
- **Real-input harness:** game/test_input/ and tools/run_input_tests.sh, running invisibly on the GPU.
- **First pony fixed:** the first tip named no button, and closing a conversation with E opened the next one (an endless loop with Tumble). test_first_pony catches on the first try.
- **Beam targeting:** aim assist cone, a highlight before the press (gold outline, ring, chevron), and the press takes the lit pony. Covered by test_beam_targeting.
- **All nine notes fixed**, each with a test that failed before its fix and passes after (PLAYTEST_FIXES.md):
  - shadows: PCSS off, range 160 m;
  - scale: SCALE.md, test_scale;
  - loading screen: worst stall 0.35 s;
  - tabbed Settings menu;
  - hoofsteps on footfalls, per surface (AUDIO_AUDIT.md);
  - pony textures and eyes: contact sheets, test_pony_materials;
  - camera lens ball: never under the terrain.
- **The first catch can no longer be wrenched away** (found after the merges: test_first_pony was failing 2 runs in 4).
- **The real-input playthrough driver** reached all five endings from a new game, each run separately.
- **Gates on the final code:** the GUT suite, and all 10 real-input tests through tools/run_input_tests.sh.
- **Exports rebuilt** (Linux and Windows, 0 export errors). The Linux build ran on the GPU invisibly and exited cleanly, but printed engine errors that come only from the experimental render thread and were already there before this round (DECISIONS.md).
- **Two of the owner's save slots (0 and 9) were overwritten** by an agent's probe runs, and they could not be recovered (DECISIONS.md).

### 2026-10-25: playtest round 2 (PLAYTEST_FIXES.md, "Round 2")
- **Pens upgrade in place:** Paddock to Big Pen costs 150 and Big Pen to Grand Pen costs 330, and every resident stays. A built pen offers the upgrade on its prompt when the bag is empty or the pen is full. A full pen's refusal now says what to do.
- **Plots 3 and 4 start overgrown:** 100 and 250 bits to clear, through a painted signpost, the prompt and the card. Old saves keep the pens they already built there.
- **Catching ramps with experience:** bold ponies take up to 1.85 s to subdue, curious ones up to 1.45 s, and shy ones stay at 1.0 s. The first catch is unchanged.
- **Catch card:** a sliding card with her portrait, name, rarity stars and four trait icon chips replaces the "Caught ..." toast.
- **Not yet done:** pacing (tools/pacing.sh) and the five real-input playthroughs have not been re-run with the new economy. The playthrough driver was taught to clear plots and upgrade pens, but that teaching has not been exercised end to end.
- **My thirteen notes of round 2** (PLAYTEST_FIXES.md table):
  - the creator's mane colour;
  - sprint on Shift;
  - soft hoofsteps and penning sound;
  - chatter off by default;
  - the "!" bubble;
  - slipped and blinked ponies land;
  - townsfolk keep apart;
  - the empty white card;
  - the homestead re-laid round a plaza with signs, roads and an icon compass;
  - Spike 1.9x;
  - the Palace marquee over the door.
- **The window resize was not reproduced:** pinned by test_window_size.

### 2026-10-26 (overnight)
- **New game could hang forever on "Saddling up... 6%".** It happened in about one boot in six under the input gate: ResourceLoader's worker thread stopped inside world/ranch.tscn. The loading screen now loads leaves first on the main thread (game/ui/staged_loader.gd), 12 ms a frame, with no thread at all. That is 2.4 s in all, against 2.2 s before, and the worst single step is 0.6 s with the bar moving. Twenty boots in a row all reached the ranch, and test_loading still passes. test_staged_loader is new. The input watchdog now prints where a timed-out test was stuck.
- **Roads with a clean edge and some wear.** Half-width 1.5 m with a 0.35 m edge (was 1.1 m and 1.3 m), plus a lighter crown, cart ruts and pebbles in the shader. Spawn views are in build/playtest_evidence/round3/spawn_view_*.png.
- **test_race_parts:** every donor, in every race it can wear, shows only its race's parts. It passed at once (the "Unicorn with wings" card was most likely her tail).
- **Every tool script passes --log-file.**
- **The Spectra Palace walk-in interior** is being built on its own branch.
