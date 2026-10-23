# Game Design Document

**Filly Rancher** (v1). Godot 4, Forward+, Linux and Windows. Single player, third person. Story: STORY.md. Research behind the rules here: RESEARCH.md. What exists today: AUDIT.md.

---

## 1. Pitch

Slime Rancher's catch-pen-feed-sell joy, in a show-accurate pastel pony valley, with a town full of neighbors and a filly who follows you everywhere. Every wild pony you care for can Bloom and earn her cutie mark. The company that pays you to send the others "up for Placement" is turning them into the rainbow in the sky. When you find out, you choose: keep working for the Factory (richer, smoother, grayer) or turn everything you have learned into a rescue operation (harder, poorer, right).

---

## 2. Design pillars

Every feature serves at least one of these, or it is cut.

1. **Every catch is a little joy.** The Scoop, the ponies' reactions, and the feedback on every action are tactile, layered and immediate. A muted, ten-second clip of catching a pony should make someone smile.
2. **A valley worth caring about.** Show-accurate cel look, ponies with faces that react, neighbors who talk, and a companion who loves you. The first hour is a complete, cozy game.
3. **The same world, seen twice.** Every clue is in plain sight in play, people and places. The tone shift is one dial (`dread`) driving light, color, fog, music and sound together. A replay is a different game.
4. **Choices made with your hooves.** Morality lives in systems, not dialog boxes: who you deliver, who you Bloom, what you build. Both paths are mechanically distinct and fun, and the endings count what you did.
5. **Small and finished.** One valley, one factory, a handful of people, deeply polished. No placeholder survives to v1.

---

## 3. Core loop

### 30 seconds
Spot a Drifter (Tumble points), sneak close, Scoop her (aim, hold, tug against her struggle, pop into the bag), scoop up a dropped gem or a fruit, look for the next one.

*Feel:* the pony stretches toward the nozzle and squeaks (cartoon, not horse), the bag counter bounces, the beam's pitch rises as she nears.

### 5 minutes
Bag full: head home, pen her, toss her favorite food, collect the gem tray, sell gems to Bramble, buy food or an upgrade, check the board, and with luck watch a pony Bloom.

### 1 hour
Open a new region (permit), meet the townsfolk and push their requests along, survive a collection day (meet the quota, or not), find a rare Drifter, raise a few Blooms, try the casino, and hit a story beat.

### After the reveal
- **Factory 30 s / 5 min / 1 h:** lure, Lens-check, Scoop; Express Chute and contracts; rank up toward the Jubilee.
- **Rescue 30 s / 5 min / 1 h:** sneak and raid; Bloom against Heat, dye, send down the Lantern Line; cut a pylon, recruit an ally, push toward Lights Out.

---

## 4. Systems

Each system: what it does, the pillar it serves, how it connects. Bold names are new or substantially rebuilt for v1; the rest exist and are kept (see AUDIT.md).

### 4.1 Player and Scoop (pillar 1)
- Third-person movement with acceleration curves, coyote time (0.1 s), jump buffer (0.1 s) and a short hop.
- The player picks a body in the customizer (earth, pegasus or unicorn). Wings are cosmetic. A unicorn's horn glows while she Scoops.
- **The Scoop:** a Cloudsdale-issued lantern device strapped to the player's side, replacing horn magic so every body type works. Same capture logic as today's beam (hold, reel, struggle, escape timer, release to bag). Rebuilt feel: stretch toward the nozzle, a squash on the pop, rising pitch, and a short hit pause on rare catches.
- **The Sparkle gauge** (relabelled "Spectral yield" after the reveal) reads the pony's coat vividness times her happiness.
- **Launch:** fire bagged food or ponies out of the Scoop to toss them into pens.
- *Connects to:* bag storage, pens, corral raids, pylon cutting.

### 4.2 Ponies (pillars 1 and 2)
- **Generated looks.** Every pony in the game is produced by the generator (section 4.3): wild Drifters, townsfolk, story characters (fixed seeds plus overrides), Collectors and stewards.
- **AI states:** idle, wander, graze, sleep (night), flee, approach (curious), held, penned behaviors (eat, play, nuzzle a friend), and a Bloom ceremony.
- **Personality:** shy, bold, curious and lazy. Plus a liked food and a liked companion trait.
- **Expression:** blink, ear flicks, head-track the player within 6 m, brow and mouth poses per mood. Squash on landing, hop when happy, flinch when startled.
- **Bloom meter:** fed favorite food, a friend in the pen, and a toy or race raise it; hunger, crowding and Calm Lamps stop it. Full meter: Bloom ceremony, a generated name and mark, a talent, and better gems. Marked ponies cannot be delivered or collected.
- **Rare Drifters:** pearl, starry-mane and two-tone variants under specific conditions (dawn fog on the lake, a storm in the Thornwood, the night meadow at midnight). Variable reward for collection.

