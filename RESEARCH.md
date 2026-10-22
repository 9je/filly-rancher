# Research

Concrete principles pulled for Filly Rancher v1. Each section ends with **Apply:** lines, which are the rules the GDD and the build are held to. Sources are the games themselves plus well-known public design talks and postmortems (cited by name where the idea comes from one).

---

## 1. What makes Slime Rancher work

**Core loop.** Vac (suck up) slimes and food in the wild, carry them home, put slimes in corrals, feed them, they produce plorts, sell plorts at the Plort Market, spend newbucks on ranch expansions and gear that let you go further out. Every step is a physical verb done with one tool (the vacpack). There is no menu between "I see a thing" and "I have the thing".

**Why the minute-to-minute feels good.**
- The vac is a continuous, physical verb: objects visibly stretch toward the nozzle, wobble, then pop into the tank with a fat "thwop". The catch is a little tug-of-war, never a menu.
- Slimes are expressive at all times: faces, bounces, a happy wiggle on eating, a little "plort" squash on producing. The world reacts to you constantly.
- Shooting things out of the vac is as satisfying as sucking them in. Both directions of the verb are toys.
- Feedback is layered: squash, sound with pitch variation, particles, a counter ticking up in the HUD.

**Cozy tone.** No death penalty worth mentioning (you lose some inventory), no timers that punish, soft pastel world, gentle music that changes by zone, a day/night cycle that changes mood but not rules much. Danger (tarrs, feral slimes) exists, is legible, and is self-inflicted (tarrs come from your own mismanagement of largos).

**Progression pacing.**
- The ranch is the progress bar you live in: every purchase is a physical object you walk past every day.
- Expansions are gated by money and by keys/doors in the world, so exploration and economy pull on each other.
- New zones arrive roughly every 30 to 60 minutes early on; each introduces 1 or 2 new slime types and one new hazard or mechanic, never more.
- The plort market fluctuates daily, so "what should I farm today" is a light, recurring decision.

**Discovery.** Hidden areas behind slime gates, treasure pods with blueprints, slime keys, and "gordo" giant slimes you feed to open paths. Ambient lore lives in the 7Zee rancher log entries and Beatrix's ranch-house notes, which you read if you want to.

**The emergent-problem layer.** Largos (two slime types combined) are more valuable and more dangerous. Mixing is the risk/reward toy: more money, more chance of a tarr outbreak. The system generates stories without a writer.

**Apply:**
- The beam must feel like the vacpack: continuous, physical, stretchy, with a pop on capture and a satisfying launch on release. No catch is ever a menu.
- Ponies must emote constantly (ear flicks, head turns toward the player, happy hops on feeding, a flinch when startled).
- One new mechanic or pony type per area unlock, never more.
- Every ranch purchase is a visible object in the world. No invisible stat upgrades without a model.
- A light daily market fluctuation gives a recurring decision.
- One risk/reward toy that generates emergent stories (our version: pen mood and mixing temperaments, see GDD).

---

## 2. Moral choice, complicity, and tone shifts

