# Phase 3 Slice 1: Character Creation, Stock Ponies and the Ledger Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the player a pony she designed and named, fill the world with recoloured generic ponies who are the crowd the named ones hide in, and hang a Company debt over the whole thing that only delivering ponies can move.

**Architecture:** One recolour pipeline (`StockPalette` swatches plus `StockTint` material overrides) serves two users: the stock crowd and the player's own model. Stock ponies are three hidden `PonyData` records (one per personality) built on a single base model; they are resolvable by id but never listed, so the Compendium, the spawn tables and the pause menu count exactly the 43 collectibles they counted before. `PonyInstance` gains `stock: Dictionary` (the palette triple) so a stock pony in a pen is a real, saved resident. `Ledger` is pure arithmetic: a balance, a collection day every three cycles, upkeep, a service charge, a quota, delivery credits and a four rung collector ladder. The Depot is a building beside the Market whose menu delivers, pays and prints a statement; a delivered pony walks to the crate on the existing departure path (`Pony.leave_toward`, one new target on the one existing `LEAVING` state) and is freed only by that path. The cutie mark is a 64 by 64 `Image` the player paints, applied to both flanks as `Decal` nodes on a bone attachment and stored in the save as a base64 PNG. Save format version becomes 5.

**Tech Stack:** Godot 4.5.2, GDScript, GUT 9.5.0, the project's headless gate conventions.

**Spec:** `docs/superpowers/specs/2026-08-30-phase3-rainbow-factory-design.md`, sections "Character creation", "Stock ponies", "The ledger", "The Depot", "Pacing", "Data model changes", "Testing", and build order item 1. Casino, story beats, NPCs, the insider, the fork, the Resistance and the Factory interior are later slices and are out of scope here.

## Global Constraints

- **No em dash and no double hyphen in ANY player-facing string; also none in new code, comments, docs, or data (ASCII banners like `# --- x ---` are exempt). Use ";" or ":" or commas.** This applies to every string in this slice: swatch labels, Depot rows, statement lines, receipt letters, toasts, prompts, and the plan's own new documentation.
- **Tone.** The owner's standing touchstones: Slime Rancher for the ranching feel, Stardew Valley for the town and the forever loop, gambling for fun, and a dark humour register. Company copy reads like an HR poster: funny until it is not. Every Depot string, statement line and receipt letter in this slice is written cheerful corporate ("Your 3rd shipment! Cloudsdale thanks you"), never grim.
- **NO PONY EVER DIES ON SCREEN; the only way a pony leaves the world is the existing departure path (`Pony.leave()`); a delivered pony walks into the Depot crate via that path. Capture wins over leaving; nothing is freed while HELD.** `Pen.release_body()` (Task 5) hands a body over without freeing it; only `Pony._state_leaving` may call `queue_free()` on a pony.
- **Explicit type annotations wherever `:=` cannot infer the type** (Godot 4.5 promotes `INFERENCE_ON_VARIANT` to an error on the preload dependency compile path; GUT's loader does not catch it, but `tools/run_tests.sh`'s parse sweep does).
- **Every new `.gd` gets its `.uid` sidecar committed; preload by `res://` path**, never by the global `class_name` (the class cache lives in the gitignored `game/.godot/`).
- **Saves: `SaveIO.FORMAT_VERSION` becomes 5; `migrate()` stays additive; v1 to v4 saves must load** (a v4 save gets: the ledger at its starting balance, the player named "Twilight" with the current look and a blank mark, story free defaults). Round trip tests for every new key in `game/test/test_save_io.gd`.
- **Headless gates print their marker only after deciding the verdict; exit code is the verdict**; run as `tools/bin/godot --headless --audio-driver Dummy --path game <scene>`. New gates for this slice: `ledger_test`, `depot_test`, `creation_test`, plus additions to the existing ranch gate report for the invariant that the world pony count never loses a pony to anything but the departure path.
- **Commit messages via `git commit -F <file>`; conventional prefixes** (`feat:`/`fix:`/`test:`/`docs:`).
- **Exact numbers from the spec are binding.** `Ledger.STARTING_BALANCE = 25000`; a collection day every `Ledger.PERIOD_CYCLES = 3` cycles; `Ledger.DELIVERY_CREDIT_STOCK = 300`; `Ledger.DELIVERY_NAMED_MULTIPLIER = 40`; `Ledger.STARTING_QUOTA = 2`; the collector ladder in the order fee, permit revoked, pen padlocked, beam recalled for one cycle. (The spec writes these as `LEDGER_STARTING_BALANCE`, `LEDGER_PERIOD_CYCLES`, `LEDGER_CEILING`, `DELIVERY_CREDIT_STOCK`, `DELIVERY_NAMED_MULTIPLIER`; on the `Ledger` class the `LEDGER_` prefix is dropped because the class name already carries it. `DELIVERY_CREDIT_STOCK` and `DELIVERY_NAMED_MULTIPLIER` keep their spec names verbatim.)
- **The tuning invariant "gems alone never clear the balance" gets a simulation test**: the best gem rate the roster and the plot catalogue permit, over 50 collection days, ends above zero.
- **Pacing.** The first collection day lands at one real hour of play (3 cycles at `WorldState.CYCLE_SECONDS` 1200). Stock ponies are the crowd: named ponies are at most 1 in 5 wild spawns in the ranch region and rarer beyond it. Stock respawn on a timer. The map wide no duplicates rule applies to named ponies only; two stock ponies may stand in the same field.
- **Menus draw and emit; `ranch.gd` transacts and pays.** The Depot menu never touches `Economy`, `Ledger` or `GameState` directly.
- Branch: `phase3-slice1-ledger`. Commit after every task. Run `bash tools/run_tests.sh` (no `FILLY_SKIP_SWEEP`) before calling any task finished.

---

## What is on disk today, and what this slice changes

Read before starting. Everything below was verified against the working tree at `687a441`.

**The pony models.** `game/assets/converted/ponies/` holds 43 `.glb` files in three families. Twenty three of them are the "ReVAmped" rig, whose glTF materials are named exactly `body`, `hair`, `tail`, `eyeball_l`, `eyeball_r`, `eyebrow`, `eyelashes`, `teeth`, `tongue`, and (per character) `horn` or `wings`. Their body texture is a flat coat colour: `caramel_body.png` is 99.2% one RGB value with the cutie mark as the remaining 0.8%. Their hair texture is two flat tones. Godot's glTF importer copies each glTF material name into the imported `StandardMaterial3D.resource_name`, which is the handle `StockTint` matches on.

**The base model for stock ponies and for the player is `res://assets/converted/ponies/pokeypierce.glb`.** It is chosen because it is a ReVAmped rig (clean surface names), it is a unicorn (`horn` material and a `bodyparts/feral/horns/horn.dmx` mesh, and the player must be a unicorn because the beam is the game), and it has no wings. Its body mesh spans x in [-0.238, 0.238], y in [0.459, 1.164], z in [-0.504, 0.393] in model space, with the tail at +z, so the model faces -z; the flank sits at about (x = +/- 0.24, y = 0.86, z = 0.22). Its skeleton carries a `Pelvis` bone and a `Chest1` bone. Those numbers are where Task 7's decal constants come from.

**Where the counts live.** `game/world/ranch.tscn` has nine `ZoneMarker` nodes: five with `zone_id = &"ranch"` and `spawn_count = 2`, and one each for `orchard`, `everfree`, `lake` and `nightmeadow` with `spawn_count = 3`. Twenty two named ponies stand on the shipped map today and the ranch gate prints `RANCH_OK ponies=22 props=58 assets=present`. This slice retunes those counts (Task 2) and every gate and doc that names 22 moves with them.

**The registries.** `PonyRegistry.load_all(dir)` scans a directory of `.tres`, indexes by id, and `all()`/`ids()`/`by_zone()`/`by_rarity()` read that index. `Compendium` counts against `registry.all()`. `Player._build_visuals()` builds its own registry from `pony_dir` and looks the player up in the returned dictionary. Task 1 adds a second, hidden index so a stock record is resolvable by id and invisible to every listing, which is what keeps the Compendium at 43 and every existing test green.

## File structure

**New systems** (`game/systems/`, all `RefCounted` or `Resource`, all GUT tested without a scene):

| File | Responsibility |
|---|---|
| `stock_palette.gd` | `StockPalette` resource: coat, mane and eye swatch arrays; the stock id list; safe index lookup; a seeded triple draw. |
| `stock_tint.gd` | `StockTint`: turn a built model plus three colours into per surface material overrides. The one recolour pipeline. |
| `ledger.gd` | `Ledger`: balance, collection day arithmetic, upkeep, service charge, quota, delivery credits, the collector ladder, statement lines. |
| `letters.gd` | `Letters`: the stub Company sender. Fixed cheerful corporate templates rendered with the player's name. |
| `player_look.gd` | `PlayerLook`: name, palette indices, mane style, and the 64 by 64 mark image; base64 PNG serialisation. |
| `mark_paint.gd` | `MarkPaint`: pure pixel operations on the mark image (dot, stroke, clear, compare). |
| `mark_stamps.gd` | `MarkStamps`: procedurally drawn starter templates, so no binary asset is needed. |
| `cutie_mark.gd` | `CutieMark`: place two `Decal` nodes on the flanks of a built model and give them the mark texture. |

**New data** (committed `.tres`):

| File | Responsibility |
|---|---|
| `game/data/hidden/stock_shy.tres`, `stock_bold.tres`, `stock_curious.tres` | The three base `PonyData` records. Resolvable by id, never listed. |
| `game/data/stock_palette.tres` | The stock swatch rows. |
| `game/data/player_palette.tres` | The wider player swatch rows. |

**New UI** (`game/ui/`): `depot_menu.gd`/`.tscn`, `mark_canvas.gd`/`.tscn`, `creation_screen.gd`/`.tscn`.

**New gates** (`game/scenes/test/`): `ledger_test.gd`/`.tscn`, `depot_test.gd`/`.tscn`, `creation_test.gd`/`.tscn`.

**Modified:** `game/systems/pony_registry.gd` (hidden index), `pony_instance.gd` (`stock`), `compendium.gd` (`PROCESSED`), `region_data.gd` (`stock_min`/`stock_max`), `save_io.gd` (version 5), `game_state.gd` (`ledger`, `player`), `game/world/zone_marker.gd` (`stock_count`), `spawner.gd` (stock budget and respawn), `pen.gd` (`release_body`, padlock), `ranch.gd` and `ranch.tscn` (Depot, wiring, gate report), `game/actors/pony/pony.gd` (`leave_toward`, stock tint), `game/actors/player/player.gd` (base model, tint, mark), `magic_beam.gd` (carry the palette triple onto the minted instance; the recall), `game/ui/hud.gd`/`.tscn` (the balance line), `pause_menu.gd`/`.tscn` (the LEDGER page, PROCESSED rows), `tools/run_tests.sh` (`MIN_TESTS`), `docs/testing.md`, `docs/pipeline.md`.

---

### Task 1: StockPalette, the hidden base records, and the tint pipeline

**Files:**
- Create: `game/systems/stock_palette.gd`, `game/systems/stock_tint.gd`, `game/data/stock_palette.tres`, `game/data/player_palette.tres`, `game/data/hidden/stock_shy.tres`, `game/data/hidden/stock_bold.tres`, `game/data/hidden/stock_curious.tres`
- Modify: `game/systems/pony_registry.gd`, `game/actors/player/player.gd:353-365` (`_build_visuals` looks up through `by_id`)
- Test: `game/test/test_stock_palette.gd`, `game/test/test_stock_tint.gd`, `game/test/test_pony_registry.gd`

**Interfaces:**
- Consumes: `PonyRegistry.load_all(dir) -> Dictionary`, `PonyRegistry.by_id(id) -> PonyData`, `PonyVisuals.build(data) -> Node3D`, `PonyData` exports.
- Produces:
  - `class_name StockPalette extends Resource`. Exports `coats: Array[Color]`, `manes: Array[Color]`, `eyes: Array[Color]`. Constants `STOCK_PATH := "res://data/stock_palette.tres"`, `PLAYER_PATH := "res://data/player_palette.tres"`, `IDS: Array[StringName] = [&"stock_shy", &"stock_bold", &"stock_curious"]`. Statics `load_stock() -> StockPalette`, `load_player() -> StockPalette`, `is_stock_id(id: StringName) -> bool`. Methods `coat_at(index: int) -> Color`, `mane_at(index: int) -> Color`, `eye_at(index: int) -> Color` (all wrap with `posmod`, all answer `Color.WHITE` on an empty row), `is_valid() -> bool`, `draw_triple(rng: RandomNumberGenerator) -> Dictionary` returning `{"coat": int, "mane": int, "eyes": int}`.
  - `class_name StockTint extends RefCounted`, static only. `enum Role { NONE, COAT, MANE, EYE }`. Constants `COAT_SURFACES`, `MANE_SURFACES`, `EYE_SURFACES` (`Array[StringName]`). `static func role_of(material_name: StringName) -> int`. `static func apply_colors(model: Node3D, coat: Color, mane: Color, eyes: Color) -> int` returning the number of surfaces overridden. `static func apply(model: Node3D, palette: StockPalette, triple: Dictionary) -> int`. `static func override_of(model: Node3D, material_name: StringName) -> StandardMaterial3D` (for tests and gates).
  - `PonyRegistry` gains `const HIDDEN_DIR := "res://data/hidden"`, `func hidden_ids() -> Array[StringName]`, and a `by_id()` that falls back to the hidden index. `all()`, `ids()`, `by_zone()`, `by_rarity()` and `load_all()`'s return value are unchanged and still exclude hidden records.

**The tint, concretely, and what it can and cannot do.** The base model's `body`, `hair` and `tail` textures are flat colour, so a coat or mane surface is overridden with a `StandardMaterial3D` that drops `albedo_texture` (which also drops the base character's cutie mark, which is exactly right for unregistered stock) and keeps `normal_texture`, with `albedo_color` set to the swatch. The eyeball surfaces KEEP their texture, because it carries the pupil, the highlight and the iris, and `albedo_color` multiplies it; so an eye swatch tints the baked iris rather than replacing it, and the shipped eye rows are authored to read correctly against that base. A full iris replacement is Phase 5's look system and is deliberately not built here.

- [ ] **Step 1: Write the failing tests**

`game/test/test_stock_palette.gd`:

```gdscript
extends GutTest
## The swatch rows and the safe index lookup behind every recolour in the game.

const StockPaletteScript := preload("res://systems/stock_palette.gd")


func test_the_shipped_stock_palette_loads_and_is_valid() -> void:
	var palette: StockPalette = StockPaletteScript.load_stock()
	assert_not_null(palette, "res://data/stock_palette.tres must load")
	assert_true(palette.is_valid(), "every row of the stock palette must hold at least one swatch")


func test_the_player_palette_is_wider_than_the_stock_palette() -> void:
	var stock: StockPalette = StockPaletteScript.load_stock()
	var player: StockPalette = StockPaletteScript.load_player()
	assert_gt(player.coats.size(), stock.coats.size(), "the player picks from a wider coat row")
	assert_gt(player.manes.size(), stock.manes.size(), "the player picks from a wider mane row")


func test_an_index_out_of_range_wraps_instead_of_crashing() -> void:
	var palette: StockPalette = StockPaletteScript.load_stock()
	var n: int = palette.coats.size()
	assert_eq(palette.coat_at(n), palette.coat_at(0), "one past the end wraps to the start")
	assert_eq(palette.coat_at(-1), palette.coat_at(n - 1), "a negative index wraps from the end")


func test_an_empty_row_answers_white_rather_than_erroring() -> void:
	var palette := StockPalette.new()
	assert_eq(palette.coat_at(0), Color.WHITE)
	assert_eq(palette.mane_at(3), Color.WHITE)
	assert_eq(palette.eye_at(-2), Color.WHITE)
	assert_false(palette.is_valid())


func test_draw_triple_is_deterministic_for_a_seed() -> void:
	var palette: StockPalette = StockPaletteScript.load_stock()
	var a := RandomNumberGenerator.new()
	a.seed = 4242
	var b := RandomNumberGenerator.new()
	b.seed = 4242
	assert_eq(palette.draw_triple(a), palette.draw_triple(b), "same seed, same pony")


func test_draw_triple_stays_inside_every_row() -> void:
	var palette: StockPalette = StockPaletteScript.load_stock()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 200:
		var triple: Dictionary = palette.draw_triple(rng)
		assert_between(int(triple["coat"]), 0, palette.coats.size() - 1)
		assert_between(int(triple["mane"]), 0, palette.manes.size() - 1)
		assert_between(int(triple["eyes"]), 0, palette.eyes.size() - 1)


func test_the_three_stock_ids_are_recognised_and_nobody_else_is() -> void:
	for id: StringName in StockPaletteScript.IDS:
		assert_true(StockPaletteScript.is_stock_id(id), "%s is a stock id" % id)
	assert_false(StockPaletteScript.is_stock_id(&"twilight"))
	assert_false(StockPaletteScript.is_stock_id(&""))
```

`game/test/test_stock_tint.gd`:

```gdscript
extends GutTest
## The one recolour pipeline, proved against the real base model.

const StockTintScript := preload("res://systems/stock_tint.gd")
const StockPaletteScript := preload("res://systems/stock_palette.gd")
const PonyRegistryScript := preload("res://systems/pony_registry.gd")
const PonyVisualsScript := preload("res://actors/pony/pony_visuals.gd")

var _model: Node3D = null


func after_each() -> void:
	if _model != null and is_instance_valid(_model):
		_model.free()
	_model = null


## The base model, or null on an assetless checkout (game/assets/converted/ is gitignored,
## see docs/ci.md section 4). Every test below skips rather than fails without it.
func _base_model() -> Node3D:
	var registry := PonyRegistryScript.new()
	registry.load_all("res://data/ponies")
	var data: PonyData = registry.by_id(StockPaletteScript.IDS[0])
	if data == null or not ResourceLoader.exists(data.model_path):
		return null
	return PonyVisualsScript.build(data)


func test_surface_roles_are_matched_by_material_name() -> void:
	assert_eq(StockTintScript.role_of(&"body"), StockTintScript.Role.COAT)
	assert_eq(StockTintScript.role_of(&"wings"), StockTintScript.Role.COAT)
	assert_eq(StockTintScript.role_of(&"hair"), StockTintScript.Role.MANE)
	assert_eq(StockTintScript.role_of(&"tail"), StockTintScript.Role.MANE)
	assert_eq(StockTintScript.role_of(&"eyeball_l"), StockTintScript.Role.EYE)
	assert_eq(StockTintScript.role_of(&"eyeball_r"), StockTintScript.Role.EYE)
	assert_eq(StockTintScript.role_of(&"teeth"), StockTintScript.Role.NONE)
	assert_eq(StockTintScript.role_of(&"horn"), StockTintScript.Role.NONE)


func test_the_tint_lands_on_the_coat_the_mane_and_the_eyes() -> void:
	_model = _base_model()
	if _model == null:
		pass_test("no converted assets on this machine; nothing to tint")
		return
	var coat := Color(0.20, 0.60, 0.95)
	var mane := Color(0.95, 0.35, 0.10)
	var eyes := Color(0.35, 0.80, 0.45)
	var touched: int = StockTintScript.apply_colors(_model, coat, mane, eyes)
	assert_gt(touched, 0, "at least one surface must be recoloured")
	assert_eq(StockTintScript.override_of(_model, &"body").albedo_color, coat)
	assert_eq(StockTintScript.override_of(_model, &"hair").albedo_color, mane)
	assert_eq(StockTintScript.override_of(_model, &"tail").albedo_color, mane)
	assert_eq(StockTintScript.override_of(_model, &"eyeball_l").albedo_color, eyes)


func test_a_coat_override_drops_the_texture_and_keeps_the_normal_map() -> void:
	_model = _base_model()
	if _model == null:
		pass_test("no converted assets on this machine; nothing to tint")
		return
	StockTintScript.apply_colors(_model, Color.RED, Color.BLUE, Color.GREEN)
	var body: StandardMaterial3D = StockTintScript.override_of(_model, &"body")
	assert_null(body.albedo_texture, "the flat coat texture is replaced by a flat colour")
	var eye: StandardMaterial3D = StockTintScript.override_of(_model, &"eyeball_l")
	assert_not_null(eye.albedo_texture, "the eye keeps its iris art and is only modulated")


func test_untinted_surfaces_get_no_override_at_all() -> void:
	_model = _base_model()
	if _model == null:
		pass_test("no converted assets on this machine; nothing to tint")
		return
	StockTintScript.apply_colors(_model, Color.RED, Color.BLUE, Color.GREEN)
	assert_null(StockTintScript.override_of(_model, &"teeth"),
		"a surface with no role is left exactly as the artist made it")


func test_applying_twice_replaces_rather_than_stacks() -> void:
	_model = _base_model()
	if _model == null:
		pass_test("no converted assets on this machine; nothing to tint")
		return
	StockTintScript.apply_colors(_model, Color.RED, Color.BLUE, Color.GREEN)
	StockTintScript.apply_colors(_model, Color.BLACK, Color.WHITE, Color.GRAY)
	assert_eq(StockTintScript.override_of(_model, &"body").albedo_color, Color.BLACK)


func test_apply_reads_the_triple_through_the_palette() -> void:
	_model = _base_model()
	if _model == null:
		pass_test("no converted assets on this machine; nothing to tint")
		return
	var palette: StockPalette = StockPaletteScript.load_stock()
	var triple := {"coat": 1, "mane": 2, "eyes": 0}
	StockTintScript.apply(_model, palette, triple)
	assert_eq(StockTintScript.override_of(_model, &"body").albedo_color, palette.coat_at(1))
	assert_eq(StockTintScript.override_of(_model, &"hair").albedo_color, palette.mane_at(2))


func test_a_null_model_is_refused_rather_than_crashing() -> void:
	assert_eq(StockTintScript.apply_colors(null, Color.RED, Color.BLUE, Color.GREEN), 0)
```

Add to `game/test/test_pony_registry.gd`:

```gdscript
func test_hidden_records_resolve_by_id_and_are_never_listed() -> void:
	var registry := PonyRegistry.new()
	registry.load_all("res://data/ponies")
	for id: StringName in StockPalette.IDS:
		assert_not_null(registry.by_id(id), "%s must resolve for pens, bags and saves" % id)
		assert_false(id in registry.ids(), "%s must not appear in the roster listing" % id)
	for data: PonyData in registry.all():
		assert_false(StockPalette.is_stock_id(data.id), "all() is the collectibles, nothing else")
	assert_eq(registry.by_zone(&"ranch").filter(
		func(d: PonyData) -> bool: return StockPalette.is_stock_id(d.id)).size(), 0,
		"a stock record is zoned nowhere and must never be drawn by a spawn table")


func test_the_collectible_roster_is_still_forty_three() -> void:
	var registry := PonyRegistry.new()
	registry.load_all("res://data/ponies")
	assert_eq(registry.all().size(), 43, "adding hidden records must not change the Compendium")
```

- [ ] **Step 2: Run the tests and watch them fail**

Run: `FILLY_SKIP_SWEEP=1 bash tools/run_tests.sh 2>&1 | tail -40`
Expected: the run fails. `test_stock_palette.gd` and `test_stock_tint.gd` are reported as `Ignoring script ... because it does not extend GutTest` (their preloads do not exist yet), and `tools/run_tests.sh` fails on the script count shortfall regardless of GUT's exit code.

- [ ] **Step 3: Write `game/systems/stock_palette.gd`**

```gdscript
class_name StockPalette
extends Resource
## THE SWATCH ROWS EVERY RECOLOUR IN THE GAME PICKS FROM. One resource class, two
## authored files: game/data/stock_palette.tres is the crowd's palette and
## game/data/player_palette.tres is the wider one the creation screen offers. The
## machinery is identical, which is the point: the player's pony and an unregistered
## stock pony are tinted by exactly the same code (game/systems/stock_tint.gd).
##
## A TRIPLE OF INDICES, NOT THREE COLOURS. What a stock pony carries in her save record
## (PonyInstance.stock) and what the player's look carries (game/systems/player_look.gd)
## are indices into these rows. A colour written into a save would freeze today's palette
## into every old file; an index lets a later authoring pass restyle the whole crowd by
## editing one .tres. The cost is that reordering a row restyles existing ponies, which is
## a trade this project takes knowingly: nothing about a pony's identity lives in her coat.
##
## EVERY LOOKUP WRAPS. coat_at()/mane_at()/eye_at() take posmod of the index, so a hand
## edited save, a shortened row, or an off by one in a menu produces a pony in the wrong
## colour rather than an out of range read. An EMPTY row answers Color.WHITE, so a resource
## that failed to load leaves a white pony standing in the field: visibly wrong, and still
## a pony.

## Where the two shipped palettes live. Committed, unlike game/assets/converted/, so they
## are present on every machine and in every export (docs/ci.md section 4).
const STOCK_PATH := "res://data/stock_palette.tres"
const PLAYER_PATH := "res://data/player_palette.tres"

## The three hidden PonyData records every stock pony is built from, one per personality.
## THREE RECORDS RATHER THAN ONE WITH A PERSONALITY FIELD ON THE INSTANCE, because
## personality is what the capture difficulty and the notice radius are keyed to
## (game/actors/pony/pony.gd, game/actors/player/magic_beam.gd) and both of those read it
## off PonyData. Splitting the record is three small .tres files; threading a per instance
## personality through the beam is a change to the capture code, which this slice has no
## business touching.
const IDS: Array[StringName] = [&"stock_shy", &"stock_bold", &"stock_curious"]

@export var coats: Array[Color] = []
@export var manes: Array[Color] = []
@export var eyes: Array[Color] = []


static func load_stock() -> StockPalette:
	return _load(STOCK_PATH)


static func load_player() -> StockPalette:
	return _load(PLAYER_PATH)


static func _load(path: String) -> StockPalette:
	var res: Resource = load(path)
	if res == null or not (res is StockPalette):
		push_error("StockPalette: '%s' did not load as a StockPalette resource" % path)
		return StockPalette.new()
	return res as StockPalette


## Is `id` one of the three hidden stock records? The one question every caller that has to
## tell a member of the crowd from a collectible asks, in one place.
static func is_stock_id(id: StringName) -> bool:
	return id in IDS


func is_valid() -> bool:
	return not coats.is_empty() and not manes.is_empty() and not eyes.is_empty()


func coat_at(index: int) -> Color:
	return _at(coats, index)


func mane_at(index: int) -> Color:
	return _at(manes, index)


func eye_at(index: int) -> Color:
	return _at(eyes, index)


static func _at(row: Array[Color], index: int) -> Color:
	if row.is_empty():
		return Color.WHITE
	return row[posmod(index, row.size())]


## One pony's whole look, drawn off `rng`. Three numbers pulled in a fixed order, so the
## same seed always produces the same pony and a gate can pin one.
func draw_triple(rng: RandomNumberGenerator) -> Dictionary:
	return {
		"coat": rng.randi_range(0, maxi(0, coats.size() - 1)),
		"mane": rng.randi_range(0, maxi(0, manes.size() - 1)),
		"eyes": rng.randi_range(0, maxi(0, eyes.size() - 1)),
	}
```

- [ ] **Step 4: Write `game/systems/stock_tint.gd`**

```gdscript
class_name StockTint
extends RefCounted
## THE ONE RECOLOUR PIPELINE, WITH TWO USERS: the stock crowd
## (game/world/spawner.gd, game/actors/pony/pony.gd) and the player's own pony
## (game/actors/player/player.gd, built in the creation screen). Both go through
## apply(); there is no second path, and there must never be one.
##
## MATCHED ON THE MATERIAL NAME, NOT ON A SURFACE INDEX. Godot's glTF importer copies each
## glTF material's name into the imported StandardMaterial3D.resource_name, and the base
## model's names are the descriptive ones the artist wrote: `body`, `hair`, `tail`,
## `eyeball_l`, `eyeball_r`. Indices would break the first time a mesh was re-exported with
## its surfaces in another order; a name survives that.
##
## WHY A COAT DROPS ITS TEXTURE AND AN EYE DOES NOT. The base model's body and hair
## textures are flat colour (its body texture is 99.2% one RGB value, the rest being the
## character's own cutie mark), so replacing them with a flat albedo_color loses nothing
## except that mark, which is exactly what an unregistered stock pony should not have. The
## eyeball texture is different: it carries the pupil, the white and the iris, so it is
## KEPT and the swatch modulates it. That means an eye swatch tints the baked iris rather
## than replacing it, and the shipped eye rows are authored against that base. Replacing
## the iris outright is Phase 5's look system.
##
## OVERRIDES, NEVER EDITS. set_surface_override_material() leaves the imported material
## untouched, so two ponies built from the same .glb do not share a recolour; editing the
## material off the mesh would recolour every pony in the world at once, which is the exact
## bug this shape exists to make impossible.
##
## Preloads by path rather than by the global class_name, per the convention at the top of
## game/scripts/pony_rig.gd.

enum Role { NONE, COAT, MANE, EYE }

const COAT_SURFACES: Array[StringName] = [&"body", &"wings"]
const MANE_SURFACES: Array[StringName] = [&"hair", &"tail"]
const EYE_SURFACES: Array[StringName] = [&"eyeball_l", &"eyeball_r"]


static func role_of(material_name: StringName) -> int:
	if material_name in COAT_SURFACES:
		return Role.COAT
	if material_name in MANE_SURFACES:
		return Role.MANE
	if material_name in EYE_SURFACES:
		return Role.EYE
	return Role.NONE


## Recolour `model` in place. Returns how many surfaces were overridden, which is zero for
## a null model and zero for a model whose materials carry none of the names above; both
## are reported by the caller rather than pushed as an error here, because an assetless
## checkout legitimately has neither.
static func apply_colors(model: Node3D, coat: Color, mane: Color, eyes: Color) -> int:
	if model == null:
		return 0
	var touched := 0
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_node: MeshInstance3D = node
		if mesh_node.mesh == null:
			continue
		for i in range(mesh_node.mesh.get_surface_count()):
			var source: Material = mesh_node.get_active_material(i)
			if source == null or not (source is StandardMaterial3D):
				continue
			var role: int = role_of(StringName(source.resource_name))
			if role == Role.NONE:
				continue
			var colour := coat
			if role == Role.MANE:
				colour = mane
			elif role == Role.EYE:
				colour = eyes
			mesh_node.set_surface_override_material(i,
				_tinted(source as StandardMaterial3D, colour, role == Role.EYE))
			touched += 1
	return touched


static func apply(model: Node3D, palette: StockPalette, triple: Dictionary) -> int:
	if palette == null:
		return 0
	return apply_colors(model,
		palette.coat_at(int(triple.get("coat", 0))),
		palette.mane_at(int(triple.get("mane", 0))),
		palette.eye_at(int(triple.get("eyes", 0))))


## The override this pipeline put on the surface named `material_name`, or null if there is
## none. For the tests and the gates, which otherwise have no way to tell "the tint was
## applied" from "the model happened to be that colour already".
static func override_of(model: Node3D, material_name: StringName) -> StandardMaterial3D:
	if model == null:
		return null
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_node: MeshInstance3D = node
		if mesh_node.mesh == null:
			continue
		for i in range(mesh_node.mesh.get_surface_count()):
			var override: Material = mesh_node.get_surface_override_material(i)
			if override == null:
				continue
			if StringName(override.resource_name) == material_name:
				return override as StandardMaterial3D
	return null


## A copy of `source` recoloured to `colour`. The copy keeps the normal map, the cull mode
## and the shading mode, so a tinted pony still lights and silhouettes like the model she
## was built from. `keep_texture` is true only for the eyes; see the class comment.
static func _tinted(source: StandardMaterial3D, colour: Color,
		keep_texture: bool) -> StandardMaterial3D:
	var out: StandardMaterial3D = source.duplicate()
	# Carried through so override_of() can find this material by the name of the surface it
	# replaced; duplicate() copies resource_name already, and this states that it must.
	out.resource_name = source.resource_name
	if not keep_texture:
		out.albedo_texture = null
	out.albedo_color = colour
	return out
```

- [ ] **Step 5: Add the hidden index to `game/systems/pony_registry.gd`**

Add the constant and the second index beside `_by_id`:

```gdscript
## Records that must RESOLVE by id but must never be LISTED. The stock pony base records
## live here (game/systems/stock_palette.gd IDS), and Phase 3 slice 4's talk box NPCs will
## join them. A PonyInstance carrying data_id &"stock_shy" has to reach a real PonyData or
## her pen has no body to build and her save row has no name; and the same record must be
## invisible to the Compendium, to the pause menu's roster page and to every spawn table,
## or the collection quietly grows entries the player can never complete.
##
## Loaded by load_all() from a fixed path rather than from its `dir` argument: the tests
## and the fixtures point `dir` at directories of their own, and a fixture registry that
## silently lost the base records would fail far away from the line that caused it.
const HIDDEN_DIR := "res://data/hidden"

var _hidden: Dictionary = {}  # StringName -> PonyData
```

At the end of `load_all()`, immediately before `return _by_id`:

```gdscript
	_load_hidden()

	return _by_id
```

And the loader plus the changed lookup:

```gdscript
## Fill the hidden index. Missing directory is not an error worth failing a load over: a
## checkout without game/data/hidden/ is a broken checkout, and PonyInstance.data()
## answering null is already a supported answer everywhere it is read.
func _load_hidden() -> void:
	_hidden.clear()
	var da := DirAccess.open(HIDDEN_DIR)
	if da == null:
		return
	da.list_dir_begin()
	var seen := {}
	var file_name := da.get_next()
	while file_name != "":
		if not da.current_is_dir():
			var path := _resource_path(HIDDEN_DIR, file_name)
			if path != "" and not seen.has(path):
				seen[path] = true
				var res: Resource = load(path)
				if res != null and res is PonyDataScript:
					var data: PonyData = res
					_hidden[data.id] = data
				else:
					push_error("PonyRegistry: '%s' did not load as a PonyData resource" % path)
		file_name = da.get_next()
	da.list_dir_end()


## Every hidden id this registry can resolve, in text order, for the gates.
func hidden_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in _hidden.keys():
		out.append(id)
	out.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	return out
```

Change `by_id()` to fall back, keeping its existing doc comment and appending the new paragraph:

