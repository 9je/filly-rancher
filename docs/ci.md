# CI — cross-platform build verification

Workflow: [`.github/workflows/build-and-smoke.yml`](../.github/workflows/build-and-smoke.yml)
Shared assertion script: [`.github/workflows/smoke_run.sh`](../.github/workflows/smoke_run.sh)

## Why this exists

Phase 0 exported a Windows `.exe` and never ran it. The only evidence it worked
was `file` reporting `PE32+ executable` — which is a statement about the first few
bytes of a file, not about whether the game boots. The founding requirement of this
project is that the game runs on the owner's Pop!\_OS machine *and* on the friend's
Windows machine, and Wine isn't installed locally (installing it needs sudo), so
there was no way to close that gap on the owner's box.

GitHub Actions has real Windows machines. This workflow uses one.

---

## 1. What the workflow does

Two jobs:

**`export-and-linux-smoke` (`ubuntu-latest`)**

1. Restores Godot `4.5.2-stable` + its export templates from `actions/cache`, or
   downloads them on a cache miss and checks both against the SHA512s the Godot
   release publishes. Same version pin as `tools/setup_env.sh`; same URLs and
   template-install layout as `docs/pipeline.md` §9.
2. Exports **both** presets from `game/export_presets.cfg` —
   `build/filly-rancher-linux.x86_64` and `build/filly-rancher-windows.exe`
   (Godot cross-exports the Windows binary from Linux, no Wine involved; this is
   exactly what the owner does locally).
3. Fails the job if either export log contains a resource error (see §4).
4. **Runs the Linux binary** and asserts its startup marker.
5. Uploads both builds as downloadable artifacts.

**`windows-smoke` (`windows-latest`)**

6. Downloads the Windows artifact and **runs `filly-rancher-windows.exe` on real
   Windows**, asserting the same startup marker with the same script.

The export runs once, on the cheap runner. The Windows runner (billed at a **2x**
minute multiplier) only does the part that genuinely requires Windows: executing
the `.exe`.

### The assertion

`smoke_run.sh` launches the binary as:

```
<binary> --headless --audio-driver Dummy --quit-after 600 --log-file ci_smoke_engine.log
```

(`--audio-driver Dummy` is redundant here — `--headless` already forces it — kept
explicit anyway so this line stays the "quiet form" to copy even in a context that
doesn't use `--headless`. Every non-interactive/scripted invocation of this game is
meant to be silent on principle, not just on CI runners that happen to have no audio
hardware to be silent on.)

and requires **both**:

* exit code `0`, and
* a line matching `RANCH_OK` in the captured output.

`RANCH_OK` is what `game/world/ranch.gd` prints — the main scene since **Phase 1A
Task 7** (`game/project.godot`: `run/main_scene = res://world/ranch.tscn`). It is
printed *only* when every check that scene runs actually held; otherwise the scene
prints `RANCH_FAILED` and exits 1, so a broken ranch fails this script on the exit
code as well as on the marker.

**`SMOKE_OK` was removed from `MARKERS` when the ranch landed**, as the note that
used to live here asked. `game/scenes/test/smoke.tscn` still exists and is still run
directly as a gate, but it is no longer what the game boots into — and leaving its
marker in the accepted list would mean a future accident that reverted
`run/main_scene` to the retired scene would sail through CI green. The list has to
name what the game is *supposed* to boot into, not everything it ever booted into.
The marker is spelled out as a literal rather than matched loosely (`[A-Z]*_OK`) for
the same reason: a loose pattern is how this check would rot into a silent pass.

Output is captured twice — the shell's stdout redirect *and* Godot's own
`--log-file` — and the marker may appear in either. That redundancy is for Windows:
release exports set `debug/export_console_wrapper=1` ("debug builds only"), so no
`filly-rancher-windows.console.exe` is produced, and the shipped `.exe` is a
GUI-subsystem binary whose stdout depends on handle inheritance from the launching
shell. The engine-written log doesn't. (In the verified run below, both channels
carried the marker on both platforms.)

`--quit-after 600` bounds the run. As it turned out the ranch *does* quit itself
under `--headless` (it runs its checks, prints its verdict and calls
`get_tree().quit()` with 0 or 1) — but only under `--headless`; launched normally it
is a game and stays up, which is the whole point of it being the main scene. The
bound stays because it costs nothing and it is what stops a future main scene that
forgets to quit from hanging the job to the runner timeout instead of reporting a
result.

