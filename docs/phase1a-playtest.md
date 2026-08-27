# Filly Rancher — Phase 1A playtest

This is the first build of Filly Rancher that is meant to be *played* rather than
tested. It is one slice of the game: a ranch to walk around, wild ponies to find,
and a magic beam to catch them with. Everything the ponies are eventually *for*
— pens, food, gem production, the economy — is Phase 1B and is not in here yet.

Read §5 before you decide something is broken; several of the odd things in this
build are known and deliberate.

---

## 1. Running it

**Windows.** Download `filly-rancher-windows.exe` and double-click it. That is the
whole install — there is no installer, no zip, and no second file to keep next to
it (the game data is embedded in the executable).

Two things will happen the first time and neither means anything is wrong:

* **"Windows protected your PC."** The build is not code-signed — a signing
  certificate costs real money and this is a two-person project. Click
  **More info**, then **Run anyway**.
* **Antivirus grumbling.** Freshly-built unsigned executables that bundle a game
  engine get flagged by heuristics fairly often. Allow the file if you are asked.

**Linux.** Download `filly-rancher-linux.x86_64`, then:

```bash
chmod +x filly-rancher-linux.x86_64
./filly-rancher-linux.x86_64
```

**The window.** It opens at 1600x900, windowed, and the whole HUD scales with the
window if you resize it. The mouse is captured as soon as the game starts (that is
what lets you look around) — press **Esc** to get your cursor back, and Esc again
to go back to looking around. There is no menu and no quit key: close the window.

---

## 2. Controls

Everything is bound for **both** keyboard/mouse and a gamepad. Press **H** in game
for the same list on screen; the card is up when you start, and H puts it away.

| | Keyboard / mouse | Gamepad |
|---|---|---|
| Move | `W` `A` `S` `D` (or arrow keys) | Left stick |
| Gallop | `Shift` (hold) | `LB` (hold) |
| Jump | `Space` | `A` |
| Look around | Mouse | Right stick |
| Zoom in / out | Scroll wheel, or `=` / `-` | D-pad up / down |
| **Magic beam** | **Right mouse button (hold)** | **Right trigger (hold)** |
| Free the mouse cursor | `Esc` | — |
| Show/hide the control card | `H` | `Back` |

Movement is **camera-relative**: "forward" is wherever you are looking, not
wherever Twilight is pointing. The gamepad's left stick is analogue, so a gentle
push ambles and a full push goes at the top speed for whichever gait you are in.

### The magic beam, in detail

This is the whole game right now, so it is worth spelling out.

1. **The beam aims at the centre of the screen**, marked by the crosshair — not at
   Twilight's nose. Put the crosshair on a pony.
2. **Hold** right mouse / right trigger. The beam sweeps out from Twilight's horn.
   *Keep holding it* — it keeps looking for something to grab every frame, so if
   you are slightly off, sweep across her rather than letting go and trying again.
3. Once she is caught she is lifted out of the world and reeled in to float up and
   to the right of you, wrapped in a pink aura.
4. **A ring appears around the crosshair and drains away.** That is how long she
   will put up with it. Let go before the ring runs out and she goes in your
   saddlebag; let it run out and she wriggles free and drops back to the grass.
5. Ponies resist for different lengths of time depending on who they are — see §4.

**No pony is ever hurt, ever, by anything.** That is a rule the whole project is
built on. A pony who escapes, or who cannot be stored because your bag is full, is
put back in the world alive and unbothered. If you ever see one vanish, fall
through the ground or get stuck somewhere, that is a bug worth reporting.

---

## 3. Things to try

* **Walk to the barn and go inside.** It has a door you can actually walk through
  and the inside is lit. So does the farmhouse.
* **Zoom all the way in.** Twilight fades out as the camera closes on her, so full
  zoom-in is effectively a first-person aiming view. Zoom all the way out for a
  wide shot of the ranch.
* **Back yourself into a wall and look at the camera.** It pulls in rather than
  clipping through, and Twilight fades out instead of filling the frame.
* **Find all three kinds of pony.** There are eight wild ponies in three grazing
  areas: north past the barn, east over the rise, and south-west beyond the
  clearing. Every one of the three characters in the game is out there somewhere.
* **Stand still and let a curious one come to you.** Some ponies walk toward you,
  some bolt, and some completely ignore you (§4).
* **Chase a shy one.** A fleeing Fluttershy runs at about 2.5 m/s and your gallop
  is 4.0 m/s, so you will catch her — but she is genuinely running, and she will
  keep running as long as you are close enough for her to see you.
* **Try to catch one through a wall.** You cannot; the beam stops at whatever the
  crosshair is actually resting on.
* **Walk to the edge of the map.** There is an invisible wall, not a cliff.
* **Deliberately let one escape.** Hold past the ring and watch what happens.