```gdscript
## ... existing doc comment ...
##
## HIDDEN RECORDS RESOLVE HERE AND NOWHERE ELSE. See HIDDEN_DIR: the stock pony base
## records answer by_id() so a penned or saved stock pony has a body and a name, and they
## are absent from ids(), all(), by_zone() and by_rarity() so the collection stays the 43
## authored characters.
func by_id(id: StringName) -> PonyData:
	var found: PonyData = _by_id.get(id, null)
	return found if found != null else _hidden.get(id, null)
```

- [ ] **Step 6: Author the three hidden records**

`game/data/hidden/stock_shy.tres`:

```
[gd_resource type="Resource" script_class="PonyData" load_steps=2 format=3]

[ext_resource type="Script" path="res://systems/pony_data.gd" id="1_stock_shy"]

[resource]
script = ExtResource("1_stock_shy")
id = &"stock_shy"
display_name = "Pony"
model_path = "res://assets/converted/ponies/pokeypierce.glb"
rarity = 0
spawn_zones = Array[StringName]([])
favorite_foods = Array[StringName]([&"hay"])
personality = 0
voice_bank = ""
base_speed = 4.0
base_stamina = 1.0
base_spirit = 1.0
phases = Array[int]([])
weathers = Array[int]([])
```

`stock_bold.tres` and `stock_curious.tres` are byte identical except for the `ext_resource` id suffix, the `id` (`&"stock_bold"`, `&"stock_curious"`) and the `personality` (`1` for BOLD, `2` for CURIOUS). `spawn_zones` is deliberately EMPTY: nothing draws a stock pony out of a spawn table, so a stock record zoned anywhere would be a bug waiting to be drawn.

- [ ] **Step 7: Author the two palettes**

`game/data/stock_palette.tres`, eight coats, eight manes, six eyes; every colour a flat, saturated pony colour that reads at distance:

```
[gd_resource type="Resource" script_class="StockPalette" load_steps=2 format=3]

[ext_resource type="Script" path="res://systems/stock_palette.gd" id="1_pal"]

[resource]
script = ExtResource("1_pal")
coats = Array[Color]([Color(0.96, 0.86, 0.62, 1), Color(0.85, 0.62, 0.45, 1), Color(0.62, 0.78, 0.92, 1), Color(0.78, 0.72, 0.90, 1), Color(0.94, 0.74, 0.78, 1), Color(0.72, 0.88, 0.72, 1), Color(0.98, 0.94, 0.88, 1), Color(0.58, 0.56, 0.62, 1)])
manes = Array[Color]([Color(0.32, 0.24, 0.18, 1), Color(0.16, 0.16, 0.22, 1), Color(0.86, 0.72, 0.36, 1), Color(0.68, 0.30, 0.34, 1), Color(0.34, 0.46, 0.68, 1), Color(0.46, 0.34, 0.56, 1), Color(0.90, 0.88, 0.84, 1), Color(0.30, 0.52, 0.42, 1)])
eyes = Array[Color]([Color(0.30, 0.70, 0.85, 1), Color(0.24, 0.52, 0.72, 1), Color(0.28, 0.66, 0.58, 1), Color(0.36, 0.60, 0.44, 1), Color(0.22, 0.40, 0.60, 1), Color(0.32, 0.72, 0.72, 1)])
```

`game/data/player_palette.tres` is the same class with wider rows: sixteen coats, sixteen manes and ten eyes. It contains every colour above plus eight more coats, eight more manes and four more eyes, so the assertion "the player's rows are wider" in `test_stock_palette.gd` is structural rather than incidental. The eye row stays inside the range the base model's iris can be modulated to (see `StockTint`'s class comment): blues, teals, greens and greys, no reds or ambers.

- [ ] **Step 8: Point the player at `by_id`**

