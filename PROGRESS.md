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

## Next (M3)
- Factory path: ranks, Calm Lamp, Express Chute, Yield Lens, Lure Post, the town fading, the Jubilee climax.
- Rescue path: Heat, corral raids, pylons, Dye Vat, Lantern Line, allies, Clover, the Lights Out climax, Placement.
- Epilogues and credits for all five endings; the headless playthrough driver for each.

## Known issues
- **Factory interior:** still monochrome grey-white; the ring light should read stronger in colour.
- **Apple trees:** the apples sit mostly inside the canopy.
- **Distance fog:** it washes the rim hills pale.
- **Building plinths:** still read as boxes under some houses.
- **Headless runs:** they skip the toon shader swap (a dummy renderer limitation).
