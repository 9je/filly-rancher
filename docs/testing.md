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

Runs every `game/test/test_*.gd` script headlessly through GUT's CLI runner
and exits with GUT's own exit code: **0** if every test passed, **non-zero**
if any test failed (or if GUT itself errored). Output names every failing
test and the line it failed at. This is the one command every later
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

## Quirk: GUT's classes need one Godot import pass after being installed

**Symptom:** immediately after `tools/setup_env.sh` installs/updates GUT
(or on a fresh checkout with no `game/.godot/` import cache yet — that
directory is gitignored, same as the `.glb` import-cache quirk documented
in `docs/pipeline.md` §7), running `tools/run_tests.sh` prints:

```
ERROR: Some GUT class_names have not been imported.  Please restart the Editor or run godot --headless --import
Missing class_names:  ["GutErrorTracker", "GutHookScript", ... "GutTest", ...]
```

**The dangerous part:** GUT's own entry script calls `quit(0)` in this
exact branch — i.e. Godot's process exit code is **0**, indistinguishable
from "all tests passed," even though zero tests actually ran. A naive
`bash tools/run_tests.sh && echo tests passed` would lie.

**Fix, one-time per fresh checkout / per GUT install:**

```bash
tools/bin/godot --headless --path game --import
```

(~5-6s; safe to re-run, and harmless/idempotent afterward — it also
reimports any converted `.glb` assets present, same command the `--editor
--quit-after 60` workaround in `docs/pipeline.md` §7 is an alternative to.)

**`tools/run_tests.sh` does not trust GUT's exit code blindly for this
specific case** — it captures GUT's combined output and greps it for the
`have not been imported` marker, hard-failing with a clear message and
non-zero exit even though GUT itself reported `0`, rather than silently
reporting success with zero tests run. This is the same "never let a
success claim outrun what was actually verified" discipline
`tools/setup_env.sh`'s `SOURCEIO_OK`/`GUT_INSTALL_OK` marker gates follow
(see `docs/pipeline.md` §1) — a previous review caught this codebase's
setup script claiming success on an unverified step, so this harness does
not repeat that mistake.

---

## Files

| Path | Role |
|---|---|
| `game/addons/gut/` | The GUT addon itself (gitignored, fetched by `tools/setup_env.sh`) |
| `game/test/test_smoke.gd` | Harness smoke test — proves GUT reports failures with a non-zero exit, not just passes |
| `tools/run_tests.sh` | Entry point: `bash tools/run_tests.sh` |
| `tools/setup_env.sh` | Installs/pins GUT (`GUT_VER`/`GUT_SHA256`, near the SourceIO block) |
