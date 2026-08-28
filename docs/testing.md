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
success for a run that verified far less than it claimed. On top of GUT's
result the script hard-fails if zero tests ran, if any `test_*.gd` file on disk
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

Expect `MARKET_OK checks=43`; the exit code is the verdict.

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
