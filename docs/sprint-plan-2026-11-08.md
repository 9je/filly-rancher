# Next sprint plan, 2026-11-08 (P8)

Inputs: docs/playtest-2026-11-08.md (79 items, numbered "item N" below),
docs/aaa-review-2026-11-08.md (the art and UX review, "review 2.x"),
docs/sprint-retro-2026-11-08.md (what went wrong last time, "retro rule N"),
docs/ideas-2026-11-08.md (design experiments, "idea X").

The goal in one line: stop fixing screens one at a time. Build the missing systems (the
lighting rule, the icon set, the UI kit, the cinematic player, a core loop with no lazy
dominant strategy), then rebuild every area the owner called weak on top of them, and judge
each one side by side against a named reference game.

## 1. Shape of the sprint

Two sprints with a full owner playtest between them, not one 79-item sweep.

- **Sprint A: blockers, the loop and the foundation.** S0 to S5 below. Ends with a build the
  owner plays from a fresh start. The question it answers: does the game now play right, and
  does the base look (light, icons, UI) clear the bar?
- **Sprint B: area rebuilds and cinematics.** S6 to S10. Built on what Sprint A's playtest
  kept.

Two lanes from hour 0 (retro rule 11): the main session takes the visual lane, one Opus 5.5
worktree agent takes the gameplay lane. They touch different files. The agent never edits
PLAN, PROGRESS, DECISIONS or the ledger; it returns its rows in its report.

| Batch | Lane | Content | Owner items |
|---|---|---|---|
| S0 | main | Process setup (section 4) | none |
| S1 | main | Blockers and the sprint's own regressions | 1, 3, 13, 17, 20, 21, 24, 70 |
| S2 | agent | Core loop: the colour loop, days, quota, gated rares | 2, 4 to 12, 14, 22, 74 to 76 |
| S3 | agent | Catching | 23, 25 |
| S4 | main | Lighting and grade reset | 39, 49 to 51 |
| S5 | main | Icon set v1, then UI kit v1 and the HUD | 41, 44, 68, 69, 71 to 73, 77 |
| -- | owner | Sprint A playtest, fresh start | |
| S6 | main | Ponies and the creator studio | 28 to 40 |
| S7 | agent | Town and props rebuild, collision | 26, 27, 42 to 48, 52 to 55, 66 |
| S8 | main | Casino, cards, slots, race betting and the race cinematic | 56 to 65 |
| S9 | agent, then main | Cinematic player, story scenes, comedy events | 7, 15, 16, 18, 19, 22, 36, 78 |
| S10 | main | Loading screen and title | 67 |

S1 also gets a 15-minute owner check from the 14:58 save (retro rule 10). Item 79 (the
references pass) is the reference named in every batch's "done" below.

## 2. Design calls (logged in DECISIONS.md)

### 2.1 The colour loop: the Factory only wants colour
The problem: the best strategy was to catch in bulk, keep the rares and ship every blank
Drifter before she could Bloom. Bloom was optional, slow and invisible, so it was skipped.
The fix must not make anything slower.

- **A blank Drifter is worth almost nothing to the Company.** The Depot takes her for a
  token intake fee and she does not count toward the quota. A Bloomed pony (her mark showing)
  is what the quota counts and what pays. Selling blanks is no longer a strategy, it is
  clearing space.
- **Bloom becomes the core activity, fast and readable.** One pony in good care Blooms in
  about 3 to 4 minutes, all pens in parallel, so throughput rises, not falls. Each pen shows
  a meter per pony and the one thing holding her back (hungry, wrong food, crowded, bored)
  as an icon. Crowding becomes a slowdown that starts above the pen's comfortable number and
  never a silent freeze; the contradiction of CROWDED_AT 7 with a Grand pen of 8 goes.
- **Her favourite food and a toy or decoration speed her up** (idea C3, kept small): the
  care loop is what you do between catching trips.
- **The horror lands through the loop itself:** the better you care for her, the more she is
  worth to the Factory (idea B2). Letters and the quota board never say it out loud.
- **Named and legendary ponies** already have marks: they count and pay well, but they are
  gone for good, and the Depot says so (the "one of a kind" ask stays).
- **Jobs (idea B1) are deferred.** The owner was lukewarm; the colour loop gives keeping
  ponies a point without them.

### 2.2 Days, quota and pace
- **Real days (idea D1):** sleep at the house ends the day, saves, and skips to dawn
  (items 3, 11). Autosave also runs every 5 minutes outdoors.
- **A visible weekly quota replaces the hidden 5,000 floor (idea D2, items 4, 5):** the
  Depot's Pay tab becomes a statement with the quota as a bar and the collection day marked.
  Clearing the debt is a scene with Marigold (idea F5), not a red number.
- **Rares are gated (idea C1, items 6, 12):** by time of day, weather and what you have
  built, and at most one new legendary a day. Sightings drop to one or two a day and wait
  until you are outdoors and free (item 13).
