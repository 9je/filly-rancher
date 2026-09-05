# Slice R2 -- World Coherence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Retire every placeholder box building and turquoise Kenney blob tree from view, replace them with owned show-style PonySFM geometry, kit-bash a Spectra Palace that reads as a destination, and re-compose the map so no screenshot shows two art styles fighting.

**Architecture:** `game/world/building.gd` keeps its whole job -- collision shell, plinth, door apron, seating arithmetic, census membership -- and gains three exported fields (`model_file`, `model_scale`, `model_yaw`). When a model is named and its `.glb` exists, `build()` hides the wall/roof/gable/lintel meshes and stands the converted model on the plinth instead; when it does not (CI, a fresh clone, an assetless checkout) the primitive shell renders exactly as it does today. Nothing that reads a building reads its meshes: the interact verb is a flat XZ distance from the node's `global_position`, attendants and signage are derived from `width`/`depth`/`door_width`/`ridge_height`/the node basis, and the census is `buildings.get_child_count()`. Every one of those survives untouched because the node names, the origins and the exported floats stay authoritative. The Spectra Palace gets a new sibling class, `game/world/palace_facade.gd`, that kit-bashes a wide facade from Ponyville Environments pieces and dresses it with the newly sourced PonySFM Neon Lights Pack.

**Tech Stack:** Godot 4.5.2 (GDScript), GUT 9.5.0, Blender + SourceIO via `tools/convert_props.sh`, xvfb for rendered gates, Python 3 + Pillow for the sheet tiler.

**Spec:** `docs/superpowers/specs/2026-09-04-presentation-redesign-design.md` (section 5 is this slice; sections 1-2 bind globally; acceptance items 7 and 12 are the bar).

**Supporting ledgers (read before task 1):**
- `scratchpad/ledgers/redesign/redesign-inventory.md` sections 1-2 (owned assets, placeholder anchors)
- `scratchpad/ledgers/redesign/palace-sourcing.md` (why the Palace is a kit-bash and where the neon comes from)

---

## Global Constraints

- **`game/systems/` IS READ-ONLY FOR THIS ENTIRE SLICE.** Not one file under it may be edited, for any reason. THE MATH DOES NOT CHANGE.
- **NO PONY EVER DIES.** No rigging the casino. No change to odds, payouts, prices, or story logic.
- **No realistic pony vocalizations.** The one sanctioned neigh gag (`Sound.GAG_ID`) stays exactly as shipped; this slice adds no audio at all.
- **Sources: never create an account, never use any email address.** PonySFM downloads are no-login direct links. Every source URL is recorded in `tools/prop_manifest.txt` (which is committed; `assets-inbox/` is gitignored, so a URL written only there is a URL that is lost).
- **No em dashes anywhere** -- not in code, not in comments, not in docs, not in commit messages. The house dash is `" -- "`.
- **Suite green at every commit.** `MIN_TESTS` in `tools/run_tests.sh` is **1572** today; it is raised to the measured count in the final task and proved both ways with `FILLY_MIN_TESTS`. It never decreases.
- **`FILLY_TEST_SAVE_DIR="$(mktemp -d)"` prefixes every gate, test and screenshot invocation in this plan.** The owner plays out of this checkout; a run without it writes the live `user://saves`.
- **Gates run `--headless`** except: the model gallery and every screenshot run, which need `xvfb-run -a`; and the sound gate, which is `--headless` and **NEVER** xvfb.
- **Machine courtesy:** every `godot`, `blender` and `ffmpeg` command carries `nice -n 19 `. Never run two Godot processes at once.
- **Project conventions:** `.gd.uid` files are committed, `.tscn.uid`/`.tres.uid` are not; `const` arrays are plain array literals; a bare autoload identifier fails the parse sweep, so use the existing preload/dispatcher patterns; new scripts go in `game/world/` beside their neighbours.
- **SAVE COMPATIBILITY IS A HARD REQUIREMENT.** The owner has a live playthrough. Building **origins** and node **names** in `game/world/ranch.tscn` must not change; plot slot ids and positions must not change; `Buildings/Depot/Crate` and `Buildings/Palace/Cage` must keep their local transforms. Task 3 loads a synthesized pre-R2 save and proves the world rebuilds.
- **Commit style:** lowercase imperative, one commit per task's final step unless a task says otherwise.

### The gate commands, once, in the shape every task uses them

```bash
# The suite (parse sweep + GUT + the three guards)
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 bash tools/run_tests.sh

# The ranch census gate
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 tools/bin/godot --headless --audio-driver Dummy \
  --path game world/ranch.tscn

# The model gallery, props row (xvfb, NOT headless-only -- it needs a renderer for the eye row)
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 xvfb-run -a tools/bin/godot --audio-driver Dummy \
  --path game scenes/test/model_gallery.tscn -- --props

# The hosted gates (all --headless)
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 tools/bin/godot --headless --audio-driver Dummy \
  --path game scenes/test/market_test.tscn        # MARKET_OK checks=69
#  ... region_test.tscn REGION_OK checks=49 | world_test.tscn WORLD_OK checks=32
#  ... collection_test.tscn COLLECTION_OK checks=73 | ledger_test.tscn LEDGER_OK checks=87
#  ... depot_test.tscn DEPOT_OK checks=72 | creation_test.tscn CREATION_OK checks=93
#  ... casino_test.tscn CASINO_OK checks=76 | story_test.tscn STORY_OK checks=58

# The sound gate -- --headless, NEVER xvfb
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 tools/bin/godot --headless --audio-driver Dummy \
  --path game scenes/test/sound_test.tscn         # SOUND_OK ids=37

# A screenshot pass (xvfb; NOT --headless, there is no viewport to capture without one)
mkdir -p build/r2_shots
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 timeout 900 xvfb-run -a tools/bin/godot \
  --path game --audio-driver Dummy --resolution 1600x900 world/ranch.tscn -- \
  "--screenshot-dir=$(pwd)/build/r2_shots"
```

### The measurements this plan was written against

`GALLERY_OK count=35` today. Every native size below is the `PROP <file> size=(x, y, z)` line the props row printed on 2026-09-05, **before** `Props.MLP_SCALE` (0.5193) is applied. The seated column is `native * 0.5193`.

| model | native (x, y, z) | seated (w x d x h) |
|---|---|---|
| `saa_barn.glb` | 9.354, 13.479, 9.487 | 4.86 x 4.93 x 7.00 |
| `saa_shed.glb` | 1.987, 3.512, 2.555 | 1.99 x 2.56 x 3.51 (carries `SCALE_FIX` 1.93) |
| `pv_general.glb` | 20.448, 10.289, 9.762 | 10.62 x 5.07 x 5.34 |
| `pv_general_sign.glb` | 2.722, 1.555, 1.219 | 1.41 x 0.63 x 0.81 |
| `pv_wide_b.glb` | 13.984, 11.106, 6.619 | 7.26 x 3.44 x 5.77 |
| `pv_tower_b.glb` | 12.110, 14.315, 5.877 | 6.29 x 3.05 x 7.43 |
| `pv_courtyard_b.glb` | 7.506, 8.619, 6.344 | 3.90 x 3.29 x 4.48 |
| `pv_balcony_b.glb` | 6.442, 7.046, 6.951 | 3.35 x 3.61 x 3.66 |
| `pv_pink_b.glb` | 4.456, 6.982, 7.483 | 2.31 x 3.89 x 3.63 |
| `pv_bridged_b.glb` | 5.426, 6.930, 4.118 | 2.82 x 2.14 x 3.60 |

`game/world/props.gd`'s `LAYOUT` holds **104** entries today; `buildings.get_child_count()` is **7** (Barn, Farmhouse, Market, Board, Depot, Palace, Mailbox), so `RANCH_OK ponies=49 props=111 assets=present`. Of the 104: **39** are `kenney_tree_*`, one is `kenney_windmill.glb`, one is `kenney_watermill.glb`, one is `kenney_market_stall.glb`, one is `pv_general.glb` and one is `pv_general_sign.glb`.

### Spec ambiguities resolved before the tasks were written

1. **"The Building class survives ONLY as the invisible interaction/collision shell"** -- the *walls, roof, gables and lintel* retire from view. The **plinth (`Floor`) and the door apron (`DoorApron`) stay visible**, because `test_building_base.gd` asserts both by name on the shipped map and because they are what stops the terrain z-fighting a building's base. The plinth is recoloured to `Props.SKIRT_COLOUR` so it reads as turned earth under an MLP model rather than as a wooden base that does not match.
2. **"a second ranch structure uses `saa_shed.glb`"** -- the yard shed is a `Props.LAYOUT` entry, not a seventh `Building` node. It has no door the game opens, no attendant and no interaction radius; making it a `Building` would move `buildings.get_child_count()` and the census for nothing. It is placed in task 8.
3. **"Farmhouse/Board/Depot cast from the six town buildings by footprint"** -- the Board's shipped footprint is 3.0 x 1.2 m with no doorway, and the smallest town piece (`pv_bridged_b`, 2.82 x 2.14 seated) is the only one that fits. It gets that piece **plus** a real notice board mounted on its front, built through the existing `LobbySign` class, so the request board still reads as a request board.
4. **"the Market becomes `pv_general.glb` (+ its sign)"** -- the standalone `pv_general` and `pv_general_sign` `LAYOUT` entries at (19, -2) and (-1, 5) are **deleted**. They only ever stood there because the Market could not be a mesh; now it is one, and the sign moves onto the Market's own door face.
5. **The Palace shell keeps `width = 14.0`, `depth = 9.0`, `ridge_height = 4.6`.** `game/test/test_strip.gd` restates those as literals and `ranch.gd`'s `PALACE_MAX_RELIEF` check samples the hard-coded corners `(+-7.0, +-4.5)`. The kit-bash is built to fill that rectangle rather than the rectangle being resized to the kit-bash.
6. **The Palace facade pieces and the neon signs are children of `Buildings/Palace`, not `Props.LAYOUT` entries.** They are one structure, not scenery, and keeping them out of `LAYOUT` keeps the census a statement about the map's props.
7. **The interior fill light is skipped for a modelled building.** An invisible `MeshInstance3D` casts no shadow, so an `OmniLight3D` inside hidden walls would light the grass outside them -- a glowing barn in daylight. Spec section 9 puts interiors out of scope; the doorway stays a threshold.
8. **Kenney survivors.** `kenney_market_stall.glb` stays (neutral small clutter beside the request board, exactly what spec section 1 permits). `kenney_windmill.glb` and `kenney_watermill.glb` go: `building.gd`'s own header calls them "a bare X of sails with no tower behind it" and "a bare waterwheel with no mill", which is the signature-Kenney read the spec sends off the map.

---

## Task order and batching

Sourcing first (task 1), then the shell (2), the buildings (3), the boards (4), the Palace (5, 6), the environment (7, 8), the terrain (9), the close-out (10).

**Same-shape, batchable pairs:** tasks 4 and 6 are both "replace a sign's geometry and give its board/trim pair a real standoff"; tasks 7 and 8 are both "edit `Props.LAYOUT`, re-run the ranch gate, re-render the shots". Run each pair back to back with one reviewer if you are batching.

---

### Task 1: Source and convert the new PonySFM models

**Files:**
- Modify: `tools/prop_manifest.txt` (whole file: header comment gains a sources block; new rows appended per section)
- Modify: `game/scenes/test/model_gallery.gd:36` (`PROP_PREFIXES`)
- Modify: `game/test/test_ranch_world.gd:152` (`PROP_PREFIXES`)
- Modify: `docs/testing.md:974-988` (the `GALLERY_OK count=` paragraph)
- Modify: `docs/pipeline.md:1006` (the "35 lines of `id|source`" sentence)
- Creates (gitignored, not committed): `assets-inbox/neon-lights-pack.zip`, `assets-inbox/ponysfm-neon-lights/`, new `.glb` files under `game/assets/converted/props/`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: converted `.glb` files named `saa_tree_wide.glb`, `saa_tree_narrow.glb`, `saa_tree_dead_narrow.glb`, `saa_tree_dead_wide.glb`, `saa_dead_tree_large.glb`, `saa_dirt_road.glb`, `saa_small_dirt_pile.glb`, `pv_ogb_1.glb`, `pv_ogb_2.glb`, `pv_courtyard_b_balcony.glb`, and one `neon_<name>.glb` per model in the Neon Lights Pack. A committed comment block in `tools/prop_manifest.txt` headed `# NEON IDS:` naming exactly the neon ids that converted, which task 5 reads. `PROP_PREFIXES` in both files gains `"neon_"`.

- [ ] **Step 1: Download the Neon Lights Pack, no account, no email**

The direct link is recorded in `scratchpad/ledgers/redesign/palace-sourcing.md` and needs no login. `WebFetch` is Cloudflare-403'd on this host; `curl` with a browser User-Agent is not.

```bash
cd /home/admin/Documents/filly-rancher
curl -fL --retry 2 -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36" \
  -o assets-inbox/neon-lights-pack.zip \
  "https://ponysfm.com/rev/1527/download?token=rTSR1JfUy3UF4kf5x7fwnw"
ls -l assets-inbox/neon-lights-pack.zip
```

Expected: a file of roughly 7.2 MiB. If the download fails or is an HTML error page rather than a zip (`file assets-inbox/neon-lights-pack.zip` must say `Zip archive data`), STOP and report it -- do not go looking for a mirror that wants an account.

- [ ] **Step 2: Extract it and probe what it actually ships**

```bash
mkdir -p assets-inbox/ponysfm-neon-lights
unzip -o assets-inbox/neon-lights-pack.zip -d assets-inbox/ponysfm-neon-lights
find assets-inbox/ponysfm-neon-lights -name '*.mdl' | sort
```

Expected: six `.mdl` paths (the sourcing report counted 6 MDL, 28 VMT, 34 VTF, 0 BSP). Write the six paths down; they are the `source` half of the manifest rows in step 3. Any file whose basename starts with `gb_`, ends `_gb` or ends `_m` is refused by `tools/convert_props.sh` by name -- leave those out of the manifest rather than trying to convert them.

- [ ] **Step 3: Add the manifest rows and the sources block**

Edit `tools/prop_manifest.txt`. Append this block to the header comment (after the existing "NOT HERE ON PURPOSE" paragraph, before the first `# ---` section):

```
# SOURCES, so the URL a model came from is in git rather than only in the gitignored inbox.
# Every one is a no-login direct download; no account was ever created and no email was used.
#   Sweet Apple Acres        https://ponysfm.com/sweet-apple-acres-release-page
#   Ponyville Environments   https://ponysfm.com/ponyville-environments-release-page
#   Ponyville General        https://ponysfm.com/ponyville-general-building
#   Ponyville Schoolhouse    https://ponysfm.com/ponyville-schoolhouse-download
#   MLP Scenebuild Props     https://ponysfm.com/scenebuild-props
#   Las Pegasus Games PT1    https://ponysfm.com/las-pegasus-games-pt1
#   Neon Lights Pack         https://ponysfm.com/neon-lights-pack
#                            rev 1527, direct: https://ponysfm.com/rev/1527/download?token=rTSR1JfUy3UF4kf5x7fwnw
```

Append to the Sweet Apple Acres section:

```
saa_tree_wide|ponysfm-sweet-apple-acres/models/Sweet_Apple_Acres/tree_wide.mdl
saa_tree_narrow|ponysfm-sweet-apple-acres/models/Sweet_Apple_Acres/tree_narrow.mdl
saa_tree_dead_wide|ponysfm-sweet-apple-acres/models/Sweet_Apple_Acres/tree_dead_wide.mdl
saa_tree_dead_narrow|ponysfm-sweet-apple-acres/models/Sweet_Apple_Acres/tree_dead_narrow.mdl
saa_dead_tree_large|ponysfm-sweet-apple-acres/models/Sweet_Apple_Acres/dead_tree_large.mdl
saa_dirt_road|ponysfm-sweet-apple-acres/models/Sweet_Apple_Acres/dirt_road.mdl
saa_small_dirt_pile|ponysfm-sweet-apple-acres/models/Sweet_Apple_Acres/small_dirt_pile.mdl
```

Append to the Ponyville town row section:

```
# Three more pieces, so the town row keeps six DISTINCT buildings after the Farmhouse, the
# Board and the Depot take wide_b, bridged_b and tower_b for themselves.
pv_ogb_1|ponysfm-environments/models/Ponyville_Environments/ogb_1.mdl
pv_ogb_2|ponysfm-environments/models/Ponyville_Environments/ogb_2.mdl
pv_courtyard_b_balcony|ponysfm-environments/models/Ponyville_Environments/courtyard_b_balcony.mdl
```

