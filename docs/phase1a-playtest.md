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
| Move (you **run** by default) | `W` `A` `S` `D` (or arrow keys) | Left stick |
| Walk / sneak | `Shift` (hold) | `LB` (hold) |
| Jump | `Space` | `A` |
| Look around | Mouse | Right stick |
| Zoom in / out | Scroll wheel, or `=` / `-` | D-pad up / down |
| **Magic beam** | **Right mouse button (hold)** | **Right trigger (hold)** |
| Free the mouse cursor | `Esc` | — |
| Show/hide the control card | `H` | `Back` |

Movement is **camera-relative**: "forward" is wherever you are looking, not
wherever Twilight is pointing. The gamepad's left stick is analogue, so a gentle
push ambles and a full push goes at the top speed for whichever gait you are in.

**Shift is the other way round from last build.** You now run by default — press a
direction and nothing else and you are going at 5.2 m/s, the fast gait. Holding
`Shift` **slows you to a creep** (1.32 m/s) and that creep is a stealth move, not
just a slow walk: **a pony notices a creeping player from half as far away as a
running one.** A Fluttershy spots you running at 14 m and creeping at 7 m, and the
beam reaches 8.5 m — so if you are patient you can walk right up and take her
before she has reacted to you at all. Running is for chasing; creeping is for not
having to.

### The magic beam, in detail

This is the whole game right now, so it is worth spelling out.

1. **The beam aims at the centre of the screen**, marked by the crosshair — not at
   Twilight's nose. Put the crosshair on a pony.
2. **Hold** right mouse / right trigger. The beam sweeps out from Twilight's horn.
   *Keep holding it* — it keeps looking for something to grab every frame, so if
   you are slightly off, sweep across her rather than letting go and trying again.
3. Once she is caught she is lifted out of the world and reeled in to float up and
   to the right of you, wrapped in a pink aura.
4. **Two rings appear around the crosshair, and they mean different things.**
   * The **inner ring fills up** as the beam subdues her. It takes about **1.2 s**,
     the same for every pony. Until it is full she is not yours — let go early and
     she slips out of the field and drops back to the grass.
   * The **outer ring drains away** — that is how long she will put up with it, and
     it is different for every pony (§4). Let it empty and she wriggles free.
5. So: **hold until the inner ring completes, then let go.** The gap between the
   two is your window, and it is wide for a Fluttershy and narrow for a Rainbow
   Dash. The reticle turns **green and grows** the moment letting go would keep
   her; that flash is the cue to release.
6. If you fumble it, the toast tells you *which* mistake you made — "she slipped
   out" (too early) or "she wriggled free" (too late) — and the beam will not
   re-take her for about a second and a quarter, so a lost pony gets a head start.

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
* **Find all three kinds of pony.** There are ten wild ponies in five grazing
  areas: one right next to where you start, north past the barn, east over the
  rise, south-west beyond the clearing, and one out west near the map edge. Every
  one of the three characters in the game is out there somewhere.
* **Stand still and let a curious one come to you.** Some ponies walk toward you,
  some bolt, and some completely ignore you (§4).
* **Chase a shy one.** A Fluttershy notices you at **14 m** — further out than
  anyone else — and is running before you are anywhere near beam range, at about
  2.5 m/s against your 5.2 m/s run, so you will catch her, but you have to commit
  to the chase and she keeps running as long as she can see you. Do **not** hold
  Shift for this: creeping is slower than she is and you will never close.
* **Then try sneaking up on one instead.** Spot a Fluttershy from a long way off,
  hold **Shift**, and walk in. She notices a creeping player only at 7 m, and the
  beam reaches 8.5 m — so you get one clean shot at her before she has any idea you
  are there. It is slow and it is the only way to catch one without a chase. (If
  she does bolt, letting go of Shift and running is always still an option.)
* **Slow down next to a pony who is already running.** She stops fleeing and goes
  back to grazing, because she cannot see a creeping player from where she is.
* **Watch the crosshair as you walk up to a pony.** It turns **amber and grows**
  the moment she is inside beam range, before you press anything. Switch the beam
  on over open ground and a ring appears on the grass where the beam lands — sweep
  it about to see how far 8.5 m actually is.
* **Try to catch one through a wall.** You cannot; the beam stops at whatever the
  crosshair is actually resting on.
* **Walk to the edge of the map.** There is an invisible wall, not a cliff.
* **Deliberately let one escape.** Hold past the ring and watch what happens.

---

## 4. Who is out there

Three characters, and the difference between them is not cosmetic — each one
behaves differently on the ground *and* under the beam.

| | Notices you at | Reacts to you by | Resists the beam for | Your window to let go | Rarity |
|---|---|---|---|---|---|
| **Fluttershy** | **14 m** (7 m creeping) | fleeing at a gallop | **4.6 s** | **3.45 s** — she has frozen | uncommon |
| **Twilight Sparkle** | 12 m (6 m creeping) | walking over to see what you are | 3.0 s | 1.85 s | rare |
| **Rainbow Dash** | 12 m (6 m creeping) | ignoring you completely | **2.3 s** | **1.15 s** — a real fight | rare |

The "window" column is the one that matters: it is her resistance minus the ~1.2 s
the beam needs to subdue her, and it is how long you actually have between "let go
now and she slips out" and "let go now and she has already gone".

