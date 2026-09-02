#!/usr/bin/env bash
# Self-test for tools/convert_props.sh using a fake exporter and validator, so it runs in
# seconds and needs no Blender. Exit code is the verdict. Same shape and same reasoning as
# tools/test_convert_roster.sh, which is the character side of the same driver.
set -uo pipefail
cd "$(dirname "$0")/.."
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/manifest.txt" <<'EOF'
# id|source
good_barn|fakepack/models/barn_base.mdl
good_sign|fakepack/models/sign.mdl
bad_export|fakepack/models/bad.mdl
bad_validate|fakepack/models/badv.mdl
patch_prefix|fakepack/models/gb_tower_b.mdl
patch_suffix|fakepack/models/barn_gb.mdl
mirror|fakepack/models/barn_base_m.mdl
EOF

# Fake exporter: writes the --out file unless the source says "bad.mdl", and records the
# --max-texture it was handed, so the cap cannot silently stop being passed through.
cat > "$TMP/exporter.sh" <<'EOF'
#!/usr/bin/env bash
out=""; src=""; cap=""
while [ $# -gt 0 ]; do
  case "$1" in
    --out) out="$2"; shift 2;;
    --mdl) src="$2"; shift 2;;
    --max-texture) cap="$2"; shift 2;;
    *) shift;;
  esac
done
case "$src" in *bad.mdl) echo "fake exporter: boom" >&2; exit 1;; esac
mkdir -p "$(dirname "$out")"; printf 'fake %s\n' "$cap" > "$out"
EOF
chmod +x "$TMP/exporter.sh"

# Fake validator: fails for bad_validate.glb, and fails if --props was not passed. A prop
# ships no skin, so the default gate rejects every one of them; a driver that forgot the
# flag would report every model broken and the tally alone would not say why.
cat > "$TMP/validator.sh" <<'EOF'
#!/usr/bin/env bash
case " $* " in *" --props "*) ;; *) echo "fake validator: --props was not passed" >&2; exit 1;; esac
case "$1" in *bad_validate.glb) echo "fake validator: no meshes" >&2; exit 1;; esac
echo "meshes=1 skins=0 materials=1 textured=True animations=[]"
EOF
chmod +x "$TMP/validator.sh"

fails=0
check() { if [ "$1" != "$2" ]; then echo "FAIL: $3 (got '$1', want '$2')"; fails=$((fails+1)); else echo "ok: $3"; fi; }
run() {
  FILLY_EXPORTER="$TMP/exporter.sh" FILLY_VALIDATOR="$TMP/validator.sh" FILLY_OUT_DIR="$TMP/out" \
    bash tools/convert_props.sh --manifest "$TMP/manifest.txt" "$@" 2>&1
}

out=$(run); rc=$?
check "$rc" "1" "a manifest with failures and refusals exits 1"
check "$(echo "$out" | tail -1)" "PROP_CONVERT ok=2 failed=2 skipped=0 refused=3" "the summary counts each outcome"
check "$(echo "$out" | grep -c '^REFUSED patch_prefix:')" "1" "a gb_ prefixed ground patch is refused by name"
check "$(echo "$out" | grep -c '^REFUSED patch_suffix:')" "1" "a _gb suffixed ground patch is refused by name"
check "$(echo "$out" | grep -c '^REFUSED mirror:')" "1" "an _m mirrored duplicate is refused by name"
check "$([ -f "$TMP/out/patch_prefix.glb" ] && echo present || echo absent)" "absent" "a refused model never reaches the exporter"
check "$(cat "$TMP/out/good_barn.glb")" "fake 1024" "the texture cap reaches the exporter, 1024 by default"
# The one outcome the tally cannot show, and the same trap convert_roster.sh documents: a
# glb that exported but failed validation sits at the path this script uses to decide a
# model is already done, so leaving it there makes every later run SKIP it, forever.
check "$([ -f "$TMP/out/bad_validate.glb" ] && echo present || echo removed)" "removed" "a glb that failed validation is removed, not left to be skipped forever"

out=$(run --only good_barn); rc=$?
check "$rc" "0" "--only with a good model reaches no refusal and exits 0"
check "$(echo "$out" | tail -1)" "PROP_CONVERT ok=0 failed=0 skipped=1 refused=0" "an existing glb is skipped, not re-exported"

out=$(run --only good_barn --force --max-texture 512)
check "$(echo "$out" | tail -1)" "PROP_CONVERT ok=1 failed=0 skipped=0 refused=0" "--force re-exports"
check "$(cat "$TMP/out/good_barn.glb")" "fake 512" "--max-texture overrides the default"

out=$(run --dry-run); rc=$?
check "$rc:$(echo "$out" | grep -c '^WOULD ')" "1:2" "--dry-run lists only what would be exported and still fails on the refusals"

echo "PROP_CONVERT_SELFTEST failures=$fails"
exit $([ $fails -eq 0 ] && echo 0 || echo 1)