### 4.3 Customizer and random generator (pillar 2; core assets)
- **Donor bodies:** the 38 SFM models, made tintable by a pattern-based role matcher (hair, mane and tail names normalised). Horn and wing meshes are shown or hidden to set the race:
  - any donor can be an earth pony;
  - unicorn donors (10) can be unicorns;
  - pegasus donors (9) can be pegasi.
- The 5 tier-a models are excluded from the generated pool: they are the most recognisable canon meshes and are not tintable. They stay on disk as core assets and reference for the art standard.
- **Recognisable canon signatures are filtered out.** The hat, the clip and the clothes meshes are hidden; signature two-tone hair is tinted one or two tones from a generated palette.
- **PonyLook** record:
  - race and donor;
  - coat, mane primary and mane secondary (for two-tone donors), tail, and eye iris;
  - horn and wing colors derived from the coat;
  - optional socks/blaze marking (shader);
  - size (adult, or foal at 0.78 scale);
  - mark (a generated mark descriptor, or a player-drawn PNG).
- **Palette:** show-plausible harmonies (pastel coat with a saturated mane, and complementary or analogous rules), authored in a `.tres`.
- **Names:** generated from a two-part word table ("Peach" + "Sunrise", "Clover" + "Dash").
- **Marks:** generated from a talent (24 talents, each with 2 to 3 stamp motifs) composited from the existing stamp set and colors.
- **Customizer screen (player):** all of the above, a big turntable preview with good lighting, randomize, and the drawn-mark step. Reused, re-skinned, for the Rescue path's Dye Vat.
- *Tests:* determinism by seed, every donor tints every role, no canon signature visible, save round-trip.

### 4.4 Ranch, pens, food, gems (pillars 1 and 2)
- **Kept:** plots, pens, needs, production, the gem tray and the placement ghost.
- **Food:** five foods grown or bought. Favorite food doubles the Bloom gain.
- **Feedback:** gem pop with a sparkle, the tray bounce, and gems flying to the counter on collect.
- **Pen companions:** two ponies with matching traits gain Bloom faster. That is the light "mixing" decision.

### 4.5 Market and economy (pillar 1)
- **Kept:** gems sell for bits; daily price drift per gem tier (one recurring decision).
- **Targets:**
  - first purchase by minute 10;
  - the time to the next purchase stays at 5 to 10 minutes through Act Two;
  - Factory path income runs at about 2x the Rescue path's.
- **Rainbow Dye** shades are named from the delivery log (clue 5).

### 4.6 Ledger, Depot, Collectors (pillars 3 and 4)
- **Kept:** sponsorship balance, collection days every three cycles, quota, collector ladder, Depot delivery by the departure path.
- **Retuned:** the Act One quota is gentle (two, then three), so collection day is a light Papers-Please beat rather than a threat.
- **Added:**
  - the delivery feedback VFX (a coat-colored sparkle flying to the rainbow);
  - the rainbow brightness counter;
  - Bloomed ponies refused at the Depot;
  - postcards;
  - Collectors who check flanks.

### 4.7 Story, flags, tallies, dread (pillar 3)
- **Story state:** act, flags, path (`NONE`, `FACTORY`, `RESCUE`), the tallies (`delivered`, `rescued`, `allies`, `clover`, `heat`, `rank`), and the endings seen.
- **Beats** are data (`StoryBeat` resources): trigger kinds the game emits (a delivery, a bloom, a day passing, a talk, an area entered, a flag set), with effects (send a letter, set a flag, spawn an event, change a shop).
- **Dread scalar** (0 to 1): a pure function of act, path and tallies. Read by WorldTone (grading, fog, lights), Music (layers), Ambience (beds), and the town population.
- **Events autoload:** story and tone signals (`delivered`, `bloomed`, `day_passed`, `dread_changed`, `flag_set`), so the new systems do not route through ranch.gd.

