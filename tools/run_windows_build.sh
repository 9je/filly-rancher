#!/usr/bin/env bash
# Runs the exported Windows .exe through Steam Proton on THIS Linux machine and
# asserts it reaches the RANCH_OK marker -- the local, rendering- and
# Windows-file-path-capable counterpart to CI's windows-latest headless smoke
# run (.github/workflows/smoke_run.sh). See docs/windows-testing.md for what
# this tier proves and, importantly, what it does not.
#
# Exports (or reuses) build/filly-rancher-windows.exe, launches it under a
# pinned Proton-GE build via tools/install_proton.sh (installed if missing),
# and greps its output for RANCH_OK. Exits non-zero if the marker is absent OR
# the run times out -- this project just had to add watchdogs
# (game/scripts/gate_watchdog.gd) for exactly the "hung silently, reported
# nothing" failure mode, and an external wrapper needs the same discipline for
# failures the in-engine watchdog cannot see (Wine/Proton hanging before the
# engine has even started).
#
# usage: tools/run_windows_build.sh [--headless|--render] [--rebuild]
#   --headless   (default) run with --headless, check for RANCH_OK only.
#   --render     also do a windowed run under xvfb-run with --screenshot-dir,
#                saving 6 PNGs -- see docs/windows-testing.md for what to look
#                for and how it compares to the Linux build's own screenshots.
#   --rebuild    re-export build/filly-rancher-windows.exe even if present.
set -uo pipefail
cd "$(dirname "$0")/.."

MODE="headless"
REBUILD=0
for arg in "$@"; do
  case "$arg" in
    --headless) MODE="headless" ;;
    --render)   MODE="render" ;;
    --rebuild)  REBUILD=1 ;;
    *) echo "unknown argument: $arg" >&2; exit 1 ;;
  esac
done

for c in timeout; do
  command -v "$c" >/dev/null || { echo "missing required command: $c" >&2; exit 1; }
done
if [ "$MODE" = "render" ]; then
  command -v xvfb-run >/dev/null || { echo "missing required command: xvfb-run (needed for --render)" >&2; exit 1; }
fi

GODOT="tools/bin/godot"
WIN_EXE="build/filly-rancher-windows.exe"
PROTON_VER="GE-Proton11-5"
COMPAT_ROOT="${STEAM_COMPAT_TOOLS_D:-$HOME/.steam/root/compatibilitytools.d}"
PROTON_DIR="$COMPAT_ROOT/$PROTON_VER"
# Persistent (not recreated per run) so repeated runs don't pay Proton's
# first-launch prefix-build cost every time -- it is idempotent to reuse.
PREFIX_DIR="${FILLY_PROTON_PREFIX:-$HOME/.cache/filly-rancher-protonprefix}"
RUN_TIMEOUT_SEC="${FILLY_WINDOWS_RUN_TIMEOUT:-180}"

# ---------------------------------------------------------------------------
# 1. Proton: install if this is a fresh machine, otherwise reuse.
# ---------------------------------------------------------------------------
if [ ! -x "$PROTON_DIR/proton" ]; then
  echo "== Proton not found at $PROTON_DIR -- installing $PROTON_VER ==" >&2
  bash tools/install_proton.sh || { echo "ERROR: tools/install_proton.sh failed" >&2; exit 1; }
fi

# ---------------------------------------------------------------------------
# 2. Windows export: build it if missing (or forced), per docs/pipeline.md §9.
# ---------------------------------------------------------------------------
if [ "$REBUILD" -eq 1 ] || [ ! -f "$WIN_EXE" ]; then
  echo "== Exporting $WIN_EXE (docs/pipeline.md §9) ==" >&2
  [ -x "$GODOT" ] || { echo "ERROR: $GODOT not found -- run 'bash tools/setup_env.sh' first" >&2; exit 1; }
  mkdir -p build
  "$GODOT" --headless --path game --export-release "Windows" "$(pwd)/$WIN_EXE" \
    || { echo "ERROR: Windows export failed" >&2; exit 1; }
fi

[ -f "$WIN_EXE" ] || { echo "ERROR: $WIN_EXE still missing after export step" >&2; exit 1; }

# Single-file embedded-PCK export expected -- a sibling .pck means the export
# preset regressed to the non-embedded layout, which this whole tier assumes
# is not the case (§9: "single-file embedded-PCK .exe, no sibling .pck").
SIBLING_PCK="${WIN_EXE%.exe}.pck"
if [ -f "$SIBLING_PCK" ]; then
  echo "ERROR: found sibling $SIBLING_PCK next to $WIN_EXE -- expected a single-file export (embed_pck)" >&2
  exit 1
fi

