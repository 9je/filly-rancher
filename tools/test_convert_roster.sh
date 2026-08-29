#!/usr/bin/env bash
# Self-test for tools/convert_roster.sh using a fake exporter and validator, so it runs in
# seconds and needs no Blender. Exit code is the verdict.
set -uo pipefail
cd "$(dirname "$0")/.."
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/manifest.txt" <<'EOF'
# id|kind|source|rig
good_sfm|sfm|sfm/fake/good.mdl|
good_blend|blend|blender-native/fake/good.blend|G_Rig
bad_export|sfm|sfm/fake/bad.mdl|
bad_validate|sfm|sfm/fake/badv.mdl|
EOF

# Fake exporter: writes the --out file unless the source says "bad.mdl".
cat > "$TMP/exporter.sh" <<'EOF'
#!/usr/bin/env bash
out=""; src=""
while [ $# -gt 0 ]; do
  case "$1" in --out) out="$2"; shift 2;; --mdl-in) src="$2"; shift 2;; *.blend) src="$1"; shift;; *) shift;; esac
done
case "$src" in *bad.mdl) echo "fake exporter: boom" >&2; exit 1;; esac
mkdir -p "$(dirname "$out")"; echo "fake" > "$out"
EOF
chmod +x "$TMP/exporter.sh"

# Fake validator: fails for badv.glb.
cat > "$TMP/validator.sh" <<'EOF'
#!/usr/bin/env bash
case "$1" in *bad_validate.glb) echo "fake validator: no anims" >&2; exit 1;; esac
echo "meshes=1 skins=1 materials=1 textured=True animations=['gallop', 'idle', 'walk']"
EOF
chmod +x "$TMP/validator.sh"

fails=0
check() { if [ "$1" != "$2" ]; then echo "FAIL: $3 (got '$1', want '$2')"; fails=$((fails+1)); else echo "ok: $3"; fi; }

out=$(FILLY_EXPORTER="$TMP/exporter.sh" FILLY_VALIDATOR="$TMP/validator.sh" FILLY_OUT_DIR="$TMP/out" \
  bash tools/convert_roster.sh --manifest "$TMP/manifest.txt" 2>&1); rc=$?
check "$rc" "1" "a manifest with failures exits 1"
check "$(echo "$out" | tail -1)" "ROSTER_CONVERT ok=2 failed=2 skipped=0" "the summary counts each outcome"
check "$(echo "$out" | grep -c '^FAILED bad_export:')" "1" "an export failure is named"
check "$(echo "$out" | grep -c '^FAILED bad_validate:')" "1" "a validation failure is named"
check "$([ -f "$TMP/out/good_sfm.glb" ] && [ -f "$TMP/out/good_blend.glb" ] && echo yes || echo no)" "yes" "the good sfm and blend characters were written"

out=$(FILLY_EXPORTER="$TMP/exporter.sh" FILLY_VALIDATOR="$TMP/validator.sh" FILLY_OUT_DIR="$TMP/out" \
  bash tools/convert_roster.sh --manifest "$TMP/manifest.txt" --only good_sfm 2>&1); rc=$?
check "$rc" "0" "--only with a good character exits 0"
check "$(echo "$out" | tail -1)" "ROSTER_CONVERT ok=0 failed=0 skipped=1" "an existing glb is skipped, not re-exported"

out=$(FILLY_EXPORTER="$TMP/exporter.sh" FILLY_VALIDATOR="$TMP/validator.sh" FILLY_OUT_DIR="$TMP/out" \
  bash tools/convert_roster.sh --manifest "$TMP/manifest.txt" --only good_sfm --force 2>&1); rc=$?
check "$(echo "$out" | tail -1)" "ROSTER_CONVERT ok=1 failed=0 skipped=0" "--force re-exports"

out=$(FILLY_EXPORTER="$TMP/exporter.sh" FILLY_VALIDATOR="$TMP/validator.sh" FILLY_OUT_DIR="$TMP/out" \
  bash tools/convert_roster.sh --manifest "$TMP/manifest.txt" --dry-run 2>&1); rc=$?
check "$rc:$(echo "$out" | grep -c '^WOULD ')" "0:2" "--dry-run exits 0 and lists only the characters that would be exported (the two without a glb)"

echo "ROSTER_CONVERT_SELFTEST failures=$fails"
exit $([ $fails -eq 0 ] && echo 0 || echo 1)