In `game/actors/player/player.gd:353-365`, replace the dictionary lookup so hidden records resolve (the player's own model becomes a hidden base record in Task 8; this edit is what makes that possible and is harmless today):

```gdscript
func _build_visuals() -> void:
	var registry := PonyRegistryScript.new()
	registry.load_all(pony_dir)
	# by_id() rather than the dictionary load_all() returns: the player's own record is a
	# HIDDEN one (game/systems/pony_registry.gd HIDDEN_DIR), resolvable by id and absent
	# from every listing, and the returned dictionary is the listing.
	var data: PonyData = registry.by_id(pony_id)
	if data == null:
		push_error("Player: no PonyData with id '%s' in '%s' or in the hidden records"
			% [pony_id, pony_dir])
		return

	var pony: Node3D = PonyVisualsScript.build(data)
```

(the rest of the function is unchanged.)

- [ ] **Step 9: Run the tests and watch them pass**

Run: `bash tools/run_tests.sh 2>&1 | tail -25`
Expected: `---- All tests passed! ----` and exit 0, with the parse sweep reporting every file parsed.

- [ ] **Step 10: Look at the recolour**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/registry_gallery.tscn`
Expected: `REGISTRY_OK ...` unchanged (the gallery lists the roster and the hidden records are not in it).

Then render a sheet by eye. Add a `--stock` argument to `game/scenes/test/model_gallery.gd` that, instead of globbing the directory, builds eight copies of the base model spaced 3 m apart and tints each with `draw_triple` off a fixed seed, so a person can look at the crowd. Note two things about that file before editing it: it is one of the few in the project indented with FOUR SPACES rather than tabs, so match what is already there rather than the snippets below; and it preloads only `PonyRigScript` and `GateWatchdogScript` today, so add `StockPaletteScript`, `StockTintScript`, `PonyRegistryScript` and `PonyVisualsScript` beside them, by `res://` path.

```gdscript
	if "--stock" in OS.get_cmdline_user_args():
		_build_stock_row()
		return
```

```gdscript
## Eight recoloured copies of the base model, for a person to look at. The one thing no
## assertion in this project can answer: whether the crowd looks like ponies or like
## paint chips.
func _build_stock_row() -> void:
	var palette: StockPalette = StockPaletteScript.load_stock()
	var registry := PonyRegistryScript.new()
	registry.load_all("res://data/ponies")
	var data: PonyData = registry.by_id(StockPaletteScript.IDS[0])
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260830
	var built := 0
	for i in 8:
		var body: Node3D = PonyVisualsScript.build(data)
		if body == null:
			continue
		var triple: Dictionary = palette.draw_triple(rng)
		StockTintScript.apply(body, palette, triple)
		body.position = Vector3(built * 3.0, 0.0, 0.0)
		body.rotate_y(PI)
		add_child(body)
		print("STOCK ", triple)
		built += 1
	print("GALLERY_OK count=", built)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if built == 8 else 1)
```

Run: `tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/model_gallery.tscn -- --stock`
Expected: eight `STOCK {...}` lines then `GALLERY_OK count=8`, exit 0. Then run it windowed (no `--headless`) and look at the row: eight ponies of one shape in eight colour schemes, no white ponies, no black manes on black coats.

- [ ] **Step 11: Commit**

```bash
printf 'feat: one recolour pipeline, and the hidden base records behind it\n\nStockPalette holds the swatch rows; StockTint turns a built model plus three\ncolours into per surface material overrides, matched on the imported material\nname. Three hidden PonyData records (one per personality) resolve by id through\nPonyRegistry and are absent from every listing, so the Compendium is still the\n43 authored characters.\n' > /tmp/msg.txt
git add game/systems/stock_palette.gd game/systems/stock_palette.gd.uid \
  game/systems/stock_tint.gd game/systems/stock_tint.gd.uid \
  game/systems/pony_registry.gd game/actors/player/player.gd \
  game/scenes/test/model_gallery.gd \
  game/data/stock_palette.tres game/data/player_palette.tres game/data/hidden \
  game/test/test_stock_palette.gd game/test/test_stock_palette.gd.uid \
  game/test/test_stock_tint.gd game/test/test_stock_tint.gd.uid \
  game/test/test_pony_registry.gd
git commit -F /tmp/msg.txt
```

---

### Task 2: The crowd. Stock spawning, the budget, and the respawn timer

**Files:**
- Modify: `game/world/zone_marker.gd`, `game/systems/region_data.gd`, `game/world/spawner.gd`, `game/actors/pony/pony.gd`, `game/world/ranch.tscn` (the nine `ZoneMarker` nodes), `game/data/regions/*.tres` (four files), `game/world/ranch.gd` (the report, and the respawn tick)
- Test: `game/test/test_spawner.gd`, `game/test/test_pony.gd`, `game/test/test_region_registry.gd`

**Interfaces:**
- Consumes: `StockPalette.IDS`, `StockPalette.load_stock()`, `StockPalette.draw_triple(rng)`, `StockTint.apply(model, palette, triple)`, `PonyRegistry.by_id()` (Task 1).
- Produces:
  - `ZoneMarker` gains `@export var stock_count := 0`.
  - `RegionData` gains `@export var stock_min := 0` and `@export var stock_max := 0`.
  - `Pony` gains `func set_stock(triple: Dictionary) -> void`, `func get_stock() -> Dictionary`, `func is_stock() -> bool`. `set_stock` before `add_child` (like `setup`), and re-tints in place if the visuals are already built.
  - `Spawner` gains `const STOCK_RESPAWN_SECONDS := 45.0`, `const WORLD_PONY_BUDGET := 60`, `func stock_budget(marker: ZoneMarker) -> int`, `func tick_stock(delta: float) -> int` (returns how many arrived), `func stock_standing() -> int`, `func named_standing() -> int`. `populate()` and `refresh()` keep their existing signatures and return shapes; `populate()` additionally fills each marker's stock budget, and `refresh()` leaves stock alone (stock keeps no hours).

**The numbers, and where they come from.** The spec's pacing rule is that named ponies are at most one in five wild spawns in the ranch region and rarer beyond it. Today `ranch.tscn` stands 22 named ponies (five ranch markers at `spawn_count = 2`, four region markers at `spawn_count = 3`). This task retunes to:

| marker | `spawn_count` | `stock_count` | named share |
|---|---|---|---|
| the five `ranch` markers | 1 (was 2) | 4 | 5 of 25, exactly 1 in 5 |
| `orchard`, `everfree`, `lake`, `nightmeadow` | 1 (was 3) | 5 | 1 of 6, rarer than the ranch |

Nine named ponies and forty stock ponies stand on the shipped map: 49 bodies, against a `WORLD_PONY_BUDGET` of 60. Every region `.tres` gets `stock_min = 4` and `stock_max = 8`, which is the band `stock_budget()` clamps a marker's authored count into, so a region's data file is the authority on how crowded it may be. The `ranch` zone has no `RegionData` (it is the open homestead, behind no permit and inside no fence), so its markers use `stock_count` unclamped.

**Consequences to carry through, in this task, not later.** `RANCH_OK ponies=22` becomes `ponies=49`; `docs/testing.md`'s ranch gate line, the world gate's expectation, and `game/scenes/test/wild_ponies.gd` all name counts and must be re-measured and updated. `_report()`'s `expected_ponies` must add `marker.stock_count`.

- [ ] **Step 1: Write the failing tests**

Add to `game/test/test_spawner.gd` (the file already builds a `Spawner` over two `ZoneMarker`s on a floor with a fixture roster; reuse that harness verbatim and give the markers a `stock_count`):

```gdscript
func test_a_marker_stands_its_whole_stock_budget() -> void:
	var world := _build_world(2, 3)  # two markers, spawn_count 2 each; helper already here
	for marker: ZoneMarker in world.spawner.get_markers():
		marker.stock_count = 3
	world.spawner.populate(WorldStateScript.Phase.DAY, WorldStateScript.Weather.CLEAR)
	assert_eq(world.spawner.stock_standing(), 6, "three stock per marker, two markers")
	assert_eq(world.spawner.named_standing(), 4, "the named draw is untouched by stock")


func test_stock_ponies_may_stand_twice_but_named_ponies_may_not() -> void:
	var world := _build_world(2, 1)
	for marker: ZoneMarker in world.spawner.get_markers():
		marker.stock_count = 4
	world.spawner.populate(WorldStateScript.Phase.DAY, WorldStateScript.Weather.CLEAR)
	var counts := {}
	for pony in world.spawner.get_spawned():
		var data: PonyData = pony.get_data()
		counts[data.id] = int(counts.get(data.id, 0)) + 1
	for id in counts:
		if StockPalette.is_stock_id(id):
			continue
		assert_eq(int(counts[id]), 1, "a named character stands in exactly one place")
	assert_gt(world.spawner.stock_standing(), 3, "the crowd is allowed to repeat itself")


func test_every_stock_pony_carries_a_palette_triple() -> void:
	var world := _build_world(1, 1)
	world.spawner.get_markers()[0].stock_count = 5
	world.spawner.populate(WorldStateScript.Phase.DAY, WorldStateScript.Weather.CLEAR)
	var seen_triples := {}
	for pony in world.spawner.get_spawned():
		if not pony.is_stock():
			continue
		var triple: Dictionary = pony.get_stock()
		assert_true(triple.has("coat") and triple.has("mane") and triple.has("eyes"),
			"a stock pony's look is a coat, a mane and a pair of eyes")
		seen_triples[str(triple)] = true
	assert_gt(seen_triples.size(), 1, "five stock ponies are not five copies of one pony")


func test_the_stock_draw_is_deterministic_for_a_seed() -> void:
	var first: Array = _stock_signature(_build_world(1, 1))
	var second: Array = _stock_signature(_build_world(1, 1))
	assert_eq(first, second, "the same world seed stands the same crowd")


func test_a_marker_budget_is_clamped_into_its_region_band() -> void:
	var world := _build_world(1, 1)
	var marker: ZoneMarker = world.spawner.get_markers()[0]
	marker.zone_id = &"orchard"
	marker.stock_count = 99
	var region: RegionData = RegionRegistry.new().load_all().get(&"orchard")
	assert_eq(world.spawner.stock_budget(marker), region.stock_max,
		"a region's data file caps how crowded it may be")
	marker.stock_count = 0
	assert_eq(world.spawner.stock_budget(marker), region.stock_min,
		"and how empty")


func test_a_marker_outside_every_region_uses_its_own_count() -> void:
	var world := _build_world(1, 1)
	var marker: ZoneMarker = world.spawner.get_markers()[0]
	marker.zone_id = &"ranch"
	marker.stock_count = 4
	assert_eq(world.spawner.stock_budget(marker), 4, "the homestead is behind no permit")


func test_stock_respawns_on_a_timer_after_one_is_taken() -> void:
	var world := _build_world(1, 1)
	world.spawner.get_markers()[0].stock_count = 3
	world.spawner.populate(WorldStateScript.Phase.DAY, WorldStateScript.Weather.CLEAR)
	assert_eq(world.spawner.stock_standing(), 3)
	var victim: CharacterBody3D = null
	for pony in world.spawner.get_spawned():
		if pony.is_stock():
			victim = pony
			break
	victim.free()
	assert_eq(world.spawner.stock_standing(), 2, "a freed body leaves the tally at once")
	assert_eq(world.spawner.tick_stock(SpawnerScript.STOCK_RESPAWN_SECONDS * 0.5), 0,
		"half the timer buys nothing")
	assert_eq(world.spawner.tick_stock(SpawnerScript.STOCK_RESPAWN_SECONDS * 0.6), 1,
		"and the rest of it brings one back")
	assert_eq(world.spawner.stock_standing(), 3)


func test_a_full_marker_never_respawns() -> void:
	var world := _build_world(1, 1)
	world.spawner.get_markers()[0].stock_count = 2
	world.spawner.populate(WorldStateScript.Phase.DAY, WorldStateScript.Weather.CLEAR)
	assert_eq(world.spawner.tick_stock(SpawnerScript.STOCK_RESPAWN_SECONDS * 10.0), 0,
		"a field that is already full stays as it is")


func test_a_change_of_sky_does_not_move_the_crowd() -> void:
	var world := _build_world(1, 1)
	world.spawner.get_markers()[0].stock_count = 4
	world.spawner.populate(WorldStateScript.Phase.DAY, WorldStateScript.Weather.CLEAR)
	var before: int = world.spawner.stock_standing()
	world.spawner.refresh(WorldStateScript.Phase.NIGHT, WorldStateScript.Weather.STORM, 0,
		Vector3(500.0, 0.0, 500.0))
	assert_eq(world.spawner.stock_standing(), before, "stock ponies keep no hours")
```

Add to `game/test/test_pony.gd`:

```gdscript
func test_a_pony_told_she_is_stock_carries_the_triple_and_reads_back() -> void:
	var pony: Pony = PonyScene.instantiate()
	pony.set_stock({"coat": 2, "mane": 5, "eyes": 1})
	assert_true(pony.is_stock())
	assert_eq(pony.get_stock(), {"coat": 2, "mane": 5, "eyes": 1})
	pony.free()


func test_a_named_pony_is_not_stock() -> void:
	var pony: Pony = PonyScene.instantiate()
	assert_false(pony.is_stock())
	assert_eq(pony.get_stock(), {})
	pony.free()
```

Add to `game/test/test_region_registry.gd`:

```gdscript
func test_every_shipped_region_declares_a_stock_band() -> void:
	var registry := RegionRegistry.new()
	registry.load_all()
	for region: RegionData in registry.all():
		assert_gt(region.stock_max, 0, "%s must say how many stock ponies it holds" % region.id)
		assert_true(region.stock_min <= region.stock_max,
			"%s has an inverted stock band" % region.id)
```

- [ ] **Step 2: Run the tests and watch them fail**

Run: `FILLY_SKIP_SWEEP=1 bash tools/run_tests.sh 2>&1 | tail -40`
Expected: failures naming `stock_standing`, `stock_budget`, `tick_stock`, `set_stock` and `stock_max` as missing.

- [ ] **Step 3: Add the two exports**

`game/world/zone_marker.gd`, in the `Zone` export group under `spawn_count`:

```gdscript
## How many STOCK ponies stand here, on top of `spawn_count` named ones. The crowd the
## named characters hide in (docs/superpowers/specs/2026-08-30-phase3-rainbow-factory-design.md,
## "Stock ponies"). Clamped into the zone's RegionData band by Spawner.stock_budget(); a
## marker in the open homestead, which is behind no permit and inside no fence and so has no
## RegionData, uses this number as it stands.
@export var stock_count := 0
```

`game/systems/region_data.gd`, under `lake_depth`:

```gdscript
## How crowded this region may be with STOCK ponies: the band a ZoneMarker's own
## `stock_count` is clamped into. Authored here rather than only on the marker so the
## region's data file stays the authority on its own population, the way `permit_cost` is
## the authority on its price.
@export var stock_min := 0
@export var stock_max := 0
```

Then edit the four files in `game/data/regions/` to add `stock_min = 4` and `stock_max = 8`.

- [ ] **Step 4: Teach `Pony` about a palette triple**

In `game/actors/pony/pony.gd`, beside `_data`:

```gdscript
## Her palette triple if she is one of the crowd, or {} if she is a named character.
## `{"coat": int, "mane": int, "eyes": int}`, indices into game/data/stock_palette.tres.
##
## ON THE BODY AS WELL AS ON THE RECORD. A WILD stock pony has no PonyInstance at all (an
## individual identity is a thing a pony acquires by being caught), so the only place her
## look can live before she is caught is here; MagicBeam copies it onto the instance it
## mints (see _settle_pony). A penned pony comes the other way, through adopt().
var _stock: Dictionary = {}
```

and the three methods, placed next to `setup()`:

```gdscript
## Give her a stock pony's look. Call BEFORE add_child, the same rule setup() states, or
## call it afterwards and the tint is applied to the body she already has.
func set_stock(triple: Dictionary) -> void:
	_stock = triple.duplicate()
	if is_node_ready():
		_apply_stock_tint()


func get_stock() -> Dictionary:
	return _stock.duplicate()


func is_stock() -> bool:
	return not _stock.is_empty()


## Recolour the built body from _stock. A no op for a named character and for a body that
## failed to build, both of which are ordinary states rather than errors.
func _apply_stock_tint() -> void:
	if _stock.is_empty() or visuals.get_child_count() == 0:
		return
	var body: Node3D = visuals.get_child(0)
	StockTintScript.apply(body, StockPaletteScript.load_stock(), _stock)
```

Add the two preloads at the top with the others, and call `_apply_stock_tint()` as the last line of `_apply_data()` (after `_play(&"idle")`). Extend `adopt()` so a penned stock pony gets her look back:

```gdscript
func adopt(instance: PonyInstance) -> void:
	_instance = instance
	if instance == null:
		return
	# Her look comes back with her record, so a pony let out of a pen is the same pony the
	# player put in it rather than a differently coloured stranger with the same uid.
	if not instance.stock.is_empty():
		_stock = instance.stock.duplicate()
	setup(instance.data())
```

**Do not make that `adopt()` edit in this task.** `PonyInstance.stock` does not exist until Task 3, which repeats the whole function and makes the edit there. In THIS task `adopt()` is left exactly as it is, and the only thing that ever calls `set_stock()` is the spawner.

- [ ] **Step 5: Stock spawning in `game/world/spawner.gd`**

Add the constants and state:

```gdscript
## Real seconds a marker waits before standing a replacement for a stock pony who was
## caught, delivered or otherwise left. Long enough that emptying a field feels like an
## achievement for the length of a walk back to the pens, short enough that the field is
## full again by the next visit. THE WILD MUST NEVER RUN DRY: this timer is the whole of
## the spec's repeatability promise.
const STOCK_RESPAWN_SECONDS := 45.0

## The most pony bodies this spawner will ever have standing at once, named and stock
## together. A ceiling rather than a target: it is what stops a future retune of
## stock_count from quietly tripling the frame cost, and ranch.gd's report fails on a world
## that exceeds it.
const WORLD_PONY_BUDGET := 60

## Seconds a marker has been short of its stock budget, keyed by marker instance id. Reset
## the moment a replacement is stood.
var _stock_wait: Dictionary = {}

## Loaded once. Null only until the first stock pony is stood.
var _palette: StockPalette = null
var _regions: RegionRegistry = null
```

The budget:

```gdscript
## How many stock ponies belong at `marker`: its own `stock_count`, clamped into its
## region's authored band. A marker whose zone has no RegionData (the open homestead) uses
## its own number as it stands.
func stock_budget(marker: ZoneMarker) -> int:
	if marker == null:
		return 0
	if _regions == null:
		_regions = RegionRegistryScript.new()
		_regions.load_all()
	var region: RegionData = _regions.by_id(marker.zone_id)
	if region == null:
		return maxi(0, marker.stock_count)
	return clampi(marker.stock_count, region.stock_min, region.stock_max)
```

The tallies, which every caller and every gate reads rather than counting for itself:

```gdscript
func stock_standing() -> int:
	var n := 0
	for pony in get_spawned():
		if pony.is_stock() and not pony.is_leaving():
			n += 1
	return n


func named_standing() -> int:
	var n := 0
	for pony in get_spawned():
		if not pony.is_stock() and not pony.is_leaving():
			n += 1
	return n
```

One stock pony, and the fill. `_spawn_one()` already does the placement, the collision layers and the seeded per pony RNG, so this reuses it rather than repeating it:

```gdscript
## Stand one stock pony at `marker`. Her personality is one of the three hidden base
## records and her colours are a palette triple, both drawn off `rng`, so a seed produces
## the same crowd every time.
func _spawn_stock(marker: ZoneMarker, slot: int, rng: RandomNumberGenerator) -> CharacterBody3D:
	if _palette == null:
		_palette = StockPaletteScript.load_stock()
	var id: StringName = StockPaletteScript.IDS[rng.randi_range(0,
		StockPaletteScript.IDS.size() - 1)]
	var triple: Dictionary = _palette.draw_triple(rng)
	var data: PonyData = _registry_for_stock().by_id(id)
	if data == null or data.model_path.is_empty() or not ResourceLoader.exists(data.model_path):
		# The assetless checkout (docs/ci.md section 4). One calm skip, not a push_error per
		# pony per marker; ranch.gd's report already says assets=absent at the top.
		return null
	var pony: CharacterBody3D = _spawn_one(data, marker, slot)
	if pony != null:
		pony.set_stock(triple)
	return pony


## The registry hidden records resolve through. Loaded once and kept, like _entries.
func _registry_for_stock() -> PonyRegistry:
	if _stock_registry == null:
		_stock_registry = PonyRegistryScript.new()
		_stock_registry.load_all(pony_dir)
	return _stock_registry
```

with `var _stock_registry: PonyRegistry = null` beside the other state. `_spawn_one` sets `pony.set_stock` AFTER `add_child` and `setup()`, which is why `set_stock` re-tints in place.

At the end of `populate()`, after `_next_slot = slot` and before `return`:

```gdscript
	slot = _fill_stock(slot)
	_next_slot = slot
	return _spawned.size()
```

```gdscript
## Top every marker up to its stock budget. Returns the next free slot number.
##
## THE CROWD IS ALLOWED TO REPEAT ITSELF. The map wide no duplicates rule exists so that
## seeing a named character is an event (game/world/spawner.gd's refresh() comment); two
## stock ponies of the same personality standing in one field is not a duplicate, it is a
## field with two ponies in it, which is the entire point of the crowd.
func _fill_stock(from_slot: int) -> int:
	var slot := from_slot
	for marker: ZoneMarker in get_markers():
		var want: int = stock_budget(marker) - _stock_at(marker)
		if want <= 0:
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = spawn_seed * 131 + marker.get_instance_id() % 100003
		for i in range(want):
			if _spawned.size() >= WORLD_PONY_BUDGET:
				break
			var pony := _spawn_stock(marker, slot, rng)
			if pony != null:
				_spawned.append(pony)
				_marker_by_pony[pony.get_instance_id()] = marker
			slot += 1
	return slot


## How many stock ponies are standing at `marker` and staying.
func _stock_at(marker: ZoneMarker) -> int:
	var n := 0
	for pony in get_spawned():
		if not pony.is_stock() or pony.is_leaving():
			continue
		if _marker_by_pony.get(pony.get_instance_id()) == marker:
			n += 1
	return n
```

The respawn timer:

```gdscript
## THE FIELD FILLS ITSELF BACK UP. Called every physics frame by ranch.gd while somebody is
## playing, and directly by the tests and the gates. A marker that is short of its budget
## banks `delta`; once it has banked STOCK_RESPAWN_SECONDS it stands ONE replacement and
## starts again, so emptying a field of four takes four waits rather than one. A marker at
## its budget banks nothing, so the timer never runs ahead of the need for it.
##
## Returns how many arrived, which is what a caller puts in a report line.
func tick_stock(delta: float) -> int:
	if delta <= 0.0:
		return 0
	var arrived := 0
	var slot := _next_slot
	for marker: ZoneMarker in get_markers():
		var key := marker.get_instance_id()
		if stock_budget(marker) - _stock_at(marker) <= 0:
			_stock_wait[key] = 0.0
			continue
		var waited: float = float(_stock_wait.get(key, 0.0)) + delta
		if waited < STOCK_RESPAWN_SECONDS:
			_stock_wait[key] = waited
			continue
		_stock_wait[key] = 0.0
		if _spawned.size() >= WORLD_PONY_BUDGET:
			continue
		var rng := RandomNumberGenerator.new()
		# The slot number is in the seed, so consecutive replacements at one marker are not
		# the same pony over and over.
		rng.seed = spawn_seed * 131 + key % 100003 + slot * 7919
		var pony := _spawn_stock(marker, slot, rng)
		slot += 1
		if pony != null:
			_spawned.append(pony)
			_marker_by_pony[pony.get_instance_id()] = marker
			arrived += 1
	_next_slot = slot
	return arrived
```

`refresh()` is NOT changed: it iterates `get_spawned()` and asks each pony's `get_data().available(phase, weather)`, and the hidden stock records carry empty `phases` and `weathers`, so `available()` is true at every hour and no stock pony is ever told to leave by a change of sky. Add one line to its doc comment saying so.

- [ ] **Step 6: Retune the markers and wire the tick**

In `game/world/ranch.tscn`, set `spawn_count = 1` on all nine `ZoneMarker` nodes, `stock_count = 4` on the five `ranch` markers and `stock_count = 5` on the four region markers.

In `game/world/ranch.gd`, inside `_physics_process`, immediately after the `if not _interactive: return` guard:

```gdscript
	# The wild refills itself while somebody is playing. Not while a gate is driving the
	# scene: a gate that teleports the player about for two hundred frames would otherwise
	# stand a fresh crowd behind it, and the pony count it is asserting on would move under
	# it. The gates call spawner.tick_stock() themselves, deliberately, where they mean to.
	spawner.tick_stock(delta)
```

In `_report()`, change the expectation and add the two new checks:

```gdscript
	var expected_ponies := 0
	for marker in spawner.get_markers():
		expected_ponies += marker.spawn_count + spawner.stock_budget(marker)
```

and, next to the existing pony checks:

```gdscript
	print("RANCH crowd named=%d stock=%d budget=%d" % [
		spawner.named_standing(), spawner.stock_standing(), spawner.WORLD_PONY_BUDGET])
	_set_check(checks, "the world stays inside its pony budget",
		ponies.size() <= spawner.WORLD_PONY_BUDGET)
	# The spec's pacing rule, asserted rather than hoped for: a named pony is at most one in
	# five of what is standing in the homestead, so finding one takes minutes.
	var ranch_named := 0
	var ranch_stock := 0
	for marker in spawner.get_markers():
		if marker.zone_id != &"ranch":
			continue
		ranch_named += marker.spawn_count
		ranch_stock += spawner.stock_budget(marker)
	_set_check(checks, "named ponies are at most one in five of the homestead crowd",
		ranch_stock >= ranch_named * 4)
```

- [ ] **Step 7: Run the tests and the gates**

Run: `bash tools/run_tests.sh 2>&1 | tail -25`
Expected: `---- All tests passed! ----`, exit 0.

Run: `tools/bin/godot --headless --audio-driver Dummy --path game world/ranch.tscn`
Expected: `RANCH crowd named=9 stock=40 budget=60` and `RANCH_OK ponies=49 props=58 assets=present`, exit 0.

Run each of the four hosted gates and re-measure any count they name:
```
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/market_test.tscn
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/region_test.tscn
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/world_test.tscn
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/collection_test.tscn
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/wild_ponies.tscn
```
Expected: `MARKET_OK`, `REGION_OK`, `WORLD_OK`, `COLLECTION_OK`, `WILD_OK` (or the marker each prints), all exit 0. `collection_test.gd`'s `EXPECTED_EXTRA_NIGHTS` is a MEASURED number printed beside the real one; if the printed `extra=` has moved because a region marker now holds one named slot instead of three, update the constant and its comment in the same commit and say what moved it.

- [ ] **Step 8: Commit**

```bash
printf 'feat: the crowd; stock ponies fill the world and respawn on a timer\n\nZoneMarker gains stock_count and RegionData gains a stock band it is clamped\ninto. The spawner stands the crowd in populate() and refills a short marker in\ntick_stock(). Named counts drop to one per marker, so a named pony is one in\nfive of the homestead and rarer beyond it; 49 bodies stand on the map against a\nbudget of 60.\n' > /tmp/msg.txt
git add game/world/zone_marker.gd game/world/spawner.gd game/world/ranch.gd \
  game/world/ranch.tscn game/systems/region_data.gd game/data/regions \
  game/actors/pony/pony.gd game/test/test_spawner.gd game/test/test_pony.gd \
  game/test/test_region_registry.gd game/scenes/test/collection_test.gd
git commit -F /tmp/msg.txt
```

---

### Task 3: A stock pony you own. `PonyInstance.stock`, capture, pens and the save

**Files:**
- Modify: `game/systems/pony_instance.gd`, `game/actors/player/magic_beam.gd:1445-1466` (`_settle_pony`), `game/actors/pony/pony.gd` (`adopt`), `game/world/ranch.gd` (`_on_pony_captured`)
- Test: `game/test/test_pony_instance.gd`, `game/test/test_magic_beam.gd`, `game/test/test_pen.gd`, `game/test/test_save_io.gd`

**Interfaces:**
- Consumes: `Pony.get_stock()`, `Pony.set_stock()`, `Pony.is_stock()`, `StockPalette.is_stock_id()` (Tasks 1 and 2).
- Produces: `PonyInstance` gains `var stock: Dictionary = {}` and `func is_stock() -> bool`, both round tripped through `to_dict()`/`from_dict()` under the key `"stock"`. No save version bump: a missing `"stock"` key defaults to `{}`, which is what every pre Phase 3 record is.

**Why this is not part of Task 2.** Task 2 puts stock ponies in the field. This one makes a caught stock pony a real, saved, penned individual whose colours come back after a reload. They fail separately and a reviewer can reject either without the other.

- [ ] **Step 1: Write the failing tests**

Add to `game/test/test_pony_instance.gd`:

```gdscript
func test_a_new_instance_is_not_stock() -> void:
	var inst := PonyInstance.create(&"twilight")
	assert_eq(inst.stock, {})
	assert_false(inst.is_stock())


func test_a_palette_triple_round_trips_through_the_dictionary() -> void:
	var inst := PonyInstance.create(&"stock_shy")
	inst.stock = {"coat": 3, "mane": 6, "eyes": 2}
	var back := PonyInstance.from_dict(inst.to_dict())
	assert_eq(back.stock, {"coat": 3, "mane": 6, "eyes": 2})
	assert_true(back.is_stock())


func test_a_record_written_before_phase_three_loads_as_a_named_pony() -> void:
	var old := {"uid": "twilight#000004", "data_id": "twilight", "nickname": "",
		"happiness": 0.5, "hunger": 0.0, "caught_at_ms": 0, "home_slot": ""}
	var inst := PonyInstance.from_dict(old)
	assert_eq(inst.stock, {}, "a missing stock key is a named pony, not a broken one")
	assert_false(inst.is_stock())


func test_a_junk_stock_value_is_dropped_rather_than_stored() -> void:
	var inst := PonyInstance.from_dict({"data_id": "stock_bold", "stock": "purple"})
	assert_eq(inst.stock, {}, "a hand edited blob must not fabricate a look")


func test_stock_indices_are_coerced_to_ints() -> void:
	# JSON has no integer type: every number comes back off disk as a float.
	var inst := PonyInstance.from_dict({"data_id": "stock_bold",
		"stock": {"coat": 2.0, "mane": 4.0, "eyes": 1.0}})
	assert_eq(inst.stock, {"coat": 2, "mane": 4, "eyes": 1})
	assert_eq(typeof(inst.stock["coat"]), TYPE_INT)
```

Add to `game/test/test_magic_beam.gd`:

```gdscript
func test_catching_a_stock_pony_carries_her_colours_onto_her_record() -> void:
	var beam: MagicBeam = _beam()  # the file's existing helper
	var pony: Pony = PonyScene.instantiate()
	pony.set_stock({"coat": 1, "mane": 7, "eyes": 3})
	add_child_autofree(pony)
	pony.setup(_stock_data())  # a hidden record, resolved through PonyRegistry.by_id
	beam._settle_pony(pony)
	var stored: PonyInstance = beam.get_storage().contents()[0]
	assert_eq(stored.stock, {"coat": 1, "mane": 7, "eyes": 3},
		"her look is minted with her uid, or a caught stock pony is a stranger on reload")


func test_catching_a_named_pony_leaves_her_stock_empty() -> void:
	var beam: MagicBeam = _beam()
	var pony: Pony = PonyScene.instantiate()
	add_child_autofree(pony)
	pony.setup(_named_data())
	beam._settle_pony(pony)
	assert_eq(beam.get_storage().contents()[0].stock, {})
```

Add to `game/test/test_pen.gd`:

```gdscript
func test_a_penned_stock_pony_keeps_her_colours() -> void:
	var pen: Pen = _pen(3)  # the file's existing helper
	var inst := PonyInstance.create(&"stock_curious")
	inst.stock = {"coat": 4, "mane": 1, "eyes": 0}
	assert_true(pen.add_pony(inst))
	var body: Node3D = pen.body_for(inst.uid)
	assert_not_null(body, "a resident has a body standing in the pen")
	assert_eq(body.get_stock(), {"coat": 4, "mane": 1, "eyes": 0},
		"the body wears what her record says")
```

Add to `game/test/test_save_io.gd`:

```gdscript
func test_a_stock_pony_survives_a_whole_save_round_trip() -> void:
	var inst := PonyInstance.create(&"stock_shy")
	inst.stock = {"coat": 5, "mane": 2, "eyes": 4}
	inst.home_slot = &"plot_a"
	assert_true(SaveIO.save(_slot, {"ponies": [inst.to_dict()]}))
	var loaded := SaveIO.load(_slot)
	var back := PonyInstance.from_dict(loaded["ponies"][0])
	assert_eq(back.stock, {"coat": 5, "mane": 2, "eyes": 4})
	assert_eq(back.data_id, &"stock_shy")
	assert_eq(back.home_slot, &"plot_a")
```

- [ ] **Step 2: Run the tests and watch them fail**

Run: `FILLY_SKIP_SWEEP=1 bash tools/run_tests.sh 2>&1 | tail -40`
Expected: failures naming `stock` as an invalid property of `PonyInstance`.

- [ ] **Step 3: Add the field to `game/systems/pony_instance.gd`**

Beside `home_slot`:

```gdscript
## HER LOOK, if she is one of the crowd: `{"coat": int, "mane": int, "eyes": int}`, indices
## into game/data/stock_palette.tres. EMPTY for a named character, whose look is her model.
##
## ON THE INDIVIDUAL AND NOT ON THE CHARACTER, because that is the whole difference between
## a stock pony and a named one: two ponies of the same character are the same colours, and
## two stock ponies of the same hidden base record are not. Her three indices are the only
## thing that makes her her, so they ride in her own record beside her uid and her hunger,
## and a traded blob carries her colours with her.
##
## INDICES RATHER THAN COLOURS, for the reason StockPalette's class comment gives: a colour
## written into a save freezes today's palette into every old file.
var stock: Dictionary = {}
```

The reader, next to `display_name()`:

```gdscript
## Is she one of the crowd? Asked of her LOOK rather than of her data_id, because the look
## is what the save carries and the id is what a build's roster happens to hold: a record
## whose data_id this build has never heard of still resolves to null and still has to know
## whether to be tinted.
func is_stock() -> bool:
	return not stock.is_empty()
```

In `to_dict()`, add `"stock": stock.duplicate(),` after `"home_slot"`.

In `from_dict()`, after the `home_slot` line:

```gdscript
	# JSON has no integer type, so every index comes back as a float and is int()ed; and a
	# value that is not a dictionary of three numbers is DROPPED rather than kept, so a hand
	# edited blob cannot fabricate a look this class would not have written.
	inst.stock = {}
	var saved_stock: Variant = d.get("stock", {})
	if typeof(saved_stock) == TYPE_DICTIONARY:
		var triple: Dictionary = saved_stock
		var ok := true
		for key in ["coat", "mane", "eyes"]:
			var raw: Variant = triple.get(key, null)
			if typeof(raw) != TYPE_INT and typeof(raw) != TYPE_FLOAT:
				ok = false
				break
		if ok:
			inst.stock = {
				"coat": int(triple["coat"]),
				"mane": int(triple["mane"]),
				"eyes": int(triple["eyes"]),
			}
	return inst
```

- [ ] **Step 4: Carry the look from the body to the record**

In `game/actors/player/magic_beam.gd`, inside `_settle_pony`, immediately after the mint:

```gdscript
		instance = PonyInstanceScript.create(
			data.id, int(Time.get_unix_time_from_system() * 1000.0))
		# HER COLOURS COME OFF HER BODY. A wild stock pony has no record until this moment,
		# so the body the spawner tinted is the only thing that knows what she looks like;
		# minting without this makes every caught stock pony a differently coloured stranger
		# the next time she is stood up out of a pen.
		if pony.has_method("get_stock"):
			instance.stock = pony.get_stock()
```

`has_method` rather than a type check for the reason the file already gives elsewhere: the beam is handed bodies by tests that are not full `Pony` scenes.

- [ ] **Step 5: Carry the look from the record back to the body**

In `game/actors/pony/pony.gd`, `adopt()`:

```gdscript
func adopt(instance: PonyInstance) -> void:
	_instance = instance
	if instance == null:
		return
	# Her look comes back with her record, so a pony stood up out of a pen after a reload is
	# the same pony the player put in it rather than a stranger with the same uid.
	if not instance.stock.is_empty():
		_stock = instance.stock.duplicate()
	setup(instance.data())
```

- [ ] **Step 6: Keep stock ponies out of the Compendium**

In `game/world/ranch.gd`, `_on_pony_captured`:

```gdscript
func _on_pony_captured(instance: PonyInstance) -> void:
	if instance == null or _game_state == null:
		return
	# THE CROWD IS NOT COLLECTED. A stock pony has no Compendium entry and no request ever
	# names one: she is supply, not a character. Marking her would put an id in the book
	# that no page can ever show and no count can ever include.
	if instance.is_stock():
		return
	_game_state.compendium.mark_caught(instance.data_id)
	if _board == null:
		return
	var here: RegionData = _regions_registry().region_at(
		Vector2(player.global_position.x, player.global_position.z))
	var zone: StringName = here.id if here != null else &"ranch"
	_pay_out(_board.on_caught(instance.data(), zone))
```

- [ ] **Step 7: Run the tests and the gates**

Run: `bash tools/run_tests.sh 2>&1 | tail -25`
Expected: `---- All tests passed! ----`, exit 0.

Run: `tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/capture_test.tscn`
Expected: `CAPTURE_OK ...`, exit 0.

Run: `tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/collection_test.tscn`
Expected: `COLLECTION_OK checks=72` (or a higher count if the file grew in Task 2), exit 0. The gate catches a pony picked out of the live herd; with the crowd standing it may now pick a stock pony, and the check that catching her marks her CAUGHT would then be wrong. If it does, change the gate's pony picker to skip `pony.is_stock()` bodies and say so in the commit.

- [ ] **Step 8: Commit**

```bash
printf 'feat: a stock pony you own; her colours ride in her own record\n\nPonyInstance gains stock, the palette triple, saved and round tripped with a\nmissing key defaulting to a named pony. The beam copies it off the body it is\nminting from and adopt() puts it back on the body a pen stands up. Stock ponies\nare never marked in the Compendium.\n' > /tmp/msg.txt
git add game/systems/pony_instance.gd game/actors/player/magic_beam.gd \
  game/actors/pony/pony.gd game/world/ranch.gd \
  game/test/test_pony_instance.gd game/test/test_magic_beam.gd \
  game/test/test_pen.gd game/test/test_save_io.gd
git commit -F /tmp/msg.txt
```

---

### Task 4: The Ledger, and save format version 5

**Files:**
- Create: `game/systems/ledger.gd`
- Modify: `game/systems/game_state.gd`, `game/systems/save_io.gd`
- Test: `game/test/test_ledger.gd`, `game/test/test_game_state.gd`, `game/test/test_save_io.gd`

**Interfaces:**
- Consumes: `Economy.GEM_VALUE_BY_RARITY`, `PonyData.Rarity`, `WorldState.cycle_index()`.
- Produces:
  - `class_name Ledger extends RefCounted`. `enum Punishment { NONE, FEE, PERMIT_REVOKED, PEN_PADLOCKED, BEAM_RECALLED }`; `const LADDER: Array[int]` in that order. Constants `STARTING_BALANCE := 25000`, `PERIOD_CYCLES := 3`, `STARTING_QUOTA := 2`, `CEILING := 40000`, `PRINCIPAL_FLOOR := 5000`, `UPKEEP_BASE := 1800`, `UPKEEP_PER_PLOT := 350`, `UPKEEP_PER_PERMIT := 450`, `INTEREST_RATE := 0.04`, `MIN_SERVICE_CHARGE := 25`, `DELIVERY_CREDIT_STOCK := 300`, `DELIVERY_NAMED_MULTIPLIER := 40`, `COLLECTOR_FEE := 500`, `BEAM_RECALL_CYCLES := 1`.
  - `signal changed(balance: int)`, `signal collection_day(summary: Dictionary)`.
  - Fields `balance: int`, `quota: int`, `delivered_this_period: int`, `periods_run: int`, `shipments: int`, `tier: int`, `pending_punishment: int`, `revoked_permits: Array`, `padlocked_slots: Array`, `beam_recalled_until: int`.
  - `static func period_of(cycle: int) -> int`, `static func is_collection_cycle(cycle: int) -> bool`, `static func delivery_credit(rarity: int, is_stock: bool) -> int`.
  - `func upkeep_for(built_plots: int, open_permits: int, rank_multiplier: float = 1.0) -> int`, `func service_charge() -> int`, `func payable() -> int`, `func run_collection_day(cycle: int, built_plots: int, open_permits: int) -> Dictionary`, `func credit_delivery(rarity: int, is_stock: bool) -> int`, `func pay(bits: int) -> int`, `func take_pending_punishment() -> int`, `func relieve() -> Dictionary`, `func beam_is_recalled(cycle: int) -> bool`, `func statement_lines(player_name: String, built_plots: int, open_permits: int, cycle: int) -> Array[String]`, `func to_dict() -> Dictionary`, `static func from_dict(d: Dictionary) -> Ledger`.
  - `GameState` gains `var ledger: Ledger` under `const KEY_LEDGER := "ledger"`, replaced (not mutated) by `from_dict()` and `reset()`, exactly as `gems` and `compendium` are.
  - `SaveIO.FORMAT_VERSION := 5`; `migrate()` gains a `from_version < 5` branch adding `"ledger": {}`. (Task 8 adds `"player"` to the SAME branch; the version is bumped once, here.)

**`run_collection_day`'s return shape,** which the ranch, the Depot statement and three tests all read:

```
{"period": int, "upkeep": int, "service_charge": int, "delivered": int, "quota": int,
 "quota_met": bool, "over_ceiling": bool, "punishment": int, "balance": int}
```

**The tuning, and the one place the spec had to be resolved.** The spec attributes "gems alone never clear the balance" to interest alone. Interest alone cannot do it: three legendary ponies in a pen produce a gem each every twenty seconds at a hundred bits a gem, which is 54,000 bits in one collection day against a 25,000 balance, and no small percentage of a falling balance outruns that. So the promise is made by an explicit, player visible rule instead: **bits settle the service charges, stock settles the principal.** `pay()` will never take the balance below `PRINCIPAL_FLOOR`; only `credit_delivery()` reaches under it. The Depot says so in as many words, cheerfully. Interest and upkeep stay exactly as the spec describes them and are what the player actually feels; the floor is what makes the promise true, and `test_ledger.gd` asserts the two together.

`UPKEEP_BASE` is 1800 because of the other pacing number: a fresh ranch is one free Paddock holding three ponies, and three ponies at the best production rate earn `3 * (3600 / 20) * 5 = 2700` bits in one collection period. The first collection day charges `1800 + 350 + 1000 = 3150`, so the balance goes UP even if she sells every gem and pays every bit, which is the spec's "the balance up, not down".

- [ ] **Step 1: Write the failing test file `game/test/test_ledger.gd`**

```gdscript
extends GutTest
## The debt clock. Arithmetic only: no scene, no clock, no RNG.

const LedgerScript := preload("res://systems/ledger.gd")
const EconomyScript := preload("res://systems/economy.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")
const ProductionScript := preload("res://systems/production.gd")
const WorldStateScript := preload("res://systems/world_state.gd")


func test_a_new_ledger_opens_at_the_sponsorship_balance() -> void:
	var l := LedgerScript.new()
	assert_eq(l.balance, LedgerScript.STARTING_BALANCE)
	assert_eq(l.quota, LedgerScript.STARTING_QUOTA)
	assert_eq(l.delivered_this_period, 0)
	assert_eq(l.tier, 0)


func test_collection_day_is_every_three_cycles_and_one_real_hour_in() -> void:
	assert_false(LedgerScript.is_collection_cycle(0), "the day you start is not a collection day")
	assert_false(LedgerScript.is_collection_cycle(1))
	assert_false(LedgerScript.is_collection_cycle(2))
	assert_true(LedgerScript.is_collection_cycle(3))
	assert_true(LedgerScript.is_collection_cycle(6))
	var seconds: float = float(LedgerScript.PERIOD_CYCLES) * WorldStateScript.CYCLE_SECONDS
	assert_eq(seconds, 3600.0, "the first collection day lands at one real hour of play")


func test_upkeep_is_a_base_plus_a_charge_per_plot_and_per_permit() -> void:
	var l := LedgerScript.new()
	assert_eq(l.upkeep_for(0, 0), LedgerScript.UPKEEP_BASE)
	assert_eq(l.upkeep_for(2, 0),
		LedgerScript.UPKEEP_BASE + 2 * LedgerScript.UPKEEP_PER_PLOT)
	assert_eq(l.upkeep_for(2, 3),
		LedgerScript.UPKEEP_BASE + 2 * LedgerScript.UPKEEP_PER_PLOT
			+ 3 * LedgerScript.UPKEEP_PER_PERMIT)
	assert_eq(l.upkeep_for(2, 3, 2.0), 2 * l.upkeep_for(2, 3),
		"the rank multiplier scales the whole charge; slice 4 sets it, slice 1 leaves it at 1")


func test_the_service_charge_is_a_percentage_with_a_floor() -> void:
	var l := LedgerScript.new()
	assert_eq(l.service_charge(),
		int(round(float(LedgerScript.STARTING_BALANCE) * LedgerScript.INTEREST_RATE)))
	l.balance = 10
	assert_eq(l.service_charge(), LedgerScript.MIN_SERVICE_CHARGE,
		"a nearly settled balance still costs something to carry")
	l.balance = 0
	assert_eq(l.service_charge(), 0, "and a settled one costs nothing")


func test_the_first_collection_day_outruns_a_starter_ranch() -> void:
	# One free Paddock, three ponies, the best production rate, common gems.
	var gems_per_period: int = int(float(LedgerScript.PERIOD_CYCLES)
		* WorldStateScript.CYCLE_SECONDS / ProductionScript.PRODUCTION_PERIOD_SECONDS)
	var income: int = 3 * gems_per_period \
		* int(EconomyScript.GEM_VALUE_BY_RARITY[PonyDataScript.Rarity.COMMON])
	var l := LedgerScript.new()
	var summary: Dictionary = l.run_collection_day(LedgerScript.PERIOD_CYCLES, 1, 0)
	assert_gt(int(summary["upkeep"]) + int(summary["service_charge"]), income,
		"the first hour must leave the player owing more, not less")
	assert_gt(l.balance, LedgerScript.STARTING_BALANCE)


func test_a_stock_delivery_credits_three_hundred() -> void:
	var l := LedgerScript.new()
	var before: int = l.balance
	assert_eq(l.credit_delivery(PonyDataScript.Rarity.COMMON, true),
		LedgerScript.DELIVERY_CREDIT_STOCK)
	assert_eq(l.balance, before - LedgerScript.DELIVERY_CREDIT_STOCK)
	assert_eq(l.delivered_this_period, 1)


func test_a_named_delivery_is_priced_by_rarity_and_a_legendary_clears_four_thousand() -> void:
	assert_eq(LedgerScript.delivery_credit(PonyDataScript.Rarity.LEGENDARY, false), 4000)
	assert_eq(LedgerScript.delivery_credit(PonyDataScript.Rarity.RARE, false), 1200)
	assert_eq(LedgerScript.delivery_credit(PonyDataScript.Rarity.UNCOMMON, false), 480)
	assert_eq(LedgerScript.delivery_credit(PonyDataScript.Rarity.COMMON, false), 200)
	assert_gt(LedgerScript.delivery_credit(PonyDataScript.Rarity.LEGENDARY, false),
		LedgerScript.DELIVERY_CREDIT_STOCK * 10,
		"a named delivery is the best money in the game by a wide margin, deliberately")


func test_a_delivery_may_take_the_balance_below_the_principal_floor() -> void:
	var l := LedgerScript.new()
	l.balance = 200
	l.credit_delivery(PonyDataScript.Rarity.LEGENDARY, false)
	assert_lt(l.balance, 0, "stock settles the principal, and may overshoot into credit")


func test_bits_never_take_the_balance_below_the_principal_floor() -> void:
	var l := LedgerScript.new()
	var allowed: int = l.payable()
	assert_eq(allowed, LedgerScript.STARTING_BALANCE - LedgerScript.PRINCIPAL_FLOOR)
	assert_eq(l.pay(1000000), allowed,
		"pay() takes what it may and answers with what it actually took")
	assert_eq(l.balance, LedgerScript.PRINCIPAL_FLOOR)
	assert_eq(l.pay(5000), 0, "and refuses to go further")
	assert_eq(l.balance, LedgerScript.PRINCIPAL_FLOOR)


func test_paying_zero_or_less_changes_nothing() -> void:
	var l := LedgerScript.new()
	assert_eq(l.pay(0), 0)
	assert_eq(l.pay(-500), 0)
	assert_eq(l.balance, LedgerScript.STARTING_BALANCE)


func test_the_quota_is_counted_per_period_and_reset_by_the_collection_day() -> void:
	var l := LedgerScript.new()
	l.credit_delivery(PonyDataScript.Rarity.COMMON, true)
	l.credit_delivery(PonyDataScript.Rarity.COMMON, true)
	var summary: Dictionary = l.run_collection_day(3, 1, 0)
	assert_true(bool(summary["quota_met"]))
	assert_eq(int(summary["delivered"]), 2)
	assert_eq(l.delivered_this_period, 0, "the count starts again for the next period")


func test_the_collector_ladder_climbs_in_the_order_the_spec_names() -> void:
	var l := LedgerScript.new()
	var seen: Array[int] = []
	for i in 6:
		var summary: Dictionary = l.run_collection_day(3 * (i + 1), 1, 0)
		seen.append(int(summary["punishment"]))
	assert_eq(seen[0], LedgerScript.Punishment.FEE)
	assert_eq(seen[1], LedgerScript.Punishment.PERMIT_REVOKED)
	assert_eq(seen[2], LedgerScript.Punishment.PEN_PADLOCKED)
	assert_eq(seen[3], LedgerScript.Punishment.BEAM_RECALLED)
	assert_eq(seen[4], LedgerScript.Punishment.BEAM_RECALLED, "the top rung is the top rung")


func test_meeting_the_quota_steps_back_down_the_ladder() -> void:
	var l := LedgerScript.new()
	l.run_collection_day(3, 1, 0)
	l.run_collection_day(6, 1, 0)
	assert_eq(l.tier, 2)
	l.credit_delivery(PonyDataScript.Rarity.COMMON, true)
	l.credit_delivery(PonyDataScript.Rarity.COMMON, true)
	var summary: Dictionary = l.run_collection_day(9, 1, 0)
	assert_eq(int(summary["punishment"]), LedgerScript.Punishment.NONE)
	assert_eq(l.tier, 1, "a good period walks the ladder back down one rung, not all of it")


func test_a_balance_over_the_ceiling_calls_a_collector_even_with_the_quota_met() -> void:
	var l := LedgerScript.new()
	l.balance = LedgerScript.CEILING + 1
	l.credit_delivery(PonyDataScript.Rarity.COMMON, true)
	l.credit_delivery(PonyDataScript.Rarity.COMMON, true)
	var summary: Dictionary = l.run_collection_day(3, 1, 0)
	assert_true(bool(summary["quota_met"]))
	assert_true(bool(summary["over_ceiling"]))
	assert_eq(int(summary["punishment"]), LedgerScript.Punishment.FEE)


func test_a_pending_punishment_is_taken_exactly_once() -> void:
	var l := LedgerScript.new()
	l.run_collection_day(3, 1, 0)
	assert_eq(l.take_pending_punishment(), LedgerScript.Punishment.FEE)
	assert_eq(l.take_pending_punishment(), LedgerScript.Punishment.NONE,
		"a collector who has already called does not call twice at the same dawn")


func test_relief_arrives_when_the_balance_is_back_under_the_ceiling() -> void:
	var l := LedgerScript.new()
	l.balance = LedgerScript.CEILING + 5000
	l.revoked_permits = ["permit_orchard"]
	l.padlocked_slots = ["plot_a"]
	l.beam_recalled_until = 12
	assert_eq(l.relieve(), {}, "nothing is given back while she is over the ceiling")
	l.credit_delivery(PonyDataScript.Rarity.LEGENDARY, false)
	l.credit_delivery(PonyDataScript.Rarity.LEGENDARY, false)
	var given: Dictionary = l.relieve()
	assert_eq(given["permits"], ["permit_orchard"])
	assert_eq(given["slots"], ["plot_a"])
	assert_true(bool(given["beam"]))
	assert_eq(l.revoked_permits, [])
	assert_eq(l.padlocked_slots, [])
	assert_eq(l.beam_recalled_until, -1)
	assert_eq(l.relieve(), {}, "and nothing is given back twice")


func test_the_beam_recall_lasts_exactly_one_cycle() -> void:
	var l := LedgerScript.new()
	l.beam_recalled_until = 5 + LedgerScript.BEAM_RECALL_CYCLES
	assert_true(l.beam_is_recalled(5))
	assert_false(l.beam_is_recalled(6), "one cycle later she has her horn back")


func test_gems_alone_never_clear_the_balance() -> void:
	# THE BEST RANCH THE GAME PERMITS: six plot slots, all Grand Pens (eight spaces each),
	# every space filled with the most valuable pony the roster can supply (one of each of
	# the 3 legendary, 8 rare, 15 uncommon and 17 common characters, the remainder stock),
	# every resident at happiness 1.0 and hunger 0.0, every gem sold at full price, every
	# permit open, and not one pony ever delivered.
	var per_pony: int = int(float(LedgerScript.PERIOD_CYCLES) * WorldStateScript.CYCLE_SECONDS
		/ ProductionScript.PRODUCTION_PERIOD_SECONDS)
	var values: Array[int] = []
	for i in 3:
		values.append(int(EconomyScript.GEM_VALUE_BY_RARITY[PonyDataScript.Rarity.LEGENDARY]))
	for i in 8:
		values.append(int(EconomyScript.GEM_VALUE_BY_RARITY[PonyDataScript.Rarity.RARE]))
	for i in 15:
		values.append(int(EconomyScript.GEM_VALUE_BY_RARITY[PonyDataScript.Rarity.UNCOMMON]))
	while values.size() < 48:
		values.append(int(EconomyScript.GEM_VALUE_BY_RARITY[PonyDataScript.Rarity.COMMON]))
	var income := 0
	for value in values:
		income += per_pony * value
	var l := LedgerScript.new()
	for period in 50:
		l.run_collection_day(LedgerScript.PERIOD_CYCLES * (period + 1), 6, 4)
		l.pay(income)
	assert_gt(l.balance, 0,
		"a player who never delivers a pony cannot pay the balance off; that is the game")
	assert_eq(l.balance, LedgerScript.PRINCIPAL_FLOOR,
		"and she settles exactly at the principal, which is what the Depot tells her")


func test_shipments_count_up_across_periods_and_never_reset() -> void:
	var l := LedgerScript.new()
	assert_eq(l.shipments, 0)
	l.credit_delivery(PonyDataScript.Rarity.COMMON, true)
	l.credit_delivery(PonyDataScript.Rarity.COMMON, true)
	l.run_collection_day(3, 1, 0)
	assert_eq(l.delivered_this_period, 0, "the quota count starts again")
	assert_eq(l.shipments, 2, "the shipment count does not; the receipts keep counting")


func test_a_statement_names_the_player_and_carries_no_dashes() -> void:
	var l := LedgerScript.new()
	var lines: Array[String] = l.statement_lines("Moonbeam", 2, 1, 4)
	assert_gt(lines.size(), 4)
	var joined: String = "\n".join(lines)
	assert_true(joined.contains("Moonbeam"), "the statement is made out to her")
	assert_false(joined.contains("--"), "no double hyphen in anything a player reads")
	assert_false(joined.contains(char(0x2014)), "and no em dash")


func test_the_whole_ledger_round_trips() -> void:
	var l := LedgerScript.new()
	l.balance = 31234
	l.quota = 5
	l.delivered_this_period = 3
	l.periods_run = 7
	l.shipments = 21
	l.tier = 2
	l.pending_punishment = LedgerScript.Punishment.PEN_PADLOCKED
	l.revoked_permits = ["permit_lake"]
	l.padlocked_slots = ["plot_b"]
	l.beam_recalled_until = 19
	var back: Ledger = LedgerScript.from_dict(l.to_dict())
	assert_eq(back.balance, 31234)
	assert_eq(back.quota, 5)
	assert_eq(back.delivered_this_period, 3)
	assert_eq(back.periods_run, 7)
	assert_eq(back.shipments, 21)
	assert_eq(back.tier, 2)
	assert_eq(back.pending_punishment, LedgerScript.Punishment.PEN_PADLOCKED)
	assert_eq(back.revoked_permits, ["permit_lake"])
	assert_eq(back.padlocked_slots, ["plot_b"])
	assert_eq(back.beam_recalled_until, 19)


func test_an_empty_dictionary_loads_as_a_brand_new_ledger() -> void:
	var back: Ledger = LedgerScript.from_dict({})
	assert_eq(back.balance, LedgerScript.STARTING_BALANCE)
	assert_eq(back.quota, LedgerScript.STARTING_QUOTA)


func test_junk_is_clamped_rather_than_trusted() -> void:
	var back: Ledger = LedgerScript.from_dict({"quota": -4, "tier": 900,
		"revoked_permits": "not an array"})
	assert_eq(back.quota, 0, "a negative quota is no quota, not a bonus")
	assert_eq(back.tier, LedgerScript.LADDER.size(), "the ladder has a top")
	assert_eq(back.revoked_permits, [])
```

- [ ] **Step 2: Run the test and watch it fail**

Run: `FILLY_SKIP_SWEEP=1 bash tools/run_tests.sh 2>&1 | tail -30`
Expected: `Ignoring script res://test/test_ledger.gd because it does not extend GutTest`, and the run fails on the script count shortfall.

- [ ] **Step 3: Write `game/systems/ledger.gd`**

```gdscript
class_name Ledger
extends RefCounted
## THE COMPANY'S HOLD ON THE PLAYER, AS ARITHMETIC. A sponsorship balance that the ranch
## was bought with, a collection day every three cycles that adds upkeep and a service
## charge to it, a quota of ponies that has to be delivered between one collection day and
## the next, and a four rung ladder of collectors for the periods where neither happens.
## No scene, no clock, no RNG: the cycle number comes in as an argument, the same
## discipline game/systems/production.gd and game/systems/economy.gd are built under, so
## the whole of it is GUT testable in milliseconds (game/test/test_ledger.gd).
##
## --- THE PROMISE THIS CLASS EXISTS TO KEEP -------------------------------------------
##
## A player who never delivers a pony cannot pay the balance off. That is the premise of
## the whole phase: the ranch is not a business, it is a debt with a supply contract
## attached, and the only thing that actually moves the principal is stock.
##
## THE MECHANISM IS A FLOOR, NOT MERELY INTEREST, and it is worth writing down why. The
## design doc attributes the promise to the service charge alone. The service charge cannot
## carry it: three legendary ponies in a pen produce a gem each every twenty seconds at a
## hundred bits a gem (game/systems/production.gd, game/systems/economy.gd), which is
## 54,000 bits in one collection day against a 25,000 balance, and no small percentage of a
## FALLING balance outruns that. So the rule is stated outright instead, and the Depot says
## it in as many words: bits settle the service charges, stock settles the principal.
## pay() will never take the balance below PRINCIPAL_FLOOR; credit_delivery() is the only
## thing that reaches under it. The service charge and the upkeep are still exactly what
## the player feels week to week; the floor is what makes the promise true.
## test_gems_alone_never_clear_the_balance asserts the two of them together.
##
## --- NOTHING IS EVER DELETED ----------------------------------------------------------
##
## A collector revokes a permit, padlocks a pen or recalls the beam. Every one of those is
## a note in this object that relieve() takes back the moment the balance is under the
## ceiling; the permit is still bought, the pen is still built, the ponies inside it are
## still hers, and NO PONY IS EVER TAKEN. (The one place after the fork where a collector
## reaches into a pen is the Resistance route, which is a later slice and is not here.)

enum Punishment { NONE, FEE, PERMIT_REVOKED, PEN_PADLOCKED, BEAM_RECALLED }

## The collector ladder, in the order the design doc names it. Index by `tier`, clamped at
## the end: the fourth failure and the fortieth both recall the beam.
const LADDER: Array[int] = [Punishment.FEE, Punishment.PERMIT_REVOKED,
	Punishment.PEN_PADLOCKED, Punishment.BEAM_RECALLED]

## What the ranch, the beam and the first pen cost, in bits, at a price the player never
## agreed to. Shown from minute one and never hidden.
const STARTING_BALANCE := 25000

## Cycles between collection days. Three at WorldState.CYCLE_SECONDS (1200 s) is one real
## hour, which is where the design doc puts the first one.
const PERIOD_CYCLES := 3

## Ponies that must be delivered between one collection day and the next. Grows with rank
## in a later slice; this is where it starts.
const STARTING_QUOTA := 2

## Over this, a collector calls whether or not the quota was met, and every punishment
## stands until the balance is back under it.
const CEILING := 40000

## The balance bits will not go below. See the class comment.
const PRINCIPAL_FLOOR := 5000

## Upkeep: a base, plus a charge per built plot and per open permit, times the rank
## multiplier. UPKEEP_BASE is 1800 for a pacing reason with a test on it: a fresh ranch is
## one free Paddock holding three ponies, three ponies at the best production rate earn
## 2700 bits in one collection period, and the first collection day has to charge more than
## that so the balance goes UP in the player's first hour even if she sells everything.
const UPKEEP_BASE := 1800
const UPKEEP_PER_PLOT := 350
const UPKEEP_PER_PERMIT := 450

## The service charge, as a fraction of the balance, with a floor so a nearly settled
## balance still visibly costs something to carry.
const INTEREST_RATE := 0.04
const MIN_SERVICE_CHARGE := 25

## Credit for delivering one pony of the crowd, and the multiplier a NAMED pony's gem value
## is scaled by (game/systems/economy.gd GEM_VALUE_BY_RARITY times this), so a legendary
## clears 4,000. A named delivery is the best money in the game by a wide margin. That is
## deliberate, and it is the whole hinge of the story.
const DELIVERY_CREDIT_STOCK := 300
const DELIVERY_NAMED_MULTIPLIER := 40

## What the first rung of the ladder costs in bits.
const COLLECTOR_FEE := 500

## How long the beam is "recalled" for, in cycles.
const BEAM_RECALL_CYCLES := 1

## Emitted whenever `balance` actually moves. Carries the new total so a HUD can bind to it
## without a second read, matching Economy.bits_changed's rule.
signal changed(balance: int)

## Emitted by run_collection_day() with the summary it returns, so a HUD, a toast and a
## letter can all hang off one event.
signal collection_day(summary: Dictionary)

var balance := STARTING_BALANCE
var quota := STARTING_QUOTA
var delivered_this_period := 0
var periods_run := 0

## Every pony this ranch has ever shipped, across every period. Counted here rather than in
## the ranch because a delivered pony leaves no trace anywhere else by design, and the
## receipt letter counts her shipments back to her ("your 12th delivery!"). Saved, so a
## reload does not start the count over and hand her a first receipt on her twentieth pony.
var shipments := 0

## How far up LADDER the next failure will reach. Raised by a failed collection day,
## lowered by one (not reset) by a good one, so recovering from a bad run takes as many
## good periods as the bad run took.
var tier := 0

## The punishment the collector will serve at the NEXT DAWN, taken exactly once by
## take_pending_punishment(). Separated from the collection day itself because the design
## doc puts the visit at dawn and the arithmetic at the cycle boundary.
var pending_punishment: int = Punishment.NONE

## Permit unlock ids currently revoked, and plot slot ids currently padlocked. Plain
## Strings, and untyped Arrays, for GameState.unlocks' reason: these are assigned
## dynamically from the ranch and from tests, and a typed array would refuse an untyped
## literal at runtime rather than at parse time.
var revoked_permits: Array = []
var padlocked_slots: Array = []

## Cycle index the beam comes back at, or -1 when it was never recalled.
var beam_recalled_until := -1


## Which collection period `cycle` falls in.
static func period_of(cycle: int) -> int:
	return int(floor(float(maxi(0, cycle)) / float(PERIOD_CYCLES)))


## Is `cycle` a collection day? Cycle zero is not: the day the player starts is the day she
## is handed the ranch, and billing her for it before she has walked out of the house would
## be a joke with no setup.
static func is_collection_cycle(cycle: int) -> bool:
	return cycle > 0 and cycle % PERIOD_CYCLES == 0


## Bits credited for delivering one pony. Stock is a flat rate; a named pony is her gem
## value times the multiplier.
static func delivery_credit(rarity: int, is_stock: bool) -> int:
	if is_stock:
		return DELIVERY_CREDIT_STOCK
	var unit: int = int(Economy.GEM_VALUE_BY_RARITY.get(rarity, 0))
	return unit * DELIVERY_NAMED_MULTIPLIER


func upkeep_for(built_plots: int, open_permits: int, rank_multiplier: float = 1.0) -> int:
	var raw: int = UPKEEP_BASE + maxi(0, built_plots) * UPKEEP_PER_PLOT \
		+ maxi(0, open_permits) * UPKEEP_PER_PERMIT
	return int(round(float(raw) * maxf(0.0, rank_multiplier)))


func service_charge() -> int:
	if balance <= 0:
		return 0
	return maxi(MIN_SERVICE_CHARGE, int(round(float(balance) * INTEREST_RATE)))


## The most bits pay() will accept right now. Never negative.
func payable() -> int:
	return maxi(0, balance - PRINCIPAL_FLOOR)


## THE COLLECTION DAY. Adds the upkeep and the service charge, judges the period, arms the
## next collector, and starts the count again. Returns everything the ranch, the statement
## and the tests need, in one dictionary, so nothing has to ask this object a second
## question about a moment that has already passed.
func run_collection_day(cycle: int, built_plots: int, open_permits: int,
		rank_multiplier: float = 1.0) -> Dictionary:
	var upkeep: int = upkeep_for(built_plots, open_permits, rank_multiplier)
	var charge: int = service_charge()
	balance += upkeep + charge

	var delivered: int = delivered_this_period
	var quota_met: bool = delivered >= quota
	var over_ceiling: bool = balance > CEILING
	var punishment: int = Punishment.NONE
	if quota_met and not over_ceiling:
		tier = maxi(0, tier - 1)
	else:
		punishment = LADDER[clampi(tier, 0, LADDER.size() - 1)]
		tier = mini(tier + 1, LADDER.size())
	pending_punishment = punishment

	delivered_this_period = 0
	periods_run += 1

	var summary := {
		"period": period_of(cycle),
		"upkeep": upkeep,
		"service_charge": charge,
		"delivered": delivered,
		"quota": quota,
		"quota_met": quota_met,
		"over_ceiling": over_ceiling,
		"punishment": punishment,
		"balance": balance,
	}
	changed.emit(balance)
	collection_day.emit(summary)
	return summary


## One pony delivered. Returns the credit applied, counts her toward the quota, and MAY
## take the balance below the floor and into credit: stock settles the principal.
func credit_delivery(rarity: int, is_stock: bool) -> int:
	var credit: int = delivery_credit(rarity, is_stock)
	if credit <= 0:
		return 0
	balance -= credit
	delivered_this_period += 1
	shipments += 1
	changed.emit(balance)
	return credit


## Pay bits against the balance. Returns what was actually taken, which is zero for a
## non positive amount and is capped at payable(). A caller must debit the wallet by the
## RETURN VALUE, never by what it asked for.
func pay(bits: int) -> int:
	if bits <= 0:
		return 0
	var taken: int = mini(bits, payable())
	if taken <= 0:
		return 0
	balance -= taken
	changed.emit(balance)
	return taken


## The punishment a collector should serve at this dawn, taken exactly once. A second call
## before the next collection day answers NONE, so a dawn that fires twice (a mid session
## load, a pinned clock) cannot serve one collector twice.
func take_pending_punishment() -> int:
	var punishment: int = pending_punishment
	pending_punishment = Punishment.NONE
	return punishment


## GIVE EVERYTHING BACK, once the balance is under the ceiling. Returns what was cleared,
## `{"permits": Array, "slots": Array, "beam": bool}`, so the caller can re-open the fences,
## unpadlock the pens and hand the horn back; or an EMPTY dictionary when there was nothing
## to give back or she is still over the ceiling, which is the caller's cue to do nothing
## and say nothing.
func relieve() -> Dictionary:
	if balance > CEILING:
		return {}
	if revoked_permits.is_empty() and padlocked_slots.is_empty() and beam_recalled_until < 0:
		return {}
	var given := {
		"permits": revoked_permits.duplicate(),
		"slots": padlocked_slots.duplicate(),
		"beam": beam_recalled_until >= 0,
	}
	revoked_permits = []
	padlocked_slots = []
	beam_recalled_until = -1
	return given


func beam_is_recalled(cycle: int) -> bool:
	return beam_recalled_until >= 0 and cycle < beam_recalled_until


## The Depot's statement, as lines. Made out to the player by name, because the Company
## knowing your name is part of the register.
func statement_lines(player_name: String, built_plots: int, open_permits: int,
		cycle: int) -> Array[String]:
	var next_cycle: int = (period_of(cycle) + 1) * PERIOD_CYCLES
	var lines: Array[String] = []
	lines.append("Cloudsdale Weather Corporation, Sponsorship Services")
	lines.append("Account: %s" % player_name)
	lines.append("Sponsorship balance: %d bits" % balance)
	lines.append("Upkeep next collection: %d bits" % upkeep_for(built_plots, open_permits))
	lines.append("  base %d, plots %d at %d, permits %d at %d" % [
		UPKEEP_BASE, built_plots, UPKEEP_PER_PLOT, open_permits, UPKEEP_PER_PERMIT])
	lines.append("Service charge next collection: %d bits" % service_charge())
	lines.append("Next collection day: cycle %d (you are on cycle %d)" % [next_cycle, cycle])
	lines.append("Quota this period: %d of %d delivered" % [delivered_this_period, quota])
	lines.append("Collections passed: %d" % periods_run)
	lines.append("Bits settle the service charges. The principal is settled in stock.")
	lines.append("You may pay down to %d bits here; thank you for choosing Cloudsdale!"
		% PRINCIPAL_FLOOR)
	return lines


func to_dict() -> Dictionary:
	return {
		"balance": balance,
		"quota": quota,
		"delivered_this_period": delivered_this_period,
		"periods_run": periods_run,
		"shipments": shipments,
		"tier": tier,
		"pending_punishment": pending_punishment,
		"revoked_permits": revoked_permits.duplicate(),
		"padlocked_slots": padlocked_slots.duplicate(),
		"beam_recalled_until": beam_recalled_until,
	}


## Rebuild from a to_dict() dictionary, or from one JSON.parse_string handed back, which is
## the same thing with every number as a float. Every field is optional and falls back to a
## brand new ledger's value, which is what makes an older save load without a migration
## step; and every field is CLAMPED rather than trusted, so a hand edited file cannot
## produce a negative quota or a rung the ladder does not have.
static func from_dict(d: Dictionary) -> Ledger:
	var out := Ledger.new()
	out.balance = int(d.get("balance", STARTING_BALANCE))
	out.quota = maxi(0, int(d.get("quota", STARTING_QUOTA)))
	out.delivered_this_period = maxi(0, int(d.get("delivered_this_period", 0)))
	out.periods_run = maxi(0, int(d.get("periods_run", 0)))
	out.shipments = maxi(0, int(d.get("shipments", 0)))
	out.tier = clampi(int(d.get("tier", 0)), 0, LADDER.size())
	out.pending_punishment = clampi(int(d.get("pending_punishment", Punishment.NONE)),
		Punishment.NONE, Punishment.BEAM_RECALLED)
	out.revoked_permits = _string_list(d.get("revoked_permits", []))
	out.padlocked_slots = _string_list(d.get("padlocked_slots", []))
	out.beam_recalled_until = int(d.get("beam_recalled_until", -1))
	return out


static func _string_list(value: Variant) -> Array:
	var out: Array = []
	if typeof(value) != TYPE_ARRAY:
		return out
	for entry in (value as Array):
		out.append(str(entry))
	return out
```

- [ ] **Step 4: Hold the ledger in `game/systems/game_state.gd`**

Add the preload `const LedgerScript := preload("res://systems/ledger.gd")`, the key `const KEY_LEDGER := "ledger"`, and the field beside `compendium`:

```gdscript
## The Company's account against this ranch (game/systems/ledger.gd): the balance, the
## quota, how far up the collector ladder the last few periods have taken her, and what is
## currently revoked or padlocked. REPLACED, NOT MUTATED, by from_dict() and reset(), the
## same rule `gems` and `compendium` follow and for the same reason: a listener holding the
## old object is holding the account of a ranch nobody is playing any more.
var ledger: Ledger = LedgerScript.new()
```

In `to_dict()`, add `KEY_LEDGER: ledger.to_dict(),`. In `from_dict()`, beside the compendium:

```gdscript
	var saved_ledger: Variant = data.get(KEY_LEDGER, {})
	ledger = LedgerScript.from_dict(
		saved_ledger if typeof(saved_ledger) == TYPE_DICTIONARY else {})
```

In `reset()`, add `ledger = LedgerScript.new()`.

- [ ] **Step 5: Bump the save format**

In `game/systems/save_io.gd`, change `const FORMAT_VERSION := 4` to `5`, add the version note to the class comment beside the version 4 one:

```
## Version 5 (Phase 3 slice 1) adds "ledger" and "player"; ledger defaults to {} (a brand
## new sponsorship balance) and player defaults to {} (the name Twilight and the shipped
## look). Both are read through their own from_dict(), each of which fills every missing
## field from its own default, so a version 4 file needs nothing else.
```

and add the branch to `migrate()` (Task 8 adds `"player"` to the same branch; the version is bumped once, here):

```gdscript
	if from_version < 5:
		if not out.has("ledger"):
			out["ledger"] = {}
```

- [ ] **Step 6: Extend the save and state tests**

Add to `game/test/test_game_state.gd`:

```gdscript
func test_the_ledger_round_trips_through_the_state() -> void:
	GameState.reset()
	GameState.ledger.balance = 31000
	GameState.ledger.quota = 4
	var data: Dictionary = GameState.to_dict()
	GameState.reset()
	assert_eq(GameState.ledger.balance, Ledger.STARTING_BALANCE)
	GameState.from_dict(data)
	assert_eq(GameState.ledger.balance, 31000)
	assert_eq(GameState.ledger.quota, 4)


func test_a_load_replaces_the_ledger_rather_than_mutating_it() -> void:
	GameState.reset()
	var old: Ledger = GameState.ledger
	GameState.from_dict({})
	assert_ne(GameState.ledger, old, "a listener holding the old account must be told to re-read")
```

Add to `game/test/test_save_io.gd`:

```gdscript
func test_the_format_version_is_five() -> void:
	assert_eq(SaveIO.FORMAT_VERSION, 5)
	assert_true(SaveIO.can_load_version(1))
	assert_true(SaveIO.can_load_version(4))
	assert_true(SaveIO.can_load_version(5))
	assert_false(SaveIO.can_load_version(6))


func test_migrating_a_version_four_save_gives_it_a_ledger() -> void:
	var migrated: Dictionary = SaveIO.migrate({"bits": 40, "compendium": {}, "requests": []}, 4)
	assert_eq(migrated["ledger"], {})
	var ledger: Ledger = Ledger.from_dict(migrated["ledger"])
	assert_eq(ledger.balance, Ledger.STARTING_BALANCE,
		"a ranch from before the Company opens its account at the sponsorship balance")


func test_a_version_four_file_on_disk_loads_in_this_build() -> void:
	var path: String = SaveIO.slot_path(_slot)
	DirAccess.make_dir_recursive_absolute(SaveIO.save_dir)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 4, "bits": 77,
		"compendium": {"twilight": 2}, "requests": []}, "  ", true, true))
	file.close()
	var loaded: Dictionary = SaveIO.load(_slot)
	assert_eq(int(loaded["version"]), 5, "it is brought up to today's shape")
	assert_eq(int(loaded["bits"]), 77, "and nothing it did say is lost")
	assert_eq(loaded["ledger"], {})
```

- [ ] **Step 7: Run the tests and watch them pass**

Run: `bash tools/run_tests.sh 2>&1 | tail -25`
Expected: `---- All tests passed! ----`, exit 0.

Run: `bash tools/prove_atomic_save.sh` and `bash tools/prove_atomic_save.sh --negative-control`
Expected: `ATOMIC_SAVE_PROOF_OK` and `ATOMIC_SAVE_PROOF_NEGATIVE_CONTROL_OK`, both exit 0.

- [ ] **Step 8: Commit**

```bash
printf 'feat: the Ledger, and save format version 5\n\nA sponsorship balance of 25000, a collection day every three cycles with upkeep\nand a service charge, a quota of two, delivery credits of 300 for stock and gem\nvalue times 40 for a named pony, and the collector ladder in the order fee,\npermit revoked, pen padlocked, beam recalled. Bits settle the service charges\nand stock settles the principal, which is the tested promise that gems alone\nnever clear the balance.\n' > /tmp/msg.txt
git add game/systems/ledger.gd game/systems/ledger.gd.uid game/systems/game_state.gd \
  game/systems/save_io.gd game/test/test_ledger.gd game/test/test_ledger.gd.uid \
  game/test/test_game_state.gd game/test/test_save_io.gd
git commit -F /tmp/msg.txt
```

---

### Task 5: The Depot. Deliver, pay, statement, and the walk to the crate

**Files:**
- Create: `game/systems/letters.gd`, `game/ui/depot_menu.gd`, `game/ui/depot_menu.tscn`
- Modify: `game/actors/pony/pony.gd` (`leave_toward`, `_state_leaving`), `game/world/pen.gd` (`release_body`), `game/systems/compendium.gd` (`PROCESSED`), `game/world/ranch.tscn` (the Depot building and its crate), `game/world/ranch.gd` (the prompt, the transactions, the report), `game/ui/pause_menu.gd` (the PROCESSED row and the header)
- Test: `game/test/test_pony.gd`, `game/test/test_pen.gd`, `game/test/test_compendium.gd`, `game/test/test_letters.gd`, `game/test/test_depot_menu.gd`, `game/test/test_pause_menu.gd`

**Interfaces:**
- Consumes: `Ledger.credit_delivery`, `Ledger.pay`, `Ledger.payable`, `Ledger.statement_lines` (Task 4); `PonyInstance.is_stock()` (Task 3); `Economy.spend`, `Economy.bits`.
- Produces:
  - `Pony` gains `func leave_toward(point: Vector3) -> bool` and `const LEAVE_ARRIVAL_RADIUS := 1.2`. `leave()` is unchanged in behaviour and clears the target.
  - `Pen` gains `func release_body(uid: StringName, new_parent: Node3D) -> Node3D`, which removes the resident record and hands her LIVE body over, reparented with her world transform kept. It never frees anything.
  - `Compendium.State` gains `PROCESSED` (value 3); `func mark_processed(id: StringName) -> bool`; `from_dict()` accepts it.
  - `class_name Letters extends RefCounted`, static only. `enum Id { WELCOME, RECEIPT_STOCK, RECEIPT_NAMED, QUOTA_REMINDER, COLLECTION_NOTICE, COLLECTOR_VISIT }`; `const MAX_NAME_LENGTH := 16`; `const LINE_WIDTH := 58`; `const SENDER := "Cloudsdale Weather Corporation"`; `static func ids() -> Array[int]`; `static func render(id: int, params: Dictionary) -> Dictionary` returning `{"sender": String, "title": String, "body": Array[String]}`.
  - `class_name DepotMenu extends CanvasLayer` with `enum Tab { DELIVER, PAY, STATEMENT }`, signals `opened()`, `closed()`, `deliver_requested(uid: StringName)`, `pay_requested(bits: int)`; injected `var can_open := Callable()`, `var rows_provider := Callable()`, `var bits_provider := Callable()`, `var statement_provider := Callable()`; `func open() -> bool`, `func close() -> void`, `func is_open() -> bool`, `func refresh() -> void`, `func deliver_rows() -> Array[Dictionary]`, `func pay_amounts() -> Array[int]`, `func tab() -> int`, `func selected_index() -> int`, `func move_selection(step: int) -> void`, `func switch_tab(step: int) -> void`, `func confirm() -> bool`.
  - `Ranch` gains `const DEPOT_RADIUS := 4.0`, `func is_near_depot() -> bool`, `func deliver_pony(uid: StringName) -> Dictionary`, `func pay_the_company(bits: int) -> int`, `func get_depot_menu() -> CanvasLayer`, `func crate_position() -> Vector3`.

**A delivery, step by step, and the invariant it must not break.** `deliver_pony(uid)` finds the pen holding her, calls `pen.release_body(uid, self)` to take her live body out of the pen without freeing it, drops her record from `GameState`, credits the ledger, marks a NAMED pony `PROCESSED` in the Compendium (a stock pony has no entry), renders a receipt letter as a toast, and calls `body.leave_toward(crate_position())`. She then walks there under her own `LEAVING` state and frees herself on arrival, in `Pony._state_leaving`, which remains the only line in the project that frees a pony. Nothing gruesome happens on screen: she walks into a crate and the crate closes.

**The Depot building.** A `Building` node under `Buildings` in `ranch.tscn`, at `Vector3(10, 0, 4)` with `rotation_degrees.y = -30`, `width = 6.0`, `depth = 4.5`, `wall_height = 3.0`, `ridge_height = 4.0`, `door_width = 3.0`, `wall_color = Color(0.62, 0.64, 0.68)`, `roof_color = Color(0.30, 0.34, 0.40)`. That point is 12.8 m from `Terrain.HOMESTEAD_CENTRE` and so inside the flat apron (`Terrain.FLAT_RADIUS` is 30), which is why it can sit at `y = 0` like the other four buildings; it is 11.0 m from the Farmhouse, 8.6 m from the Board and 8.5 m from the nearest plot slot, so it crowds nothing. A `Marker3D` child named `Crate` at local `Vector3(0, 0, 3.2)` is the loading dock, just outside the door.

- [ ] **Step 1: Write the failing tests**

Add to `game/test/test_pony.gd`:

```gdscript
func test_a_pony_can_be_sent_to_a_named_point_rather_than_merely_away() -> void:
	var pony: Pony = _pony_on_a_floor()  # the file's existing helper
	var crate := Vector3(6.0, 0.0, 0.0)
	assert_true(pony.leave_toward(crate))
	assert_true(pony.is_leaving())
	assert_eq(pony.state, Pony.State.LEAVING)


func test_she_frees_herself_on_reaching_the_crate() -> void:
	var pony: Pony = _pony_on_a_floor()
	var ghost := weakref(pony)
	pony.leave_toward(pony.global_position + Vector3(2.0, 0.0, 0.0))
	for i in 600:
		await wait_physics_frames(1)
		if ghost.get_ref() == null:
			break
	assert_null(ghost.get_ref(), "arriving at the crate is what ends the walk")


func test_a_held_pony_refuses_to_be_delivered() -> void:
	var pony: Pony = _pony_on_a_floor()
	pony.set_held(true)
	assert_false(pony.leave_toward(Vector3.ZERO), "capture wins over leaving, always")
	assert_ne(pony.state, Pony.State.LEAVING)
	pony.set_held(false)


func test_grabbing_a_pony_on_her_way_to_the_crate_cancels_the_walk() -> void:
	var pony: Pony = _pony_on_a_floor()
	pony.leave_toward(pony.global_position + Vector3(20.0, 0.0, 0.0))
	pony.set_held(true)
	assert_false(pony.is_leaving(), "the beam takes her out of LEAVING")
	pony.set_held(false)
	assert_false(pony.is_leaving(), "and puts her back into her own life, not back on the walk")


func test_a_plain_departure_still_walks_away_from_the_player() -> void:
	var pony: Pony = _pony_on_a_floor()
	assert_true(pony.leave())
	assert_true(pony.is_leaving())
```

Add to `game/test/test_pen.gd`:

```gdscript
func test_a_released_body_leaves_the_pen_alive_and_reparented() -> void:
	var pen: Pen = _pen(3)
	var host := Node3D.new()
	add_child_autofree(host)
	var inst := PonyInstance.create(&"stock_bold")
	inst.stock = {"coat": 1, "mane": 1, "eyes": 1}
	pen.add_pony(inst)
	var body: Node3D = pen.body_for(inst.uid)
	var where: Vector3 = body.global_position
	var released: Node3D = pen.release_body(inst.uid, host)
	assert_eq(released, body, "the same body, still alive")
	assert_true(is_instance_valid(released))
	assert_eq(released.get_parent(), host)
	assert_almost_eq(released.global_position, where, Vector3(0.01, 0.01, 0.01),
		"she is standing where she was standing")
	assert_null(pen.find_pony(inst.uid), "and the pen no longer has a record of her")
	assert_eq(pen.count(), 0)
	assert_eq(inst.home_slot, &"", "her address is cleared by the pen, as always")


func test_releasing_a_pony_who_is_not_here_answers_null_and_changes_nothing() -> void:
	var pen: Pen = _pen(3)
	var host := Node3D.new()
	add_child_autofree(host)
	assert_null(pen.release_body(&"nobody#000001", host))
	assert_eq(pen.count(), 0)


func test_a_padlocked_pen_makes_no_gems_and_keeps_its_ponies() -> void:
	var pen: Pen = _pen(3)
	var inst := PonyInstance.create(&"stock_shy")
	inst.happiness = 1.0
	pen.add_pony(inst)
	pen.set_padlocked(true)
	assert_eq(pen.tick(120.0), 0, "no gems until the balance is back under the ceiling")
	assert_eq(pen.count(), 1, "and nobody is taken")
	pen.set_padlocked(false)
	assert_gt(pen.tick(120.0), 0, "paying gives the pen back")
```

Add to `game/test/test_compendium.gd`:

```gdscript
func test_processed_is_above_caught_and_never_falls_back() -> void:
	var c := Compendium.new()
	c.mark_caught(&"trixie")
	assert_true(c.mark_processed(&"trixie"))
	assert_eq(c.state_of(&"trixie"), Compendium.State.PROCESSED)
	assert_false(c.mark_caught(&"trixie"), "a delivered pony is not un-delivered by a re-catch")
	assert_false(c.mark_seen(&"trixie"))


func test_a_pony_can_be_delivered_without_ever_being_marked_caught_first() -> void:
	var c := Compendium.new()
	assert_true(c.mark_processed(&"lyra"))
	assert_eq(c.state_of(&"lyra"), Compendium.State.PROCESSED)


func test_processed_round_trips_and_junk_still_does_not() -> void:
	var c := Compendium.new()
	c.mark_processed(&"lyra")
	assert_eq(Compendium.from_dict(c.to_dict()).state_of(&"lyra"),
		Compendium.State.PROCESSED)
	assert_eq(Compendium.from_dict({"lyra": 4}).state_of(&"lyra"),
		Compendium.State.UNSEEN, "a state this class never writes is dropped")
	assert_eq(Compendium.from_dict({"lyra": 2.5}).state_of(&"lyra"),
		Compendium.State.UNSEEN)
```

Create `game/test/test_letters.gd`:

```gdscript
extends GutTest
## The Company's stub sender: fixed, cheerful, corporate text with the player's name in it.

const LettersScript := preload("res://systems/letters.gd")

## A name of exactly MAX_NAME_LENGTH characters, in the widest glyph a name box will accept.
func _longest_legal_name() -> String:
	return "W".repeat(LettersScript.MAX_NAME_LENGTH)


func test_every_template_renders_with_the_longest_legal_name_without_overflow() -> void:
	var params := {"name": _longest_legal_name(), "count": 12, "credit": 4000,
		"pony": "Wwwwwwwwwwwwwwww", "quota": 2, "balance": 25000, "upkeep": 3150,
		"punishment": "a fee of 500 bits"}
	for id: int in LettersScript.ids():
		var letter: Dictionary = LettersScript.render(id, params)
		assert_false(String(letter["title"]).is_empty(), "letter %d has a title" % id)
		var body: Array = letter["body"]
		assert_gt(body.size(), 0, "letter %d has a body" % id)
		for line in body:
			assert_lte(String(line).length(), LettersScript.LINE_WIDTH,
				"letter %d overflows on line '%s'" % [id, line])


func test_no_letter_carries_a_dash_of_any_kind() -> void:
	var params := {"name": "Moonbeam", "count": 3, "credit": 300, "pony": "Trixie",
		"quota": 2, "balance": 25000, "upkeep": 3150, "punishment": "a fee of 500 bits"}
	for id: int in LettersScript.ids():
		var letter: Dictionary = LettersScript.render(id, params)
		var joined: String = String(letter["title"]) + "\n" + "\n".join(letter["body"])
		assert_false(joined.contains("--"), "letter %d carries a double hyphen" % id)
		assert_false(joined.contains(char(0x2014)), "letter %d carries an em dash" % id)


func test_a_receipt_names_the_player_and_the_shipment_number() -> void:
	var letter: Dictionary = LettersScript.render(LettersScript.Id.RECEIPT_STOCK,
		{"name": "Moonbeam", "count": 3, "credit": 300})
	var joined: String = "\n".join(letter["body"])
	assert_true(joined.contains("Moonbeam"))
	assert_true(joined.contains("3rd"), "the receipt counts her shipments for her")
	assert_true(joined.contains("300"))


func test_the_ordinal_suffixes_are_right_where_english_is_odd() -> void:
	assert_eq(LettersScript.ordinal(1), "1st")
	assert_eq(LettersScript.ordinal(2), "2nd")
	assert_eq(LettersScript.ordinal(3), "3rd")
	assert_eq(LettersScript.ordinal(4), "4th")
	assert_eq(LettersScript.ordinal(11), "11th")
	assert_eq(LettersScript.ordinal(12), "12th")
	assert_eq(LettersScript.ordinal(13), "13th")
	assert_eq(LettersScript.ordinal(21), "21st")
	assert_eq(LettersScript.ordinal(112), "112th")


func test_an_unknown_id_answers_an_empty_letter_rather_than_crashing() -> void:
	var letter: Dictionary = LettersScript.render(999, {})
	assert_eq(letter["body"], [])
```

Create `game/test/test_depot_menu.gd`:

```gdscript
extends GutTest
## The Depot menu draws and emits. It never touches the ledger, the wallet or the state.

const DepotMenuScene := preload("res://ui/depot_menu.tscn")
const LedgerScript := preload("res://systems/ledger.gd")

var _menu: DepotMenu = null


func before_each() -> void:
	_menu = DepotMenuScene.instantiate()
	add_child_autofree(_menu)
	_menu.can_open = func() -> bool: return true
	_menu.bits_provider = func() -> int: return 900
	_menu.rows_provider = func() -> Array[Dictionary]:
		var rows: Array[Dictionary] = []
		rows.append({"uid": &"stock_shy#000001", "name": "Pony", "stock": true, "credit": 300})
		rows.append({"uid": &"trixie#000002", "name": "Trixie", "stock": false, "credit": 4000})
		return rows
	_menu.statement_provider = func() -> Array[String]:
		return LedgerScript.new().statement_lines("Moonbeam", 1, 0, 2)


func test_it_opens_and_closes_and_reports_which_it_is() -> void:
	assert_false(_menu.is_open())
	assert_true(_menu.open())
	assert_true(_menu.is_open())
	_menu.close()
	assert_false(_menu.is_open())


func test_it_refuses_to_open_over_another_menu() -> void:
	_menu.can_open = func() -> bool: return false
	assert_false(_menu.open())
	assert_false(_menu.is_open())


func test_the_deliver_tab_lists_stock_first_then_named_with_their_credit() -> void:
	_menu.open()
	var rows: Array[Dictionary] = _menu.deliver_rows()
	assert_eq(rows.size(), 2)
	assert_true(bool(rows[0]["stock"]), "the crowd is offered first")
	assert_eq(int(rows[1]["credit"]), 4000)


func test_confirming_a_row_emits_the_uid_and_pays_for_nothing_itself() -> void:
	_menu.open()
	watch_signals(_menu)
	_menu.confirm()
	assert_signal_emitted_with_parameters(_menu, "deliver_requested", [&"stock_shy#000001"])


func test_the_pay_tab_offers_amounts_the_wallet_can_actually_cover() -> void:
	_menu.open()
	_menu.switch_tab(1)
	assert_eq(_menu.tab(), DepotMenu.Tab.PAY)
	for amount in _menu.pay_amounts():
		assert_lte(amount, 900, "the menu never offers to spend bits she does not have")
	assert_gt(_menu.pay_amounts().size(), 0)


func test_confirming_a_pay_row_emits_the_amount() -> void:
	_menu.open()
	_menu.switch_tab(1)
	watch_signals(_menu)
	var first: int = _menu.pay_amounts()[0]
	_menu.confirm()
	assert_signal_emitted_with_parameters(_menu, "pay_requested", [first])


func test_the_statement_tab_repeats_the_ledger_without_editing_it() -> void:
	_menu.open()
	_menu.switch_tab(2)
	assert_eq(_menu.tab(), DepotMenu.Tab.STATEMENT)
	var lines: Array[String] = _menu.statement_provider.call()
	assert_true("\n".join(lines).contains("Sponsorship balance"))


func test_no_string_the_menu_draws_carries_a_dash() -> void:
	_menu.open()
	for tab in [DepotMenu.Tab.DELIVER, DepotMenu.Tab.PAY, DepotMenu.Tab.STATEMENT]:
		_menu.set_tab(tab)
		for line in _menu.drawn_lines():
			assert_false(line.contains("--"), "'%s' carries a double hyphen" % line)
			assert_false(line.contains(char(0x2014)), "'%s' carries an em dash" % line)


func test_an_empty_pen_shows_a_note_rather_than_an_empty_box() -> void:
	_menu.rows_provider = func() -> Array[Dictionary]: return []
	_menu.open()
	assert_eq(_menu.deliver_rows().size(), 0)
	assert_true("\n".join(_menu.drawn_lines()).contains(DepotMenu.EMPTY_TEXT))
```

- [ ] **Step 2: Run the tests and watch them fail**

Run: `FILLY_SKIP_SWEEP=1 bash tools/run_tests.sh 2>&1 | tail -40`
Expected: `test_letters.gd` and `test_depot_menu.gd` reported as ignored (their preloads do not exist), plus failures naming `leave_toward`, `release_body`, `set_padlocked` and `mark_processed`.

- [ ] **Step 3: Give the departure path a destination (`game/actors/pony/pony.gd`)**

Beside `LEAVE_DISTANCE` and `LEAVE_SECONDS`:

```gdscript
## How near a delivered pony has to get to the crate before the walk is over. Wider than a
## pony is long, so an arrival is not a race between her steering and the frame rate.
const LEAVE_ARRIVAL_RADIUS := 1.2
```

Beside `_leave_direction`:

```gdscript
## Where she is walking TO, and whether there is anywhere in particular. An ordinary
## departure has no target: she walks away from the player and is discarded once she is out
## of his sight (see _state_leaving). A DELIVERY has one: the Depot crate. Same state, same
## walk, same single place in this project where a pony is ever freed. The Depot does not
## get a second way to remove a pony, because there must not be one.
var _leave_target := Vector3.ZERO
var _has_leave_target := false
```

`leave()` gains one line, and its sibling is added below it:

```gdscript
func leave() -> bool:
	if state == State.HELD:
		return false
	if state == State.LEAVING:
		return true
	_has_leave_target = false
	_leave_elapsed = 0.0
	_leave_direction = _away_from_player()
	_transition_to(State.LEAVING)
	return true


## THE DELIVERY WALK. She sets off for `point` and frees herself when she gets there,
## through exactly the same LEAVING state a runaway uses, so there is still only one way a
## pony leaves the world.
##
## REFUSED WHILE HELD, like leave(), and for the same reason: capture wins. A pony the
## player grabs on her way to the crate is taken out of LEAVING by set_held(true) and
## dropped back into IDLE by set_held(false), so a change of heart at the Depot door gives
## her back rather than sending her on.
##
## Re-targeting a pony who is ALREADY leaving is allowed and restarts her timer, so a crate
## that moves (it does not, today) or a second delivery order cannot strand her.
func leave_toward(point: Vector3) -> bool:
	if state == State.HELD:
		return false
	_leave_target = point
	_has_leave_target = true
	_leave_elapsed = 0.0
	_leave_direction = _toward_target()
	if state != State.LEAVING:
		_transition_to(State.LEAVING)
	return true
```

`_state_leaving` grows the arrival test:

```gdscript
func _state_leaving(delta: float) -> Vector3:
	_leave_elapsed += delta
	if _has_leave_target:
		var gap := Vector2(_leave_target.x - global_position.x,
			_leave_target.z - global_position.z).length()
		# The timer is still the ceiling: a pony who cannot reach the crate (a prop in the
		# way, a stuck step) is not left walking into a wall forever.
		if gap <= LEAVE_ARRIVAL_RADIUS or _leave_elapsed >= LEAVE_SECONDS:
			queue_free()
			return Vector3.ZERO
		_leave_direction = _toward_target()
		return _leave_direction * _flee_speed
	if _leave_distance() > LEAVE_DISTANCE or _leave_elapsed >= LEAVE_SECONDS:
		queue_free()
		return Vector3.ZERO
	if _leave_direction.length_squared() < 0.0001:
		_leave_direction = _away_from_player()
	return _leave_direction * _flee_speed


## The flat direction to her destination, or her current heading if she is standing on it.
func _toward_target() -> Vector3:
	var to := _leave_target - global_position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return _leave_direction if _leave_direction.length_squared() > 0.0001 else Vector3.FORWARD
	return to.normalized()
```

- [ ] **Step 4: Let a pen hand a body over (`game/world/pen.gd`)**

```gdscript
## THE DELIVERY DOOR. Take `uid` off the roster and hand her LIVE BODY to `new_parent`,
## keeping her exactly where she is standing. Returns the body, or null if she does not
## live here.
##
## NOTHING IS FREED. remove_pony() despawns the body, which is right for a pony who has
## gone into the saddlebag and wrong for a pony who is about to walk to the Depot crate
## under her own steam; this is the only other way out of a pen and it deliberately hands
## the caller a living pony and no way to skip the walk. The one line in this project that
## frees a pony is Pony._state_leaving.
##
## HER ADDRESS IS CLEARED HERE, as it is by remove_pony(), because this pen is no longer
## where she lives and a record filed in a pen that has no record of her is the two homes
## bug PonyInstance.home_slot's comment describes.
func release_body(uid: StringName, new_parent: Node3D) -> Node3D:
	var body: Node3D = _bodies.get(uid, null)
	var inst: PonyInstance = find_pony(uid)
	if body == null or not is_instance_valid(body) or inst == null or new_parent == null:
		return null
	var where: Transform3D = body.global_transform
	for i in _residents.size():
		if _residents[i].uid == uid:
			_residents.remove_at(i)
			break
	_bodies.erase(uid)
	_held_bodies.erase(uid)
	inst.home_slot = &""
	ProductionScript.forget(uid)
	body.get_parent().remove_child(body)
	new_parent.add_child(body)
	body.global_transform = where
	_reseat_released_residents()
	roster_changed.emit(count())
	return body
```

and the padlock, which Task 6 turns on:

```gdscript
## THE COLLECTOR'S PADLOCK (game/systems/ledger.gd). A padlocked pen makes no gems and
## keeps every one of its ponies: nothing is deleted, nothing is taken, and paying the
## balance down under the ceiling takes the lock straight back off. Needs and feeding still
## run, so a padlocked pony is not a starved one.
var _padlocked := false


func set_padlocked(value: bool) -> void:
	_padlocked = value


func is_padlocked() -> bool:
	return _padlocked
```

with `tick()` gaining one line, immediately after the needs and feeding calls inside the loop:

```gdscript
		var made := 0 if _padlocked else ProductionScript.tick(inst, delta)
```

(replacing `var made := ProductionScript.tick(inst, delta)`.)

- [ ] **Step 5: Add `PROCESSED` to `game/systems/compendium.gd`**

```gdscript
enum State { UNSEEN, SEEN, CAUGHT, PROCESSED }
```

with the class comment gaining a paragraph:

```
## PROCESSED IS WHAT THE COMPANY CALLS IT. A character the player has delivered to the
## Depot is PROCESSED: above CAUGHT, and reached by the same one way _raise(), so a pony
## delivered and then somehow caught again is still delivered. Before the story's fork the
## page renders it as "Delivered" with a smiley; after the fork the same state renders as a
## desaturated portrait and a yield percentage. One state, and only the words change.
```

the marker:

```gdscript
## Raise `id` to PROCESSED: she has been delivered to the Depot. Returns whether that
## happened. Never called for a stock pony, who has no entry at all.
func mark_processed(id: StringName) -> bool:
	return _raise(id, State.PROCESSED)
```

and one line in `from_dict()`:

```gdscript
		if state != State.SEEN and state != State.CAUGHT and state != State.PROCESSED:
			continue
```

In `game/ui/pause_menu.gd`, `compendium_header()` counts a delivered pony as caught (she was), and `_entry_value()` gains the PROCESSED row:

```gdscript
	var caught: int = compendium.count(CompendiumScript.State.CAUGHT, registry) \
		+ compendium.count(CompendiumScript.State.PROCESSED, registry)
```

```gdscript
	if compendium.state_of(data.id) == CompendiumScript.State.PROCESSED:
		# The Company's word for it, in the Company's tone, until the story teaches the
		# player what it means. See game/systems/compendium.gd.
		return "Delivered :)"
```

Add the matching assertion to `game/test/test_pause_menu.gd`:

```gdscript
func test_a_delivered_character_reads_as_delivered_and_still_counts_as_caught() -> void:
	var menu: PauseMenu = _menu()  # the file's existing helper
	var first: PonyData = menu.registry.all()[0]
	menu.compendium.mark_processed(first.id)
	assert_true(menu.compendium_header().contains("1 of"))
	assert_true("\n".join(menu.compendium_rows()).contains("Delivered :)"))
```

- [ ] **Step 6: Write `game/systems/letters.gd`**

```gdscript
class_name Letters
extends RefCounted
## THE COMPANY'S POST, AS A STUB. Slice 3 of this phase builds the mailbox, the Mail page
## and the StoryBeat resources that fill them; this is the fixed text slice 1 needs so that
## delivering a pony produces a receipt rather than a silence, and so that the creation
## screen can be tested against the promise that every letter renders with the longest name
## the name box will accept.
##
## THE REGISTER IS CHEERFUL CORPORATE. Company copy reads like an HR poster: exclamation
## marks, a thank you, a number that is slightly the wrong kind of number to be pleased
## about. It is funny for a long time. Nothing here is grim, and nothing here explains
## anything; the horror is that the player re-reads these later.
##
## Static only, no scene, no state. Every string here is player facing, so none of it
## carries an em dash or a double hyphen, and test_letters.gd asserts that rather than
## trusting it.

enum Id { WELCOME, RECEIPT_STOCK, RECEIPT_NAMED, QUOTA_REMINDER, COLLECTION_NOTICE,
	COLLECTOR_VISIT }

## The longest name the creation screen's name box accepts, and therefore the longest one
## every template below has to render inside LINE_WIDTH. Mirrored by
## PlayerLook.MAX_NAME_LENGTH, which is where the name box reads it from.
const MAX_NAME_LENGTH := 16

## The widest a rendered line may be. The Depot panel and the toast both wrap at this, so a
## template that overflows is a template that gets cut off on somebody's screen.
const LINE_WIDTH := 58

const SENDER := "Cloudsdale Weather Corporation"


static func ids() -> Array[int]:
	return [Id.WELCOME, Id.RECEIPT_STOCK, Id.RECEIPT_NAMED, Id.QUOTA_REMINDER,
		Id.COLLECTION_NOTICE, Id.COLLECTOR_VISIT]


## `params` may carry: name, count, credit, pony, quota, balance, upkeep, punishment.
## A missing one renders as its own placeholder rather than as an error, because a letter
## that fails to render is a letter the player never sees and never knows she missed.
static func render(id: int, params: Dictionary) -> Dictionary:
	var who: String = str(params.get("name", "Valued Partner"))
	var count: int = int(params.get("count", 1))
	var credit: int = int(params.get("credit", 0))
	var pony: String = str(params.get("pony", "a pony"))
	var quota: int = int(params.get("quota", 0))
	var balance: int = int(params.get("balance", 0))
	var upkeep: int = int(params.get("upkeep", 0))
	var punishment: String = str(params.get("punishment", "a courtesy visit"))

	match id:
		Id.WELCOME:
			return _letter("Welcome to the family!", [
				"Dear %s," % who,
				"",
				"Congratulations on your new ranch! Your sponsorship",
				"is active and your balance is %d bits." % balance,
				"Catch ponies, keep them happy, and bring us stock.",
				"Together we make the weather!",
				"",
				"Warmly, Sponsorship Services",
			])
		Id.RECEIPT_STOCK:
			return _letter("Shipment received", [
				"Dear %s," % who,
				"",
				"Your %s shipment! Cloudsdale thanks you." % ordinal(count),
				"Unregistered stock, condition: excellent.",
				"Credit applied to your balance: %d bits." % credit,
				"",
				"Keep up the great work!",
			])
		Id.RECEIPT_NAMED:
			return _letter("Shipment received, with thanks", [
				"Dear %s," % who,
				"",
				"Your %s shipment! What a find." % ordinal(count),
				"Registered arrival: %s." % pony,
				"Shipment quality: excellent. Yield: outstanding.",
				"Credit applied to your balance: %d bits." % credit,
				"",
				"You are in the top tier of partners this period!",
			])
		Id.QUOTA_REMINDER:
			return _letter("A friendly reminder", [
				"Dear %s," % who,
				"",
				"Just a note that %d ponies are expected this" % quota,
				"period, and we have %d so far. No pressure!" % count,
				"Partners who meet quota sleep so much better.",
				"",
				"Yours in weather, Sponsorship Services",
			])
		Id.COLLECTION_NOTICE:
			return _letter("Your statement is ready", [
				"Dear %s," % who,
				"",
				"Collection day! Upkeep of %d bits has been" % upkeep,
				"added to your account, along with the usual",
				"small service charge. Your balance is now",
				"%d bits. Thank you for choosing Cloudsdale!" % balance,
			])
		Id.COLLECTOR_VISIT:
			return _letter("A visit from your account manager", [
				"Dear %s," % who,
				"",
				"Our records show the last period fell short.",
				"An associate will call at dawn regarding",
				"%s." % punishment,
				"Everything is reversible! Simply pay, or ship.",
				"",
				"We know you will bounce right back.",
			])
	return _letter("", [])


static func _letter(title: String, body: Array) -> Dictionary:
	var lines: Array[String] = []
	for line in body:
		lines.append(String(line))
	return {"sender": SENDER, "title": title, "body": lines}


## "1st", "2nd", "3rd", "4th", and the three English exceptions in the teens. Public
## because the Depot toast counts shipments too, and two orderings of the same rule in two
## files is one of them being wrong.
static func ordinal(n: int) -> String:
	var tens: int = absi(n) % 100
	if tens >= 11 and tens <= 13:
		return "%dth" % n
	match absi(n) % 10:
		1:
			return "%dst" % n
		2:
			return "%dnd" % n
		3:
			return "%drd" % n
	return "%dth" % n
```

- [ ] **Step 7: Write `game/ui/depot_menu.gd` and `.tscn`**

The scene mirrors `game/ui/market_menu.tscn` exactly: a `CanvasLayer` with `Centre/Panel/Margin/Column/{Title, Tabs, Rows, Footer}`, `process_mode = PROCESS_MODE_ALWAYS`, hidden at rest. Copy that scene, rename the script, and set the title to "Depot".

```gdscript
class_name DepotMenu
extends CanvasLayer
## THE COMPANY'S COUNTER: deliver a pony, pay against the balance, read the statement.
##
## THE MENU DRAWS AND EMITS; ranch.gd TRANSACTS AND PAYS. This file never touches Ledger,
## Economy, GameState or a Pen. It is handed four Callables (what is in the pens, how many
## bits she has, what the statement says, and whether it may open at all) and it hands back
## two signals. That is the same split game/ui/market_menu.gd is built on, and it is what
## lets the whole of this be tested in milliseconds against four lambdas.
##
## Three tabs rather than three menus, because they are three questions about one account
## and the player is standing at one counter.

enum Tab { DELIVER, PAY, STATEMENT }

const TAB_NAMES: Array[String] = ["Deliver", "Pay", "Statement"]
const TITLE := "Depot"
const EMPTY_TEXT := "No ponies in your pens right now."
const FOOTER := "  up down  choose      left right  tab      Enter / A  confirm      Esc / B  leave"

## The amounts the Pay tab offers, before they are cut down to what she can afford and to
## what the ledger will accept.
const PAY_STEPS: Array[int] = [100, 500, 2000, 10000]

const COLOR_TITLE := Color(1.0, 0.96, 0.86, 1.0)
const COLOR_NAME := Color(1.0, 1.0, 1.0, 0.94)
const COLOR_DIM := Color(1.0, 1.0, 1.0, 0.58)
const COLOR_VALUE := Color(1.00, 0.80, 0.25, 1.0)

signal opened()
signal closed()
signal deliver_requested(uid: StringName)
signal pay_requested(bits: int)

## Injected by ranch.gd. Every one of them is a question this menu is not allowed to answer
## for itself.
var can_open := Callable()
var rows_provider := Callable()
var bits_provider := Callable()
var statement_provider := Callable()

var _tab: int = Tab.DELIVER
var _selected := 0
var _open := false

@onready var _title: Label = $Centre/Panel/Margin/Column/Title
@onready var _tabs: Label = $Centre/Panel/Margin/Column/Tabs
@onready var _rows: VBoxContainer = $Centre/Panel/Margin/Column/Rows
@onready var _footer: Label = $Centre/Panel/Margin/Column/Footer


func _ready() -> void:
	visible = false
	_title.text = TITLE
	_footer.text = FOOTER


func open() -> bool:
	if _open:
		return false
	if can_open.is_valid() and not can_open.call():
		return false
	_open = true
	_tab = Tab.DELIVER
	_selected = 0
	visible = true
	get_tree().paused = true
	refresh()
	opened.emit()
	return true


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	get_tree().paused = false
	closed.emit()


func is_open() -> bool:
	return _open


func tab() -> int:
	return _tab


func set_tab(value: int) -> void:
	_tab = clampi(value, Tab.DELIVER, Tab.STATEMENT)
	_selected = 0
	refresh()


func switch_tab(step: int) -> void:
	set_tab(posmod(_tab + step, Tab.STATEMENT + 1))


func selected_index() -> int:
	return _selected


func move_selection(step: int) -> void:
	var n: int = _row_count()
	if n <= 0:
		_selected = 0
		return
	_selected = posmod(_selected + step, n)
	refresh()


## The pens, as the Deliver tab shows them: stock first, then named, each with her credit.
## Sorted HERE rather than by the provider, so the tab's own promise ("stock first, then
## named, with their credit") is a property of this file and is tested against it.
func deliver_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if not rows_provider.is_valid():
		return rows
	for entry in rows_provider.call():
		rows.append(entry as Dictionary)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a["stock"]) != bool(b["stock"]):
			return bool(a["stock"])
		return int(a["credit"]) < int(b["credit"]))
	return rows


## The amounts the Pay tab offers: the steps above, cut to what is in the wallet, plus an
## "everything you have" row when that is more than the largest step. Never an amount she
## cannot cover, because a menu row that always refuses is a menu row that lies.
func pay_amounts() -> Array[int]:
	var bits: int = int(bits_provider.call()) if bits_provider.is_valid() else 0
	var out: Array[int] = []
	for step in PAY_STEPS:
		if step <= bits:
			out.append(step)
	if bits > 0 and (out.is_empty() or out[out.size() - 1] < bits):
		out.append(bits)
	return out


func confirm() -> bool:
	match _tab:
		Tab.DELIVER:
			var rows: Array[Dictionary] = deliver_rows()
			if _selected < 0 or _selected >= rows.size():
				return false
			deliver_requested.emit(StringName(rows[_selected]["uid"]))
			return true
		Tab.PAY:
			var amounts: Array[int] = pay_amounts()
			if _selected < 0 or _selected >= amounts.size():
				return false
			pay_requested.emit(amounts[_selected])
			return true
	return false


## Every line this menu is currently drawing, in order. For the tests, which otherwise have
## no way to ask whether a string carries a dash without walking the Label nodes.
func drawn_lines() -> Array[String]:
	var lines: Array[String] = []
	match _tab:
		Tab.DELIVER:
			var rows: Array[Dictionary] = deliver_rows()
			if rows.is_empty():
				lines.append(EMPTY_TEXT)
			for row in rows:
				lines.append("%s   %d bits" % [String(row["name"]), int(row["credit"])])
		Tab.PAY:
			var amounts: Array[int] = pay_amounts()
			if amounts.is_empty():
				lines.append("You have no bits to pay with today.")
			for amount in amounts:
				lines.append("Pay %d bits" % amount)
		Tab.STATEMENT:
			if statement_provider.is_valid():
				for line in statement_provider.call():
					lines.append(String(line))
	return lines


func refresh() -> void:
	if not is_node_ready():
		return
	_tabs.text = "   ".join(TAB_NAMES.map(func(t: String) -> String:
		return "[%s]" % t if TAB_NAMES.find(t) == _tab else " %s " % t))
	for child in _rows.get_children():
		child.queue_free()
	var lines: Array[String] = drawn_lines()
	for i in lines.size():
		var label := Label.new()
		label.text = ("> " if i == _selected and _tab != Tab.STATEMENT else "  ") + lines[i]
		label.add_theme_color_override("font_color",
			COLOR_VALUE if i == _selected and _tab != Tab.STATEMENT else COLOR_NAME)
		_rows.add_child(label)


func _row_count() -> int:
	match _tab:
		Tab.DELIVER:
			return deliver_rows().size()
		Tab.PAY:
			return pay_amounts().size()
	return 0


func _unhandled_input(event: InputEvent) -> void:
	if not _open or not event.is_pressed():
		return
	if event.is_action(&"ui_cancel"):
		close()
	elif event.is_action(&"ui_up"):
		move_selection(-1)
	elif event.is_action(&"ui_down"):
		move_selection(1)
	elif event.is_action(&"ui_left"):
		switch_tab(-1)
	elif event.is_action(&"ui_right"):
		switch_tab(1)
	elif event.is_action(&"ui_accept"):
		confirm()
	else:
		return
	get_viewport().set_input_as_handled()
```

- [ ] **Step 8: Stand the Depot and wire it (`game/world/ranch.tscn`, `game/world/ranch.gd`)**

In `ranch.tscn`, add under `Buildings` a `StaticBody3D` named `Depot` with `script = building.gd` and the exports listed at the top of this task, and a `Marker3D` child named `Crate` at `position = Vector3(0, 0, 3.2)`. Add a `DepotMenu` instance as a sibling of `MarketMenu`.

In `ranch.gd`, the constant, the `@onready`, and the preloads:

```gdscript
const LedgerScript := preload("res://systems/ledger.gd")
const LettersScript := preload("res://systems/letters.gd")
const StockPaletteScript := preload("res://systems/stock_palette.gd")

## How near the loading dock she has to be for E to open the Depot. Tighter than the
## Market's radius because the Depot is a smaller building on a busier corner of the yard.
const DEPOT_RADIUS := 4.0
```

```gdscript
@onready var depot_menu: CanvasLayer = $DepotMenu
```

`_no_menu_but()` gains `depot_menu` in its list, so the Depot cannot stack on the Market and vice versa. The binding, called from `_ready()` beside `_bind_market_menu()`:

```gdscript
func _bind_depot_menu() -> void:
	if depot_menu == null or not depot_menu.has_method("open"):
		return
	depot_menu.set("can_open", func() -> bool: return _no_menu_but(depot_menu))
	depot_menu.set("rows_provider", func() -> Array[Dictionary]: return _penned_rows())
	depot_menu.set("bits_provider", func() -> int: return _current_bits())
	depot_menu.set("statement_provider", func() -> Array[String]: return _statement())
	for pair in [["opened", _on_menu_opened_any], ["closed", _on_menu_closed],
			["deliver_requested", _on_deliver_requested],
			["pay_requested", _on_pay_requested]]:
		if not depot_menu.is_connected(pair[0], pair[1]):
			depot_menu.connect(pair[0], pair[1])


## `_on_menu_opened` takes a PlotSlot; the Depot's `opened` carries nothing, so it needs a
## nullary sibling rather than a bound lambda that would not compare equal on reconnect.
func _on_menu_opened_any() -> void:
	_on_menu_opened(null)


## What is standing in the pens, as the Depot lists it. Stock ponies and named ponies alike;
## the menu sorts and prices the rows, this only says who is here.
func _penned_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for slot in _plot_slots():
		var pen := slot.get_built() as Pen
		if pen == null:
			continue
		for inst: PonyInstance in pen.ponies():
			var data: PonyData = inst.data()
			var rarity: int = data.rarity if data != null else PonyDataScript.Rarity.COMMON
			rows.append({
				"uid": inst.uid,
				"name": inst.display_name(),
				"stock": inst.is_stock(),
				"credit": LedgerScript.delivery_credit(rarity, inst.is_stock()),
			})
	return rows


func _statement() -> Array[String]:
	if _game_state == null:
		return []
	var cycle: int = _world.cycle_index() if _world != null else 0
	return _game_state.ledger.statement_lines(_player_name(), _built_plot_count(),
		_open_permit_count(), cycle)


## What the player called herself at the creation screen. "Twilight" until Task 8 makes the
## screen; the whole of the Company's paperwork reads it from here so there is one answer.
func _player_name() -> String:
	return "Twilight"


func _built_plot_count() -> int:
	var n := 0
	for slot in _plot_slots():
		if not slot.is_empty():
			n += 1
	return n


func _open_permit_count() -> int:
	var n := 0
	for region: RegionData in _regions_registry().all():
		if is_region_open(region.id):
			n += 1
	return n


## The loading dock the delivered pony walks into, in world space, or the Depot's own origin
## if the marker is missing.
func crate_position() -> Vector3:
	var crate := get_node_or_null(^"Buildings/Depot/Crate") as Node3D
	if crate != null:
		return crate.global_position
	var depot := get_node_or_null(^"Buildings/Depot") as Node3D
	return depot.global_position if depot != null else Vector3.ZERO


func is_near_depot() -> bool:
	var depot := get_node_or_null(^"Buildings/Depot") as Node3D
	if depot == null:
		return false
	var gap := Vector2(player.global_position.x - depot.global_position.x,
		player.global_position.z - depot.global_position.z).length()
	return gap <= DEPOT_RADIUS


## E at the loading dock opens the Depot. Once per approach, the Market's and the board's
## rule, for the reason _update_plot_interaction() gives.
func _update_depot_interaction() -> void:
	if not _no_other_menu_open():
		return
	var near := is_near_depot()
	if near != _depot_prompted:
		_depot_prompted = near
		if near:
			_toast("Press E / X at the Depot.")
	if near and Input.is_action_just_pressed(&"interact") and _prompt_slot == null:
		if depot_menu != null and depot_menu.has_method("open"):
			depot_menu.open()
```

with `var _depot_prompted := false` beside `_market_prompted`, and a call to `_update_depot_interaction()` in `_physics_process` immediately after `_update_board_interaction()`.

The two transactions:

```gdscript
## DELIVER ONE PONY. Returns `{"ok": bool, "credit": int, "named": bool, "name": String}`,
## so a gate can assert on what happened rather than on a toast.
##
## THE ORDER MATTERS AND IS THE POINT. Her body comes out of the pen ALIVE
## (Pen.release_body), her record leaves the save, the ledger is credited, the book records
## her, the receipt is written, and only then is she pointed at the crate. She walks there
## herself and frees herself on arrival, in Pony._state_leaving, which stays the one line in
## this project that frees a pony. There is no branch here that removes her any other way,
## deliberately: NO PONY EVER DIES ON SCREEN, and nothing gruesome happens at the Depot.
func deliver_pony(uid: StringName) -> Dictionary:
	var refused := {"ok": false, "credit": 0, "named": false, "name": ""}
	if _game_state == null:
		return refused
	var pen: Pen = null
	var inst: PonyInstance = null
	for slot in _plot_slots():
		var candidate := slot.get_built() as Pen
		if candidate == null:
			continue
		var found: PonyInstance = candidate.find_pony(uid)
		if found != null:
			pen = candidate
			inst = found
			break
	if pen == null or inst == null:
		return refused

	var body: Node3D = pen.release_body(uid, self)
	if body == null:
		return refused
	_game_state.remove_pony(uid)

	var data: PonyData = inst.data()
	var rarity: int = data.rarity if data != null else PonyDataScript.Rarity.COMMON
	var credit: int = _game_state.ledger.credit_delivery(rarity, inst.is_stock())
	var named: bool = not inst.is_stock()
	if named:
		_game_state.compendium.mark_processed(inst.data_id)

	# credit_delivery() has already counted her, so the ledger's own running total IS the
	# number this receipt should carry.
	var shipments: int = _game_state.ledger.shipments
	var letter: Dictionary = LettersScript.render(
		LettersScript.Id.RECEIPT_NAMED if named else LettersScript.Id.RECEIPT_STOCK,
		{"name": _player_name(), "count": shipments, "credit": credit,
			"pony": inst.display_name()})
	_toast("%s: %s shipment received, %d bits credited."
		% [letter["sender"], LettersScript.ordinal(shipments), credit])

	body.leave_toward(crate_position())
	if depot_menu != null and depot_menu.has_method("refresh"):
		depot_menu.refresh()
	return {"ok": true, "credit": credit, "named": named, "name": inst.display_name()}


## PAY THE COMPANY. The ledger says how much it will accept (bits settle the service
## charges, not the principal), the wallet is debited by exactly that, and the difference is
## explained rather than silently swallowed. Returns what was actually paid.
func _on_pay_requested(bits: int) -> void:
	pay_the_company(bits)


func pay_the_company(bits: int) -> int:
	if _game_state == null or _economy == null:
		return 0
	var ledger: Ledger = _game_state.ledger
	var wanted: int = mini(bits, _economy.bits)
	var taken: int = ledger.pay(wanted)
	if taken <= 0:
		_toast("Bits settle the service charges. The principal is settled in stock.")
		return 0
	_economy.spend(taken)
	if taken < bits:
		_toast("Paid %d bits. That is as low as bits will take it; the rest is stock."
			% taken)
	else:
		_toast("Paid %d bits. Balance: %d." % [taken, ledger.balance])
	_relieve_if_paid_down()
	if depot_menu != null and depot_menu.has_method("refresh"):
		depot_menu.refresh()
	return taken


func _on_deliver_requested(uid: StringName) -> void:
	deliver_pony(uid)
```

`_relieve_if_paid_down()` is written in Task 6; add it in this task as a stub that Task 6 fills, and DO NOT leave it empty: this task's version is the whole of the relief that exists so far.

```gdscript
## Give back whatever the balance being under the ceiling entitles her to. Task 6 adds the
## permits, the padlocks and the beam; today the ledger's own bookkeeping is all there is,
## and calling it here is what makes those arrive with no edit at this call site.
func _relieve_if_paid_down() -> void:
	if _game_state == null:
		return
	var given: Dictionary = _game_state.ledger.relieve()
	if given.is_empty():
		return
	_toast("Your account is in good standing again. Cloudsdale thanks you!")
```

Finally, `_report()` gains the Depot's checks:

```gdscript
	_set_check(checks, "the Depot stands", get_node_or_null(^"Buildings/Depot") != null)
	_set_check(checks, "the Depot has a crate to walk into",
		get_node_or_null(^"Buildings/Depot/Crate") != null)
	_set_check(checks, "the ranch built a ledger",
		_game_state != null and _game_state.ledger != null)
	print("RANCH ledger balance=%d quota=%d delivered=%d tier=%d" % [
		_game_state.ledger.balance, _game_state.ledger.quota,
		_game_state.ledger.delivered_this_period, _game_state.ledger.tier])
```

- [ ] **Step 9: Run the tests and the gates**

Run: `bash tools/run_tests.sh 2>&1 | tail -25`
Expected: `---- All tests passed! ----`, exit 0.

Run: `tools/bin/godot --headless --audio-driver Dummy --path game world/ranch.tscn`
Expected: `RANCH ledger balance=25000 quota=2 delivered=0 tier=0` and `RANCH_OK ponies=49 props=59 assets=present` (props is one higher: `expected_props` counts `buildings.get_child_count()`), exit 0.

Run the four hosted gates as in Task 2, Step 7.
Expected: all green.

- [ ] **Step 10: Commit**

```bash
printf 'feat: the Depot; deliver, pay, and a statement made out to you\n\nA delivered pony walks to the crate on the one departure path there has ever\nbeen: Pen.release_body hands her body over alive, Pony.leave_toward points her\nat the dock, and Pony._state_leaving is still the only line that frees a pony.\nA named delivery marks her PROCESSED, which reads as Delivered with a smiley\nuntil the story teaches the player otherwise. Letters is the stub sender.\n' > /tmp/msg.txt
git add game/systems/letters.gd game/systems/letters.gd.uid \
  game/systems/compendium.gd game/ui/depot_menu.gd game/ui/depot_menu.gd.uid \
  game/ui/depot_menu.tscn game/ui/pause_menu.gd \
  game/actors/pony/pony.gd game/world/pen.gd game/world/ranch.gd game/world/ranch.tscn \
  game/test/test_pony.gd game/test/test_pen.gd game/test/test_compendium.gd \
  game/test/test_letters.gd game/test/test_letters.gd.uid \
  game/test/test_depot_menu.gd game/test/test_depot_menu.gd.uid \
  game/test/test_pause_menu.gd
git commit -F /tmp/msg.txt
```

---

### Task 6: Collectors. The ladder, served at dawn, and taken back by paying

**Files:**
- Modify: `game/world/ranch.gd`, `game/actors/player/magic_beam.gd`, `game/ui/hud.gd`, `game/ui/hud.tscn`
- Test: `game/test/test_magic_beam.gd`, `game/test/test_hud.gd`

**Interfaces:**
- Consumes: `Ledger.run_collection_day`, `Ledger.take_pending_punishment`, `Ledger.relieve`, `Ledger.beam_is_recalled`, `Ledger.Punishment` (Task 4); `Pen.set_padlocked` (Task 5); `Shop.permit_id_for`.
- Produces:
  - `MagicBeam` gains `func set_recalled(value: bool) -> void` and `func is_recalled() -> bool`. While recalled the beam refuses to start and drops anything it is holding by RELEASING it, never by freeing it.
  - `Ranch` gains `func run_collection_day() -> Dictionary`, `func serve_collector() -> int`, and the private `_on_world_cycle_changed`. `_relieve_if_paid_down()` (stubbed in Task 5) is completed here.
  - `HUD` gains `func set_balance(total: int) -> void` and `func get_balance_text() -> String`, drawing the line `CWC balance: %d bits` from a new `$Bag/Balance` Label.

**When the collection day runs.** `WorldState` emits `phase_changed`; `ranch._on_world_changed()` already handles it. The collection day fires on the first `phase_changed` of a cycle whose index is a collection cycle, and the collector calls at the next DAWN, which is the phase change after it. Both are guarded by the ledger's own state so a mid session load, a pinned clock or two phase changes in one frame cannot serve one collector twice: `run_collection_day` is called at most once per cycle index (`_last_collection_cycle`), and `take_pending_punishment()` answers `NONE` on its second call.

- [ ] **Step 1: Write the failing tests**

Add to `game/test/test_magic_beam.gd`:

```gdscript
func test_a_recalled_beam_refuses_to_start() -> void:
	var beam: MagicBeam = _beam()
	assert_false(beam.is_recalled())
	beam.set_recalled(true)
	assert_true(beam.is_recalled())
	beam._start_beam()
	assert_false(beam.is_active(), "the horn is recalled; nothing comes out of it")


func test_the_beam_comes_back_and_works() -> void:
	var beam: MagicBeam = _beam()
	beam.set_recalled(true)
	beam.set_recalled(false)
	beam._start_beam()
	assert_true(beam.is_active())


func test_recalling_a_beam_that_is_holding_a_pony_releases_her_rather_than_losing_her() -> void:
	var beam: MagicBeam = _beam()
	var pony: Pony = PonyScene.instantiate()
	add_child_autofree(pony)
	pony.setup(_named_data())
	var ghost := weakref(pony)
	beam._begin_hold(pony)  # the file's existing helper for putting a pony in the beam
	beam.set_recalled(true)
	assert_false(beam.is_holding(), "she is put down, not vanished")
	assert_not_null(ghost.get_ref(), "NO PONY EVER DIES; a recall is not a way to remove one")
```

Add to `game/test/test_hud.gd`:

```gdscript
func test_the_hud_shows_the_company_balance() -> void:
	var hud: HUD = _hud()  # the file's existing helper
	hud.set_balance(25000)
	assert_eq(hud.get_balance_text(), "CWC balance: 25000 bits")
	assert_false(hud.get_balance_text().contains("--"))


func test_a_negative_balance_reads_as_credit_rather_than_as_a_minus_sign() -> void:
	var hud: HUD = _hud()
	hud.set_balance(-400)
	assert_eq(hud.get_balance_text(), "CWC balance: 400 bits in credit")
```

- [ ] **Step 2: Run the tests and watch them fail**

Run: `FILLY_SKIP_SWEEP=1 bash tools/run_tests.sh 2>&1 | tail -30`
Expected: failures naming `set_recalled` and `set_balance` as missing methods.

- [ ] **Step 3: The recall (`game/actors/player/magic_beam.gd`)**

Beside `_beaming`:

```gdscript
## Whether the Company has "recalled" the horn (game/systems/ledger.gd's collector ladder).
## A recalled beam will not start, and a recall while she is holding somebody puts that pony
## DOWN through the ordinary release path. It is a punishment, and every punishment in this
## game is reversible and takes nothing away: the pony is still there, the bag is still
## full, and paying the balance down hands the horn straight back.
var _recalled := false


func set_recalled(value: bool) -> void:
	if _recalled == value:
		return
	_recalled = value
	if not _recalled:
		return
	if is_holding():
		release()
	_beaming = false


func is_recalled() -> bool:
	return _recalled
```

and one line at the top of `_start_beam()`:

```gdscript
	if _recalled:
		return
```

(`release()` is the beam's existing "set her down where she is floating" path; it never frees a pony.)

- [ ] **Step 4: The balance line (`game/ui/hud.gd`, `game/ui/hud.tscn`)**

Add a `Label` named `Balance` under `$Bag`, below `Bits`, and:

```gdscript
@onready var _balance: Label = $Bag/Balance
```

```gdscript
## The Company's account, on screen from minute one and never hidden. Shown beside the
## wallet on purpose: the two numbers are the whole of the game's tension and reading one
## without the other is what lets a player feel rich.
func set_balance(total: int) -> void:
	_balance.text = _balance_text(total)


func get_balance_text() -> String:
	return _balance.text


## A NEGATIVE BALANCE IS CREDIT, AND SAYS SO. A minus sign in front of a debt is the one
## place a player will misread this number, and a delivered legendary really can push it
## under zero.
static func _balance_text(total: int) -> String:
	if total < 0:
		return "CWC balance: %d bits in credit" % absi(total)
	return "CWC balance: %d bits" % total
```

with `_style_label(_balance, 16, COLOR_WORLD_LINE)` beside the other label styling in `_ready()`.

- [ ] **Step 5: The collection day and the collector (`game/world/ranch.gd`)**

Add the state:

```gdscript
## The last cycle index a collection day was run for, so a phase change that fires twice,
## a mid session load, or a pinned clock cannot bill the player twice for one period.
var _last_collection_cycle := -1

## True while a collector is owed a visit at the next dawn.
var _collector_due := false
```

Hook it into `_on_world_changed()`, which already runs on both `phase_changed` and `weather_changed`, immediately after the herd refresh:

```gdscript
	_maybe_run_collection_day()
	_maybe_serve_collector()
```

```gdscript
## COLLECTION DAY, ONCE PER PERIOD. Every third cycle, on the first phase change inside it,
## the upkeep and the service charge land on the balance and the period's quota is judged.
## The collector the judgement arms does NOT call now; he calls at the next dawn, which is
## what makes the letter arrive before the knock.
func _maybe_run_collection_day() -> void:
	if _game_state == null or _world == null:
		return
	var cycle: int = _world.cycle_index()
	if not LedgerScript.is_collection_cycle(cycle) or cycle == _last_collection_cycle:
		return
	_last_collection_cycle = cycle
	var summary: Dictionary = run_collection_day()
	if int(summary["punishment"]) != LedgerScript.Punishment.NONE:
		_collector_due = true


func run_collection_day() -> Dictionary:
	var ledger: Ledger = _game_state.ledger
	var cycle: int = _world.cycle_index() if _world != null else 0
	var summary: Dictionary = ledger.run_collection_day(cycle, _built_plot_count(),
		_open_permit_count())
	var letter: Dictionary = LettersScript.render(LettersScript.Id.COLLECTION_NOTICE, {
		"name": _player_name(), "balance": int(summary["balance"]),
		"upkeep": int(summary["upkeep"])})
	_toast("%s. Balance: %d bits." % [letter["title"], int(summary["balance"])])
	if not bool(summary["quota_met"]):
		_toast("Quota: %d of %d delivered. An associate will call at dawn."
			% [int(summary["delivered"]), int(summary["quota"])])
	_push_balance()
	return summary


## THE COLLECTOR CALLS. One rung of the ladder, served once, at the next dawn after a
## period that fell short. Every rung is reversible and none of them takes a pony:
## a fee is bits, a revoked permit is a fence that closes over ponies who stay exactly where
## they are, a padlock is a pen that makes no gems, and a recall is a horn she gets back
## next cycle. Returns which rung was served, for the gates.
func serve_collector() -> int:
	if _game_state == null:
		return LedgerScript.Punishment.NONE
	var ledger: Ledger = _game_state.ledger
	var punishment: int = ledger.take_pending_punishment()
	match punishment:
		LedgerScript.Punishment.FEE:
			var fee: int = LedgerScript.COLLECTOR_FEE
			if _economy != null and _economy.can_afford(fee):
				_economy.spend(fee)
				_toast("An associate called: a service fee of %d bits. Have a lovely day!"
					% fee)
			else:
				# She cannot pay it, so it goes on the account. Nothing is confiscated.
				ledger.balance += fee
				_toast("An associate called: %d bits added to your balance. No trouble at all!"
					% fee)
		LedgerScript.Punishment.PERMIT_REVOKED:
			var permit: StringName = _dearest_open_permit()
			if permit != &"":
				ledger.revoked_permits.append(String(permit))
				_game_state.unlocks.erase(String(permit))
				_apply_permits()
				_toast("An associate called: one permit is under review. Pay to resume access.")
		LedgerScript.Punishment.PEN_PADLOCKED:
			var slot_id: StringName = _fullest_pen_slot()
			if slot_id != &"":
				ledger.padlocked_slots.append(String(slot_id))
				_apply_padlocks()
				_toast("An associate called: one pen is sealed pending payment. Everyone inside is fine!")
		LedgerScript.Punishment.BEAM_RECALLED:
			var cycle: int = _world.cycle_index() if _world != null else 0
			ledger.beam_recalled_until = cycle + LedgerScript.BEAM_RECALL_CYCLES
			_apply_beam_recall()
			_toast("An associate called: your horn licence is suspended for one cycle.")
	if punishment != LedgerScript.Punishment.NONE:
		var letter: Dictionary = LettersScript.render(LettersScript.Id.COLLECTOR_VISIT, {
			"name": _player_name(), "punishment": _punishment_phrase(punishment)})
		_toast(String(letter["title"]))
	_push_balance()
	return punishment


func _maybe_serve_collector() -> void:
	if _world == null:
		return
	# The beam's recall expires on its own clock, so this is asked at every phase change and
	# not only at dawn.
	_apply_beam_recall()
	if not _collector_due or _world.phase() != WorldStateScript.Phase.DAWN:
		return
	_collector_due = false
	serve_collector()


static func _punishment_phrase(punishment: int) -> String:
	match punishment:
		LedgerScript.Punishment.FEE:
			return "a service fee"
		LedgerScript.Punishment.PERMIT_REVOKED:
			return "a permit under review"
		LedgerScript.Punishment.PEN_PADLOCKED:
			return "a sealed pen"
		LedgerScript.Punishment.BEAM_RECALLED:
			return "a suspended horn licence"
	return "a courtesy visit"


## The most expensive permit she currently holds. The dearest one, so the punishment is felt
## rather than shrugged off, and so it is obvious which fence closed.
func _dearest_open_permit() -> StringName:
	var best: StringName = &""
	var best_cost := -1
	for region: RegionData in _regions_registry().all():
		if not is_region_open(region.id):
			continue
		if region.permit_cost > best_cost:
			best_cost = region.permit_cost
			best = ShopScript.permit_id_for(region.id)
	return best


## The slot id of the pen with the most ponies in it that is not already padlocked.
func _fullest_pen_slot() -> StringName:
	var best: StringName = &""
	var most := -1
	for slot in _plot_slots():
		var pen := slot.get_built() as Pen
		if pen == null or pen.is_padlocked():
			continue
		if pen.count() > most:
			most = pen.count()
			best = slot.slot_id
	return best


## Push the ledger's padlock list onto the pens. Absolute rather than incremental, the way
## _apply_permits() and _apply_unlocks() are: a pen not on the list is not padlocked, so a
## load, a relief and a collector all reach the same state from the same one function.
func _apply_padlocks() -> void:
	if _game_state == null:
		return
	var locked: Array = _game_state.ledger.padlocked_slots
	for slot in _plot_slots():
		var pen := slot.get_built() as Pen
		if pen != null:
			pen.set_padlocked(String(slot.slot_id) in locked)


## Same shape for the horn.
func _apply_beam_recall() -> void:
	if _game_state == null:
		return
	var beam: Node3D = player.get_magic_beam()
	if beam == null or not beam.has_method("set_recalled"):
		return
	var cycle: int = _world.cycle_index() if _world != null else 0
	beam.call("set_recalled", _game_state.ledger.beam_is_recalled(cycle))


func _push_balance() -> void:
	var hud := get_node_or_null(^"HUD")
	if hud != null and hud.has_method("set_balance") and _game_state != null:
		hud.call("set_balance", _game_state.ledger.balance)
```

Complete `_relieve_if_paid_down()`, replacing the Task 5 body:

```gdscript
## GIVE EVERYTHING BACK once the balance is under the ceiling. Called after every payment
## and after every delivery, because either can be what brings her back into good standing.
func _relieve_if_paid_down() -> void:
	if _game_state == null:
		return
	var given: Dictionary = _game_state.ledger.relieve()
	if given.is_empty():
		return
	for permit in given.get("permits", []):
		if not String(permit) in _game_state.unlocks:
			_game_state.unlocks.append(String(permit))
	_apply_permits()
	_apply_padlocks()
	_apply_beam_recall()
	_toast("Your account is in good standing again. Cloudsdale thanks you!")
```

and call it at the end of `deliver_pony()` (just before the `return`), because a delivery is the other thing that can bring her under the ceiling.

Finally, `_apply_padlocks()`, `_apply_beam_recall()` and `_push_balance()` are called from `rebind_economy()` so a load reaches the same state, and `_push_balance()` is also connected to the ledger:

```gdscript
	if _game_state != null and not _game_state.ledger.changed.is_connected(_on_balance_changed):
		_game_state.ledger.changed.connect(_on_balance_changed)
	_apply_padlocks()
	_apply_beam_recall()
	_push_balance()
```

```gdscript
func _on_balance_changed(_balance: int) -> void:
	_push_balance()
```

- [ ] **Step 6: Run the tests and the gates**

Run: `bash tools/run_tests.sh 2>&1 | tail -25`
Expected: `---- All tests passed! ----`, exit 0.

Run: `tools/bin/godot --headless --audio-driver Dummy --path game world/ranch.tscn`
Expected: `RANCH_OK ponies=49 props=59 assets=present`, exit 0.

Run: `tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/capture_test.tscn`
Expected: `CAPTURE_OK ...`, exit 0. A fresh ranch is never recalled, so the beam behaves exactly as it did.

- [ ] **Step 7: Commit**

```bash
printf 'feat: collectors; the ladder is served at dawn and taken back by paying\n\nA collection day every third cycle bills the upkeep and the service charge and\njudges the quota; the collector it arms calls at the next dawn with a fee, a\npermit under review, a sealed pen or a suspended horn licence, in that order.\nNothing is deleted and no pony is taken: paying the balance under the ceiling\nhands every one of them straight back. The HUD shows the CWC balance.\n' > /tmp/msg.txt
git add game/world/ranch.gd game/actors/player/magic_beam.gd game/ui/hud.gd \
  game/ui/hud.tscn game/test/test_magic_beam.gd game/test/test_hud.gd
git commit -F /tmp/msg.txt
```

---

### Task 7: The cutie mark. A canvas she paints, and two flanks that wear it

**Files:**
- Create: `game/systems/mark_paint.gd`, `game/systems/mark_stamps.gd`, `game/systems/cutie_mark.gd`, `game/ui/mark_canvas.gd`, `game/ui/mark_canvas.tscn`
- Test: `game/test/test_mark_paint.gd`, `game/test/test_mark_stamps.gd`, `game/test/test_cutie_mark.gd`, `game/test/test_mark_canvas.gd`

**Interfaces:**
- Consumes: `PonyVisuals.build(data)` and the base model from Task 1.
- Produces:
  - `class_name MarkPaint extends RefCounted`, static only. `const SIZE := 64`; `const FORMAT := Image.FORMAT_RGBA8`; `const BRUSHES: Array[int] = [1, 2, 4, 8]` (radii in pixels). `static func blank() -> Image`, `static func dot(image: Image, at: Vector2i, colour: Color, radius: int) -> void`, `static func stroke(image: Image, from: Vector2i, to: Vector2i, colour: Color, radius: int) -> void`, `static func clear(image: Image) -> void`, `static func equal(a: Image, b: Image) -> bool`, `static func is_blank(image: Image) -> bool`, `static func copy_of(image: Image) -> Image`.
  - `class_name MarkStamps extends RefCounted`, static only. `enum Stamp { STAR, HEART, APPLE, CLOUD, FLOWER, GEM }`; `static func ids() -> Array[int]`; `static func stamp_name(id: int) -> String`; `static func build(id: int, colour: Color) -> Image`.
  - `class_name CutieMark extends RefCounted`, static only. `const LEFT_NAME := &"CutieMarkLeft"`, `const RIGHT_NAME := &"CutieMarkRight"`, `const BONE_NAMES: Array[StringName] = [&"Pelvis", &"Chest1"]`, `const FLANK := Vector3(0.26, 0.86, 0.22)`, `const DECAL_SIZE := Vector3(0.30, 0.26, 0.30)`. `static func apply(model: Node3D, mark: Image) -> int` returning how many flanks were marked (0 or 2), `static func decals_of(model: Node3D) -> Array[Decal]`, `static func clear(model: Node3D) -> void`.
  - `class_name MarkCanvas extends Control` with `signal changed()`; `func image() -> Image` (a copy), `func set_image(source: Image) -> void`, `func set_colour(colour: Color) -> void`, `func set_brush(radius: int) -> void`, `func set_eraser(on: bool) -> void`, `func stamp(id: int) -> void`, `func undo() -> bool`, `func clear_all() -> void`, `func paint_at(point: Vector2) -> void` and `func drag_to(point: Vector2) -> void` (canvas local coordinates, which is what makes the widget drivable from a test with no mouse).

**How a flank takes a texture, verified against the actual model.** The base model has no spare UV island and no overlay surface, so the mark is projected rather than painted into the albedo: two `Decal` nodes, one per flank. Each hangs off a `BoneAttachment3D` bound to the `Pelvis` bone (`Chest1` is the fallback, and the model root is the last resort), so it follows the haunch through the walk cycle instead of sliding off it. `Decal` needs the Forward+ renderer, which `game/project.godot` already declares (`config/features=PackedStringArray("4.5", "Forward Plus")`).

The placement is computed in MODEL space and converted into the attachment's local space, because the bone's rest orientation is not something this plan can state and does not have to be:

```
target_basis = Basis(Vector3(0, 0, -1), Vector3(side, 0, 0), Vector3(0, 1, 0)) for the +X flank
```
which points the decal's projection axis (its local -Y) inward along -X, so the box projects onto the flank from just outside it. `FLANK` is `(0.26, 0.86, 0.22)`: the body mesh spans x in [-0.238, 0.238], so 0.26 puts the box just clear of the surface; y 0.86 is mid barrel between 0.459 and 1.164; z 0.22 is the haunch, the tail end of a model whose tail sits at +z. `DECAL_SIZE` is 0.30 across, 0.26 deep and 0.30 tall, shallow enough that the left flank's decal cannot reach the right flank through the barrel.

- [ ] **Step 1: Write the failing tests**

`game/test/test_mark_paint.gd`:

```gdscript
extends GutTest
## The pixels under the cutie mark canvas. No Control, no mouse, no scene.

const MarkPaintScript := preload("res://systems/mark_paint.gd")


func test_a_blank_mark_is_sixty_four_square_and_fully_transparent() -> void:
	var image: Image = MarkPaintScript.blank()
	assert_eq(image.get_width(), MarkPaintScript.SIZE)
	assert_eq(image.get_height(), MarkPaintScript.SIZE)
	assert_eq(image.get_format(), MarkPaintScript.FORMAT)
	assert_true(MarkPaintScript.is_blank(image))
	assert_eq(image.get_pixel(0, 0).a, 0.0)


func test_a_dot_lands_where_it_is_put_and_nowhere_else() -> void:
	var image: Image = MarkPaintScript.blank()
	MarkPaintScript.dot(image, Vector2i(32, 32), Color.RED, 2)
	assert_eq(image.get_pixel(32, 32), Color.RED)
	assert_eq(image.get_pixel(32, 34), Color.RED, "the radius is inclusive")
	assert_eq(image.get_pixel(32, 36).a, 0.0, "and it stops")
	assert_false(MarkPaintScript.is_blank(image))


func test_a_dot_at_the_edge_is_clipped_rather_than_wrapped() -> void:
	var image: Image = MarkPaintScript.blank()
	MarkPaintScript.dot(image, Vector2i(0, 0), Color.BLUE, 4)
	assert_eq(image.get_pixel(0, 0), Color.BLUE)
	assert_eq(image.get_pixel(MarkPaintScript.SIZE - 1, MarkPaintScript.SIZE - 1).a, 0.0,
		"a brush off the left edge must not appear on the right one")


func test_a_dot_entirely_outside_the_canvas_changes_nothing() -> void:
	var image: Image = MarkPaintScript.blank()
	MarkPaintScript.dot(image, Vector2i(-40, 200), Color.BLUE, 2)
	assert_true(MarkPaintScript.is_blank(image))


func test_a_stroke_paints_every_pixel_between_its_ends() -> void:
	var image: Image = MarkPaintScript.blank()
	MarkPaintScript.stroke(image, Vector2i(10, 10), Vector2i(50, 10), Color.GREEN, 1)
	for x in range(10, 51):
		assert_eq(image.get_pixel(x, 10), Color.GREEN, "gap at x=%d" % x)
	assert_eq(image.get_pixel(9, 10).a, 0.0)


func test_a_diagonal_stroke_leaves_no_gaps() -> void:
	var image: Image = MarkPaintScript.blank()
	MarkPaintScript.stroke(image, Vector2i(4, 4), Vector2i(60, 40), Color.BLACK, 1)
	var painted := 0
	for y in MarkPaintScript.SIZE:
		var row := false
		for x in MarkPaintScript.SIZE:
			if image.get_pixel(x, y).a > 0.0:
				row = true
		if row:
			painted += 1
	assert_eq(painted, 39, "every row the line crosses has ink in it")


func test_the_eraser_is_a_stroke_of_full_transparency() -> void:
	var image: Image = MarkPaintScript.blank()
	MarkPaintScript.dot(image, Vector2i(32, 32), Color.RED, 4)
	MarkPaintScript.dot(image, Vector2i(32, 32), Color(0, 0, 0, 0), 4)
	assert_true(MarkPaintScript.is_blank(image))


func test_clear_empties_the_whole_canvas() -> void:
	var image: Image = MarkPaintScript.blank()
	MarkPaintScript.stroke(image, Vector2i(0, 0), Vector2i(63, 63), Color.RED, 8)
	MarkPaintScript.clear(image)
	assert_true(MarkPaintScript.is_blank(image))


func test_two_images_compare_pixel_by_pixel() -> void:
	var a: Image = MarkPaintScript.blank()
	var b: Image = MarkPaintScript.blank()
	assert_true(MarkPaintScript.equal(a, b))
	MarkPaintScript.dot(b, Vector2i(1, 1), Color.RED, 0)
	assert_false(MarkPaintScript.equal(a, b))
	assert_false(MarkPaintScript.equal(a, null))


func test_a_copy_is_independent_of_its_original() -> void:
	var a: Image = MarkPaintScript.blank()
	var b: Image = MarkPaintScript.copy_of(a)
	MarkPaintScript.dot(b, Vector2i(5, 5), Color.RED, 1)
	assert_true(MarkPaintScript.is_blank(a), "the undo stack must not share pixels with the canvas")
```

`game/test/test_mark_stamps.gd`:

```gdscript
extends GutTest

const MarkStampsScript := preload("res://systems/mark_stamps.gd")
const MarkPaintScript := preload("res://systems/mark_paint.gd")


func test_every_stamp_draws_something_and_is_the_canvas_size() -> void:
	for id: int in MarkStampsScript.ids():
		var image: Image = MarkStampsScript.build(id, Color.RED)
		assert_eq(image.get_width(), MarkPaintScript.SIZE, "stamp %d" % id)
		assert_false(MarkPaintScript.is_blank(image), "stamp %d drew nothing" % id)


func test_every_stamp_has_a_name_with_no_dash_in_it() -> void:
	for id: int in MarkStampsScript.ids():
		var text: String = MarkStampsScript.stamp_name(id)
		assert_false(text.is_empty())
		assert_false(text.contains("--"))
		assert_false(text.contains(char(0x2014)))


func test_a_stamp_is_drawn_in_the_colour_it_is_asked_for() -> void:
	var image: Image = MarkStampsScript.build(MarkStampsScript.Stamp.STAR, Color.BLUE)
	var found := false
	for y in MarkPaintScript.SIZE:
		for x in MarkPaintScript.SIZE:
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a > 0.0:
				assert_eq(pixel, Color.BLUE)
				found = true
	assert_true(found)


func test_stamps_differ_from_one_another() -> void:
	var star: Image = MarkStampsScript.build(MarkStampsScript.Stamp.STAR, Color.RED)
	var heart: Image = MarkStampsScript.build(MarkStampsScript.Stamp.HEART, Color.RED)
	assert_false(MarkPaintScript.equal(star, heart))


func test_an_unknown_stamp_answers_a_blank_canvas_rather_than_crashing() -> void:
	assert_true(MarkPaintScript.is_blank(MarkStampsScript.build(99, Color.RED)))
```

`game/test/test_cutie_mark.gd`:

```gdscript
extends GutTest
## The mark on the model. Structural: headless renders nothing, so this asserts the nodes,
## the texture and where in the world they sit.

const CutieMarkScript := preload("res://systems/cutie_mark.gd")
const MarkPaintScript := preload("res://systems/mark_paint.gd")
const MarkStampsScript := preload("res://systems/mark_stamps.gd")
const StockPaletteScript := preload("res://systems/stock_palette.gd")
const PonyRegistryScript := preload("res://systems/pony_registry.gd")
const PonyVisualsScript := preload("res://actors/pony/pony_visuals.gd")

var _model: Node3D = null


func after_each() -> void:
	if _model != null and is_instance_valid(_model):
		_model.free()
	_model = null


func _base_model() -> Node3D:
	var registry := PonyRegistryScript.new()
	registry.load_all("res://data/ponies")
	var data: PonyData = registry.by_id(StockPaletteScript.IDS[0])
	if data == null or not ResourceLoader.exists(data.model_path):
		return null
	return PonyVisualsScript.build(data)


func test_a_mark_lands_on_both_flanks() -> void:
	_model = _base_model()
	if _model == null:
		pass_test("no converted assets on this machine")
		return
	add_child_autofree(_model)
	var mark: Image = MarkStampsScript.build(MarkStampsScript.Stamp.STAR, Color.RED)
	assert_eq(CutieMarkScript.apply(_model, mark), 2, "a pony has two flanks")
	var decals: Array[Decal] = CutieMarkScript.decals_of(_model)
	assert_eq(decals.size(), 2)
	for decal in decals:
		assert_not_null(decal.texture_albedo, "the mark is the decal's albedo")
		assert_eq(decal.texture_albedo.get_image().get_width(), MarkPaintScript.SIZE)


func test_the_two_flanks_are_on_opposite_sides_of_the_barrel() -> void:
	_model = _base_model()
	if _model == null:
		pass_test("no converted assets on this machine")
		return
	add_child_autofree(_model)
	CutieMarkScript.apply(_model, MarkStampsScript.build(MarkStampsScript.Stamp.HEART, Color.RED))
	var decals: Array[Decal] = CutieMarkScript.decals_of(_model)
	var xs: Array[float] = []
	for decal in decals:
		xs.append(_model.to_local(decal.global_position).x)
	xs.sort()
	assert_lt(xs[0], 0.0, "one flank is on the left")
	assert_gt(xs[1], 0.0, "and one on the right")
	assert_almost_eq(absf(xs[0]), absf(xs[1]), 0.01, "and they are the same distance out")


func test_applying_twice_replaces_the_mark_rather_than_stacking_decals() -> void:
	_model = _base_model()
	if _model == null:
		pass_test("no converted assets on this machine")
		return
	add_child_autofree(_model)
	CutieMarkScript.apply(_model, MarkStampsScript.build(MarkStampsScript.Stamp.STAR, Color.RED))
	CutieMarkScript.apply(_model, MarkStampsScript.build(MarkStampsScript.Stamp.GEM, Color.BLUE))
	assert_eq(CutieMarkScript.decals_of(_model).size(), 2, "still two flanks, not four")


func test_a_blank_mark_leaves_a_blank_flank() -> void:
	_model = _base_model()
	if _model == null:
		pass_test("no converted assets on this machine")
		return
	add_child_autofree(_model)
	assert_eq(CutieMarkScript.apply(_model, MarkPaintScript.blank()), 0,
		"a pony who drew nothing has a blank flank, which is a real look")
	assert_eq(CutieMarkScript.decals_of(_model).size(), 0)


func test_clear_takes_the_mark_off_again() -> void:
	_model = _base_model()
	if _model == null:
		pass_test("no converted assets on this machine")
		return
	add_child_autofree(_model)
	CutieMarkScript.apply(_model, MarkStampsScript.build(MarkStampsScript.Stamp.STAR, Color.RED))
	CutieMarkScript.clear(_model)
	assert_eq(CutieMarkScript.decals_of(_model).size(), 0)


func test_a_null_model_is_refused() -> void:
	assert_eq(CutieMarkScript.apply(null, MarkPaintScript.blank()), 0)
```

`game/test/test_mark_canvas.gd`:

```gdscript
extends GutTest
## The painting widget, driven in canvas local coordinates rather than through a mouse.

const MarkCanvasScene := preload("res://ui/mark_canvas.tscn")
const MarkPaintScript := preload("res://systems/mark_paint.gd")
const MarkStampsScript := preload("res://systems/mark_stamps.gd")

var _canvas: MarkCanvas = null


func before_each() -> void:
	_canvas = MarkCanvasScene.instantiate()
	add_child_autofree(_canvas)
	_canvas.size = Vector2(256.0, 256.0)


func test_a_fresh_canvas_is_blank() -> void:
	assert_true(MarkPaintScript.is_blank(_canvas.image()))


func test_painting_marks_the_image_and_announces_it() -> void:
	watch_signals(_canvas)
	_canvas.set_colour(Color.RED)
	_canvas.set_brush(2)
	_canvas.paint_at(Vector2(128.0, 128.0))
	assert_false(MarkPaintScript.is_blank(_canvas.image()))
	assert_signal_emitted(_canvas, "changed")


func test_a_drag_paints_a_line_rather_than_two_dots() -> void:
	_canvas.set_colour(Color.RED)
	_canvas.set_brush(1)
	_canvas.paint_at(Vector2(16.0, 128.0))
	_canvas.drag_to(Vector2(240.0, 128.0))
	var image: Image = _canvas.image()
	var y: int = 32
	var run := 0
	for x in MarkPaintScript.SIZE:
		if image.get_pixel(x, y).a > 0.0:
			run += 1
	assert_gt(run, 40, "the drag is a stroke, not its endpoints")


func test_the_eraser_takes_paint_off() -> void:
	_canvas.set_colour(Color.RED)
	_canvas.set_brush(4)
	_canvas.paint_at(Vector2(128.0, 128.0))
	_canvas.set_eraser(true)
	_canvas.paint_at(Vector2(128.0, 128.0))
	assert_true(MarkPaintScript.is_blank(_canvas.image()))


func test_undo_steps_back_one_stroke_at_a_time() -> void:
	_canvas.set_colour(Color.RED)
	_canvas.paint_at(Vector2(64.0, 64.0))
	var after_first: Image = _canvas.image()
	_canvas.paint_at(Vector2(192.0, 192.0))
	assert_false(MarkPaintScript.equal(_canvas.image(), after_first))
	assert_true(_canvas.undo())
	assert_true(MarkPaintScript.equal(_canvas.image(), after_first))
	assert_true(_canvas.undo())
	assert_true(MarkPaintScript.is_blank(_canvas.image()))
	assert_false(_canvas.undo(), "and there is nothing before the blank canvas")


func test_the_undo_stack_is_bounded() -> void:
	_canvas.set_colour(Color.RED)
	for i in MarkCanvas.UNDO_DEPTH + 20:
		_canvas.paint_at(Vector2(float(4 + i % 60) * 4.0, 128.0))
	var steps := 0
	while _canvas.undo():
		steps += 1
	assert_lte(steps, MarkCanvas.UNDO_DEPTH, "a long session must not grow without bound")


func test_clear_empties_it_and_is_itself_undoable() -> void:
	_canvas.set_colour(Color.RED)
	_canvas.paint_at(Vector2(128.0, 128.0))
	_canvas.clear_all()
	assert_true(MarkPaintScript.is_blank(_canvas.image()))
	assert_true(_canvas.undo())
	assert_false(MarkPaintScript.is_blank(_canvas.image()),
		"clearing by accident must not cost her the drawing")


func test_a_stamp_replaces_the_canvas_and_is_undoable() -> void:
	_canvas.set_colour(Color.BLUE)
	_canvas.stamp(MarkStampsScript.Stamp.APPLE)
	assert_false(MarkPaintScript.is_blank(_canvas.image()))
	assert_true(_canvas.undo())
	assert_true(MarkPaintScript.is_blank(_canvas.image()))


func test_an_image_set_from_a_save_reads_back_pixel_identical() -> void:
	var source: Image = MarkStampsScript.build(MarkStampsScript.Stamp.CLOUD, Color.GREEN)
	_canvas.set_image(source)
	assert_true(MarkPaintScript.equal(_canvas.image(), source))


func test_the_canvas_returns_a_copy_rather_than_its_own_pixels() -> void:
	var taken: Image = _canvas.image()
	MarkPaintScript.dot(taken, Vector2i(1, 1), Color.RED, 0)
	assert_true(MarkPaintScript.is_blank(_canvas.image()))
```

- [ ] **Step 2: Run the tests and watch them fail**

Run: `FILLY_SKIP_SWEEP=1 bash tools/run_tests.sh 2>&1 | tail -40`
Expected: all four new files reported as ignored, and the script count guard fails the run.

- [ ] **Step 3: Write `game/systems/mark_paint.gd`**

```gdscript
class_name MarkPaint
extends RefCounted
## THE PIXELS UNDER THE CUTIE MARK CANVAS. Every operation the painting widget performs,
## as static functions on a plain Image, so the whole of "does the brush work" is GUT
## testable in milliseconds without a Control, a mouse or a viewport
## (game/test/test_mark_paint.gd). game/ui/mark_canvas.gd is the widget; it owns the undo
## stack, the tool state and the input, and it does no pixel arithmetic of its own.
##
## SIXTY FOUR SQUARE, RGBA8, TRANSPARENT WHERE SHE HAS NOT PAINTED. Small enough that the
## whole drawing is a few kilobytes of PNG inside one JSON save
## (game/systems/player_look.gd), large enough to draw a recognisable apple. Transparency is
## load bearing rather than cosmetic: the mark is projected onto the coat as a decal, and
## the coat has to show through everywhere she did not draw.
##
## EVERY WRITE IS CLIPPED. A brush half off the edge paints the half that is on it; a brush
## entirely off the canvas paints nothing. Nothing here ever wraps, because a stroke that
## reappeared on the far side would be a drawing tool that lies about where the ink went.

const SIZE := 64
const FORMAT := Image.FORMAT_RGBA8

## Brush radii, in pixels, that the widget offers. A radius of 0 is one pixel.
const BRUSHES: Array[int] = [1, 2, 4, 8]

## Fully transparent, which is also "she has not drawn anything yet".
const EMPTY := Color(0.0, 0.0, 0.0, 0.0)


static func blank() -> Image:
	var image: Image = Image.create_empty(SIZE, SIZE, false, FORMAT)
	image.fill(EMPTY)
	return image


static func copy_of(image: Image) -> Image:
	if image == null:
		return blank()
	return Image.create_from_data(image.get_width(), image.get_height(), false,
		image.get_format(), image.get_data())


static func clear(image: Image) -> void:
	if image != null:
		image.fill(EMPTY)


## A filled square brush of half width `radius`. SQUARE RATHER THAN ROUND on purpose: at
## these radii a circle is a lumpy square anyway, and a square brush makes a hand drawn
## sixty four pixel mark read as pixel art rather than as a failed attempt at smooth.
static func dot(image: Image, at: Vector2i, colour: Color, radius: int) -> void:
	if image == null:
		return
	var r: int = maxi(0, radius)
	for y in range(at.y - r, at.y + r + 1):
		if y < 0 or y >= image.get_height():
			continue
		for x in range(at.x - r, at.x + r + 1):
			if x < 0 or x >= image.get_width():
				continue
			image.set_pixel(x, y, colour)


## A line of dots from `from` to `to`, stepped one pixel at a time along the longer axis, so
## a fast drag leaves a stroke rather than two dots with a hole between them.
static func stroke(image: Image, from: Vector2i, to: Vector2i, colour: Color,
		radius: int) -> void:
	if image == null:
		return
	var steps: int = maxi(absi(to.x - from.x), absi(to.y - from.y))
	if steps <= 0:
		dot(image, from, colour, radius)
		return
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		dot(image, Vector2i(
			int(round(lerpf(float(from.x), float(to.x), t))),
			int(round(lerpf(float(from.y), float(to.y), t)))), colour, radius)


static func is_blank(image: Image) -> bool:
	if image == null:
		return true
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.0:
				return false
	return true


## Pixel for pixel, which is what "round trips pixel identical" means in the save test.
## Compares the raw buffers rather than pixel by pixel: a PNG round trip preserves bytes,
## and a byte comparison is the strongest statement available.
static func equal(a: Image, b: Image) -> bool:
	if a == null or b == null:
		return false
	if a.get_width() != b.get_width() or a.get_height() != b.get_height():
		return false
	if a.get_format() != b.get_format():
		return false
	return a.get_data() == b.get_data()
```

- [ ] **Step 4: Write `game/systems/mark_stamps.gd`**

```gdscript
class_name MarkStamps
extends RefCounted
## SOMETHING TO START FROM. Six shapes the creation screen offers as a starting point for a
## cutie mark, so a player who does not want to draw one from nothing still gets a mark she
## chose. Applied as a whole canvas, and undoable like any other stroke.
##
## DRAWN IN CODE, NOT SHIPPED AS PNGs. game/assets/converted/ is gitignored and regenerated
## per machine (docs/ci.md section 4), and a stamp sheet living there would be a creation
## screen that works on the author's machine and shows six blank buttons on a fresh clone.
## Each shape below is an implicit function evaluated per pixel, which is a dozen lines and
## no asset at all.
##
## Static only, no scene, and every shape is a pure function of (id, colour), so
## game/test/test_mark_stamps.gd can assert on the pixels.

enum Stamp { STAR, HEART, APPLE, CLOUD, FLOWER, GEM }

const NAMES: Array[String] = ["Star", "Heart", "Apple", "Cloud", "Flower", "Gem"]

const MarkPaintScript := preload("res://systems/mark_paint.gd")


static func ids() -> Array[int]:
	return [Stamp.STAR, Stamp.HEART, Stamp.APPLE, Stamp.CLOUD, Stamp.FLOWER, Stamp.GEM]


static func stamp_name(id: int) -> String:
	if id < 0 or id >= NAMES.size():
		return ""
	return NAMES[id]


## The stamp, drawn in `colour` on a transparent canvas. An unknown id answers a BLANK
## canvas rather than erroring: a stamp row that grew a button the shapes do not cover
## should produce an empty mark the player can see is empty, not a crash.
static func build(id: int, colour: Color) -> Image:
	var image: Image = MarkPaintScript.blank()
	if not id in ids():
		return image
	var half: float = float(MarkPaintScript.SIZE) * 0.5
	for py in MarkPaintScript.SIZE:
		for px in MarkPaintScript.SIZE:
			# Centred coordinates in [-1, 1], with +y UP, which is how the shapes below are
			# written; the image's own y runs downward.
			var x: float = (float(px) + 0.5 - half) / half
			var y: float = (half - float(py) - 0.5) / half
			if _inside(id, x, y):
				image.set_pixel(px, py, colour)
	return image


static func _inside(id: int, x: float, y: float) -> bool:
	match id:
		Stamp.STAR:
			return _star(x, y)
		Stamp.HEART:
			# The standard implicit heart, scaled to fill the canvas.
			var hx: float = x * 1.25
			var hy: float = y * 1.25 - 0.15
			var t: float = hx * hx + hy * hy - 0.42
			return t * t * t - hx * hx * hy * hy * hy <= 0.0
		Stamp.APPLE:
			# A round body with a bite out of the left and a stalk on top.
			var body: bool = (x * x) / 0.52 + ((y + 0.08) * (y + 0.08)) / 0.60 <= 1.0
			var stalk: bool = absf(x) <= 0.06 and y > 0.62 and y < 0.92
			var bite: bool = (x + 0.66) * (x + 0.66) + (y - 0.05) * (y - 0.05) <= 0.10
			return (body and not bite) or stalk
		Stamp.CLOUD:
			# Three overlapping discs on a flat base.
			if y < -0.42 or y > 0.55:
				return false
			var a: bool = (x + 0.36) * (x + 0.36) + (y + 0.10) * (y + 0.10) <= 0.13
			var b: bool = x * x + (y - 0.12) * (y - 0.12) <= 0.20
			var c: bool = (x - 0.38) * (x - 0.38) + (y + 0.06) * (y + 0.06) <= 0.15
			var base: bool = absf(x) <= 0.72 and y <= -0.10 and y >= -0.42
			return a or b or c or base
		Stamp.FLOWER:
			# Five petals on a polar rose, plus a centre.
			var r: float = sqrt(x * x + y * y)
			if r <= 0.16:
				return true
			return r <= 0.30 + 0.55 * absf(cos(2.5 * atan2(y, x)))
		Stamp.GEM:
			# A cut stone: a wide table over a point.
			if y > 0.30:
				return absf(x) <= 0.62 and y <= 0.62
			return absf(x) <= 0.62 * (1.0 - (0.30 - y) / 1.15) and y >= -0.85
	return false


## A five pointed star, as a polar radius test.
static func _star(x: float, y: float) -> bool:
	var r: float = sqrt(x * x + y * y)
	if r <= 0.001:
		return true
	var angle: float = atan2(y, x) - PI * 0.5
	var spoke: float = fposmod(angle, TAU / 5.0) - PI / 5.0
	# 0.38 is the inner radius and 0.92 the outer one, so the star fills the canvas without
	# clipping its points on the corners.
	return r <= 0.38 + (0.92 - 0.38) * (1.0 - absf(spoke) / (PI / 5.0))
```

- [ ] **Step 5: Write `game/systems/cutie_mark.gd`**

```gdscript
class_name CutieMark
extends RefCounted
## THE MARK, ON THE PONY. Two Decal nodes, one per flank, hung off a BoneAttachment3D so
## they follow the haunch through the walk cycle instead of sliding off it.
##
## WHY A DECAL AND NOT A TEXTURE. The base model
## (res://assets/converted/ponies/pokeypierce.glb) has no spare UV island and no overlay
## surface, and its body albedo is a flat colour that StockTint replaces outright
## (game/systems/stock_tint.gd), so there is nowhere to paint a mark into. A Decal projects
## the drawing onto whatever geometry is inside its box, needs no knowledge of the model's
## UVs, and is undone by deleting a node. Decals require the Forward+ renderer, which
## game/project.godot already declares.
##
## THE NUMBERS ARE MEASURED, NOT GUESSED. The base model's body mesh spans x in
## [-0.238, 0.238], y in [0.459, 1.164] and z in [-0.504, 0.393] in model space, and its
## tail sits at +z, so the model faces -z and the haunch is the +z end. FLANK therefore puts
## each decal at x = +/- 0.26 (just clear of the surface), y = 0.86 (mid barrel) and
## z = 0.22 (the haunch). DECAL_SIZE is 0.26 deep, which is shallower than the barrel is
## wide, so the left flank's projection cannot reach the right flank through the pony.
##
## THE PLACEMENT IS COMPUTED IN MODEL SPACE AND CONVERTED. The rest orientation of the
## `Pelvis` bone is not something this file can state and does not have to: the target
## transform is built in the model's own space and then multiplied through the attachment's
## inverse global transform, so whatever the bone's rest pose is, the decal lands on the
## flank.

const LEFT_NAME := &"CutieMarkLeft"
const RIGHT_NAME := &"CutieMarkRight"

## The bone the flanks hang off, in order of preference. `Pelvis` is the haunch; `Chest1`
## is the fallback for a rig that names its hips something else; a model with neither gets
## the decals on its root, which does not animate but does at least show the mark.
const BONE_NAMES: Array[StringName] = [&"Pelvis", &"Chest1"]

## Model space (x out to the flank, y up the barrel, z back toward the haunch).
const FLANK := Vector3(0.26, 0.86, 0.22)

## Decal box: across the flank, INTO the pony (the projection depth), and along her.
const DECAL_SIZE := Vector3(0.30, 0.26, 0.30)

const MarkPaintScript := preload("res://systems/mark_paint.gd")


## Put `mark` on both flanks of `model`. Returns how many flanks were marked: two on
## success, ZERO for a blank drawing, which is a real look and not a failure. Any previous
## mark is removed first, so applying twice replaces rather than stacks.
static func apply(model: Node3D, mark: Image) -> int:
	if model == null:
		return 0
	clear(model)
	if mark == null or MarkPaintScript.is_blank(mark):
		return 0
	var texture: ImageTexture = ImageTexture.create_from_image(mark)
	var anchor: Node3D = _anchor(model)
	if anchor == null:
		return 0
	var placed := 0
	for side in [1.0, -1.0]:
		var decal := Decal.new()
		decal.name = LEFT_NAME if side < 0.0 else RIGHT_NAME
		decal.size = DECAL_SIZE
		decal.texture_albedo = texture
		decal.albedo_mix = 1.0
		# Softened at the rim so the square canvas does not read as a sticker with a hard
		# edge on a curved barrel.
		decal.upper_fade = 0.4
		decal.lower_fade = 0.4
		anchor.add_child(decal)
		decal.global_transform = _flank_transform(model, side)
		placed += 1
	return placed


## The world transform of one flank's decal. Its local -Y is the projection axis, so it is
## aimed INWARD along the barrel: for the +X flank that is -X, and the reverse for the other.
static func _flank_transform(model: Node3D, side: float) -> Transform3D:
	var basis := Basis(
		Vector3(0.0, 0.0, -side),   # local X runs along the pony
		Vector3(side, 0.0, 0.0),    # local Y is the projection axis, pointing outward
		Vector3(0.0, 1.0, 0.0))     # local Z runs up the barrel
	var where := Vector3(FLANK.x * side, FLANK.y, FLANK.z)
	return model.global_transform * Transform3D(basis, where)


static func decals_of(model: Node3D) -> Array[Decal]:
	var out: Array[Decal] = []
	if model == null:
		return out
	for node: Node in model.find_children("*", "Decal", true, false):
		if StringName(node.name) == LEFT_NAME or StringName(node.name) == RIGHT_NAME:
			out.append(node as Decal)
	return out


static func clear(model: Node3D) -> void:
	for decal in decals_of(model):
		decal.get_parent().remove_child(decal)
		decal.queue_free()


## Where the decals hang. A BoneAttachment3D on the haunch when the model has a skeleton
## with one of BONE_NAMES; the model itself otherwise. Reused across calls so applying a new
## mark does not leave a trail of empty attachments behind it.
static func _anchor(model: Node3D) -> Node3D:
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		return model
	var existing := skeleton.get_node_or_null(^"CutieMarkAnchor") as BoneAttachment3D
	if existing != null:
		return existing
	for bone_name: StringName in BONE_NAMES:
		var index: int = skeleton.find_bone(String(bone_name))
		if index < 0:
			continue
		var attachment := BoneAttachment3D.new()
		attachment.name = "CutieMarkAnchor"
		attachment.bone_name = String(bone_name)
		attachment.bone_idx = index
		skeleton.add_child(attachment)
		return attachment
	return model
```

- [ ] **Step 6: Write `game/ui/mark_canvas.gd` and `.tscn`**

The scene is a `Control` named `MarkCanvas` with a `TextureRect` child named `Surface` (`expand_mode = EXPAND_IGNORE_SIZE`, `stretch_mode = STRETCH_KEEP_ASPECT`, `texture_filter = TEXTURE_FILTER_NEAREST`, anchors filling the parent) and a `Panel` behind it for the checkerboard backing.

```gdscript
class_name MarkCanvas
extends Control
## THE CUTIE MARK THE PLAYER DRAWS. A sixty four pixel square she paints on with a colour,
## four brush sizes, an eraser, undo, clear, and six shapes to start from
## (game/systems/mark_stamps.gd).
##
## THE PIXELS ARE game/systems/mark_paint.gd's; the tools, the undo stack and the input are
## this file's. That split is what lets the drawing be tested without a mouse: every
## operation this widget performs is reachable through paint_at()/drag_to()/undo()/stamp()
## in CANVAS LOCAL coordinates, and _gui_input() does nothing but convert a mouse position
## into one of those calls.
##
## UNDO IS A BOUNDED STACK OF SNAPSHOTS, not a list of operations. A sixty four square RGBA
## image is sixteen kilobytes, so twenty four of them is under half a megabyte and the
## whole of "undo" is one assignment. An operation log would be smaller and would have to be
## right about the inverse of every tool, including clear and stamp; this cannot be wrong.
##
## CLEAR AND STAMP ARE UNDOABLE, deliberately: both throw the whole drawing away, and a
## player who hits one by accident must not lose the thing she has been working on.

const MarkPaintScript := preload("res://systems/mark_paint.gd")
const MarkStampsScript := preload("res://systems/mark_stamps.gd")

## Snapshots kept. See the class comment for the arithmetic.
const UNDO_DEPTH := 24

signal changed()

var _image: Image = null
var _texture: ImageTexture = null
var _undo: Array[Image] = []
var _colour := Color(0.20, 0.20, 0.24, 1.0)
var _radius: int = MarkPaintScript.BRUSHES[1]
var _eraser := false
var _last := Vector2i(-1, -1)

@onready var _surface: TextureRect = $Surface


func _ready() -> void:
	_image = MarkPaintScript.blank()
	_texture = ImageTexture.create_from_image(_image)
	_surface.texture = _texture


## A COPY, always. The undo stack and the save both hold the pixels this returns, and either
## of them sharing the live image would mean painting one more stroke silently rewrote the
## history and the save with it.
func image() -> Image:
	return MarkPaintScript.copy_of(_image)


## Load a drawing (from a save, or from the creation screen restoring one). Does NOT push an
## undo entry: this is not something the player did.
func set_image(source: Image) -> void:
	_image = MarkPaintScript.copy_of(source)
	_undo.clear()
	_refresh()


func set_colour(colour: Color) -> void:
	_colour = colour
	_eraser = false


func set_brush(radius: int) -> void:
	_radius = clampi(radius, 0, MarkPaintScript.BRUSHES[MarkPaintScript.BRUSHES.size() - 1])


func set_eraser(on: bool) -> void:
	_eraser = on


func is_erasing() -> bool:
	return _eraser


## Begin a stroke at `point`, in this control's local coordinates.
func paint_at(point: Vector2) -> void:
	_push_undo()
	var at: Vector2i = _to_pixels(point)
	MarkPaintScript.dot(_image, at, _ink(), _radius)
	_last = at
	_refresh()
	changed.emit()


## Continue the stroke begun by paint_at(). No undo entry: one drag is one undoable action.
func drag_to(point: Vector2) -> void:
	var at: Vector2i = _to_pixels(point)
	if _last.x < 0:
		_last = at
	MarkPaintScript.stroke(_image, _last, at, _ink(), _radius)
	_last = at
	_refresh()
	changed.emit()


func end_stroke() -> void:
	_last = Vector2i(-1, -1)


func stamp(id: int) -> void:
	_push_undo()
	_image = MarkStampsScript.build(id, _colour)
	_refresh()
	changed.emit()


func clear_all() -> void:
	_push_undo()
	MarkPaintScript.clear(_image)
	_refresh()
	changed.emit()


## Step back one action. Returns whether there was anything to step back to.
func undo() -> bool:
	if _undo.is_empty():
		return false
	_image = _undo.pop_back()
	_refresh()
	changed.emit()
	return true


func _ink() -> Color:
	return MarkPaintScript.EMPTY if _eraser else _colour


func _push_undo() -> void:
	_undo.append(MarkPaintScript.copy_of(_image))
	while _undo.size() > UNDO_DEPTH:
		_undo.remove_at(0)


## Local pixels to canvas pixels. The control is square in the creation screen's layout, and
## a zero sized control (a widget that has not been laid out yet) maps everything to the top
## left rather than dividing by zero.
func _to_pixels(point: Vector2) -> Vector2i:
	var box: Vector2 = size
	if box.x <= 0.0 or box.y <= 0.0:
		return Vector2i.ZERO
	return Vector2i(
		clampi(int(point.x / box.x * float(MarkPaintScript.SIZE)), 0, MarkPaintScript.SIZE - 1),
		clampi(int(point.y / box.y * float(MarkPaintScript.SIZE)), 0, MarkPaintScript.SIZE - 1))


func _refresh() -> void:
	_texture = ImageTexture.create_from_image(_image)
	if _surface != null:
		_surface.texture = _texture


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		if button.pressed:
			paint_at(button.position)
		else:
			end_stroke()
		accept_event()
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		if motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
			drag_to(motion.position)
			accept_event()
```

- [ ] **Step 7: Run the tests and watch them pass**

Run: `bash tools/run_tests.sh 2>&1 | tail -25`
Expected: `---- All tests passed! ----`, exit 0.

- [ ] **Step 8: Look at a marked pony**

Extend the `--stock` branch of `game/scenes/test/model_gallery.gd` so the first pony of the row wears a stamp:

```gdscript
		if built == 0:
			CutieMarkScript.apply(body, MarkStampsScript.build(
				MarkStampsScript.Stamp.STAR, Color(0.95, 0.80, 0.25)))
```

Run: `tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/model_gallery.tscn -- --stock`
Expected: `GALLERY_OK count=8`, exit 0.

Then run the same scene windowed (no `--headless`) and look at the first pony from the side: a star on the haunch, on both sides, sitting on the coat rather than floating beside it. Nudge `CutieMark.FLANK` and `DECAL_SIZE` if it sits high, low or proud, and say in the commit what moved and by how much.

- [ ] **Step 9: Commit**

```bash
printf 'feat: a cutie mark the player draws, on both flanks\n\nMarkPaint is the pixels, MarkStamps six shapes drawn in code so no binary asset\nis needed, MarkCanvas the widget with brushes, an eraser, a bounded undo stack\nand an undoable clear, and CutieMark two Decal nodes on a bone attachment at the\nhaunch, placed from the base model measured in model space.\n' > /tmp/msg.txt
git add game/systems/mark_paint.gd game/systems/mark_paint.gd.uid \
  game/systems/mark_stamps.gd game/systems/mark_stamps.gd.uid \
  game/systems/cutie_mark.gd game/systems/cutie_mark.gd.uid \
  game/ui/mark_canvas.gd game/ui/mark_canvas.gd.uid game/ui/mark_canvas.tscn \
  game/scenes/test/model_gallery.gd \
  game/test/test_mark_paint.gd game/test/test_mark_paint.gd.uid \
  game/test/test_mark_stamps.gd game/test/test_mark_stamps.gd.uid \
  game/test/test_cutie_mark.gd game/test/test_cutie_mark.gd.uid \
  game/test/test_mark_canvas.gd game/test/test_mark_canvas.gd.uid
git commit -F /tmp/msg.txt
```

---

### Task 8: The creation screen. A pony she designed, a name the Company knows

**Files:**
- Create: `game/systems/player_look.gd`, `game/ui/creation_screen.gd`, `game/ui/creation_screen.tscn`
- Modify: `game/systems/game_state.gd`, `game/systems/save_io.gd` (the `from_version < 5` branch), `game/actors/player/player.gd`, `game/world/ranch.gd`, `game/world/ranch.tscn`
- Test: `game/test/test_player_look.gd`, `game/test/test_creation_screen.gd`, `game/test/test_game_state.gd`, `game/test/test_save_io.gd`, `game/test/test_player.gd`

**Interfaces:**
- Consumes: `StockPalette.load_player()`, `StockTint.apply` (Task 1); `MarkPaint`, `MarkStamps`, `MarkCanvas`, `CutieMark` (Task 7).
- Produces:
  - `class_name PlayerLook extends RefCounted`. `const DEFAULT_NAME := "Twilight"`, `const MAX_NAME_LENGTH := 16`, `const DEFAULT_COAT := 3`, `const DEFAULT_MANE := 1`, `const DEFAULT_EYES := 4`. Fields `player_name: String`, `coat: int`, `mane: int`, `eyes: int`, `mane_style: int`. `static func default_look() -> PlayerLook`, `static func sanitize_name(raw: String) -> String`, `func mark() -> Image` (never null), `func set_mark(image: Image) -> void`, `func has_mark() -> bool`, `func to_dict() -> Dictionary` (keys `name`, `coat`, `mane`, `eyes`, `mane_style`, `mark_png`), `static func from_dict(d: Dictionary) -> PlayerLook`.
  - `GameState` gains `var player: PlayerLook` under `const KEY_PLAYER := "player"`, replaced by `from_dict()`/`reset()`.
  - `SaveIO.migrate()`'s `from_version < 5` branch gains `out["player"] = {}`.
  - `Player` gains `func apply_look(look: PlayerLook) -> void` and its `pony_id` default becomes `&"stock_shy"`.
  - `class_name CreationScreen extends CanvasLayer` with `signal confirmed(look: PlayerLook)`; `func open(look: PlayerLook) -> void`, `func is_open() -> bool`, `func look() -> PlayerLook`, `func set_name_text(text: String) -> void`, `func cycle_coat(step: int) -> void`, `func cycle_mane(step: int) -> void`, `func cycle_eyes(step: int) -> void`, `func canvas() -> MarkCanvas`, `func model() -> Node3D` (the pony on the turntable, null on an assetless checkout), `func stamp(id: int) -> void`, `func drawn_lines() -> Array[String]`, `func confirm() -> bool`.
  - `Ranch` gains `@onready var creation_screen: CanvasLayer` and `func _maybe_open_creation() -> void`; `_player_name()` (Task 5) starts answering `_game_state.player.player_name`.

**Where the screen lives, and the one place the spec had to be resolved.** The spec says the creation screen comes up "before the ranch loads". `game/project.godot`'s `run/main_scene` is `res://world/ranch.tscn`, and every gate, the export smoke run and `docs/ci.md` are built on that; changing the main scene to get a title flow would be a much larger blast radius than this slice can carry. So the screen is a `CanvasLayer` inside `ranch.tscn` with `process_mode = PROCESS_MODE_ALWAYS`, opened at boot by `ranch.gd` when the session is interactive and no save was loaded, with the tree paused behind it. The player's own pony stands on a turntable in a `SubViewport` inside the screen, against a dawn coloured `WorldEnvironment` of its own, so nothing about the ranch behind it shows through and nothing about the screen touches the ranch. A hosted or headless run never opens it, which is what keeps every existing gate unchanged.

**The name is sanitised, not merely capped.** `sanitize_name()` strips control characters, collapses runs of whitespace, trims, truncates to `MAX_NAME_LENGTH`, and REMOVES em dashes and hyphens outright, because that name is interpolated into every Company letter and the project's own copy rule applies to it. An empty result becomes `DEFAULT_NAME`, so there is no such thing as a nameless account.

- [ ] **Step 1: Write the failing tests**

`game/test/test_player_look.gd`:

```gdscript
extends GutTest

const PlayerLookScript := preload("res://systems/player_look.gd")
const MarkPaintScript := preload("res://systems/mark_paint.gd")
const MarkStampsScript := preload("res://systems/mark_stamps.gd")


func test_the_default_look_is_twilight_with_a_blank_mark() -> void:
	var look: PlayerLook = PlayerLookScript.default_look()
	assert_eq(look.player_name, PlayerLookScript.DEFAULT_NAME)
	assert_false(look.has_mark())
	assert_true(MarkPaintScript.is_blank(look.mark()))


func test_a_name_is_trimmed_collapsed_and_capped() -> void:
	assert_eq(PlayerLookScript.sanitize_name("  Moon   beam  "), "Moon beam")
	assert_eq(PlayerLookScript.sanitize_name("W".repeat(80)).length(),
		PlayerLookScript.MAX_NAME_LENGTH)
	assert_eq(PlayerLookScript.sanitize_name(""), PlayerLookScript.DEFAULT_NAME)
	assert_eq(PlayerLookScript.sanitize_name("   "), PlayerLookScript.DEFAULT_NAME)


func test_a_name_may_not_carry_a_dash_of_any_kind() -> void:
	# It is interpolated into every Company letter, so the project's copy rule reaches it.
	assert_false(PlayerLookScript.sanitize_name("Moon--beam").contains("-"))
	assert_false(PlayerLookScript.sanitize_name("Moon" + char(0x2014) + "beam")
		.contains(char(0x2014)))
	assert_eq(PlayerLookScript.sanitize_name("Moon-beam"), "Moonbeam")


func test_a_name_drops_control_characters() -> void:
	assert_eq(PlayerLookScript.sanitize_name("Moon\nbeam\t"), "Moon beam")


func test_a_drawn_mark_round_trips_pixel_identical_through_base64_png() -> void:
	var look: PlayerLook = PlayerLookScript.default_look()
	var drawn: Image = MarkStampsScript.build(MarkStampsScript.Stamp.APPLE, Color(0.9, 0.2, 0.2))
	MarkPaintScript.stroke(drawn, Vector2i(2, 60), Vector2i(60, 2), Color(0.1, 0.3, 0.8), 2)
	look.set_mark(drawn)
	assert_true(look.has_mark())
	var back: PlayerLook = PlayerLookScript.from_dict(look.to_dict())
	assert_true(MarkPaintScript.equal(back.mark(), drawn),
		"every pixel she drew comes back exactly as she drew it")


func test_a_blank_mark_is_stored_as_nothing_rather_than_as_a_blank_png() -> void:
	var look: PlayerLook = PlayerLookScript.default_look()
	assert_eq(String(look.to_dict()["mark_png"]), "",
		"a save should not carry four kilobytes of transparent pixels")


func test_the_whole_look_round_trips() -> void:
	var look: PlayerLook = PlayerLookScript.default_look()
	look.player_name = "Moonbeam"
	look.coat = 7
	look.mane = 11
	look.eyes = 2
	look.mane_style = 1
	var back: PlayerLook = PlayerLookScript.from_dict(look.to_dict())
	assert_eq(back.player_name, "Moonbeam")
	assert_eq(back.coat, 7)
	assert_eq(back.mane, 11)
	assert_eq(back.eyes, 2)
	assert_eq(back.mane_style, 1)


func test_an_empty_dictionary_is_the_default_look() -> void:
	var back: PlayerLook = PlayerLookScript.from_dict({})
	assert_eq(back.player_name, PlayerLookScript.DEFAULT_NAME)
	assert_eq(back.coat, PlayerLookScript.DEFAULT_COAT)


func test_a_corrupt_mark_loads_as_a_blank_one_rather_than_failing_the_save() -> void:
	var back: PlayerLook = PlayerLookScript.from_dict({"mark_png": "not base64 at all"})
	assert_false(back.has_mark())
	assert_true(MarkPaintScript.is_blank(back.mark()))
	assert_eq(back.player_name, PlayerLookScript.DEFAULT_NAME,
		"one bad field must not cost her the rest of her pony")


func test_the_mark_is_handed_out_as_a_copy() -> void:
	var look: PlayerLook = PlayerLookScript.default_look()
	var taken: Image = look.mark()
	MarkPaintScript.dot(taken, Vector2i(1, 1), Color.RED, 0)
	assert_true(MarkPaintScript.is_blank(look.mark()))
```

`game/test/test_creation_screen.gd`:

```gdscript
extends GutTest
## The creation screen, driven through its own methods rather than through a mouse.

const CreationScreenScene := preload("res://ui/creation_screen.tscn")
const PlayerLookScript := preload("res://systems/player_look.gd")
const StockPaletteScript := preload("res://systems/stock_palette.gd")
const MarkPaintScript := preload("res://systems/mark_paint.gd")
const MarkStampsScript := preload("res://systems/mark_stamps.gd")

var _screen: CreationScreen = null


func before_each() -> void:
	_screen = CreationScreenScene.instantiate()
	add_child_autofree(_screen)
	_screen.open(PlayerLookScript.default_look())


func after_each() -> void:
	get_tree().paused = false


func test_it_opens_on_the_default_look() -> void:
	assert_true(_screen.is_open())
	assert_eq(_screen.look().player_name, PlayerLookScript.DEFAULT_NAME)


func test_cycling_a_swatch_row_wraps_and_stays_in_range() -> void:
	var palette: StockPalette = StockPaletteScript.load_player()
	for i in palette.coats.size() + 3:
		_screen.cycle_coat(1)
		assert_between(_screen.look().coat, 0, palette.coats.size() - 1)
	_screen.cycle_coat(-1)
	assert_between(_screen.look().coat, 0, palette.coats.size() - 1)


func test_every_row_can_be_cycled_independently() -> void:
	_screen.cycle_coat(1)
	_screen.cycle_mane(2)
	_screen.cycle_eyes(3)
	var look: PlayerLook = _screen.look()
	assert_ne(look.coat, look.mane, "three rows, three choices")


func test_a_typed_name_is_sanitised_into_the_look() -> void:
	_screen.set_name_text("  Moon--beam  ")
	assert_eq(_screen.look().player_name, "Moonbeam")


func test_a_drawn_mark_reaches_the_look_on_confirm() -> void:
	_screen.canvas().set_colour(Color(0.2, 0.6, 0.9))
	_screen.canvas().stamp(MarkStampsScript.Stamp.GEM)
	watch_signals(_screen)
	assert_true(_screen.confirm())
	assert_signal_emitted(_screen, "confirmed")
	var look: PlayerLook = _screen.look()
	assert_true(look.has_mark())
	assert_true(MarkPaintScript.equal(look.mark(), _screen.canvas().image()))


func test_confirming_closes_the_screen_and_unpauses_the_world() -> void:
	_screen.confirm()
	assert_false(_screen.is_open())
	assert_false(get_tree().paused)


func test_confirming_twice_emits_once() -> void:
	watch_signals(_screen)
	assert_true(_screen.confirm())
	assert_false(_screen.confirm())
	assert_signal_emit_count(_screen, "confirmed", 1)


func test_the_turntable_holds_a_tinted_pony() -> void:
	if _screen.model() == null:
		pass_test("no converted assets on this machine")
		return
	_screen.cycle_coat(2)
	var palette: StockPalette = StockPaletteScript.load_player()
	assert_eq(StockTint.override_of(_screen.model(), &"body").albedo_color,
		palette.coat_at(_screen.look().coat),
		"the swatch she picked is the colour standing on the turntable")


func test_nothing_the_screen_draws_carries_a_dash() -> void:
	for line in _screen.drawn_lines():
		assert_false(line.contains("--"), "'%s' carries a double hyphen" % line)
		assert_false(line.contains(char(0x2014)), "'%s' carries an em dash" % line)
```

Add to `game/test/test_game_state.gd`:

```gdscript
func test_the_player_look_round_trips_through_the_state() -> void:
	GameState.reset()
	GameState.player.player_name = "Moonbeam"
	GameState.player.coat = 9
	GameState.player.set_mark(MarkStamps.build(MarkStamps.Stamp.STAR, Color.RED))
	var data: Dictionary = GameState.to_dict()
	GameState.reset()
	assert_eq(GameState.player.player_name, PlayerLook.DEFAULT_NAME)
	GameState.from_dict(data)
	assert_eq(GameState.player.player_name, "Moonbeam")
	assert_eq(GameState.player.coat, 9)
	assert_true(GameState.player.has_mark())
```

Add to `game/test/test_save_io.gd`:

```gdscript
func test_a_version_four_save_gets_twilight_with_a_blank_mark() -> void:
	var migrated: Dictionary = SaveIO.migrate({"bits": 40}, 4)
	assert_eq(migrated["player"], {})
	var look: PlayerLook = PlayerLook.from_dict(migrated["player"])
	assert_eq(look.player_name, PlayerLook.DEFAULT_NAME)
	assert_false(look.has_mark())


func test_a_drawn_mark_survives_the_file_on_disk() -> void:
	var look: PlayerLook = PlayerLook.default_look()
	var drawn: Image = MarkStamps.build(MarkStamps.Stamp.FLOWER, Color(0.4, 0.8, 0.3))
	look.set_mark(drawn)
	assert_true(SaveIO.save(_slot, {"player": look.to_dict()}))
	var loaded: Dictionary = SaveIO.load(_slot)
	assert_true(MarkPaint.equal(PlayerLook.from_dict(loaded["player"]).mark(), drawn),
		"the save is one self contained JSON blob and the drawing comes back exactly")
```

Add to `game/test/test_player.gd`:

```gdscript
func test_the_player_wears_the_look_she_is_given() -> void:
	var player: Player = _player()  # the file's existing helper
	if player.get_animation_player() == null:
		pass_test("no converted assets on this machine")
		return
	var look: PlayerLook = PlayerLook.default_look()
	look.coat = 2
	look.set_mark(MarkStamps.build(MarkStamps.Stamp.HEART, Color.RED))
	player.apply_look(look)
	var body: Node3D = player.visuals.get_child(0)
	assert_eq(StockTint.override_of(body, &"body").albedo_color,
		StockPalette.load_player().coat_at(2))
	assert_eq(CutieMark.decals_of(body).size(), 2)
```

- [ ] **Step 2: Run the tests and watch them fail**

Run: `FILLY_SKIP_SWEEP=1 bash tools/run_tests.sh 2>&1 | tail -40`
Expected: the two new files ignored, and failures naming `PlayerLook` and `apply_look`.

- [ ] **Step 3: Write `game/systems/player_look.gd`**

```gdscript
class_name PlayerLook
extends RefCounted
## THE PONY THE PLAYER DESIGNED, AND THE NAME THE COMPANY KNOWS HER BY. Saved under the
## key "player" (game/systems/game_state.gd) and read by the creation screen, by the player
## model, and by every letter the Company writes.
##
## THE LOOK IS INDICES AND THE MARK IS A PNG. Coat, mane and eyes are indices into
## game/data/player_palette.tres for StockPalette's stated reason; the cutie mark is not a
## choice from a sheet, it is a drawing, so it is stored as the pixels themselves. As a
## BASE64 PNG rather than as a side file, because the whole design of this project's saves
## is one human readable JSON blob a player can paste to somebody (see save_io.gd's class
## comment) and a save that carried a companion image would stop being tradeable the moment
## it left the machine that wrote it. A sixty four square drawing is a few kilobytes.
##
## PNG BECAUSE PNG IS LOSSLESS. "Round trips pixel identical" is a promise the creation
## test asserts, and it is only true of a lossless format; the same drawing through a JPEG
## would come back subtly different every save.
##
## A BLANK MARK IS STORED AS THE EMPTY STRING, not as a PNG of nothing. A blank flank is a
## real look, it is what a version 4 save gets, and it should not cost the file anything.
##
## THE NAME IS SANITISED RATHER THAN MERELY CAPPED. It is interpolated into every Company
## letter, so the project's copy rule reaches it: no em dash, no hyphen, no control
## characters, no runs of whitespace, and never empty.

const MarkPaintScript := preload("res://systems/mark_paint.gd")

const DEFAULT_NAME := "Twilight"

## The longest name the box accepts. Letters.MAX_NAME_LENGTH mirrors this, and
## test_letters.gd renders every template at exactly this length.
const MAX_NAME_LENGTH := 16

## The shipped look a version 4 save loads with: a lavender coat, a dark mane and violet
## eyes, which is as near as game/data/player_palette.tres gets to the pony who used to
## stand in the player slot.
const DEFAULT_COAT := 3
const DEFAULT_MANE := 1
const DEFAULT_EYES := 4

## Named `player_name` rather than `name`, because `name` is a property of Node and a
## future refactor that made this a Node would shadow it silently.
var player_name := DEFAULT_NAME
var coat := DEFAULT_COAT
var mane := DEFAULT_MANE
var eyes := DEFAULT_EYES

## Which mane mesh she wears. Zero is the base model's own, which is the only one this
## slice ships; the field exists so a second sourced style is data rather than a schema
## change.
var mane_style := 0

var _mark: Image = null


static func default_look() -> PlayerLook:
	return PlayerLook.new()


## Trim, collapse, strip and cap. An empty result is DEFAULT_NAME, so there is no such thing
## as a nameless account.
static func sanitize_name(raw: String) -> String:
	var out := ""
	for i in raw.length():
		var c: String = raw[i]
		var code: int = raw.unicode_at(i)
		if code < 32 or code == 127:
			out += " "
			continue
		# The project's copy rule, applied at the one place a player can type into it.
		if c == "-" or code == 0x2014 or code == 0x2013:
			continue
		out += c
	while out.contains("  "):
		out = out.replace("  ", " ")
	out = out.strip_edges()
	if out.length() > MAX_NAME_LENGTH:
		out = out.substr(0, MAX_NAME_LENGTH)
	out = out.strip_edges()
	return out if not out.is_empty() else DEFAULT_NAME


## Her drawing. NEVER NULL: a look with no mark answers a blank canvas, so every caller can
## hand it straight to CutieMark.apply() without a null check.
func mark() -> Image:
	return MarkPaintScript.copy_of(_mark) if _mark != null else MarkPaintScript.blank()


func set_mark(image: Image) -> void:
	_mark = null if image == null else MarkPaintScript.copy_of(image)


func has_mark() -> bool:
	return _mark != null and not MarkPaintScript.is_blank(_mark)


func to_dict() -> Dictionary:
	return {
		"name": player_name,
		"coat": coat,
		"mane": mane,
		"eyes": eyes,
		"mane_style": mane_style,
		"mark_png": _encoded_mark(),
	}


func _encoded_mark() -> String:
	if not has_mark():
		return ""
	return Marshalls.raw_to_base64(_mark.save_png_to_buffer())


## Rebuild from a to_dict() dictionary. Every field is optional and falls back to this
## class's default, which is what makes a version 4 save load as Twilight with a blank
## mark and no migration branch of its own.
##
## A MARK THAT WILL NOT DECODE IS DROPPED, not fatal. A hand edited or truncated blob costs
## her the drawing and nothing else; the alternative is a save that refuses to load over a
## picture, which is the worst trade this file could make.
static func from_dict(d: Dictionary) -> PlayerLook:
	var out := PlayerLook.new()
	out.player_name = sanitize_name(str(d.get("name", DEFAULT_NAME)))
	out.coat = int(d.get("coat", DEFAULT_COAT))
	out.mane = int(d.get("mane", DEFAULT_MANE))
	out.eyes = int(d.get("eyes", DEFAULT_EYES))
	out.mane_style = maxi(0, int(d.get("mane_style", 0)))
	var encoded := str(d.get("mark_png", ""))
	if encoded.is_empty():
		return out
	var raw: PackedByteArray = Marshalls.base64_to_raw(encoded)
	if raw.is_empty():
		push_warning("PlayerLook: the saved cutie mark is not base64; loading a blank one.")
		return out
	var image := Image.new()
	if image.load_png_from_buffer(raw) != OK:
		push_warning("PlayerLook: the saved cutie mark is not a PNG; loading a blank one.")
		return out
	if image.get_width() != MarkPaintScript.SIZE or image.get_height() != MarkPaintScript.SIZE:
		image.resize(MarkPaintScript.SIZE, MarkPaintScript.SIZE, Image.INTERPOLATE_NEAREST)
	if image.get_format() != MarkPaintScript.FORMAT:
		image.convert(MarkPaintScript.FORMAT)
	out._mark = image
	return out
```

- [ ] **Step 4: Hold the look in `game/systems/game_state.gd` and migrate to it**

Add `const PlayerLookScript := preload("res://systems/player_look.gd")`, `const KEY_PLAYER := "player"`, and:

```gdscript
## THE PONY THE PLAYER MADE (game/systems/player_look.gd): her name, her three palette
## indices, her mane style and the cutie mark she drew. REPLACED, NOT MUTATED, by
## from_dict() and reset(), the same rule `gems`, `compendium` and `ledger` follow.
var player: PlayerLook = PlayerLookScript.default_look()
```

`to_dict()` gains `KEY_PLAYER: player.to_dict(),`; `from_dict()` gains:

```gdscript
	var saved_player: Variant = data.get(KEY_PLAYER, {})
	player = PlayerLookScript.from_dict(
		saved_player if typeof(saved_player) == TYPE_DICTIONARY else {})
```

`reset()` gains `player = PlayerLookScript.default_look()`.

In `game/systems/save_io.gd`, the `from_version < 5` branch added in Task 4 grows one clause:

```gdscript
	if from_version < 5:
		if not out.has("ledger"):
			out["ledger"] = {}
		if not out.has("player"):
			# PlayerLook.from_dict({}) is Twilight, the shipped look and a blank mark, which
			# is exactly what the design doc says a version 4 save should load as. Stated
			# here rather than left to that default so migrate()'s OUTPUT states the version
			# 5 shape, the way the version 2 branch does.
			out["player"] = {}
```

- [ ] **Step 5: Dress the player (`game/actors/player/player.gd`)**

Change the export default and add the applier:

```gdscript
## The base record the player's body is built from. A HIDDEN record
## (game/systems/pony_registry.gd HIDDEN_DIR), because the player is not a collectible and
## must not appear in the Compendium; and the same record the crowd is built from, because
## the recolour is one pipeline with two users. Twilight Sparkle has left the player slot
## and may join the catchable roster in a later phase's authoring.
@export var pony_id: StringName = &"stock_shy"
```

```gdscript
## Wear `look`: the palette tint and the cutie mark, on the body already built. Called by
## ranch.gd at boot and again whenever a load replaces GameState.player, so the pony on
## screen is always the pony the save describes.
##
## THE SAME StockTint THE CROWD GOES THROUGH, deliberately: one pipeline, two users, and no
## second path that could drift.
func apply_look(look: PlayerLook) -> void:
	if look == null or visuals.get_child_count() == 0:
		return
	var body: Node3D = visuals.get_child(0)
	StockTintScript.apply(body, StockPaletteScript.load_player(),
		{"coat": look.coat, "mane": look.mane, "eyes": look.eyes})
	CutieMarkScript.apply(body, look.mark())
```

with the three preloads added at the top.

- [ ] **Step 6: Write `game/ui/creation_screen.gd` and `.tscn`**

The scene is a `CanvasLayer` named `CreationScreen`, `process_mode = PROCESS_MODE_ALWAYS`, hidden at rest, laid out as: a `SubViewportContainer`/`SubViewport` on the left holding `Turntable` (a `Node3D`), a `Camera3D` at `(0, 1.1, 3.2)` looking at `(0, 1.0, 0)`, a `DirectionalLight3D` and a `WorldEnvironment` with a dawn coloured sky; and on the right a `VBoxContainer` holding a `LineEdit` named `NameBox` (`max_length = 16`), three swatch rows (`HBoxContainer`s of `ColorRect` buttons), a `MarkCanvas` instance sized 256 by 256, a row of stamp buttons, a row of brush and eraser buttons, `Undo` and `Clear` buttons, and a `Confirm` button.

```gdscript
class_name CreationScreen
extends CanvasLayer
## WHERE A NEW GAME BEGINS: the player's own pony on a turntable, three rows of swatches, a
## name box, and a square of canvas she draws her cutie mark on.
##
## A CanvasLayer INSIDE ranch.tscn RATHER THAN A SCENE OF ITS OWN. The design doc says the
## screen comes up before the ranch loads; game/project.godot's main scene is
## world/ranch.tscn and every gate, the export smoke run and docs/ci.md are built on that,
## so a title flow that changed the main scene would be a far larger change than this slice
## can carry. The screen therefore opens OVER a paused ranch, with its own SubViewport, its
## own camera and its own dawn sky, so nothing of the ranch shows through and nothing here
## reaches into it. ranch.gd opens it only for an interactive session with no save, so no
## gate and no headless run ever sees it.
##
## THE WIDGET IS DRIVEN BY METHODS, NOT BY INPUT. cycle_coat(), set_name_text(), canvas()
## and confirm() are the whole of what the buttons do, which is what lets
## game/test/test_creation_screen.gd drive the entire screen with no mouse and no viewport.
##
## THE TINT ON THE TURNTABLE IS THE SAME StockTint THE CROWD GOES THROUGH. If the pony she
## is looking at were tinted by a second path, the pony she gets would not be the pony she
## chose.

const PlayerLookScript := preload("res://systems/player_look.gd")
const StockPaletteScript := preload("res://systems/stock_palette.gd")
const StockTintScript := preload("res://systems/stock_tint.gd")
const CutieMarkScript := preload("res://systems/cutie_mark.gd")
const MarkStampsScript := preload("res://systems/mark_stamps.gd")
const MarkPaintScript := preload("res://systems/mark_paint.gd")
const PonyRegistryScript := preload("res://systems/pony_registry.gd")
const PonyVisualsScript := preload("res://actors/pony/pony_visuals.gd")

const TITLE := "Who are you?"
const NAME_LABEL := "Your name"
const COAT_LABEL := "Coat"
const MANE_LABEL := "Mane and tail"
const EYES_LABEL := "Eyes"
const MARK_LABEL := "Your cutie mark; draw it yourself"
const CONFIRM_LABEL := "This is me"
const HINT := "Left click to draw. Pick a shape to start from, or start with nothing."

## Degrees per second the turntable turns. Slow enough to read, fast enough to see both
## flanks (and both cutie marks) inside a few seconds.
const TURN_DEGREES_PER_SECOND := 24.0

signal confirmed(look: PlayerLook)

var _look: PlayerLook = null
var _palette: StockPalette = null
var _model: Node3D = null
var _open := false

@onready var _turntable: Node3D = $Viewport/SubViewport/Turntable
@onready var _name_box: LineEdit = $Panel/Column/NameBox
@onready var _canvas: MarkCanvas = $Panel/Column/MarkCanvas
@onready var _confirm: Button = $Panel/Column/Confirm


func _ready() -> void:
	visible = false
	_palette = StockPaletteScript.load_player()
	_name_box.max_length = PlayerLookScript.MAX_NAME_LENGTH
	_confirm.text = CONFIRM_LABEL
	_name_box.text_changed.connect(set_name_text)
	_confirm.pressed.connect(func() -> void: confirm())
	_canvas.changed.connect(func() -> void: _sync_mark())


## Show the screen on `look` and pause the world behind it.
func open(look: PlayerLook) -> void:
	_look = look if look != null else PlayerLookScript.default_look()
	_open = true
	visible = true
	get_tree().paused = true
	_name_box.text = _look.player_name
	_canvas.set_image(_look.mark())
	_build_model()
	_restyle()


func is_open() -> bool:
	return _open


func look() -> PlayerLook:
	return _look


## The pony standing on the turntable, or null on an assetless checkout.
func model() -> Node3D:
	return _model


func canvas() -> MarkCanvas:
	return _canvas


func set_name_text(text: String) -> void:
	_look.player_name = PlayerLookScript.sanitize_name(text)


func cycle_coat(step: int) -> void:
	_look.coat = posmod(_look.coat + step, maxi(1, _palette.coats.size()))
	_restyle()


func cycle_mane(step: int) -> void:
	_look.mane = posmod(_look.mane + step, maxi(1, _palette.manes.size()))
	_restyle()


func cycle_eyes(step: int) -> void:
	_look.eyes = posmod(_look.eyes + step, maxi(1, _palette.eyes.size()))
	_restyle()


func stamp(id: int) -> void:
	_canvas.stamp(id)


## Take the look as it stands and hand it over. Returns whether anything happened; a second
## call does nothing, so a double click on the button cannot start two ranches.
func confirm() -> bool:
	if not _open:
		return false
	_sync_mark()
	set_name_text(_name_box.text)
	_open = false
	visible = false
	get_tree().paused = false
	confirmed.emit(_look)
	return true


## Every string this screen draws, for the copy rule test.
func drawn_lines() -> Array[String]:
	var lines: Array[String] = [TITLE, NAME_LABEL, COAT_LABEL, MANE_LABEL, EYES_LABEL,
		MARK_LABEL, CONFIRM_LABEL, HINT]
	for id: int in MarkStampsScript.ids():
		lines.append(MarkStampsScript.stamp_name(id))
	return lines


func _sync_mark() -> void:
	_look.set_mark(_canvas.image())
	if _model != null:
		CutieMarkScript.apply(_model, _look.mark())


func _build_model() -> void:
	if _model != null and is_instance_valid(_model):
		_model.queue_free()
		_model = null
	var registry := PonyRegistryScript.new()
	registry.load_all("res://data/ponies")
	var data: PonyData = registry.by_id(StockPaletteScript.IDS[0])
	if data == null or not ResourceLoader.exists(data.model_path):
		# The assetless checkout (docs/ci.md section 4). The swatches and the canvas still
		# work; there is simply nothing standing on the turntable to look at.
		return
	_model = PonyVisualsScript.build(data)
	if _model != null:
		_model.rotate_y(PI)
		_turntable.add_child(_model)


func _restyle() -> void:
	if _model == null:
		return
	StockTintScript.apply(_model, _palette,
		{"coat": _look.coat, "mane": _look.mane, "eyes": _look.eyes})
	CutieMarkScript.apply(_model, _look.mark())


func _process(delta: float) -> void:
	if _open and _turntable != null:
		_turntable.rotate_y(deg_to_rad(TURN_DEGREES_PER_SECOND) * delta)
```

- [ ] **Step 7: Open it at boot, and dress the player (`game/world/ranch.gd`, `game/world/ranch.tscn`)**

Add a `CreationScreen` instance to `ranch.tscn` beside the other menus, and in `ranch.gd`:

```gdscript
@onready var creation_screen: CanvasLayer = $CreationScreen
```

`_no_menu_but()` gains `creation_screen`, so nothing else can open over it. At the end of `_ready()`'s interactive branch, after the report:

```gdscript
	_apply_player_look()
	_maybe_open_creation()
```

```gdscript
## A NEW GAME OPENS ON THE CREATION SCREEN. Only for somebody actually playing: a hosted
## ranch, a headless gate and a screenshot run all skip it, so no automated run ever waits
## on a button nobody is going to press. A session that LOADED a save skips it too; there is
## no re-edit screen this phase.
func _maybe_open_creation() -> void:
	if not _interactive or _save_loaded or _game_state == null:
		return
	if creation_screen == null or not creation_screen.has_method("open"):
		return
	if not creation_screen.is_connected("confirmed", _on_creation_confirmed):
		creation_screen.connect("confirmed", _on_creation_confirmed)
	creation_screen.call("open", _game_state.player)


## She has made her pony. Keep it, dress the model, and write it down straight away: the
## first thing that happens after this is a ranch, and a crash before the first autosave
## should not cost her the pony she just spent five minutes on.
func _on_creation_confirmed(look: PlayerLook) -> void:
	if _game_state == null:
		return
	_game_state.player = look
	_apply_player_look()
	save_game()
	var letter: Dictionary = LettersScript.render(LettersScript.Id.WELCOME, {
		"name": look.player_name, "balance": _game_state.ledger.balance})
	_toast("%s: %s" % [letter["sender"], letter["title"]])


func _apply_player_look() -> void:
	if _game_state == null or player == null or not player.has_method("apply_look"):
		return
	player.call("apply_look", _game_state.player)
```

`_apply_player_look()` is also called from `rebind_economy()`, so a mid session load re-dresses her. And `_player_name()` (Task 5) becomes real:

```gdscript
func _player_name() -> String:
	return _game_state.player.player_name if _game_state != null else PlayerLookScript.DEFAULT_NAME
```

`_report()` gains:

```gdscript
	_set_check(checks, "the player has a look", _game_state != null and _game_state.player != null)
	_set_check(checks, "the creation screen is closed in an automated run",
		creation_screen == null or not creation_screen.call("is_open"))
	print("RANCH player name=%s coat=%d mane=%d eyes=%d mark=%s" % [
		_player_name(), _game_state.player.coat, _game_state.player.mane,
		_game_state.player.eyes, _game_state.player.has_mark()])
```

- [ ] **Step 8: Run the tests and the gates**

Run: `bash tools/run_tests.sh 2>&1 | tail -25`
Expected: `---- All tests passed! ----`, exit 0.

Run: `tools/bin/godot --headless --audio-driver Dummy --path game world/ranch.tscn`
Expected: `RANCH player name=Twilight coat=3 mane=1 eyes=4 mark=false` and `RANCH_OK ponies=49 props=59 assets=present`, exit 0.

Run the four hosted gates plus `capture_test`.
Expected: all green. `capture_test` drives the player's beam and the player's body is now built from a different base model; if it names a bone, a height or a beam origin that moved, re-measure and update it, and say so in the commit.

- [ ] **Step 9: Look at her**

Run the ranch windowed on an empty save slot and step through the creation screen by hand: pick a coat, a mane and a pair of eyes, type a name with a hyphen in it and watch the hyphen go, draw a mark, undo it, stamp an apple, and confirm. Then walk to the Depot and read the statement; it is made out to the name you typed.

- [ ] **Step 10: Commit**

```bash
printf 'feat: character creation; a pony you designed and a name the Company knows\n\nPlayerLook holds the name, the three palette indices, the mane style and the\ncutie mark as a base64 PNG, so the save stays one self contained JSON blob and\nthe drawing round trips pixel identical. The creation screen opens over a paused\nranch on a new game with the pony on a turntable, tinted through the same\nStockTint the crowd goes through. A version 4 save loads as Twilight with the\nshipped look and a blank mark.\n' > /tmp/msg.txt
git add game/systems/player_look.gd game/systems/player_look.gd.uid \
  game/ui/creation_screen.gd game/ui/creation_screen.gd.uid game/ui/creation_screen.tscn \
  game/systems/game_state.gd game/systems/save_io.gd \
  game/actors/player/player.gd game/world/ranch.gd game/world/ranch.tscn \
  game/test/test_player_look.gd game/test/test_player_look.gd.uid \
  game/test/test_creation_screen.gd game/test/test_creation_screen.gd.uid \
  game/test/test_game_state.gd game/test/test_save_io.gd game/test/test_player.gd
git commit -F /tmp/msg.txt
```

---

### Task 9: The three gates, the pause menu page, the docs and the floor

**Files:**
- Create: `game/scenes/test/ledger_test.gd`/`.tscn`, `game/scenes/test/depot_test.gd`/`.tscn`, `game/scenes/test/creation_test.gd`/`.tscn`
- Modify: `game/ui/pause_menu.gd`, `game/ui/pause_menu.tscn`, `tools/run_tests.sh`, `docs/testing.md`, `docs/pipeline.md`
- Test: `game/test/test_pause_menu.gd`

**Interfaces:**
- Consumes: everything from Tasks 1 to 8.
- Produces: `PauseMenu.Page` becomes `{ MAIN, SETTINGS, COMPENDIUM, REQUESTS, LEDGER }` and `PauseMenu.Row` becomes `{ RESUME, COMPENDIUM, REQUESTS, LEDGER, SAVE, SETTINGS, QUIT }`, with `MAIN_ROWS` following; `var ledger: Ledger`, `var player_look: PlayerLook`, `var statement_provider := Callable()` injected by `ranch._bind_pause_menu()`'s `inject_pages` lambda; `func ledger_rows() -> Array[String]`.

**Every existing test that names a `Row` index moves with the enum.** `game/test/test_pause_menu.gd` walks the main rows by name; re-run it and fix the indices it asserts, in this commit, saying which moved.

#### The pause menu page

In `game/ui/pause_menu.gd`:

```gdscript
enum Page { MAIN, SETTINGS, COMPENDIUM, REQUESTS, LEDGER }
enum Row { RESUME, COMPENDIUM, REQUESTS, LEDGER, SAVE, SETTINGS, QUIT }

const MAIN_ROWS := ["Resume", "Compendium", "Requests", "The ledger", "Save the ranch",
	"Settings", "Quit to desktop"]

const FOOTER_LEDGER := "  Esc / B  back"
```

```gdscript
## The Company's account, repeated from the Ledger's own statement rather than re-derived
## here, so the pause menu and the Depot counter can never disagree about what she owes.
func ledger_rows() -> Array[String]:
	if not statement_provider.is_valid():
		return [EMPTY_TEXT]
	var lines: Array[String] = []
	for line in statement_provider.call():
		lines.append(String(line))
	return lines if not lines.is_empty() else [EMPTY_TEXT]


func _draw_ledger() -> void:
	for line in ledger_rows():
		_add_note(line)
```

with `_refresh()` and `footer_text()` gaining the `Page.LEDGER` arm, and `confirm()` on `Row.LEDGER` opening it.

In `ranch._bind_pause_menu()`, the `inject_pages` lambda gains:

```gdscript
		pause_menu.set("ledger", _game_state.ledger if _game_state != null else null)
		pause_menu.set("player_look", _game_state.player if _game_state != null else null)
		pause_menu.set("statement_provider", func() -> Array[String]: return _statement())
```

Add to `game/test/test_pause_menu.gd`:

```gdscript
func test_the_ledger_page_repeats_the_statement() -> void:
	var menu: PauseMenu = _menu()
	menu.statement_provider = func() -> Array[String]:
		return Ledger.new().statement_lines("Moonbeam", 1, 0, 2)
	assert_true(menu.open_page(PauseMenu.Page.LEDGER))
	assert_eq(menu.page(), PauseMenu.Page.LEDGER)
	var joined: String = "\n".join(menu.ledger_rows())
	assert_true(joined.contains("Sponsorship balance"))
	assert_true(joined.contains("Moonbeam"))
	assert_false(joined.contains("--"))


func test_the_ledger_page_says_so_when_there_is_no_ledger_to_show() -> void:
	var menu: PauseMenu = _menu()
	menu.statement_provider = Callable()
	assert_eq(menu.ledger_rows(), [PauseMenu.EMPTY_TEXT])
```

#### `ledger_test`: the arithmetic, walked on the real clock

`game/scenes/test/ledger_test.tscn` hosts `world/ranch.tscn` exactly as `market_test`, `region_test`, `world_test` and `collection_test` do: instanced under a `Node`, `await ranch.gate_report_finished`, verdict folded into this gate's own. `game/scenes/test/ledger_test.gd` checks, in one run:

- the ranch built a ledger and it opens at `Ledger.STARTING_BALANCE` with quota `Ledger.STARTING_QUOTA`;
- `ranch.advance_world(WorldState.CYCLE_SECONDS * Ledger.PERIOD_CYCLES)` runs exactly one collection day (the balance rose by `upkeep + service_charge` and `periods_run` is 1), and advancing the same distance again runs exactly one more, so a phase change that fires four times per cycle bills once;
- that first collection day left the balance ABOVE where it started, which is the spec's pacing promise made on the real clock rather than in arithmetic;
- the quota was unmet, so a collector is due, and the next DAWN serves `Ledger.Punishment.FEE` and no more than one rung: `ranch.serve_collector()` a second time at the same dawn answers `NONE`;
- climbing three more periods with no deliveries serves `PERMIT_REVOKED`, then `PEN_PADLOCKED`, then `BEAM_RECALLED`, in that order, and after each one the world is still whole: the permit's unlock is gone but the region's fence node still exists and every pony inside it is still standing; the padlocked pen still holds every resident and makes no gems over 120 simulated seconds; the beam refuses to start and the saddlebag still holds whatever it held;
- `ranch.pay_the_company(...)` down to the ceiling gives all three back in one call: the unlock is restored, the pen makes gems again, the beam starts;
- **the pony census never falls except through a departure**: the gate counts `ranch.spawner.get_spawned().size()` before and after every step above and asserts it never dropped for any reason other than a body that was in `is_leaving()` when it was last seen;
- a save, a `GameState.reset()`, a rebind and a load bring the balance, the quota, the tier and the padlock list back.

Marker: `LEDGER_OK checks=N`, printed after the verdict; exit code is the verdict.

Run: `tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/ledger_test.tscn`
Expected: `LEDGER_OK checks=N`, exit 0.

#### `depot_test`: a delivery, from the pen to the crate

`game/scenes/test/depot_test.gd`, hosted the same way, checks:

- the Depot stands, its crate marker exists, and the Depot menu opens and refuses to open over the Market;
- a stock pony is caught with the real magic beam (the sequence `collection_test.gd` already uses; read it rather than re-inventing it) and moved into a pen through `ranch._move_pony_into_pen()`;
- `depot_menu.deliver_rows()` lists her, stock first, priced at `Ledger.DELIVERY_CREDIT_STOCK`;
- `ranch.deliver_pony(uid)` answers `{"ok": true, "credit": 300, "named": false}`; the balance fell by exactly 300; `delivered_this_period` is 1; `GameState.find_pony(uid)` is null and every pen's `find_pony(uid)` is null;
- **she is walking, not gone**: on the frame after the delivery her body is still in the tree, `is_leaving()` is true, and her distance to `ranch.crate_position()` is falling; she is freed within `Pony.LEAVE_SECONDS` and her final measured distance to the crate was inside `Pony.LEAVE_ARRIVAL_RADIUS`;
- **NOTHING ELSE LOST A PONY**: the gate holds a `WeakRef` to every pony body in the world across the whole run and asserts that the only one that went null is the delivered one, and that it went null while `is_leaving()` was true;
- a NAMED pony delivered marks her `Compendium.State.PROCESSED`, and the pause menu's compendium page renders her row as `Delivered :)` while the header still counts her as caught;
- `ranch.pay_the_company(200)` moves the balance by exactly 200 and debits the wallet by exactly 200; a pay of more than `Ledger.payable()` takes only what is allowed and the wallet is debited by that same number, never more;
- the statement lines name the player and carry no dash;
- the world's pony count after the whole run is the boot count minus one (the delivered pony), plus whatever `spawner.tick_stock()` legitimately stood back up, and the gate calls `tick_stock` itself so that number is its own rather than the frame count's.

Marker: `DEPOT_OK checks=N`.

Run: `tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/depot_test.tscn`
Expected: `DEPOT_OK checks=N`, exit 0.

#### `creation_test`: the look, the mark and the letters

`game/scenes/test/creation_test.gd` hosts the ranch and drives the creation screen directly (a headless run never opens it on its own, so the gate opens it):

- the screen opens on `GameState.player` and the turntable holds a model;
- cycling each of the three swatch rows all the way round lands every index in range and the model's `body`, `hair`, `tail` and `eyeball_l` overrides follow the player palette at every step: **every palette choice is round tripped**, which the gate does by walking each row's whole length and comparing `StockTint.override_of()` to `StockPalette.load_player()`'s own answer;
- a mark is drawn on `creation_screen.canvas()` with a stamp plus two strokes; `confirm()` puts it on `GameState.player`; the two `CutieMark` decals exist on the player's body and their world positions sit on opposite sides of her barrel;
- `GameState.save_to_slot(slot)`, `GameState.reset()`, `GameState.load_from_slot(slot)`: the name, the three indices and the mark come back, and `MarkPaint.equal()` says the mark is **pixel identical** to what was drawn;
- every `Letters` template renders with a name of exactly `PlayerLook.MAX_NAME_LENGTH` characters and no line exceeds `Letters.LINE_WIDTH`, and none of them carries a dash;
- a hand written version 4 save on disk loads in this build with the name Twilight, the shipped look, a blank mark and a ledger at `Ledger.STARTING_BALANCE`.

Marker: `CREATION_OK checks=N`.

Run: `tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/creation_test.tscn`
Expected: `CREATION_OK checks=N`, exit 0.

#### The gate scaffold every one of the three shares

Copy it from `game/scenes/test/collection_test.gd`, which is the newest and cleanest of the four hosted gates. The parts that must be copied rather than reinvented: `GateWatchdogScript.arm(self, "<NAME>", 180.0)` as the first line of `_ready()`; `var ranch_ok: bool = await ranch.gate_report_finished`; `_set_check(label, ok)` with the duplicate label guard; `_finish()` printing `<NAME>_OK checks=%d` or `<NAME>_FAILED` after the verdict and quitting with it; a fixed capture seed; and reading state through the ranch's accessors rather than by parsing its printed lines.

- [ ] **Step 1: Write the three gates and the pause menu page**

Following the specifications above. Each gate prints only lines prefixed with its own name.

- [ ] **Step 2: Run everything**

```bash
bash tools/run_tests.sh
for scene in market region world collection ledger depot creation; do
  tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/${scene}_test.tscn
  echo "${scene}: $?"
done
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/capture_test.tscn
tools/bin/godot --headless --audio-driver Dummy --path game world/ranch.tscn
bash tools/prove_atomic_save.sh
```
Expected: `---- All tests passed! ----`; `MARKET_OK`, `REGION_OK`, `WORLD_OK`, `COLLECTION_OK`, `LEDGER_OK`, `DEPOT_OK`, `CREATION_OK`, `CAPTURE_OK`, `RANCH_OK`, `ATOMIC_SAVE_PROOF_OK`; every exit code 0.

- [ ] **Step 3: Raise the test floor**

Read the `Tests <N>` line out of the suite's Totals block and set `MIN_TESTS` in `tools/run_tests.sh` to exactly that number. It stood at 653 before this slice, which is also the exact number of `func test_` in `game/test/` today, so the floor and the suite are in step and must stay so. This plan adds roughly 130 tests across nine test files, so expect a number near 780; do not guess it, read it.

```bash
tests=$(bash tools/run_tests.sh 2>&1 | grep -E '^Tests +[0-9]+' | awk '{print $2}')
echo "the suite now runs $tests tests"
sed -i "s/MIN_TESTS=\"\${FILLY_MIN_TESTS:-653}\"/MIN_TESTS=\"\${FILLY_MIN_TESTS:-$tests}\"/" tools/run_tests.sh
grep -n 'MIN_TESTS=' tools/run_tests.sh
```

Then prove the guard still has teeth:

```bash
FILLY_MIN_TESTS=99999 bash tools/run_tests.sh; echo "expected 1, got $?"
```

- [ ] **Step 4: Write the docs**

`docs/testing.md` gains three sections in the style of "The collection gate", one per new gate, each saying what the gate proves that a unit test cannot, the exact run command and the expected marker. Update the ranch gate's line from `RANCH_OK ponies=22 props=58 assets=present` to whatever this slice's ranch actually prints, and note in the same edit that the count moved because the crowd arrived.

`docs/pipeline.md` gains a subsection under the roster material, titled "Recolouring a pony", stating: the base model is `pokeypierce.glb`; the ReVAmped rig's material names are the handle (`body`, `hair`, `tail`, `eyeball_l`, `eyeball_r`, `wings`); Godot's glTF importer copies the glTF material name into `StandardMaterial3D.resource_name`, which is what `StockTint` matches on; a coat or mane surface has its flat albedo texture replaced with a colour and keeps its normal map; an eyeball surface keeps its texture and is modulated, so an eye swatch tints the baked iris rather than replacing it; the cutie mark is a `Decal` per flank on a `BoneAttachment3D` at the `Pelvis` bone, with the measured model space numbers; and a new pony model is usable as a stock base only if its material names match that list, which is the one thing to check when adding one.

Both docs follow the project's copy rule: no em dash, no double hyphen outside an ASCII banner.

- [ ] **Step 5: Commit**

```bash
printf 'test: the ledger, depot and creation gates, and the floor that keeps them\n\nThree hosted gates prove what the unit suite cannot: a collection day that bills\nonce on the real clock and a collector ladder that gives everything back when\npaid; a delivery that walks to the crate and a world that never loses a pony to\nanything but that walk; and a look, a drawn mark and a name that round trip\npixel identical through the save. MIN_TESTS raised to the suite size; the pause\nmenu grows a ledger page; docs/testing.md and docs/pipeline.md updated.\n' > /tmp/msg.txt
git add game/scenes/test/ledger_test.gd game/scenes/test/ledger_test.gd.uid \
  game/scenes/test/ledger_test.tscn game/scenes/test/depot_test.gd \
  game/scenes/test/depot_test.gd.uid game/scenes/test/depot_test.tscn \
  game/scenes/test/creation_test.gd game/scenes/test/creation_test.gd.uid \
  game/scenes/test/creation_test.tscn game/ui/pause_menu.gd game/ui/pause_menu.tscn \
  game/world/ranch.gd game/test/test_pause_menu.gd \
  tools/run_tests.sh docs/testing.md docs/pipeline.md
git commit -F /tmp/msg.txt
```

---

## Self-review

**1. Spec coverage, section by section, for build order item 1.**

| Spec requirement | Task |
|---|---|
| Creation screen: turntable, dawn sky, name box | 8 |
| Coat, mane and tail, eye swatch rows from the same `StockPalette` machinery, wider player palette | 1, 8 |
| Mane style ("otherwise the one") | 8 (`PlayerLook.mane_style`, 0 is the base model's own; the field exists so a second sourced style is data) |
| A cutie mark the player DRAWS: 64 square canvas, colours, brush sizes, eraser, undo, clear, stamp templates, applied to both flanks | 7, 8 |
| The mark saved inside the `player` blob as a base64 PNG, one self contained JSON | 8 |
| Result saved as `player` (name, palette, mane, mark); the player model tinted exactly as stock ponies are, one pipeline two users | 1, 8 |
| v4 save loads with the current look, the name Twilight and a blank mark; no re-edit screen | 8 |
| Stock ponies: one base model, recoloured per instance from a palette (coat, mane, tail, eyes) | 1 |
| Stock spawn in every region in numbers; respawn on a timer; produce COMMON gems in a pen; no Compendium entry | 2, 3 |
| `StockPalette` resource; a stock pony is (palette triple, personality, rarity COMMON) | 1 |
| Recolour is a material tint on coat and mane surfaces; a one off pipeline change in `docs/pipeline.md` | 1, 9 |
| `Spawner` keeps map wide no duplicates for named characters and gains a stock budget; `stock_min`/`stock_max` on `RegionData` | 2 |
| Stock ponies flee, get caught, get penned and leave exactly as named ponies do; `Pony` does not know the difference | 2, 3 |
| `PonyInstance.stock: Dictionary`; a stock pony in a pen is a real resident and saves as one | 3 |
| Named ponies keep their conditions and rarities; they are the thing hunted among the stock | 2 |
| `Ledger`: balance, `LEDGER_STARTING_BALANCE` 25000, shown in the pause menu and on the HUD as "CWC balance" | 4, 6, 9 |
| Collection day every 3 cycles; upkeep is a base plus per built plot and per open permit, times the rank multiplier | 4 |
| Deliveries credit: `DELIVERY_CREDIT_STOCK` 300, named by rarity times `DELIVERY_NAMED_MULTIPLIER` 40, a legendary clears 4000 | 4 |
| Quota starts at 2; unmet or over `LEDGER_CEILING` calls a collector at the next dawn | 4, 6 |
| Collector ladder in order: fee, permit revoked, pen padlocked, beam recalled for one cycle; nothing deleted; recoverable by paying; no pony taken | 4, 6 |
| Interest, small and shown, "service charge" | 4 |
| "Gems alone never clear the balance" as a tuning invariant with a test | 4 |
| Depot: a Company building beside the Market, a loading dock with a crate | 5 |
| Deliver lists penned ponies, stock first then named with their credit; confirm and she walks to the crate by `Pony.leave()`; credit, quota, receipt | 5 |
| Pay bits against the balance | 5 |
| Statement: balance, upkeep breakdown, next collection day, quota progress, rank | 4, 5 (rank is a later slice's field; the statement carries the multiplier's effect through `upkeep_for`) |
| Named deliveries set the Compendium to `PROCESSED`, rendered before the fork as "Delivered" with a smiley | 5 |
| Stub receipt letters with fixed text | 5 |
| Save `player` and `ledger`; version becomes 5; v4 loads | 4, 8 |
| Pacing: first collection day at one real hour; named at most 1 in 5 in the ranch and rarer beyond; stock respawn on a timer; capture flow unchanged | 2, 4 |
| Testing: `ledger_test`, `depot_test`, `creation_test`, save round trips for every new key, the visual harness reviewed by eye | 1, 7, 8, 9 |

Explicitly out of scope and absent from every task, as the brief requires: the casino and the Strip, `Story`/`StoryBeat`/chapters/mail, the Town and NPCs, `PonyData.npc`, the insider and the fork, heat, `InsiderTask`, `Rank`, `RESCUED`, `pylon_position`, and the Factory interior. The one interface a later slice needs and gets here is the `player` save key and `Letters`, because letters are addressed by name from slice 3 onward.

**2. Placeholder scan.** Every code step carries real code. Three places name a judgement rather than a literal, and each names how to get the literal: the `MIN_TESTS` value (Task 9 reads it out of the run rather than guessing it), `collection_test.gd`'s `EXPECTED_EXTRA_NIGHTS` (Task 2 re-measures it and says so in the commit), and `CutieMark.FLANK`/`DECAL_SIZE` (Task 7 ships measured numbers and Step 8 is a look by eye that may nudge them). The three gate scripts in Task 9 are specified as check lists rather than as full listings because each is 400 to 900 lines of scaffold copied from `collection_test.gd`; the checks themselves, the markers, the run commands and the expected output are all stated.

**3. Type and signature consistency.** `StockPalette.IDS`, `is_stock_id()`, `coat_at`/`mane_at`/`eye_at` and `draw_triple` are used in Tasks 2, 7 and 8 as Task 1 defines them. `StockTint.apply(model, palette, triple)` and `override_of(model, material_name)` are used in Tasks 2, 7, 8 and 9 as Task 1 defines them. `Pony.set_stock`/`get_stock`/`is_stock` are defined in Task 2 and read in Tasks 3 and 5. `PonyInstance.stock`/`is_stock()` are defined in Task 3 and read in Tasks 5 and 6. `Ledger`'s constants and methods are defined in Task 4 and used verbatim in Tasks 5, 6 and 9, including `shipments`, which Task 5's receipt reads. `Pen.release_body`/`set_padlocked`/`is_padlocked` are defined in Task 5 and used in Task 6. `Pony.leave_toward` is defined in Task 5 and used only there. `MarkPaint`, `MarkStamps`, `MarkCanvas` and `CutieMark` are defined in Task 7 and used in Task 8. `PlayerLook` is defined in Task 8 and read by `ranch._player_name()`, which Task 5 introduces returning the literal "Twilight" and Task 8 makes real; that hand off is stated at both ends. `Ranch._relieve_if_paid_down()` is introduced in Task 5 with a working body and completed in Task 6; both bodies are written out.