The script is a single file executed by both jobs — `windows-latest` runs it under
Git Bash via `shell: bash`. Two separate scripts would mean a green Windows job
could just be proving the Windows script was the more lenient one.

### Proof it can fail

An assertion that has never failed is not an assertion. `smoke_run.sh` was run
against four negative controls before it was committed; all four exited non-zero:

| Control | Result |
| --- | --- |
| binary that prints no marker, exits 0 | `FAIL: no startup marker matching …` |
| binary that prints the marker but exits 3 | `FAIL: binary exited 3 (expected 0)` |
| binary that does not exist | `FAIL: binary exited 127` |
| binary that hangs | `FAIL: binary exited 124 (timed out; the scene never quit)` |

One of these controls caught a real bug in an earlier draft: `cat stdout engine | grep`
under `set -o pipefail` returned non-zero when the engine log was absent, so a marker
that *was* present in stdout read as missing. The script now merges the two logs into
a file and greps the file.

The same failure was then confirmed end-to-end in CI, not just locally: a run with the
marker list deliberately changed to a string the game never prints failed **both** the
Linux and the Windows job (§7).

---

## 2. When it runs

| Trigger | Runs? |
| --- | --- |
| Push to `master` | yes |
| Pull request | yes (on open and on every push to the PR branch) |
| Push to any other branch | **no** — deliberate |
| Manual (`workflow_dispatch`) | yes |

This is a 2-person private repo on free CI minutes and Windows bills at 2x, so
there is no "every push to every branch" trigger. In-flight runs for a ref are
cancelled when a newer commit supersedes them.

### Triggering a manual run

```bash
gh workflow run build-and-smoke.yml            # default branch
gh workflow run build-and-smoke.yml --ref my-branch
gh run watch                                   # follow the latest run
```

Or in the browser: **Actions → build-and-smoke → Run workflow**.

`gh workflow run --ref <branch>` was tested against this branch **before** the
workflow existed on `master`, and it worked (§7). The commonly-cited rule that
`workflow_dispatch` requires the workflow to be on the default branch turns out to
govern the **Run workflow** button in the web UI, not the API — so if the button
isn't there yet, use the CLI, or push to the PR branch and let the `pull_request`
trigger fire.

---

## 3. What this genuinely proves — and what it doesn't

**Proves:**

* Godot 4.5.2 exports both presets from a *clean checkout* (no owner-machine state,
  no editor pass, no locally-generated files) — so the presets aren't accidentally
  depending on anything only present on one machine.
* The exported **Windows `.exe` boots on real Windows**: it loads its `.pck`,
  initialises the engine, instantiates the main scene, runs `_ready()`, prints its
  marker, and exits cleanly. That is the specific claim Phase 0 could not make.
* The exported Linux binary does the same on Linux, so a regression on either
  platform is caught rather than only the one the owner happens to test.
* The two platforms stay in sync: same commit, same engine, same assertion.

**Does not prove:**

* **That anything renders.** `--headless` uses the dummy rendering driver: no GPU,
  no window, no rasterisation. `docs/pipeline.md` §7 records a real instance of this
  blind spot — Twilight was rendering nearly invisible while `WALK_OK` and every
  structural gate passed. Headless CI would not have caught that either. Only
  rendering actual frames (Phase 0 did it with `xvfb-run` + llvmpipe) can.
* **That the game is playable.** No input, no audio (`--headless` forces the dummy
  audio driver), no frame-rate or GPU-driver claim. A Vulkan driver bug on the
  friend's actual machine is out of scope for a runner with no GPU.
* **That the assets work.** The CI build contains none — see §4.
* **Anything about the friend's specific Windows version/hardware.**
  `windows-latest` is a clean Windows Server image, not a gaming desktop.

Was headless the right call? Yes for what's being verified here: the marker is
printed from `_ready()`, which headless reaches normally, and Phase 0 already ran the
3D gallery / walk / terrain-probe scenes headless with correct output, so a 3D main
scene is expected to reach its marker too. A GPU-backed runner would be slower,
costlier and still wouldn't be the friend's machine. The honest framing is: **this
workflow verifies the binary boots and runs its startup logic on both platforms; it
does not verify pixels.** Adding the cheap render-and-compare check
`docs/pipeline.md` §7 recommends for Phase 1 would be the natural next step, and it
would need a software-Vulkan (`xvfb-run` + llvmpipe) job rather than `--headless`.