- **Pacing target is order, not hours:** the story beats must arrive in order (the first
  collection-day letter before the debt can clear; Bloom taught before it is asked for). No
  step is lengthened just to fill time.

### 2.3 Catching
- One clean catch again (idea A1): the multi-hit hold and the hidden look-at rule go
  (item 23).
- Difficulty comes from behaviour: skittish kinds bolt if they see you, so you walk to sneak
  up from behind (idea A2). This gives walking its job (item 25).
- Bait (idea A3): drop her favourite food and she comes to eat; while eating she is easy.

### 2.4 Story cracks
Every crack gets its moment through the camera, sound and timing, and the words stay
innocent (memory story-cracks-subtle). Concretely: the collection day is staged on camera
(item 7), Bramble's Color Day line turns quietly scared (16), the "Top of the board" letter
gets a picture that does the work (19), the postcard goes only to Drifters (18), and Tumble
is met after Marigold's first talk ends, never during it (15).

### 2.5 Art direction (from the review, accepted as written)
Hard toon shadows to 60 m, SSAO off, blob shadows, baked AO, a ramp texture, AgX, a moon
light and lit windows at night, one LUT per tone, painted skies. Icons: one SVG set from a
64 px template plus the baked 3D route, on cream plates; the per-pixel and polygon icon code
is deleted once replaced. UI: one Theme of nine-patch paper, wood and velvet, Fredoka for
display plus a rounded body face, one motion library, a 48 px safe area, toasts as event
cards (icon, number, three words).

### 2.6 Flank jiggle and comedy
The jiggle stays everywhere. It is scaled up for small ponies and for big tails so it reads
(item 36). Two comedy events show it off: Derpy crash-landing (tumble, bounce, jiggle) and
the Sonic Rainboom across the sky, both through the cinematic player (S9).

## 3. Batches

Each batch lists its "done", judged by eye on a render of the owner's situation, next to the
named reference where there is one. Tests back it up; they do not replace it.

### S0. Process setup (time-box: 2 h)
- A fresh session for the sprint, with docs/sprint-resume.md (60 lines or fewer) as the only
  thing re-read after a compaction.
- A new ledger, docs/playtest-2026-11-08-ledger.md: one row per item with the owner's words
  verbatim, the screenshot, a situation column (who, where, crowd, weather, time, what the
  player was doing), the diagnosis in its own column, the evidence path, and the verdict.
- Static dialogue-graph test: every story-gating conversation's every branch fires its event,
  sets its flag, or leaves the talk offered again (would have caught item 1).
- Story reachability test per beat from fixture saves: the objective names a target, the
  target exists, and her talk prompt wins over any building prompt in range (item 17).
- Constant cross-checks: Bloom crowding vs the largest pen, autosave ceiling, beat order in
  the pacing model.
- scenes/test/stress_pen.gd: a Grand pen of 8 mixed rigs, the live player walking to each
  corner and jumping, rain then night, 120 s, a 5 fps contact sheet.
- A regression sheet of about 15 fixed shots (full pen with the player at a corner, a Mane
  Six landing, the tail on a jump, the casino hall, the fingerpost edge-on and walked into,
  the town overview, the Depot front with Marigold, the beam aimed low), regenerated after
  every batch and looked at.

### S1. Blockers and regressions (main)
- Item 1: "Give me a minute" leaves the lift offered again; Marigold waits at the Depot.
- Item 3: autosave every 5 minutes outdoors and on sleep.
- Item 24: the beam always lifts a caught pony (undo the side effect of 2d9c055's
  `_keep_over_ground`, rendered aimed low).
- Item 17: Marigold's talk wins over the Depot prompt.
- Items 20, 21: one summary letter and one summary toast per Depot batch.
- Item 13: sightings and spotting wait until you are outdoors and no menu is up.
- Item 70: pronouns from PonyData in the Depot.
- Render-check the suspected regressions from the retro: buildings scaled on old footprints,
  toasts held longer.
- Done: the owner's save resumes, picks "Give me a minute", and finishes the story. Then a
  15-minute owner check.

### S2. Core loop (agent)
Section 2.1 and 2.2: the colour loop, the Bloom meter and reasons, crowding as a slowdown,
favourite food shown on the pen and her card (item 10), days and sleep, the quota statement,
the debt-cleared scene hook, gated rares and fewer sightings, Bramble's spotting shown as a line you can read (item 14), Drifters marked as Drifters in
the world and at the Depot (item 9), the Bloom ceremony calling you over (item 22), plain
objective words with a one-time explainer of Drifter and Bloom (items 74, 75), a pen "full"
sign (76). Done: a scripted first hour on the pacing model shows beats in order, plus renders
of a pen's meters with each blocking reason.

### S3. Catching (agent)
Section 2.3. Done: a 10 fps strip of sneaking up on a skittish pony and of a bait catch.

