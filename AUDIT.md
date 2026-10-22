# Audit

Branch `v1-overhaul` at e459813, 2026-10-22. Method: full code and data read (two read-only audit passes plus direct checks of the converted .glb files), the test suite run as a baseline, and the owner's two prior playtests (2026-08-31, 2026-09-04) as the record of what a person actually experienced. Detailed working notes: `scratchpad/audit-ponies.md`, `scratchpad/audit-systems.md` (gitignored).

---

## 1. What the game currently is

A third-person Godot 4.5.2 (Forward+) ranching game. Title screen, then character creation (name, swatches, a hand-drawn cutie mark), then one 220 m heightfield map:

- **Capture:** hold the magic beam on a wild pony, reel her in against her struggle, release into the saddlebag (`actors/player/magic_beam.gd`, 1851 lines). This is the vacpack analogue and the best-built verb in the game.
- **Ranch:** buy plots, build pens, pen ponies. Penned ponies get hungry and happy and produce gems into a tray (`world/pen.gd`, `systems/needs.gd`, `systems/production.gd`). Green/red placement ghost for plots.
- **Economy:** sell gems at the Market for bits. Bits buy food, saddlebag upgrades and permits for four fenced regions (orchard, lake, night meadow, everfree) plus the free Strip.
- **World clock:** 20-minute cycle, four phases, four weathers, seeded; ponies keep hours and weathers (`systems/world_state.gd`, `world/sky_rig.gd`).
- **Meta:** Request Board (three standing favours), Compendium (45 canon-named ponies, UNSEEN/SEEN/CAUGHT).
- **The Company:** a Ledger with a 25,000-bit sponsorship balance, collection day every three cycles, a pony quota, four collector punishments, and a Depot crate where penned ponies are delivered for credit.
- **Mail:** 15 authored letters (`data/story/`), a mailbox, a Mail page. The Survey/Requisition beat is the one scripted story event.
- **Casino (Spectra Palace on the Strip):** slots, wheel, blackjack and racing (your own pony is the bet), all with published honest edges and drawn UIs.
- **Saves:** atomic JSON slots, versioned, isolated in automated runs.

**The story stops at chapter two.** `systems/story.gd` declares CONTACT, COMPANY and RESISTANCE and states they are unreachable. There are no NPCs who talk (the shop attendants are silent shells), no fork, no paths, no Factory, no endings.

---

## 2. What works

- **The capture verb.** Hold, reel, struggle, escape timer, release-to-bag. Personality- and rarity-keyed difficulty. This is the foundation of the game and it is sound.
- **The pure-logic systems.** Economy, needs, production, ledger, collectors, casino maths, world clock, spawner, request board: RefCounted classes with unit tests, data in `.tres`. They can be carried forward nearly untouched.
- **Save safety.** Atomic writes, version stamps, `FILLY_TEST_SAVE_DIR` isolation proven by `tools/prove_save_safety.sh`.
- **Casino presentation.** The one part the owner praised. Drawn reels, wheel, cards and form guide.
- **Racing.** The owner's standout from the first playtest.
- **The Company's voice.** The HR-poster letters (the Survey above all) are genuinely good dark comedy and are the right register to grow from.
- **Test and CI discipline.** 108 test files, 1647 GUT tests, a parse sweep, three guards against false greens, 25 gate scenes, CI exporting Linux and Windows. Typed GDScript at about 97% of functions.
- **Autoload discipline.** Four autoloads, all true globals (AudioSafety, GameState, InputDevice, Sound).

---

## 3. What is broken or below bar

- **Art does not hang together, and ponies are not show-shaded.** There is exactly one shader in the project (`world/terrain.gdshader`). Ponies render with their imported StandardMaterial3D: lit PBR, no cel bands, no outlines, no eye shader. Props are PonySFM ports with their own PBR materials, plus some Kenney low-poly leftovers. The owner's 2026-09-04 verdict ("the clashing asset style looks terrible") is structurally unfixed: R2 swapped models but did not unify shading.
- **ACES tonemapping** (`tonemap mode 3` in `world/ranch.tscn`) desaturates the highlights, which fights the show's flat saturated colours.
- **Stock tinting is fragile.** `systems/stock_tint.gd` matches exact material names (`body`, `wings`, `hair`, `tail`, `eyeball_l`, `eyeball_r`). Of the 38 SFM models, many name their hair `hairfront`/`hairback`/`hair_core`/`ManeTop`/`Hair`/`Tail`, so only a hand-picked pool of four tints correctly. A coat tint drops the body texture, which also drops any cutie mark. The eye tint multiplies the baked iris, which goes muddy.
- **Penning, the tail, the creation camera.** R3 claims fixes. The code supports them, but none has been verified by a person since the 2026-09-04 playtest.
- **Menus.** Mouse and keyboard now work everywhere (R1), but outside the casino the look is still text rows with a caret, which is the "cheap GUI" verdict the owner gave.