mkdir -p "$PREFIX_DIR"
export STEAM_COMPAT_DATA_PATH="$PREFIX_DIR"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.steam/steam"
# Proton's own PROTON_LOG-file machinery (unrelated to Godot's --log-file,
# used only for verbose wine/dxvk debug logs) requires SteamGameId to be set
# at all -- discovered by tracing why `PROTON_LOG=1 proton run` produced zero
# bytes of log output until this was set. Harmless dummy app id; nothing here
# talks to Steam's actual servers.
export SteamGameId=0
export SteamAppId=0

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# Godot's exported .exe is a GUI-subsystem binary -- like the CI script notes
# (.github/workflows/smoke_run.sh), stdout capture through Wine is not
# reliable, so RANCH_OK is looked for in Godot's own --log-file instead. That
# path is handed to the *Windows* binary, so it must be a Windows-style path;
# Wine maps the Linux root to the Z: drive, so an absolute Linux path with
# backslashes substituted for slashes round-trips correctly without needing
# `winepath` -- verified by hand against this exact invocation before being
# relied on here.
ENGINE_LOG_UNIX="$WORKDIR/ranch_windows_run.log"
ENGINE_LOG_WIN="Z:$(printf '%s' "$ENGINE_LOG_UNIX" | tr '/' '\\')"

RUN_ARGS=(--log-file "$ENGINE_LOG_WIN")
if [ "$MODE" = "headless" ]; then
  RUN_ARGS+=(--headless)
else
  SHOTS_DIR_UNIX="$WORKDIR/shots"
  mkdir -p "$SHOTS_DIR_UNIX"
  SHOTS_DIR_WIN="Z:$(printf '%s' "$SHOTS_DIR_UNIX" | tr '/' '\\')"
  RUN_ARGS+=(-- "--screenshot-dir=$SHOTS_DIR_WIN")
fi

echo "== Running $WIN_EXE under $PROTON_VER (mode=$MODE, timeout=${RUN_TIMEOUT_SEC}s) ==" >&2
STDOUT_LOG="$WORKDIR/stdout.log"

# --kill-after backstops a process that ignores SIGTERM (observed nowhere so
# far with Proton, but the whole point of a watchdog is not needing to have
# observed the hang first). rc=124 (or 137 if it needed the KILL) is the
# unambiguous timeout signal `timeout` documents.
run_cmd=("$PROTON_DIR/proton" run "$(pwd)/$WIN_EXE" "${RUN_ARGS[@]}")
if [ "$MODE" = "render" ]; then
  timeout --kill-after=15 "$RUN_TIMEOUT_SEC" \
    xvfb-run -a -s "-screen 0 1280x720x24" "${run_cmd[@]}" \
    >"$STDOUT_LOG" 2>&1
else
  timeout --kill-after=15 "$RUN_TIMEOUT_SEC" "${run_cmd[@]}" >"$STDOUT_LOG" 2>&1
fi
rc=$?

# Best-effort: tear down this prefix's wineserver so a killed run doesn't
# leave a wine process pinning the prefix for the next invocation. Never
# fails the script -- this is cleanup, not a correctness check.
"$PROTON_DIR/files/bin/wineserver" -k 2>/dev/null || true

echo "== proton run exit code: $rc ==" >&2
echo "== stdout/stderr ==" >&2
cat "$STDOUT_LOG" >&2 2>/dev/null || true
echo "== engine log ($ENGINE_LOG_UNIX) ==" >&2
cat "$ENGINE_LOG_UNIX" >&2 2>/dev/null || echo "(engine wrote no log file)" >&2
echo "== end of captured output ==" >&2

fail=0

if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then
  echo "FAIL: run timed out after ${RUN_TIMEOUT_SEC}s (rc=$rc) -- treating as a hang, not a hard bug" >&2
  fail=1
elif [ "$rc" -ne 0 ]; then
  echo "FAIL: proton run exited $rc (expected 0)" >&2
  fail=1
fi

COMBINED="$WORKDIR/combined.log"
: >"$COMBINED"
cat "$STDOUT_LOG" >>"$COMBINED" 2>/dev/null || true
cat "$ENGINE_LOG_UNIX" >>"$COMBINED" 2>/dev/null || true

if grep -q 'RANCH_OK' "$COMBINED"; then
  echo "PASS: RANCH_OK marker found" >&2
else
  echo "FAIL: no RANCH_OK marker in stdout or engine log" >&2
  echo "  A Proton failure here is a LEAD to investigate, not proof of a Windows bug --" >&2
  echo "  see docs/windows-testing.md's interpretive-caveat section before concluding" >&2
  echo "  anything about the real Windows build from this alone." >&2
  fail=1
fi

if [ "$MODE" = "render" ] && [ "$fail" -eq 0 ]; then
  shot_count="$(find "$SHOTS_DIR_UNIX" -name '*.png' 2>/dev/null | wc -l)"
  echo "== $shot_count screenshot(s) saved under $SHOTS_DIR_UNIX (removed on exit -- copy out first if you need them) ==" >&2
  if [ "$shot_count" -eq 0 ]; then
    echo "FAIL: --render requested but zero screenshots were produced" >&2
    fail=1
  else
    # Keep the shots around past the trap for inspection -- copy rather than
    # rely on the workdir, which is always cleaned up.
    OUT_DIR="build/windows_proton_shots"
    rm -rf "$OUT_DIR"
    mkdir -p "$OUT_DIR"
    cp "$SHOTS_DIR_UNIX"/*.png "$OUT_DIR"/ 2>/dev/null || true
    echo "== copied to $OUT_DIR/ ==" >&2
  fi
fi

exit "$fail"