### S4. Lighting and grade reset (main; review 2.1)
Done: the plaza at noon, dusk and night next to an Animal Crossing plaza and a show
background; no stencilled shadows on walls at night; every terminator a flat edge; distant
coop and trees hold together (item 50).

### S5. Icon set v1, then UI kit v1 and HUD (main; review 3, 2.4, 2.6, 2.7, 2.11, 2.12)
Icons first: about 80 icons by the spec, the contact sheet at 32, 64 and 128 on cream, plum
and grass next to a row of Slime Rancher and Animal Crossing icons. Then the kit: the Theme,
the two faces, the motion library, the safe area, event cards, compass markers, and the
showcase scene. Then the screens on it: HUD, pause, letters (per-sender stationery), Depot
(portraits, one number per row, deliver-all, the pony popping to coins at once, item 69),
Market (Bramble's portrait, Buy and Sell tabs, fixed size, item 68), caught card (item 71).
Done: the HUD over the noon plaza next to Slime Rancher's and Animal Crossing's; nothing
clipped at 1600x900 or 2560x1440; no toast is a sentence.

### Quality gate: the vertical slice (before S5 goes wide)
Before the full icon set and every screen, one slice is taken all the way: the plaza at noon
and at night under the new lighting, 12 icons from the spec, and the HUD plus the Depot on
the kit. The owner sees it as renders and a short clip, side by side with the references,
and says keep, change or switch route. If the drawn icons or painted skies fall short, the
fallback is bought or commissioned art for those pieces (owner's call on spend), not more
passes of the same route.

### Sprint A playtest
A fresh start build. The owner plays as far as they like. Their list decides what Sprint B
keeps, cuts or changes.

### S6. Ponies and the creator studio (main; review 2.2, 2.5)
The tipping and pen pile-up repeats (28, 29) checked on the stress scene, not a calm one; the
tail on a jump (30); look-at deadband (31); floating (32); the player fade by dither (33);
hair shading and real NPC tails (34); Spike's eyes (35); jiggle scaled (36); the creator as a
studio scene with picture tiles, the preview matching the picks, the mark anchor (37 to 41).
Done: a creator turntable next to a show reference sheet; a herd at 25 m keeps outlines and
eyes; the stress sheet clean.

### S7. Town and props (agent; review 2.14)
A plaza plan with the Market and Depot facing it and close together, the house and pens
about 40 m out, the Strip on its own hill; one fingerpost of four arms; 3D signs with
thickness; path meshes and curbs; no primitives left; scale fixes; lake banks, reeds and
dock; a collision pass and an "unstuck" pause option; a walkable sighting route; NPCs off the
gates; new Market music. Done: a top-down next to an Animal Crossing plaza and a 60 s walk
from the house to the Palace with no snag.

### S8. Casino (main; review 2.8 to 2.10)
A generator crowd seated and playing, attract lights, table spotlights, a carpet, a cashier
the first visit points to; blackjack with stacking chips, Clear and Max, a drawn card atlas;
slot symbols and spin feedback; race betting rebuilt like Inside Track with portraits and
odds; the race watched as a cinematic with your pick ringed and pinned on the HUD; the arcade
props and the House rules sign moved in or cut. Done: the hall next to a GTA Diamond Casino
shot, the betting screen next to Inside Track, one race watched end to end.

### S9. Cinematics (agent builds the player, main authors the scenes; review 2.15, idea F)
The player: camera rails, letterbox, skip, input lock, a hold until menus close, scenes as
data. Scenes in order: the Bloom ceremony (F3), collection day (F4, item 7), debt cleared
(F5), Color Day and the lift (F6), arrival (F1), the Derpy crash and the Sonic Rainboom (F8,
F9), the legendary sighting (F11), the jackpot (F12), then the reveal and the endings (F7).
Done: a clip of each, judged against a Cult of the Lamb ritual cut, and each one skippable.

### S10. Loading and title (main; review 2.13)
Done: side by side with Hades' loading screen and Cult of the Lamb's title.

## 4. Process rules (from the retro)

1. Evidence reproduces the owner's situation column in full (crowd, weather, time, action).
   Motion is shown in motion (a 5 to 10 fps strip), never stills 30 s apart.
2. The owner's words go to the reviewer verbatim with the screenshot, never a one-line
   rewrite.
3. Focused tests on every commit. The full suite runs on a snapshot once per batch in the
   background and never holds a commit.
4. The stress scene and regression sheet after every batch, looked at before the batch closes.
5. A harness fix that changes game code needs a render of how the game now plays.
6. Infrastructure and bench work: 2 hours a row, then log it and move on. Perf and exports
   are not sweep gates.
7. Fable runs once per batch, for acceptance only, with the raw owner lines and the renders.
8. Never end a turn with open work and nothing running. Compact at batch boundaries without
   waiting for the owner.
9. The ledger is the only source of item status. PROGRESS gets one line per batch. DECISIONS
   only real design calls.
10. No bot playthroughs. No "all done" until every row has its verdict.