---

## 4. What is missing

Against the v1 brief:

| Area | Missing |
|---|---|
| Story | NPCs, talk box, foreshadowing beyond letters, the reveal set piece, the choice, both paths, the Factory, every ending. The cast is canon (see section 6), which the brief bans. |
| Animation | Every pony has exactly three clips: `idle`, `walk`, `gallop`. No trot, jump, graze or eat, sleep, sit, startle, fear or cower, happy hop, talk, nod, emotes, being-carried, horn cast or wing flap. No AnimationTree. No facial animation. |
| Look | Cel shading, outlines, eye shader, colour grading, a cozy-to-dread tone system. |
| Audio | **No music at all.** No reverb or ducking buses. No dread soundscape. |
| Settings | Graphics/quality (none), keybind remapping (none), controller settings (none). Settings today: three volumes, mouse sensitivity, invert look. |
| Onboarding | A toggleable hints card and a welcome letter. No guided first five minutes. |
| Controller | InputMap has some joypad events; menu gamepad navigation is unverified and largely untested. |
| Tests | No playthrough or ending-reachability scripts (no endings exist), no performance profile, no settings tests. |
| Docs | README.md, CREDITS.md, GDD.md, STORY.md, PLAN.md, PROGRESS.md. |

---

## 5. Pony assets inventory (core assets: kept, improved, never replaced)

### 5.1 Models
- **43 converted .glb** in `game/assets/converted/ponies/` (gitignored; regenerated by `tools/convert_roster.sh` from `tools/roster_manifest.txt`), one per canon `PonyData` in `game/data/ponies/`. Plus three hidden stock records (`data/hidden/stock_{shy,bold,curious}.tres`) that all point at `pokeypierce.glb`.
- **Tier a: 5 Blender-pack models** (CreatorOfPony/MythicSpeed): twilight, rainbowdash, fluttershy, applejack, rarity. Distinct CON_/DEF_/IK_ rigs (126 to 165 bones), flat material colours, `Base_*` material names, 155k to 170k triangles (applejack 37k), cutie marks baked into large images. Not tintable.
- **Tier c: 38 SFM ReVAmped models** (`assets_raw/sfm/.../reVAmped_ponies/*.mdl` via SourceIO): 37k to 99k triangles (typically 52k to 72k), 79 to 122 bones. Textures: body 2048 plus normal map; hair, tail, horn and pupils 1024; teeth and tongue 32.
- **Shared SFM material vocabulary** (verified across all 38): `body`, `eyebrow`, `eyeball_l`, `eyeball_r`, `teeth`, `eyelashes`, `tongue`, optional `horn` and `wings`. Only the hair and tail names vary: `hair`, `hair_core`, `hairfront`/`hairback`, `hairbackupper`/`hairbacklower`, `ManeTop`/`ManeSide`, `Hair`, `SS_HairR`/`SS_HairY`, `hair_straight`, `tail`, `Tail`, `tail_core`, `tail_straight`. Odd parts: `hair_clip` (cocopommel), `clothes` (kerfuffle).
- **Body types, inferred from materials** (not stored as data anywhere):
  - Unicorn (10 SFM): lyra, minuette, nightlight, pokeypierce, shiningarmor, starlightglimmer, sunsetshimmer, sweetiebelle, trixie, vinylscratch.
  - Pegasus (9 SFM): cloudchaser, derpyhooves, flitter, kerfuffle, lightningdust, mane_allgood, scootaloo, soarin, spitfire.
  - Earth (19 SFM): the rest.
  - Tier a: alicorn twilight, unicorn rarity, pegasi rainbowdash and fluttershy, earth applejack.