---

## 4. The assetless-build limitation (read this before shipping an artifact)

`game/assets/converted/**` is **gitignored** — and so are the source packs in
`assets_raw/`, which are gitignored downloads. A CI checkout therefore has **no pony
models, no props, and no converted audio**, and CI *cannot* regenerate them: the
inputs simply aren't in the repo. Blender and the conversion pipeline are not run in
CI for the same reason.

Consequences, stated plainly:

* **The artifacts this workflow uploads are assetless builds.** They boot and print
  their marker. They will not contain Twilight. Do not hand a CI artifact to anyone
  as "the game" once the game actually has content in it — until asset delivery is
  solved, a build with ponies in it still has to come from the owner's machine.
* This stayed harmless through Phase 1A Task 7: no committed scene references a
  converted path statically (they all resolve at runtime via `DirAccess` /
  `ResourceLoader.exists`), so a clean-checkout export is still completely
  error-free. Verified against a fresh `git clone` before this workflow was written,
  and re-verified against an assets-removed copy of the tree when the ranch became
  the main scene — see "What Task 7 actually did about it" below.
* To stop that from turning into a *silent* problem, the workflow greps both export
  logs for `ERROR:` / `Failed loading resource` / `Cannot open file` /
  `Resource file not found` and **fails the job** if any appears.

  Why fail rather than warn: a Godot export that can't resolve a resource still
  exits `0` and still writes a runnable binary. The startup-marker check would pass
  it happily. So the first scene that statically references a converted asset would
  otherwise produce a green run and a broken build — the exact failure mode this
  whole workflow exists to eliminate. Since the current baseline is *zero* matching
  lines, the gate is strict without being flaky. If it ever fires on something
  genuinely benign, narrow the pattern in the workflow and say why in the commit —
  don't delete the step.

### What Task 7 actually did about it — option (a)

The ranch landed as the main scene and **the gate did not fire**, because the scene
was built so it never could. Of the three options this section listed, Task 7 took
**(a), graceful degradation**, and deliberately not (b) or (c):

* **(c) — a dedicated assetless smoke scene — was rejected outright.** It would mean
  CI verifies a scene the game does not boot into, which is the precise shape of a
  test that passes while measuring nothing. It also directly contradicts the point of
  retiring `SMOKE_OK` above.
* **(b) — commit placeholder assets — was rejected** as the wrong trade for a
  gitignored-assets repo: it puts binaries in git to make a check pass, and the
  placeholders would then need maintaining against the real ones forever.
* **(a) was also just… correct anyway.** "The map still works when the converted
  assets are missing" is not a CI accommodation; it is what a fresh clone on a new
  machine needs before anyone has run Blender on it.

Concretely, `world/ranch.tscn` **statically references nothing under
`assets/converted/`**. Its `ext_resource` list is scripts plus `player.tscn`, none of
which resolve into that tree. Everything that does is loaded at runtime and skipped
when absent:

* `game/world/props.gd` scans its layout against `ResourceLoader.exists()` and places
  what is there.
* `game/world/spawner.gd` filters the registry to entries whose `model_path` actually
  resolves, and draws from what is left.
* `game/world/terrain.gd` and `game/world/building.gd` are **generated in code**, so
  the ground, the barn and the farmhouse exist on every checkout — which is why CI
  still has real geometry to test the camera's collision pull-in against, rather than
  an empty plane.

The result on an assetless checkout is `RANCH_OK ponies=0 props=6 assets=absent`,
exit 0 — verified locally by running the scene against a copy of the tree with
`game/assets/converted/` removed.

**The `assets=` field is the point.** A degraded run that printed a bare `ponies=0`
would be indistinguishable from a spawner that silently broke. So the scene decides
up front whether the assets exist, says so in one plain sentence at the top of the
log, and then *checks against the right expectation*: with assets present it demands
the full count and fails on anything less; with assets absent it expects zero. The
lenient path is chosen deliberately and announced, not fallen into.

Don't just delete the gate.

---

## 5. Downloading the builds (including for the friend)

A genuinely useful side effect: **the friend can download the Windows build straight
from a CI run** instead of waiting for someone to hand it over. Every run — on
`master`, on a PR, or manual — publishes both builds as artifacts, kept 30 days.

