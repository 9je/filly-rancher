# Sprint retrospective, 2026-11-08

Blameless, but blunt. The sprint is the work that followed the owner's 2026-11-05 playtest
(70 items, docs/playtest-2026-11-05.md). It ran as the PT sweep, then the PS sweep "no
exceptions" (PLAN.md sections PT and PS), then three rounds of independent verdicts
(docs/ps13/), and it ended at 8ba2fd7 on v1-overhaul. The owner's 2026-11-08 playtest
(docs/playtest-2026-11-08.md, 79 items) is the measure of what held.

Sources: `git log --since=2026-11-05`, the session transcript
3bd3e118-95ba-43ae-9b46-8eed8cc0fc8e.jsonl (tool calls, background-task notifications, turn
ends, the owner's messages, including the ones queued during long turns), the ledger
docs/playtest-2026-11-05-ledger.md, docs/ps13/verdicts*.md, PLAN/PROGRESS/DECISIONS and the
owner's feedback memories. Times are local (UTC-5). "Active" means the main session did
something at least every 10 minutes. Subagent work runs alongside that and is not counted in it.

## The short answer

1. **Why about 2 days?** The sprint ran 59.7 hours, from the end of the playtest (11-05 19:47)
   to the last commit (11-08 07:31). The main session was active for only about 21 of them
   (35%). About 17.5 hours went to waiting on background test runs with nothing else in
   hand. About 12 hours were stops that lasted until the owner wrote ("u got stuck?", "have you
   been idle for 2 hours", "Did you stop?"). The PT sweep's claims were false, so its
   verification was done a second time. The last 18 hours went mostly to test-bench and
   performance rows the owner never sees.
2. **How to make the next one faster:** do not run the full suite for every item. Never end a
   turn with work left and nothing running. Use the two-at-once setup from the start (it did 38
   commits in 5 hours, the best stretch by far). Time-box infrastructure work. Keep the status
   docs short.
3. **Why so many gaps?** Items were checked against a narrowed rewrite of the owner's words, in
   a calm scripted scene, with no rain, no crowd, a frozen stand-in player and a single camera
   angle. The owner meets them in a packed pen, in the rain, while jumping. Fixes changed shared
   systems, and the earlier items were never checked again afterwards. Several systems (Bloom,
   the economy, the story's dialogue branches) were checked only by a model or a unit test, or
   not at all.

## 1. Timeline: where the hours went

### Phases

| Phase | Local time | Wall | Main active | Commits | What happened |
|---|---|---|---|---|---|
| PT sweep | 11-05 19:47 to 11-06 08:34 | 12.8 h | 6.0 h | 35 | All 70 items "fixed" by group (PT1 to PT11) with their tests. Then the five-ending bot gate: it ran 01:52 to 07:04, the session sat idle 01:53 to 06:00 waiting on it, and the owner wrote "u got stuck? cont". At 07:03 the owner banned the bot. The report at 08:33 said "all 70 playtest items ... are done". |
| Audit and replan | 11-06 08:34 to 15:13 | 6.7 h | 0.5 h | 3 | The owner asked what was missed. An audit found 9 items not met and 4 unverified. 11:47: "ive literally lost all trust on your reviews". PS was planned, the owner answered 4 design questions at 12:23, and then nothing ran for 2.8 h after "starting now". |
| PS0 and PS1 | 15:13 to 22:20 | 7.1 h | 2.7 h | 6 | Ledger, shot harness, old-save fixture, items 17, 17b and 65, and the batched check of 53 claimed items (36 held, 11 failed, 6 had no evidence). Then the session stopped from 18:32 to 22:20, until the owner asked "Did you stop?". |
| Serial item loop | 22:20 to 11-07 08:17 | 9.9 h | 2.8 h | 14 | PS9, PS4, PS5, PS7, one item at a time. After every item the full suite ran (25 to 45 min) before the commit, which left nine idle gaps of 25 to 45 min in a row. At the end, 52 min waiting for the owner to run /compact. |
| Two at once | 11-07 08:17 to 13:15 | 5.0 h | 4.0 h | 38 | After the owner asked for speed: one Opus worktree agent plus the main session, and the suite on a snapshot (tools/suite_snapshot.sh). Most of the PS owner items landed here. |
| Bench, perf, verdict rounds | 11-07 13:15 to 11-08 07:32 | 18.3 h | 4.9 h | 26 | PS13 rounds 1 to 3. Re-fixes of 9, 43 and 65. G10 (the input batch's flakes) took six batch runs of 75 to 116 min each. G11 (perf) took five commits and is still NOT-MET. G12 (Proton). G18 (the session's own writes into the owner's log folder, twice). |

### By category (the whole 59.7 h)

| Category | Hours | Evidence |
|---|---|---|
| Main session active (fixes, renders, ledger, reviews of agent diffs) | ~21 | gaps of 10 min or less |
| Waiting on a background run, nothing else in hand | ~17.5 | gaps that ended on a task notification |
| Stopped until the owner wrote | ~12 | 01:53 to 06:00 (bot), 12:23 to 15:13 (announce, then idle), 18:32 to 22:20, the 07:25 /compact wait, plus 2.2 h after the false "all done" |
| Stalls around a context compaction | ~5.5 | 8 compactions in this sprint. One session has run since 10-22, and its transcript is 622 MB |
| Other short gaps | ~3.8 | |

Background runs, measured from launch to notification (they overlap with the rows above): the
full GUT suite **17 runs, 10.8 h**; real-input batches **14 runs, 7.3 h**; renders and probes
2.9 h. Owner interruptions were cheap in time but expensive in trust: four "are you stuck"
checks, one audit and one trust break. The owner sent about 16 messages in the whole sprint.
Merges were cheap: 11 cherry-picks from worktree agents, but 5 of them conflicted on
DECISIONS.md or the ledger, and each conflict was resolved by a regex script.

### Rework, counted

- **The whole PT sweep was verified twice.** It claimed 70 of 70 in 12.8 h. PS re-opened all 70,
  and the batched check found 17 of the 53 claims failed or had no evidence.
- **17b (merging) was fixed four times**: 874f649, 0fc413f, 835597c, c255da7. The fourth fix's
  turn rule held 89% of pen residents' wander ticks, which is why 65 was NOT-MET in round 1. It
  also cost 4.5 times the physics time at 60 ponies (770455c), which became G11: five commits
  over about 10 h, and still NOT-MET.
- **65 (pen pile-up) was fixed three times** (874f649, 6977d2c, daa8695). It came back.
- **9 (tail) was fixed three times** (be8a013, d5decf6, 37cedd0). A different tail bug came back.
- **29 (doors)** was fixed, re-opened for the town row, and fixed again (a8985f3, 1d581f3, f341692).
- **PS13 ran three rounds:** 83 MET and 6 NOT-MET; then 8 MET and 3 NOT-MET; then 4 MET and 1 NOT-MET. Rounds 2 and
  3 were almost all bench rows (G10, G11, G12), not owner items.

## 2. Root causes of slowness, ranked

1. **Turns ended with work left and nothing running (about 12 h).** The no-announce-then-idle
   memory was written on 11-06 at 15:14, after the first case. The same pattern happened again
   at 18:32 that day (3.8 h). The owner had to wake the session four times.
2. **The full suite gated every commit, and the session waited on it (about 17.5 h of waits; 17
   suite runs, 10.8 h).** From 22:20 to 07:17 every item ended with "a full suite run is going
   over it now; I'll commit once it passes", followed by 25 to 45 min of nothing. The suite never
   once caught a fault that the focused tests had missed. tools/suite_snapshot.sh fixed this at
   08:18 on 11-07, a day and a half in.
3. **Doing the sweep twice.** PT ticked items because a commit named them (see
   tick-only-with-evidence). The fix for that, PS, cost the audit (6.7 h), the ledger and
   harness, a batched re-check and three acceptance rounds. A correct first pass would have
   saved most of a day.
4. **Bench and infrastructure work grew without a time-box (most of the last 18 h).** G10 was a
   test-harness flake: about 9.6 h of batch runs, plus fixes to the harness itself. G11 is a perf
   target the sprint itself regressed. G12 is a Proton boot. G18 was self-inflicted log writes.
   None of it is visible to the owner, and the 05 playtest did not ask for any of it.
5. **The forbidden or low-value gate ran anyway: the five-ending bot, 5.2 h, 4.1 h of it idle.**
   On 11-05 at 16:44 the owner had said "dont waste time on long play tests". The bot did find one
   real bug, the lake ledge, which a focused test then pinned.
6. **Context churn.** There were 8 compactions in 60 h. Each one re-reads 300 KB of status docs
   (DECISIONS 100 KB, ledger 80 KB, PLAN 63 KB, packet 91 KB, PROGRESS 35 KB), and three of them
   sat next to stalls of about an hour. The session asked the owner to run /compact and then
   waited 52 min.
7. **Fixes that broke something the next gate measured.** The 17b turn rule caused both 65's
   clump and the G11 perf regression. The G10 beam fix changed how the game plays (see 3.3).

## 3. Root causes of the gaps and regressions, ranked

### The repeats, item by item

| 11-08 item | Was | What the sprint did | Why it didn't hold |
|---|---|---|---|
| 28 Rarity pitched nose-down in a crowded pen in the rain | 05/17 | It found two causes: the borrowed graze and sleep folded the Mane Six neck 66 degrees (test_mane_six_neck), and [52] was the corner heap of item 65. twist_probe.gd measured "lean at most 3.1 degrees" in a 2-minute calm Paddock. Verdict MET on a before/after neck render. | The probe ran on 11-06, before four later changes to the same bodies: joy hops with a rump kick (1a239a5), ring spots and the turn hold (daa8695, c255da7), and drawing between ticks (37cedd0). It was never run again. It never put a packed pen, rain or a moving player together. Only one owner situation (the neck fold) was checked. |
| 29 Pen ponies pile into the corner nearest the player, clip through each other and the fence | 05/65 | Fixed three times. The final fix gives each resident her own spot on a 2.25 m ring. test_pen_spread checks nearest-neighbour spacing. Renders at 60 and 75 s. MET in round 2. | The test puts a **stand-in "farmer" body, frozen at one corner**, beside one isolated pen, and the renders were taken with the player disabled. The owner walks up to packed pens. The "watch, don't approach" rule only covers a resident in a routine state that is not WANDER (pony.gd ~1508). The condition that triggers the bug (a live player walking up to a full pen) was never put on screen. |
| 30 Tail flips over the back into the mane on a jump; odd while running | 05/9 | Fixed three times. The final fix draws her body and camera between physics ticks. It was measured with great care: tail jerk per drawn frame went from 1.993 to 0.135. MET in round 2. | The probe (tail_frames.gd) **only walks straight for 3 s**. Jumping and galloping were never sampled. The same sprint added HAIR_THROW (the bounce throws the mane and tail on landings, at the owner's request) and a hard-landing stumble (f7d0000). Both act exactly at a jump landing. The fix was correct for the narrow symptom it measured; the owner's real complaint was "the tail looks wrong in motion". |
| 56 Casino crowd cloned, floating, clipping, nobody plays | 05/44 | Every regular and staff member runs a routine of clips, and slot regulars change machine. test_casino_patrons counts the clips started. The hall strip is 4 stills 30 s apart. MET: "a different pose in each frame". | The item was cut down to the literal word "frozen". The owner's surrounding words that night were "cmon this can look so much prettier". The evidence proves that something changes. It does not show a believable crowd: still frames 30 s apart cannot show floating, clipping or cloned coats. Nobody checked the patrons at their new positions after the Palace and building changes. |
| 43 Signs flat, vanish edge-on, walk-through; fingerpost arms overlap | 05/14 | PT7 made each board "solid or gone": PlaceSign hides a board within 1.4 m or when it stands between the lens and the player. The evidence was **one frame** ("single frame, not the planned 120-frame strip", in the ledger). MET. | The fix for the flicker *is* the new complaint: boards that vanish. The owner's other sign words on 11-05 ("signs dont have white bg", "these look bad") were folded into "flicker" when the list was written. Edge-on views and walking into a sign were never rendered. The plan's 120-frame walk-past was downgraded to one still. |

### The causes, ranked

1. **Items were checked in a calm scripted scene, not in the owner's situation.** The table
   above has five cases. The PS Review Focus did name night, rain and the Mane Six rig, but it gave
   "night and rain" only to the world items (PS4), never to pony bodies or pens. No check
   combined crowd, weather and a moving player.
2. **The owner's words were narrowed before anyone checked them, and the review then judged the
   narrowed text.** The 05 list was written by the agent and carries its own diagnoses inside the
   item ("Likely retarget/HoofPlanter on the Mane Six rig", "PlaceSign blocking-fade toggling").
   Those anchored the fixes. The reviewer saw only the one-line item, so "frozen" became "do
   their poses change", and that passed. Every one of the 89 MET verdicts is only as good as the
   wording it was judged against.
3. **Fixes to shared systems were never checked against earlier items or the rest of the game.**
   Each item was checked once, at the moment it was fixed. Later changes to pony.gd, pen.gd and
   the bodies did not trigger another look at 17, 65 or 9. Changes likely to have caused new
   11-08 items (none of these is confirmed by a render yet):
   - Buildings grown 1.9 to 2.8 times from their door fronts (a8985f3) on the same footprints → "the town is crowded" (42), scale misses (48), "the Depot prompt wins over talking to Marigold" (17), "a board floats detached from the building" (45).
   - G10's harness fix `_keep_over_ground` (2d9c055): when you aim low, a held pony is set on the terrain → "a caught pony sometimes stays on the ground in the beam" (24). A fix for a test flake changed how the game plays and was never rendered.
   - Item 59 made toasts hold longer → after a 55-pony Depot run, "one toast per shipment, played back for minutes" (21).
   - Signs "solid or gone" → signs vanish (43).
4. **Systems were checked by a model or a unit test, never in play.** PS9's pacing bands were
   enforced by test_pacing_model, which replays one sell-the-repeats strategy. It has **zero
   mentions of Bloom**, and the "first hour" count was left to the owner. The owner cleared the
   debt in about 1 hour and got every legendary in 65 minutes (11-08 items 6 and 4), then stalled on
   Bloom for 25 minutes. Bloom has two constants that contradict each other: CROWDED_AT 7 in a
   game whose Grand pen holds 8 and whose pens the economy pushes you to fill. Bloom also tells the
   player nothing about it. Any test that read both constants would have caught this.
5. **The story path was never exercised branch by branch.** The Color Day soft-lock (11-08 item
   1) is in data/dialogue_src/act2.txt from 3f77648 (10-22). The `wait` branch ("Give me a
   minute") ends with no event, and the lift choice never comes back. The bot always took the
   main branch, and after the ban nothing replaced it. No test walks the dialogue graph.
6. **Owner-visible quality was below the bar even where the item was "met".** The visual-quality
   memory says "built modern, fun and engaging at birth". The casino, creator, signs and town
   met their rows and still read as cheap. Items 37, 56, 65 and 79 in the 11-08 list ask for a
   references pass because of this.

For scale: of the 70 items from 05, four came back tagged "was 05/NN" (17, 65, 9, 44) and one more
without a tag (14, the signs), and a handful more came back as neighbours (69 in 6 and 23, 64 in
10, 33 in 4, 66 in 73). Most items held. The owner played 1 h 45 min and reached Color Day; on
11-05 they quit early on a soft-lock in the Depot.

## 4. Process changes for the next sprint

Each one is meant to be checkable after the fact.

### Verifying items

1. **A situation column in the ledger.** Fill it from the owner's raw words and screenshot: who,
   where, crowd size, weather, time of day, and what the player was doing (walking, jumping,
   holding, standing at a corner). The evidence render has to reproduce *every* condition in it.
   *Check:* test_ledger_complete fails when the column is empty, or when a render path lacks the tags (`_rain`, `_night`, `_crowd8`, `_jump`).
2. **The owner's words go in verbatim, and the diagnosis goes in a separate column.** The
   acceptance reviewer gets the owner's chat lines and screenshots for the item, not the
   one-line summary. *Check:* the packet builder (tools/ps13_packet.py) pulls the raw lines.
3. **A stress scene for bodies and pens:** `scenes/test/stress_pen.gd`. A Grand pen of 8 with mixed
   rigs (Mane Six and PonySFM), the live player walking to each corner and jumping, rain then
   night, 120 s, and a 5 fps contact sheet. Any change to pony.gd, body_space.gd, pen.gd,
   rump_bounce.gd, hoof_planter.gd or the player's hair re-runs it, and the main session looks at
   the sheet before committing. *Check:* a sheet newer than the commit, linked in the row.
4. **A standing regression sheet**, about 15 fixed shots of the places where repeats happen: a full
   pen with the player at a corner, a Mane Six landing, the player's tail on a jump, the casino
   hall, the fingerpost edge-on and walked into, a town overview, the Depot front with Marigold,
   the beam aimed low. One script regenerates it after each batch, side by side with the previous
   sheet. It takes about 5 minutes, and the main session looks at it. *Check:* one sheet per batch
   in build/ps_evidence/regression/.
5. **Motion is shown in motion.** Any item about movement (tail, tipping, crowd, patrons) gets a
   strip or clip at 5 to 10 fps through the action named in the item. Stills taken 30 s apart do
   not count.
6. **A test-harness fix may not change game code without a render of how the game now plays**
   (lesson from 2d9c055).

### Scope and batching

7. **Triage the list first, into blockers, repeats, feel, art (needs a reference first) and
   wanted.** Fix blockers and repeats first. Art items wait for the references pass that PLAN P8
   already names.
8. **Batch by system:** pens and bodies, story and economy, town, casino, UI. Each batch ends with
   its stress or regression sheet and goes to acceptance. A sweep is not one long serial list.
9. **Time-box bench and infrastructure work to 2 hours a row.** Past that, log it in DECISIONS and
   move on. Perf and Proton belong to their own task, not to an owner playtest sweep.
10. **Show the owner something mid-sprint.** After the blockers batch (about 8 to 10 h in), make a
    build that starts from a save at the right spot, so the owner can spend 15 minutes checking the
    top items. This replaces the long silence and the wrong "all done".

### Two agents at most

11. **The main session plus one Opus 5.5 worktree agent, from hour 0, not hour 36.** The agent
    gets a batch whose files do not overlap the main session's. **The agent never edits PLAN,
    PROGRESS, DECISIONS or the ledger.** It returns its ledger rows in its report and the main
    session pastes them in, which removes the 5 cherry-pick conflicts. The brief keeps the
    pace-two-at-once setup steps.
12. **Fable runs once per batch, for acceptance only**, with the raw owner lines and the
    situation renders. Rounds 2 and 3 should not go to bench rows.
13. **While the agent runs, the main session works its own batch.** If the main session has
    nothing to do, the batches are too small.

### Gates

| Gate | Keep or drop | When |
|---|---|---|
| Focused GUT on the files touched | **Keep** | Every commit (minutes) |
| Full GUT suite | Keep, but **never wait on it to commit** | On a snapshot (suite_snapshot.sh) once per batch, in the background. Commit first; revert if it fails |
| Real-input batch | Keep, **once** | End of the sprint, a single run. Flakes are logged; a fix costs at most 2 h |
| Stress scene and regression sheet | **Add** | Per batch, looked at |
| Dialogue-graph and story-reachability tests | **Add** | In the focused set for any dialogue or story change; always in the full suite |
| Both exports and a boot | Keep | End of the sprint |
| Perf p99 | **Drop as a sweep gate** | Its own task |
| Bot playthroughs | **Dropped** (owner's rule) | Never |
| Owner log and save folder untouched | Keep (the launcher enforces it now) | Automatic |

### Catching soft-locks without bots

14. **A dialogue graph test (GUT).** Parse every data/dialogue_src/*.txt. For each conversation that
    gates story (it fires an event, or sets a flag that a later `when:` needs), every leaf branch
    must either fire that event or set that flag, or leave the conversation offered again next
    time. This would have failed on act2.txt's `wait`. It is a static check: no game launch, about a
    second.
15. **A story-reachability test at each story beat.** For each chapter step, load a fixture save
    taken at that beat (written by a script like make_old_save.gd), then assert at data level that
    the objective names a target, that the target NPC or site exists, and that her talk prompt wins
    over any building prompt within its radius. That last check covers 11-08 item 17.
16. **Constant cross-checks.** Bloom's CROWDED_AT against the largest pen capacity; the pacing
    model gets time to first Bloom and the order of debt-cleared against the first collection-day
    letter (11-08 item 6); the autosave interval has a ceiling (11-08 item 3).

### Keeping the 3 status docs current without the cost

17. **The ledger is the single source of truth for items.** PLAN gets a script that generates its
    ticks from the ledger, and no hand edits. PROGRESS gets one line per batch with a link. DECISIONS
    is only for real design calls, 1 to 3 lines each. In this sprint, 85 of 122 commits touched a
    status doc, and DECISIONS alone is 100 KB.
18. **Write the verdict back into the ledger.** 89 of the 90 rows still say FIXED-UNREVIEWED, even though
    PS13 judged every row MET except G11. The report the owner reads should not disagree with itself.
19. **A resume file of 60 lines or fewer** (current batch, next 5 steps, open rows), re-read after a
    compaction instead of the 300 KB of docs. **Start a fresh session per sprint**: the current one has
    run since 10-22.

### Not stalling

20. **Before ending a turn, either something is running in the background and the next task is
    already in progress, or the plan is finished or blocked on the owner, and the message says
    which.** *Check:* no transcript gap over 20 minutes that does not end with the owner's
    message. The owner could add a Stop hook that refuses to end a turn while the plan has open
    rows and the owner has not asked for a stop. That is the owner's call, since it changes settings.
21. **Compact at batch boundaries, on the session's own initiative,** rather than waiting on the
    owner.

## 5. What worked; keep it

- **Two at once** (11-07 08:17 to 13:15): 38 commits in 5 h, with 4 h of main-session activity
  out of 5. Most of the PS owner items landed in this one stretch. The setup notes in the
  pace-two-at-once memory are right.
- **tools/suite_snapshot.sh.** Editing carries on while the suite runs, and failures are listed by
  name.
- **The ledger and an independent acceptance reviewer.** Round 1 caught 9, 43 and 65 as NOT-MET.
  Round 2 found that the claimed Proton boot had actually printed RANCH_FAILED. Round 3 caught the
  owner-folder log writes. The mechanism works; it was fed narrowed words and calm scenes.
- **Measuring before fixing.** Doors were measured in pony heights before buildings were scaled.
  The tail was measured per drawn frame. 17b got a seeded frame-by-frame trace. The old-save
  fixture found a real duplicate-pony bug (39, 63, 70) on day one.
- **Design calls as one batch of questions** (11-06 12:23). The owner answered four big calls in
  minutes, and they were logged once.
- **The launcher guard** (tools/godot_launch.sh) and `user://automated_saves` for scripted runs.
  These close a whole class of accidents in code instead of relying on discipline.
- **Most items held.** About 65 of the 70 items from 05 did not come back by name, and the owner got
  further into the game than ever (Color Day, every legendary, the debt paid).

## Caveats

- The hour splits come from gaps in the main transcript. Work by subagents, and time the owner
  spent reading, are not in "active".
- The suspected causes marked as likely in 3.3 (buildings, beam, toasts) come from reading the
  code and the commits. Nobody has rendered or tested them yet. Treat them as the first things to
  check in P8, not as findings.