- **Unconverted in assets_raw:** changelingdrone, raricow, songbirdserenade, plus SFM duplicates of the tier-a five.

### 5.2 Rigs
- **Two rig families.** Tier a has per-pack rigs with separate hair-physics armatures. Tier c shares one Source 70-bone core skeleton with identical rest positions; hair, tail, wing and accessory chains differ per model.
- `tools/sfm_rig.py` grafts synthetic CON_Root, CON_Belly, DEF_Head and four IK hoof targets onto SFM rigs so one authoring script (`tools/author_anims.py`) serves both families.
- **Hair and tail** are runtime spring bones: `scripts/pony_rig.gd` attaches a SpringBoneSimulator3D, finds chains by name pattern, and pins stiffness by speed (R3). Known gaps (`docs/notes-hair-sim.md`): no collision (hair passes through the neck and wings), one-bone locks on some chains.

### 5.3 Animations
- **Three clips, every model:** `idle` (2 s bob and head nod), `walk` (clip speed 0.66 m/s), `gallop` (3.3 m/s). They are authored procedurally in Blender by keying only the belly, the head and four hoof IK targets.
- **Playback** is a bare `AnimationPlayer.play` (`actors/pony/pony.gd:1218`; `actors/player/player.gd`), with gait chosen in `systems/gait.gd`.
- **AI states reuse those clips.** IDLE, WANDER, GRAZE, FLEE, APPROACH, HELD and LEAVING all map onto the three: GRAZE plays idle, HELD plays idle.
- **The authoring path for new clips exists and works:** `author_anims.py` with the IK handles on both rig families. That is how the missing set gets made.

### 5.4 Materials and shaders
- No pony shader. Imported StandardMaterial3D per surface; StockTint overrides coat, mane and eyes with flat-colour duplicates.
- Tier-a models carry a `Base_Outline` material (an inverted-hull mesh from their original Blender setup). It is not a Godot outline shader.
- Eyebrows, eyelashes and horn are never tinted, so a recoloured unicorn keeps the donor's horn colour.

### 5.5 Character customizer
- `ui/creation_screen.gd` (880 lines) plus `creation_backdrop.gd`. Two steps: LOOK, then MARK.
- **LOOK:** a name of up to 16 characters, coat (16 swatches), mane-and-tail as one colour (16), eyes (10), and mane style ("Style N of 4").
- **MARK:** a 64x64 drawn cutie mark (`mark_canvas.gd`, `mark_paint.gd`, `mark_stamps.gd`) with stamps, inks, tools and undo, applied as two Decals on a pelvis BoneAttachment (`systems/cutie_mark.gd`).
- **Not offered:** body type (the player is always a unicorn), tail style separate from mane, a secondary mane colour, horn and wing colour, size or age, accessories, markings or socks, eyebrow and eyelash colour.
- **Saved as** `PlayerLook`: name, palette indices, mane style index, and the mark as a base64 PNG.

### 5.6 Random pony generator
- `StockPalette.draw_look(rng)` returns palette indices `{coat, mane, eyes, mane_style}`. The palette (`data/stock_palette.tres`) has 8 coats, 8 manes and 6 eye colours.
- **The mane-style pool** (`StockPalette.MANE_STYLES`) is 4 whole donor models: pokeypierce, vinylscratch, shiningarmor and nightlight, **all unicorns**. So every stock pony and the player are unicorns from one of four heads.
- `world/spawner.gd` stands stock ponies per region budget. Personality is one of three hidden records.
- **The generator stops at looks.** No names, no cutie marks, no traits beyond shy, bold or curious, no age. Stock ponies are "Pony", uncollectable, with no Compendium entry.
- **Saved as** `PonyInstance.stock` indices, which wrap with posmod, so reordering the palette restyles saves.

### 5.7 What the customizer and generator need
1. A role matcher that normalises hair and tail names by pattern, making all 38 SFM bodies tintable. That takes the donor pool from 4 unicorns to 38 bodies across earth, pegasus and unicorn.
2. Tint horn, wings, brows and lashes coherently with coat and mane.
3. A replace-not-multiply iris shader.
4. A real appearance record (body donor, colours, two-tone mane, a generated cutie mark) so generated ponies are people: names, marks, personality traits.
5. A palette authored for show-plausible harmonies.
6. A filter that keeps the most recognisable canon signatures (applejack's hat, kerfuffle's clothes, the clip, derpy's eyes, sunset's two-tone mane) out of the generated pool.
7. Body type as a customizer choice. That needs the per-race verbs decision (see DECISIONS.md once made).

