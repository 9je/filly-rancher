#!/usr/bin/env bash
#
# One-command release publishing: exports both platforms fresh from THIS machine
# (which has the real, gitignored game/assets/converted/** on disk -- see
# docs/distribution.md), smoke-tests the Linux build, and publishes both
# single-file binaries to a GitHub Release via `gh release create`.
#
# CI (`.github/workflows/build-and-smoke.yml`) deliberately does NOT publish
# releases: a CI checkout has no game/assets/converted/** (it's gitignored), so
# a CI-built export is assetless. Only a machine that has run the asset
# pipeline (tools/setup_env.sh + the conversion tools under tools/) can produce
# a release worth handing to a player. That is why this script is local-only.
#
# usage:
#   tools/publish_release.sh <tag> [--draft|--publish] [--notes "text"]
#
#   <tag>       required. The git tag AND the release tag, e.g. v0.1.0.
#               Also used to name the artifacts:
#                 filly-rancher-<tag>-windows.exe
#                 filly-rancher-<tag>-linux.x86_64
#   --draft     publish as a draft (default -- nothing goes out until someone
#               hits "Publish release" in the GitHub UI, or re-runs with
#               --publish).
#   --publish   publish for real, immediately visible to anyone with repo
#               access. Only pass this once you actually mean it.
#   --notes     release notes text (default: a short auto-generated note).
#
# Refuses to run on a dirty working tree, refuses to run if the local asset
# pipeline hasn't produced real assets, and prints the release URL at the end.

set -euo pipefail
cd "$(dirname "$0")/.."

DRAFT=1
TAG=""
NOTES=""

while [ $# -gt 0 ]; do
  case "$1" in
    --draft) DRAFT=1; shift ;;
    --publish) DRAFT=0; shift ;;
    --notes) NOTES="${2:?--notes requires a value}"; shift 2 ;;
    -h|--help)
      sed -n '2,26p' "$0"
      exit 0
      ;;
    -*)
      echo "ERROR: unknown option: $1" >&2
      exit 1
      ;;
    *)
      if [ -n "$TAG" ]; then
        echo "ERROR: unexpected extra argument: $1" >&2
        exit 1
      fi
      TAG="$1"
      shift
      ;;
  esac
done

if [ -z "$TAG" ]; then
  echo "usage: tools/publish_release.sh <tag> [--draft|--publish] [--notes \"text\"]" >&2
  exit 1
fi

# --- preflight ---------------------------------------------------------

for c in git gh; do
  command -v "$c" >/dev/null || { echo "ERROR: missing required command: $c" >&2; exit 1; }
done

if [ ! -x tools/bin/godot ]; then
  echo "ERROR: tools/bin/godot not found -- run 'bash tools/setup_env.sh' first." >&2
  exit 1
fi

# A dirty tree could mean the build you're about to export and ship doesn't
# match any commit -- refuse rather than publish something unreproducible.
if [ -n "$(git status --porcelain)" ]; then
  echo "ERROR: working tree is dirty. Commit or stash your changes before publishing a release." >&2
  git status --short >&2
  exit 1
fi

# Guard against publishing an assetless build from a checkout that never ran
# the asset pipeline (game/assets/converted/** is gitignored -- see
# docs/distribution.md). A handful of real pony assets is a good proxy for
# "the pipeline has actually run here".
if [ -z "$(find game/assets/converted/ponies -maxdepth 1 -iname '*.glb' 2>/dev/null)" ]; then
  echo "ERROR: game/assets/converted/ponies has no .glb files -- this machine hasn't run the asset" >&2
  echo "       pipeline (game/assets/converted/** is gitignored, so a bare/CI checkout has none)." >&2
  echo "       Run the pipeline first (see docs/pipeline.md), then retry." >&2
  exit 1
fi

echo "== publishing release '$TAG' (draft=$DRAFT) =="

# --- export --------------------------------------------------------------

mkdir -p build
rm -f build/filly-rancher-linux.x86_64 build/filly-rancher-linux.pck \
      build/filly-rancher-windows.exe build/filly-rancher-windows.pck

echo "-- exporting Linux --"
tools/bin/godot --headless --path game --export-release "Linux" \
  ../build/filly-rancher-linux.x86_64 2>&1 | tee /tmp/publish-export-linux.log

echo "-- exporting Windows --"
tools/bin/godot --headless --path game --export-release "Windows" \
  ../build/filly-rancher-windows.exe 2>&1 | tee /tmp/publish-export-windows.log

if grep -nE 'ERROR:|Failed loading resource|Failed to load resource|Cannot open file|Resource file not found' \
     /tmp/publish-export-linux.log /tmp/publish-export-windows.log; then
  echo "ERROR: export emitted resource errors above -- refusing to publish a broken build." >&2
  exit 1
fi

# Both presets set binary_format/embed_pck=true (game/export_presets.cfg), so each
# platform should be a single file with no sibling .pck -- verify that, not assume it.
if ls build/*.pck >/dev/null 2>&1; then
  echo "ERROR: found a .pck next to the export -- embed_pck should make these single-file builds." >&2
  exit 1
fi

for f in build/filly-rancher-linux.x86_64 build/filly-rancher-windows.exe; do
  [ -s "$f" ] || { echo "ERROR: expected export output missing: $f" >&2; exit 1; }
done

# --- smoke-test the Linux build (same assertion CI uses) -----------------

echo "-- smoke-testing Linux build --"
bash .github/workflows/smoke_run.sh ./build/filly-rancher-linux.x86_64

# The Windows .exe can't run on this (Pop!_OS) machine -- CI's windows-latest
# job is what actually executes it. Local publishing trusts the last green
# CI run for Windows-side correctness; see docs/distribution.md.

# --- name the artifacts ---------------------------------------------------

LINUX_OUT="build/filly-rancher-${TAG}-linux.x86_64"
WINDOWS_OUT="build/filly-rancher-${TAG}-windows.exe"
cp build/filly-rancher-linux.x86_64 "$LINUX_OUT"
cp build/filly-rancher-windows.exe "$WINDOWS_OUT"
chmod +x "$LINUX_OUT"

echo "== artifacts =="
ls -la "$LINUX_OUT" "$WINDOWS_OUT"

# --- publish ---------------------------------------------------------------

if [ -z "$NOTES" ]; then
  NOTES="Filly Rancher $TAG.

Windows: download filly-rancher-${TAG}-windows.exe and double-click it. No installer, no unzip.
Linux: download filly-rancher-${TAG}-linux.x86_64, \`chmod +x\` it, and run it.

Unsigned binary warnings are expected -- see docs/distribution.md for what to
tell people (Windows SmartScreen, antivirus false positives)."
fi

DRAFT_FLAG="--draft"
[ "$DRAFT" -eq 0 ] && DRAFT_FLAG=""

echo "== creating GitHub release =="
# shellcheck disable=SC2086
gh release create "$TAG" \
  "$LINUX_OUT" "$WINDOWS_OUT" \
  --title "Filly Rancher $TAG" \
  --notes "$NOTES" \
  $DRAFT_FLAG

RELEASE_URL="$(gh release view "$TAG" --json url -q .url)"
echo "== done =="
echo "Release URL: $RELEASE_URL"
