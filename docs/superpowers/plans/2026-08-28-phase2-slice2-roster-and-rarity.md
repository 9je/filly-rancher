# Phase 2 Slice 2: Roster and Rarity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Take the roster from 6 characters to 45 by converting every remaining character already on disk through the proven pipelines, and spread the four rarity tiers across them so rarity means something to the hunt and to the wallet.

**Architecture:** A manifest (`tools/roster_manifest.txt`) names every character, its source file, and its pipeline (`sfm` or `blend`); a batch script (`tools/convert_roster.sh`) walks it, exports each missing or stale `.glb` with the existing `tools/export_blend.py`, validates each with the existing `tools/validate_gltf.py --require-anims`, and fails loudly on any character that does not convert. The game learns about a character purely by a `.tres` under `game/data/ponies/`, so the roster growth is data plus the existing `registry_gallery` gate, which already builds every registered character and asserts the three clips and a live hair simulation. No engine code changes are expected; two gate timeouts scale with the roster.

**Tech Stack:** Godot 4.5.2, Blender (portable, `tools/bin/blender`), SourceIO addon, GUT, bash.

**Spec:** `docs/superpowers/specs/2026-08-28-phase2-bigger-world-design.md`, build order item 2: "Roster and rarity. The 43 characters already on disk, converted through the proven SFM path, with rarity spread across them so the four tiers all have members."

## Global Constraints

