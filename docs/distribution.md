# Distribution — handing the friend a build

How the shipped build is put together, why it's one file per platform, and how
to cut and publish a release. For how CI exports and smoke-tests both
platforms on every push, see [`docs/ci.md`](ci.md); for the asset pipeline
itself, see [`docs/pipeline.md`](pipeline.md).

## 1. What's in the build

`game/export_presets.cfg` uses `export_filter="all_resources"` (export
everything) plus an `exclude_filter` that strips out project content that
exists for development but has no business in a build a player runs:

* `game/addons/gut/` — the GUT unit-test framework. It's invoked directly via
  `tools/bin/godot -s addons/gut/gut_cmdln.gd` (see `tools/run_tests.sh`); it's
  never loaded by the main scene, so excluding it from export doesn't touch
  runtime behavior. (~3 MB.)
* `game/scenes/test/hair_lag_test.*`, `model_gallery.*`, `terrain_probe.*`,
  `walk_test.*`, and `scenes/test/tmp/*` — Phase 0/1A probe and gallery
  scenes. Nothing else in the project references them, so excluding them is
  safe.
* `game/assets/converted/probe/` — the throwaway Source-engine test pony from
  the Phase 0 tier-c experiment (~34 MB, unused by anything in `game/`).

**The main scene is `res://world/ranch.tscn`** (`game/project.godot`), as of
Phase 1A task 7. It sits outside `scenes/test/` entirely, so none of the exclude
patterns above can reach it — which removes the hazard the paragraph that used to
stand here was managing (the main scene living inside the excluded test tree, kept
safe only because the patterns name each junk file individually rather than
globbing the directory). Keep it that way: **exclude patterns must stay
file-specific, not `scenes/test/*`**, because `scenes/test/smoke.tscn` and
`smoke_test.gd` are still deliberately packed. They are no longer the main scene,
but they remain the one gate that proves the engine boots with no content
involved at all.

Verified by exporting and running the build: it prints
`RANCH_OK ponies=49 props=94 assets=present` and exits 0.

Effect measured on this machine (a full local export, real assets present):

| | before (unfiltered) | after (filtered) |
|---|---|---|
| `.pck` alone (unembedded, apples-to-apples) | 101 MB | 29 MB |
| **Windows total** (`.exe` 92 MB + `.pck` 96 MB before) | **~188 MB, two files** | **~121 MB, one file** |
| **Linux total** (`.x86_64` 67 MB + `.pck` 96 MB before) | **~163 MB, two files** | **~96 MB, one file** |

One caveat, checked and judged harmless: `strings` on the exported binary
still shows a couple hundred short path references like
`res://addons/gut/hook_script.gd` and `res://assets/converted/probe/...`.
These come from Godot's project-wide global-script-class registry and UID
cache, which record every path in the project (so the engine can print a
clear "resource not found" instead of crashing if something is ever
requested that isn't packed) — they're a few KB of JSON-ish text, not the
actual excluded files. The `Storing File:` lines in the export log (and the
~70 MB size drop above) confirm the actual GUT code, probe textures, and
test-scene bytecode are not packed.

## 2. Single-file builds (no installer, no unzip)

Both export presets now set `binary_format/embed_pck=true`. This merges the
`.pck` (all game data) directly into the executable, so `--export-release`
produces exactly one file per platform:

* `build/filly-rancher-windows.exe` — nothing else needed next to it.
* `build/filly-rancher-linux.x86_64` — same.

Verified locally: `file build/filly-rancher-windows.exe` reports a normal
PE32+ executable, `ls build/*.pck` finds nothing, and
`./build/filly-rancher-linux.x86_64 --headless --quit-after 600` prints
`RANCH_OK ponies=49 props=94 assets=present` and exits 0 (it was `SMOKE_OK` until
Phase 1A task 7 changed the main scene). The Windows side of that same assertion runs for real
on `windows-latest` in CI (`.github/workflows/build-and-smoke.yml`) — this
machine has no Wine and can't execute the `.exe` itself.

**How the friend runs it:** download `filly-rancher-<version>-windows.exe`
and double-click it. That's the whole install — no installer, no zip to
extract, no `.pck` to keep alongside it.

**Send [`docs/phase1a-playtest.md`](phase1a-playtest.md) with the build.** It is
the player-facing half of this doc: the controls for both keyboard and gamepad,
what there is to do, what is deliberately not in the build yet (pens, food, the
economy, saves), and the known rough edges — so the first ten minutes are spent
playing rather than guessing which button fires the magic beam.

## 3. Publishing a release

```
tools/publish_release.sh <tag> [--draft|--publish] [--notes "text"]
```

One command: exports both platforms fresh, names the artifacts
`filly-rancher-<tag>-windows.exe` and `filly-rancher-<tag>-linux.x86_64`,
smoke-tests the Linux build, and runs `gh release create` with both files
attached. It prints the release URL when done.

* **Defaults to `--draft`.** Nothing is visible to anyone until you either
  re-run with `--publish` or hit "Publish release" in the GitHub UI. Pass
  `--publish` only when you actually mean to ship it.
* **Refuses on a dirty working tree** (`git status --porcelain` must be
  empty) — otherwise the binary you'd publish wouldn't correspond to any
  commit.
* **Refuses if this machine hasn't run the asset pipeline** (checks for at
  least one `.glb` under `game/assets/converted/ponies/`) — see §4, this is
  the operational fact that makes running it from CI the wrong move.

Example:

```
tools/publish_release.sh v0.1.0            # exports, smoke-tests, drafts a release
tools/publish_release.sh v0.1.0 --publish  # same, but goes live immediately
```

The script was tested end-to-end (export → smoke test → artifact naming →
`gh release create` → `gh release view`) using a throwaway tag
(`throwaway-test-v0.0.0-DELETE-ME`), then cleaned up with
`gh release delete --cleanup-tag`; both the release and the tag were
confirmed gone afterward (`gh release view` → "release not found",
`git ls-remote --tags` → no match).

## 4. Releases must be published from a machine with real assets — never from CI

This is the key operational fact: **`game/assets/converted/**` is gitignored**
(see `.gitignore` and `docs/ci.md` §4). A CI checkout has no pony models, no
props, no converted audio — CI's export is genuinely assetless, and CI has no
way to regenerate them (the raw asset packs under `assets_raw/` are also
gitignored, and Blender/the conversion pipeline don't run in CI at all).

CI's build-and-smoke workflow exists to prove the binaries *boot* on both
platforms, not to produce something to hand to a player. `tools/publish_release.sh`
therefore only runs locally, on a machine that has already run the asset
pipeline (`tools/setup_env.sh` and the `tools/*.py` conversion scripts — see
`docs/pipeline.md`), and it actively checks for that before exporting anything.

Practical upshot: publish releases from the owner's Pop!_OS machine (or any
machine that has run the full pipeline), never by wiring `gh release create`
into the GitHub Actions workflow.

## 5. Two things to warn the friend about

Both of these are expected and not a sign anything is broken — pass them
along before the friend downloads anything:

* **Windows SmartScreen.** The `.exe` isn't code-signed (`codesign/enable` is
  off in `game/export_presets.cfg` — a code-signing certificate costs money
  and isn't warranted for a two-person project). Windows will show "Windows
  protected your PC" the first time it's run. Click **More info**, then
  **Run anyway**.
* **Antivirus false positives.** Unsigned, freshly-built executables
  (especially ones bundling a game engine) occasionally get flagged by
  antivirus/Defender heuristics with no real malware present. If that
  happens, the friend may need to allow the file or add an exception. This is
  common for indie/hobby Godot exports generally, not specific to this build.
