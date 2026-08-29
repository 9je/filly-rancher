#!/usr/bin/env bash
# Convert every character in tools/roster_manifest.txt that has no .glb yet (or all of
# them with --force), through the same two commands docs/pipeline.md documents by hand:
# tools/export_blend.py for the export, tools/validate_gltf.py --require-anims for the
# check. One character failing does not stop the others; the last line is the tally and
# the exit code is the verdict.
#
# usage: tools/convert_roster.sh [--manifest FILE] [--only id[,id...]] [--force] [--dry-run]
#
# FILLY_EXPORTER, FILLY_VALIDATOR and FILLY_OUT_DIR override the tools and the output
# directory so tools/test_convert_roster.sh can run this in seconds without Blender.
set -uo pipefail
cd "$(dirname "$0")/.."

MANIFEST="tools/roster_manifest.txt"
ONLY=""
FORCE=0
DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --manifest) MANIFEST="$2"; shift 2 ;;
    --only) ONLY="$2"; shift 2 ;;
    --force) FORCE=1; shift ;;
    --dry-run) DRY=1; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

OUT_DIR="${FILLY_OUT_DIR:-game/assets/converted/ponies}"
VALIDATOR="${FILLY_VALIDATOR:-python3 tools/validate_gltf.py}"
BLENDER="tools/bin/blender/blender"

selected() {
  [ -z "$ONLY" ] && return 0
  case ",$ONLY," in *",$1,"*) return 0 ;; esac
  return 1
}

export_one() {
  local id="$1" kind="$2" source="$3" rig="$4" out="$5"
  local src="assets_raw/$source"
  case "$kind" in
    sfm)
      if [ -n "${FILLY_EXPORTER:-}" ]; then
        "$FILLY_EXPORTER" --mdl-in "$src" --out "$out" --anims --rotate-z 180 --scale 2.0
      else
        "$BLENDER" -b -P tools/export_blend.py -- --mdl-in "$src" --out "$out" --anims --rotate-z 180 --scale 2.0
      fi ;;
    blend)
      if [ -n "${FILLY_EXPORTER:-}" ]; then
        "$FILLY_EXPORTER" "$src" --out "$out" --object "$rig" --anims --rotate-z 180 --scale 0.5
      else
        "$BLENDER" -b "$src" -P tools/export_blend.py -- --out "$out" --object "$rig" --anims --rotate-z 180 --scale 0.5
      fi ;;
    *) echo "unknown kind '$kind'" >&2; return 1 ;;
  esac
}

ok=0; failed=0; skipped=0
mkdir -p "$OUT_DIR"
while IFS='|' read -r id kind source rig; do
  case "$id" in ''|\#*) continue ;; esac
  selected "$id" || continue
  out="$OUT_DIR/$id.glb"
  if [ -f "$out" ] && [ "$FORCE" -eq 0 ]; then
    skipped=$((skipped + 1)); continue
  fi
  if [ "$DRY" -eq 1 ]; then
    echo "WOULD $id ($kind, $source)"; continue
  fi
  log="${TMPDIR:-/tmp}/convert_${id}.log"
  if ! export_one "$id" "$kind" "$source" "$rig" "$out" > "$log" 2>&1; then
    echo "FAILED $id: export failed, see $log"; failed=$((failed + 1)); rm -f "$out"; continue
  fi
  if ! $VALIDATOR "$out" --require-anims >> "$log" 2>&1; then
    echo "FAILED $id: validation failed, see $log"; failed=$((failed + 1)); rm -f "$out"; continue
  fi
  echo "CONVERTED $id"; ok=$((ok + 1))
done < "$MANIFEST"

echo "ROSTER_CONVERT ok=$ok failed=$failed skipped=$skipped"
[ "$failed" -eq 0 ]