---

## 4. Who is out there

Three characters, and the difference between them is not cosmetic — each one
behaves differently on the ground *and* under the beam.

| | Reacts to you by | Resists the beam for | Rarity |
|---|---|---|---|
| **Fluttershy** | fleeing at a gallop | **1.5 s** — you have to be quick | uncommon |
| **Twilight Sparkle** | walking over to see what you are | 2.5 s | rare |
| **Rainbow Dash** | ignoring you completely | 4.0 s — near enough a free catch | rare |

Rarity decides the odds when the herd is drawn; the herd this build actually ships
with is **three Fluttershies, three Rainbow Dashes and two Twilights**, spread
across the three grazing areas.

A pony notices you from about 5 m. The beam reaches 8.5 m, so you can take a shy
pony from outside her notice range if you spot her first — that is the whole point
of the beam being longer than her eyesight.

The eight ponies, where they stand, and where they wander are **the same every
time you launch the game**. That is deliberate: a collection game whose map
reshuffles on every boot is a map you cannot learn.

---

## 5. Known issues and deliberate omissions

### Not bugs — this is what Phase 1A is

* **There are no pens, no food, no gem production and no money.** Catching ponies
  is the entire loop right now. All of that is Phase 1B.
* **There is no way to let a pony back out of your saddlebag.** Once she is in,
  she is in for the session. Releasing is part of the pen system, so it lands with
  Phase 1B.
* **Nothing is saved.** Close the game and your catches are gone. Also Phase 1B.
* **The bag holds twelve and there are only eight ponies**, so you cannot fill it
  yet. The "saddlebag full" message exists and works; you just cannot reach it.
* **The trees and bushes are mint green.** That is the Kenney Nature Kit's own
  stylised palette shipped as it comes, not a lighting bug and not a
  colour-management mistake. Whether to re-tint the foliage is a decision for
  later, not a defect.
* **The ponies have no cutie marks.** glTF cannot carry the source models'
  colour-plus-decal material in one piece, so every pony currently ships with a
  flat body colour. Fixing it needs a texture bake and is written up in
  `docs/pipeline.md` §3.
* **Only Twilight has a voice**, and only one line, played once on your first
  catch ever. The voice system is a later phase (`docs/notes-voice.md`).

### Real rough edges

* **A beam that is *reaching* for a distant pony is hard to see.** The camera sits
  directly behind Twilight, and the beam runs from her horn toward the middle of
  the screen — which is almost straight away from you, so it compresses into a
  few pixels. Once she has hold of something it is obvious (the pony floats out to
  the side with a bright aura and the beam is clearly drawn to her); it is only the
  empty sweep that is faint. The proper fix is to move the camera off to one side,
  which is its own piece of work and is deliberately not in this build.
* **Walking is slow on purpose, and it may still feel too slow.** Twilight's walk
  is 1.32 m/s. That is not an arbitrary choice: the authored walk cycle depicts
  0.66 m/s of ground travel, and 1.32 is exactly double, which is as fast as the
  clip can be played before her hooves start sliding over the ground. **The gallop
  (Shift / LB, 4.0 m/s) is the real travel speed** and the map is sized around it —
  the ground runs about 140 m across. If you find yourself ambling anywhere, hold
  Shift; you are meant to. Making the *walk* genuinely faster means authoring a
  longer stride, not turning a number up.
* **The buildings are boxes.** The Kenney prop pack turned out to contain no actual
  buildings — its "windmill" is a bare set of sails and its "watermill" is a bare
  waterwheel — so the barn and the farmhouse are assembled from primitives in code
  (`game/world/building.gd`). They read as buildings and you can walk into them,
  but they are placeholder architecture.
* **The camera is not smart about corners.** It will not clip through a wall, but
  in a tight spot it can pull in far enough that Twilight fades out entirely. That
  is the fade doing its job — back away a step and she reappears.
* **Wild ponies do not path around obstacles.** They wander in a circle around
  where they spawned and will nudge along a tree trunk rather than walk round it.
  Nothing gets permanently stuck (there is a timeout that makes them pick a new
  destination), but it is not clever.

---

## 6. What would be most useful to hear back

In rough order of usefulness:

1. **Does catching a pony feel good?** That is the one thing the whole phase is
   built around. Is the ring the right length? Is 8.5 m the right reach? Is the
   moment she comes flying in satisfying, or fiddly?
2. **Can you tell what is going on without being told?** You have this document;
   the next person will not. Was the crosshair enough? Did you work out that you
   have to *release* to keep her?
3. **Does the ranch read as a place** — somewhere with a shape you could learn —
   or as objects scattered on a field?
4. Anything that looked broken. Especially anything involving a pony ending up
   somewhere she should not be.
