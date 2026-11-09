#!/usr/bin/env bash
# Bake ambient occlusion into every converted prop and building (tools/blender_props/bake_ao.py),
# in place, keeping the unbaked .glb beside it as <name>.glb.noao so a re-run starts clean.
# Run after tools/convert_props.sh, then a Godot --import. P8, docs/aaa-review-2026-11-08.md 2.1.
#   tools/bake_ao_all.sh [samples]
set -uo pipefail
cd "$(dirname "$0")/.."
SAMPLES="${1:-24}"
ok=0; bad=0
for f in game/assets/converted/props/*.glb; do
  [ -f "$f.noao" ] || cp "$f" "$f.noao"
  if blender -b -P tools/blender_props/bake_ao.py -- "$f.noao" "$f" "$SAMPLES" 2>&1 | grep -q BAKE_AO_OK; then
    ok=$((ok + 1))
  else
    bad=$((bad + 1)); echo "BAKE_AO_FAILED $f"; cp "$f.noao" "$f"
  fi
done
echo "BAKE_AO_ALL ok=$ok failed=$bad"
