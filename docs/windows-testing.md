# Windows testing — local verification via Proton

Scripts: [`tools/install_proton.sh`](../tools/install_proton.sh),
[`tools/run_windows_build.sh`](../tools/run_windows_build.sh)

## Why this exists

`docs/ci.md` covers the first rung: GitHub Actions launches the exported
`.exe` headless on a real `windows-latest` runner and checks for `RANCH_OK`.
That proves the binary starts and the scene graph builds on real Windows —
but the runner has no GPU worth calling one and no interactive session, so it
cannot prove the game *renders*, and it cannot say anything about Windows
file paths that only diverge from Linux once real files get written (Phase 1B
saves, screenshots, logs). Wine is not installed locally and installing it
needs `sudo`, which this project avoids everywhere it can. Steam and Proton
sidestep that: Steam was already installed, and a Proton build can be pulled
as a plain GitHub Releases tarball with no package manager, no sudo, and no
GUI — the same integrity discipline `tools/setup_env.sh` already uses for
Godot/Blender/SourceIO/GUT (pinned version, checksum verified against the
release's own published sums, fail hard on mismatch, idempotent).

This is a **local, opt-in verification tier**, not a CI replacement. It runs
on the owner's machine, on demand, and needs Proton installed once
(`tools/install_proton.sh`).

## What this tier proves

1. **The Windows binary actually executes on this machine**, not just on a
   GitHub-hosted VM — real file I/O, real process startup, under Wine's
   Win32 emulation rather than native Windows.
2. **It renders.** `tools/run_windows_build.sh --render` drives a windowed run
   under `xvfb-run` and saves the same six screenshots the Linux build's own
   `xvfb-run` smoke test saves (`docs/pipeline.md` §9). This machine has a
   real AMD GPU (`Radeon RX 9070 XT`, Mesa's `radv` Vulkan driver) — Wine's
   `winevulkan` passes Vulkan calls through close to natively, so Godot's
   Forward+ renderer is drawing with real hardware acceleration, not a
   software rasterizer. Comparing the Proton screenshots against the Linux
   build's: same terrain, same prop and pony placement (the scene is
   deterministic), same HUD, same materials. Minor differences in ambient
   shading/fog tone are visible between the two runs — expected driver/GL
   vs Vulkan-path variance, not a content bug — but nothing is missing,
   black, or mistextured.
3. **Where Godot's `user://` resolves on Windows**, which nothing before this
   tier had ever actually checked (see below) — the single highest-value
   thing to nail down before Phase 1B adds save files. As of Phase 1B Task 2
   this is no longer inferred from a log file that happened to be there: the
   ranch gate itself now writes a real save, reads it back, and prints where it
   landed, so every run of this tier answers the question directly.

## What this tier does NOT prove

- **Real Windows GPU drivers.** Wine's `winevulkan` on Linux is not the
  friend's NVIDIA/AMD/Intel Windows driver stack. A render that works under
  Proton's `radv` says nothing about whatever driver quirks exist on actual
  Windows hardware.
- **Actual performance.** Frame time under Wine's translation layers (even
  with near-native Vulkan passthrough) does not predict frame time on
  Windows. Don't use this tier for performance judgments in either direction.
- **DPI / multi-monitor behaviour.** The Wine prefix here has one virtual,
  non-HiDPI display. Nothing about scaling, multi-monitor window placement,
  or fullscreen-exclusive behaviour on a real Windows desktop is exercised.
- **SmartScreen / antivirus warnings.** The friend runs an **unsigned**
  `.exe` downloaded from GitHub. Windows SmartScreen and/or their antivirus
  WILL flag it on first run — Proton never shows this, because Wine has no
  concept of SmartScreen. This tier cannot rehearse that moment; the release
  notes/instructions to the friend need to say what to expect and click
  through.

## The interpretive caveat — read this before trusting a result