---

## 6. The canon problem

The brief requires every story character to be an original OC, and every NPC, worker and rescuable pony to come from the generator. Today the collectible roster is 43 canon characters, the Company "processes" them, and the default player name is "Twilight". The fan-RVC Twilight voice clip is a canon character's voice.

**Feasibility is good.** Canon identity lives in data (ids and names) and in textures (painted marks, signature colours), not in the SFM body template. A coat tint already strips the painted mark. The tier-a five are the most recognisable and the least compatible meshes; they are candidates for retirement from the in-game pool (kept on disk as assets), with that decision logged.

---

## 7. Licences

- **Cleared:** Kenney (CC0).
- **Not cleared for redistribution:** 32 of the 46 sound rows come from the BBC Sound Effects archive (RemArc licence: personal, educational and research use). These must be replaced with CC0 or equivalent for v1. The fan-RVC Twilight clip goes too (canon voice, unclear model licence).
- **Fan assets, kept by the owner's rule:** the pony models (CreatorOfPony, ReVAmped SFM) and the PonySFM prop ports. Fan works of Hasbro IP with no recorded licence. They are kept, because the pony models are core assets by mandate and the props are the restyle base the owner asked for. CREDITS.md must record their provenance and their non-commercial fan status honestly.
- **No CREDITS.md or README.md exists.**

---

## 8. Tech debt

- **`world/ranch.gd` is 7,063 lines, 223 functions.** `_ready` is 374 lines, and `_report` (line 4678) is 1,101 lines of gate assertions living in the production script. Every new system so far has been glued in here. New v1 systems will not be: they go in their own scenes and scripts, and ranch.gd sheds responsibilities as they are touched.
- **No event bus.** Coupling is by injected providers and `bind_*` calls from ranch.gd. Consistent and test-friendly, but it centralises everything in the god object. An `Events` autoload for story and tone signals is justified (the brief lists events as a true global).
- **Engine is two minors behind** (4.5.2 vs 4.7.2).
- **Assets are not in git.** `game/assets/converted/`, `assets_raw/` and `assets-inbox/` are gitignored, so a fresh clone cannot build the real game. Acceptable for a private project, but README.md must say so and say how to regenerate.
- **Comment density is extreme** (about one third of lines). It costs reading time, but it records why things are the way they are. New code matches a lighter house density.
- **Settings UI is duplicated** between the title screen and the pause menu.
- **Convention drift:** `scripts/pony_rig.gd` sits outside `actors/`.

---

## 9. Is it fun right now? (honest)

**Yes, in places:**
- The beam catch has real tension.
- The pen-gem-sell loop works.
- Permits give a sense of the map opening.
- Racing your own pony is a genuine toy.
- The casino games are polished.
- The letters are funny.

**No, as a whole, and the reasons are specific:**
1. **The first hour has no people.** Nobody talks. There is nothing to discover but the next permit, and no music. Cozy needs company, and the game has none.
2. **The twist cannot land.** The story stops before it starts, and it lives only in letters a player can skip.
3. **It does not look like the show.** Lit-PBR ponies and props from mixed sources read as a mod, not as Equestria. The owner's eye caught this immediately.
4. **Ponies are mannequins.** Three clips, no reactions, no faces. Slime Rancher's charm is that slimes emote constantly; here a pony being beamed, penned, fed or delivered plays the same idle.
5. **Feedback is thin outside the beam.** Selling, buying, feeding and producing lack layered feel (particles, squash, rising-pitch sound).
6. **No onboarding, so the systems are opaque.** The owner's own playtests asked how bits are earned.

**The verdict that shapes the plan:** the logic layer is a strong foundation, and the presentation, characters and story layers are where v1 is won or lost. Keep the systems, rebuild the look around one shared toon shader, give the ponies bodies and faces, put people in the world, and build the story the brief asks for on top of the Company machinery that already exists.
