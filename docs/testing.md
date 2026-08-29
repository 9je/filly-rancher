# GUT unit-test harness

Headless GDScript unit testing for this project, via
[GUT (Godot Unit Test)](https://github.com/bitwes/Gut).

> **Note:** this doc is not yet linked from `docs/pipeline.md` — a concurrent
> edit to that file's §6 was in flight when this was written. A later task
> should add a link to this file from `docs/pipeline.md` (e.g. a short
> "Testing" section or a pointer near §7's validation commands).

---

## Running the suite

```bash
bash tools/run_tests.sh
```

Runs every `game/test/test_*.gd` script headlessly through GUT's CLI runner:
**0** if every test passed, **non-zero** if any test failed (or if GUT itself
errored). Output names every failing test and the line it failed at.

**Exit 0 means more than GUT's own exit code**, which has twice now reported
success for a run that verified far less than it claimed. Before GUT is invoked
at all the script parse-sweeps every `game/**/*.gd` outside `addons/` (see "The
parse sweep" below). On top of GUT's
result it then hard-fails if zero tests ran, if any `test_*.gd` file on disk
was not executed, or if the test count fell below a floor — see the three
invariant sections below. This is the one command every later
gameplay task's tests run through — add new test files under `game/test/`
following GUT's default naming convention (`test_*.gd`, one `test_*()`
method per case) and they are picked up automatically, no registration
step needed.

Example failing output:

```
res://test/test_smoke.gd
* test_harness_reports_failure
    [Failed]:  [1] expected to equal [2]:  deliberate failure
      at line 9
...
---- 1 failing tests ----
```
exit code `1`.

Example passing output:

```
res://test/test_smoke.gd
* test_harness_reports_success
1/1 passed.
...
---- All tests passed! ----
```
exit code `0`.

---

## The parse sweep (runs before GUT)

`tools/run_tests.sh` hands **every** `game/**/*.gd` outside `game/addons/` to
the engine's own front end before a single test runs:

```
tools/bin/godot --headless --audio-driver Dummy --path game --check-only --script <res://path>
```

Any file the engine refuses fails the run, all of them are named, and GUT is
never reached.

**Why this is not something GUT already does.** GUT loads *test* scripts, and
the two guards further down this file catch a test script that failed to load.
Neither says anything about the other hundred-odd scripts in the project, and
those are loaded by *scenes*, not by GUT. The failure that motivated this
shipped on the slice 5 branch: `var x := <something statically typed Variant>`
compiles far enough for GUT to run the whole suite green, and then Godot's
analyzer, which the editor and every scene load **do** run, promotes
`INFERENCE_ON_VARIANT` from a warning to an **error**, so the scene that
preloads that script will not open. Green suite, broken game, and nothing
anywhere said so. `--check-only --script` is the same front end a scene load
goes through, which is exactly why it catches this and GUT does not.

**Cost.** One engine process per file, about 0.7 s each: a little over a minute
for this project's ~108 scripts, against ~2.5 minutes for the GUT run itself.
Paid up front on purpose. Batching several files into one process would be
faster and would lose the property that makes the output useful, which is that
a failure names one path.

**The local iteration hatch.** `FILLY_SKIP_SWEEP=1 bash tools/run_tests.sh`
skips the sweep and goes straight to GUT:

```
Parse sweep: SKIPPED (FILLY_SKIP_SWEEP=1). Local iteration only; CI always runs it.
```

It is for the fifth re-run of a test you are in the middle of writing, where the
minute buys nothing you did not learn on the first run. **CI never sets it and
no gate sets it**, so nothing merges on a run that skipped it; and a run that did
skip it says so on its own line, so a log cannot be mistaken for one that passed
the sweep. Run the suite once without it before calling anything finished.

**Proving the guard.** Drop a file into `game/systems/` containing
`var x := {"a": 1}.get("a")` and run `bash tools/run_tests.sh`: it exits 1 with

```
ERROR: 1 of 109 GDScript file(s) do not parse; the suite was NOT run.
  res://systems/zz_sweep_probe.gd
```

and no tests run. Delete the file and the suite is green again. That exact
script passes GUT untouched, which is the point.

---

## Installation

GUT is installed as a Godot addon under `game/addons/gut/` by
`tools/setup_env.sh` (same bootstrap that vendors Godot/Blender/SourceIO —
see `docs/pipeline.md` §1). Re-running it is a fast idempotent no-op once
GUT is present.

**Version pin: GUT 9.5.0.** GUT's own README compatibility table
(`https://github.com/bitwes/Gut/blob/master/README.md`, "Version Links"
section) lists this as the release for Godot `4.5.x` — the row matching
this project's pinned Godot `4.5.2`. Newer GUT releases (9.6.x, 9.7.x) are
pinned to Godot 4.6.x/4.7.x respectively per that same table; do not
casually bump to "latest" without checking the table against whatever
Godot version this project is pinned to at the time.

**Install-vs-commit decision: fetched by `tools/setup_env.sh`, gitignored
(`game/addons/gut/` is a dedicated `.gitignore` entry), not committed.**
`game/addons/` itself is deliberately *not* blanket-ignored (so a
first-party or intentionally-committed addon dropped elsewhere under it
still tracks normally) — only the `gut/` subdirectory is excluded. This
mirrors the existing pattern for every other third-party dependency in this
repo (Godot, Blender, SourceIO all live in `tools/bin/`, gitignored, fetched
by pinned-version+checksum): GUT is vendored code, not hand-authored project
code, so a version bump is a one-line change to `setup_env.sh` rather than a
multi-hundred-file diff, and the repo never carries two copies of the same
addon (a stale committed one plus whatever `setup_env.sh` fetches). A fresh
checkout is not test-ready until `bash tools/setup_env.sh` has run — same
precondition the rest of the pipeline already has for Godot/Blender/
SourceIO/converted assets.

**No addon-enable step needed.** Unlike SourceIO (which must be registered
+ enabled into Blender's home-dir user prefs to load at all, see
`docs/pipeline.md` §1), GUT's headless CLI entry point
(`addons/gut/gut_cmdln.gd`) is invoked directly via Godot's `-s` flag and
loads its own dependencies by `res://` path — it does **not** need to be
listed in `game/project.godot`'s `[editor_plugins]` block to run tests.
(Enabling it there only matters for the *GUI* test-runner dock inside the
editor, which this project does not use.) Verified by running the CLI
against this project's unmodified `project.godot` (no `gut` references in
it at all) and observing tests execute and report correctly.

---

## Quirk / invariant: GUT can exit 0 having run zero tests

**GUT's own process exit code is not trustworthy on its own.** Its CLI
entry script calls `quit(0)` — success — in more than one situation where
it actually executed zero tests. Two confirmed:

1. **Import cache not populated yet.** Immediately after
   `tools/setup_env.sh` installs/updates GUT (or on a fresh checkout with
   no `game/.godot/` import cache yet — that directory is gitignored, same
   root cause as the `.glb` import-cache quirk documented in
   `docs/pipeline.md` §7), running the suite prints:

   ```
   ERROR: Some GUT class_names have not been imported.  Please restart the Editor or run godot --headless --import
   Missing class_names:  ["GutErrorTracker", "GutHookScript", ... "GutTest", ...]
   ```
   and still exits 0.

   **Fix, one-time per fresh checkout / per GUT install:**
   ```bash
   tools/bin/godot --headless --path game --import
   ```
   (~5-6s; safe to re-run, and harmless/idempotent afterward — it also
   reimports any converted `.glb` assets present, same command the
   `--editor --quit-after 60` workaround in `docs/pipeline.md` §7 is an
   alternative to.)

2. **No test scripts matched.** `-gdir` pointing at an empty or
   nonexistent directory — a future path typo, an emptied `game/test/`, a
   renamed test file — prints:
   ```
   ERROR: Nothing was run.
   On the one hand nothing failed, on the other hand nothing did anything.
   ```
   and still exits 0.

Enumerating each such message as it's discovered is a losing game — the
next unknown variant that produces zero executed tests would slip through
the same way a bare `bash tools/run_tests.sh && echo tests passed` did for
both cases above. Instead, **`tools/run_tests.sh` enforces the invariant
directly: a real GUT run always ends with a `Totals` summary block
containing a `Tests   <N>` line, the count of tests it actually executed
(pass or fail). The script parses that count out of GUT's captured output
and hard-fails — regardless of GUT's own exit code — if it is zero or the
line can't be found at all.** This subsumes both cases above and any other
zero-tests-executed failure mode, known or not, in one check. The known
causes above are still grepped for afterward, but only to attach a better
diagnostic message to the failure — that string-matching is no longer what
stands between a real problem and a false pass.

This is the same "never let a success claim outrun what was actually
verified" discipline `tools/setup_env.sh`'s `SOURCEIO_OK`/`GUT_INSTALL_OK`
marker gates follow (see `docs/pipeline.md` §1) — a previous review caught
this codebase's setup script claiming success on an unverified step, and a
later review caught this harness doing the same thing (grepping for one
known failure string instead of asserting the actual invariant), so this
harness does not repeat either mistake.

**Testing the guard itself, safely.** `tools/run_tests.sh` reads a
`GUT_TEST_DIR` env var (default `res://test`) so the zero-tests-ran guard
can be exercised against a bogus directory without touching the real
`game/test/`:

```bash
GUT_TEST_DIR="res://nonexistent_test_dir_xyz" bash tools/run_tests.sh
```
exits 1 with `Likely cause: no test scripts matched in
'res://nonexistent_test_dir_xyz' ...` even though GUT itself reported exit
0. The import-cache case (cause 1 above) was reproduced the same way but
needs a *whole separate Godot project* with no import cache at all — an
addon copied into a throwaway temp directory with a minimal
`project.godot` and no prior `--import` pass — since the real project's
`game/.godot/` is already populated and shared with other in-flight work.

---

## Quirk / invariant 2: GUT silently SKIPS a test script that fails to parse

**This is the same family of hole as the one above and it is not covered by it,
because the number of tests that ran is not zero.** A test script with a parse
error — a `preload` of a file that does not exist yet, a syntax error, a bad
merge — never loads, so GUT never sees a `GutTest` in it. It logs a warning,
runs the *other* scripts, and reports a clean sweep. Observed, verbatim, while
writing Phase 1B Task 2 (two new test files, their implementations not written
yet):

```
[WARNING]:  Ignoring script res://test/test_save_io.gd because it does not extend GutTest
...
Scripts              13
Tests               149
Passing Tests       149
---- All tests passed! ----
```

exit code `0`. Twelve tests and two whole scripts had vanished from the suite
while it claimed success.

**The invariant with teeth is counting the files on disk.** Every
`test_*.gd` in the test directory is a script GUT is supposed to run, so the
`Scripts <N>` count in its Totals block must equal the number of files sitting
there. `tools/run_tests.sh` compares the two and hard-fails on any shortfall,
regardless of GUT's exit code, printing the `Ignoring script` / `Parse Error`
lines as a diagnostic. This number maintains itself — adding a test file raises
both sides at once — and it subsumes every skip cause, known or not, the same
way the zero-tests guard subsumes every zero cause. (`-maxdepth 1`, matching
GUT's own default of not descending into subdirectories without
`-ginclude_subdirs`, which this script does not pass.)

**And a floor on the test count**, for the half the script count cannot see: a
file that still parses but has lost most of its tests (a mass rename, a bad
merge, a `func test_x` that became `func x`). `MIN_TESTS` in
`tools/run_tests.sh` — currently **299** — is a deliberate FLOOR rather than an
exact count, so adding tests never breaks the build. Raise it when the suite
grows; never lower it without saying in the same commit which tests went away
and why. (It was 194 through Phase 1A and was raised to the suite's real size in
Phase 1B Task 3 — a floor a hundred tests below the actual count could not have
caught a whole test script going missing, which is exactly the failure the
paragraph above describes.)

**Proving both guards, safely:**

```bash
# 1. Skipped-script guard: break a test script's syntax, then run the suite.
printf '\nfunc test_broken() -> void:\n\tvar x = = 3\n' >> game/test/test_gait.gd
bash tools/run_tests.sh    # exit 1
git checkout game/test/test_gait.gd

# 2. Test-count floor: FILLY_MIN_TESTS overrides it, so the guard can be
#    exercised without deleting real tests.
FILLY_MIN_TESTS=99999 bash tools/run_tests.sh   # exit 1
```

Both were run. Guard 1 printed, over the top of GUT's own
`---- All tests passed! ----` and exit 0:

```
Scripts              14
Tests               176
---- All tests passed! ----
ERROR: GUT ran 14 test script(s) but 15 test_*.gd file(s) exist in game/test/ --
  1 script(s) were SILENTLY SKIPPED and their tests did not run. Failing
  regardless of GUT's own exit code (0).
  [WARNING]:  Ignoring script res://test/test_gait.gd because it does not extend GutTest
```

Guard 2 was proved the harder way as well, by renaming one real test method out
of `test_gait.gd` so the file still parsed with one test fewer (the floor stood
at 190 when this was run; four tests were added afterwards, hence 194 today):

```
Tests               189
---- All tests passed! ----
ERROR: GUT ran 189 tests, below this suite's floor of 190 -- tests have gone
  missing. Failing regardless of GUT's own exit code (0).
```

---

## Quirk / gotcha 3: ~19 failing tests (not zero) after a fresh checkout or an asset regen

**This is the same root cause as cause 1 above (a Godot import cache that
hasn't caught up), but it does NOT go through the zero-tests guard, because
it is not a zero-tests failure.** GUT's own bootstrap is fine — its
`class_names` are already registered, so the suite actually runs all 131
tests — but a `.glb` under `game/assets/converted/` was (re)generated by the
asset pipeline (or this is a genuinely fresh clone that has run the asset
pipeline but never done an editor `--import` pass, see `docs/pipeline.md`
§7) since the last time Godot imported it. Loading that model at runtime
fails, and every test that depends on a real pony or the player's body goes
red with it: **two people have now lost time to this**, because unlike
cause 1, nothing printed a hint at all.

Symptom, verbatim (real numbers seen; exact chains/counts hit will vary):

```
<push_error>PonyVisuals.build: pony 'twilight' model_path 'res://assets/converted/ponies/twilight.glb' did not load as a PackedScene

res://test/test_player.gd
- test_...
    [Failed]:  Expected [<null>] to be anything but NULL:  the player's body must build with a reachable AnimationPlayer
...
Totals
------
Tests               131
Passing Tests       112
Failing Tests        19
```

**Fix — identical one-time command as cause 1:**
```bash
tools/bin/godot --headless --path game --import
```

`tools/run_tests.sh` now greps its own captured output for `did not load as
a PackedScene` whenever GUT's exit code is non-zero (not only when the
tests-run count is zero) and prints the same "run `--import`" hint if it
finds it — best-effort and cosmetic, exactly like cause 1's diagnostic,
since a resource that genuinely fails to load for some other reason would
print the same engine message and deserves the same first thing to try.
Reproduced by deleting one pony's cached import artifacts
(`game/.godot/imported/twilight.glb-<hash>.{scn,md5}`) without touching
`game/assets/` at all — that alone reproduces the exact 19-failing-tests
shape above, and re-running `--import` (or, as done for this reproduction,
restoring the cache) turns the suite green again.

---

## Files

| Path | Role |
|---|---|
| `game/addons/gut/` | The GUT addon itself (gitignored, fetched by `tools/setup_env.sh`) |
| `game/test/test_smoke.gd` | Harness smoke test — proves GUT reports failures with a non-zero exit, not just passes |
| `tools/run_tests.sh` | Entry point: `bash tools/run_tests.sh` |
| `tools/prove_atomic_save.sh` | Out-of-band proof that an interrupted save cannot destroy the previous one — see below |
| `game/scripts/prove_atomic_save.gd` | The phases that script drives (seed / SIGKILL mid-write / verify) |
| `game/scenes/test/collection_test.gd` | The collection gate (see below) |
| `tools/setup_env.sh` | Installs/pins GUT (`GUT_VER`/`GUT_SHA256`, near the SourceIO block) |

---

## The market gate

`scenes/test/market_test.tscn` proves the loop a unit test cannot: a gem a
pony produces, sold for bits, bits spent on hay, a hungry pony fed, the save
reloaded with the same gems and inventory intact, and the pause menu opened
and closed without leaving the tree paused.

It instances `world/ranch.tscn` in hosted mode rather than launching it: the
hosted ranch arms no watchdog of its own, hands its verdict over as
`gate_report_finished` instead of quitting the process, and the gate calls
`GameState.reset()` for a known empty pouch and inventory instead of loading
the player's own save slot.

Run it with:

```
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/market_test.tscn
```

Expect `MARKET_OK checks=69`; the exit code is the verdict.

---

## The region gate

`scenes/test/region_test.tscn` proves the unlock loop a unit test cannot: four
rings of timber standing shut around the four regions of the shipped map, the
residents of each region spawned inside it, the orchard's gateway solid to the
player, its permit priced in the Market and out of reach on an empty wallet,
two legendary gems sold to pay for it, that one gate swinging open while the
other three stay shut, the same walk now carrying her into the region, the
permit refused a second time, and a save, reset and reload putting the regions
back the way the file says rather than the way the session did.

It hosts `world/ranch.tscn` exactly the way the market gate does, and for the
same reasons.

Both gate checks DRIVE the player rather than casting a ray at the leaf. A ray
says a collider is there; only a body that tried says she cannot get past it.
`ranch.player` is placed 4 m outside `gate_position()` on the gate's outward
bearing and walked toward a point 4 m inside it with `move_and_slide()` over 90
physics frames, and the verdict is her flat distance from the region's centre:
outside the fence line with the gate shut, at least 2 m inside it with the gate
bought. Every drive also asserts that she moved at all, because "she did not get
in" is trivially true of a body that never moved.
`game/test/test_region_fence.gd` asks the same question of a fence on a flat
plane in a bare scene; this asks it of the fence the shipped map stands, on the
shipped terrain, at the shipped radius, with the shipped permit paying for it.

Run it with:

```
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/region_test.tscn
```

Expect `REGION_OK checks=47`; the exit code is the verdict.

---

## The world gate

`scenes/test/world_test.tscn` proves the clock a unit test cannot: a fresh
ranch opening at dawn with the clock on zero, two minutes of play carrying it
into day and nine more into dusk, the sky rig aimed at whichever hour the clock
is actually on, the weather at every phase of a full cycle equal to what
`WorldState.weather_for(seed, cycle, phase)` says that seed rolls, the HUD line
repeating the clock's own `describe()`, a save writing `world_time` into the
file on disk and a reload resuming the same second in the same phase and the
same weather, and a pinned stormy night thickening the fog to the storm's
density and turning the rain on.

It hosts `world/ranch.tscn` exactly the way the market and region gates do, and
for the same reasons.

`game/test/test_world_state.gd` proves the arithmetic and
`game/test/test_sky_rig.gd` proves the palette, both without a scene. Neither
can see the wire between them, and the wire is what breaks: a rig never handed
the state, a HUD label nobody pushes to, or a load that restores
`GameState.world_time` into an object no longer driving the sky all pass every
unit test in the suite and all leave the player with a sky that stopped.

Two things about how it reads the clock are worth knowing before editing it.
It reads the state through `ranch.get_world_state()` **after** the hosted
ranch's report has finished, never by parsing the `RANCH world` line that
report prints: a gate that scrapes a print is a gate that a reworded print
breaks, and the report rebuilds the world state part way through on purpose
(that rebuild is how it proves a mid-session load re-aims the sky), so the
object to drive is the one that exists at the end. The printed line is the
run's own clock, held before that probe. And it asks the rig what it is walking
toward with `current_targets()`, comparing those numbers against `SkyRig`'s own
pure mapping for the phase and weather the clock says it is on, because a rig
holding a stale state produces a consistent set of wrong numbers rather than an
obviously broken sky.

Run it with:

```
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/world_test.tscn
```

Expect `WORLD_OK checks=32`; the exit code is the verdict.

**Pinning an hour.** `world/ranch.tscn` takes `--phase=`, `--weather=` and
`--world-time=` after a bare `--`, which hold the clock at a named hour and
weather (or start it at a given number of elapsed seconds) so a gate or a
screenshot does not have to sit through twenty minutes of cycle to reach a
stormy night. A pinned run never moves the clock and never writes it to
anybody's save, which the ranch gate itself checks. The pinned invocation is:

```
tools/bin/godot --headless --audio-driver Dummy --path game world/ranch.tscn -- --phase=NIGHT --weather=STORM
```

Phase names are `dawn`, `day`, `dusk`, `night` and weathers are `clear`,
`rain`, `fog`, `storm`, matched case-insensitively; `--world-time=` takes
seconds. Expect the same `RANCH_OK ponies=22 props=58 assets=present` as an
unpinned run, with the `RANCH world` line naming the hour that was pinned.

**Looking at the sky.** The gate checks numbers; only a person can say whether a
stormy dusk *looks* like one. `bash tools/sky_sheet.sh` renders the ranch once
for each of the sixteen (phase, weather) pairs and tiles them into
`build/sky_sheet.png`, rows for the phases and columns for the weathers (a
minute or two a cell under xvfb, so most of an hour in total). It **clears the
cells it is about to render first** (all sixteen of `build/sky_shots`, by
default) so a sheet is always fresh renders of the build in front of you rather
than a mix of today's and last week's; pass `--keep` to reuse whatever is
already rendered there, and the summary counts those cells as `kept=` rather
than `rendered=`. `--only=<phase>_<weather>`
(for instance `--only=night_storm`) renders and tiles that one cell, which is
what to use after tuning a single number. Unlike the gates above it **is** a
pass or fail: a failed render or a missing cell exits 1, so a sheet with a hole
in it cannot be mistaken for a sheet. Not committed; `build/` is gitignored.

---

## The collection gate

`scenes/test/collection_test.tscn` proves slice 5's collection loop a unit test
cannot: a herd whose membership answers to the hour, a compendium that fills
itself from what the player actually does, a request board that pays for it, a
pause menu page repeating the counts, and a save that brings all of it back.

In one run, on the real ranch: a fresh dawn with nobody out who keeps night
hours; a pony who marks herself **SEEN** the moment the player is inside her
notice radius; a second pony caught with the real magic beam (aimed through the
same `CameraRig.get_aim_ray()` the beam casts along, held until the beam reports
her secured, released into the saddlebag) who marks **CAUGHT** and finishes the
tutorial's "catch a pony" for 20 bits; moved into a pen for the tutorial's 30;
a gem sold at the Market for the tutorial's 50 plus the gem's own price; three
fresh favours standing on the board afterwards and not one of them a tutorial
one; the COMPENDIUM page's header reading the book's own counts; the clock
walked one phase at a time through dawn, day, dusk and night with a
`Spawner.refresh()` on each change; and a save, reset, rebind and load bringing
the whole book and the whole board back.

It hosts `world/ranch.tscn` exactly the way the market, region and world gates
do, and for the same reasons.

Four things about how it reads are worth knowing before editing it.

**It names no character.** Which characters keep night hours is a property of
the `.tres` files on disk, and a gate with `nightlight` typed into it would go
green on a roster that had stopped being conditional at all. "NIGHT-only",
"DAY-only" and "her hours have ended" are computed at run time by asking every
character's own `PonyData.available()` about all sixteen (phase, weather)
pairs. The two ponies it walks up to are picked out of the live herd the same
way, in the spawner's own seeded placement order, so the same run picks the
same ponies every time.

**It asks about the night pool over several nights, not one.**
`Spawner.refresh()` only fills the slots a departure freed, out of that
marker's own zone; four NIGHT-only characters in a roster of forty-three need
not all be reachable from the three slots one night happens to open. The claim
with teeth is that they are reachable **at all**. A build where the conditional
half of the roster could never be drawn is a build where a third of the
compendium is uncompletable. The loop stops at the first night that
answers and prints how many it took, so a change in the draw shows up as a
number rather than as a red.

**It watches one departure from three metres away.** A pony whose hours end
with nobody near her is discarded on the first frame of her departure, and
correctly so: her own `DetectionArea` has no player in it, so
`Pony._leave_distance()` answers `INF`. Timing that would be timing nothing.
So the player is stood inside the notice radius of somebody the coming phase is
about to close on, and only then does the hour turn; now the departure has to
carry her out of his sight before she may be freed. Which pony that is cannot
be decided in advance (a phase change need not end anybody's hours), so every
advance offers and the first one with a candidate takes it.

**It compares the board as a rendered signature, not `to_array()` against
`to_array()`.** A save is JSON and JSON has no integer type, so every count and
every enum comes back off disk as a float; a board written with ints does not
compare equal to the same board read back. The signature renders both sides
through `int()`, which says what "the board came back" actually means.

The gate calls `ranch._move_pony_into_pen()` directly, which is the one place
it reaches past a public method. It has to: the whole of `ranch.gd`'s
`_physics_process` input handling is gated on `_interactive`, false in a
headless run precisely so that a gate teleporting the player about cannot trip
a build menu or an autosave, so the E prompt that normally calls it cannot be
driven from here.

Run it with:

```
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/collection_test.tscn
```

Expect `COLLECTION_OK checks=73`; the exit code is the verdict. Every line it
prints is prefixed `COLLECTION`, and two runs print byte-identical lines: the
beam's capture generator is seeded, the herd and the weather come out of the
world seed, and nothing it prints is a raw physics quantity that a reordered
frame could move. Diffing two runs is therefore a real check on the whole
chain, and worth doing after touching the spawner, the beam or the board.


---

## Proving the atomic save (a thing a unit test cannot do)

`game/systems/save_io.gd` promises that a save interrupted part-way through
leaves the previous save intact, because the new state is written to a temp
file and published with a rename. That promise is about what happens when the
**process dies**, and a unit test cannot die — it can only decline to call
`commit()`, which demonstrates the shape of the code rather than the behaviour
of the filesystem. Both halves exist:

* `game/test/test_save_io.gd` covers the in-process half (a staged write that
  never commits; the live file byte-identical while a write is in flight; a
  leftover temp file being inert; the backup holding the previous save).
* `bash tools/prove_atomic_save.sh` covers the real half. It seeds a save,
  starts writing a new one, and **SIGKILLs a real Godot process between
  `stage()` and `commit()`** (`OS.kill(OS.get_process_id())` — no cleanup, no
  destructors, no buffer flush), then loads the slot in a *third* process:

  ```
  PROOF kill staged=true -- SIGKILLing this process before commit()
     (process died with rc=137 == 128+SIGKILL, as intended)
  PROOF verify marker='OLD_SAVE' loaded_keys=7 intact=true temp_left=true backup_left=false
  ATOMIC_SAVE_PROOF_OK
  ```

* `bash tools/prove_atomic_save.sh --negative-control` proves that proof can
  fail. It applies the same interruption to a **naive** write — open the live
  file (which truncates it on the spot), write half the new state, SIGKILL —
  and requires the verify phase to catch it:

  ```
  ERROR: SaveIO.load: '...slot_0.json' is not a readable save file -- corrupt or
    truncated (Unterminated string at line 2). It has been left on disk exactly as it is.
  PROOF verify marker='' loaded_keys=0 intact=false
  ATOMIC_SAVE_PROOF_NEGATIVE_CONTROL_OK
  ```

Everything it writes goes to `user://atomic_write_proof/`, never to the slot the
game plays in. Both scripts pass `--audio-driver Dummy`, like every other
automated run in this project.