Append a new section at the end, with one row per `.mdl` found in step 2 (ids lowercased, `neon_` prefixed, `-` and spaces turned into `_`):

```
# --- Neon Lights Pack, the Spectra Palace's dressing ------------------------------------
# THE PALACE IS A KIT BASH AND THIS IS WHY. scratchpad/ledgers/redesign/palace-sourcing.md
# searched PonySFM for casino, Las Pegasus, Gladmane, resort, hotel, vegas, gambling, slot,
# dice, carnival, fairground and boardwalk and found no casino structure anywhere that does
# not want an account. These are signs, not a building; the building is Ponyville
# Environments pieces standing shoulder to shoulder.
neon_<name>|ponysfm-neon-lights/<path from step 2>
```

- [ ] **Step 4: Prove the driver still refuses what it should, before spending Blender time**

```bash
cd /home/admin/Documents/filly-rancher && bash tools/test_convert_props.sh
```

Expected: exit 0. This runs `convert_props.sh` against stub exporter/validator scripts in seconds, including both refusal rules.

- [ ] **Step 5: Dry-run the manifest, then convert only the new ids**

```bash
cd /home/admin/Documents/filly-rancher
bash tools/convert_props.sh --dry-run | tail -20
```

Expected: `WOULD` lines for exactly the new ids and nothing else (the 35 existing `.glb` files already exist, so they are skipped), and a final `PROP_CONVERT ok=0 failed=0 skipped=35 refused=0`. If any `REFUSED` line appears, a manifest row names a `gb_`/`_gb`/`_m` model -- fix the row, do not work around the refusal.

```bash
nice -n 19 bash tools/convert_props.sh 2>&1 | tail -25
```

Expected: one `CONVERTED <id>` per new row and `PROP_CONVERT ok=<n> failed=0 skipped=35 refused=0`, where `<n>` is the number of rows you added. This runs Blender per model and takes minutes.

- [ ] **Step 6: Import the new assets into Godot's cache**

```bash
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 tools/bin/godot --headless --path game --import
```

Expected: exit 0. Skipping this is `docs/testing.md`'s quirk 3: about nineteen tests go red on a stale import cache with no hint printed.

- [ ] **Step 7: Teach the gallery and the layout guard about the `neon_` family**

In `game/scenes/test/model_gallery.gd`, line 36:

```gdscript
const PROP_PREFIXES := ["saa_", "pv_", "mlp_", "school_", "lp_", "neon_"]
```

In `game/test/test_ranch_world.gd`, line 152:

```gdscript
const PROP_PREFIXES := ["kenney_", "saa_", "pv_", "mlp_", "school_", "lp_", "neon_"]
```

- [ ] **Step 8: Run the gallery and record the real count and the new native sizes**

```bash
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 xvfb-run -a tools/bin/godot --audio-driver Dummy \
  --path game scenes/test/model_gallery.tscn -- --props 2>&1 | grep -E "^PROP |GALLERY_OK"
```

Expected: a `PROP <file> size=(x, y, z) meshes=N materials=N textured=N` line for every model including the new ones, and `GALLERY_OK count=<measured>`. The count is `35 + <rows you added>`. **Write the measured number down and the native size of every new model** -- tasks 5, 7 and 8 place these and need the sizes. Any new model reporting `textured=0` or an empty AABB fails the gate; if one does, re-run `tools/convert_props.sh --only <id> --force` and look at `${TMPDIR:-/tmp}/convert_prop_<id>.log`.

- [ ] **Step 9: Record the neon ids where task 5 will find them**

Append to `tools/prop_manifest.txt`, directly under the neon section, the ids that actually converted:

```
# NEON IDS: neon_<a>, neon_<b>, neon_<c>, neon_<d>, neon_<e>, neon_<f>
# game/world/palace_facade.gd mounts these by name. Change one here and change it there.
```

- [ ] **Step 10: Update the two docs that name the count**

In `docs/testing.md`, the paragraph at lines 974-988: change `GALLERY_OK\ncount=35` to the measured count, change "`count=35` is the size of the prop manifest, and it is 35 rather than 43 for exactly this reason" to the measured pair, and add `neon_` to the list "(`saa_`, `pv_`, `mlp_`, `school_`, `lp_`)".

In `docs/pipeline.md` line 1006: change "35 lines of `id|source`" to the measured count, and change the sample output at line 1002 (`PROP_CONVERT ok=35 ...`) to say `ok=<measured>` for a fresh clone.

- [ ] **Step 11: Run the suite and commit**

```bash
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 bash tools/run_tests.sh
```

Expected: `---- All tests passed! ----`, no `Ignoring script`, exit 0.

```bash
git add tools/prop_manifest.txt game/scenes/test/model_gallery.gd game/test/test_ranch_world.gd \
  docs/testing.md docs/pipeline.md
git commit -m "feat: source the neon pack and convert the trees, roads and town pieces r2 needs"
```

---

### Task 2: Building learns to wear a converted model

**Files:**
- Modify: `game/world/building.gd` (add exports after line 193; change `build()` at 210-337; change `_slab()` at 453-475; new `_stand_model()`)
- Test: `game/test/test_building_model.gd` (create), `game/test/test_building_model.gd.uid` (Godot writes it on first import -- commit it)

**Interfaces:**
- Consumes: `Props.PROP_DIR` (`"res://assets/converted/props/"`), `Props.MLP_SCALE` (0.5193), `Props.SKIRT_COLOUR`, `Props.world_aabb(root: Node3D) -> AABB` -- all already preloaded in `building.gd` as `PropsScript`.
- Produces: on `Building`, three new exports `@export var model_file: String`, `@export var model_scale: float`, `@export var model_yaw: float`; one new method `func wears_a_model() -> bool`; a child node named `Model` (a `Node3D` holding the instanced `.glb`) when one is worn. Task 3 sets the exports in `ranch.tscn`; tasks 4 and 5 call `wears_a_model()`.

- [ ] **Step 1: Write the failing tests**

Create `game/test/test_building_model.gd`:

```gdscript
extends GutTest
## THE SHELL WEARS A MODEL, OR IT DOES NOT AND STILL STANDS.
##
## game/assets/converted/ is gitignored, so CI and a fresh clone have no props at all. A
## building that only renders when its .glb is present would leave the CI runner with a map
## of invisible collision. Both halves are tested here: the modelled path on a machine that
## has run the pipeline, and the fallback path, which is what a missing model_file proves.

const BuildingScript := preload("res://world/building.gd")
const PropsScript := preload("res://world/props.gd")

const SHELL_MESHES := ["WallBack", "WallLeft", "WallRight", "RoofLeft", "RoofRight", "Gables"]


func _bare() -> Building:
	var b: Building = BuildingScript.new()
	b.width = 6.0
	b.depth = 4.0
	b.wall_height = 3.0
	b.ridge_height = 4.2
	b.door_width = 2.0
	b.door_height = 2.6
	add_child_autofree(b)
	return b


func test_a_building_with_no_model_file_wears_nothing_and_renders_its_own_shell() -> void:
	var b := _bare()
	b.build()
	assert_false(b.wears_a_model(), "an unnamed model is not a worn one")
	assert_null(b.get_node_or_null(^"Model"), "nothing should have been instanced")
	for part: String in SHELL_MESHES:
		var node := b.get_node_or_null(NodePath(part)) as MeshInstance3D
		assert_not_null(node, "the primitive shell still builds %s" % part)
		assert_true(node.visible, "%s renders when no model stands" % part)


func test_a_model_file_that_is_not_on_this_machine_falls_back_to_the_shell() -> void:
	var b := _bare()
	b.model_file = "there_is_no_such_prop.glb"
	b.build()
	assert_false(b.wears_a_model(), "a named model that does not exist is not worn")
	var wall := b.get_node_or_null(^"WallBack") as MeshInstance3D
	assert_not_null(wall, "the fallback shell built")
	assert_true(wall.visible, "the fallback shell renders")


func test_a_worn_model_hides_the_walls_and_the_roof_and_keeps_the_plinth_and_the_apron() -> void:
	var b := _bare()
	b.model_file = "saa_shed.glb"
	b.build()
	if not b.wears_a_model():
		pass_test("no converted props on this machine; the fallback tests above cover it")
		return
	for part: String in SHELL_MESHES:
		var node := b.get_node_or_null(NodePath(part)) as MeshInstance3D
		assert_not_null(node, "%s is still built, for its collision" % part)
		assert_false(node.visible, "%s must not render behind a model" % part)
	var floor_node := b.get_node_or_null(^"Floor") as MeshInstance3D
	assert_not_null(floor_node, "the plinth is still built")
	assert_true(floor_node.visible, "the plinth still renders: it is what the model stands on")
	var apron := b.get_node_or_null(^"DoorApron") as MeshInstance3D
	assert_not_null(apron, "the apron is still built")
	assert_true(apron.visible, "the apron still renders: it is the threshold")


func test_a_worn_model_stands_on_the_plinth_and_never_below_the_skirt() -> void:
	var b := _bare()
	b.model_file = "saa_shed.glb"
	b.build()
	if not b.wears_a_model():
		pass_test("no converted props on this machine")
		return
	var model := b.get_node_or_null(^"Model") as Node3D
	assert_not_null(model, "the model was instanced")
	var box: AABB = PropsScript.world_aabb(model)
	assert_almost_eq(box.position.y, BuildingScript.FLOOR_TOP, 0.02,
		"the model's own floor meets the top of the plinth")
	assert_almost_eq(box.get_center().x, 0.0, 0.05, "the model is centred on the shell in x")
	assert_almost_eq(box.get_center().z, 0.0, 0.05, "the model is centred on the shell in z")


func test_a_worn_model_lights_nothing_because_hidden_walls_cast_no_shadow() -> void:
	var b := _bare()
	b.model_file = "saa_shed.glb"
	b.build()
	if not b.wears_a_model():
		pass_test("no converted props on this machine")
		return
	assert_null(b.get_node_or_null(^"InteriorFill"),
		"an omni inside invisible walls lights the grass outside them")


func test_a_shell_with_no_model_keeps_its_interior_fill() -> void:
	var b := _bare()
	b.build()
	assert_not_null(b.get_node_or_null(^"InteriorFill"),
		"the primitive shell is a closed box and still needs its light")


func test_the_plinth_under_a_model_is_turned_earth_rather_than_timber() -> void:
	var b := _bare()
	b.model_file = "saa_shed.glb"
	b.build()
	if not b.wears_a_model():
		pass_test("no converted props on this machine")
		return
	var floor_node := b.get_node_or_null(^"Floor") as MeshInstance3D
	var mat: StandardMaterial3D = (floor_node.mesh as BoxMesh).material
	assert_eq(mat.albedo_color, PropsScript.SKIRT_COLOUR,
		"a plinth under an MLP model reads as ground, not as a base in the wrong wood")
```

- [ ] **Step 2: Run the tests and watch them fail**

```bash
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 tools/bin/godot --headless --audio-driver Dummy \
  --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_building_model.gd -gexit
```

Expected: failures naming `Invalid call. Nonexistent function 'wears_a_model'`.

- [ ] **Step 3: Add the three exports**

In `game/world/building.gd`, after line 193 (`@export_range(0.0, 1.0) var trim_metallic := 0.0`), insert:

```gdscript
@export_group("Model")
## THE CONVERTED .glb THIS SHELL WEARS, or "" for the primitive shell.
##
## WHY THE PRIMITIVE SHELL DID NOT SIMPLY GO. game/assets/converted/ is gitignored
## (docs/ci.md section 4), so a CI checkout and a fresh clone have no props at all. A shell
## that only renders when its model is present would leave the CI runner, the export smoke
## and the Windows build with a map of invisible collision. So the shell stays, in full, and
## a model hides it only when the file is actually on the machine. `assets=absent` therefore
## still means what ranch.gd has always printed it to mean.
##
## The walls, the roof, the gables and the lintel hide. THE PLINTH AND THE DOOR APRON DO
## NOT: game/test/test_building_base.gd asserts both by name on every building on the
## shipped map, they are what stops the terrain z fighting a base seated across a metre of
## relief (see FLOOR_TOP), and the apron is the threshold a player walks up. What changes is
## the plinth's COLOUR, to Props.SKIRT_COLOUR, so it reads as the turned earth a building is
## set into rather than as dark timber that matches nothing on a hand painted MLP model.
@export var model_file := ""
## Multiplier ON TOP of Props.MLP_SCALE. One, for every building on the shipped map: the
## whole point of MLP_SCALE is that every converted Source model on this map is at one
## scale, and a building at a different one is the clash this slice exists to end. It is an
## export rather than a constant so a model whose shipped size is a defect (the case
## Props.SCALE_FIX exists for) can be corrected in the scene beside the model that needs it.
@export var model_scale := 1.0
## Degrees the model is turned about Y inside the shell, so its own entrance faces the
## shell's local plus Z -- which is where the doorway, the apron and the attendants are.
## The packs do not agree on which way a model faces, so this is a measurement, taken off a
## rendered shot, not a convention.
@export var model_yaw := 0.0
```

- [ ] **Step 4: Add the state, the predicate and the model builder**

In `game/world/building.gd`, change line 199 (`var _built := false`) to:

```gdscript
var _built := false
var _wearing := false
```

Then add these two functions immediately after `apron_foot_z()` (which ends at line 360):

```gdscript
## True if this shell actually stands a converted model rather than its own primitives.
## False before build(), false for a shell with no model_file, and false on any machine
## where that file has not been converted.
func wears_a_model() -> bool:
	return _wearing


## Instance model_file, scale it into the MLP family, turn it to face the doorway and stand
## it on the plinth. Returns true if a model actually went up.
##
## SEATED BY ITS OWN BOUNDING BOX, NOT BY ITS ORIGIN, for the reason props.gd's own class
## comment gives at length: these packs do not agree on where a model's origin is, so the
## only reliable way to put a floor on a floor is to measure the floor. Measured AFTER the
## scale and the yaw are applied and the node is in the tree, because a footprint is the
## footprint of the model as it will actually stand.
##
## AND IT LANDS ON FLOOR_TOP RATHER THAN ON LOCAL ZERO. Local y = 0 is nearly a metre inside
## a solid plinth (see GROUND_DROP); a model dropped there would be half buried, and its
## bottom would drag the whole building's world AABB down, which is the number ranch.gd
## seats every building by and then re-checks. Standing it on the plinth's own top face
## leaves the plinth's underside the lowest thing under this node, exactly as before.
func _stand_model() -> bool:
	if model_file.is_empty():
		return false
	var path: String = PropsScript.PROP_DIR + model_file
	if not ResourceLoader.exists(path):
		return false
	var scene: Resource = load(path)
	if scene == null or not (scene is PackedScene):
		push_error("Building '%s': '%s' did not load as a PackedScene" % [name, path])
		return false
	var inst: Node3D = (scene as PackedScene).instantiate()
	if inst == null:
		push_error("Building '%s': '%s' failed to instantiate" % [name, path])
		return false
	var holder := Node3D.new()
	holder.name = "Model"
	add_child(holder)
	holder.add_child(inst)
	inst.scale = Vector3.ONE * (PropsScript.MLP_SCALE * model_scale)
	inst.rotation.y = deg_to_rad(model_yaw)

	var box: AABB = PropsScript.world_aabb(holder)
	if box.size == Vector3.ZERO:
		push_error("Building '%s': '%s' measured an empty AABB" % [name, path])
		holder.queue_free()
		return false
	# Centre it on the shell in XZ and put its floor on the plinth's top face. global_position
	# is used because world_aabb() is a world space measurement and the parent may be turned.
	var centre: Vector3 = box.get_center()
	holder.global_position += global_transform.basis * Vector3.ZERO \
		+ Vector3(0.0, FLOOR_TOP - box.position.y, 0.0)
	holder.global_position -= Vector3(centre.x - global_position.x, 0.0,
		centre.z - global_position.z)
	return true
```

- [ ] **Step 5: Wire it into `build()`**

In `game/world/building.gd`'s `build()`:

Replace line 232 (`var plinth_mat := _material(trim_color, TRIM_ROUGHNESS)`) with:

