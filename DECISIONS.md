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
