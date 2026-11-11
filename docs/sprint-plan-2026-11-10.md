# Sprint P9: the 2026-11-10 playtest, overnight 2026-11-10/11

Source: docs/playtest-2026-11-10.md (76 items). Status per item: docs/playtest-2026-11-10-ledger.md.
Branch v1-overhaul, local commits only, no push.

## Why this sprint exists
Rounds 3-8 judged staged renders and unit tests. The owner played the real route and found
inert guards, walk-through props, a shop that buys the wrong item and three items ticked fixed
that were not. So the rule this sprint:

- An item is FIXED only with a frame (or frame strip) from the real scene, reached the way the
  owner reaches it (a fresh save, or a save at that beat), rendered on the GPU (gpu-headless-renders), and
  LOOKED AT. The ledger names the file. A test may back it; it never stands alone.
- For behaviour (guards detect, list does not jump, E talks to Tumble), the evidence is a frame
  strip of the input and the result, not an assert.
- No 5-ending bot as a gate. Parse sweep per batch. Sandbox user-folder paths.

## Lanes (memory: pace-two-at-once, limit-parallel-agents)
- Lane A, me in the main checkout: W1 then W2.
- Lane B, ONE Opus 5.5 subagent in a worktree: W3, then W4. I review each batch from its
  frames and cherry-pick. Never more than one agent beside me.

## Waves
**W1, stops the game or costs money** (items 1-6, 26, 27, 29, 37, 38, 41, 46, 74, 75)
- Bloom: an active way to push it (feeding/grooming/play beat), plus a visible meter and reason.
- Next-step guidance after the first one-of-a-kinds (Depot, gems to bits).
- World events wait for the player; a short "while you were away" card after idle.
- Bed offers "till dusk" as well as "till dawn"; notification queue with spacing and priority.
- Beam slip drops the pony (no mid-air freeze; no CAUGHT card on a slip).
- Building a pen pushes bystanders out; NPCs never trapped.
- Tumble's prompt: only when she is in reach and E works; stale tips clear with the objective.
- Shop list never moves after a buy; confirm on big purchases. Race: pick pony, pick stake, Place bet.
- Pause in dialogue (and in the factory). Run toggle on Shift, default run.
- Tumble's late-story line follows story state.

**W2, the Rainbow Factory and the ending** (7-25)
Guards that see and react (light cone in front, ring off the head, no clip through walls),
collision on every prop, an objective and marker for every step, the opening shot, NPC
pathing out of walls, colour in the rooms, posters filled, the staff door as a real beat,
a readable two-path choice, Heat explained on screen, the corral and pylons explained, a
lever that reads, and an ending card: its name, that there are five, what you missed.

**W3, text and 2D** (28, 30-36, 39, 40, 42-45, 47-50, 55, 68, 76)
Pen status badge replaces all floating pen text; short prompts; tips shown not written;
Marigold and the collection letter rewritten plainly; Owned state; price rows aligned;
mailbox states and Close; chips redrawn; race result matches odds; race scene shaded;
slots payout and a bonus machine; light catch for Drifters; swatch row; pantry label.

**W4, rendering and art** (51-54, 56-67, 69-73)
AA and shadow filtering, fog, one tree family, camera out of canopies, creator (leg, tail
colour, marks, freckles), the striped tube, prop placement, NPC wall-staring, Spike.

## Order tonight
1. Plan, ledger and resume note committed (the streak commit, before midnight).
2. Lane B starts on W3; I start W1 at once.
3. Each batch: parse sweep, focused tests, real-flow frames looked at, ledger row, commit.