### 4.8 People: NPCs, talk, companion (pillar 2)
- **NPCs:** Marigold, Fennel, Pip, Bramble and Static, plus 8 to 12 generated townsfolk with one-line barks.
- **Talk box:** a portrait-free speech bubble in world space, anchored to the speaker's head. A line at a time, babble voice, at most two choices, lines keyed by act, path and flags. The speaker turns to face you, with ear and brow poses per line mood.
- **Babble voice:** per-character pitch and timbre, syllable-synced to the text reveal and the jaw bone. Original, cartoon, and never horse sounds. Real voice lines can replace babble later through the same hook.
- **Tumble (companion):** follows at 2 to 4 m, points at Drifters within 25 m (sparkle marker), cheers Blooms, refuses the Depot (and the Works lift until the reveal), and reacts to the path afterward.

### 4.9 Factory path systems (pillar 4)
- **Contracts** on the board, ranks, and the Supply Desk.
- **Calm Lamp:** a pen upgrade that sets mood to fixed, stops fleeing, stops Bloom, and stops emotes.
- **Express Chute:** auto-delivers at dawn.
- **Yield Lens:** a grade overlay on the HUD reticle.
- **Lure Post:** spawns a night herd.
- **World response:** dread climbs per delivery; the town fades; Bramble becomes a franchise.

### 4.10 Rescue path systems (pillar 4)
- **Heat** (0 to 100): driven by missed quotas, sightings and raids; reduced by pylon cuts, dyes and time. Thresholds trigger Collector visits:
  - a fine at 30;
  - a padlocked pen at 55;
  - an unmarked pony taken at 80;
  - the Placement ending at a sustained 100.
- **Intake Corrals:** one per region; a night raid past patrols with light cones (shared stealth component).
- **Pylons:** four, one per outer region; a night beam-hold cut (12 s with a struggle).
- **Dye Vat:** the customizer applied to a rescued pony; it re-rolls her registry id.
- **Lantern Line:** a gate in the Thornwood; send marked ponies at night.
- **Allies:**
  - Pip: she warns of Collector visits a day ahead.
  - Bramble: her cellar shelters pens and hides ponies.
  - Fennel: he gives you more pen space. Clover can be rescued only if he has been recruited.

### 4.11 The Works (pillars 3 and 4)
- A separate interior scene with three uses: the reveal, the Factory Jubilee and the Rescue climax. One geometry, three scripts and three grades.
- Rooms in order:
  1. lift landing;
  2. Welcome Hall;
  3. Classroom;
  4. Gift Shop;
  5. service walkway (stealth);
  6. the window gallery above the processing floor;
  7. long-term holding;
  8. control room with the lever.

### 4.12 Casino (kept; pillar 1)
- Kept as built: slots, wheel, blackjack and racing, honest edges. Restyled into the show look.
- **Racing** feeds the Bloom meter for the racer (a talent for speed).
- **Factory path:** comps. **Rescue path:** banned above Heat 70.

### 4.13 Endings (pillar 4)
- The ending selector is a pure function of the story state, unit tested.
- **Epilogue scene:** an in-engine camera move, the final grade, and a closing letter. Then the credits roll, then the post-game.

### 4.14 Interconnection map

```
Scoop --> bag --> pen --> needs --> gems --> market --> bits --> upgrades/permits
             \                 \--> Bloom --> mark/name --> (Depot refuses) --> protection
              \--> Depot --> ledger credit --> rainbow brighter --> dread --> grade/music/town
Story <-- Events <-- (delivered, bloomed, day, talk, area, flag)
Story --> letters, board, shop stock, NPC lines, Works events, path systems, endings
Heat <--> Collectors <--> pens  (Rescue)        Contracts --> ranks --> gear (Factory)
```

---

## 5. How the two paths change gameplay

| | Factory | Rescue |
|---|---|---|
| Money | Stipend doubled, upkeep waived, contract bonuses | No stipend; upkeep rises with Heat; gems, races and Bramble's back room |
| Catching | Lures and Lens: easy and fast | Raids under patrols: tense, with stealth |
| Pens | Calm Lamps: quiet, efficient, no Bloom | Bloom races Heat; companions and food matter more |
| Delivery | Express Chute; the best money in the game | Lantern Line: no money, permanent rescues |
| Customizer | Unused | Dye Vat: hide ponies |
| World | Grays out; the town empties | Color returns region by region as pylons fall |
| Pressure | Contract deadlines (soft) | Heat and Collectors (hard) |
| Climax | Jubilee: pull the lever on stage | Lights Out: free the line, find Clover, pull the lever |

