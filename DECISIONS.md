# Decisions

One line of reasoning per call. Newest at the bottom.

- 2026-10-22 -- Engine: installed Godot is 4.5.2 (pinned in tools/bin, matching 4.5.2 export templates installed incl. Windows/Linux); latest stable is 4.7.2. Upgrade is scheduled as the first build milestone (fetch 4.7.2 + templates, re-import, full suite green) rather than done during setup, because a two-minor jump under a 1647-test suite is a migration that needs its own gate and rollback point.
- 2026-10-22 -- .claude/worktrees/ gitignored instead of committed: it holds a stale agent git checkout, not project content.
- 2026-10-22 -- No references/ folder exists (owner confirmed). The visual target is the existing pony models plus the G4 show look as written in RESEARCH.md section 5; screenshots are compared against pony renders, not invented references.
- 2026-10-22 -- Blender MCP tools are not connected in this session. Meshes are modelled, UV'd, textured and exported to .glb by headless Blender Python scripts (tools/bin/blender, tools/*.py), which is the same pipeline with the advantage of being reproducible from the repo.
- 2026-10-22 -- An offscreen xvfb render of the ranch was declined by the owner mid-audit; the audit's visual verdict therefore rests on the owner's 2026-09-04 playtest and code reading, and renders resume at milestone reviews.
- 2026-10-22 -- Wild ponies become blank-flanked "Drifters" and caring for one makes her Bloom (earn a generated cutie mark); the Works can only drain the unmarked. One rule makes ranching the rescue mechanic, makes the Depot's refusal of marked ponies the first clue, and gives the generator a reason to make marks.
- 2026-10-22 -- The capture tool becomes the Brightsky "Scoop", a company-issued device, instead of horn magic: every body type can play, and the tool itself is complicit (its gauge measures yield).
- 2026-10-22 -- Both reveal choices save Tumble (Factory: as a contract perk; Rescue: by scooping her out of the line). The Factory path must be chosen by someone sympathetic, not a strawman; per Spec Ops, nothing the player was forced to do pre-reveal is blamed on them.
- 2026-10-22 -- Endings are a pure function of path plus post-reveal tallies (delivered, rescued, allies, Clover, heat): five endings including two mixed ones and a fail-forward Placement ending that offers a pre-collection reload, so no ending is a softlock.
- 2026-10-22 -- Canon removed from play: the 43 canon PonyData records leave the game; the 38 SFM models stay as donor bodies for the generator (tintable via pattern role matching, race set by hiding horn/wings); the 5 tier-a Mane Six models stay on disk but leave the generated pool (most recognisable, untintable). Canon place names (Cloudsdale, Everfree, Las Pegasus) are replaced with originals.
- 2026-10-22 -- Company renamed Brightsky Weather Company (from Cloudsdale Weather Corporation): Cloudsdale is a canon place, and an original name lets the Company have its own voice.
- 2026-10-22 -- Compendium of named characters becomes the Pony Book (Bloomed ponies, talents, rare variants): collection stays a pillar without canon characters.
- 2026-10-22 -- Voices are per-character syllable babble in v1, not AI TTS: an original, cartoon sound beats a flat converted voice (the owner's earlier verdict on the RVC line), and a voice-line hook stays for later.
- 2026-10-22 -- Casino kept (owner's bright spot, fits the light-gambling direction); racing feeds Bloom. Fusion, flight, seasons cut as off-pillar.
- 2026-10-22 -- BBC Sound Effects rows (32) will be replaced with CC0/CC-BY sources: the RemArc licence does not permit free redistribution, which the brief requires of third-party assets.
- 2026-10-22 -- One toon shader family converts every imported PBR material at load (albedo kept); tonemap moves off ACES to Filmic/AgX: the owner's "clashing art" verdict is a shading problem more than a modelling one.
- 2026-10-22 -- An Events autoload is added for story/tone signals so new systems stop routing through the 7063-line ranch.gd.
- 2026-10-22 -- GUT stays on 9.5.0 under Godot 4.7.2: the full suite is green on it; 9.7.1 fails every test that sees an engine error (the headless dummy renderer logs "material is null" for each ShaderMaterial) and rejects the suite's assert_push_error form, a 1650-test migration that buys v1 nothing.
- 2026-10-22 -- Headless runs skip the toon shader swap (ToonStyler.shading_enabled is false under the headless display server): Godot 4.7.2's dummy renderer logs "material is null" for ShaderMaterials on skinned bodies built and freed within a frame, which GUT counts as failures. Bisected to that cause (zero errors with no ShaderMaterials); the Forward+ renderer is unaffected; material tests opt back in.
- 2026-10-22 -- SUPERSEDED by the owner: canon characters, names and places stay ("lean into mlp fully", private, not for redistribution). The de-canon roster migration was reverted before commit; the Company is the Cloudsdale Weather Corporation again, the cloud palace is the Rainbow Factory, the town is Ponyville, regions keep their canon names. The OC story cast (Tumble, Marigold, Fennel, Pip, Bramble, Static, Clover) stays: they are new characters in canon Equestria. The generator keeps refusing canon colour signatures, now so a generated Drifter is never mistaken for a roster character who exists as herself.
- 2026-10-22 -- BBC sound rows stay (not replaced): the licence concern was redistribution, which the owner has ruled out (private build), and the BBC beds and hoofsteps carry two playtests of ear-tuning. Only new rows are added (Kevin MacLeod score, CC-BY 4.0; Bloom fanfare, Scoop pop, sparkle).
- 2026-10-22 -- The Rainbow Factory is its own scene (world/factory.tscn, FactoryRun) rather than a far corner of the ranch: its own environment, lighting and dread, a save on the way up and a load on the way down. One scene, three scripted visits (the reveal, the Jubilee, Lights Out).
- 2026-10-22 -- The processing hall sits beside the gallery, off its east wall, not beyond it: the Factory's rooms run on down -Z, so a hall past the far wall overlapped the holding room and the window looked into holding. A layout test pins it.
- 2026-10-22 -- Story state that is not a yes or no (counters, path, heat, rank, queues) lives in Story.vars, saved as itself; flags stay bool. A counter in flags came back from a save as `true`.
- 2026-10-22 -- Act Three's rules are one static module (systems/path_rules.gd) the world reports to; every number is there and under test. The world only says what happened.
- 2026-10-22 -- A rescue counts once per pony (keyed by uid): a pony who Bloomed and was then sent down the Lantern Line was two. A Bloom after the reveal counts on either path, which is what makes Gray Gold reachable ("ponies secretly Bloomed").
- 2026-10-22 -- The Supply Desk's gear is ordinary Market stock with `requires_path = "factory"`: off the path it is not on the shelf, and the Shop refuses it if asked.
- 2026-10-22 -- The Dye Vat repaints the pony at the top of the saddlebag (a generated coat and mane) rather than opening the creator on her. The visual repaint flow is a post-v1 idea; the verb and its Heat are in.
- 2026-10-22 -- Endings play in the ranch, over the player's own valley (camera orbit, final grade, closing letter, credits), then the save continues: no separate ending scene to keep in sync with the world.
- 2026-10-22 -- The headless playthrough driver (scenes/test/playthrough.gd) plays through the game's own entry points (conversations, the bag, pens, Bloom, deliver_pony, dawn and collection-day handlers, Act3World verbs, the Factory scene with --factory-fast) and changes scenes itself; BootIntent.driven keeps the ranch from quitting a headless run and from resetting the save it should load.
- 2026-10-22 -- Drifters are named from their look's seed (PonyGenerator.make_name), the same name the Bloom gives them: postcards and the Pony Book no longer say "Pony".
- 2026-10-23 -- Every audio bus gets its own slider (the UI bus no longer rides Effects); the settings page scrolls a 12-row window. Full settings live in the pause menu; the title screen keeps its short list.
- 2026-10-23 -- Key rebinding is keyboard only (one key per action, a key moves rather than doubling); gamepad bindings are fixed. Controller play is covered by the project's joypad events.
- 2026-10-23 -- One save slot plus autosave (Save game / Load game in the pause menu). Multiple named slots are not v1.
- 2026-10-23 -- Placement keeps "the morning before" in its own save slot (5), written at the start of every Rescue path collection day; after the epilogue that morning comes back as the play save, with `endings_seen` merged in. It is restored without a yes/no prompt: being collected leaves nothing to continue, so the only real offer is to go back. With no such morning on disk, the ending is lifted and Heat drops to the padlock line so the save stays playable.
- 2026-10-23 -- A taken key swaps the other action onto the thief's old key (defaults included), and Backspace in a capture puts an action back on its project default. That replaces "a key moves rather than doubling", which left the other action without a key.
- 2026-10-23 -- The Express Chute pays 25 bits per pony on top of the delivery: "convenience" on the statement, and still cheaper than walking them over.
- 2026-10-23 -- The review's two "driver bypasses rules" and "rank gating" findings are not defects: the driver proves reachability, and the rules it skips are pinned by unit tests. Recorded in REVIEW.md.
- 2026-10-23 -- Deferred past v1, recorded in PLAN.md: an Ultra preset and per-effect graphics overrides, controller rebinding, accessibility options, save thumbnails, the 60-pony perf gate, and a Proton smoke run of the Windows build.
- 2026-10-23 -- **The pacing test plays like a person rather than shortcutting** (`scenes/test/human_bot.gd`, `tools/pacing.sh`).
  - It runs headless at a fixed 60 fps, so the play clock is simulated real time.
  - It walks a navmesh baked from the world's colliders, turns the camera toward where it is going, sneaks, aims and holds the Scoop, and presses E at the prompts.
  - It reads at about 22 characters a second and shops from a wishlist.
  - The same bot drives FIRST_10_MINUTES.mp4, so the video and the measurement are one thing.
- 2026-10-23 -- **The gap limits:** a gap in the first hour may not exceed 8 min (the top of the brief's "5 to 8"), a later gap may not exceed 15, and the first clue must come by 15:00. The end of the run counts as a gap, so a run that stops producing novelty fails.
- 2026-10-23 -- Barks (repeatable one-liners) are not novelty. Every non-bark conversation is a story beat; the Act Two wrongness conversations and letters marked `evidence` are clues. Pens the save starts with are not news; pens the player builds are.
- 2026-10-23 -- Three bugs found by the bot, each one a human would hit:
  - Fennel and Clover stood inside plot Slot1, so the first pen built there fenced them in.
  - Bramble stood inside the Market's footprint and was lifted onto it.
  - Pip and Tumble answered every E meant for the mailbox. Tumble follows you, and talk outranked buildings. A following companion with nothing new to say now steps aside for a building prompt.
- 2026-10-23 -- **Traits are derived from the look seed, not stored** (`systems/pony_traits.gd`), so old saves have them too.
  - Each Drifter gets a favorite food from five, weighted, and one of nine quirks: Glutton, Night Owl, Social Butterfly, Loner, Sparkler, Skittish, Escape Artist, Sleepyhead, Show-off.
  - Race does something: pegasi flee 1.35x faster, unicorns blink 4.5 m away when startled, earth ponies Bloom 1.2x faster.
  - Canon ponies have the quirk that is them: Pinkie is Social, Fluttershy Skittish, Rainbow Dash a Show-off, Twilight a Night Owl.
- 2026-10-23 -- **Verb-changing gear** (`world/ranch_tools.gd`):
  - Treat Pouch: Fennel's gift in the pen tutorial.
  - Gallop Shoes.
  - Steward's Monocle: a target card under the crosshair.
  - Scoop Launcher.
  - Pony Whistle.
  - Gem Chute.
  - Depot Cart: at dawn it collects full pens' unmarked ponies, so the player can automate the very thing the story indicts.
  - The Factory path's Lure Post and Yield Lens are now real: the Lure Post draws wild ponies in, and the Yield Lens adds a vividness grade to the target card.
  - New stock appears on Bramble's shelf as story flags rise (`ShopItem.requires_flag`), and each restock is announced.
  - Count: 10 of 14 upgrades are verb-changing (`ShopItem.verb`, pinned by test_shop).
- 2026-10-23 -- **Happenings** (`world/happenings.gd`): each fires once per save, on the play clock and the story.
  - A sun shower brings pegasi down (9 min).
  - Tumble spots an uncaught canon pony (13 min, then every 9).
  - The Palace's grand opening (17 min). The casino was always open before, so nobody ever noticed it arrive. It now opens on a flyer; gates and tests still find it open.
  - Race day (30 min).
  - Pip's lost foal (35 min).
- 2026-10-23 -- **The trailer is 2560x1440, not 4K** (the owner: a 2K deliverable is sufficient; their monitor is 2560x1440). Capture is GPU-rendered Movie Maker footage with the root viewport pinned to the capture size (the "viewport" stretch mode, set for the capture run only): the window manager clamps a 4K window to the work area and even exclusive fullscreen loses the panel strip, so sizing the window cannot give exact frames, while a pinned viewport does on any desktop. Xvfb was tried and is software rendering only (llvmpipe).
- 2026-10-23 -- **Performance: the render thread is on** (`rendering/driver/threads/thread_model=2`), vendor-neutral Vulkan on both the owner's AMD/Linux machine and a friend's NVIDIA/Windows one. On the 60-pony check it took the average frame from 16.6 to 11.7 ms; a separate physics thread added nothing and is not used.
- 2026-10-23 -- **Pony detail tiers** (FULL under 12 m, MID to 40 m, FAR past that or off screen past 12 m), with 2 m of hysteresis and a random phase within each stride:
  - Thinking, moving and animating run every 3rd or 6th tick, carrying the skipped time.
  - Springs are off past FULL; shadows and outlines are off past FULL; detection is off at FAR.
  - Outlines switch through a per-instance shader parameter, not a material swap (a swap rebuilt the render instance, and that hitched).
  - Runtime mesh LODs (`actors/pony/pony_lod.gd`) keep every eye surface at full detail, so the iris-cap bug of August cannot return.
  - A collision-free glide for FAR ponies was tried and dropped: it walked ponies through trunks.
- 2026-10-23 -- The babble voice is synthesised once per syllable shape and cached, not per sample per frame in GDScript. The per-sample loop was a 10 ms hitch on every audio buffer refill whenever anypony talked.
- 2026-10-23 -- **The trailer is for the owner's friends, not Steam** (the owner: "make it interesting, maybe add some humor elements and load it with mlp references"). It keeps the craft rules (gameplay first, beat cuts, a 6-second loop, the twist teased not spoiled) and loosens the callout limit: six joke caption cards instead of three, and staged canon gags (the Crusaders as Escape Artists, a 20%-cooler Rainbow Dash, Pinkie, Derpy, Fluttershy), all listed in TRAILER_PLAN.md.


## 2026-10-23: the trailer ships at 4K after all

The owner said a 2K deliverable was enough, then set a /goal that names TRAILER_4K.mp4 at 3840x2160 60 fps. The later, more specific instruction wins. The capture pins the root viewport at 3840x2160 (the window manager clamps any window that large, so the viewport is pinned, not the window), and the edit scales its caption and title cards from their 1440p layout by H/1440. 4K also downsamples cleanly to the owner's 1440p monitor.

## 2026-10-23: the Palace and the mailbox are modelled, not boxes

The visual review found the Spectra Palace was a purple box with a flat gold lid, and the mailbox was three grey slabs. Both are now Blender-built (tools/blender_props/build_props.py: spectra_palace, mailbox):
- **The Palace:** gold-domed towers, a pink dome, a portico and a bulb-lit marquee, worn over its Building shell, with Building taking res:// model paths.
- **The mailbox:** the slabs stay as the colliders and as the shape test_mailbox measures; their meshes just stop drawing. The flag stays the game's own node so it can still stand up.

## 2026-10-23: the exit hang, root-caused and fixed (bd6b128)

**Cause.** Godot 4.7.2's AudioStreamGeneratorPlayback holds its AudioStreamGenerator by a raw pointer and reads the generator's rate on every mix. A stopped playback is not dropped at once: the server marks it FADE_OUT_TO_DELETION and mixes it one more time. Freeing a Babble (the cartoon pony voice) freed its generator, held only by `player.stream`, before that last mix. The mix then read the rate from freed memory. A garbage rate (roughly 1e10 to 1e19, or NaN) gives the resampler (`AudioStreamPlaybackResampled::mix`) an increment so large that its catch-up loop is effectively endless, all while it holds the audio driver lock. Anything needing that lock then blocks forever. That includes quit()'s join on the audio thread, which is the "exit hang". At shutdown it is worse, because GDScript is torn down before the AudioServer (Main::cleanup).

**Evidence.**
- **The catch:** a headless debug-symbol 4.7.2 build under gdb, one hang in 10 loaded suite runs. The audio thread was in `AudioStreamGeneratorPlayback::_mix_internal` under `AudioStreamPlaybackResampled::mix`, holding the driver lock; the main thread was blocked on that lock.
- **The mechanism:** a live generator at a 1e15 rate runs its frames, then never exits.
- **Ruled out:** 200 sound-test runs under gdb and 36,000 Babble create/free cycles did not reproduce it, which fits a use-after-free that bites only when the freed memory gets reused.

**Fix.** A leaving Babble buries its generator with an extra reference. Graves older than 1 s are released by later burials, and anything still buried at shutdown stays referenced. test_babble.gd pins this. An upstream fix (hold a Ref, or snapshot the rate) would belong in the engine. This is the game-side guard.

**Re-proven on the final code (2026-10-24, after 7f69812).** Ten full-suite runs in a row, each with a 2400 s hang timeout: all exited cleanly (rc 0), and every run passed 1752 of 1752 tests.

## 2026-10-23 (evening): the owner's "eyes buggy, text random, movement weird", deep dive

**Eyes, cause 1 (the big one): a stale import cache.**
- **The symptom:** in the working copy the owner plays from, Fluttershy, Twilight and Rainbow Dash were served from Godot's cached imports of an older conversion, with their eyeballs hanging off the backs of their heads. Seen from the front they had hollow eye sockets.
- **Why it hid:** every clean checkout imported the current models correctly, which is why no bisect commit reproduced it.
- **The fix:** 20 stale cache entries dropped and re-imported. `tools/fix_stale_imports.py` now runs from play.sh before every launch.

**Eyes, cause 2: PonySFM irises drawn too big.**
- **The symptom:** in the 37 PonySFM-converted ponies, each eyeball's UVs span only the middle of the iris texture, because Source projected the iris small and our conversion pasted it across the whole ball. Every eye was a black pupil with a thin ring.
- **The fix:** pony_eye.gdshader takes `iris_scale` (1.45), which shrinks the iris about its center and puts white sclera outside it. Canon ponies keep their own colors (`recolor` off), and Drifters get the same scale. `scenes/test/roster_eyes.gd` renders every canon face for checking.

**Text:**
- **The trailer:** its gameplay shots kept the HUD's bag panel and prompts, which read as stray boxes of text. Now no shot shows any HUD.
- **The game:** the herd-churn toast ("3 ponies wandered off, 2 ponies arrived") is gone, the "CWC balance" and "Day, clear" lines are gone from the saddlebag panel, and the typed [ ] / [x] boxes are now a bullet and "Done!".

**Movement:**
- **Treats:** a tossed treat never drew a pony. Entering WANDER picked its own random target and overwrote the treat, so the Treat Pouch sent ponies strolling anywhere. Fixed.
- **Trailer staging:** a pony's staged facing was undone by her own `_visual_yaw`, so staged ponies showed their backs. Dash was meant to bolt but stood frozen. Strangers from the spawn meadow wandered through featured shots. All three fixed: facing sticks, Dash's bolt is forced, and the stage is cleared around each featured pony.

## 2026-10-24: 60 ponies at 60 FPS, measured honestly

The 60-pony check (`scenes/test/perf.gd`) was failing at p99 22-27 ms. Three of its findings were the check measuring the wrong thing; the rest were real costs in the game.

**The check, corrected:**
- **Unlayered ponies.** Its own ponies came straight from pony.tscn on collision layer 1. Their 14 m detection spheres paired with the ground, the props and each other (5,019 broadphase pairs), and their bodies ignored the props. They are now layered the way spawner.gd layers a Drifter.
- **Strays, and a growing herd.** A rejected spawn spot left its pony standing at the origin. The ranch's restock kept topping the wild up mid-run. The ring now holds exactly 60, on open ground, with restocking held (`Spawner.restock`).
- **Synchronous render queries every frame.** These waited for the render thread and serialized it with the main thread. They are now sampled once a second.

**The game, faster** (p99 about 25 to 15.3-16.5 ms; 8 of 8 runs PERF_OK across two sessions; worst second 86-104 fps; average about 8.7 ms). The full suite ran 1750 of 1752 under Jolt. Both failures were the first wary rule, which settled a bolting pony in the tick she bolted; it is fixed (she runs at least 1 s first), and test_pony_leash's cornered pony may now be settled wary, which its assertion accepts:
- **Jolt physics** (project.godot). A tick fell from about 13 to about 7 ms with the herd layered properly. A slide against the ground fell from 141 to 38 us.
- **The herd settles.** Two changes:
  - A shy pony who has run at least 1 s and is past her notice radius, or pinned by her leash or a wall, now stops and watches the player for 5 s. She bolts again only if the player closes inside 5 m. Before, she fled until the player left her 14 m sphere, which her leash never allowed, so half a herd ran in place for as long as the player stood near it (27 of 59 in the check).
  - Grazing is 4-9 s (was 1.5-3.5), idles are 1-2.5 s, and the wander chance is 0.5. The herd is on the move about a quarter of the time, not half.
- **Far ponies draw no outline at all.** The pass was collapsed but still issued as a draw call. Each toon material is now built with an outline-free twin (`ToonStyler.BARE_META`), and the MID/FAR tiers wear the twin, so a far pony is 11-18 draws, not 22-38. Teeth and tongue are not drawn out there. NPCs get the same past 14 m, plus no shadows.
- **Fewer shadow casters:**
  - Each region fence's 113 post and rail meshes are one mesh. The four fences had been 452 shadow casters; their colliders are unchanged.
  - The orchard's whole-scene props are batched into MultiMeshes like the rest of the dressing.
  - Nothing under 30 cm casts a shadow.
- **Resting ponies do less:**
  - A mid-distance pony who is standing still ticks every 6th physics tick, not every 3rd.
  - An off-screen far pony ticks every 24th.
- **Smaller fixes:**
  - A wanderer pressed into a wall gives up after 0.75 s. One pony grinding the coop cost as much as twenty grazing ones.
  - Foliage collision keeps only the faces within 3 m of the ground. Tree canopies were 60-80k collision faces each. This also stopped about 30 wild ponies failing to spawn under canopies.

**Kept, tried and rejected:**
- **Depth prepass off:** frame 8.3 ms, but SSAO reads the prepass's normals. The frame went visibly darker and a pony rendered black.
- **Physics on its own thread:** about 0.3 ms, but it makes ray casts from `_process` unsafe, and the game does those.
- **Mid and far ponies stepped from `_process`:** worse. move_and_slide outside the physics step costs more under Jolt.
- **Also no help:** a heightmap ground collider, fewer max slides, two shadow cascades, and custom AABBs.

## 2026-10-24: treetops are solid to the camera again (CollisionLayers.CANOPY)

**Found in the visual review on the final code.** I re-rendered all 45 tour views after 7f69812. In every homestead and tone_dread view, a tree canopy filled the right half of the frame. Yesterday's shots of the same views were clear.

**Cause.** The 60-pony work kept foliage collision only below 3 m, so the herd stopped querying tens of thousands of leaf faces. That also took the canopies away from everything that looks for solid world:
- the tour's clear-line probe, which then left the lens inside the leaves;
- the player camera's SpringArm3D, which could now sink into a treetop in play.

**Fix.** The faces above 3 m are kept as their own trimesh on a new layer, CANOPY (bit 7). No character's mask contains it, so ponies still skip the leaves. The camera rig's `probe_mask` and the tour probe are WORLD | CANOPY, and test_ranch_world pins the new mask.

**Measured after the fix:**
- The homestead and tone views match yesterday's reviewed framing.
- The 60-pony check passed 3 runs of 3: p99 15.9, 16.2 and 16.5 ms, with the owner's browser and Steam open.

**Rest of the review: nothing to fix.**
- The two factory views that looked crowded are framed exactly as on 10-23, minus yesterday's stray talk bubble.
- Every other view matches its reviewed version or improved on it: the endings and their flyovers, the regions, pens, herd, town, Spike, the Palace and the Strip.

**Known, not visible.** The creator's restyle logs 4 "material is null" render errors. They persist with every 7f69812 rendering file reverted, so they predate it, and the creator renders correctly.


## 2026-10-24: "i cant get the beam to work" (owner, playing the export)

**Not broken, but silent.** A new ranch has no Scoop until Marigold's welcome hands it over (STORY.md beat 1.1), and until then the horn is recalled. A right-click before that did nothing and said nothing. A probe in the real ranch with the real input (scenes/test/beam_probe.gd) confirms:
- with the Scoop, the beam grabs and secures a pony under Jolt;
- with the welcome letter closed, Marigold walks up and opens the welcome by herself at about 5 s.

**Fix.**
- A beam press before the Scoop now toasts "No Scoop yet. Marigold has it for you: she's on her way over."
- It also sends her back to the player.
- She now follows a steward who walks more than 6 m away before the welcome is done; before this she stood wherever she had been left.

## 2026-10-24: the owner's real-hardware playtest round (PLAYTEST_FIXES.md)

The owner's rules for this round:
- root cause and a failing test before every fix;
- tests through real input only;
- no trailer work, and the current trailer deleted.

Decisions:
- **Trailer deleted.** TRAILER_4K.mp4, TRAILER_1080p.mp4, build/trailer (15 GB of takes), TRAILER_PLAN.md and TRAILER_REVIEW.md are gone; git history keeps the docs. The capture pipeline (tools/trailer, scenes/test/trailer.gd) stays as code. It is not a trailer.
- **Real-input tests are standalone SceneTree scripts** (game/test_input/), not GUT cases.
  - They must boot the real main scene in a real window, and GUT's runner would sit in the way of a scene change.
  - Each prints INPUT_TEST_OK or INPUT_TEST_FAILED, and tools/run_input_tests.sh runs them.
- **Tests may look but not touch.** A test reads the game the way eyes read a screen (positions, the HUD tip, menu rows). It acts only through RealInput, which builds events from the InputMap, so a rebound key is the key pressed.
- **Invisible display, real GPU.**
  - The owner was using the machine and the first test windows took the mouse, so every windowed run goes into xvfb.
  - Xvfb has no DRI3, so RADV cannot present to it. Mesa's software WSI (MESA_VK_WSI_DEBUG=sw) lets the GPU render and copies each frame in.
  - llvmpipe was tried first and was far too slow.
  - Runs use --fixed-fps 60, and the watchdog counts game seconds.
- **Parallel work.** Notes 5 to 11 and the playthrough rewrite went to agents, each in its own worktree, all niced and invisible. Each writes docs/playtest_fixes/<area>.md, which is merged into PLAYTEST_FIXES.md here.
- **Back to one agent at a time.** Eight agents in parallel used up the owner's usage limit, and five of them died mid-task. Each stopped agent was resumed alone, in order: settings, audio, scale, loading, camera, ponies, shadows, then the playthrough driver.
- **Beam targeting test: aim on the clear side.**
  - After the pens moved 2.5 m south (SCALE.md), the point 0.9 m beside the test's pony was nearer the crosshair to a pony behind her: 4.4 degrees against 9.4.
  - The beam took that pony, which is the rule we want: the pony nearest the crosshair wins.
  - The game was not changed. The test now aims on whichever side of her has no other pony, and logs every candidate's angle.
- **A real-input test that ends with no verdict fails.**
  - A script error ends `_play()` early and returns to `InputTest._main()` as if the test had finished, and `_main()` used to call that a pass.
  - Every test now reaches its own `ok()` or `fail()`.
- **Shadows: PCSS off, range out to 160 m.** The numbers and reasons are in docs/playtest_fixes/shadows.md.
  - The perf check measures 85 m and 160 m the same in the invisible display: p99 25.4 ms against 24.4 ms.
  - The commit before this round, 877d56d, measures 23.8 ms under the same conditions, so the round added no cost.
  - That p99 is over the 16.6 ms budget only because of how the invisible display presents frames (its CPU-side process time is about 18 ms). The 15 ms pass recorded in PROGRESS.md was measured in a real window.
  - It was not re-measured in a real window, because the owner asked that nothing open on their screen.
- **Two of the owner's save slots were overwritten.**
  - At 19:34 on 2026-10-24 the shadow agent made two probe launches without `FILLY_TEST_SAVE_DIR`. They wrote fresh-game `slot_0.json` and `slot_9.json`, with their `.bak` files, into the live saves folder. Slot 9 was rewritten again at 21:24, by another direct launch.
  - `tools/run_input_tests.sh`, `run_tests.sh`, `playthrough.sh` and `pony_turntable.sh` all isolate saves. Only the direct one-off launches did not.
  - The newest play.sh stash is from 2026-08-28, so whatever the slots held is gone.
  - Every agent brief now requires `FILLY_TEST_SAVE_DIR` on every launch.
- **First catch: no wrench** (`MagicBeam.first_catch_grace`). After the merges, `test_first_pony` failed 2 runs in 4.
  - A new player's nearest pony can be bold. A HARD hold wrenches at 0.5, about 0.85 s in, so the first catch the tips teach was a coin toss.
  - While story var `catches` is 0 on an interactive ranch, the beam applies the falloff rule it already has, as if this were her third grab.
  - The GUT sweep reads 26 of 64 seeds wrenching without the grace, and 0 with it.
- **The final export launch printed engine errors, and they were left in place.**
  - The Linux export ran on the RX 9070 XT in the invisible display and exited cleanly. It printed:
    - 1 to 3 `Condition "p_image.is_null() || p_image->is_empty()"` errors from `_texture_2d_update`;
    - one `finalize can only be called from the render thread` error at quit.
  - Both appear only with the experimental render thread (`thread_model=2`, on since 2026-10-23 for the 60-pony target). With `--render-thread safe` there are none.
  - The exit error appears even with no scene loaded, so it is the engine's own shutdown.
  - The empty-image errors appear at the title, vary from run to run, and print the same on the commit before this round (877d56d). The boot splash was ruled out.
  - Safe mode costs about 4 ms a frame on the 60-pony check (average 21.0 ms against 17.0 ms in the invisible display), which would give up the 60 fps target. So the render thread stays, and these errors are recorded as a known issue rather than hidden.
  - If the owner sees instability, set `rendering/driver/threads/thread_model` to 1 (Safe). One boot crash in this round, a signal 11 in the camera agent's run, probably came from the same mode.

## 2026-10-25: playtest round 2, plots, upgrades, catching and the catch card (PLAYTEST_FIXES.md)

The owner's save after 11.6 minutes: 17 ponies, 157 bits, a pen on all four plots (three free Paddocks and one Big Pen), then "That pen is full." with nothing to do about it.

- **Upgrade in place, for the price difference.**
  - Paddock to Big Pen costs 150 bits and Big Pen to Grand Pen costs 330 (`PlotData.upgrade_price()`, the new list price less the old one).
  - The difference was chosen over the full list price so that building small first never costs more than building big at once. Paddock to Big Pen is still the 150 the owner expected to pay.
  - The chain is data: `PlotData.upgrades_to` in each .tres.
  - The pen is not rebuilt. Its capacity changes through the same `configure()` hook a build uses, so no resident leaves the pen at any point.
- **Where the upgrade lives.**
  - At a built pen, E means "move her in" when there is a pony in the bag and room in the pen.
  - Otherwise it means the upgrade: an empty bag (she is looking at the pen itself) or a full pen (she needs a bigger one).
  - The prompt names the size and the price, and adds "not enough bits" before E is pressed. E opens the build menu on a single UPGRADE card, so a stray E press never spends bits. The card shows "Not enough bits: you need N more." in red.
  - A full Grand Pen says "this pen is full, build another pen". The refusal itself now says "That pen is full. Upgrade it, or build another pen."
- **Two plots open, two overgrown.**
  - slot_1 and slot_2 are open, which allows two free Paddocks, six ponies.
  - slot_3 costs 100 bits to clear and slot_4 costs 250 (`ranch.gd PLOT_CLEAR_COSTS`).
  - The reasoning comes from the save: about 300 bits were earned in the first 11.6 minutes (157 left after a 150-bit pen), so roughly 25 bits a minute.
    - 100 bits sits below the first upgrade (150), so the first real choice, around minutes 7 to 9, is more ground or a bigger pen.
    - 250 sits above both, which makes the fourth plot the goal for minutes 15 to 20.
    - With 6 penned plus a 12-pony bag, the pen limit now bites before minute 10 instead of never.
  - Overgrown plots show brambles and a signpost painted "CLEAR ME / N bits" on both faces. The prompt is "E: clear this plot (N bits)", and E opens a CLEAR card.
- **Old saves.** Cleared plots are story flags (`plot_cleared_slot_N`), so the save format does not change. A save that already has a pen on slot_3 or slot_4 restores the pen first. `_apply_overgrowth()` then marks that plot cleared, so the pen and its ground both stay.
- **Overgrowth applies headless too.** The rule is a game rule, and the scoop gate taught that a rule which only runs when someone is watching is a rule no test checks. The real-input playthrough driver now clears plots and upgrades pens through the prompts. The smoke-endings shortcut clears the brambles directly, the way it already builds pens directly.
- **Catching, longer rather than tighter.**
  - The subdue clock grows with story var `catches`, for the bolder grades only:
    - EASY (shy) stays at 1.0 s;
    - MEDIUM rises to 1.45 s;
    - HARD rises to 1.85 s, and 2.0 s at the top of the jitter.
  - The ramp is linear from 3 catches to 15.
  - The capture windows (the owner's own numbers from the third playtest) are untouched. A bold pony becomes a longer hold with the same release to land, which also gives her wrench more time, since the wrench fires at a fraction of the subdue clock.
  - The first catch is unchanged (catches 0, plus `first_catch_grace`).
  - More skittish ponies were considered and not done: SHY already flees from 14 m, and making the herd flee more would make finding a pony harder, not catching one.
- **The catch card.**
  - A catch slides a card into the top right corner instead of a toast:
    - her portrait, rendered from a copy of her own body in a small SubViewport;
    - her name;
    - one to four rarity stars and the tier word;
    - four trait chips, each a drawn icon and a word: race, quirk, favourite food, and hold difficulty.
  - It holds for 4.6 s. A second catch replaces it rather than queueing behind it.
  - The icons are drawn from simple shapes in `ui/catch_icon.gd`, with no new assets.
  - The top right corner was chosen because nothing else on the HUD uses it. It stays clear of the crosshair and the saddlebag, and `test_catch_card` measures both.

## 2026-10-25: owner playtest round 2 (my half; the progression half is its own entry)
- **Mane colour.** The creator built the turntable body from the old four-unicorn list (StockPalette.MANE_STYLES) while PonyPaint used the race's donor list (PlayerLook.styles_for), so past the fourth style, and for every earth pony and pegasus, the mane's surface names missed and it kept the donor's texture. The turntable now builds from the donor the look names. In game the player was already right (player.gd used the donor).
- **"Window resized on New Game" was not reproduced.** In the invisible display at the game's own 1600x900 window, test_window_size watches the OS window's size and mode every frame from the title through the creator to the ranch: unchanged, and the X11 size hints never change (min 64x64). Nothing in the game resizes the window except the Settings menu's Display tab. The likely cause is the desktop (GNOME on X11, four monitors). The creator was also checked at 1366x768, 1280x1024, 1600x900 and 2560x1380: nothing runs off the window. Kept as a pinned test; no speculative change.
- **Sprint on Shift, sneak on C.** The default gait was already the run (5.2 m/s), and Shift was the hold-to-sneak key, so a player holding Shift to run went slower. Shift now sprints at 1.5x the run (gallop clip played past its usual ceiling so the hooves keep up), C sneaks, the controller's left-stick click sprints. test_sprint: W 4.7 m/s, Shift 6.7, C 0.9.
- **Hoofsteps synthesised.** The Kenney takes were a person's shoes on gravel at -3 to -9 dB on nearly every footfall. tools/make_hoofsteps.py now makes soft taps per surface (a muffled thump on grass and dirt, a small clop on wood, a tock on stone, a faint ring on metal), played 11 to 13 dB quieter, and at a run only the front hooves sound. All 20 pass tools/audio_audit.py. A listening preview is in build/playtest_evidence/round2/sound_preview.wav; I could not listen myself, so this is the first thing to judge by ear.
- **Penning sound.** A door creak at +3 dB played on every penning; now a latch and a two-note marimba rise (tools/make_pen_sounds.py) at -8 dB.
- **Pony chatter off by default.** The Animal Crossing babble is now Settings > Audio > Pony chatter, off. Mouths still move with the words.
- **Floating ponies, one root cause twice.** A pony's resting shortcut (60 FPS work, 2026-10-24) skips move_and_slide when she is still and is_on_floor(). Anything that moves her without move_and_slide (the beam's hold, a unicorn's blink) left is_on_floor() reading the old ground, so she hung in the air for good. Both now clear the shortcut and start her falling. test_slip_flight (5 slips, all land within 0.43 s; failed before) and the ranch's own boot check (a blinked unicorn at 0.3 m, failed 4 of 4 before).
- **Townsfolk keep apart.** They never collided with one another (by design, so a crowd cannot jam), so two sent to one place stood inside each other. A soft separation push, and a standing one's spot moves with the push. test_npc_separation.
- **The "!" bubble.** has_news() said "the '!' over her head" but nothing drew one. Now a gold speech bubble (an icon, drawn in code) bobs over every townspony with news, seen through walls; the Scoop toast says to look for it. test_news_marker.
- **Empty white box.** HUD.set_tasks([]) returned before hiding the card, so a finished Getting started list left its empty card up for the rest of the game.
- **The homestead re-laid round a plaza.** Every building had been turned 20 to 45 degrees and packed into a knot about 20 m across; the Market was a plain house with no sign. Now: the Farmhouse closes the plaza's north side, the Market faces it from the east, the Depot from the west, the request board and the barn to the north-west, the mailbox and Spike by the spawn. Three painted roads (PATH_BREAK lets one list hold several): main street, cross street, spur to the pens. Shop signs on posts (icon plus name), a fingerpost at the crossroads, a Pens sign at the yard, and an icon compass strip on the HUD. Empty plots stay visible at 60% to 60 m with a gold pennant (they used to vanish past 8 m). test_find_market: the compass leads a bot to the Market in 4 s and to a plot in under 4 s.
- **Spike 1.9x** (0.76 m to 1.31 m, 0.6 PH: up to a pony's neck).
- **The Palace marquee** hung across the top of the entrance steps, where the third-person camera passed through it. It is a shorter board on the worn model's frieze now, its lower edge 4.6 m up. The Palace still has no walk-in interior: E at the door opens the casino lobby, as before. A real interior is a larger piece of work, not done this round.
- **My own process slip:** a handful of direct Godot test launches early in this round ran without FILLY_TEST_SAVE_DIR. No save was written (the creator tests do not save, and the slot files predate those runs), but they pushed the owner's playtest log out of Godot's five-log rotation. The owner's saves are backed up to scratchpad/save-backups/2026-10-25_playtest2/, and every launch since used isolated saves and its own --log-file.

## 2026-10-25 -- round 2 gates: Barn moved north, news bubble fades up close

- **Barn to (-17, 0, -19), from -15.** The camera-terrain sweep stalled for 25 minutes against
  the Depot's north end: the Barn's door apron ended 4 m from the Depot's side, so "5 m in
  front of the Barn" was the Depot's corner. The owner's note was that the start buildings sit
  too close together; a test pony that cannot get round them says the same. Now about 8 m. The
  sweep's route goes round the Depot's north end (-8, -9.5) to and from the Barn.
- **The "!" bubble fades out between 6 m and 3 m from the lens**, and its texture has mipmaps.
  The round 2 catch-card picture showed a townspony beside the camera wearing a bubble a
  quarter of the screen tall, in 96 px blocks. Close up she needs no marker to be found.
- **Brambles in SCALE.md as prop_medium** (1.14 PH, a thicket about pony height); `bush` tops
  out at 1.0.

## 2026-10-26 -- New game could hang for good; the loading screen loads without threads

- **The hang.** About one New game in six under the input gate sat on "Saddling up... 6%"
  forever. The watchdog's new state dump (input_test.gd `_where()`) caught it: title scene,
  loading screen in LOADING, `load_threaded_get_status` IN_PROGRESS for 600 game seconds,
  every Godot thread parked on a futex. ResourceLoader's worker stopped inside world/ranch.tscn
  and never came back. I could not attach a debugger (ptrace is restricted to children here,
  and the official binary has no symbols), so the exact engine lock is not known.
- **Correction of my own 2026-10-25 note.** I put the earlier "New game never reached the
  ranch" failures down to the test counting game seconds while the loading screen's frames ran
  free. The wall-clock wait was still right, but those failures were most likely this same
  hang: the "Could not preload" lines are what a quit mid-load prints.
- **The fix: game/ui/staged_loader.gd.** It loads the scene on the main thread, leaves first:
  every dependency the files name, plus every script any of them preload()s, each only after
  what it needs is cached. The loading screen steps it 12 ms a frame, so the bar moves between
  every load. That is 2.4 s in all (2.2 s threaded), and the worst single load is ranch.gd's
  compile, about 0.6 s, inside test_loading's rule that a stall is allowed while the bar moves.
  Instancing moved off WorkerThreadPool too (6 ms on the main thread). No thread is asked for
  anything, so nothing can stop and never return. test_staged_loader (3 tests, failed before:
  no such file); 20 New-game boots in a row (results in PROGRESS.md).
- **Race and parts.** One catch card read "Unicorn" over what looked like a wing.
  test_race_parts paints every donor in every race it can wear: no wing on a non-pegasus, no
  horn on a non-unicorn, every pegasus and unicorn keeps hers. It passed at once, so the
  painting is right. The shape in catch_card_settled.png is most likely her tail behind her.
  The test stays as a guard.
- **Every tool script passes --log-file now** (pacing, the playthroughs, shots, turntable,
  sheets, the release export, the atomic-save proof, the theme build), so no tool can push the
  owner's play log out of Godot's five-log rotation. The run_tests.sh parse sweep was the one
  that did, on 2026-10-25 at 21:33: one launch per script, each without --log-file.
- **Dawn re-lit.** Every new game opens at dawn, so dawn is the owner's first look at the
  valley, and in round 2 it read as an overcast lavender haze over olive grass. Zenith
  (0.62, 0.55, 0.70) to (0.50, 0.62, 0.88), sun (1.0, 0.78, 0.60) to (1.0, 0.84, 0.68),
  sun energy 0.62 to 0.85, fill 0.24 to 0.28. Dusk is unchanged and dawn stays under day. I
  considered starting a new save in DAY instead. I chose not to: that would shorten the first
  day and move every night-keyed beat, while a good dawn helps every dawn, not just the
  first. The before and after spawn views are in build/playtest_evidence/round3/
  (spawn_view_* and spawn_view_dawn_relit_*).
- **The shipment toast says where the bits went.** "4th shipment received, 300 bits
  credited." showed up while the purse on screen did not move, because the credit comes off
  the sponsorship balance. Now it reads "300 bits off your balance, 24,100 to go." (or "It is
  paid off."). Ranch.delivery_toast(), test_delivery_toast.
- **Shop signs fade for the camera.** The bot review found the camera behind the Depot's
  door sign at every visit. A PlaceSign is solid past 3 m from the lens and 92% see-through
  inside 1.2 m, measured to the board's nearest point. test_place_sign_fade.
- **Bot screenshots:** playthrough_input.gd takes `--shots=<dir>`, a frame every 15 game
  seconds, so a run can be reviewed as a player sees it with nothing opened on the desktop.
  The 12-minute review of 2026-10-26 found the Market, Depot and Build menus still the old
  dark text lists (next), the receipt toast, and the door signs.
- **The Market and the Depot are tiles now, in the casino lobby's look** (the owner's one
  kind word in September was for the casino's screens). At 1280x720 the Market's BUY list
  ran off both ends of the screen, and its SELL/BUY tabs could not be clicked. Now every row
  is a plum tile with a gold edge (game/ui/tile_style.gd) carrying a picture drawn in the
  catch card's style (game/ui/shop_icon.gd: the foods, all twelve pieces of gear, the four
  permits, the four gems, a coin pile). BUY is a grid of three, SELL a column, both in a
  scroll area that stays on screen, and the tabs are buttons. The Depot shows each pony as
  her race's icon on a disc of her coat, two columns, scrolled. Row order, indices, signals
  and drawn_lines() are unchanged, so the bot and the old tests drive them as before.
  test_market_tiles (5 tests). The Build menu got the same tiles, with a fence that grows
  with the pen (two, three, four bays), an upgrade arrow and clearing shears. Renders:
  build/playtest_evidence/round3/menu_*.png.
- **The Getting started card is a checklist**: drawn tick boxes that fill green when a job is
  done, and each reward as a coin and a number, in place of a bulleted paragraph with
  "(20 bits)" after each line. task_lines() is unchanged.
- **The Strip's lamp posts have lamps.** By day the ring read as ten bare dark sticks
  around the Strip, the track and the north road, because the only thing on top was an
  OmniLight3D. Now each post has a stepped foot, a gold collar, a warm glowing globe and a
  gold cap. test_strip: every post wears a lamp you can see by day.

## 2026-10-26 -- the Spectra Palace you walk into

Owner playtest note (2026-10-25): "spectra palace not real yet? weird sign you gotta walk
through to get in".

- **A hall in the ranch scene, not a scene change.** game/world/palace_interior.gd builds a
  sealed 24 m by 32 m hall, 7.5 m to the ceiling, sixty metres under the Palace's own
  footprint. Going in fades to black and moves the player; nothing is unloaded, saved or
  rebuilt, so the bag, the pens, the herd, the clock and the bits are the ones she walked in
  with (test_palace_interior, GUT and real input, both check). A separate scene was rejected
  for exactly that reason: the Factory's scene change needs a save and a reload around it.
  Under the map rather than off its edge because a room off the edge can be seen from the
  valley rim; under the ground the terrain hides the roof.
- **What being under the map costs, and the fix for each.**
  - The camera's terrain guard would lift the lens to the grass overhead: CameraRig gains
    `ground_guard`, off while she is inside. The hall's floor, walls and ceiling are on the
    TERRAIN layer the arm's sweeps probe, so the lens stays in (the real-input test swings
    the camera a turn and a half and floor to ceiling at the slots and at the doors: 0 bad
    frames).
  - The sky would rain and fog indoors and the sun's toon shadow would band everything:
    SkyRig.set_indoors() puts the sun out, stops the rain, thins the fog to nothing and gives
    the ambient a warm fixed fill. The hour and the weather keep ramping underneath.
  - Everything else measures the map in the XZ plane, so the Palace's own door, the
    townsfolk and the Scoop Launcher would all be "in reach" from below: inside, the
    interact resolver is handed the hall's candidates and nothing else.
  - Tumble's follow is an XZ walk: she waits at the foot of the steps
    (People.park_companions()) and follows again when the player comes out.
- **Walking in is going in.** A trigger just inside the doorway takes her in; E on the steps
  does the same ("E: go into the Spectra Palace"). Inside, walking into the doors or E in
  front of them takes her out, to the foot of the steps, facing the Strip, with the camera
  reset to its default pitch behind her.
- **Every station opens the existing screen, straight at its game.** Slots, the wheel,
  blackjack (two tables) and racing open their own panels exactly as the lobby rows did; the
  cage opens the lobby panel on its Cage tab (House rules is a tab away). Two new resolver
  verbs, appended so every old int keeps its meaning: PALACE_STATION (the station id is the
  subject) and PALACE_EXIT. The lobby menu itself is untouched and still reachable from the
  cage.
- **The door's rules hold at the door.** casino_can_enter() is asked before she is let in
  (closed before the grand opening: walking into the doors says so, once per approach), the
  stations are not offered while it says no, and enforce_palace_ban() walks her out at once
  if it starts saying no while she is inside. A ban does not wait for a fade.
- **The weird sign was real, and still there.** Round 2 lifted the Strip's marquee board to
  4.6 m over "the ground", but the Strip hangs it while the Palace is still at y = 0, and the
  Palace is then seated 2 m up onto a plinth whose floor is 0.85 m higher again: the board's
  lower edge stood 1.73 m over the floor of the doorway, through a pony's head. Strip now
  rehangs it after the seating loop (rehang_marquee()), its lower edge 3.3 m over the
  doorway floor, over the doors and the camera, under the model's own pink sign.
- **The doorway is a door now.** pc_palace_doors (velvet leaves, gold studs, lit portholes)
  stands in the model's dark recess, with a collision slab behind it so nobody walks into the
  model.
- **Built lazily, behind the black.** The hall is about seventy models and twelve dressed
  ponies; it is built the first time she goes in, so a player who never does never pays for
  it at boot. test_scale asks for it (ensure_palace_interior()) and measures every piece.
- **The kit is Blender, like the Factory's.** Seventeen pc_* pieces in
  tools/blender_props/build_props.py: the hall shell (parquet, patterned carpet, a red
  runner, plum walls, ruby panels, velvet pilasters with lit sconces, a neon band, a starry
  coffered ceiling), white columns, two slot cabinets, the wheel and its stand and stage,
  the blackjack table, the cage, the racing booth, chandeliers, the doors in and out, a rope
  lane, palms, neon stars and horseshoes. The wheel's pockets and the felt are the casino
  screens' own colours (converted to linear for glTF), so the wheel on the stage and the
  wheel on the screen are one wheel. Glowing materials carry glTF emission, which ToonStyler
  passes to the toon shader.
- **Some life.** Staff are Attendants (not Ponies, so the beam cannot take them): a cashier,
  a race clerk, a wheel host, a dealer at each table, and regulars at three machines and the
  tables, coloured by the random generator's own look draw, seeded. The wheel idles round,
  the bulbs breathe, and the tote board runs a race of lights.
- **Footsteps on timber.** The hall's floor collider is tagged hoof_wood (carpet or
  parquet); there is no carpet set, and the soft clop reads as an indoor floor.
- **SCALE.md** gains two categories (interior 2.5-4.5 PH: the hall and its columns;
  fixture 0.3-1.5 PH: the chandeliers) and a row for every pc_* piece. The racing booth's
  horseshoe was lowered to fit stall's 2.5 PH (it measured 2.55).

## 2026-10-26 -- the second overnight pass: endings, wayfinding, feel, one art language
Owner asked for a pass on four gaps: art that reads as one style, animation and feel, wayfinding and onboarding, and endings that block. (Licensing is out of scope for good.)
- **lights_out was a real bug, not the bot's.** The Act Three sites (Dye Vat, pylons, corrals) speak only when the ranch offers nothing, and a companion at your heels counted as something, so Tumble or Pip took E at the Vat for good. A companion now steps aside for a site in reach, exactly as she already did for a building.
- **gray_gold stalled on a pony the bot could not reach** (a Drifter inside the locked Everfree), chased for six hours. The bot now gives up on a pony it cannot close on for three minutes and says where she was. The game was right: the region needs a permit.
- **"Catch a pony" never ticked.** The board was told of a catch only for named ponies; in the first minutes every pony is a Drifter. The board now hears of every catch; only the Compendium skips the crowd.
- **The guide, not a quest marker.** One rule-based goal at a time (systems/guide.gd): a full bag, then the mail, then news, then the three lessons. Past the lessons it speaks only for things that are waiting, so it guides rather than nags. Shown as a short drifting trail of star motes on the ground and a gold-ringed icon on the compass, pinned to the strip's end when behind her. No floating words or arrows, per the owner's bar. Settings > Gameplay > Show the way.
- **One UI language.** Every menu frame is now the HUD card's language in Palace plum: violet outline, round corners, soft shadow. The black slab is gone. Market tiles end their one line properly and name their kind, and a detail strip shows the pick in full with a Buy button: a cut-off description was why upgrades read as unclear.
- **Feel at the two verbs you do most.** A catch: her ghost arcs into the Scoop (stretch, shrink), then pop, Scoop squash, camera kick. A pen: she flies out of the Scoop over the rail, grows, lands with a squash and a puff. The camera gained a trauma shake (centimetres, gone in a second, toggle in Settings).
- **Paddocks and region borders are cartoon timber** (round posts with caps, rounded rails, warm wood, toon shading and ink) instead of untextured boxes: the most-seen object in the game was the least show-like.
- **A sign in the way is gone, not half gone.** Half faded it drew as a grey or dark sheet across the screen at the pen's gate. A board between the lens and her fades at any distance, and past 0.85 it is not drawn.
- **A post against the lens is not drawn** (pen timber within 0.75 m of the camera).
- **Not done, logged:** the walk sound; a bits sink after the ending.

## 2026-11-05 -- learning from home-equestria; the slapstick bounce

The owner pointed at github.com/homedevanon/home-equestria (a Godot 4.5 Ponyville life-sim) as a source of better parts. Their order: hoof sounds first ("anything is better than we got", though theirs were "a bit loud and not perfect" in play, so they go in quieter and tuned); then faces and eyes, better models where they fit, the procedural leg solver, and world techniques. Voice is not wanted.

Their mares carry a "flank jiggle" shader. I first said no to porting it; the owner overruled: "its my game i want to see if it creates funny elements ... i see a bouncing butt as funny not sexual". The owner's call stands. It is built as our own secondary-motion bounce on the hindquarters, fired by slapstick moments (landing from a jump, flopping into a pen from the beam, sitting down hard) so the owner can judge in play whether it lands as comedy.

## 2026-11-05 -- the pasture by the yard thinned, and the wild refills slower

The owner's note "its super easy to catch ponies so you can collect all the spots before you get upgrades" survived the catch ramp. On the half_light bot run both starter pens (six places) were full by 3:36, and the first 150-bit upgrade came into reach around minute six to ten. The cause was supply, not the catch: HomePasture, beside the yard, held a named pony and four stock ones and refilled each 45 s after she took one, so the next catch was always a few steps away. HomePasture now holds two stock ponies (the first lesson still has one close by), and stock respawns after 90 s, not 45. Filling the pens means going out to the other fields, which is also where the world is. Pinned by game/test/test_pacing_tuning.gd; the real-input first catch, catch card, beam targeting and find-the-market tests pass on it. The five endings have not yet been rerun on it.

## 2026-11-05 -- decorations stand in hand-placed spots, not anywhere

FS7.1 planned free placement with a ghost. Built instead: twelve decorations (200 to 20,000 bits) sold at the Market, each with its own spot round the homestead, standing the moment it is bought. A spot can never block a road, a pen gate, a building or a townspony (game/test/test_decor.gd holds all twelve clear of each), there is no new placement interface to learn or to break, and the plaza always looks arranged. Two of the twelve are stone statues of Fluttershy and Rainbow Dash (their own bodies, frozen and greyed, on a plinth). Free placement can come later on top of the same catalogue. The collection sets that unlock decorations (FS7.2) are not built yet.

## 2026-11-05 -- the playtest sweep is fixed by cause, not by item

The owner's 70-item playtest (docs/playtest-2026-11-05.md) is planned as eleven groups by shared cause (PLAN.md section PT), each with a test that sweeps every instance of its kind, so a fix to one building, menu or pony cannot leave its siblings broken. The owner asked for exactly this ("tackle ... from the root and make sure its not reoccuring similar elsewhere"). The Wheel becomes a tiered wheel in the style the owner named (Rust's), replacing the colour and number bets.

## 2026-11-05 -- an Escape Artist comes home at dawn; nobody owned spawns twice

The owner: "were my ponies escaping the paddock? cuz i feel like i was catching repeats". Both were true, and the second was a bug: an escaped pony's body stood in the world unknown to the spawner, so it spawned her again (two Sweetie Belles side by side, two Scootaloos in the Deliver list). The spawner is now told every named pony the player has (pens, saddlebag, out for the night) and never draws one of them. The Escape Artist trait stays (she hops a Paddock fence at night; a Big Pen holds her), but she is no longer lost: she comes home at dawn to her own pen or any with room, and the save remembers her if the game is quit at night. The pasture by the yard is Drifters only (the homestead's crowd rule, four stock to one named, had been broken by thinning it), and the Bloom objective says only Drifters Bloom and sends her for one when none is penned (the owner had delivered every Drifter and kept the named ponies, so "0/2" could never move).

## 2026-11-05 -- the casino rebuilt: a Rust style wheel, real reel strips, blackjack with decisions

- **The Wheel is a tiered big wheel** (owner: "closer to the rust wheel with different payout levels"). 45 equal segments: 1x on 21, 3x on 11, 5x on 7, 10x on 4, 20x on 2. A tier of n pays n to 1 (stake back on top), the Rust convention and the honest reading of a "3x" on a slice. Stakes go on any number of tiers at once; the stacks stay on the felt for the next spin unless the purse can no longer cover them.
- **Why 45 and why the tier edges differ.** Returns 2, 4, 6, 11 and 21 share no small multiple, so no wheel under a few hundred segments makes every tier equal. A search over 20 to 60 segments found 45 the wheel whose worst tier is kindest: every tier keeps 2.22 or 6.67 per cent (old roulette 4.0, slots 7.0). The lobby sign prints the worst (6.7), the felt's rules print the range. The layout was searched for no two neighbours alike and each rare tier spread evenly (the two 20x opposite).
- **Slots get a real strip per reel**, same counts as before (so 3809/4096 and the 7.0 per cent edge are unchanged to the chip), ordered so any three adjacent positions are three different symbols. The playtest's "three apples stacked" came from a sorted shared strip. The menu lands each reel on a real strip position carrying the rolled symbol, so the symbols above and below the payline are the strip's true neighbours; which occurrence is used walks with the spin count (no generator under game/ui/).
- **Blackjack has decisions**: Hit, Stand, Double on the first two cards (one card, twice the stake). No split, no insurance (a second hand to lay out; not asked for). Dealer peeks for naturals, keeps the hole card face down until she stands, draws below 17 and stands on any 17. Twenty one stands for her. A hand lives in game/systems/blackjack_round.gd; ranch.gd holds the one live round and still moves every chip (the doubling stake comes out before the card). Walking away mid hand stands for her rather than forfeiting.
- **The published blackjack edge is unchanged**: the strategy card reference player now plays through the same round class, asking the generator for the same numbers in the same order, and re measures to 5.2 per cent.
- **The three tables share a button stage** (game/ui/casino_table.gd): every control is a drawn thing on the felt, one list feeds the paint, the pointer and the keyboard. The row column, the result text log and the key hints are gone. The old 50/200 chip bug was that the drawn chips were never click targets (invisible rows in the column under the stage were).
- **ranch.gd was edited** (unavoidable: the wheel's bet became a set of stakes and blackjack became several requests): play_wheel(bets), play_blackjack() deals, blackjack_action() acts. The slot machine's glue is unchanged.
- **The casino gate checks slots and the wheel by roll frequency, not by a measured edge.** Their edges are exact by enumeration (unit tested); a 100k-spin measured slots edge has a standard error near two points (a 450x line), and the old 0.6 point check passed only on its seed's luck. Symbol and tier frequencies have no fat tail, so the same tolerance is several standard errors wide.
- **A result pushed into a closed table lands at once** (a gate, or blackjack's walk-away Stand, settling while nobody watches), so the felt is never still "spinning" when she next walks up to it.
- The ranch.gd blackjack wiring (play_blackjack deals, blackjack_action, the action_requested connect) went in with the orchestrator's commit e560489 rather than the casino's own.

## 2026-11-05/06 -- the overnight sweep's design calls

Made without asking, per CLAUDE.md; each is the smallest change that fixes the owner's note at its cause.
- **Buildings are not entered on foot.** Every doorway is sealed; the Palace hall is still reached through its doors by Ranch.enter_palace. A worn model now stands 0.2 m over the highest ground under it instead of on a 1.8 m pedestal (the plinth only shows where the ground falls away).
- **The camera's field of view defaults to 60, not 75.** A save holding the old default is moved once; a chosen value is kept.
- **A delivery pays a handler's share** (a quarter of its credit, into the purse) ON TOP of the full credit coming off the balance, so the story's pace of paying the debt is unchanged. Food sells in sacks (hay 20 for 20 bits).
- **Rarer ponies weave in the beam.** Uncommon, rare and legendary ponies drift off the crosshair while held; only time on the crosshair secures them. Commons and Drifters are caught exactly as before. Tuned so the endings bot still catches them (its servos outrun the weave).
- **A new area opens with one of its rares** standing inside the gate, pointed out like a sighting.
- **An Escape Artist comes home at dawn**; nobody the player owns is ever spawned in the wild as well.
- **Spike gives tips** (E at Spike): the most useful thing to know right now.
- **The pause menu opens mid conversation**; the talk box steps aside and comes back.
- **Toasts live at the bottom centre**, wrap at 900 px, and hold while paused.
- **The Wheel is a Rust-style tiered wheel** (1x to 20x on 45 segments); Blackjack has real decisions. (The casino agent's own calls are logged above under 2026-11-05.)
- **Controller rebinding (FS8.1) shares the key row.** Pressing a pad button while a row listens rebinds the button; B always cancels and is never bound, Guide and D-pad up/down (zoom) are reserved, and the sticks stay fixed. Backspace resets both key and button.
- **The lake's wading floor ramps down at its rim** (2026-11-06): it had made a 0.55 m wall round the lake, found by the endings bot at the Lake pylon.
- **FS4.2 is a GaitBlend over the AnimationPlayer, not an AnimationTree blend space.** Two rigs (PonySFM and the Mane Six) and four actor scripts already drive one AnimationPlayer each; a shown speed that settles and a debounced rung-down gives the stop through trot and walk, and a roll gives the turn lean, with no new rig wiring. At a run only the front hooves sound, now judged by the clip she shows rather than her true speed (a settle step was a rear-hoof tap).
- **The five-ending bot playthrough is no longer a gate** (owner, 2026-11-06): hours of wall time for little signal. Changes are verified by focused GUT tests on the system touched, short real-input tests where input matters, and renders that are looked at.

## 2026-11-06 -- the review of the unreviewed commits

A Fable review of the FS sweep, de3f961, a543262 and 13d0c11 (never reviewed before) found five bugs, all fixed with a test each:
- **A clip played over a one-shot ends it** (Pony._play clears `_action`). A startle cut off by the beam's struggle never sent animation_finished, so the pony never animated again.
- **A catch ends an Escape Artist's night out** (Ranch._end_night_out on every capture). The saddlebag is not in GameState.ponies until a save syncs it, so dawn penned a second copy of a pony caught again that night.
- **A townspony makes room without losing her spot.** The push out of the player or a wild pony now goes into `_yield`, which runs back at 0.5 m/s once nobody stands in her; only the townsfolk-on-townsfolk push moves `home` (so two sent to one spot still settle side by side). Her shape query is skipped past 30 m from the camera.
- **The ranch applies the saved text size** too, not only the title screen.
- The FS items the review found built short of their spec are marked PARTLY DONE in PLAN.md with what is missing, rather than ticked.

## 2026-11-06 -- the PT ticks were false; section PS re-opens all 70

The owner's audit request found nine playtest items not met (3, 6, 29, 32, 36, 44, 55, 64, 69) and four unverified (17, 37, 40, 56), though PLAN.md ticked them all. They had been ticked because a commit cited them. From now on an item is ticked only in the ledger (docs/playtest-2026-11-05-ledger.md), only with evidence of the owner's own words, and only marked MET by an acceptance reviewer that sees the owner's text and the evidence but not my commit messages. Calls made in PLAN.md section PS, logged here: doors at least 1.25 times the player's height (29); a paved street with yards for the Ponyville row (36); every rarity weaves in the beam, scaled from 0.35 to 1.2, with pacing bands enforced by tools/pacing.sh (69); permit tiles preview the region's ponies (55); a pantry chip per pen and a SAD hungry pony (64); coat markings, six accessories and eye shapes (6); a stamp-based mark editor (3); casino regulars animate and move between machines (44).
- **Owner answers, 2026-11-06, on the PS calls.** Catching: every rarity weaves, and smarter fleeing; catch-behaviour types and beam stamina were declined. Pacing: both halfway. The owner's money came from selling every repeat and keeping the best earners, so a repeat's sale price falls with each sale of the same pony in a cycle (100, 70, 50, then a 35% floor), other earnings drop about 15%, and prices rise about 15%. World: buildings scaled up to the doors. Creator: all of the stamp mark editor, coat markings, accessories and eye shapes. Already-claimed items get one quick batched check, not a full re-work.

## 2026-11-06 -- PS0 and PS1 item 17, as found

- **An Escape Artist home on a load counts as owned.** Loading a save quit at night brings her home at once (she has no body after a quit), but her only record had been the night-out list, which coming home clears; until the next save, `_owned_named_ids()` (which the spawner reads) missed her and the wild could make a second of her. It now reads the pens too, and the Survey's picker reads the pens and the bag through `_owned_instances()` (same cause: a pony caught since the last save could not be named). Found by the old-save test.
- **Item 17, "Twilight twisted at a broken angle", is the borrowed clips, not the body sim.** A probe (scratchpad twist_probe.gd; renders in build/ps_evidence/item17/) put the Mane Six on slopes, in the beam, dropped from 3 m and in a full Paddock: the torso never turned more than 18 degrees from rest and the body never leaned more than 2.4. The clip sheet showed it instead: Lyra's graze (and sleep) lower the head at the skull joint alone, and the retarget carried that 68-degree bend onto Twilight's head joint, whose pivot sits elsewhere in her skull, folding her muzzle into her chest. The fix shares the head's turn down her two neck bones (50% and 90%, picked by eye against the donor's own graze from three tries: 30/60 left the muzzle under her chest), so the head ends where the clip puts it and no joint folds. The PonySFM cast is untouched.
- **The pacing bands are checked by a model, not by tools/pacing.sh** (2026-11-06): pacing.sh drives the human-paced bot through the game, which is a bot playthrough, and the owner has banned those. test_pacing_model.gd replays the owner's sell-the-repeats strategy from the game's own constants instead.
- **Every Drifter counts as one kind for repeat deliveries**: the owner's money came from delivering every pony that was not one of a kind, and Drifters are the farm.
- **Item 69, as built (2026-11-06).** Every wild pony weaves in the beam (Drifter 0.35, common 0.55, uncommon 0.8, rare 1.0, legendary 1.2) and every weaving hold needs 1.2 s more on the crosshair, so the quickest common takes 2.05 s. Only a SHY pony sees further, 16.5 m (was 14): the plan said a quarter further (17.5), but then half of it while sneaking (8.75) is past the beam's 8.5 m reach and the sneak stops working (test_magic_beam's invariant), so 16.5; she is the only one who runs, and a wider CURIOUS radius would have had the whole field walking over. A fleeing pony looks 2.5 m ahead (three rays, shoulder width) and takes the smallest turn of 0.5, 1.0 or 1.5 rad that is clear, keeping to the side she chose. Repeat deliveries fall 1.0, 0.7, 0.5, 0.35 per kind per cycle, quoted on the Depot tile too; the handler's share falls with them. Gem values drop to 4 / 10 / 26 / 85 (were 5 / 12 / 30 / 100): whole bits, so the tile's price is the price paid, which makes a common 20% down and the rest 13 to 17%; deliveries keep the old units in Ledger.DELIVERY_UNIT_BY_RARITY so they are not cut twice. Pens, permits (shop and region), gear, decor and plot clearing cost 1.15, rounded to 5; food is unchanged. **The "under 20 deliveries in the first hour" band is not checked**: no model of hands can say how many deliveries a player makes, and a bot run is banned, so the owner's next playtest judges it. The model (test_pacing_model.gd) shows the owner's first hour of repeats now credits 58% of what it did (7305 bits, was 12600), and a 765-gem trip sells for 3060 bits (was 3825); one mid-game period still brings the debt from 25000 to 9423, so the debt stays easy at the owner's pace -- halfway, as chosen.
- **Item 17b's last merges were turns, not steps (2026-11-07).** A seeded trace showed two ponies turning on the spot sweep their heads 0.23 to 0.35 m into each other in a tenth of a second. A turn that would bring a pony within BodySpace.CLEARANCE of a neighbour now goes the long way round, or is held if both ways are blocked; a held pony does not walk more than 90 degrees off her facing (without that, one walking pony in eight walked backwards or sideways). The cost is accepted and logged: in a tight clearing of ten, ponies walk about half as often, waiting for room. test_wild_no_merge is seeded now, because unseeded it passed or failed by luck.
- **Item 55 and G15 (2026-11-07).** A permit's detail strip in the Market lists everypony whose spawn zone is that region, rarest first, each as a chip with her rarity shape and her hours drawn (ui/hours_icon.gd: sun, moon, a sun on the horizon for dawn or dusk; sun and moon together for any time); rare and up get a gold edge, so the Orchard shows Applejack first. Words were kept to her name: the owner asked for visuals over text. Rendering it found that no decoration could ever be bought (Shop.refusal had no DECOR case and answered "Not for sale yet."); fixed with a test, and an owned decoration now says "You already have that." rather than the Supply Desk line.
- **Item 64 (2026-11-07): the pantry is one HUD row, not a chip per pen.** Pens have no sign to hang it by, and one row under the bits answers the owner's words (the stock and the hungry) wherever the player stands. A hungry resident looks SAD, but a render showed the face change alone is too slight to read across a pen (the mouth is part of the model), so she also wears a cream bubble with a hay bale, the townsponies' news-bubble shape. The row uses the card's own inks: styled white, it was unreadable on the cream card, the same fault as G13.
- **Item 29: the doors you see, measured (2026-11-07).** Orthographic renders of each model with a half-metre grid showed the painted doors at 0.47 (Barn) to 0.69 (Depot) pony heights: shorter than the pony, while test_scale passed on the hidden shell's 3.85 m opening. The plan's target, 1.25 PH, was written before that measurement; the doors now stand 1.32 PH, just over SCALE.md's own door minimum of 1.3, by growing each building (Barn x2.78, Farmhouse x2.18, Market x2.01, Depot x1.90) with its door front kept where its road ends. SCALE.md's house and landmark maxima went up to 9 and 10 PH to admit them; its door row now means the painted door. The Board building moved to the lot west of the north road (it would have stood inside the Farmhouse), the homestead's yard props and two decorations moved out of the grown footprints, and the Market and Depot now open from their doors rather than from their centres (the Market's door had ended up outside its own radius). The ramps the owner called oversized are untouched in this commit.
- **Item 36 and the town row's doors (2026-11-07).** The row's six houses had painted doors of 0.43 to 0.84 pony heights. Grown to a pony's door, three of them (pv_ogb_1, pv_ogb_2, pv_balcony_b, each with only a small side door on a big front) would stand 18 to 29 m tall, so the row is now two each of pv_pink_b and the courtyard pair, the two whose doors make a house at pony scale (11 and 15.6 m), two a side, set back so each has a yard. The street is code (world/street.gd), not props: the road through the row paved in the Strip's own flagstones from a kerb across the dirt road, kerbed both sides, each house fenced with a white picket (built, since the only fence model is a 5.4 m rail) gated at its door, the gate placed off the house's measured door (Props.DOOR_OFFSET). The Strip's paving rim is clipped to its circle (a 360-gon) instead of stepping. The lean in the owner's screenshot was the old 75-degree lens; nothing is tilted to the ground.
- **Item 40: rain at night (2026-11-07).** Measured at the owner's spot, rain took a quarter of a clear night's light. At night, rain now keeps 92% of the moonlight, the ambient fill and the sky, and mixes its cloud colour in at a quarter and its haze at a half of their daytime weights: a rainy night renders at 95% of a clear night's mean luminance. Storms keep the old, darker night floor; rain is still strictly dimmer than clear and storm dimmer than rain.
- **Item 48: Split (2026-11-07).** Once per round, on a pair of the same rank, before any other action; each hand carries the stake and gets one more card; she may Double either split hand; split aces take one card each and stand; twenty one on a split hand pays even money; the dealer plays once after both hands, and draws nothing if both bust. No resplitting and no insurance. The four buttons sit in one row with Split greyed when it cannot be taken, so the row never shifts under the cursor.
- **Item 3: stamps, and G16 (2026-11-07).** The mark canvas keeps free drawing and gains up to three stamps (the 24 talents and 12 plain shapes), each moved by its body, sized by its corner knob, turned by its top knob and recoloured by an ink; a press anywhere in a stamp's box takes it (a hollow crescent pressed in its middle used to paint a stroke). The one-pair-three arrangements and the six whole-canvas stamps are gone. Rendering it found that no mark had ever shown on a pony: the decals project onto the mesh with the most vertices, which is the head on the PonySFM rig; the mark now goes on the mesh named as the body.
- **Pace without lowering the bar (2026-11-07).** The owner asked for faster fixes at the same quality. Two changes, no relaxed evidence: (1) two items run at once -- one Opus 5.5 subagent in its own git worktree on an independent PS group (first PS3: 39, 53, 62, 63, 70), held to the same rules (root cause, failing test first, renders looked at, a ledger row with evidence), while I work another; its branch is reviewed by me (diff read, tests re-run) before it is merged onto v1-overhaul. (2) The full suite runs on a detached snapshot worktree of the commit (tools/suite_snapshot.sh), so editing carries on during the 15 minutes instead of waiting; it runs once per batch of about three items and before any row is ticked, and every item still gets its targeted tests and renders.
- **Item 6: what "more customisation" is (2026-11-07).** Markings, eye shapes and accessories, all three (the owner approved all three in the PS plan), on one new creator step of picture cards rather than words. The four existing wearables were made for other characters (Marigold's sash, Pip's satchel, the Collector's goggles): the hat fits a pony and stays; the sash, satchel and goggles were remade in a pony's own units as a barrel sash, saddlebags and pony goggles, and a bow and a scarf were added. Pieces are painted with her own toon (the props' style bleached leather to cream); a hat rests on whatever mane she has. NPCs wear none by default (accessory -1).
- **Item 62: menu time is day time (2026-11-07).** The owner's save had 3392 s of play and 1647 s on the world clock: every menu pauses the tree, and the clock only ticks unpaused, so an evening at the tables never reached the first collection. The time a menu was up now goes back on the clock when it closes (in 60 s steps, so night escapes, the dawn cart and a collection day still happen in order); the pause menu still stops time. The 20-minute cycle and the three-cycle period are unchanged, so the first collection lands about an hour into play; before it, the statement says when it comes instead of "Collections passed: 0".
- **Item 53: the Bloom step points at a Drifter (2026-11-07).** "Feed Drifters to Bloom" no longer borrows the pens goal (a pen with room, which with every pen full fell back to the first plot). It leads to the nearest pen holding an unmarked Drifter, full or not, and "Pen a Drifter to Bloom" leads to the nearest wild Drifter rather than the nearest wild pony of any kind, since only a Drifter can Bloom.
- **Items 39 and 70: nobody twice, and the pens hold (2026-11-07).** The owner's "escapes from fully upgraded pens" were repeats: the CMC Escape Artists hopped Paddock fences early on and his build's spawner drew them, and other ponies he owned, into the wild again. No code lets a Big or Grand Pen lose a pony at night, and that stays. Owned repeats stay blocked (PT3) and the rule now covers every way a named pony enters the wild: a guest (Tumble's sighting, a canon guest) is refused if she is owned or already standing, and a pony walking off the map still counts as standing until she is gone, since she can still be caught. Not changed: a named pony who has been delivered or taken is no longer owned and can be drawn into the wild again later; that is a story question (the Factory's harvest) and was not what the owner reported.
- **Item 63: the Deliver tag is counted (2026-11-07).** "One of a kind" now shows only on a named pony with no twin in the pens; a twin (only possible in a save from before the item 39 fix, since nobody owned is ever deleted) reads "there are two of her here". The tag stays on unique named ponies, because it is the warning that she cannot be got back.
- **Items 8, 51, G13: the paper letters (2026-11-07).** A numbered "N. VERB" line in any letter is drawn as a step row (a picture tile with its number, the step in bold, the how-to under it), so the welcome letter's how-to is four rows, not a paragraph; the letters' text is unchanged and the capitals become sentence case only on the sheet. The pictures are the HUD checklist's own Catch, Pen and Sell icons plus a drawn gem for Collect, so the letter and the checklist teach with the same pictures. Every button on a paper sheet wears one new style, MenuStyle.paper_button (ink on a slightly darker paper face, ink edge, gold under the pointer), instead of the dark-menu theme Button. The letter's sheet is now fully opaque (it was 0.97), because a HUD toast showed through it beside the survey's answers.
- **G14: decoration pictures are baked from the real models (2026-11-07).** The twelve Market decorations get pictures rendered from the very prop (or stone statue) the ranch stands, with an ink edge so pale ones (hay, stone, the white arch) read on the tile's cream disc, rather than twelve new hand-drawn vector icons: the tile then shows exactly what she gets. Same pattern as the creator's style cards (baked PNGs committed under game/assets/ui/, re-baked by a probe, game/scenes/test/decor_icons.gd). Flower Bushes shows the bush model as it is in the world, which has no flowers.
- **Item 9 and physics interpolation (2026-11-07, reworked after NOT-MET).** Measured per drawn frame at an exact 144 Hz (tail_frames.gd, sampled just before each frame is drawn), PT11 had made the tail worse, not better: putting her clip and springs on the 60 Hz tick made the tail the one thing on screen stepping in a 2-3-2 frame cadence (jerk/motion 1.99; before PT11 it was 0.135 in her own frame, and PT11's per-tick "win" was mostly sampling a per-frame tail at uneven tick moments). Before PT11 the remaining 60 Hz step was the camera: it follows her body, which moves on the tick, so the whole world stepped (31 m of jerk over 15.6 m of motion). Fix, confined to her: her Visuals and the camera's pivot are drawn between the last two tick positions by Engine.get_physics_interpolation_fraction() (her yaw likewise), while her collision body and everything gameplay reads stay on the tick; the clip and the springs went back to per drawn frame. Not Godot's built-in physics interpolation: it is project-wide (every NPC, prop and the camera rig, which places its lens in _process from global positions) and would need reset_physics_interpolation at every teleport (ranch.gd alone sets her position at nine places). Teleports here need no call sites: anything that moves her outside her own tick, a tick step over 2 m, face(), or a yaw set by someone else (shot scripts) is drawn where it lands. Result per drawn frame at 144 Hz: tail jerk/motion 0.135 (PT11 1.993), world on screen 0.0016 m jerk (31.1 m), her body still on screen (0.0002 m). Other actors (ponies, townsfolk) still move on the tick; at their distance and speed that is the usual 60 Hz cadence of a physics game, not chased here.
- **Item 61: the Lake is a wading pond with banks (2026-11-07).** Root cause: the lake was a 2.2 m bowl subtracted from relief that varies 3 m across it, with a flat disc laid on top at one height, so the bank cut wedges out of the water on one side and the disc's rim stood in the air on the other; ponies stand on height_at() (the bowl floor), under a wading shelf only the player's collider had. Now the ground is shaped round the water (terrain.gd `_lake_ground`): the relief is levelled to one bank-top height inside the shore + 4 m, easing back to the hills 6 m past the fence; one smooth bank curve falls from that level through the waterline at 0.7 of the radius (unchanged, where the lily pads and jetty already were) to a flat bed 0.45 m under the water (lake.tres `lake_depth`, now meaning water over the bed). The water is a paper-thin opaque sheet tucked 1 m under the bank. Call made: wading depth everywhere, not a shore wall for the player, because the Act Three Lake pylon stands 12.8 m out in the water and must be walked to; 0.45 m is below a 2.19 m pony's knee. Ponies are kept OUT of the water by a one-way invisible ring on PEN_GATE (in a pony's mask, not the player's or the camera's), 0.5 m outside the shore, facing out: a pony walking down to the water stops on the bank; one dropped in the water by the beam walks out through its back. The spawner draws the Lake's ponies over the dry ring only, and the Lake marker became spawn_radius 20.5 / roam_radius 4 (was 18 / 6) so its residents' roam discs still fit inside the fence ring check. Not changed: pony.gd's wander still picks targets in the water (it is being edited in parallel); such a pony walks to the shore and stops there, which reads as going down to drink. The black wedges were the canoe's hull and the shore stones' mossy tops painted black by region_dressing.gd's default "no tint" Color(), which is opaque black; the lake's calls now pass NO_TINT / GREEN. The same default still reaches the Everfree's _scatter calls without a green (mushrooms, logs, rocks), not looked at here.
- **After the lake (2026-11-07, reviewing the PS2 branch).** Two loose ends from its report, closed: (1) region_dressing's tint default was opaque black everywhere, not only at the lake: three rock kinds in other regions wore black grass tops; every placing function now defaults to NO_TINT (test_region_dressing.test_no_dressing_material_is_painted_black). (2) A lake pony's wander picked spots in the water 73 times in 300 and walked to the shore ring to stand; the pick now skips the keep-out ring and falls back to its last dry pick (test_lake_shore.test_a_lake_pony_never_wanders_toward_the_water).
- **G1: the lesson chip's tooltip is a HUD card, themed for every tooltip (2026-11-07).** The sentence comes up on the HUD's cream card with its pay under it, through the engine's own tooltip (hover delay and placement are Godot's) rather than a hand-rolled popup; the card look went into the generated theme (TooltipPanel, TooltipLabel) so the compass markers' and the creator's tooltips stop being grey slabs too. Not changed: in play the camera holds the cursor whenever no menu is up and every menu dims the HUD, so a player only reaches the hover with a free cursor over the HUD. A "hold a key to free the cursor" was not added: it is a control-scheme change for the owner's playtest to ask for, and the objective card already carries the current lesson's sentence.
- **G6: the tile deal and the coin (2026-11-07).** The stagger runs on a clock per menu (game/ui/tile_entrance.gd), not a tween per tile, because the menus rebuild every tile on each cursor move and a tween dies with its tile; it deals on opening and on a new tab only. It went into the Depot and the build menu as well as the Market, since FS6.1 says "every tile menu". The coin flies on a buy as FS6.1 asks, and on a sale too (a shower of up to four), because a sale is the money moment the Market is mostly for. The spec says "from the tile to the wallet" even for a purchase, where money leaves; kept as written: it reads as the purse taking the change, and the pop beside it says "-N bits". A free item moves no bits, so it flies no coin and does not emit `purchased`.
- **G7: the Depot's payout (2026-11-07).** Each delivery is a card counting up where it was pressed (a named pony's card starts on the "yes" tile, since her own tile is hidden while the counter asks), the cards pay one by one, and the purse (new: her bits and what she owes) lands once when the last coin is in, per FS6.2's "three deliveries give three roll-ups and one balance change of their sum". One counter tick per card, on the existing ui_move sound, and ui_confirm when the total lands: the world SFX (coins_grant, reel_tick) are on the Effects bus and would be paused under the menu, and no new sound was made. The purse also rolls when a Pay-tab payment changes it, for the same feel.
- **G8: the Depot's rarity shapes are in the gem colours (2026-11-07).** The shape is RarityGlyph's, coloured like the Sell tab's gems of that rarity, so the Depot, the pouch and the Market agree on what "rare" looks like.
- **Item 43: the Teller stands off the plinth as built, and the Palace opens from 6.5 m (2026-11-07).** He stood 0.65 m past the shell's `depth * 0.5`, but the Palace wears a model whose plinth face is at 4.83 m, and he faces out with about a metre of hindquarters and tail behind his origin, so 0.7 m of him was in the brick. He is now placed off Building.plinth_rect() and his own measured body (Attendant.drawn_rect()), still facing out beside the ramp (turning him side-on would have kept him inside 6.0 m by 4 cm and shown the player his flank). That puts his origin 6.36 m from the Palace's centre, so PALACE_RADIUS went from 6.0 to 6.5: the Palace stands alone on the Strip, so nothing else opens or intrudes differently.
- **Item 65: each resident has her own spot, and stops facing out (2026-11-07, after the PS13 review).** Set down 0.75 m apart, item 17b's turn hold froze nine wandering ticks in ten and the pen stood as one clump; letting residents roam the whole pen by roominess sent them across it through each other into the same jam. The spot ring (one in the middle, seven on 2.25 m) and short walks round it keep about 1.9 m between centres; stopping on the ring she turns to face out over the rails, so neighbours stand side by side instead of nose to rump. Cost: residents walk shorter distances than before. The ranch's pen probe now sends its residents at the fence (Pony.wander_to), since its stress had relied on incidental long walks.
- **G11: the herd's cost was BodySpace, measured per section (2026-11-07).** The 60-pony check (invisible display, against the commit before the sweep, alternating runs) bisected to item 17b's turn rule, and a per-section profile of the pony tick found BodySpace's solve at 4 ms a tick (each close pair re-derived body lines and closest points up to four times, allocating arrays) plus the turn rule rebuilding neighbours' footprints. Now one pass per pair, no allocations, and turns read the tick's footprints. The invisible display still cannot show the 16.6 ms budget (its presentation adds ~20 ms, see "Shadows" above); the gate is "no worse than before the sweep", run against 2099bcc^.
- **G11, the second pass: the scripts got cheaper, and the frame is the render thread's (2026-11-08).** A per-section profile of the 60-pony check (temporary timers; build/ps_evidence/itemG11/README.txt) put the pony tick at 6.7 to 7.3 ms a physics tick, BodySpace's solve 4.0 to 4.1 of it and turn checks 1.4 to 1.5, and the idle pass at 3.7 ms a frame. Cut without changing what any pony does, for any pony (no level-of-detail change, nothing done less often): the solve weighs only the pairs in neighbouring cells of a grid as wide as its reach, in the order every pair was weighed, and skips the body-line solve for pairs further apart than both bodies and CLEARANCE; a turn weighs only neighbours within TURN_LIMIT (CLEARANCE + 0.01: the answer is provably the one the exact gaps give), builds no footprint when nobody is that near (turn_is_free) or the step cannot move her nose a millimetre (turn_too_small, within turn_allowed's own 1 mm slack), and a held turn's long way round reuses the gap it already has; a RumpBounce at rest sleeps until kicked (it stepped to exactly where it was, 108 times a frame). After: pony tick 5.3 to 5.5 ms, solve 2.5 to 2.6, turns 1.1 to 1.2, idle pass 2.7 to 2.9. Tests pin each one against the pair rules on random herds. PERF_OK is still not reachable on the invisible display: the main thread now waits 10.7 ms a frame on the render thread (8.2 to 8.6 before), so the time saved went to waiting; with pony physics off entirely the check still reads p99 32 ms, and an empty scene at 1920x1080 there costs 6.8 ms a frame (the software presentation path). PERF_SPLIT's process_ms and physics_ms are Godot's per-second maxima of whole steps (the idle one includes that wait), not per-frame script time; the scripts are 6.4 to 8.3 ms a tick. perf.gd gained --window=WxH: at 960x540, where the threads show, average 15.1 to 16.0 -> 14.3 to 14.9 ms and p99 32.5 to 33.1 -> 28.4 to 32.5.
- **Running single GUT files: use the suite's flags (2026-11-07).** `--render-thread safe` (tools/run_tests.sh) is required; without it a direct launch throws engine "material/m is null" errors that read as flaky failures. Several "pre-existing flakes" earlier this day were that, not the code.
- **G18: a scripted run never writes the player's saves (2026-11-07).** The PS13 gate check found slot 9 and five logs in the owner's game folder written by this sweep's launches (GUT files run by hand without FILLY_TEST_SAVE_DIR, probes without --log-file). The owner's slot 0 and settings were untouched; older logs of their play were rotated out by Godot's five-log limit and are gone. A brief rule had already failed once (2026-10-24), so it is now a mechanism: a process started with `-s` that names no save directory saves to user://automated_saves (SaveIO.resolve_save_dir). Logs still depend on --log-file on every launch.
- **The GUT boot warning is the test tool's, not the game's (2026-11-07).** Every GUT run prints "SCRIPT ERROR: Trying to assign value of type 'Nil' to a variable of type 'bool'" at gut_loader.gd:35: the addon reads the project setting debug/gdscript/warnings/exclude_addons, which this Godot version doesn't define, into a bool. It runs only when GUT loads, never in the game or the exports, and changes no result; the vendored addon is left as it is rather than patched, so it can be updated cleanly. Not a ledger row.
