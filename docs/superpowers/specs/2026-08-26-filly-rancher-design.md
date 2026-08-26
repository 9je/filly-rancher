# Filly Rancher — Game Design Spec

**Date:** 2026-08-26
**Status:** Approved design, pre-implementation
**Scope of this spec:** Full-game vision plus detailed requirements for Phase 0 and Phase 1. Later phases get their own specs when they begin.

## What this is

A 3D single-player collect-and-ranch game in the style of Slime Rancher, cast with My Little Pony (G4) canon characters. Personal project for two players (one on Pop!_OS, one on Windows) — not distributed, not sold. All character models, maps, voices, and music are sourced from community/fan repositories.

**Fantasy:** play as Twilight Sparkle, roam Equestria, capture canon ponies with a magic beam, keep them happy on your ranch, fuse them into absurd hybrids, complete the Ponypedia, and get rich(ish) at the racetrack.

**Pillars:**
1. **Collection first** — the goal is finding and logging as many canon characters as the asset pool allows.
2. **Economy with teeth** — bits fund everything; racing and fusion are gambles.
3. **Nopony suffers** — unhappy ponies escape, they never die. Fusion creates a new pony; parents survive.

## Decisions already made

| Topic | Decision |
|---|---|
| Players | Single-player only. Two separate installs (Linux + Windows), identical behavior. |
| Engine | Godot 4.5 stable, GDScript, Forward+ renderer. |
| Player character | Twilight Sparkle (third person). Full pony customization is a Phase 5+ feature. |
| Collectibles | Canon characters only, as many as sourceable. No generic breeds. |
| Breeding | Fusion: two ponies → new procedural hybrid (blended colors/parts, rarity roll). Parents unaffected. This is the gacha. |
| Gambling | Racing bets + fusion gacha in core phases; Las Pegasus casino zone deferred to Phase 5+. |
| Capture | Unicorn magic tractor-beam (player is Twilight, so v1 needs only this). Pegasus/earth-pony capture styles arrive with player customization. |
| World | Zone-gated scenes with loading transitions, not seamless. v1 targets Ranch + Ponyville. |
| Maps | Built on Godot-native terrain from sourced *props* (buildings, trees). Whole Source-engine map imports are out. |
| Voices | Pre-generated WAV voice banks per character. Pony Preservation Project community models first; paid service (e.g. ElevenLabs) as per-character fallback if quality disappoints. No runtime TTS. |
| Music | Show soundtrack OGGs per zone with a crossfade manager. User curates tracks. |
| Saves | Human-readable JSON per slot. Ponies are self-contained JSON blobs so the two players can trade by pasting files. |
| Asset sourcing | User downloads from sites (accounts/captchas/taste calls); Claude automates all conversion from the downloaded files onward. |

## Phase roadmap

Each phase is its own spec → plan → build cycle and ends with smoke-tested Linux + Windows exports.

- **Phase 0 — Asset pipeline proof** (this spec, detailed below)
- **Phase 1 — Core loop vertical slice** (this spec, detailed below)
- **Phase 2 — Collection & fusion:** Ponypedia log, fusion chamber, roster to ~15–20 characters.
- **Phase 3 — Ponyville & racing:** town hub with NPC shops, racetrack with pony entry + betting on NPC fields.
- **Phase 4 — Voices & polish:** batch voice generation, music zones, ambient audio, UI pass.
- **Phase 5+ (wishlist):** player pony customization with per-race capture mechanics (pegasus herding, earth-pony befriend/lasso), Everfree Forest, Crystal Empire, Cloudsdale, Las Pegasus casino, day/night-dependent spawns (bat ponies).

---

## Phase 0 — Asset pipeline proof

**Question answered:** can we reliably turn community pony assets into animated, playable Godot characters — and which sources are worth bulk-pulling?

### Deliverables
1. **Source priority verified.** Try in order: (a) native Blender packs (CreatorOfPony/MythicSpeed Mane 6), (b) Sketchfab glTF/FBX, (c) SFM/GMod `.mdl` via Crowbar decompile → Blender Source Tools → glTF. Record which tiers produce usable rigs.
2. **Three converted characters** — Twilight plus two others — standing in a Godot test scene with working materials.
3. **Animation strategy decided.** Test retargeting all models onto one canonical pony rig (shared animation set). Fallback: each model must ship its own idle/walk/run, which constrains the roster. Document the verdict.
4. **One animated pony** walking a path in Godot (idle + walk minimum).
5. **Conversion recipe** — a scripted, repeatable pipeline (headless Blender Python where possible) + a written checklist for the manual steps, committed as `docs/pipeline.md` and `tools/`.
6. **Map-asset probe:** source enough props (terrain textures, trees, 2–3 Ponyville-style buildings) to confirm the props-on-Godot-terrain approach for zones.
7. **One PPP voice line** generated for Twilight; judge quality; note the fallback decision.
8. **Shopping list** for the user: exactly which packs/models to download for Phase 1–2, from where.

### Exit criteria
A stranger (or a future Claude session) can follow `docs/pipeline.md` to take a downloaded model to an in-engine animated character without rediscovering anything.

## Phase 1 — Core loop vertical slice

**Milestone:** "it's a real game" — the full Slime-Rancher-shaped loop is playable start to finish on both platforms.

### Player
- Third-person Twilight: walk/trot/gallop, jump, camera orbit. Gamepad + keyboard/mouse.
- **Magic beam** (hold right-click): raycast tractor beam. Pulls loose items (food, produce) into saddlebag inventory; pulls wild ponies into a levitation hold → stored in limited **pony slots** (vac-tank equivalent). Release-to-deposit into pens or back into the world.

### Wild ponies
- Spawn tables per zone with rarity tiers (common/uncommon/rare/legendary).
- State-machine AI: wander → graze → react to player (flee or approach, per-character personality flag) → struggle timer in beam (escapes if held too long without capture).
- Phase 1 roster: 3–5 characters from Phase 0's pipeline.

### Ranch
- Fixed map with pre-placed **plot slots**; buy a plot, choose its building: **pen** (holds N ponies) or **garden** (grows a food type). Fusion chamber and race stable are later-phase plot types.
- Ponies have favorite foods. Fed + favorite → happiness up → faster production. Neglected → production stops → escape timer → pony leaves the pen (returns to the wild pool; recapturable).
- Ponies produce **gems** on a happiness-scaled timer; gems sell at the ranch market stall for **bits**.

### Economy
- Bits buy: plots, pen/garden upgrades, beam upgrades (range, pony-slot count), seeds. Sinks and faucets tuned so Phase 1 is beatable in a few hours of play.

### Saves
- JSON save slots: roster (each pony a self-contained blob: character id, nickname, happiness, stats, location), ranch plots, wallet, unlocks. Save at player house; autosave on quit.

### Data model
- Every character is a Godot resource: id, display name, model path, rarity, spawn zones, favorite foods, personality, race stats (speed/stamina/spirit — used from Phase 3), voice-bank path (used from Phase 4). Adding a character never requires code.

### Testing
- GUT headless tests: economy math, spawn-table draws, happiness/production timers, save/load round-trip.
- Manual playtest checklist per build; Linux + Windows export smoke test every phase.

## Out of scope (recorded so they stay out)
- Multiplayer/networking of any kind.
- Seamless open world; combat; pony death.
- Runtime AI voice generation.
- Importing whole Source-engine maps.
- Distribution/monetization of any kind — this stays a private two-person project.