---

## 6. Progression curve

Target times for a first-time player. A scripted headless player verifies the first-ten-minutes row.

| Time | Milestone |
|---|---|
| 0:02 | First catch |
| 0:05 | First pen, first feed, first gem |
| 0:10 | First sale and first purchase |
| 0:20 | First Bloom |
| 0:25 | Depot explained; first collection day by about 0:40 |
| 0:45 | First permit (Orchard Hollow) |
| 1:00 | Casino open, second permit, first rare Drifter likely |
| 1:30 to 2:00 | Invitation, then Color Day (the reveal) |
| 2:00 to 3:30 | Path midgame: ranks or pylons |
| 3:30 to 4:30 | Climax and ending |

**Regions** (renamed from the current map to originals):
- Sunny Acres (the ranch, free);
- Ponyville town (free);
- Orchard Hollow (150);
- Mirror Lake (300);
- Moonpetal Meadow (700, night spawns);
- Thornwood (1,200, the Lantern Line);
- Glitter Row (the casino strip, free from day 2).

---

## 7. Content list (v1)

- **Map:** one valley, the existing heightfield reworked. Seven areas above, plus the Works interior.
- **Ponies:**
  - unlimited generated Drifters;
  - 3 rare variants per outer region;
  - 6 story characters;
  - 10 townsfolk;
  - Collectors and stewards.
- **Animations (both rig families, generated pool uses SFM):**
  - locomotion: idle (and 3 variants: look around, ear flick, tail swish), walk, trot, gallop, jump and land, turn;
  - ground actions: graze, sit, lie down, sleep;
  - reactions: startle, cower, happy hop, held (struggle);
  - talking: talk, nod, head shake;
  - emotes: sad, laugh, rear (Bloom);
  - face: blink and mouth flaps (bone-driven).
- **Story content:**
  - about 40 letters and postcards;
  - about 300 lines of NPC dialogue;
  - 18 clues;
  - 3 Works scripts;
  - 5 epilogues.
- **Props (new, Blender-built and show-styled):**
  - Cloudsdale gear: the Depot crate and chute, the cloud-lift and cart, a pylon, Calm Lamp, Lure Post and the Scoop;
  - Rescue gear: the Intake Corral, the Lantern Line gate and the Dye Vat;
  - mail: the postbox and postcards;
  - Works architecture: the cloud palace exterior and an interior kit.
- **Existing PonySFM and Kenney props** restyled with the toon shader.
- **Audio:**
  - cozy theme and region variations, Works theme, path themes, an ending theme;
  - layered dread stems;
  - CC0 replacements for every BBC sound;
  - babble voices.
- **UI:**
  - title and main menu, customizer, HUD, pause, settings (graphics, audio, controls with rebinding, controller);
  - talk box, letters, market, build, depot, casino;
  - endings and credits;
  - onboarding prompts.

---

## 8. Art direction

**Standard:** the existing pony models, show-shaded. Nothing on screen may look like it belongs to another game.

### 8.1 Shading
- **One toon shader family** for everything: ponies, props and terrain.
- Two-tone cel lighting (a hard step on N dot L with a very narrow smooth band), a shadow tone of base times a cool tint (0.72, 0.74, 0.92), and an optional stepped rim.
- **Inverted-hull outlines** on ponies and hero props, colored at albedo times 0.45 (saturation kept), with screen-constant width. Environment meshes get thinner outlines or none.
- **Eyes:** an iris-replacing shader (keeps the pupil and highlight from the texture; replaces the iris hue), and a bright specular dot.
- **Imported PBR materials** are converted at load: albedo color and texture kept, roughness and metallic ignored.

### 8.2 Palettes
| Tone | Sky | Grass | Shadows | Accent | Grade |
|---|---|---|---|---|---|
| Cozy (dread 0) | #8FD3FF top, #E6F6FF horizon | #7CCB5B with #5FAE48 patches | cool lavender tint | rainbow, cottage reds, cream | saturation 1.15, contrast 1.0, warm sun #FFF4DD |
| Unease (0.3) | paler, slight green cast | #8CBF6A | grayer | rainbow over-bright | saturation 0.95, light haze |
| Dread (0.8+) | #6F7680 to #A9A08A | #6E7F5E | teal-gray | only the spectrum stays saturated | saturation 0.55, contrast 1.15, low fog, vignette, sun #E8C98A |
| Free (Rescue end) | true dawn gradient #FFB38A to #7FC8FF | #86D25E | warm | no rainbow; real sunrise | saturation 1.2 |