**Failures skew false-positive.** Wine has real, well-known compatibility
gaps that have nothing to do with this game's code — a missing DLL, an
unimplemented API, a prefix that wasn't set up quite right. A Proton run
failing here is a **lead to investigate**, not proof the Windows build is
broken. Concretely: raw `wine` (Route B below) failed to even load the
process on this exact binary, for reasons that turned out to be entirely
about how the *raw* Wine prefix was initialized, not about the game — see
"Two routes" below.

**A Proton success is decent evidence**, though not proof: if the binary
starts, spawns 8 ponies and 33 props, builds terrain, and renders a
recognizable ranch under Wine's Win32 emulation, the Windows-specific code
paths involved (file loading, path handling, PCK unpacking) are very likely
fine on real Windows too. It is not proof, because Wine and real Windows
still diverge (see "What this tier does NOT prove" above) — but a green
result here is meaningfully more informative than "the binary is PE32+ and
CI ran it headless."

## The three-tier picture

| Tier | Proves | Doesn't prove |
|---|---|---|
| CI, `windows-latest`, headless (`docs/ci.md`) | Real Windows OS, real file loading, engine boots and passes every ranch check | Rendering, GPU, input, feel |
| Proton, locally, this doc | Rendering (real GPU via Wine), Windows file-path handling (`user://`), a second independent "does it boot" check | Real Windows drivers, real performance, DPI, SmartScreen |
| The friend's machine | Real drivers, real performance, real feel, the actual SmartScreen/antivirus moment | Nothing — this is the ground truth the other two tiers are proxies for |

None of the three is sufficient alone; together they cover starts (CI),
renders-correctly (Proton), and feels-right-on-real-hardware (the friend).

## Installing Proton (once per machine)

```bash
tools/install_proton.sh
```

Downloads `GE-Proton11-5` (~530MB) from
`GloriousEggroll/proton-ge-custom`'s GitHub releases, verifies it against the
release's own published SHA512 (cross-checked against the GitHub Releases
API's independently-computed SHA256 digest for the same asset), and extracts
it to `~/.steam/root/compatibilitytools.d/GE-Proton11-5/` — **outside this
repo**, so there is nothing here for git to ever pick up (hundreds of MB;
must never be committed). Idempotent: re-running with the build already
present just re-verifies the install layout and exits.

## Two routes, and which one actually works

The task brief called out two routes to try in order:

**(a) `proton run <exe>`** with `STEAM_COMPAT_DATA_PATH` (a prefix directory)
and `STEAM_COMPAT_CLIENT_INSTALL_PATH=~/.steam/steam` set. **This is the one
that works**, and `tools/run_windows_build.sh` uses it.

**(b) The bundled `wine`/`wine64` directly** (`files/bin/` inside the Proton
build), with a hand-rolled `WINEPREFIX`. **This does NOT work for this
binary, and the reason is instructive, not a dead end to just note in
passing:** a fresh prefix built by running `wine wineboot --init` directly
has no DXVK/VKD3D translation DLLs installed into `system32` — those only
get copied in by Proton's own `proton run` setup step (`utilities.py`'s
prefix population, not part of raw Wine). Godot's exported binary imports
`dxgi.dll` (used for one of its optional backends), and without the
DXVK-provided `dxgi.dll` in place, Wine's loader fails outright:

```
00dc:err:module:import_dll Library dxgi.dll (which is needed by
  L"...\filly-rancher-windows.exe") not found
00dc:err:module:loader_init Importing dlls for ... failed, status c0000135
```

i.e. exit 53, before the game ever gets a chance to run. This is exactly the
"Wine gap, not a game bug" case the interpretive caveat above is about — it
looked like a hard failure of the binary, and was actually a Wine-versus-raw-
wine setup gap. Route (a) exists precisely because Proton does that DLL
population automatically as part of `proton run`; there is no reason to
reimplement it by hand when route (a) works.

Also worth noting for route (a) specifically: **pass an absolute Linux path**
to the `.exe` (Proton translates it via the `Z:` drive), not a relative one —
a relative path was tried first and failed with
`err:steam:run_process Failed to create process ...: 2` (file not found),
because whatever cwd Proton's Python wrapper resolves the relative path
against is not this repo's working directory. `tools/run_windows_build.sh`
always passes `$(pwd)/build/filly-rancher-windows.exe`.