**Getting to her and holding on to her are now two different problems, and they
run in opposite directions.** That is the change you asked for after the last
session ("it makes sense Fluttershy runs but freezes"):

* **Fluttershy is hard to reach and easy to hold.** She sees you coming from
  further away than anyone and she is gone. But once the beam has her she is too
  frightened to fight it — she freezes, and 3.45 s is not really a window, it is
  a breather. Last build she was hard on *both* counts, in series, and the second
  half was a 0.75 s reaction test after a chase you had already had to win. That
  is why she felt impossible.
* **Rainbow Dash is trivial to reach and hard to hold.** She does not care that
  you are there — walk right up. Then she thrashes, and 1.15 s is a window you can
  genuinely miss. She is not frightened of you, she is just not having it.
* **Twilight is in between on both**, and she is the one who walks *towards* you.

This also fixes something backwards about the last build: Rainbow Dash is a
**rare** pony and she was the *easiest* one in the game to collect. Now the rarest
pony is the one that asks the most of you.

Rarity decides the odds when the herd is drawn; the herd this build actually ships
with is **four Fluttershies, three Rainbow Dashes and three Twilights**, spread
across the five grazing areas.

**A pony notices a *running* player from 12 m (14 for a Fluttershy), and the beam
only reaches 8.5 m.** That way round is the point: a shy pony is *already running*
by the time you are close enough to take her, so catching one at a run is a chase
you commit to rather than a click you get in first. (It used to be the other way
round — 5 m of eyesight against 8.5 m of reach — which meant every catch happened
before its target had reacted to anything, and the fleeing behaviour, which works,
never actually happened in a game. That was the single worst bug the first
playtest found.)

**Creeping is the sanctioned way round it**, and the only one: hold Shift and those
numbers halve, to 7 m and 6 m, which is *inside* the beam's 8.5 m. That is the
whole trade — you give up three quarters of your speed and you get to close the
distance without being seen. A longer beam is something the Phase 1B shop will sell
you, and every metre of it eats into her head start, which is what will make buying
it feel like something.

The ten ponies, where they stand, and where they wander are **the same every
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
* **The bag holds twelve and there are only ten ponies**, so you cannot fill it
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

* **Judging beam range is still partly guesswork.** The camera sits behind
  Twilight and the beam runs from her horn toward the middle of the screen, which
  is almost straight away from you, so a long beam is heavily foreshortened. Three
  things now answer "how far does this go?" — the arc rides higher the further it
  reaches, a ring is drawn on the ground where it lands, and the crosshair turns
  amber when something grabbable is in range — but none of them is a distance in
  metres, and reading depth in a third-person view will never be exact.
* **The run slides its hooves very slightly.** Top speed is now 5.2 m/s and the
  authored gallop cycle honestly depicts 4.29 m/s, so at a flat run Twilight
  covers about 21% more ground than her legs account for. It is still below the
  threshold where that is visible in motion (the cutoff is about 25%, and there is
  a test that goes red if anyone pushes past it), and it is a deliberate purchase:
  4.29 m/s is also exactly the fastest a *fleeing* pony can be animated, so a
  player capped at it could never close a chase. The clean fix is a faster
  authored gallop cycle, which is an animation job. Since running is now the
  default, this is what you see most of the time rather than only while a button
  is held — worth telling us if you can actually see it.
* **The creep is slow on purpose.** 1.32 m/s, which is slower than the old default
  walk you called painful. That is the price of the halved detection range, not an
  oversight: a creep that moved at three quarters of a running pace would not read
  as creeping. You should never need to hold Shift to get anywhere — that is what
  the run is for.
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

1. **Is Fluttershy catchable now?** She was the headline complaint. She is now
   the *hardest to get near* and the *easiest to hold on to*, and there are two
   ways to reach her — outrun her, or creep up on her. Does either one work in
   practice? Is the freeze-once-caught readable as her being frightened, or does
   it just feel like she gave up?
2. **Is Rainbow Dash's 1.15 s window a fair fight or an unfair one?** She is where
   the difficulty went. She is free to walk up to, and then she is the only pony
   who can actually beat you. Is losing her annoying or motivating?
3. **Does running-by-default feel right, and is 5.2 m/s enough?** It went 4.0 →
   4.8 → 5.2 over two sessions. And does holding Shift to creep ever feel worth
   it, or do you just never touch it?
4. **Is the chase fun?** A shy pony bolts before you can reach her, so every catch
   of one starts with a run or a creep. Does that read as exciting or as tedious —
   and does it change how you feel about the ones that *don't* run?
5. **Can you tell what is going on without being told?** You have this document;
   the next person will not. Are two rings one too many? Did you work out from the
   screen alone that the inner one has to fill before letting go means anything?
   Did the control card make the Shift-to-creep thing land?
6. **Are there ponies where you walk?** The herd was all round the rim last time;
   there are now ten of them in five places, one of which is next to where you
   start. Does the ranch feel inhabited or crowded?
7. **Does the ranch read as a place** — somewhere with a shape you could learn —
   or as objects scattered on a field?
8. Anything that looked broken. Especially anything involving a pony ending up
   somewhere she should not be.