### 8.3 Lighting and post-processing
- A warm directional sun with a high sky ambient.
- **Tonemap Filmic or AgX at low contrast** (not ACES, which crushes the flat colors). SSAO off or very low in cozy scenes.
- Glow is subtle, for the rainbow and magic only.
- **Volumetric fog** carries dread.

### 8.4 Environment and UI style
- **Environment:** rounded, chunky shapes and soft blob trees, as the show's backgrounds are. Background detail stays lower than character detail.
- **UI:** show-style rounded panels with a cream fill, a thick colored outline, a bubbly rounded display font, and icons over text. Every menu is visual-first, the casino's drawn style is the bar, and nothing is ever just text rows.

---

## 9. Audio direction

- **Music** (sourced CC0 or CC-BY, logged in CREDITS.md): a gentle acoustic and woodwind cozy theme with day, night and town variations. A layered build (four stems) lets dread remove the warm layers and add a drone. A music-box Works theme; a pulsing stealth layer; ending themes.
- **Ambience:** meadow, town and night beds, each with a dread variant (wind replaces birds).
- **SFX:** every action layered and pitch-varied.
  - The Scoop has hum, tug, pop and launch sounds.
  - Gem pickups climb in pitch over a streak.
  - Coins cha-ching.
  - The Bloom fanfare is a short chord swell.
  - Hoofsteps per surface.
  - UI ticks are soft.
- **Voices:** syllable babble per character; ponies chirp and giggle in cartoon style. **Never realistic horse vocalisations** (the one sanctioned exception, the rare capture neigh gag, may stay).
- **Mix:** ambience sits under SFX; there is a ducking bus for dialogue; the music bus has a dread low-pass.

---

## 10. UI and UX flow

```
Boot --> Title (New / Continue / Load / Settings / Credits / Quit)
New --> Customizer (body, colors, mane & tail, eyes, mark, name) --> Arrival (cart ride) --> Sunny Acres
In game: HUD (bag, bits, gems, objective chip, Tumble ping, contextual prompt)
  Esc/Start --> Pause (Resume, Map, Journal [requests, letters, pony book], Settings, Save, Load, Quit to title)
  World interactions open themed panels: Market, Build, Depot, Talk box, Letter, Casino tables
Story --> Works scene --> back to the valley; ending --> Epilogue --> Credits --> post-game
```

- **Onboarding:** contextual prompts only, shown once, dismissed after the action is done twice. Tumble and Fennel teach by doing; no text walls.
- **Input:** mouse and keyboard, and controller, everywhere; full rebinding; device-aware prompt glyphs.
- **Settings:**
  - **graphics:** quality preset (Low, Medium, High, Ultra), resolution scale, FSR, window mode, vsync, shadows, SSAO, glow, fog, outlines, max FPS;
  - **audio:** master, music, ambience, effects, voices and UI;
  - **controls:** sensitivity, invert, rebinding, controller deadzone;
  - **accessibility:** screen shake, text speed, and a colorblind-friendly gauge.

---

## 11. Scope

### In v1
Everything above.

### Cut (and why)
- **Fusion:** off-pillar; Bloom carries the long-term reward.
- **Flight and pegasus or earth capture styles:** the Scoop makes them unnecessary, and wings stay cosmetic.
- **Seasons:** the day cycle and story acts carry the time.
- **Multiplayer:** off-pillar.
- **Voice acting:** babble beats bad TTS. The hook stays for real lines.
- **Canon characters stay** (owner direction, 2026-10-22): the 43-character roster are rare named finds, as themselves.
- **The Compendium of named characters stays**, joined by the **Pony Book** (every Bloomed pony, the talents and rare variants discovered).
- **A second map:** the Works is an interior scene.

### Kept from the existing build
Capture logic, ledger and collectors, casino, racing, needs and production, saves, the world clock, the request board, the mark canvas, the tests.

### Engine
Upgrade to 4.7.2 (the latest stable) as the first milestone.