## Running it

```bash
# Build (if needed) + headless run + RANCH_OK check. Exits non-zero on
# missing marker or timeout.
tools/run_windows_build.sh

# Same, but also do a windowed run under xvfb-run and save 6 screenshots to
# build/windows_proton_shots/ (gitignored, like the rest of build/).
tools/run_windows_build.sh --render

# Force a fresh export even if build/filly-rancher-windows.exe exists.
tools/run_windows_build.sh --rebuild
```

**This is always silent, in both modes.** The script passes `--audio-driver Dummy`
to every run unconditionally, not just the headless one -- `--render` cannot use
`--headless` (it needs a real display driver under `xvfb-run` to render anything),
so unlike the headless case Godot's own `--headless`→dummy-audio-driver mapping does
not cover it, and without an explicit flag `--render` would open a real audio
device. This script is a scripted, non-interactive invocation and must never make
noise on whatever machine runs it -- concretely, this scene plays Twilight's capture
voice line the first time a pony is captured, and an earlier Proton verification run
played it out loud through real speakers/headphones before this flag existed.
`game/systems/audio_safety.gd` (an autoload) also mutes the Master bus on its own
whenever it sees a `--screenshot...` arg, as a backstop in case a future invocation
forgets the flag.

The script:

1. Installs Proton if it isn't already present (calls `tools/install_proton.sh`).
2. Exports `build/filly-rancher-windows.exe` if missing (`docs/pipeline.md` §9),
   and hard-fails if a sibling `.pck` shows up (the single-file embedded-PCK
   export is the one this whole tier assumes).
3. Runs it via `proton run` with a **persistent** prefix at
   `~/.cache/filly-rancher-protonprefix` (reused across invocations — Proton's
   first-launch prefix setup is not free, and there is no reason to pay it on
   every run) unless overridden with `FILLY_PROTON_PREFIX`.
4. Wraps the whole run in `timeout --kill-after=15 <N>` (`FILLY_WINDOWS_RUN_TIMEOUT`,
   default 180s) so a Wine hang can never block forever — this project just
   added `game/scripts/gate_watchdog.gd` for exactly the "hung silently,
   reported nothing" failure mode inside the engine; this is the same
   discipline applied at the process level, for hangs the in-engine watchdog
   cannot see (Wine wedging before the engine has even started).
5. Reads `RANCH_OK` out of Godot's own `--log-file` (pointed at a
   Wine-translated path under a scratch dir), **not stdout** — the exported
   `.exe` is a GUI-subsystem binary, and like `.github/workflows/smoke_run.sh`
   already notes for the CI case, stdout capture through a GUI-subsystem
   binary is not reliable, so the engine's own log file is the trustworthy
   channel.
6. Exits non-zero if the marker is missing OR the run timed out, with a
   printed pointer back to this doc's interpretive-caveat section so a
   failure here doesn't get over-read as "the Windows build is broken."

Verified negative control: running with `FILLY_WINDOWS_RUN_TIMEOUT=1` reliably
produces `rc=124`, `FAIL: run timed out`, and a non-zero exit — the timeout
path is real, not just a comment.

## Where `user://` resolves under Proton (the Phase 1B–relevant finding)

Godot's `game/project.godot` sets no `application/config/use_custom_user_dir`
override, so the default rule applies: on Windows, `user://` maps to
`%APPDATA%\Godot\app_userdata\<project name>\`, where the project name is
`config/name` = `"Filly Rancher"`.

This was **not just inferred from Godot's documented behavior** — it was
confirmed empirically. Godot exported release builds write their own default
engine log to `user://logs/godot.log` regardless of what `--log-file` is
also pointed at, so after a single `tools/run_windows_build.sh` run, that
file existed inside the fresh Proton prefix at:

```
~/.cache/filly-rancher-protonprefix/pfx/drive_c/users/steamuser/AppData/Roaming/Godot/app_userdata/Filly Rancher/logs/godot.log
```

