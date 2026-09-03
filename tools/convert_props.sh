#!/usr/bin/env bash
# Convert every model in tools/prop_manifest.txt that has no .glb yet (or all of them with
# --force), through the two commands docs/pipeline.md section 5 documents by hand:
# tools/convert_mdl.py for the SourceIO import and the glTF export, tools/validate_gltf.py
# --props for the check. One model failing does not stop the others; the last line is the
# tally and the exit code is the verdict. This is tools/convert_roster.sh's shape, applied
# to props: read that file first if anything here looks arbitrary.
#
# usage: tools/convert_props.sh [--manifest FILE] [--only id[,id...]] [--force] [--dry-run]
#                               [--max-texture N]
#
# GROUND PATCHES AND MIRRORS ARE REFUSED BY NAME, and a refusal fails the run. Every
# building in the PonySFM environment packs ships a gb_ sibling that is its ground decal (a
# flat dirt and grass patch, not a building) and an _m sibling that is a mirrored duplicate
# of it. A manifest line naming one is a curation mistake, not an input to work around, so
# it is reported and counted rather than quietly converted into a floating rug.
#
# FILLY_EXPORTER, FILLY_VALIDATOR and FILLY_OUT_DIR override the tools and the output
# directory so tools/test_convert_props.sh can run this in seconds without Blender.
set -uo pipefail
cd "$(dirname "$0")/.."

MANIFEST="tools/prop_manifest.txt"
ONLY=""
FORCE=0
DRY=0
# 1024 is the cap the probe argued for: barn_base.glb came out 34 MB at native VTF
# resolution, almost all of it baked PNG, and thirty five models at that rate is a
# multi gigabyte tree for scenery nobody stands closer than a few metres to.
MAX_TEXTURE=1024
while [ $# -gt 0 ]; do
  case "$1" in
    --manifest) MANIFEST="$2"; shift 2 ;;
    --only) ONLY="$2"; shift 2 ;;
    --force) FORCE=1; shift ;;
    --dry-run) DRY=1; shift ;;
    --max-texture) MAX_TEXTURE="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

OUT_DIR="${FILLY_OUT_DIR:-game/assets/converted/props}"
VALIDATOR="${FILLY_VALIDATOR:-python3 tools/validate_gltf.py}"
BLENDER="tools/bin/blender/blender"
INBOX="assets-inbox"

selected() {
  [ -z "$ONLY" ] && return 0
  case ",$ONLY," in *",$1,"*) return 0 ;; esac
  return 1
}

# Prints why this model may not be converted, and returns 0 when there is a reason.
refused_reason() {
  case "$1" in
    gb_*) echo "ground patch (gb_ prefix)"; return 0 ;;
    *_gb) echo "ground patch (_gb suffix)"; return 0 ;;
    *_m)  echo "mirrored duplicate (_m suffix)"; return 0 ;;
  esac
  return 1
}

export_one() {
  local mdl="$1" out="$2"
  if [ -n "${FILLY_EXPORTER:-}" ]; then
    "$FILLY_EXPORTER" --mdl "$mdl" --out "$out" --max-texture "$MAX_TEXTURE"
  else
    "$BLENDER" -b -P tools/convert_mdl.py -- \
      --mdl "$mdl" --out "$out" --max-texture "$MAX_TEXTURE"
  fi
}

ok=0; failed=0; skipped=0; refused=0
# Only when something might actually be written. --dry-run reports what it WOULD convert
# and must not leave an output directory behind as a side effect of being asked.
[ "$DRY" -eq 1 ] || mkdir -p "$OUT_DIR"
while IFS='|' read -r id source; do
  case "$id" in ''|\#*) continue ;; esac
  selected "$id" || continue
  base="$(basename "$source" .mdl)"
  if reason="$(refused_reason "$base")"; then
    echo "REFUSED $id: $base is a $reason"; refused=$((refused + 1)); continue
  fi
  out="$OUT_DIR/$id.glb"
  if [ -f "$out" ] && [ "$FORCE" -eq 0 ]; then
    skipped=$((skipped + 1)); continue
  fi
  if [ "$DRY" -eq 1 ]; then
    echo "WOULD $id ($source)"; continue
  fi
  log="${TMPDIR:-/tmp}/convert_prop_${id}.log"
  # < /dev/null on both tools below: this loop reads the manifest ON STDIN, so anything
  # they read from stdin is eaten out of the manifest and every model after it is never
  # converted at all. Blender reads stdin. See tools/convert_roster.sh's own note.
  if ! export_one "$INBOX/$source" "$out" > "$log" 2>&1 < /dev/null; then
    echo "FAILED $id: export failed, see $log"; failed=$((failed + 1)); rm -f "$out"; continue
  fi
  if ! $VALIDATOR "$out" --props >> "$log" 2>&1 < /dev/null; then
    echo "FAILED $id: validation failed, see $log"; failed=$((failed + 1)); rm -f "$out"; continue
  fi
  echo "CONVERTED $id"; ok=$((ok + 1))
done < "$MANIFEST"

echo "PROP_CONVERT ok=$ok failed=$failed skipped=$skipped refused=$refused"
[ "$failed" -eq 0 ] && [ "$refused" -eq 0 ]