### Stardew Valley: Joja vs the Community Center
- Both paths are offered as **the same goal** (restore the town's services: bridge, minecarts, greenhouse) with a different **method**. The Community Center route needs you to gather bundles of items across seasons (slow, exploratory, uses every system). Joja route: pay money per project (fast, efficient, transactional).
- Joja is **tempting by design**: it is genuinely faster for a min-maxer, its store sells things cheaply, and the only cost is moral and social (the Community Center becomes a warehouse; Joja HQ appears).
- The choice is **soft and lagged**: you drift into it by buying a membership, there is no single dialog box with a "be evil" button. NPC reactions follow later.
- The town visibly changes based on the route (warehouse vs restored building, Morris's speech).

**Apply:** The Factory path must be measurably faster at money and progression (target: about 1.5 to 2x income), with real perks. The rescue path costs more but unlocks things money cannot (specific rescued ponies, NPC friendships, the good endings). The commitment should be lagged and partial: the player can lean one way then waver, which is what makes mixed endings meaningful.

### Undertale
- The game tracks what you did, not what you said. Mercy and violence are both mechanical (FIGHT vs ACT/SPARE), and the game remembers kills across saves.
- Characters react to your specific choices by name ("You killed X"). Specificity is what makes complicity land.
- Tone shift in the genocide route is mostly **absence**: empty rooms, music slowed down, NPCs gone, the save point text changing. The world gets quieter.

**Apply:** Track the specific ponies the player delivered (name, coat, the day). Reference them later by name and by appearance. Let the factory path's tone shift come from absence: fewer ponies in the town, emptier pens, slower and thinner music.

### Doki Doki Literature Club
- Commits fully to the cozy genre first: a long, competent, genuinely charming first act. The horror only works because the player believed the surface.
- Wrongness enters as small glitches before the break: a word misspelled, a sprite held a frame too long, a line that seems to address the player.
- The reveal reuses the familiar UI and assets, corrupted. The menu you trusted becomes the horror.

**Apply:** The cozy act must be a complete good game for at least the first 60 to 90 minutes. Foreshadowing uses the game's own familiar elements going slightly wrong (a receipt number that is off, a letter template that fills one field with the wrong data, a pony who stops in the same spot every time). The reveal reuses the familiar loop (the delivery crate) seen from the other side.

### Papers, Please
- Complicity through **routine**: you are a cog doing a job with a quota, and the job itself is the moral system. Every stamp is a small decision with immediate economic consequence for your family.
- Moral choices are framed as **economic pressure**, never "good button vs bad button". You can afford to be kind sometimes, not always.
- Information is presented through documents, so the player discovers by reading closely what the game never says out loud.

**Apply:** The quota and the ledger are the moral system, not a dialog choice. Rescue costs bits and safety the player can feel. Documents (receipts, statements) hide the truth in plain sight for the attentive player.

### Spec Ops: The Line
- Uses the genre's own conventions (shooter loop) to indict the player. Loading screen text changes over the game ("Do you feel like a hero yet?").
- Tone shift is carried by environment and character animation (the squad's barks grow angry and ragged; executions become brutal) more than cutscenes.
- The "choice" in the white phosphorus scene is no choice at all; it criticises the game's linearity. Players resented being blamed for something they were forced to do.

**Apply:** Do not punish the player for something they could not avoid. Before the reveal, everything the player feeds the factory must be something the game asked of them and they had good reason to do. After the reveal, every factory act is a free choice. Use small UI text that changes over time (loading tips, HUD greetings) as a cheap, powerful tone shift channel. Pony barks and animation sour as dread grows.

---

## 3. Game feel

From Steve Swink's *Game Feel*, Jan Willem Nijman's "The art of screenshake" (2013), Martin Jonasson and Petri Purho's "Juice it or lose it" (2012), and Vlambeer practice.

- **Input response under 100 ms**, ideally the same frame. Acceleration to full speed in about 0.1 to 0.2 s, deceleration slightly faster. Third-person characters should turn quickly toward the input direction (rotation lerp rate high, about 10 to 15 per second) with body lean into turns.
- **Coyote time** (about 0.1 s) and **jump buffering** (about 0.1 s). Variable jump height (release early for a short hop). Higher gravity on the way down than up (about 1.5 to 2x) for snappy arcs.
- **Squash and stretch**: on land (squash 0.85 y / 1.1 xz, recover over 0.15 s), on take-off (stretch), on capture pop (the captured thing stretches toward the beam, then pops). Preserve volume.
- **Anticipation and follow-through**: a short crouch before jump (can be visual only, a few frames, so it does not add input lag), ears and mane follow-through after stops, tail swish after turns.
- **Screen shake**: small, short, directional, trauma-based (shake = trauma squared, decays linearly, Perlin noise, not random jitter). Reserve for impacts that matter (big catch, a rare pony, a door slam in the factory). Always offer a setting to reduce it.
- **Hit pause / hit stop**: 30 to 80 ms freeze on high-value moments (capturing a rare pony, landing a coin jackpot). Use sparingly.
- **Particles**: every pickup, capture, sell, and purchase gets a short burst. Keep them in the art style (flat-colored shapes, sparkles and stars for cozy; dust and ash for dread).
- **Layered sound**: every key action is 2 to 3 layers (transient click + body + sweetener), with 5 to 10 percent random pitch and small volume variation, and no two identical plays in a row. Rising pitch for streaks (each successive coin a semitone up, the Mario coin trick).
- **Camera feel**: smooth follow with slight lag (spring arm with damping), look-ahead in the movement direction, small FOV kick on sprint (+5 to 8 degrees), collision that pulls the camera in and never clips through walls, never through the player.
- **Numbers that fly to the counter**: rewards physically travel to the HUD element they increment.

**Apply:** Every player action in the GDD gets a feel row: visual, audio, and motion response. The test is a muted-screen check (does it feel good without sound?) and a blind check (does it sound good without the screen?).

---

## 4. Progression, onboarding, rewards, grind

- **Onboarding without text walls** (Nintendo's "kishōtenketsu" level design, the World 1-1 lesson): introduce a mechanic in a safe space, let the player try it, then combine it with something they know, then twist it. One new verb per area.
- Teach by **level layout and affordance**: the first wild pony stands near the start, facing away, in a clearing with nothing else to do. The first pen is right next to the arrival point. Gates are visible before they are openable.
- **Contextual prompts only**, shown at the moment of need, at most one line, never blocking. They disappear forever after the player performs the action twice.
- **Reward schedules**: mix fixed (goals the player can see, like the next ranch upgrade) with variable (rare pony sightings, market spikes, a lucky cosmetic drop). Variable ratio rewards are the strongest motivator; use them for delight (rare coats, rare cutie mark spots), never for required progress.
- **Visible next goal at all times**: a short, always-on objective that points to the next meaningful thing, framed in-fiction (a request on the board).
- **Avoiding grind**: each step up in cost should come with a new capability, not just a bigger number. A good heuristic: the time to the next purchase should stay roughly constant (5 to 10 minutes) as the player progresses, because income grows with costs. If income ever stalls, the next purchase should be one that raises income.
- **Session shape**: aim for a natural stopping point every 15 to 25 minutes (a day ending, a delivery made), and a hook to start the next session (mail on the doorstep, a new request).
- **The first 10 minutes**: the player should have caught a pony, penned it, seen it produce, and sold the produce in under 5 minutes, and made their first purchase by 10.

**Apply:** The 30-second, 5-minute and 1-hour loops in the GDD are tuned to these numbers, and a headless test checks the first-10-minutes milestones with a scripted player.

---

## 5. Matching the G4 show look in 3D Godot

**What the show actually looks like** (Friendship Is Magic, DHX Media, Flash-animated):
- Flat color fills with **one hard shadow tone** per material (cel shading, no gradients on characters), sometimes a single rim highlight.
- **Clean dark outlines** on characters, colored darker than the fill rather than pure black (a dark version of the local color). Backgrounds have thinner, softer or no outlines; the separation is done by value and saturation instead.
- **Saturated, high-value palettes**: Ponyville is warm, pastel and bright (cream, peach, soft greens, sky blue), with lighting almost always daytime-flat. Shadows are a cool, desaturated version of the base, never black.
- **Backgrounds are painted**: gentle gradients in skies, simple shapes, rounded architecture, stylised trees as soft blobs with a few leaf shapes, grass as a flat green with darker patches. Background detail is lower than character detail so characters pop.
- **Big expressive eyes** with bright specular highlights are the center of character appeal.

**Shading recipe in Godot 4 (Forward+):**
- Character shader: `diffuse_toon` or a custom `light()` function with `step()` (or `smoothstep` with a very narrow band) on N dot L to give two tones; shadow tone = base color multiplied by a cool tint (about rgb 0.75, 0.75, 0.9) rather than darker grey. Specular off or a single hard rim with `pow(1 - dot(N, V), k)` stepped.
- **Outlines**: inverted hull (second material pass, `cull_front`, vertices pushed along normals by a screen-space-constant width) for characters and hero props. Outline color = albedo times about 0.4 to 0.5, saturation preserved. For environments, a post-process depth and normal edge-detect at lower strength, or none.
- **Lighting for cozy sections**: one directional sun with soft color (warm, about 1.0, 0.96, 0.88), a high ambient from the sky (energy high, so shadow sides stay readable and saturated), `tonemap` Filmic or Linear tuned so colors are not crushed (ACES desaturates highlights and fights the show's flat colors; prefer Filmic or AgX with low contrast, or Linear with a manual exposure). Shadows on, but softened and tinted, never pitch.
- **Color grading** via `Environment.adjustment` (brightness, contrast, saturation) and a color correction LUT/gradient texture. Keep the cozy grade at saturation about 1.1 to 1.2.
- **Dread grade** for the factory and the late factory-path world: same assets, change the environment and lights only:
  - Saturation down to about 0.5 to 0.7, a cool or sickly cast (teal-green shadows, the sun pushed toward a dirty amber).
  - Volumetric fog (Forward+ supports it) with low-lying density and a desaturated color; in the factory, fog lit by colored machine lights.
  - Ambient light lower so shadow sides darken; directional light lower and more horizontal (long shadows).
  - Contrast up slightly, vignette via a full-screen shader.
  - **The rainbow motif inverted**: in the cozy world rainbows are joyful; in dread, the only saturated colors left on screen are the factory's spectral outputs (pipes, tanks, the sky rainbow). Saturation becomes the thing that is wrong.
- Use **one shared toon shader** for everything (props, terrain, ponies) so nothing reads as from another game. Props imported with PBR materials get converted to the toon material with their albedo kept and roughness/metal ignored.

**Apply:** A single `toon` material family drives every mesh. The world-tone (cozy to dread) is one scalar (`dread` 0 to 1) that drives environment grading, fog, light color, music layer, and ambient sound together, so the tone shift is felt everywhere at once and is trivially testable.