- No em dash (U+2014) and no double hyphen (` -- `) in anything a player can read (display names) or in new code, comments, docs, or the manifest.
- Converted assets under `game/assets/converted/` are gitignored pipeline output; only the manifest, the script, the `.tres` files, tests and docs are committed. The script must be re-runnable on a fresh clone to regenerate everything.
- A gate prints `<NAME>_OK` only after deciding it passed; exit code is the verdict.
- `NO PONY EVER DIES`; nothing in this slice touches saves or ponies at runtime.
- The six existing `.tres` files keep their ids, rarities and stats (saves reference `data_id`).
- Every character that gets a `.tres` must pass `registry_gallery`: three authored clips and a `SpringBoneSimulator3D` under its skeleton. A character that cannot pass is left out of the roster (no `.tres`) and listed in the docs with the reason, never registered broken.
- Duplicates of tier-a characters (`twilightsparkle`, `rainbowdash`, `fluttershy` in the SFM pack) and the joke variant `raricow` are excluded. `pinkamena` (Pinkie's straight-mane canon variant) is included as its own character.
- Branch: `phase2-slice2-roster`. Commit after every task.

---

## The roster

45 characters after this slice: 6 existing, 2 new tier-a (Blender-native), 37 new tier-c (SFM). Rarity by canon prominence, with the four tiers all populated and the LEGENDARY tier deliberately small. Personality spread so no tier is all one personality. Favourite foods drawn from the shop's five (`hay`, `apple`, `carrot`, `daisy`, `daffodil`); a second favourite may be a flavour id with no `FoodData` (like the existing `muffin`, `cupcake`), which `Needs.is_favorite()` tolerates.

Rarity ints: COMMON 0, UNCOMMON 1, RARE 2, LEGENDARY 3. Personality ints: SHY 0, BOLD 1, CURIOUS 2.

| id | display_name | source | rarity | personality | favorite_foods | speed | stamina | spirit |
|---|---|---|---|---|---|---|---|---|
| applejack | Applejack | blend `Applejack_1-0/Applejack_1-0.blend` rig `AJ_Rig` | 2 | 1 | apple, hay | 4.6 | 7.0 | 6.5 |
| rarity | Rarity | blend `Rarity_1-0/Rarity_1-0.blend` rig `R_Rig` | 2 | 0 | daisy, daffodil | 3.3 | 4.5 | 7.5 |
| sunsetshimmer | Sunset Shimmer | sfm | 3 | 1 | apple, daffodil | 4.2 | 5.5 | 8.5 |
| songbirdserenade | Songbird Serenade | sfm | 3 | 0 | daisy, daffodil | 3.8 | 5.0 | 9.0 |
| pinkamena | Pinkamena | sfm | 2 | 0 | cupcake, hay | 3.9 | 5.5 | 4.0 |
| changelingdrone | Changeling | sfm | 2 | 1 | daisy, hay | 4.4 | 5.0 | 5.5 |
| trixie | Trixie | sfm | 2 | 1 | carrot, daffodil | 3.7 | 5.0 | 7.5 |
| shiningarmor | Shining Armor | sfm | 2 | 1 | apple, hay | 4.5 | 7.0 | 6.5 |
| spitfire | Spitfire | sfm | 2 | 1 | carrot, hay | 6.2 | 6.5 | 6.0 |
| maudpie | Maud Pie | sfm | 2 | 0 | hay | 3.0 | 7.5 | 5.0 |
| applebloom | Apple Bloom | sfm | 1 | 2 | apple, hay | 3.6 | 4.0 | 6.5 |
| sweetiebelle | Sweetie Belle | sfm | 1 | 0 | daisy, hay | 3.3 | 3.5 | 6.5 |
| scootaloo | Scootaloo | sfm | 1 | 1 | carrot, hay | 4.8 | 4.0 | 6.5 |
| soarin | Soarin | sfm | 1 | 2 | apple, hay | 6.0 | 6.0 | 5.5 |
| lightningdust | Lightning Dust | sfm | 1 | 1 | carrot, hay | 6.3 | 5.5 | 5.0 |
| cocopommel | Coco Pommel | sfm | 1 | 0 | daisy, hay | 3.2 | 4.5 | 6.0 |
| limestonepie | Limestone Pie | sfm | 1 | 1 | hay, carrot | 3.8 | 6.5 | 4.5 |
| marblepie | Marble Pie | sfm | 1 | 0 | hay, daisy | 3.1 | 5.0 | 5.0 |
| octavia | Octavia | sfm | 1 | 0 | daffodil, hay | 3.4 | 5.0 | 6.5 |
| vinylscratch | Vinyl Scratch | sfm | 1 | 1 | carrot, hay | 4.0 | 5.0 | 7.0 |
| cheerilee | Cheerilee | sfm | 1 | 2 | apple, hay | 3.4 | 5.0 | 6.0 |
| braeburn | Braeburn | sfm | 1 | 2 | apple, hay | 4.4 | 6.5 | 6.0 |
| drwhooves | Doctor Whooves | sfm | 1 | 2 | carrot, hay | 3.6 | 5.0 | 7.0 |
| derpyhooves (existing) | | | 0 | 2 | | | | |
| lyra | Lyra Heartstrings | sfm | 0 | 2 | daisy, hay | 3.6 | 4.5 | 6.0 |
| bonbon | Bon Bon | sfm | 0 | 0 | daisy, hay | 3.4 | 4.5 | 5.5 |
| minuette | Minuette | sfm | 0 | 2 | carrot, hay | 3.6 | 4.5 | 6.0 |
| carrottop | Carrot Top | sfm | 0 | 2 | carrot, hay | 3.5 | 5.0 | 5.5 |
| berrypunch | Berry Punch | sfm | 0 | 1 | apple, hay | 3.5 | 4.5 | 5.5 |
| caramel | Caramel | sfm | 0 | 0 | apple, hay | 3.7 | 5.0 | 5.0 |
| cloudchaser | Cloudchaser | sfm | 0 | 1 | carrot, hay | 5.2 | 5.0 | 5.5 |
| flitter | Flitter | sfm | 0 | 0 | daisy, hay | 5.0 | 4.5 | 5.5 |
| milkyway | Milky Way | sfm | 0 | 0 | hay, daisy | 3.3 | 4.5 | 5.0 |
| kerfuffle | Kerfuffle | sfm | 0 | 2 | daffodil, hay | 3.4 | 4.0 | 6.5 |
| pokeypierce | Pokey Pierce | sfm | 0 | 1 | apple, hay | 3.6 | 4.5 | 5.0 |
| redheart | Nurse Redheart | sfm | 0 | 0 | daisy, hay | 3.3 | 5.0 | 5.5 |
| aloeblossom | Aloe | sfm | 0 | 0 | daffodil, hay | 3.2 | 4.5 | 6.0 |
| lotusblossom | Lotus | sfm | 0 | 0 | daffodil, hay | 3.2 | 4.5 | 6.0 |
| mane_allgood | Mane Allgood | sfm | 0 | 2 | apple, hay | 3.4 | 5.0 | 5.5 |
| nightlight | Night Light | sfm | 0 | 2 | carrot, hay | 3.3 | 5.0 | 6.0 |

Excluded from the SFM pack: `twilightsparkle`, `rainbowdash`, `fluttershy`, `applejack`, `rarity` (the Blender-native tier-a versions are used instead), `pinkiepie`, `derpyhooves`, `starlightglimmer` (already shipped), `raricow` (joke). 37 used plus 9 excluded accounts for all 46 `.mdl` files.

Tier counts after the slice, existing six included: LEGENDARY 2 (sunsetshimmer, songbirdserenade), RARE 11 (twilight, rainbowdash, starlightglimmer, applejack, rarity, pinkamena, changelingdrone, trixie, shiningarmor, spitfire, maudpie), UNCOMMON 15 (pinkiepie, fluttershy and the 13 listed), COMMON 17 (derpyhooves and the 16 listed). The existing six keep their current values; derpyhooves appears in the table only to place her tier.

---

### Task 1: The manifest and the batch converter

**Files:**
- Create: `tools/roster_manifest.txt`
- Create: `tools/convert_roster.sh`
- Test: `tools/test_convert_roster.sh` (a bash self-test using a fake manifest and a fake exporter)

**Interfaces:**
- Manifest line format, one per character, `#` comments allowed: `id|kind|source|rig` where `kind` is `sfm` or `blend`, `source` is relative to `assets_raw/`, `rig` is the armature object name for `blend` and empty for `sfm`.
- `tools/convert_roster.sh [--only id[,id...]] [--force] [--dry-run]`. Exit 0 only if every selected character's `.glb` exists and passes `validate_gltf.py --require-anims`. Prints `ROSTER_CONVERT ok=<n> failed=<n> skipped=<n>` as its last line, with a `FAILED <id>: <reason>` line per failure above it.
- Environment: `FILLY_EXPORTER` overrides the exporter command (default `tools/bin/blender/blender -b -P tools/export_blend.py --` or, for `blend`, `tools/bin/blender/blender -b <source> -P tools/export_blend.py --`), and `FILLY_VALIDATOR` overrides `python3 tools/validate_gltf.py`, so the self-test can substitute fakes.

- [ ] **Step 1: Write the self-test first**

`tools/test_convert_roster.sh`:
```bash
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
check "$([ -f "$TMP/out/good_sfm.glb" ] && echo yes || echo no)" "yes" "a good sfm character was written"
check "$([ -f "$TMP/out/good_blend.glb" ] && echo yes || echo no)" "yes" "a good blend character was written"

out=$(FILLY_EXPORTER="$TMP/exporter.sh" FILLY_VALIDATOR="$TMP/validator.sh" FILLY_OUT_DIR="$TMP/out" \
  bash tools/convert_roster.sh --manifest "$TMP/manifest.txt" --only good_sfm 2>&1); rc=$?
check "$rc" "0" "--only with a good character exits 0"
check "$(echo "$out" | tail -1)" "ROSTER_CONVERT ok=1 failed=0 skipped=0" "--only converts one (and re-validates an existing glb as skipped=0 because it re-exports only when missing... see next check)"

out=$(FILLY_EXPORTER="$TMP/exporter.sh" FILLY_VALIDATOR="$TMP/validator.sh" FILLY_OUT_DIR="$TMP/out" \
  bash tools/convert_roster.sh --manifest "$TMP/manifest.txt" --only good_sfm,good_blend 2>&1); rc=$?
check "$(echo "$out" | tail -1)" "ROSTER_CONVERT ok=0 failed=0 skipped=2" "an existing glb is skipped, not re-exported"

out=$(FILLY_EXPORTER="$TMP/exporter.sh" FILLY_VALIDATOR="$TMP/validator.sh" FILLY_OUT_DIR="$TMP/out" \
  bash tools/convert_roster.sh --manifest "$TMP/manifest.txt" --only good_sfm --force 2>&1); rc=$?
check "$(echo "$out" | tail -1)" "ROSTER_CONVERT ok=1 failed=0 skipped=0" "--force re-exports"

out=$(FILLY_EXPORTER="$TMP/exporter.sh" FILLY_VALIDATOR="$TMP/validator.sh" FILLY_OUT_DIR="$TMP/out" \
  bash tools/convert_roster.sh --manifest "$TMP/manifest.txt" --dry-run 2>&1); rc=$?
check "$rc" "0" "--dry-run exits 0"
check "$(echo "$out" | grep -c '^WOULD ')" "2" "--dry-run lists only the characters that would be exported (the two without a glb)"

echo "ROSTER_CONVERT_SELFTEST failures=$fails"
exit $([ $fails -eq 0 ] && echo 0 || echo 1)
```

Fix the second `--only good_sfm` check's expectation once the script exists: after the first run `good_sfm.glb` exists, so `--only good_sfm` without `--force` must report `skipped=1`. Rewrite that check to `"ROSTER_CONVERT ok=0 failed=0 skipped=1"` and its label to "an existing glb is skipped", and drop the following duplicate check. The self-test must end with exactly nine `ok:` lines.

- [ ] **Step 2: Run the self-test to verify it fails**

Run: `bash tools/test_convert_roster.sh; echo exit=$?`
Expected: FAIL lines (the script does not exist), exit 1.

- [ ] **Step 3: Write the manifest**

`tools/roster_manifest.txt`, one line per new character from the roster table, in the order of the table. `sfm` sources are `sfm/SFM Ready Compiled Files/Models/reVAmped_ponies/revamped_<id>.mdl`; the two `blend` sources are given in the table. Header comment: what the format is, that the six shipped characters are listed too (so a fresh clone regenerates everything), and that exclusions are listed in `docs/pipeline.md`. Include the six existing characters with their real sources (`twilight|blend|blender-native/TwilightSparkle_1-0/TwilightSparkle_1-0.blend|TS_Rig`, `rainbowdash|blend|blender-native/RainbowDash_1-1/RainbowDash4.blend|RD_Rig`, `fluttershy|blend|blender-native/Fluttershy_1-0/Fluttershy_1-0.blend|FS_Rig`, and `pinkiepie`, `derpyhooves`, `starlightglimmer` as `sfm`).

- [ ] **Step 4: Write the converter**

`tools/convert_roster.sh`:
```bash
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
    echo "FAILED $id: validation failed, see $log"; failed=$((failed + 1)); continue
  fi
  echo "CONVERTED $id"; ok=$((ok + 1))
done < "$MANIFEST"

echo "ROSTER_CONVERT ok=$ok failed=$failed skipped=$skipped"
[ "$failed" -eq 0 ]
```

The `--dry-run` summary line must still print and exit 0 (the tally loop `continue`s before counting, so `ok=0 failed=0`).

- [ ] **Step 5: Run the self-test to verify it passes**

Run: `chmod +x tools/convert_roster.sh tools/test_convert_roster.sh && bash tools/test_convert_roster.sh; echo exit=$?`
Expected: nine `ok:` lines, `ROSTER_CONVERT_SELFTEST failures=0`, exit 0.

- [ ] **Step 6: Dry-run against the real manifest**

Run: `bash tools/convert_roster.sh --dry-run | tail -3`
Expected: 39 `WOULD` lines (the six shipped characters already have a `.glb` and are skipped), `ROSTER_CONVERT ok=0 failed=0 skipped=6`.

- [ ] **Step 7: Commit**

```bash
git add tools/roster_manifest.txt tools/convert_roster.sh tools/test_convert_roster.sh
git commit -m "feat: a roster manifest and a batch converter that regenerates every character"
```

---

### Task 2: Convert the roster and record what did not convert

**Files:**
- Modify: `docs/pipeline.md` (a "Roster" subsection under section 5b)
- Output (gitignored): `game/assets/converted/ponies/*.glb` and textures

- [ ] **Step 1: Run the conversion in the background and wait for it**

Run: `bash tools/convert_roster.sh > /tmp/roster_convert.log 2>&1; echo exit=$? >> /tmp/roster_convert.log`
This takes about 12 minutes (39 exports at roughly 17 s each, plus validation). Run it in the background and poll `tail -3 /tmp/roster_convert.log` no more often than every two minutes.
Expected: `ROSTER_CONVERT ok=39 failed=0 skipped=6`, exit 0. Every `FAILED` line names a character that must be investigated: open its log, and classify the failure as (a) a pipeline bug that affects many characters (fix `tools/sfm_rig.py` or `tools/export_blend.py` generically, never per character, and re-run with `--only`), or (b) a one-off model defect (leave the character out of the roster and record it in Step 3).

- [ ] **Step 2: Reimport and run the structural check on every new glb**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game --import > /dev/null 2>&1; for f in game/assets/converted/ponies/*.glb; do printf "%-22s " "$(basename $f .glb)"; python3 tools/validate_gltf.py "$f" --require-anims 2>&1 | tail -1; done`
Expected: every line ends in `textured=True animations=['gallop', 'idle', 'walk']`.

- [ ] **Step 3: Document the roster in docs/pipeline.md**

Under section 5b add `#### The roster manifest`: what `tools/roster_manifest.txt` and `tools/convert_roster.sh` are, the one-line command to regenerate everything on a fresh clone, the nine exclusions and why (`twilightsparkle`, `rainbowdash`, `fluttershy`, `applejack`, `rarity` have tier-a versions; `pinkiepie`, `derpyhooves`, `starlightglimmer` were already shipped; `raricow` is a joke variant; plus any character from Step 1 that failed for a model-specific reason, with its reason), and the tier counts. No dashes.

- [ ] **Step 4: Commit**

```bash
git add docs/pipeline.md
git commit -m "docs: the roster manifest, how to regenerate it, and what is excluded"
```

---

### Task 3: Author the 39 character data files, with a test that pins the roster's shape

**Files:**
- Create: `game/data/ponies/<id>.tres` for every row of the roster table except the existing derpyhooves row (39 files)
- Test: `game/test/test_roster_data.gd`

**Interfaces:**
- Each `.tres` is a `PonyData` resource with the exact shape of `game/data/ponies/pinkiepie.tres`: `id`, `display_name`, `model_path = "res://assets/converted/ponies/<id>.glb"`, `rarity`, `spawn_zones = Array[StringName]([&"ranch"])`, `favorite_foods`, `personality`, `voice_bank = ""`, `base_speed`, `base_stamina`, `base_spirit`.

- [ ] **Step 1: Write the failing test**

```gdscript
extends GutTest
## The roster's SHAPE, pinned. Phase 2 slice 2 took it from 6 to 45 characters, and
## every one of them is a .tres under game/data/ponies/; these tests are what stop a
## typo in one of fifty files from being a character who never spawns, sells for the
## wrong price, or shows a dash on screen.

const PonyRegistryScript := preload("res://systems/pony_registry.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")
const FoodRegistryScript := preload("res://systems/food_registry.gd")

const MIN_ROSTER := 45
const EXPECTED_TIERS := {
	PonyDataScript.Rarity.COMMON: 17,
	PonyDataScript.Rarity.UNCOMMON: 15,
	PonyDataScript.Rarity.RARE: 11,
	PonyDataScript.Rarity.LEGENDARY: 2,
}


func _roster() -> Dictionary:
	var registry: PonyRegistry = PonyRegistryScript.new()
	return registry.load_all("res://data/ponies")


func test_the_roster_is_at_least_forty_five() -> void:
	assert_gte(_roster().size(), MIN_ROSTER)


func test_every_id_matches_its_file_name() -> void:
	for file_name in DirAccess.get_files_at("res://data/ponies"):
		if not file_name.ends_with(".tres"):
			continue
		var data: PonyData = load("res://data/ponies/" + file_name)
		assert_eq(String(data.id), file_name.get_basename(),
			"%s must carry id %s" % [file_name, file_name.get_basename()])


func test_every_model_path_points_at_its_own_glb() -> void:
	for id in _roster():
		var data: PonyData = _roster()[id]
		assert_eq(data.model_path, "res://assets/converted/ponies/%s.glb" % id)


func test_display_names_are_unique_and_carry_no_dashes() -> void:
	var seen := {}
	for id in _roster():
		var name: String = _roster()[id].display_name
		assert_false(name.is_empty(), "%s needs a display name" % id)
		assert_false(seen.has(name), "duplicate display name '%s'" % name)
		seen[name] = true
		assert_false(name.contains("--") or name.contains("—"), "'%s' must not contain a dash" % name)


func test_every_rarity_tier_has_members_in_the_expected_numbers() -> void:
	var counts := {}
	for id in _roster():
		var r: int = _roster()[id].rarity
		counts[r] = int(counts.get(r, 0)) + 1
	for tier in EXPECTED_TIERS:
		assert_eq(int(counts.get(tier, 0)), EXPECTED_TIERS[tier],
			"tier %s should have %d members" % [PonyDataScript.Rarity.keys()[tier], EXPECTED_TIERS[tier]])


func test_every_personality_is_used_in_every_tier_that_has_more_than_two_members() -> void:
	var by_tier := {}
	for id in _roster():
		var data: PonyData = _roster()[id]
		if not by_tier.has(data.rarity):
			by_tier[data.rarity] = {}
		by_tier[data.rarity][data.personality] = true
	for tier in by_tier:
		if int(EXPECTED_TIERS.get(tier, 0)) <= 2:
			continue
		assert_eq(by_tier[tier].size(), PonyDataScript.Personality.size(),
			"tier %s should use every personality" % PonyDataScript.Rarity.keys()[tier])


func test_every_character_is_zoned_ranch_for_now() -> void:
	# Slice 3 splits the map into regions; until then every character must be reachable.
	for id in _roster():
		assert_true(_roster()[id].spawn_zones.has(&"ranch"), "%s must spawn on the ranch" % id)


func test_every_character_likes_at_least_one_food_the_market_sells() -> void:
	var foods: FoodRegistry = FoodRegistryScript.new()
	foods.load_all("res://data/foods")
	for id in _roster():
		var liked := false
		for food_id in _roster()[id].favorite_foods:
			if foods.by_id(food_id) != null:
				liked = true
		assert_true(liked, "%s must like something the Market can sell, or care items are pointless for her" % id)


func test_stats_are_in_the_range_the_existing_six_established() -> void:
	for id in _roster():
		var data: PonyData = _roster()[id]
		assert_between(data.base_speed, 2.5, 7.0, "%s speed" % id)
		assert_between(data.base_stamina, 3.0, 8.0, "%s stamina" % id)
		assert_between(data.base_spirit, 3.0, 9.5, "%s spirit" % id)
```

Read the six existing `.tres` files: `derpyhooves` likes `muffin, hay` and `pinkiepie` likes `cupcake, hay`, so `test_every_character_likes_at_least_one_food_the_market_sells` passes for them through `hay`. If `_roster()` is slow when called per test, cache it in `before_all()`.

- [ ] **Step 2: Run the test to verify it fails**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_roster_data.gd -gexit 2>&1 | grep -E "Tests|Passing|Failing"`
Expected: several failures (roster is 6, tier counts wrong).

- [ ] **Step 3: Write the 39 data files**

One `.tres` per row of the roster table, copying `game/data/pinkiepie.tres`'s exact shape. Use a fresh `id="1_<4chars>"` ext_resource id per file (the value is arbitrary but must be unique within the file). `favorite_foods` as `Array[StringName]([&"apple", &"hay"])`. Write them with a small generator script in the scratchpad if you prefer, but commit only the `.tres` files.

- [ ] **Step 4: Reimport, run the test, then the registry gate**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game --import > /dev/null 2>&1; tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_roster_data.gd -gexit 2>&1 | grep -E "Tests|Passing|Failing"`
Expected: 9 passing.
Run: `tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/registry_gallery.tscn 2>&1 | grep -E "BUILT|REGISTRY_(OK|FAILED)"; echo exit=${PIPESTATUS[0]}`
Expected: 45 `BUILT <id> anim_ok=true hair_ok=true` lines, `REGISTRY_OK count=45`, exit 0. If the gate's 30 s watchdog fires before 45 builds finish, that is Task 4's job; note the elapsed time. If any character reports `hair_ok=false` or `anim_ok=false`, that character is a Task 2 Step 1 case: fix the pipeline generically or exclude her (delete her `.tres`, adjust `EXPECTED_TIERS` and the docs, and say so in the commit message).

- [ ] **Step 5: Commit**

```bash
git add game/data/ponies/ game/test/test_roster_data.gd
git commit -m "feat: thirty-nine more canon characters, rarity spread across all four tiers"
```

---

### Task 4: Gates that scale with the roster

**Files:**
- Modify: `game/scenes/test/registry_gallery.gd` (the `GateWatchdogScript.arm(self, "REGISTRY")` call, line 33)
- Modify: `game/scenes/test/model_gallery.gd` (line 14) if it also builds every character
- Modify: `tools/run_tests.sh` (`MIN_TESTS`)

- [ ] **Step 1: Size the watchdogs**

From Task 3 Step 4's elapsed time, set `registry_gallery`'s watchdog to `max(30, 2 * elapsed)` seconds via the third argument of `arm()`, with a comment: the roster is forty-five characters and each build loads a 3 to 7 MB glb. Do the same for `model_gallery` only if it builds the whole registry (read it; if it builds a fixed three, leave it).

- [ ] **Step 2: Run every gate by exit code and the suite**

```bash
for s in smoke model_gallery walk_test terrain_probe registry_gallery playground camera_test wild_ponies capture_test market_test; do
  out=$(timeout 900 tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/$s.tscn 2>&1); rc=$?
  printf "%-18s exit=%-3s %s\n" $s $rc "$(echo "$out" | grep -oE '[A-Z_]+_(OK|FAILED)[^ ]*( checks=[0-9]+| count=[0-9]+)?' | head -1)"
done
out=$(timeout 900 tools/bin/godot --headless --audio-driver Dummy --path game world/ranch.tscn 2>&1); echo "ranch exit=$? $(echo "$out" | grep -oE 'RANCH_(OK|FAILED)[^"]*')"
bash tools/run_tests.sh 2>&1 | grep -E "^Tests|^Passing|All tests passed|FAILED"
```
Expected: every gate exit 0; `REGISTRY_OK count=45`; `RANCH_OK ponies=10 props=34 assets=present` (ten spawn slots, unchanged); suite green. Set `MIN_TESTS` to the reported count.

- [ ] **Step 3: Commit**

```bash
git add game/scenes/test/registry_gallery.gd game/scenes/test/model_gallery.gd tools/run_tests.sh
git commit -m "chore: gate watchdogs sized for a forty-five-character roster; test floor raised"
```

---

### Task 5: A contact sheet, so the owner can review forty-five ponies in one image

**Files:**
- Create: `tools/roster_sheet.sh`
- Output (not committed): `build/roster_sheet.png`

- [ ] **Step 1: Write the sheet script**

Uses the existing `scenes/test/visual_review.tscn` in `face` mode per character (it writes `<id>_face_front.png` into an output dir), then tiles them with Python PIL into a grid with the display name under each. Read `game/scenes/test/visual_review.gd`'s usage comment for the exact invocation (`xvfb-run -a tools/bin/godot --path game --audio-driver Dummy --resolution 1280x720 scenes/test/visual_review.tscn -- mode=face character=<id> out=<dir>`).

```bash
#!/usr/bin/env bash
# Render every registered character's face and tile them into build/roster_sheet.png.
# Slow (about 20 s per character under xvfb). Not a gate: it renders, a person looks.
set -uo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-build/roster_shots}"
mkdir -p "$OUT" build
for f in game/data/ponies/*.tres; do
  id=$(basename "$f" .tres)
  [ -f "$OUT/${id}_face_front.png" ] && continue
  timeout 300 xvfb-run -a tools/bin/godot --path game --audio-driver Dummy --resolution 640x360 \
    scenes/test/visual_review.tscn -- mode=face character="$id" out="$OUT" > /dev/null 2>&1 || echo "render failed: $id"
done
python3 - "$OUT" <<'PY'
import sys, glob, os
from PIL import Image, ImageDraw
out = sys.argv[1]
files = sorted(glob.glob(os.path.join(out, "*_face_front.png")))
cols = 8
w, h = 320, 200
rows = (len(files) + cols - 1) // cols
sheet = Image.new("RGB", (cols * w, rows * h), (30, 30, 30))
draw = ImageDraw.Draw(sheet)
for i, f in enumerate(files):
    im = Image.open(f).resize((w, h - 20))
    x, y = (i % cols) * w, (i // cols) * h
    sheet.paste(im, (x, y))
    draw.text((x + 6, y + h - 18), os.path.basename(f).replace("_face_front.png", ""), fill=(240, 240, 240))
sheet.save("build/roster_sheet.png")
print("ROSTER_SHEET characters=%d file=build/roster_sheet.png" % len(files))
PY
```

- [ ] **Step 2: Run it in the background and look at the result**

Run: `bash tools/roster_sheet.sh > /tmp/roster_sheet.log 2>&1` (about 17 minutes). Then open `build/roster_sheet.png` with the Read tool and look at every face: heads level, eyes present with pupils, coat colours plausible, no character rendering white or black. Any character that looks wrong is a Task 2 Step 1 case.

- [ ] **Step 3: Commit the script and note the sheet in the docs**

Add one line to `docs/pipeline.md`'s roster subsection: how to regenerate the sheet.
```bash
git add tools/roster_sheet.sh docs/pipeline.md
git commit -m "tools: a roster contact sheet for reviewing forty-five ponies at a glance"
```

---

## Self-review

**Spec coverage.** "The 43 characters already on disk, converted through the proven SFM path": Task 1 and 2 (37 SFM plus 2 Blender-native; of the 46 on-disk SFM files, 3 were already shipped, 5 have tier-a versions, and `raricow` is excluded). "Rarity spread across them so the four tiers all have members": Task 3's table and test. Gates and the test floor: Task 4. A way for the owner to review the result: Task 5.

**Placeholder scan.** None.

**Type consistency.** `convert_roster.sh`'s flags in Task 1 match the self-test's invocations; the manifest format is stated once and used by both. `test_roster_data.gd`'s `EXPECTED_TIERS` matches the table's tier counts (17 / 15 / 11 / 2 = 45).