i.e. inside the Wine prefix, `%APPDATA%` resolved (verified directly via
`wine cmd /c "echo %APPDATA%"` against this same prefix) to
`C:\users\steamuser\AppData\Roaming`, and Godot appended
`Godot\app_userdata\Filly Rancher\` on top of that, exactly as documented.

**Practically, for Phase 1B save files:**

- The path is **per-user** (`steamuser` here is Proton's fixed in-prefix
  username — the friend's real Windows machine will use their actual Windows
  username instead) and **per-machine** (depends on wherever `%APPDATA%`
  points, which is not always the OS default on a machine with redirected
  profile folders). Nothing in save/load code should ever hardcode or guess
  this path — always go through `user://`, never construct an
  `AppData\Roaming\...` string by hand.
- It is a **completely different location and directory structure** than the
  Linux path (`~/.local/share/godot/app_userdata/Filly Rancher/` under
  `XDG_DATA_HOME`), which is exactly the divergence Phase 1B needs to design
  saves around — e.g. don't assume forward slashes, don't assume the parent
  directory pre-exists, and remember the Windows friend's save file lives
  somewhere the Linux owner will never casually stumble onto while poking
  around their own filesystem.
- This also means: **do not go looking for a save file at some fixed path in
  a bug report from the friend** without first asking them to paste the
  output of a `%APPDATA%`-based path, or have the game print
  `OS.get_user_data_dir()` somewhere visible/logged.

## Confirmed with an actual save file (Phase 1B Task 2)

The section above worked out where `user://` goes by finding Godot's own engine
log inside the prefix. Saves are now checked directly, by the game, on every run
of this tier: `game/world/ranch.gd`'s gate writes a save into a reserved scratch
slot (slot 9 — never the slot the game plays in), reads it back with a second,
independent `GameState`, compares every field, and prints the resolved path.
`bash tools/run_windows_build.sh` printed, from the exported `.exe` running
under Proton:

```
RANCH save user_dir=C:/users/steamuser/AppData/Roaming/Godot/app_userdata/Filly Rancher
  file=C:/users/steamuser/AppData/Roaming/Godot/app_userdata/Filly Rancher/saves/slot_9.json
  wrote=true reloaded=true loaded_at_boot=false owned=0
RANCH_OK ponies=49 props=110 assets=present
```

and the file was there on the host filesystem afterwards, at exactly the path
this doc predicted:

```
~/.cache/filly-rancher-protonprefix/pfx/drive_c/users/steamuser/AppData/Roaming/
  Godot/app_userdata/Filly Rancher/saves/slot_9.json
```

This is a verbatim capture from that Proton run at the time (Phase 1B Task 2), when the
census read `props=110`; the live gate has moved twice since (Phase 3's dressing slice, then
slice R2's replanting and placement passes) -- see `docs/testing.md` for the current count.

with the same human-readable, sorted, `"version": 1` JSON the Linux build
writes — the save format is byte-for-byte the same shape on both platforms,
which is what makes the spec's "trade a pony by sending each other a blob" work
between the Linux owner and the Windows friend.

**The second run is the interesting one.** Running it again exercises the path
Windows and Linux genuinely differ on: publishing a save over one that already
exists. Godot's `DirAccess.rename` is an atomic `rename()` on POSIX, but on
Windows it *removes* the destination first and then renames. The second Proton
run left both files in place —

```
slot_9.json        344 bytes
slot_9.json.bak    344 bytes
```

— i.e. the overwrite worked and `SaveIO`'s backup (which exists specifically to
cover that Windows remove-then-rename window, see the class comment in
`game/systems/save_io.gd`) was written where it should be.

**Still true, and worth repeating:** the path is per-user and per-machine.
`steamuser` is Proton's fixed in-prefix username; the friend's machine will use
their own. Nothing in save/load code constructs this path — everything goes
through `user://`, and the gate prints `OS.get_user_data_dir()` so a bug report
can just quote the log.