```gdscript
	# A MODEL CHANGES WHAT THE PLINTH IS FOR. Under the primitive shell it is the building's
	# own boarded floor and matches its lintel; under a hand painted MLP model it is the
	# ground the model is set into, and props.gd's SKIRT_COLOUR is the colour that already
	# says so under every wide prop on the map.
	var wearing: bool = model_file != "" and ResourceLoader.exists(PropsScript.PROP_DIR + model_file)
	var plinth_mat := _material(
		PropsScript.SKIRT_COLOUR if wearing else trim_color,
		0.95 if wearing else TRIM_ROUGHNESS)
```

Add `wearing` as the extra argument to the six slab calls that build hideable geometry, and leave `Floor` and `DoorApron` alone. Concretely, change these calls to pass `true` as the new final `hideable` argument:

- line 250 `_slab("WallBack", ..., wall_mat, 0.0, 0.0, true)`
- line 252 `_slab("WallLeft", ..., wall_mat, 0.0, 0.0, true)`
- line 254 `_slab("WallRight", ..., wall_mat, 0.0, 0.0, true)`
- line 261 `_slab("WallFrontL", ..., wall_mat, 0.0, 0.0, true)`
- line 263 `_slab("WallFrontR", ..., wall_mat, 0.0, 0.0, true)`
- line 267 `_slab("Lintel", ..., trim_mat, 0.0, 0.0, true)`
- line 308 `_slab("RoofLeft", slab, ..., roof_mat, angle, 0.0, true)`
- line 309 `_slab("RoofRight", slab, ..., roof_mat, -angle, 0.0, true)`

Replace the tail of `build()` (lines 332-337, the `Gables` node plus `_add_interior_light()`) with:

```gdscript
	var gable_node := MeshInstance3D.new()
	gable_node.name = "Gables"
	gable_node.mesh = gable
	add_child(gable_node)

	# THE MODEL GOES UP LAST, so the shell it hides is already standing and its collision is
	# already in place. _stand_model() answers false on any machine with no converted props,
	# which is what leaves the primitives visible on CI.
	_wearing = _stand_model()
	if _wearing:
		gable_node.visible = false
		for part: String in HIDEABLE:
			var node := get_node_or_null(NodePath(part)) as MeshInstance3D
			if node != null:
				node.visible = false
	else:
		# NO INTERIOR LIGHT UNDER A MODEL. An invisible MeshInstance3D casts no shadow, so an
		# OmniLight3D inside hidden walls would light the grass outside them: a glowing barn
		# in daylight. The spec puts interiors out of scope for this slice (section 9), so the
		# doorway is a threshold and the room behind it is the model's own business.
		_add_interior_light()
```

Add the constant beside `WALL_ROUGHNESS` (after line 197):

```gdscript
## The mesh parts a worn model hides. Collision is untouched: what the player bumps into is
## the same box shell it has always been, sized in ranch.tscn to the model standing in front
## of it.
const HIDEABLE := ["WallBack", "WallLeft", "WallRight", "WallFrontL", "WallFrontR",
	"Lintel", "RoofLeft", "RoofRight"]
```

- [ ] **Step 6: Give `_slab()` the flag**

Replace `game/world/building.gd:453-455` (the signature and the first lines of `_slab`) with:

```gdscript
func _slab(slab_name: String, size: Vector3, at: Vector3, mat: StandardMaterial3D,
		roll := 0.0, pitch := 0.0, _hideable := false) -> void:
```

The flag is documentation rather than behaviour -- `build()` hides by name through `HIDEABLE` so the list is in one place -- so `_hideable` carries a leading underscore and is never read. Add above the signature:

```gdscript
## `_hideable` marks a slab that a worn model replaces. It is deliberately UNREAD: the
## hiding happens in build() through the HIDEABLE list, so the set of parts a model covers
## is one list in one place rather than eight booleans spread down a function. The parameter
## exists so a reader of the call site knows which slabs are structural (Floor, DoorApron)
## and which are the shell.
```

- [ ] **Step 7: Run the tests to green**

```bash
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 tools/bin/godot --headless --audio-driver Dummy \
  --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_building_model.gd -gexit
```

Expected: all tests pass. `saa_shed.glb` is converted on the owner's machine, so the modelled tests run for real rather than taking their `pass_test` escape.

- [ ] **Step 8: Prove the existing building invariants did not move**

```bash
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 tools/bin/godot --headless --audio-driver Dummy \
  --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_building_base.gd -gexit
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 tools/bin/godot --headless --audio-driver Dummy \
  --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_attendant.gd -gexit
```

Expected: both green. No building in `ranch.tscn` names a model yet, so every one of them is still the primitive shell.

- [ ] **Step 9: Run the suite and commit**

```bash
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 bash tools/run_tests.sh
```

Expected: `---- All tests passed! ----`, exit 0.

```bash
git add game/world/building.gd game/test/test_building_model.gd game/test/test_building_model.gd.uid
git commit -m "feat: a building shell can wear a converted model and hide its own boxes"
```

---

### Task 3: The ranch's five modelled buildings put their models on

**Files:**
- Modify: `game/world/ranch.tscn:120-200` (the `Barn`, `Farmhouse`, `Market`, `Board`, `Depot` nodes; the `Palace` node is left alone -- task 5 owns it)
- Modify: `docs/testing.md:594-609` (the `RANCH_OK ponies=49 props=111` paragraph)
- Test: `game/test/test_building_model.gd` (extend with a shipped-map test)

**Interfaces:**
- Consumes: `Building.model_file`, `Building.model_scale`, `Building.model_yaw`, `Building.wears_a_model()` from task 2.
- Produces: five modelled buildings on the shipped map with their `width`/`depth`/`wall_height`/`ridge_height` re-sized to their models. **Origins, node names, yaws, `door_width`, `door_height`, `wall_color`, `roof_color`, `trim_color` and `trim_metallic` are unchanged** -- `game/ui/casino_paint.gd:17` reads the Palace's colours, every interaction is a distance from an origin, and attendants are derived from `depth` and `door_width`.

- [ ] **Step 1: Write the failing shipped-map test**

Append to `game/test/test_building_model.gd`:

```gdscript
const RanchScene := preload("res://world/ranch.tscn")

## The five that wear a model, and the seated footprint each was sized to. The Palace is not
## here: it is a kit bash of several pieces (game/world/palace_facade.gd), not one model.
const SHIPPED := {
	"Barn": {"file": "saa_barn.glb", "w": 4.86, "d": 4.93, "ridge": 7.00},
	"Farmhouse": {"file": "pv_wide_b.glb", "w": 7.26, "d": 3.44, "ridge": 5.77},
	"Market": {"file": "pv_general.glb", "w": 10.62, "d": 5.07, "ridge": 5.34},
	"Board": {"file": "pv_bridged_b.glb", "w": 2.82, "d": 2.14, "ridge": 3.60},
	"Depot": {"file": "pv_tower_b.glb", "w": 6.29, "d": 3.05, "ridge": 7.43},
}

## Every building origin the owner's live save was made against. THESE MAY NOT MOVE: the
## interact verb is a flat XZ distance from each of these points (ranch.gd's is_near_*),
## so a moved origin is a Market that opens somewhere else than where the player learned it.
const ORIGINS := {
	"Barn": Vector2(-10.0, -9.0), "Farmhouse": Vector2(9.0, -7.0),
	"Market": Vector2(-2.0, -1.0), "Board": Vector2(3.0, -1.0),
	"Depot": Vector2(10.0, 4.0), "Palace": Vector2(-10.0, 61.6),
	"Mailbox": Vector2(8.0, -2.5),
}


func test_the_shipped_map_names_a_model_on_every_building_but_the_palace() -> void:
	var ranch: Node3D = RanchScene.instantiate()
	var buildings: Node3D = ranch.get_node(^"Buildings")
	for who: String in SHIPPED:
		var b := buildings.get_node_or_null(NodePath(who)) as Building
		assert_not_null(b, "%s stands" % who)
		assert_eq(b.model_file, String(SHIPPED[who]["file"]), "%s names its model" % who)
		assert_eq(b.model_scale, 1.0, "%s is at the MLP family's own scale" % who)
	ranch.free()


func test_every_shell_is_sized_to_the_model_standing_in_it() -> void:
	var ranch: Node3D = RanchScene.instantiate()
	var buildings: Node3D = ranch.get_node(^"Buildings")
	for who: String in SHIPPED:
		var b := buildings.get_node(NodePath(who)) as Building
		var want: Dictionary = SHIPPED[who]
		assert_almost_eq(b.width, float(want["w"]), 0.05, "%s width" % who)
		assert_almost_eq(b.depth, float(want["d"]), 0.05, "%s depth" % who)
		assert_almost_eq(b.ridge_height, float(want["ridge"]), 0.05, "%s ridge" % who)
		assert_gt(b.ridge_height, b.wall_height, "%s ridge is above its eaves" % who)
		assert_gt(b.width, b.door_width, "%s is wider than its own doorway" % who)
	ranch.free()


func test_no_building_origin_moved_out_from_under_the_owners_save() -> void:
	var ranch: Node3D = RanchScene.instantiate()
	var buildings: Node3D = ranch.get_node(^"Buildings")
	for who: String in ORIGINS:
		var node := buildings.get_node_or_null(NodePath(who)) as Node3D
		assert_not_null(node, "%s stands" % who)
		var at := Vector2(node.position.x, node.position.z)
		assert_almost_eq(at.x, (ORIGINS[who] as Vector2).x, 0.001, "%s x" % who)
		assert_almost_eq(at.y, (ORIGINS[who] as Vector2).y, 0.001, "%s z" % who)
	assert_eq(buildings.get_child_count(), 7, "the census term did not move")
	ranch.free()
```

- [ ] **Step 2: Run it and watch it fail**

```bash
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 tools/bin/godot --headless --audio-driver Dummy \
  --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_building_model.gd -gexit
```

Expected: three failures -- `model_file` is `""` and the widths are the old ones.

- [ ] **Step 3: Re-size and dress the Barn**

In `game/world/ranch.tscn`, replace lines 123-128 (`width` through `door_height` on `Barn`) with:

```
width = 4.86
depth = 4.93
wall_height = 4.34
ridge_height = 7.0
door_width = 3.0
door_height = 2.9
```

and add, after line 131 (`trim_color = ...`):

```
model_file = "saa_barn.glb"
model_scale = 1.0
model_yaw = 0.0
```

- [ ] **Step 4: Re-size and dress the Farmhouse, the Market, the Board and the Depot**

`Farmhouse` (lines 136-141) becomes:

```
width = 7.26
depth = 3.44
wall_height = 3.58
ridge_height = 5.77
door_width = 1.8
door_height = 2.6
```

with `model_file = "pv_wide_b.glb"`, `model_scale = 1.0`, `model_yaw = 0.0` appended after its `trim_color` line.

`Market` (lines 149-154) becomes:

```
width = 10.62
depth = 5.07
wall_height = 3.31
ridge_height = 5.34
door_width = 2.4
door_height = 2.6
```

with `model_file = "pv_general.glb"`, `model_scale = 1.0`, `model_yaw = 0.0`.

`Board` (lines 162-167) becomes:

```
width = 2.82
depth = 2.14
wall_height = 2.4
ridge_height = 3.6
door_width = 0.0
door_height = 2.4
```