Browser: **Actions → the run → Artifacts** at the bottom of the summary page →
`filly-rancher-windows` (or `filly-rancher-linux`).

CLI:

```bash
gh run download <run-id> -n filly-rancher-windows -D ./win-build
```

Then, on Windows: unzip and run `filly-rancher-windows.exe` — that's the whole
build, one file. Both export presets set `binary_format/embed_pck=true` (see
`docs/distribution.md` §2), so the `.pck` is embedded directly in the
executable; there is no sibling `.pck` to keep alongside it any more. Same on
Linux: unzip `filly-rancher-linux.x86_64` and run it (plus `chmod +x`, since
zip archives don't carry the execute bit) — no `.pck` there either.

Note that the repo is private, so downloading artifacts requires a GitHub account
with access to it.

And re-read §4 first: right now these artifacts are assetless.

---

## 6. When it fails

Open the failing job's log. The smoke step prints the exit code, the full stdout,
and the full engine log before it reports `PASS`/`FAIL`, so the evidence is in the
run — you shouldn't need to reproduce it to know what happened.

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| `no export template found` / templates step fails | Godot version bumped in `tools/setup_env.sh` but not in the workflow's `GODOT_VERSION`/`GODOT_TEMPLATES_VERSION`, or a stale cache | Update both `env:` pins **and** the pinned SHA512s, and bump the cache key suffix (`-v1` → `-v2`) |
| `sha512sum: WARNING: … checksum did NOT match` | The pinned hash and the downloaded file disagree | Do **not** "fix" it by deleting the check. Verify against the release's own `SHA512-SUMS.txt` and update the pin deliberately |
| `Export emitted resource/errors` | A scene now statically references an asset that isn't in the repo | See §4 — this is the assetless-build limitation firing |
| `FAIL: no startup marker …` on **both** platforms | The main scene changed and no longer prints `RANCH_OK`, or the ranch printed `RANCH_FAILED` because one of its own checks went red | Read the captured output: `ranch: FAILED check -- <name>` names the exact claim that broke. Only edit `MARKERS` if the main scene legitimately changed |
| `FAIL: binary exited 1` with `RANCH_FAILED` in the output | The ranch booted but a check failed — the gate working. Common causes: terrain collider not built, a prop with no collision, the camera's probe mask no longer covering `PROPS` | Fix the cause; do not relax the check |
| `RANCH_OK … assets=absent` | Expected in CI — `game/assets/converted/**` is gitignored (§4) | Nothing. It is a declared state, not a failure |
| `FAIL: no startup marker …` on **Windows only** | A genuine Windows-specific break — this is the case the workflow was built to catch | Read the captured engine log in the job output; do not merge |
| `FAIL: binary exited 124` | The scene never quit within 300s | Check for a blocking `await`/infinite loop in `_ready()`; `--quit-after 600` should have ended it |
| Windows job skipped | The Linux job failed first (`needs:`) | Fix the Linux job; artifacts still upload (`if: always()`) so you can debug the build itself |

Local reproduction of the Linux half, from a clean checkout (`docs/pipeline.md` §9
has the toolchain setup):

```bash
git clone <repo> /tmp/clean && cd /tmp/clean && mkdir -p build
tools/bin/godot --headless --path game --export-release "Linux"   ../build/filly-rancher-linux.x86_64
tools/bin/godot --headless --path game --export-release "Windows" ../build/filly-rancher-windows.exe
bash .github/workflows/smoke_run.sh ./build/filly-rancher-linux.x86_64
```

The Windows half can only be reproduced on Windows (or via a CI run) — that
asymmetry is the reason this workflow exists.

---

## 7. Verified run

CI that has never been observed working has the same credibility problem as an
unrun `.exe`, so the workflow was run for real before being written up.

> **These runs predate Phase 1A Task 7.** They were made while `smoke.tscn` was
> still the main scene, so their logs show `SMOKE_OK` and the two-marker
> `SMOKE_OK|RANCH_OK` list. They are kept verbatim as the record of the workflow
> being observed working end to end, including failing on purpose; the marker list
> they show is not the current one (§1).

**Green run — <https://github.com/9je/filly-rancher/actions/runs/33040201478>**
(PR #1, commit `57e725a`). Both jobs passed. The `windows-smoke` job's log shows
the exported `.exe` executing on `windows-latest`:

```
== running: ./build/filly-rancher-windows.exe --headless --quit-after 600 ==
== exit code: 0 ==
Godot Engine v4.5.2.stable.official.6ce3de25a - https://godotengine.org
SMOKE_OK renderer=forward_plus
PASS: startup marker matched (SMOKE_OK|RANCH_OK)
```

That line is the thing Phase 0 never had. The Linux job printed the same. The
marker turned up in *both* capture channels on both platforms, so stdout
redirection does work through Git Bash for the GUI-subsystem `.exe` — the
`--log-file` belt-and-braces wasn't needed here, but it costs nothing and removes
a dependency on that behaviour continuing to hold.

**Deliberately-broken run — <https://github.com/9je/filly-rancher/actions/runs/33040359736>.**
`MARKERS` was changed to `THIS_MARKER_IS_NEVER_PRINTED` on a throwaway branch (so
the shared branch's history stayed clean; the branch has since been deleted, the
run log has not). **Both** jobs went red with
`FAIL: no startup marker matching 'THIS_MARKER_IS_NEVER_PRINTED'` — including the
Windows one, which is the specific job whose ability to fail could not be checked
locally. That throwaway branch also temporarily gave `windows-smoke` an
`if: always()`, so it would run rather than be skipped by its failed `needs:`.

**Manual-dispatch run — <https://github.com/9je/filly-rancher/actions/runs/33040532862>.**
Also green, and it confirms `gh workflow run --ref phase0-asset-pipeline` triggers
this workflow from a non-default branch (see §2).

**Warm-cache run — <https://github.com/9je/filly-rancher/actions/runs/33040681055>.**
Green, and the one that proves the caching is worth having: `Cache restored from
key: godot-4.5.2-stable-linux-v1`, no download step at all, and about 14 seconds
from cache restore to `PASS` on the Linux smoke test.

Total cost of a full run: roughly 1.5–3 minutes of Linux time and well under a
minute of Windows time, *including* the first-run 1.3GB template download — the
Windows job only downloads an artifact and runs one binary, which is the whole
point of exporting on the Linux runner.

---

## 8. Maintenance notes

* **Version pins live in two places** — `tools/setup_env.sh` (`GODOT_VER`) and this
  workflow's `env:` block. CI deliberately does *not* run `setup_env.sh`: that script
  also fetches Blender (~1GB), SourceIO and GUT, none of which CI needs. The cost is
  that a Godot bump must be applied in both files. The `Verify toolchain` step
  asserts the installed template folder matches the pin, so a mismatch fails loudly
  rather than silently exporting with the wrong engine.
* **Bump the cache key** (`godot-…-linux-v1`) whenever what's *inside* the cache
  changes shape; changing `GODOT_VERSION` already changes the key by itself.
* **Cache scope is not global, and the first run on `master` matters.** GitHub
  scopes a cache to the ref that wrote it: a cache saved by a PR run is visible to
  later runs *of that same PR*, and a cache saved on the default branch is visible
  to everything. Observed live during §7 — two of the three verification runs, each
  on a different ref, reported `Cache not found for input keys:
  godot-4.5.2-stable-linux-v1` despite an earlier run having saved exactly that key.
  So expect one full ~1.3GB download per new ref until this lands on `master`, and
  don't read a cache miss on a new branch as a broken cache configuration.
* **`actions/*` are pinned at `@v4`** and GitHub currently annotates every run with
  a Node 20 deprecation warning. It's a warning, not a failure; bump the action
  majors when convenient (that's also a good moment to bump the cache key).
* **GUT unit tests are not run in CI.** `game/addons/gut/` is gitignored (it's a
  fetched dependency), so a CI checkout has no test runner. Adding a test job means
  first fetching GUT in the workflow the way `setup_env.sh` does. Note that
  `game/test/test_smoke.gd` extends `GutTest` and still exports cleanly without the
  addon present — verified on a clean clone — so its absence doesn't break the build.
* **Nothing in CI depends on the owner's machine.** The only inputs are the repo,
  the pinned Godot release, and its export templates. The things that *are*
  owner-machine-only — `assets_raw/`, `game/assets/converted/`, `tools/bin/`,
  `game/addons/gut/` — are all gitignored, and §4 covers what their absence means.