with `model_file = "pv_bridged_b.glb"`, `model_scale = 1.0`, `model_yaw = 0.0`. (`door_width = 0.0` keeps the Board's "no doorway, no apron" shape, which `test_building_base.gd:188` and `:247` both depend on.)

`Depot` (lines 175-179) becomes:

```
width = 6.29
depth = 3.05
wall_height = 4.6
ridge_height = 7.43
door_width = 3.0
```

with `model_file = "pv_tower_b.glb"`, `model_scale = 1.0`, `model_yaw = 0.0`. Leave `door_height` unset (it defaults to 2.8, which clears `MIN_DOOR_CLEARANCE`).

- [ ] **Step 5: Run the unit tests to green**

```bash
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 tools/bin/godot --headless --audio-driver Dummy \
  --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_building_model.gd -gexit
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 tools/bin/godot --headless --audio-driver Dummy \
  --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_building_base.gd -gexit
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 tools/bin/godot --headless --audio-driver Dummy \
  --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_attendant.gd -gexit
```

Expected: all three green. `test_attendant.gd` derives every one of its assertions from the live `depth`/`door_width`/`width`, so a re-sized shell moves the attendants and the assertions together.

- [ ] **Step 6: Run the ranch gate and read the census**

```bash
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 tools/bin/godot --headless --audio-driver Dummy \
  --path game world/ranch.tscn 2>&1 | grep -E "RANCH_OK|RANCH_FAILED|RANCH prop|FAILED"
```

Expected: `RANCH_OK ponies=49 props=111 assets=present`. **`props` must not move in this task** -- `buildings.get_child_count()` is still 7 and `LAYOUT` is untouched. If the gate goes red on `no MLP prop's collider reaches inside a building's interaction radius`, the grown Market has swallowed a yard prop: note which one from the `RANCH prop doors intrusions=` line and move it in task 8; if it is red now, move it now with a one-line `at` edit in `LAYOUT` and say so in the commit message.

- [ ] **Step 7: Prove a pre-R2 save still rebuilds the world**

Synthesize a save written against the pre-R2 map and load it. The save format carries no coordinates (`GameState.plots` is `{slot_id: plot_id}`, `PonyInstance.home_slot` is a slot id, `PlayerLook` has no position), so what this proves is that a full restore -- plots rebuilt on their slots, penned ponies put back in them, the player spawned and not trapped -- survives the re-sized shells.

```bash
SAVE_DIR="$(mktemp -d)"
mkdir -p "$SAVE_DIR"
cat > "$SAVE_DIR/slot_0.json" <<'JSON'
{"version": 5, "bits": 480, "world_seed": 20260829, "world_time": 640.0,
 "plots": {"slot_1": "pen_small", "slot_2": "pen_small"},
 "unlocks": ["permit_orchard"],
 "gems": {"common": 3, "rare": 1},
 "inventory": {"hay": 4},
 "ponies": [{"character": "twilight", "home_slot": "slot_1"},
            {"character": "applejack", "home_slot": "slot_2"}],
 "compendium": {}, "requests": [], "ledger": [], "casino": {}, "story": {},
 "player": {"name": "Test", "coat": "#e8c8a0", "mane": "#5a3f7a", "eyes": "#3f6a8a",
            "mane_style": "straight", "mark_png": ""}}
JSON
FILLY_TEST_SAVE_DIR="$SAVE_DIR" nice -n 19 tools/bin/godot --headless --audio-driver Dummy \
  --path game world/ranch.tscn 2>&1 | grep -E "RANCH_OK|RANCH_FAILED|restored|plots|ponies"
rm -rf "$SAVE_DIR"
```

Expected: `RANCH_OK`, and the restore lines report both plots rebuilt and both ponies put back into their pens. If `GameState.from_dict()` rejects a field, fix the fixture JSON to match `game/systems/game_state.gd`'s keys (read them, do not edit them -- `game/systems/` is read-only this slice).

- [ ] **Step 8: Render the shots and look at them**

```bash
rm -rf build/r2_shots && mkdir -p build/r2_shots
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 timeout 900 xvfb-run -a tools/bin/godot \
  --path game --audio-driver Dummy --resolution 1600x900 world/ranch.tscn -- \
  "--screenshot-dir=$(pwd)/build/r2_shots"
ls build/r2_shots
```

Read `build/r2_shots/01_establishing.png`, `05_scale_at_the_barn.png`, `14_ponyville_general.png` and `12_*` with the Read tool. What to look for, per building: **which face the model's entrance is on**. The shell's doorway, apron and attendants are all on local +Z; a model whose door faces sideways is a barn you walk up a ramp to a wall of.

- [ ] **Step 9: Set each `model_yaw` from what the shots showed**

For each of the five, set `model_yaw` in `game/world/ranch.tscn` to the multiple of 90 that turns the model's entrance onto the shell's local +Z (0, 90, 180 or 270). Write the reason beside it as a scene comment is not possible in a `.tscn`, so record the five values and their justification in the commit message instead. Re-render:

```bash
rm -rf build/r2_shots && mkdir -p build/r2_shots
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 timeout 900 xvfb-run -a tools/bin/godot \
  --path game --audio-driver Dummy --resolution 1600x900 world/ranch.tscn -- \
  "--screenshot-dir=$(pwd)/build/r2_shots"
```

Read the same shots again and confirm every door faces its own ramp. Note in the commit message which building is now the tallest thing on the map -- `_tallest_building()` frames shot 05, and `pv_tower_b` on the Depot (7.43 m) stands taller than the barn (7.00 m), so shot 05 may now be a picture of the Depot. That is correct behaviour, not a regression.

- [ ] **Step 10: Run every hosted gate that touches a building**

```bash
for gate in market region world collection depot casino story; do
  echo "== $gate"
  FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 tools/bin/godot --headless --audio-driver Dummy \
    --path game "scenes/test/${gate}_test.tscn" 2>&1 | grep -E "_OK |_FAILED |checks="
done
```

Expected: `MARKET_OK checks=69`, `REGION_OK checks=49`, `WORLD_OK checks=32`, `COLLECTION_OK checks=73`, `DEPOT_OK checks=72`, `CASINO_OK checks=76`, `STORY_OK checks=58`.

- [ ] **Step 11: Update the census paragraph in the docs**

In `docs/testing.md`, in the "Pinning an hour" paragraph at lines 594-609, add after the existing "`props` moved again, from 59 to 60, in Phase 3 slice 2" sentence:

```
`props` did NOT move in slice R2's building pass, and that is the point of how it was done:
the six `Building` nodes kept their names, their origins and their place in
`buildings.get_child_count()`, and only their meshes changed. `game/world/building.gd` now
wears a converted `.glb` (`model_file`) and hides its own walls, roof, gables and lintel
behind it, keeping the plinth and the door apron -- so the interact verb, which is a flat XZ
distance from each building's own origin, and the attendants, which are derived from `depth`
and `door_width`, are the same measurements they always were. On a checkout with no
converted props the primitive shell renders exactly as before, which is what keeps CI, the
export smoke and a fresh clone looking at a map rather than at invisible collision.
```

- [ ] **Step 12: Run the suite and commit**

```bash
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 bash tools/run_tests.sh
git add game/world/ranch.tscn game/test/test_building_model.gd docs/testing.md
git commit -m "feat: the ranch's buildings are barns and shops instead of boxes"
```

---

### Task 4: The request board becomes a board, and every sign stops z-fighting

**Files:**
- Modify: `game/world/lobby_sign.gd:38-39` (`TRIM`, `THICKNESS`), `:94-97` (the `Trim`/`Board` slab pair)
- Modify: `game/world/ranch.gd` (a new `_stand_request_board()` called from `_ready()` right after the `LobbySign` block that ends at line 1009; new constants beside `LOBBY_SIGN_*` at lines 339-343)
- Test: `game/test/test_lobby_sign.gd` (add the standoff test)

**Interfaces:**
- Consumes: `LobbySign.build(board_width: float, board_height: float, facing: Vector3, headline: String, subline: String) -> void`, `LobbySign.board_size() -> Vector2`, `Building.wears_a_model() -> bool` (task 2), the re-sized `Buildings/Board` (task 3).
- Produces: `LobbySign.STANDOFF` (a new const, 0.05); a `LobbySign` node named `RequestBoard` under `Buildings/Board`; `Ranch.REQUEST_BOARD_WIDTH_FRACTION`, `REQUEST_BOARD_HEIGHT`, `REQUEST_BOARD_BASE`, `REQUEST_BOARD_STANDOFF`.

- [ ] **Step 1: Write the failing tests**

Append to `game/test/test_lobby_sign.gd`:

```gdscript
func test_the_trim_and_the_board_are_never_within_a_hair_of_coplanar() -> void:
	var sign_node: LobbySign = _built_under_a_building_yawed(0.0)
	var trim := sign_node.get_node(^"Trim") as MeshInstance3D
	var board := sign_node.get_node(^"Board") as MeshInstance3D
	var trim_front: float = trim.position.z + (trim.mesh as BoxMesh).size.z * 0.5
	var board_front: float = board.position.z + (board.mesh as BoxMesh).size.z * 0.5
	assert_gt(board_front - trim_front, LobbySignScript.STANDOFF - 0.001,
		"the board's face must stand clear of the trim's, or the two z fight")


func test_the_headline_stands_clear_of_the_board_it_is_written_on() -> void:
	var sign_node: LobbySign = _built_under_a_building_yawed(0.0)
	var board := sign_node.get_node(^"Board") as MeshInstance3D
	var headline := sign_node.get_node(^"Headline") as Label3D
	var board_front: float = board.position.z + (board.mesh as BoxMesh).size.z * 0.5
	assert_gt(headline.position.z - board_front, LobbySignScript.STANDOFF - 0.001,
		"unlit letters lying on a panel flicker against it")
```

Create the shipped-map half in `game/test/test_ranch_world.gd` (append):

```gdscript
func test_the_request_board_is_a_board_and_not_only_a_building() -> void:
	var ranch: Node3D = preload("res://world/ranch.tscn").instantiate()
	var board := ranch.get_node_or_null(^"Buildings/Board") as Building
	assert_not_null(board, "the request board building stands")
	assert_eq(board.door_width, 0.0, "a notice board has no doorway and stands no ramp")
	ranch.free()
```

- [ ] **Step 2: Run them and watch the standoff tests fail**

```bash
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 tools/bin/godot --headless --audio-driver Dummy \
  --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_lobby_sign.gd -gexit
```

Expected: `Nonexistent constant 'STANDOFF'`.

- [ ] **Step 3: Give `LobbySign` a real standoff**

In `game/world/lobby_sign.gd`, replace lines 38-39 with:

```gdscript
const TRIM := 0.08
const THICKNESS := 0.10

## HOW FAR EACH LAYER STANDS IN FRONT OF THE ONE BEHIND IT, and why it is not 0.03.
##
## THE BUG THIS CLOSES. The trim slab was 0.10 deep centred on the origin (front face at
## +0.05) and the board 0.06 deep centred 0.03 in front of it (front face at +0.06): one
## centimetre apart across two full sized quads, which at any distance is two surfaces
## fighting for the same pixels. The owner's word for it was flickering; the render showed a
## gold board strobing through a purple one as the camera moved. Five centimetres is small
## enough that nobody reads it as a design change and large enough that the depth buffer has
## never been asked to choose at any camera distance this game reaches.
const STANDOFF := 0.05
```

Replace lines 94-103 (the two `_slab` calls and the two `_label` calls) with:

```gdscript
	_slab("Trim", Vector3(board_width + TRIM * 2.0, board_height + TRIM * 2.0, THICKNESS),
		Vector3(0.0, anchor, 0.0), TRIM_COLOR)
	_slab("Board", Vector3(board_width, board_height, THICKNESS * 0.6),
		Vector3(0.0, anchor, 0.0) + _local_facing * STANDOFF, BOARD_COLOR)

	var headline_height: float = board_height * HEADLINE_FRACTION
	_label("Headline", headline, headline_height,
		Vector3(0.0, anchor + board_height * 0.18, 0.0) + _local_facing * (STANDOFF * 2.0))
	_label("Subline", subline, headline_height * SUBLINE_SCALE,
		Vector3(0.0, anchor - board_height * 0.20, 0.0) + _local_facing * (STANDOFF * 2.0))
```

- [ ] **Step 4: Stand a request board on the Board building**

In `game/world/ranch.gd`, add beside the `LOBBY_SIGN_*` constants (after line 343):

```gdscript
## THE REQUEST BOARD'S OWN BOARD. Buildings/Board wears a Ponyville Environments cottage now
## (slice R2), which is a fine little building and says nothing at all about favours for
## hire. So the same fitted board the Palace's lobby sign is made of stands on its front
## wall, sized off the building's own numbers the way every other sign on this map is.
const REQUEST_BOARD_WIDTH_FRACTION := 0.72
const REQUEST_BOARD_HEIGHT := 0.95
const REQUEST_BOARD_BASE := 1.15
const REQUEST_BOARD_STANDOFF := 0.30
const REQUEST_BOARD_HEADLINE := "Favours"
const REQUEST_BOARD_SUBLINE := "ask inside, paid on delivery"
```

Add this function immediately after the `_ready()` LobbySign block (that is, after line 1009 and before line 1011's `var prop_count := ...`), and call it there:

```gdscript
	_stand_request_board()
```

and define it beside `_stand_attendants()` (after line 4477):

```gdscript
## THE BOARD ON THE BOARD. Sized, placed and faced off the live Buildings/Board node, the
## same way the Palace's lobby sign is off the Palace, so a re sited or re proportioned
## notice board takes its own lettering with it instead of leaving a panel in a field.
##
## NOTHING HERE HANGS BELOW THE BUILDING'S OWN ORIGIN. LobbySign anchors its whole assembly
## TRIM above its local zero for exactly this reason, and REQUEST_BOARD_BASE puts that
## assembly above Building.FLOOR_TOP besides: ranch.gd's own seating check re-measures every
## MeshInstance3D under a building, so a board reaching below the plinth would fail the gate
## on a correctly seated building.
func _stand_request_board() -> void:
	var board := get_node_or_null(^"Buildings/Board") as Building
	if board == null:
		return
	var out_dir: Vector3 = board.global_transform.basis * Vector3(0.0, 0.0, 1.0)
	out_dir.y = 0.0
	out_dir = out_dir.normalized() if out_dir.length_squared() > 0.0 \
		else Vector3(0.0, 0.0, 1.0)
	var panel := LobbySignScript.new()
	panel.name = "RequestBoard"
	board.add_child(panel)
	panel.position = Vector3(0.0, REQUEST_BOARD_BASE, 0.0) \
		+ board.to_local(board.global_position
			+ out_dir * (board.depth * 0.5 + REQUEST_BOARD_STANDOFF))
	panel.build(board.width * REQUEST_BOARD_WIDTH_FRACTION, REQUEST_BOARD_HEIGHT, out_dir,
		REQUEST_BOARD_HEADLINE, REQUEST_BOARD_SUBLINE)
```

- [ ] **Step 5: Run the tests to green**

```bash
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 tools/bin/godot --headless --audio-driver Dummy \
  --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_lobby_sign.gd -gexit
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 tools/bin/godot --headless --audio-driver Dummy \
  --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_ranch_world.gd -gexit
```

Expected: both green.

- [ ] **Step 6: Run the ranch gate and confirm the seating check still likes the Board**

```bash
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 tools/bin/godot --headless --audio-driver Dummy \
  --path game world/ranch.tscn 2>&1 | grep -E "RANCH_OK|RANCH_FAILED|RANCH prop Board|seat_error"
```

Expected: `RANCH_OK ponies=49 props=111 assets=present`, and the `RANCH prop Board` line's `seat_error` inside tolerance. A non-zero `seat_error` on the Board means the request board reaches below the plinth: raise `REQUEST_BOARD_BASE`.

- [ ] **Step 7: Look at the boards**

```bash
rm -rf build/r2_shots && mkdir -p build/r2_shots
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 timeout 900 xvfb-run -a tools/bin/godot \
  --path game --audio-driver Dummy --resolution 1600x900 world/ranch.tscn -- \
  "--screenshot-dir=$(pwd)/build/r2_shots"
```

Read `build/r2_shots/18_palace_lobby_sign.png`. Expected: gold trim behind a dark panel behind two lines of readable text, with no flicker or striping where the layers meet.

- [ ] **Step 8: Run the suite and commit**

```bash
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 bash tools/run_tests.sh
git add game/world/lobby_sign.gd game/world/ranch.gd game/test/test_lobby_sign.gd \
  game/test/test_ranch_world.gd
git commit -m "feat: the request board says so, and no sign fights itself for pixels"
```

---

### Task 5: Kit-bash the Spectra Palace facade and dress it in neon

**Files:**
- Create: `game/world/palace_facade.gd`, `game/world/palace_facade.gd.uid`
- Modify: `game/world/ranch.gd` (call `_stand_palace_facade()` from `_ready()` after `_stand_request_board()`; new constant block)
- Test: `game/test/test_palace_facade.gd`, `game/test/test_palace_facade.gd.uid`

**Interfaces:**
- Consumes: the converted town pieces and `neon_*` ids from task 1 (read the `# NEON IDS:` line in `tools/prop_manifest.txt`); `Props.PROP_DIR`, `Props.MLP_SCALE`, `Props.world_aabb()`; `Buildings/Palace` with `width = 14.0`, `depth = 9.0`, `ridge_height = 4.6`, `door_width = 3.2`, unchanged from today.
- Produces: `class_name PalaceFacade extends Node3D` with `func build(half_width: float, half_depth: float, door_half: float, facing: Vector3) -> int` (returns the number of pieces actually stood), `func piece_count() -> int`, `func neon_count() -> int`, `const OVERSAIL := 1.0`, `const PIECES` (the composition table). Task 10 counts nothing from it -- the facade is not in the census.

- [ ] **Step 1: Write the failing tests**

Create `game/test/test_palace_facade.gd`:

```gdscript
extends GutTest
## THE PALACE IS A KIT BASH AND THIS IS THE PROOF THAT IT IS A BUILDING.
##
## scratchpad/ledgers/redesign/palace-sourcing.md searched every no-login source there is and
## found no MLP casino, resort or Las Pegasus facade anywhere. So the Palace is Ponyville
## Environments pieces standing shoulder to shoulder inside the shell's own rectangle, with
## the Neon Lights Pack over the door. What a test can say about that is geometric: nothing
## stands in the doorway, nothing oversails the shell by more than a roof would, and nothing
## dips below the plinth the shell is seated on.

const FacadeScript := preload("res://world/palace_facade.gd")
const BuildingScript := preload("res://world/building.gd")
const PropsScript := preload("res://world/props.gd")

const HALF_WIDTH := 7.0
const HALF_DEPTH := 4.5
const DOOR_HALF := 1.6


func _built() -> PalaceFacade:
	var f: PalaceFacade = FacadeScript.new()
	add_child_autofree(f)
	f.build(HALF_WIDTH, HALF_DEPTH, DOOR_HALF, Vector3(0.0, 0.0, 1.0))
	return f


func test_the_composition_table_is_symmetric_about_the_door() -> void:
	var xs: Array[float] = []
	for piece: Dictionary in FacadeScript.PIECES:
		xs.append(float((piece["at"] as Vector2).x))
	for x: float in xs:
		assert_true(xs.has(-x) or absf(x) < 0.01,
			"every piece off the centreline has a mirror: %.2f does not" % x)


func test_no_piece_stands_in_the_doorway() -> void:
	var f := _built()
	if f.piece_count() == 0:
		pass_test("no converted props on this machine")
		return
	for child: Node3D in f.get_children():
		var box: AABB = PropsScript.world_aabb(child)
		if box.size == Vector3.ZERO:
			continue
		var over_door: bool = box.position.x < DOOR_HALF and box.position.x + box.size.x > -DOOR_HALF
		var at_the_front: bool = box.position.z + box.size.z > HALF_DEPTH - 0.5
		assert_false(over_door and at_the_front,
			"%s stands in the door the player walks up to" % child.name)


func test_nothing_oversails_the_shell_by_more_than_a_roof_would() -> void:
	var f := _built()
	if f.piece_count() == 0:
		pass_test("no converted props on this machine")
		return
	for child: Node3D in f.get_children():
		var box: AABB = PropsScript.world_aabb(child)
		if box.size == Vector3.ZERO:
			continue
		assert_lt(maxf(absf(box.position.x), absf(box.position.x + box.size.x)),
			HALF_WIDTH + FacadeScript.OVERSAIL, "%s reaches past the facade in x" % child.name)
		assert_lt(maxf(absf(box.position.z), absf(box.position.z + box.size.z)),
			HALF_DEPTH + FacadeScript.OVERSAIL, "%s reaches past the facade in z" % child.name)


func test_nothing_dips_below_the_plinth_it_stands_on() -> void:
	var f := _built()
	if f.piece_count() == 0:
		pass_test("no converted props on this machine")
		return
	for child: Node3D in f.get_children():
		var box: AABB = PropsScript.world_aabb(child)
		if box.size == Vector3.ZERO:
			continue
		assert_gt(box.position.y, BuildingScript.FLOOR_TOP - 0.02,
			"%s hangs below the plinth and would drag the Palace's own seat down" % child.name)


func test_a_machine_with_no_props_stands_no_facade_and_does_not_error() -> void:
	var f: PalaceFacade = FacadeScript.new()
	add_child_autofree(f)
	var stood: int = f.build(HALF_WIDTH, HALF_DEPTH, DOOR_HALF, Vector3.ZERO)
	assert_between(stood, 0, FacadeScript.PIECES.size(),
		"a degenerate facing is not a reason to error, only a reason to face forward")
```

- [ ] **Step 2: Run it and watch it fail**

```bash
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 tools/bin/godot --headless --audio-driver Dummy \
  --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_palace_facade.gd -gexit
```

Expected: the preload fails -- `palace_facade.gd` does not exist.

- [ ] **Step 3: Write `game/world/palace_facade.gd`**

```gdscript
class_name PalaceFacade
extends Node3D
## THE SPECTRA PALACE'S FRONT, ASSEMBLED FROM TOWN BUILDINGS BECAUSE NOBODY SELLS A CASINO.
##
## WHY THIS IS A KIT BASH. scratchpad/ledgers/redesign/palace-sourcing.md queried PonySFM --
## the one source that supports true anonymous download -- for casino, Las Pegasus,
## Gladmane, resort, hotel, vegas, gambling, slot, dice, carnival, fairground, boardwalk and
## storefront, and every one of them returned nothing. The two Las Pegasus uploads that do
## exist are minigame props (we own one of them: lp_skeeball, lp_dance_game). Everything on
## SFMLab, Open3DLab, TurboSquid, CGTrader and Sketchfab either has no show style casino or
## gates the download behind an account, which is disqualifying outright. So the Palace is
## Ponyville Environments pieces standing shoulder to shoulder inside its shell's own
## rectangle, with the Neon Lights Pack over the door.
##
## IT IS NOT IN THE CENSUS AND THAT IS DELIBERATE. ranch.gd counts Props.expected_count()
## plus the Buildings children; these are children OF a building, one structure rather than
## a row of props, and adding them to a count every doc in the repo names would be churn
## with no claim attached. The claims a test can make about them are geometric and they are
## in game/test/test_palace_facade.gd.
##
## EVERY PIECE STANDS ON THE PLINTH. Building.FLOOR_TOP is the top of the Palace's own
## foundation and the height its door apron ramps up to; a piece dropped at local zero would
## be buried nearly a metre inside solid plinth (see Building.GROUND_DROP) and would drag the
## whole building's world AABB down, which is the number ranch.gd seats it by.
##
## AND NOTHING STANDS IN THE DOOR. The door bay is left clear across the front so the apron
## the player walks up leads somewhere rather than into a wall.

const PropsScript := preload("res://world/props.gd")
const BuildingScript := preload("res://world/building.gd")

## How far past the shell's own rectangle a piece may reach, on every side. Building's own
## eave_overhang is 0.45 m and nobody reads a roof that oversails its walls as a mistake;
## a metre is that idea at the scale of a fourteen metre frontage.
const OVERSAIL := 1.0

## THE COMPOSITION, in the shell's own local XZ metres, and every number is arithmetic
## rather than taste. `at` is the piece's footprint CENTRE; `yaw` turns it inside the facade.
##
## Read across the front: a courtyard block either side of the door bay, a narrow pink block
## outboard of each, and one tower behind the whole thing so the silhouette has a top to it.
## The x figures are (door half 1.6) + (a 0.2 m reveal) + (the piece's own seated half
## width), then the next piece's own half width past the previous piece's outer edge. The z
## figures put each front piece's own face just inside the shell's front plane (half depth
## 4.5) and the tower well behind them.
##
##   pv_courtyard_b  3.90 x 3.29 seated, half 1.95 / 1.645 -> x = 1.6 + 0.2 + 1.95 = 3.75
##   pv_pink_b       2.31 x 3.89 seated, half 1.155 / 1.945 -> x = 5.70 + 0.15 + 1.155 = 7.01
##   pv_tower_b      6.29 x 3.05 seated, half 3.145 / 1.525 -> centred, set back
const PIECES := [
	{"file": "pv_courtyard_b.glb", "at": Vector2(-3.75, 2.75), "yaw": 0.0},
	{"file": "pv_courtyard_b.glb", "at": Vector2(3.75, 2.75), "yaw": 0.0},
	{"file": "pv_pink_b.glb", "at": Vector2(-7.01, 2.45), "yaw": 0.0},
	{"file": "pv_pink_b.glb", "at": Vector2(7.01, 2.45), "yaw": 0.0},
	{"file": "pv_tower_b.glb", "at": Vector2(0.0, -2.60), "yaw": 0.0},
]

## The neon that turns a town row into a strip. Ids come from tools/prop_manifest.txt's
## `# NEON IDS:` line; `at` is local XZ and `y` is metres ABOVE Building.FLOOR_TOP, because
## a sign hangs on a wall rather than standing on the ground.
const NEON := [
	{"file": "neon_<a>.glb", "at": Vector2(-2.60, 4.20), "y": 2.60, "yaw": 0.0},
	{"file": "neon_<b>.glb", "at": Vector2(2.60, 4.20), "y": 2.60, "yaw": 0.0},
	{"file": "neon_<c>.glb", "at": Vector2(-6.20, 3.90), "y": 2.20, "yaw": 0.0},
	{"file": "neon_<d>.glb", "at": Vector2(6.20, 3.90), "y": 2.20, "yaw": 0.0},
]

var _pieces := 0
var _neon := 0


func piece_count() -> int:
	return _pieces


func neon_count() -> int:
	return _neon


## Stand the facade. `half_width`/`half_depth` are the shell's own half extents, `door_half`
## is half its doorway, and `facing` is the direction its door looks in WORLD space. Returns
## the number of pieces that actually went up -- zero on a checkout with no converted props,
## which is a reported state and not an error, exactly as Props.build() treats it.
func build(half_width: float, half_depth: float, door_half: float, facing: Vector3) -> int:
	var flat := Vector3(facing.x, 0.0, facing.z)
	if flat.length_squared() <= 0.0:
		# A degenerate direction is a caller bug, not a reason to stand no facade: fall back
		# on the way every Building's own door faces before it is turned. Same rule
		# LobbySign.build() and Strip.mount_marquee() already follow.
		flat = Vector3(0.0, 0.0, 1.0)
	for piece: Dictionary in PIECES:
		var at: Vector2 = piece["at"]
		# Clamped so a re-proportioned shell cannot push a piece past its own frontage.
		var x: float = clampf(at.x, -(half_width + OVERSAIL * 0.5), half_width + OVERSAIL * 0.5)
		var z: float = clampf(at.y, -(half_depth - 0.2), half_depth - 0.2)
		if absf(x) < door_half and z > half_depth - 0.5:
			continue
		if _stand(String(piece["file"]), Vector3(x, BuildingScript.FLOOR_TOP, z),
				float(piece["yaw"]), true):
			_pieces += 1
	for lamp: Dictionary in NEON:
		var at: Vector2 = lamp["at"]
		if _stand(String(lamp["file"]),
				Vector3(at.x, BuildingScript.FLOOR_TOP + float(lamp["y"]), at.y),
				float(lamp["yaw"]), false):
			_neon += 1
	return _pieces


## One piece. `sit_on_base` puts the model's own floor at `at.y`; a neon sign is hung by its
## centre instead, because a sign has no floor. Everything is measured after the scale and
## the yaw are applied and the node is in the tree, for props.gd's reason: these packs do not
## agree about where a model's origin is.
func _stand(file: String, at: Vector3, yaw: float, sit_on_base: bool) -> bool:
	var path: String = PropsScript.PROP_DIR + file
	if not ResourceLoader.exists(path):
		return false
	var scene: Resource = load(path)
	if scene == null or not (scene is PackedScene):
		push_error("PalaceFacade: '%s' did not load as a PackedScene" % path)
		return false
	var inst: Node3D = (scene as PackedScene).instantiate()
	if inst == null:
		return false
	inst.name = "%s_%d" % [file.get_basename(), get_child_count()]
	inst.scale = Vector3.ONE * PropsScript.MLP_SCALE
	inst.rotation.y = deg_to_rad(yaw)
	add_child(inst)
	inst.position = at
	var box: AABB = PropsScript.world_aabb(inst)
	if box.size == Vector3.ZERO:
		inst.queue_free()
		return false
	var centre: Vector3 = box.get_center()
	var local_at: Vector3 = to_local(Vector3(centre.x, 0.0, centre.z))
	inst.position -= Vector3(local_at.x - at.x, 0.0, local_at.z - at.z)
	inst.global_position.y += (to_global(at).y - box.position.y) if sit_on_base \
		else (to_global(at).y - centre.y)
	return true
```

Replace `neon_<a>` through `neon_<d>` with four ids from the `# NEON IDS:` line in `tools/prop_manifest.txt` -- pick the four that read as signage rather than as a bare tube, judged from the gallery's `PROP neon_* size=` lines in task 1 (a sign is wide and thin; a tube is long and thin).

- [ ] **Step 4: Mount it from `ranch.gd`**

In `game/world/ranch.gd`, add the preload beside `LobbySignScript` (near line 166-180):

```gdscript
const PalaceFacadeScript := preload("res://world/palace_facade.gd")
```

and add this call in `_ready()` immediately after `_stand_request_board()`:

```gdscript
	_stand_palace_facade()
```

with the function beside `_stand_request_board()`:

```gdscript
## THE PALACE'S OWN FRONT, standing inside the shell it is sized from. Mounted here rather
## than authored in ranch.tscn for the reason strip.gd and region_fence.gd are both built in
## code: game/assets/converted/ is gitignored, so a static ext_resource to one of these
## pieces would fail the export error gate on every CI run (docs/ci.md section 4).
func _stand_palace_facade() -> void:
	var palace := get_node_or_null(^"Buildings/Palace") as Building
	if palace == null:
		return
	var out_dir: Vector3 = palace.global_transform.basis * Vector3(0.0, 0.0, 1.0)
	out_dir.y = 0.0
	var facade := PalaceFacadeScript.new()
	facade.name = "Facade"
	palace.add_child(facade)
	var stood: int = facade.build(palace.width * 0.5, palace.depth * 0.5,
		palace.door_width * 0.5, out_dir)
	print("RANCH palace facade pieces=%d neon=%d" % [stood, facade.neon_count()])
```

- [ ] **Step 5: Run the tests to green**

```bash
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 tools/bin/godot --headless --audio-driver Dummy \
  --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_palace_facade.gd -gexit
```

Expected: all green, with `piece_count()` of 5.

- [ ] **Step 6: Run the ranch and casino gates**

```bash
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 tools/bin/godot --headless --audio-driver Dummy \
  --path game world/ranch.tscn 2>&1 | grep -E "RANCH_OK|RANCH_FAILED|palace|strip lamps|seat_error"
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 tools/bin/godot --headless --audio-driver Dummy \
  --path game scenes/test/casino_test.tscn 2>&1 | grep -E "CASINO_OK|CASINO_FAILED"
```

Expected: `RANCH_OK ponies=49 props=111 assets=present`, `RANCH palace facade pieces=5 neon=4`, `RANCH strip lamps=8 clear=true`, the Palace's own `seat_error` inside tolerance, and `CASINO_OK checks=76`. A moved `seat_error` on the Palace means a facade piece dips below `FLOOR_TOP`; the unit test above should have caught it, so re-run it first.

- [ ] **Step 7: Look at the Palace**

```bash
rm -rf build/r2_shots && mkdir -p build/r2_shots
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 timeout 900 xvfb-run -a tools/bin/godot \
  --path game --audio-driver Dummy --resolution 1600x900 world/ranch.tscn -- \
  "--screenshot-dir=$(pwd)/build/r2_shots"
```

Read `build/r2_shots/19_marquee_and_gold_trim.png` and `17_strip_arcade.png`. The bar is spec acceptance item 12: **"Palace exterior looks like a destination."** What to check: the frontage reads as one building rather than as five houses in a line; the door bay is clear and the apron leads into it; the neon reads as signage at the scale of the frontage; no piece hovers, sinks or intersects another. Adjust the `at` figures in `PIECES` and `NEON` and re-render until it does, keeping the symmetry the first test asserts.

- [ ] **Step 8: Run the suite and commit**

```bash
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 bash tools/run_tests.sh
git add game/world/palace_facade.gd game/world/palace_facade.gd.uid game/world/ranch.gd \
  game/test/test_palace_facade.gd game/test/test_palace_facade.gd.uid
git commit -m "feat: the spectra palace is a frontage instead of a purple box"
```

---

### Task 6: The marquee becomes real geometry

**Files:**
- Modify: `game/world/strip.gd:65-129` (the marquee constants), `:331-363` (`_marquee()`), `:409-441` (`_marquee_bulbs()`); new `_marquee_arch()`
- Test: `game/test/test_strip.gd` (add the arch and standoff tests)

**Interfaces:**
- Consumes: `Strip.mount_marquee(front_centre: Vector3, out_dir: Vector3, half_extents: Vector2, ridge_y: float) -> void` and everything ranch.gd already hands it -- **unchanged**.
- Produces: unchanged public API (`marquee_facing()`, `marquee_board_size()`, `marquee_board_centre()`, `marquee_top_y()`, `marquee_lines()`, `marquee_bulb_count()`, `light_count()`), so `game/test/test_strip.gd`'s existing eleven tests keep their meaning. New: `const MARQUEE_STANDOFF_LAYER := 0.05`, `const MARQUEE_ARCH_SEGMENTS := 9`, `const MARQUEE_ARCH_RISE := 0.55`, `func marquee_arch_segments() -> int`, and `MARQUEE_BULBS` raised from 10 to 18.

- [ ] **Step 1: Write the failing tests**

Append to `game/test/test_strip.gd`:

```gdscript
func test_the_marquee_stands_a_real_arch_over_the_board() -> void:
	var strip: Strip = _mounted_strip()
	var arch := strip.get_node_or_null(^"MarqueeArch") as MultiMeshInstance3D
	assert_not_null(arch, "the marquee is geometry now, not a label on a slab")
	assert_eq(arch.multimesh.instance_count, StripScript.MARQUEE_ARCH_SEGMENTS,
		"every segment of the arch is drawn")
	assert_eq(strip.marquee_arch_segments(), StripScript.MARQUEE_ARCH_SEGMENTS)


func test_the_arch_rises_above_the_board_and_stays_under_the_roofline() -> void:
	var strip: Strip = _mounted_strip()
	var arch := strip.get_node(^"MarqueeArch") as MultiMeshInstance3D
	var highest := -INF
	for i in arch.multimesh.instance_count:
		highest = maxf(highest, arch.multimesh.get_instance_transform(i).origin.y)
	assert_gt(highest, strip.marquee_top_y(), "the arch crowns the board")
	assert_lt(highest, PALACE_RIDGE_Y + 0.01, "and stays off the roof")


func test_the_bulb_rail_rings_the_whole_arch_rather_than_two_straight_rows() -> void:
	var strip: Strip = _mounted_strip()
	assert_eq(strip.marquee_bulb_count(), StripScript.MARQUEE_BULBS)
	assert_gte(StripScript.MARQUEE_BULBS, 18, "a marquee's rail is a ring, not five and five")


func test_the_board_and_its_trim_are_never_within_a_hair_of_coplanar() -> void:
	var strip: Strip = _mounted_strip()
	var board := strip.get_node(^"MarqueeBoard") as MeshInstance3D
	var trim := strip.get_node(^"MarqueeTrim") as MeshInstance3D
	var facing: Vector3 = strip.marquee_facing()
	var board_face: float = board.global_position.dot(facing) \
		+ (board.mesh as BoxMesh).size.z * 0.5
	var trim_face: float = trim.global_position.dot(facing) \
		+ (trim.mesh as BoxMesh).size.z * 0.5
	assert_gt(board_face - trim_face, StripScript.MARQUEE_STANDOFF_LAYER - 0.001,
		"one centimetre of separation is what the flickering gold was")
```

Add the helper and the constant this file needs, beside its existing Palace literals at lines 98-113:

```gdscript
## The Palace's own ridge in world terms, for the arch's ceiling check. ranch.tscn seats the
## Palace, so this is the shell's ridge_height above the height mount_marquee() was handed --
## the same number the existing roofline test already builds its expectation from.
const PALACE_RIDGE_Y := 4.6


func _mounted_strip() -> Strip:
	var strip: Strip = StripScript.new()
	add_child_autofree(strip)
	strip.mount_marquee(Vector3(PALACE_ORIGIN.x, 0.0, PALACE_ORIGIN.y - PALACE_DEPTH * 0.5),
		Vector3(0.0, 0.0, -1.0), Vector2(7.0, 4.5), PALACE_RIDGE_Y)
	strip.configure(_a_region(), Callable(self, "_flat_ground"))
	strip.build()
	return strip
```

(If `test_strip.gd` already holds equivalents of `_a_region()` and `_flat_ground()` under other names, reuse those rather than adding duplicates; read lines 1-115 first.)

- [ ] **Step 2: Run it and watch it fail**

```bash
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 tools/bin/godot --headless --audio-driver Dummy \
  --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_strip.gd -gexit
```

Expected: failures on `MarqueeArch` being null and `MARQUEE_STANDOFF_LAYER` not existing.

- [ ] **Step 3: Add the new constants**

In `game/world/strip.gd`, after line 71 (`const MARQUEE_TRIM := 0.10`), insert:

```gdscript
## HOW FAR EACH LAYER OF THE SIGN STANDS IN FRONT OF THE ONE BEHIND IT.
##
## THE BUG THIS CLOSES. The trim slab is 0.08 deep hung 0.03 in front of a 0.12 deep board:
## the trim's front face landed at +0.07 and the board's at +0.06, one centimetre apart
## across two full sized quads, which is two surfaces fighting for the same pixels at every
## distance a player looks at this sign from. Five centimetres is small enough that nobody
## reads it as a design change and large enough that the depth buffer is never asked to
## choose. game/world/lobby_sign.gd's STANDOFF is the same number for the same reason.
const MARQUEE_STANDOFF_LAYER := 0.05

## THE ARCH OVER THE BOARD: how many segments it is drawn from and how far it rises above
## the board's own top edge.
##
## A MARQUEE IS AN ARCH WITH BULBS ROUND IT. What stood here was a flat slab with a Label3D
## in front of it and five bulbs along the top and five along the bottom, which is a notice
## board with lights on it. Nine segments is enough that a semicircle at this size reads as a
## curve rather than as a polygon at the distance the walk up to the door actually offers,
## and it is one MultiMesh either way, so the cost is one draw call for the whole arch.
const MARQUEE_ARCH_SEGMENTS := 9
const MARQUEE_ARCH_RISE := 0.55
const MARQUEE_ARCH_THICKNESS := 0.16
```

Change line 98 from `const MARQUEE_BULBS := 10` to:

```gdscript
## EIGHTEEN, ROUND THE ARCH AND ALONG THE BOARD'S FOOT. Ten in two straight rows was the
## board's shape; a marquee's rail follows its own outline, which here is nine segments of
## arch plus nine along the bottom edge under them.
const MARQUEE_BULBS := 18
```

- [ ] **Step 4: Separate the board layers and stand the arch**

In `game/world/strip.gd`'s `_marquee()`, replace line 351:

```gdscript
	trim.global_position = _marquee_centre - _marquee_facing * MARQUEE_STANDOFF_LAYER
```

and replace lines 355-361 (the two `_marquee_label` calls) with:

```gdscript
	_marquee_label("MarqueeHeadline", lines[0], headline_height,
		_marquee_centre + Vector3(0.0, _marquee_size.y * 0.20, 0.0)
			+ _marquee_facing * (MARQUEE_STANDOFF_LAYER * 2.0))
	_marquee_label("MarqueeSponsor", lines[1],
		headline_height * MARQUEE_SPONSOR_SCALE,
		_marquee_centre + Vector3(0.0, -_marquee_size.y * 0.24, 0.0)
			+ _marquee_facing * (MARQUEE_STANDOFF_LAYER * 2.0))
	_marquee_arch()
	_marquee_bulbs()
	_marquee_wash()
```

Add `marquee_arch_segments()` beside `marquee_bulb_count()` (after line 405):

```gdscript
func marquee_arch_segments() -> int:
	return MARQUEE_ARCH_SEGMENTS
```

and add `_marquee_arch()` immediately after it:

```gdscript
## THE GOLD ARCH THAT CROWNS THE BOARD, as one MultiMesh of nine boxes swept round a
## semicircle from the board's left edge to its right. Boxes rather than a torus for
## _slab()'s reason in building.gd: Godot's own winding is used rather than re-derived, and a
## hand wound curve that came out inside out would be an invisible hole rather than a visible
## mistake. Each segment is turned so its long axis lies along the tangent of the sweep.
##
## IT RISES MARQUEE_ARCH_RISE ABOVE THE BOARD'S OWN TOP AND NO FURTHER, so mount_marquee()'s
## own promise -- that the whole sign hangs clear of the roofline -- still holds without
## anything here having to know what a Building is.
func _marquee_arch() -> void:
	var box := BoxMesh.new()
	var span: float = _marquee_size.x + MARQUEE_TRIM * 2.0
	var segment: float = (PI * span * 0.5) / float(MARQUEE_ARCH_SEGMENTS)
	box.size = Vector3(segment * 1.06, MARQUEE_ARCH_THICKNESS, MARQUEE_ARCH_THICKNESS)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = MARQUEE_TRIM_COLOR
	mat.metallic = 0.45
	mat.roughness = 0.35
	box.material = mat

	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = box
	multi.instance_count = MARQUEE_ARCH_SEGMENTS

	var right := Vector3(-_marquee_facing.z, 0.0, _marquee_facing.x)
	var half_x: float = span * 0.5
	var base_y: float = _marquee_centre.y + _marquee_size.y * 0.5
	for i in MARQUEE_ARCH_SEGMENTS:
		var t: float = (float(i) + 0.5) / float(MARQUEE_ARCH_SEGMENTS)
		var angle: float = PI * t
		var at: Vector3 = _marquee_centre \
			+ right * (-cos(angle) * half_x) \
			+ Vector3(0.0, (base_y - _marquee_centre.y) + sin(angle) * MARQUEE_ARCH_RISE, 0.0) \
			+ _marquee_facing * MARQUEE_STANDOFF_LAYER
		var basis := Basis(Vector3(0.0, 0.0, 1.0), -angle + PI * 0.5)
		multi.set_instance_transform(i, Transform3D(basis, at))

	var node := MultiMeshInstance3D.new()
	node.name = "MarqueeArch"
	node.multimesh = multi
	add_child(node)
```

- [ ] **Step 5: Ring the bulbs round the arch instead of across two rows**

Replace `game/world/strip.gd:428-435` (the `for i in MARQUEE_BULBS` body inside `_marquee_bulbs()`) with:

```gdscript
	var half_span: float = _marquee_size.x * 0.5 + MARQUEE_TRIM * 0.5
	var base_y: float = _marquee_centre.y + _marquee_size.y * 0.5
	var lower_y: float = _marquee_centre.y - _marquee_size.y * 0.5 - MARQUEE_TRIM * 0.5
	for i in MARQUEE_BULBS:
		# The first half ride the arch; the second half run the board's own foot under them,
		# which is the outline a marquee's rail actually follows.
		var at: Vector3
		var half_count: int = MARQUEE_BULBS / 2
		if i < half_count:
			var t: float = (float(i) + 0.5) / float(half_count)
			var angle: float = PI * t
			at = _marquee_centre + right * (-cos(angle) * half_span) \
				+ Vector3(0.0, (base_y - _marquee_centre.y)
					+ sin(angle) * MARQUEE_ARCH_RISE, 0.0)
		else:
			var t: float = -1.0 + 2.0 * (float(i - half_count) / float(half_count - 1))
			at = _marquee_centre + right * (half_span * t) \
				+ Vector3(0.0, lower_y - _marquee_centre.y, 0.0)
		at += _marquee_facing * (MARQUEE_STANDOFF_LAYER * 1.6)
		multi.set_instance_transform(i, Transform3D(Basis(), at))
```

and delete the now-unused `var half := Vector2(...)` at lines 425-426, keeping the `var right := ...` line at 427.

- [ ] **Step 6: Run the tests to green**

```bash
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 tools/bin/godot --headless --audio-driver Dummy \
  --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_strip.gd -gexit
```

Expected: all fifteen tests pass, including the eleven that were there before -- `light_count()` is still 8, `marquee_board_size()` is still 62 percent of the Palace's width, and the two label tests still find their labels.

- [ ] **Step 7: Run the ranch gate and look at the marquee**

```bash
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 tools/bin/godot --headless --audio-driver Dummy \
  --path game world/ranch.tscn 2>&1 | grep -E "RANCH_OK|RANCH_FAILED|strip lamps"
rm -rf build/r2_shots && mkdir -p build/r2_shots
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 timeout 900 xvfb-run -a tools/bin/godot \
  --path game --audio-driver Dummy --resolution 1600x900 world/ranch.tscn -- \
  "--screenshot-dir=$(pwd)/build/r2_shots"
```

Expected: `RANCH_OK ponies=49 props=111 assets=present` and `RANCH strip lamps=8 clear=true`. Read `build/r2_shots/19_marquee_and_gold_trim.png`: a gold arch with a ring of bulbs over a dark board with two readable lines on it, no flicker between the layers, nothing poking through the roofline.

- [ ] **Step 8: Run the suite and commit**

```bash
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 bash tools/run_tests.sh
git add game/world/strip.gd game/test/test_strip.gd
git commit -m "feat: the marquee is an arch with a bulb rail instead of text on a slab"
```

---

### Task 7: The treeline goes MLP

**Files:**
- Modify: `game/world/props.gd:136-166` (`SCALE_FIX`), `:219` (`FOLIAGE_PREFIXES`), `:246-460` (`LAYOUT`)
- Modify: `docs/testing.md:594-609` (the census paragraph)
- Test: `game/test/test_props.gd` (add the no-blob-trees test)

**Interfaces:**
- Consumes: `saa_tree_wide.glb`, `saa_tree_narrow.glb`, `saa_tree_dead_wide.glb`, `saa_tree_dead_narrow.glb`, `saa_dead_tree_large.glb` from task 1, and their native heights from task 1 step 8.
- Produces: a `LAYOUT` with no `kenney_tree_*`, no `kenney_windmill.glb` and no `kenney_watermill.glb` entry; `SCALE_FIX` rows for the five new tree ids; `FOLIAGE_PREFIXES` gains `"saa_tree"` and `"saa_dead_tree"`. Task 8 edits the same array and must be run after this one, not beside it.

- [ ] **Step 1: Write the failing test**

Append to `game/test/test_props.gd`:

```gdscript
func test_no_kenney_blob_tree_and_no_bare_sail_survives_the_layout() -> void:
	var banned := ["kenney_tree_", "kenney_windmill", "kenney_watermill"]
	for entry: Dictionary in PropsScript.LAYOUT:
		var file: String = entry["file"]
		for prefix: String in banned:
			assert_false(file.begins_with(prefix),
				"%s is the signature Kenney read slice R2 took off the map" % file)


func test_every_new_tree_reads_as_foliage_so_the_camera_probe_ignores_it() -> void:
	for entry: Dictionary in PropsScript.LAYOUT:
		var file: String = entry["file"]
		if file.begins_with("saa_tree") or file.begins_with("saa_dead_tree"):
			assert_true(PropsScript.is_foliage(file),
				"%s must be foliage, or the camera arm stops on a canopy" % file)


func test_every_tree_in_the_layout_carries_a_scale_correction() -> void:
	for entry: Dictionary in PropsScript.LAYOUT:
		var file: String = entry["file"]
		if not (file.begins_with("saa_tree") or file.begins_with("saa_dead_tree")):
			continue
		assert_true(PropsScript.SCALE_FIX.has(file),
			"%s is an SFM model at whatever size a 2015 modeller drew it" % file)
```

- [ ] **Step 2: Run it and watch it fail**

```bash
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 tools/bin/godot --headless --audio-driver Dummy \
  --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_props.gd -gexit
```

Expected: 39 failures on the banned-prefix test.

- [ ] **Step 3: Compute the five tree corrections**

Every `SCALE_FIX` row is `target_height / (native_height * MLP_SCALE)`, with `native_height` read off the gallery in task 1 step 8. The targets, taken from the shipped orchard so the whole map's trees agree with each other (`mlp_apple_tree.glb` is corrected to 5.60 m and the Kenney trees it replaced stood 6.2 m):

| id | target height |
|---|---|
| `saa_tree_wide.glb` | 6.20 m (the map's tallest canopy, the one you steer by) |
| `saa_tree_narrow.glb` | 5.60 m (the orchard's own number) |
| `saa_tree_dead_wide.glb` | 5.60 m (the same species, dead) |
| `saa_tree_dead_narrow.glb` | 5.20 m (a thinner dead trunk reads shorter) |
| `saa_dead_tree_large.glb` | 7.20 m (the Everfree's one landmark) |

Compute each with:

```bash
python3 -c "
targets = {'saa_tree_wide.glb': 6.20, 'saa_tree_narrow.glb': 5.60,
           'saa_tree_dead_wide.glb': 5.60, 'saa_tree_dead_narrow.glb': 5.20,
           'saa_dead_tree_large.glb': 7.20}
natives = {}  # fill from task 1 step 8's PROP lines: id -> native y
for k, t in targets.items():
    print(k, round(t / (natives[k] * 0.5193), 2))
"
```

- [ ] **Step 4: Add the `SCALE_FIX` rows and widen `FOLIAGE_PREFIXES`**

In `game/world/props.gd`, add to `SCALE_FIX` under the Sweet Apple Acres block (after line 148):

```gdscript
	# --- the treeline, which is MLP now ------------------------------------------------
	# THE KENNEY NATURE KIT'S FOLIAGE IS A FLAT CYAN SWATCH. docs/pipeline.md section 4
	# quirk 6 checked it: "leafsGreen" is the colour Kenney authored, not a colour space
	# bug, and the owner's word for the result was that the clashing asset style looks
	# terrible. Thirty nine of them stood on this map. These five replace them, at targets
	# taken from the orchard's own apple trees so the whole map's canopy agrees with itself.
	"saa_tree_wide.glb": <computed>,  # 6.20 m: the tallest canopy on the map.
	"saa_tree_narrow.glb": <computed>,  # 5.60 m: the orchard's own number.
	"saa_tree_dead_wide.glb": <computed>,  # 5.60 m: the same species, dead.
	"saa_tree_dead_narrow.glb": <computed>,  # 5.20 m: a thinner trunk reads shorter.
	"saa_dead_tree_large.glb": <computed>,  # 7.20 m: the Everfree's one landmark.
```

Replace line 219 with:

```gdscript
const FOLIAGE_PREFIXES := ["kenney_tree", "mlp_apple_tree", "saa_tree", "saa_dead_tree"]
```

- [ ] **Step 5: Replant the treeline**

In `game/world/props.gd`'s `LAYOUT`, delete the two yard fixtures at lines 248-249 (`kenney_windmill.glb`, `kenney_watermill.glb`) and every `kenney_tree_*` entry (lines 252-278 and the region plantings at 311-331), and replace them with the same coordinates carrying MLP species. **Keep every `at` and every `yaw` exactly as it stands** -- those coordinates were verified clear of every region fence ring, every `ZoneMarker` disc and the pen-plot clearing, and reusing them cannot break a clearance that was already checked (`game/test/test_props.gd:148` and `:155` assert both). Only the `file` and the `family` change. Every replacement entry carries `"family": &"mlp"`.

The species mapping, so the silhouettes still say what the place is:

| was | becomes |
|---|---|
| `kenney_tree_oak.glb` | `saa_tree_wide.glb` |
| `kenney_tree_fat.glb` | `saa_tree_wide.glb` |
| `kenney_tree_default.glb` | `saa_tree_narrow.glb` |
| `kenney_tree_pine.glb` (homestead treeline) | `saa_tree_narrow.glb` |
| `kenney_tree_pine.glb` (the Everfree Edge's eight) | `saa_tree_dead_narrow.glb`, with the two at (-95.2, -23.7) and (-76.9, -81.9) as `saa_dead_tree_large.glb` |
| `kenney_tree_pine.glb` (the Night Meadow's five) | `saa_tree_dead_wide.glb` |
| `kenney_tree_default.glb` (the Lake's four) | `saa_tree_narrow.glb` |

So, for instance, line 252

```gdscript
	{"file": "kenney_tree_oak.glb", "at": Vector2(-19.0, -19.0), "yaw": 0.0, "s": 1.15},
```

becomes

```gdscript
	{"file": "saa_tree_wide.glb", "at": Vector2(-19.0, -19.0), "yaw": 0.0, "s": 1.15, "family": &"mlp"},
```

Replace the class comment's `TREES ARE THE ONE CATEGORY-WIDE EXCEPTION` paragraph (lines 26-32) and the `TREE_SCALE` comment (lines 168-173) with a note that `TREE_SCALE` and `FAMILY_TREE` are kept for the family machinery `game/test/test_props.gd` pins and for anyone who replants a Kenney tree, while no `LAYOUT` entry uses them any more. **Do not delete `TREE_SCALE` or `FAMILY_TREE`**: `test_props.gd:32`, `:63` and `:127` all name them.

Update the Ponyville General block's comment (lines 384-395) to say the General is the Market's own model now (task 3) and delete the two entries at lines 394-395.

- [ ] **Step 6: Run the prop tests and the ranch gate, and read the new count**

```bash
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 tools/bin/godot --headless --audio-driver Dummy \
  --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_props.gd -gexit
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 tools/bin/godot --headless --audio-driver Dummy \
  --path game world/ranch.tscn 2>&1 | grep -E "RANCH_OK|RANCH_FAILED|RANCH props|skirtless|intrusions"
```

Expected: the prop tests green; `RANCH_OK ponies=49 props=<measured> assets=present`. **The count moves in this task**: 104 layout entries minus 39 trees, minus the windmill, the watermill, `pv_general` and `pv_general_sign`, plus the 39 replanted trees, so `props` drops by 4 to **107** unless the gate says otherwise. Read the printed number and use that, not this one. If `skirtless` names a new tree, add `"skirt": true` to that entry; if `intrusions` names one, move it and say so in the commit message.

- [ ] **Step 7: Update the census paragraph**

In `docs/testing.md`'s "Pinning an hour" paragraph, append:

```
`props` moved again in slice R2, from 111 to <measured>: the thirty nine Kenney blob trees
were replanted as Sweet Apple Acres trees on the same thirty nine coordinates (so every
fence ring and zone clearance already proved stays proved), the windmill and the watermill
came off the map (`game/world/building.gd`'s own header calls them a bare X of sails and a
bare waterwheel), and the standalone Ponyville General and its sign came out because the
Market building wears that model itself now.
```

- [ ] **Step 8: Run the suite and commit**

```bash
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 bash tools/run_tests.sh
git add game/world/props.gd game/test/test_props.gd docs/testing.md
git commit -m "feat: the map grows apple wood instead of turquoise blobs"
```

---

### Task 8: The placement pass

**Files:**
- Modify: `game/world/props.gd:246-460` (`LAYOUT`: the homestead yard block, the town row block, a new boardwalk block)
- Modify: `docs/testing.md` (the census paragraph, again, with the measured number)
- Test: `game/test/test_props.gd` (add the breathing-room test)

**Interfaces:**
- Consumes: `saa_dirt_road.glb`, `saa_small_dirt_pile.glb`, `pv_ogb_1.glb`, `pv_ogb_2.glb`, `pv_courtyard_b_balcony.glb` from task 1 with their native sizes; `saa_shed.glb` (already converted); the re-sized building footprints from task 3.
- Produces: a `LAYOUT` whose entries are composed rather than scattered; no new API.

- [ ] **Step 1: Write the failing test**

Append to `game/test/test_props.gd`:

```gdscript
## THE ACCEPTANCE BAR IS "THOUGHTFULLY PLACED" AND ONLY A PERSON CAN JUDGE THAT. What a test
## can hold is the half of it that is arithmetic: two props whose footprint rectangles
## overlap are two props intersecting, and no amount of taste makes that read as composed.
const BREATHING_ROOM := 0.15


func test_no_two_props_in_the_layout_stand_inside_each_other() -> void:
	# Footprint half extents are conservative: the entry's own scale times a nominal one
	# metre model, which under-reports a wide model and so never produces a false failure.
	# The real overlap check is the ranch gate's, against the LIVE colliders.
	var seen: Array[Dictionary] = []
	for entry: Dictionary in PropsScript.LAYOUT:
		var at: Vector2 = entry["at"]
		for other: Dictionary in seen:
			var gap: float = (at - (other["at"] as Vector2)).length()
			assert_gt(gap, BREATHING_ROOM,
				"%s and %s stand on the same spot" % [entry["file"], other["file"]])
		seen.append(entry)


func test_the_farmstead_has_a_shed_beside_its_barn() -> void:
	var files: Array[String] = []
	for entry: Dictionary in PropsScript.LAYOUT:
		var at: Vector2 = entry["at"]
		if absf(at.x + 10.0) < 14.0 and absf(at.y + 9.0) < 14.0:
			files.append(String(entry["file"]))
	assert_true(files.has("saa_shed.glb"),
		"spec section 5.1's second ranch structure stands in the ranch yard")


func test_the_town_row_stands_on_a_road() -> void:
	var roads := 0
	for entry: Dictionary in PropsScript.LAYOUT:
		if String(entry["file"]) != "saa_dirt_road.glb":
			continue
		var at: Vector2 = entry["at"]
		if at.y > 28.0 and at.y < 58.0:
			roads += 1
	assert_gte(roads, 6, "the road north is a road, not a strip of grass between six houses")
```

- [ ] **Step 2: Run it and watch the last two fail**

```bash
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 tools/bin/godot --headless --audio-driver Dummy \
  --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_props.gd -gexit
```

Expected: `test_the_farmstead_has_a_shed_beside_its_barn` and `test_the_town_row_stands_on_a_road` fail.

- [ ] **Step 3: Compose the farmstead**

Replace the homestead yard block (`game/world/props.gd`, the `# --- the homestead yard ---` section starting at line 445) with a composition around the Barn at (-10, -9) and the Farmhouse at (9, -7). Every entry is inside Terrain's flat apron, where relief is exactly zero and no skirt is needed; every one stands clear of the pen-plot clearing (`PEN_PLOTS_CENTRE` (-14, 13), half extent 9), of `MARKET_RADIUS` 4.5 from (-2, -1), `BOARD_RADIUS` 3.0 from (3, -1), `DEPOT_RADIUS` 4.0 from (10, 4) and `MAILBOX_RADIUS` 2.6 from (8, -2.5). The Market is 10.62 m wide now and turned 45 degrees, so its corners reach about 5.9 m from its origin on the diagonal: nothing may sit inside 6.5 m of (-2, -1).

```gdscript
	# --- the homestead yard: a farmstead, not a field with objects dropped in it ---------
	# READ AS A PICTURE. The shed stands beside the barn with the wagon between them and hay
	# stacked against the shed's wall, which is what a working yard looks like; the well and
	# the coop sit on the house side; the crates and the basket cluster by the market stall
	# so the shop has a delivery corner rather than a scatter of clutter. Every coordinate
	# clears the Market's own new footprint (10.62 m wide at 45 degrees about (-2, -1),
	# reaching 5.9 m on the diagonal) by at least 0.6 m, and clears every interaction radius
	# on the map by more.
	{"file": "saa_shed.glb", "at": Vector2(-14.5, -13.5), "yaw": 205.0, "family": &"mlp"},
	{"file": "saa_wagon.glb", "at": Vector2(-12.0, -14.5), "yaw": 200.0, "family": &"mlp"},
	{"file": "saa_hay_block.glb", "at": Vector2(-16.0, -11.0), "yaw": 15.0, "family": &"mlp"},
	{"file": "saa_hay_pile.glb", "at": Vector2(-17.5, -13.0), "yaw": 40.0, "family": &"mlp"},
	{"file": "saa_seed_bag.glb", "at": Vector2(-15.0, -10.0), "yaw": 300.0, "family": &"mlp"},
	{"file": "mlp_farm_well.glb", "at": Vector2(5.0, -11.5), "yaw": 60.0, "family": &"mlp"},
	{"file": "mlp_chicken_coop.glb", "at": Vector2(12.5, -11.0), "yaw": 250.0, "family": &"mlp"},
	{"file": "mlp_crate.glb", "at": Vector2(4.0, 7.0), "yaw": 30.0, "family": &"mlp"},
	{"file": "mlp_basket.glb", "at": Vector2(2.5, 6.0), "yaw": 0.0, "family": &"mlp"},
	{"file": "mlp_bush.glb", "at": Vector2(-6.5, -12.0), "yaw": 120.0, "family": &"mlp"},
	{"file": "mlp_bush.glb", "at": Vector2(13.5, -6.0), "yaw": 20.0, "family": &"mlp"},
	{"file": "saa_small_dirt_pile.glb", "at": Vector2(-11.5, -4.5), "yaw": 0.0, "family": &"mlp"},
```

Leave `kenney_market_stall.glb` at (2, 3) where it is: it is the neutral small clutter spec section 1 permits to survive, and it stands beside the request board on purpose.

- [ ] **Step 4: Put the town row on a real road**

Replace the town row block (lines 405-410) with a road plus six distinct buildings. `saa_dirt_road.glb` tiles along the road's own axis; read its native size from task 1 step 8 and space the tiles by their seated length so they abut rather than gap or overlap. The row runs north along z with the road on x = 1.5.

```gdscript
	# --- the town row, on the road north -------------------------------------------------
	# A ROAD, AND SIX BUILDINGS THAT ARE NOT THE RANCH'S OWN. The Farmhouse, the Board and
	# the Depot wear pv_wide_b, pv_bridged_b and pv_tower_b now (slice R2, ranch.tscn), so
	# the row uses the three that are left plus the three new pieces
	# tools/prop_manifest.txt gained, and nothing on the map is its own twin.
	#
	# The road tiles are spaced by saa_dirt_road's own seated length so they abut; they sit
	# ON the ground rather than under a building, so none of them carries a skirt.
	{"file": "saa_dirt_road.glb", "at": Vector2(1.5, 30.0), "yaw": 0.0, "family": &"mlp"},
	{"file": "saa_dirt_road.glb", "at": Vector2(1.5, 34.0), "yaw": 0.0, "family": &"mlp"},
	{"file": "saa_dirt_road.glb", "at": Vector2(1.5, 38.0), "yaw": 0.0, "family": &"mlp"},
	{"file": "saa_dirt_road.glb", "at": Vector2(1.5, 42.0), "yaw": 0.0, "family": &"mlp"},
	{"file": "saa_dirt_road.glb", "at": Vector2(1.5, 46.0), "yaw": 0.0, "family": &"mlp"},
	{"file": "saa_dirt_road.glb", "at": Vector2(1.5, 50.0), "yaw": 0.0, "family": &"mlp"},
	{"file": "saa_dirt_road.glb", "at": Vector2(1.5, 54.0), "yaw": 0.0, "family": &"mlp"},
	{"file": "pv_pink_b.glb", "at": Vector2(15.0, 36.0), "yaw": 270.0, "family": &"mlp", "skirt": true},
	{"file": "pv_ogb_1.glb", "at": Vector2(15.0, 43.0), "yaw": 270.0, "family": &"mlp", "skirt": true},
	{"file": "pv_courtyard_b.glb", "at": Vector2(15.0, 50.0), "yaw": 270.0, "family": &"mlp", "skirt": true},
	{"file": "pv_balcony_b.glb", "at": Vector2(-12.0, 36.0), "yaw": 90.0, "family": &"mlp", "skirt": true},
	{"file": "pv_ogb_2.glb", "at": Vector2(-12.0, 43.0), "yaw": 90.0, "family": &"mlp", "skirt": true},
	{"file": "pv_courtyard_b_balcony.glb", "at": Vector2(-12.0, 50.0), "yaw": 90.0, "family": &"mlp", "skirt": true},
```

Adjust the four figures in the road tiles' `at` if `saa_dirt_road`'s seated length is not 4.0 m: the spacing must equal the seated length, so `spacing = native_z * 0.5193 * SCALE_FIX_row` (the road carries no `SCALE_FIX` row unless the gallery shows it needs one -- add one only if the seated tile is not a road-sized tile beside a 2.138 m pony).

- [ ] **Step 5: Lay the boardwalk to the Palace**

Add a new block after the Las Pegasus block (after line 444). The Palace stands at (-10, 61.6) facing world -Z (its shell is yawed a half turn); the walk up to it comes from the homestead, so the boardwalk runs north along the road and turns west into the Palace's own door. Keep every tile out of the clear band the arcade cabinets already occupy (`x` in [-2, 18], `z` in [67, 72]) and out of the Palace's own rectangle (`x` in [-17, -3], `z` in [57.1, 66.1]).

```gdscript
	# --- the boardwalk up to the Palace -------------------------------------------------
	# THE APPROACH IS THE HALF OF A DESTINATION NOBODY BUILDS. The Palace's door faces world
	# minus Z at (-10, 57.1); this is the ground a player walks over on the way to it,
	# turning off the road north and running in along the door's own axis, so the frontage
	# is seen head on rather than edge on. Every tile clears the Palace's own rectangle
	# (x in [-17, -3], z in [57.1, 66.1]) and the arcade band (x in [-2, 18], z in [67, 72]).
	{"file": "saa_dirt_road.glb", "at": Vector2(1.5, 58.0), "yaw": 0.0, "family": &"mlp"},
	{"file": "saa_dirt_road.glb", "at": Vector2(-1.0, 55.5), "yaw": 45.0, "family": &"mlp"},
	{"file": "saa_dirt_road.glb", "at": Vector2(-4.5, 54.5), "yaw": 90.0, "family": &"mlp"},
	{"file": "saa_dirt_road.glb", "at": Vector2(-8.5, 54.5), "yaw": 90.0, "family": &"mlp"},
	{"file": "saa_dirt_road.glb", "at": Vector2(-12.5, 54.5), "yaw": 90.0, "family": &"mlp"},
	{"file": "mlp_bush.glb", "at": Vector2(-4.5, 51.5), "yaw": 200.0, "family": &"mlp"},
	{"file": "mlp_bush.glb", "at": Vector2(-12.5, 51.5), "yaw": 40.0, "family": &"mlp"},
```

- [ ] **Step 6: Run the prop tests and the ranch gate**

```bash
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 tools/bin/godot --headless --audio-driver Dummy \
  --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_props.gd -gexit
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 tools/bin/godot --headless --audio-driver Dummy \
  --path game world/ranch.tscn 2>&1 | grep -E "RANCH_OK|RANCH_FAILED|RANCH props|skirtless|intrusions|pen plot"
```

Expected: prop tests green; `RANCH_OK ponies=49 props=<measured> assets=present`. **The count moves again.** Read the number. A `skirtless` name means a wide prop off the flat apron with no skirt: add `"skirt": true` to that entry. An `intrusions` name means a prop reaching into a building's interaction radius: move it, do not widen the rule.

- [ ] **Step 7: Look at the whole map**

```bash
rm -rf build/r2_shots && mkdir -p build/r2_shots
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 timeout 900 xvfb-run -a tools/bin/godot \
  --path game --audio-driver Dummy --resolution 1600x900 world/ranch.tscn -- \
  "--screenshot-dir=$(pwd)/build/r2_shots"
ls build/r2_shots
```

Read `01_establishing.png`, `05_scale_at_the_barn.png`, `13_sweet_apple_acres.png`, `15_town_row_north_road.png`, `16_schoolyard.png`, `17_strip_arcade.png`, `19_marquee_and_gold_trim.png`. The bar is spec acceptance item 7: **"No clashing styles in any screenshot."** What to check in each: nothing intersects, nothing floats, nothing sinks, the road tiles abut rather than gap, the farmstead reads as a yard somebody works in, the town row reads as a street, the Strip reads as an approach. Move `at` figures and re-render until it does.

- [ ] **Step 8: Update the census paragraph and commit**

In `docs/testing.md`, revise the sentence task 7 added so it names the final measured `props` figure rather than task 7's intermediate one, and add one clause for the placement pass (the road tiles, the boardwalk, the farmstead shed).

```bash
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 bash tools/run_tests.sh
git add game/world/props.gd game/test/test_props.gd docs/testing.md
git commit -m "compose the yard, the road north and the walk up to the palace"
```

---

### Task 9: The terrain palette meets the PonySFM palette

**Files:**
- Modify: `game/world/terrain.gd:68-73` (`GRASS_LOW`, `GRASS_HIGH`, `DIRT`)
- Modify: `game/world/terrain.gdshader:22-52` (the uniform defaults for `grass_high`, `dirt_color`, `coarse_amount`, `ridge_lift`)
- Modify: `game/world/ranch.tscn:75-78` (`adjustment_saturation`, `adjustment_contrast`)
- Test: `game/test/test_terrain.gd` (add the palette-agreement test)

**Interfaces:**
- Consumes: the converted PonySFM texture PNGs under `game/assets/converted/props/` (they are the palette this is being tuned against).
- Produces: nothing new in code. `Terrain.GRASS_LOW/GRASS_HIGH/DIRT` keep their names and types; `terrain.gd:332-333` already pushes two of them into the shader, so the shader defaults and the consts stay in lockstep as they do today.

- [ ] **Step 1: Measure the palette rather than guessing at it**

```bash
cd /home/admin/Documents/filly-rancher
python3 - <<'PY'
import colorsys, glob
from PIL import Image
# The foliage and ground textures the map is about to be full of. Sampled rather than
# eyeballed: "warmer and more saturated" is not a number and a number is what the shader takes.
names = ["mlp_apple_tree_leaves.png", "mlp_bush_leaves.png",
         "mlp_apple_tree_bare_leaves.png", "mlp_apple_tree_tree_wood.png"]
for n in names:
    for path in glob.glob("game/assets/converted/props/" + n):
        im = Image.open(path).convert("RGB").resize((64, 64))
        px = list(im.getdata())
        r = sum(p[0] for p in px) / len(px) / 255
        g = sum(p[1] for p in px) / len(px) / 255
        b = sum(p[2] for p in px) / len(px) / 255
        h, l, s = colorsys.rgb_to_hls(r, g, b)
        print("%-40s rgb=(%.3f, %.3f, %.3f) hue=%.3f sat=%.3f lum=%.3f"
              % (path.split("/")[-1], r, g, b, h, s, l))
for name, c in [("GRASS_LOW", (0.239, 0.408, 0.196)),
                ("GRASS_HIGH", (0.443, 0.541, 0.271)),
                ("DIRT", (0.36, 0.28, 0.19))]:
    h, l, s = colorsys.rgb_to_hls(*c)
    print("%-40s hue=%.3f sat=%.3f lum=%.3f" % (name, h, s, l))
PY
```

Record the printed hues and saturations. Wherever the ground's hue sits more than 0.03 away from the foliage's, or its saturation more than 0.10 below, the ground is the thing that moves.

- [ ] **Step 2: Write the failing test**

Append to `game/test/test_terrain.gd`:

```gdscript
## THE GROUND AND THE THINGS STANDING ON IT SHARE LIGHT, OR THEY DO NOT LOOK LIKE ONE PLACE.
## This cannot say whether the grass is pretty. It can say the two ends of the gradient still
## bracket each other, that the dirt is still earth rather than grass, and that the numbers a
## human tuned in terrain.gd are the numbers the shader is actually handed -- which is the
## pair that silently drifts.

func test_the_grass_gradient_still_runs_from_shade_to_light() -> void:
	assert_lt(TerrainScript.GRASS_LOW.v, TerrainScript.GRASS_HIGH.v,
		"GRASS_LOW is the shaded end and GRASS_HIGH the lit one")
	assert_gt(TerrainScript.GRASS_LOW.s, 0.35, "grass at either end is grass, not a grey")
	assert_gt(TerrainScript.GRASS_HIGH.s, 0.35, "grass at either end is grass, not a grey")


func test_the_dirt_is_earth_and_never_another_green() -> void:
	var h: float = TerrainScript.DIRT.h
	assert_true(h < 0.14 or h > 0.95,
		"a hue in the greens would make the slope mask invisible")


func test_the_shader_is_handed_the_colours_terrain_gd_holds() -> void:
	var mesh := _built_terrain_mesh()
	var mat := mesh.material_override as ShaderMaterial
	assert_not_null(mat, "the ground wears the shader")
	assert_eq(mat.get_shader_parameter(&"grass_high"), TerrainScript.GRASS_HIGH,
		"the lit end of the gradient is one number in one place")
	assert_eq(mat.get_shader_parameter(&"dirt_color"), TerrainScript.DIRT,
		"the earth is one number in one place")
```

(Reuse whatever helper `test_terrain.gd` already has for building the mesh; read the file first and name it `_built_terrain_mesh()` only if no equivalent exists.)

- [ ] **Step 3: Run it and see which assertions the shipped palette already passes**

```bash
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 tools/bin/godot --headless --audio-driver Dummy \
  --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_terrain.gd -gexit
```

Expected: the third test fails if it names a helper that does not exist yet; the first two describe the shipped values and should pass, which is the point -- they are a floor the tuning must not fall through.

- [ ] **Step 4: Take a before sheet**

```bash
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 bash tools/sky_sheet.sh --only=day_clear build/r2_sky_before
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 bash tools/sky_sheet.sh --only=dusk_clear build/r2_sky_before
cp build/sky_sheet.png build/r2_sky_before/dusk_clear_sheet.png
```

Read `build/r2_sky_before/day_clear.png` and `build/r2_sky_before/dusk_clear.png`. These are the before half of the before/after pair.

- [ ] **Step 5: Move the ground toward the palette, in three small measured steps**

In `game/world/terrain.gd`, replace lines 68-73's values with numbers taken from step 1. The change is a shift of hue and saturation, not of value: keep `GRASS_LOW.v` and `GRASS_HIGH.v` within 0.03 of what they are, so nothing about the map's readability at dusk changes. Write the measurement into the comment above each:

```gdscript
## TUNED AGAINST THE PONYSFM PALETTE, NOT PICKED BY EYE A SECOND TIME. The foliage the map
## is full of now measures hue <measured> at saturation <measured> across
## mlp_apple_tree_leaves.png and mlp_bush_leaves.png; the shipped grass sat at hue <old> and
## saturation <old>, which is why the ground read as a different production's grass under an
## MLP tree. Value is deliberately held within 0.03 of the shipped numbers: what was wrong
## was the hue and the saturation, and moving the brightness as well would change how the
## map reads at dusk for a reason that has nothing to do with the palette.
const GRASS_LOW := Color(<r>, <g>, <b>)
const GRASS_HIGH := Color(<r>, <g>, <b>)
```

Mirror the new `GRASS_HIGH` and `DIRT` into `game/world/terrain.gdshader:22-23`'s uniform defaults. They are only defaults -- `terrain.gd:332-333` pushes the live values -- but a default that disagrees with the const is a trap for the next reader.

In `game/world/ranch.tscn`, line 78, take `adjustment_saturation` from `1.14` to `1.08`: the hand-painted textures carry their own saturation, and a global multiplier on top of them is what turns a warm palette garish. Leave `adjustment_contrast` at `1.05`.

- [ ] **Step 6: Take the after sheet and compare**

```bash
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 bash tools/sky_sheet.sh --only=day_clear build/r2_sky_after
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 bash tools/sky_sheet.sh --only=dusk_clear build/r2_sky_after
```

Read `build/r2_sky_after/day_clear.png` beside `build/r2_sky_before/day_clear.png`, and the dusk pair. What to check: the ground and the foliage read as one light; the dirt band around the lake basin is still visible; nothing has gone neon; dusk is still legible. If any of those fails, move the numbers halfway back and re-render. Do not touch `slope_low`, `slope_high`, `fine_amount` or the fade distances -- those were measured against this heightfield's own steepest point (0.0442) and are not palette.

- [ ] **Step 7: Run the terrain test, the ranch gate and the suite**

```bash
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 tools/bin/godot --headless --audio-driver Dummy \
  --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_terrain.gd -gexit
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 tools/bin/godot --headless --audio-driver Dummy \
  --path game world/ranch.tscn 2>&1 | grep -E "RANCH_OK|RANCH_FAILED"
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 bash tools/run_tests.sh
```

Expected: all green, `RANCH_OK` with the same counts task 8 measured.

- [ ] **Step 8: Commit**

```bash
git add game/world/terrain.gd game/world/terrain.gdshader game/world/ranch.tscn \
  game/test/test_terrain.gd
git commit -m "tune the ground's hue and saturation against the ponysfm palette"
```

---

### Task 10: Census close-out, the test floor, and the full gate sweep

**Files:**
- Modify: `tools/run_tests.sh:202` (`MIN_TESTS`)
- Modify: `docs/testing.md:328-340` (the `MIN_TESTS` paragraph), and any remaining `props=111` / `count=35` occurrence
- Do NOT modify: `docs/superpowers/specs/2026-09-04-presentation-redesign-design.md`. The spec is the argument this plan answers, not a record of what shipped.

**Interfaces:**
- Consumes: every measured number from tasks 1, 7, 8.
- Produces: a green sweep at the raised floor, proved both ways.

- [ ] **Step 1: Sweep every stale number out of the docs**

```bash
cd /home/admin/Documents/filly-rancher
grep -rn "props=111\|count=35\|ponies=49 props" docs/ tools/ game/ --include='*.md' --include='*.sh' --include='*.gd'
```

Every hit must either be the new measured number or a sentence explicitly about history ("`props` moved from ... to ..."). Fix the rest.

- [ ] **Step 2: Run the full gate sweep, one process at a time**

```bash
cd /home/admin/Documents/filly-rancher
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 bash tools/run_tests.sh 2>&1 | tail -12
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 tools/bin/godot --headless --audio-driver Dummy \
  --path game world/ranch.tscn 2>&1 | grep -E "RANCH_OK|RANCH_FAILED"
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 tools/bin/godot --headless --audio-driver Dummy \
  --path game world/ranch.tscn -- --phase=NIGHT --weather=STORM 2>&1 | grep -E "RANCH_OK|RANCH_FAILED|RANCH world"
for gate in market region world collection ledger depot creation casino story; do
  echo "== $gate"
  FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 tools/bin/godot --headless --audio-driver Dummy \
    --path game "scenes/test/${gate}_test.tscn" 2>&1 | grep -E "_OK |_FAILED "
done
echo "== sound (headless, NEVER xvfb)"
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 tools/bin/godot --headless --audio-driver Dummy \
  --path game scenes/test/sound_test.tscn 2>&1 | grep -E "SOUND_OK|SOUND_FAILED"
echo "== gallery (xvfb)"
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 xvfb-run -a tools/bin/godot --audio-driver Dummy \
  --path game scenes/test/model_gallery.tscn -- --props 2>&1 | grep -E "GALLERY_OK"
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 xvfb-run -a tools/bin/godot --audio-driver Dummy \
  --path game scenes/test/model_gallery.tscn -- --stock 2>&1 | grep -E "GALLERY_OK"
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 xvfb-run -a tools/bin/godot --audio-driver Dummy \
  --path game scenes/test/model_gallery.tscn -- --mark 2>&1 | grep -E "GALLERY_MARK_OK"
echo "== save safety"
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 bash tools/prove_save_safety.sh 2>&1 | tail -5
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 bash tools/prove_atomic_save.sh 2>&1 | tail -5
```

Expected: `MARKET_OK checks=69`, `REGION_OK checks=49`, `WORLD_OK checks=32`, `COLLECTION_OK checks=73`, `LEDGER_OK checks=87`, `DEPOT_OK checks=72`, `CREATION_OK checks=93`, `CASINO_OK checks=76`, `STORY_OK checks=58`, `SOUND_OK ids=37`, the three gallery lines at their measured counts, both save proofs green, and `RANCH_OK ponies=49 props=<measured> assets=present` from both the plain and the pinned run.

- [ ] **Step 3: Re-prove the pre-R2 save one more time, on the finished map**

Repeat task 3's step 7 verbatim, against the map as it now stands. Expected: `RANCH_OK`, both plots rebuilt, both ponies back in their pens, no error about a body starting inside geometry. If a pony or the player now spawns inside a re-sited prop, move the prop, not the save.

- [ ] **Step 4: Read the test count and raise the floor**

The `run_tests.sh` output in step 2 prints `Tests <n>` above GUT's verdict. Raise the floor to that number:

```bash
grep -n 'MIN_TESTS="${FILLY_MIN_TESTS:-1572}"' tools/run_tests.sh
```

Change `1572` to the measured `<n>`.

- [ ] **Step 5: Prove the floor both ways**

```bash
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 bash tools/run_tests.sh 2>&1 | tail -6
FILLY_TEST_SAVE_DIR="$(mktemp -d)" FILLY_MIN_TESTS=99999 nice -n 19 bash tools/run_tests.sh 2>&1 | tail -4
```

Expected: the first exits 0 with `---- All tests passed! ----`; the second exits 1 with `ERROR: GUT ran <n> tests, below this suite's floor of 99999 -- tests have gone missing.`

- [ ] **Step 6: Record the raise in `docs/testing.md`**

In the `MIN_TESTS` paragraph at lines 328-340, extend the final parenthetical:

```
It was raised again, from 1571 to <n>, by slice R2's own growth -- the modelled building
shell, the palace facade, the marquee arch, the sign standoffs, the replanted treeline and
the placement pass all brought tests with them -- proved both ways per the section below at
the new number: the suite passes at <n> and a `FILLY_MIN_TESTS=99999` run still fails on it.
```

- [ ] **Step 7: Render the final evidence set**

```bash
rm -rf build/r2_shots && mkdir -p build/r2_shots
FILLY_TEST_SAVE_DIR="$(mktemp -d)" nice -n 19 timeout 900 xvfb-run -a tools/bin/godot \
  --path game --audio-driver Dummy --resolution 1600x900 world/ranch.tscn -- \
  "--screenshot-dir=$(pwd)/build/r2_shots"
ls build/r2_shots
```

Read every shot from `01_establishing.png` through `21_race_lane_colours.png` and write a one-line verdict per shot against the two acceptance items this slice answers:

- **Item 7, "No clashing styles in any screenshot":** no Kenney silhouette in frame that has not been through the palette pass; no `BoxMesh` building visible anywhere; no floating text.
- **Item 12, "Palace exterior looks like a destination":** shots 17, 18 and 19.

Any shot that fails goes back to the task that owns it (3 for buildings, 5 for the Palace, 6 for the marquee, 8 for placement, 9 for the ground) rather than being patched here.

- [ ] **Step 8: Commit**

```bash
git add tools/run_tests.sh docs/testing.md
git commit -m "chore: raise the test floor and record what r2 moved"
```

---

## Self-review against spec section 5 and acceptance items 7 and 12

**Coverage of spec 5.1 (buildings):**
- "`building.gd` primitives retire from view" -- tasks 2 and 3.
- "Barn becomes `saa_barn.glb`" -- task 3 step 3.
- "a second ranch structure uses `saa_shed.glb`" -- task 8 step 3 (as a prop; ambiguity 2 above).
- "Market becomes `pv_general.glb` (+ its sign)" -- task 3 step 4, with the standalone prop entries removed in task 7 step 5.
- "Farmhouse/Board/Depot cast from the six town buildings by footprint" -- task 3 step 4, with the Board also gaining a real notice board in task 4 (ambiguity 3).
- "The `Building` class survives only as the invisible collision/door-marker shell" -- task 2, with the plinth and apron kept for the reason in ambiguity 1.
- "The Spectra Palace: kit-bash a wide facade + a purpose-drawn marquee" -- tasks 5 and 6.
- "Fix the sign z-fighting/floating-dots on every remaining board" -- task 4 (lobby sign, request board) and task 6 (marquee).

**Coverage of spec 5.2 (environment and placement):**
- "turquoise Kenney blob trees replaced by owned PonySFM trees" -- task 7.
- "Kenney nature survives only as neutral rocks/paths" -- task 7 step 5 removes the windmill and the watermill; the market stall survives per ambiguity 8.
- "a deliberate placement pass ... farmstead, dirt roads, boardwalk, breathing room, nothing intersecting" -- task 8.
- "Terrain/palette tune" -- task 9.
- "screenshots from the gallery gate document before/after" -- task 9 steps 4 and 6 (sky sheet cells), task 10 step 7 (the full set).

**Coverage of the brief's item E (census and gates):** every task that moves a number reads the real value out of the gate rather than predicting it, and updates `docs/testing.md` in the same task -- task 1 (`GALLERY_OK count=`), task 3 (`props` explicitly does not move, and the doc says why), task 7 and task 8 (`props` moves; measured), task 10 (`MIN_TESTS`, and the stale-number sweep).

**Placeholder scan:** the only bracketed values left in the plan are ones that are *measurements taken during the task*, each with the exact command that produces them: the five `SCALE_FIX` divisions in task 7 step 3, the four `neon_<a..d>` ids in task 5 step 3 (produced by task 1 step 9 into `tools/prop_manifest.txt`), the measured colours in task 9 step 5, the road tile spacing in task 8 step 4, and the measured counts in tasks 1, 7, 8 and 10. No step says "similar to task N", no step says "add appropriate error handling", and every code step carries the code.

**Name consistency:** `model_file` / `model_scale` / `model_yaw` / `wears_a_model()` / the `Model` child node are used identically in tasks 2, 3, 4 and 5. `PalaceFacade.build(half_width, half_depth, door_half, facing) -> int`, `piece_count()`, `neon_count()`, `PIECES`, `NEON` and `OVERSAIL` are used identically in task 5's implementation and its tests. `LobbySign.STANDOFF` (task 4) and `Strip.MARQUEE_STANDOFF_LAYER` (task 6) are deliberately different names for the same 0.05 m idea in two unrelated classes, and each comment points at the other. `Props.SKIRT_COLOUR`, `Props.MLP_SCALE`, `Props.PROP_DIR` and `Props.world_aabb()` are named exactly as `game/world/props.gd` spells them. `Building.FLOOR_TOP` is the anchor tasks 2 and 5 both build on.
