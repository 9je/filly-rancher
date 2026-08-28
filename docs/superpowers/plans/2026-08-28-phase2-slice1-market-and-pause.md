# Phase 2 Slice 1: Market and Pause Menu Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the dead economy loop (gems are produced but nothing sells them) with a Market that sells gems and buys care items and gear, and replace the cursor-dropping Escape key with a real pause menu.

**Architecture:** Pure-logic RefCounted classes first (`GemPouch`, `Inventory`, `Shop`), each GUT-tested in isolation with no scene, following `Economy` and `Storage`. Then the data (`ShopItem` resources under `game/data/shop/`, loaded by a `ShopRegistry` that mirrors `PlotRegistry`). Then the two CanvasLayer menus, modelled on `BuildMenu`: they draw and emit, and `ranch.gd` transacts, pauses and unpauses. Pens auto-feed hungry residents from the shared inventory, so care items have a purpose without a feeding UI. A headless gate (`market_test.tscn`) proves the whole loop end to end and prints its marker only after deciding the verdict.

**Tech Stack:** Godot 4.5.2 (GDScript, Forward+), GUT for unit tests, the project's headless gate convention (`GateWatchdog`, `_set_check`, marker after verdict, exit code is the verdict).

**Spec:** `docs/superpowers/specs/2026-08-28-phase2-bigger-world-design.md`, sections "The Market", "Pause menu", "Data model changes", "Testing".

## Global Constraints

- No em dash (U+2014) and no double hyphen (` -- `) in anything a player can read: toasts, menu rows, hint card, footers. Comma, colon, full stop or a rephrase instead. (Owner's standing instruction, 2026-08-28.) Existing code comments keep whatever they have; new comments you write follow the same rule.
- Every menu must be navigable without a mouse: `ui_up`/`ui_down`/`ui_left`/`ui_right`/`ui_accept`/`ui_cancel`, keyboard and gamepad. The hint card must name every binding it claims exists.
- Menus draw and emit; `ranch.gd` transacts, pauses the tree, and frees or captures the cursor. A menu never touches the wallet. (The pattern `build_menu.gd` establishes; its class comment explains why.)
- `NO PONY EVER DIES`: nothing in this slice may remove a `PonyInstance` from the world.
- Pure-logic systems are `RefCounted`, no Node, no scene, testable in milliseconds.
- A gate prints `<NAME>_OK` only after deciding it passed, and `quit(0 if passed else 1)`. Exit code is the verdict.
- Save format: every new key is optional on load with a new-game default; `SaveIO.FORMAT_VERSION` increments to 2 with a `migrate()` branch; a version 1 file must still load.
- Preload scripts by `res://` path, not by global `class_name` (convention at the top of `game/scripts/pony_rig.gd`).
- `tools/run_tests.sh` has a test-count floor (`MIN_TESTS`). Raise it in the final task to the new count.
- Commit after every task. Branch: `phase2-slice1-market`.

---

## File map

| File | Responsibility |
|---|---|
| `game/systems/gem_pouch.gd` (new) | Gems the player holds, counted by producing rarity. Pure logic. |
| `game/systems/inventory.gd` (new) | Consumables the player holds, counted by item id. Pure logic. |
| `game/systems/shop_item.gd` (new) | One thing the Market sells: a Resource, one `.tres` each. |
| `game/systems/shop_registry.gd` (new) | Loads `game/data/shop/*.tres`, cheapest first. Mirrors `PlotRegistry`. |
| `game/systems/shop.gd` (new) | The transaction: sell gems for bits, buy items with bits. Pure logic. |
| `game/data/shop/*.tres` (new) | The catalogue: five foods, two gear items. |
| `game/systems/game_state.gd` | Gains `gems` and `inventory`, saved and loaded. |
| `game/systems/save_io.gd` | `FORMAT_VERSION` 2, `migrate()` from 1. |
| `game/world/pen.gd` | Tray counts gems by rarity; residents eat from the inventory. |
| `game/actors/player/magic_beam.gd` | `set_storage_capacity()` for the saddlebag gear; reach reads a multiplier. |
| `game/ui/market_menu.gd`, `.tscn` (new) | Sell and Buy tabs. Draws, emits. |
| `game/ui/pause_menu.gd`, `.tscn` (new) | Resume, Save, Settings, Quit. Draws, emits. |
| `game/systems/settings.gd` (new) | Volume, sensitivity, invert; persisted in `user://settings.cfg`. |
| `game/actors/player/camera_rig.gd` | `invert_look`; the Escape toggle is removed. |
| `game/ui/hud.gd` | Bits line; hint rows for PAUSE and TRADE. |
| `game/world/ranch.gd`, `ranch.tscn` | Market building, interaction, wiring for both menus, gem collection. |
| `game/project.godot` | `pause` action; `ui_left`/`ui_right` overrides if the probe shows no pad binding. |
| `game/scenes/test/market_test.gd`, `.tscn` (new) | The headless gate for the whole loop. |
| `game/test/test_gem_pouch.gd`, `test_inventory.gd`, `test_shop.gd`, `test_shop_registry.gd`, `test_market_menu.gd`, `test_pause_menu.gd`, `test_settings.gd` (new); `test_pen.gd`, `test_game_state.gd`, `test_save_io.gd`, `test_hud.gd`, `test_build_menu.gd`, `test_camera_rig.gd` (modified) | Tests. |

---

### Task 1: GemPouch

**Files:**
- Create: `game/systems/gem_pouch.gd`
- Test: `game/test/test_gem_pouch.gd`

**Interfaces:**
- Consumes: `PonyData.Rarity` (int enum: COMMON 0, UNCOMMON 1, RARE 2, LEGENDARY 3).
- Produces: `class_name GemPouch extends RefCounted` with `signal changed()`, `add(rarity: int, count: int) -> void`, `count(rarity: int) -> int`, `total() -> int`, `take(rarity: int, count: int) -> int` (returns how many actually left), `take_all(rarity: int) -> int`, `to_dict() -> Dictionary` (String keys `"0".."3"`), `static func from_dict(d: Dictionary) -> GemPouch`, `is_empty() -> bool`.

- [ ] **Step 1: Write the failing tests**

```gdscript
extends GutTest
## Tests for game/systems/gem_pouch.gd: the gems the player holds, by producing rarity.
## Pure logic, no scene, same discipline as test_economy.gd and test_storage.gd.

const GemPouchScript := preload("res://systems/gem_pouch.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")


func test_a_new_pouch_is_empty() -> void:
	var pouch = GemPouchScript.new()
	assert_true(pouch.is_empty())
	assert_eq(pouch.total(), 0)
	assert_eq(pouch.count(PonyDataScript.Rarity.COMMON), 0)


func test_adding_counts_by_rarity_and_totals_across_them() -> void:
	var pouch = GemPouchScript.new()
	pouch.add(PonyDataScript.Rarity.COMMON, 3)
	pouch.add(PonyDataScript.Rarity.RARE, 2)
	assert_eq(pouch.count(PonyDataScript.Rarity.COMMON), 3)
	assert_eq(pouch.count(PonyDataScript.Rarity.RARE), 2)
	assert_eq(pouch.count(PonyDataScript.Rarity.LEGENDARY), 0)
	assert_eq(pouch.total(), 5)
	assert_false(pouch.is_empty())


func test_adding_zero_or_negative_changes_nothing_and_does_not_signal() -> void:
	var pouch = GemPouchScript.new()
	watch_signals(pouch)
	pouch.add(PonyDataScript.Rarity.COMMON, 0)
	pouch.add(PonyDataScript.Rarity.COMMON, -4)
	assert_eq(pouch.total(), 0)
	assert_signal_not_emitted(pouch, "changed")


func test_adding_a_rarity_that_does_not_exist_is_refused() -> void:
	var pouch = GemPouchScript.new()
	pouch.add(99, 5)
	assert_eq(pouch.total(), 0, "an unknown rarity is not a gem")


func test_take_removes_up_to_what_is_there_and_reports_how_many_left() -> void:
	var pouch = GemPouchScript.new()
	pouch.add(PonyDataScript.Rarity.UNCOMMON, 2)
	assert_eq(pouch.take(PonyDataScript.Rarity.UNCOMMON, 5), 2, "you cannot take more than you have")
	assert_eq(pouch.count(PonyDataScript.Rarity.UNCOMMON), 0)
	assert_eq(pouch.take(PonyDataScript.Rarity.UNCOMMON, 1), 0, "taking from an empty tier takes nothing")


func test_take_all_empties_one_tier_only() -> void:
	var pouch = GemPouchScript.new()
	pouch.add(PonyDataScript.Rarity.COMMON, 4)
	pouch.add(PonyDataScript.Rarity.RARE, 1)
	assert_eq(pouch.take_all(PonyDataScript.Rarity.COMMON), 4)
	assert_eq(pouch.count(PonyDataScript.Rarity.COMMON), 0)
	assert_eq(pouch.count(PonyDataScript.Rarity.RARE), 1, "the other tier is untouched")


func test_changed_fires_once_per_real_change() -> void:
	var pouch = GemPouchScript.new()
	watch_signals(pouch)
	pouch.add(PonyDataScript.Rarity.COMMON, 1)
	pouch.take(PonyDataScript.Rarity.COMMON, 1)
	pouch.take(PonyDataScript.Rarity.COMMON, 1)
	assert_signal_emit_count(pouch, "changed", 2, "add and the first take; the empty take is a no-op")


func test_round_trips_through_a_json_safe_dictionary_with_string_keys() -> void:
	var pouch = GemPouchScript.new()
	pouch.add(PonyDataScript.Rarity.COMMON, 3)
	pouch.add(PonyDataScript.Rarity.LEGENDARY, 1)
	var d := pouch.to_dict()
	for key in d.keys():
		assert_typeof(key, TYPE_STRING, "JSON has no integer keys, so the pouch must not use them")
	var back = GemPouchScript.from_dict(d)
	assert_eq(back.count(PonyDataScript.Rarity.COMMON), 3)
	assert_eq(back.count(PonyDataScript.Rarity.LEGENDARY), 1)
	assert_eq(back.total(), 4)


func test_from_dict_ignores_junk_and_never_goes_negative() -> void:
	var back = GemPouchScript.from_dict({"0": -5, "banana": 3, "2": "seven", "3": 2})
	assert_eq(back.count(PonyDataScript.Rarity.COMMON), 0, "a negative count is clamped")
	assert_eq(back.count(PonyDataScript.Rarity.RARE), 0, "a non-integer is dropped")
	assert_eq(back.count(PonyDataScript.Rarity.LEGENDARY), 2)
	assert_eq(back.total(), 2)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd /home/admin/Documents/filly-rancher && tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_gem_pouch.gd -gexit 2>&1 | grep -E "Tests|Passing|Failing|error"`
Expected: parse error, `Preload file "res://systems/gem_pouch.gd" does not exist`, zero tests run.

- [ ] **Step 3: Write the implementation**

```gdscript
class_name GemPouch
extends RefCounted
## THE GEMS THE PLAYER HOLDS, counted by the rarity of the pony who produced them.
##
## A gem has no identity of its own: Economy.sell() prices it by PonyData.Rarity and by
## nothing else (see economy.gd's class comment), so this pouch is four integers. It exists
## so that gems survive quitting: a pen's tray (game/world/pen.gd) is a transient staging
## area, and game/world/ranch.gd folds every tray into this pouch before a save and when
## the Market opens. GameState carries the pouch as `gems`.
##
## RefCounted, no scene, GUT-tested in isolation (game/test/test_gem_pouch.gd), the same
## discipline as Economy and Storage.

const PonyDataScript := preload("res://systems/pony_data.gd")

## Emitted once per real change. Not for a no-op (an add of zero, a take from an empty
## tier), matching Storage.changed's rule.
signal changed()

var _counts: Dictionary = {}


static func _is_rarity(rarity: int) -> bool:
	return PonyDataScript.Rarity.values().has(rarity)


func add(rarity: int, count: int) -> void:
	if count <= 0 or not _is_rarity(rarity):
		return
	_counts[rarity] = int(_counts.get(rarity, 0)) + count
	changed.emit()


func count(rarity: int) -> int:
	return int(_counts.get(rarity, 0))


func total() -> int:
	var sum := 0
	for value in _counts.values():
		sum += int(value)
	return sum


func is_empty() -> bool:
	return total() == 0


## Take up to `count` gems of `rarity`. Returns how many actually left the pouch.
func take(rarity: int, count: int) -> int:
	if count <= 0:
		return 0
	var have := count_of(rarity)
	var taken := mini(have, count)
	if taken <= 0:
		return 0
	_counts[rarity] = have - taken
	changed.emit()
	return taken


func take_all(rarity: int) -> int:
	return take(rarity, count(rarity))


## Alias kept private-ish so take() reads clearly; count() is the public name.
func count_of(rarity: int) -> int:
	return count(rarity)


## String keys, because JSON has no integer keys and GameState.plots learned that the
## hard way (see game_state.gd).
func to_dict() -> Dictionary:
	var out := {}
	for rarity in _counts.keys():
		if int(_counts[rarity]) > 0:
			out[str(rarity)] = int(_counts[rarity])
	return out


static func from_dict(d: Dictionary) -> GemPouch:
	var pouch := GemPouch.new()
	for key in d.keys():
		var rarity := int(str(key)) if str(key).is_valid_int() else -1
		var raw: Variant = d[key]
		if not _is_rarity(rarity):
			continue
		if typeof(raw) != TYPE_INT and typeof(raw) != TYPE_FLOAT:
			continue
		var value := maxi(0, int(raw))
		if value > 0:
			pouch._counts[rarity] = value
	return pouch
```

- [ ] **Step 4: Run the test to verify it passes**

Run: same command as Step 2.
Expected: `Tests 9`, `Passing Tests 9`.

- [ ] **Step 5: Commit**

```bash
cd /home/admin/Documents/filly-rancher
git switch -c phase2-slice1-market
git add game/systems/gem_pouch.gd game/test/test_gem_pouch.gd
git commit -m "feat: GemPouch, the player's gems counted by producing rarity"
```

---

### Task 2: Inventory

**Files:**
- Create: `game/systems/inventory.gd`
- Test: `game/test/test_inventory.gd`

**Interfaces:**
- Produces: `class_name Inventory extends RefCounted` with `signal changed()`, `add(item_id: StringName, count: int) -> void`, `remove(item_id: StringName, count: int) -> bool` (all or nothing), `count(item_id: StringName) -> int`, `has(item_id: StringName) -> bool`, `ids() -> Array[StringName]` (sorted), `to_dict() -> Dictionary` (String keys), `static func from_dict(d: Dictionary) -> Inventory`.

- [ ] **Step 1: Write the failing tests**

```gdscript
extends GutTest
## Tests for game/systems/inventory.gd: consumables the player holds, by item id.

const InventoryScript := preload("res://systems/inventory.gd")


func test_starts_empty() -> void:
	var inv = InventoryScript.new()
	assert_eq(inv.count(&"hay"), 0)
	assert_false(inv.has(&"hay"))
	assert_eq(inv.ids().size(), 0)


func test_add_and_count() -> void:
	var inv = InventoryScript.new()
	inv.add(&"hay", 2)
	inv.add(&"hay", 3)
	inv.add(&"apple", 1)
	assert_eq(inv.count(&"hay"), 5)
	assert_eq(inv.count(&"apple"), 1)
	assert_eq(inv.ids(), [&"apple", &"hay"], "ids come back sorted so a UI is stable")


func test_add_of_nothing_is_a_no_op() -> void:
	var inv = InventoryScript.new()
	watch_signals(inv)
	inv.add(&"hay", 0)
	inv.add(&"hay", -1)
	inv.add(&"", 4)
	assert_eq(inv.ids().size(), 0)
	assert_signal_not_emitted(inv, "changed")


func test_remove_is_all_or_nothing() -> void:
	var inv = InventoryScript.new()
	inv.add(&"hay", 2)
	assert_false(inv.remove(&"hay", 3), "cannot remove more than is held")
	assert_eq(inv.count(&"hay"), 2, "a refusal changes nothing")
	assert_true(inv.remove(&"hay", 2))
	assert_eq(inv.count(&"hay"), 0)
	assert_false(inv.has(&"hay"), "a zeroed item is gone, not held at zero")


func test_changed_fires_on_add_and_on_a_successful_remove_only() -> void:
	var inv = InventoryScript.new()
	watch_signals(inv)
	inv.add(&"hay", 1)
	inv.remove(&"hay", 5)
	inv.remove(&"hay", 1)
	assert_signal_emit_count(inv, "changed", 2)


func test_round_trips_with_string_keys() -> void:
	var inv = InventoryScript.new()
	inv.add(&"hay", 4)
	inv.add(&"carrot", 1)
	var d := inv.to_dict()
	for key in d.keys():
		assert_typeof(key, TYPE_STRING)
	var back = InventoryScript.from_dict(d)
	assert_eq(back.count(&"hay"), 4)
	assert_eq(back.count(&"carrot"), 1)


func test_from_dict_drops_junk() -> void:
	var back = InventoryScript.from_dict({"hay": -2, "apple": "lots", "carrot": 2.0, "": 5})
	assert_eq(back.count(&"hay"), 0)
	assert_eq(back.count(&"apple"), 0)
	assert_eq(back.count(&"carrot"), 2)
	assert_eq(back.ids(), [&"carrot"])
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_inventory.gd -gexit 2>&1 | grep -E "Tests|Passing|Failing|error"`
Expected: preload error, zero tests.

- [ ] **Step 3: Write the implementation**

```gdscript
class_name Inventory
extends RefCounted
## CONSUMABLES THE PLAYER HOLDS, counted by item id: hay, apples, whatever the Market's
## CARE rows sell. Pens draw from it to feed hungry residents (game/world/pen.gd), so the
## running cost of a ranch is visible here going down.
##
## Item ids are the ShopItem/FoodData ids. This class does not know what an id means; it
## counts. RefCounted, no scene, GUT-tested (game/test/test_inventory.gd).

signal changed()

var _counts: Dictionary = {}


func add(item_id: StringName, count: int) -> void:
	if count <= 0 or String(item_id).is_empty():
		return
	_counts[item_id] = int(_counts.get(item_id, 0)) + count
	changed.emit()


## All or nothing: a remove that cannot be fully honoured changes nothing.
func remove(item_id: StringName, count: int) -> bool:
	if count <= 0:
		return false
	var have := int(_counts.get(item_id, 0))
	if have < count:
		return false
	if have == count:
		_counts.erase(item_id)
	else:
		_counts[item_id] = have - count
	changed.emit()
	return true


func count(item_id: StringName) -> int:
	return int(_counts.get(item_id, 0))


func has(item_id: StringName) -> bool:
	return count(item_id) > 0


func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for key in _counts.keys():
		out.append(key)
	out.sort()
	return out


func to_dict() -> Dictionary:
	var out := {}
	for key in _counts.keys():
		out[String(key)] = int(_counts[key])
	return out


static func from_dict(d: Dictionary) -> Inventory:
	var inv := Inventory.new()
	for key in d.keys():
		var id := String(key)
		var raw: Variant = d[key]
		if id.is_empty():
			continue
		if typeof(raw) != TYPE_INT and typeof(raw) != TYPE_FLOAT:
			continue
		var value := int(raw)
		if value > 0:
			inv._counts[StringName(id)] = value
	return inv
```

- [ ] **Step 4: Run the test to verify it passes**

Expected: `Tests 7`, `Passing Tests 7`.

- [ ] **Step 5: Commit**

```bash
git add game/systems/inventory.gd game/test/test_inventory.gd
git commit -m "feat: Inventory, consumables counted by item id"
```

---

### Task 3: ShopItem resource and ShopRegistry, with the catalogue

**Files:**
- Create: `game/systems/shop_item.gd`, `game/systems/shop_registry.gd`
- Create: `game/data/shop/hay.tres`, `apple.tres`, `carrot.tres`, `daisy.tres`, `daffodil.tres`, `bigger_saddlebag.tres`, `long_beam.tres`
- Test: `game/test/test_shop_registry.gd`

**Interfaces:**
- Consumes: `FoodData` ids in `game/data/foods/` (`hay`, `apple`, `carrot`, `daisy`, `daffodil`).
- Produces: `class_name ShopItem extends Resource` with `enum Kind { GEAR, PERMIT, BUILD, CARE }`, exports `id: StringName`, `display_name: String`, `description: String` (multiline), `cost: int`, `kind: Kind`, `food_id: StringName` (CARE), `gear_id: StringName` (GEAR), `permit_zone: StringName` (PERMIT), `plot_id: StringName` (BUILD), `quantity: int` (CARE: how many per purchase, default 1). `class_name ShopRegistry` with `const SHOP_DIR := "res://data/shop"`, `load_all(dir := SHOP_DIR) -> Dictionary`, `all() -> Array[ShopItem]` (cost ascending, then id), `by_id(id) -> ShopItem`, `of_kind(kind: int) -> Array[ShopItem]`.

- [ ] **Step 1: Write the failing tests**

```gdscript
extends GutTest
## Tests for the shop catalogue: game/systems/shop_item.gd, game/systems/shop_registry.gd,
## and the .tres files under game/data/shop/. Mirrors test_plot_registry's shape.

const ShopRegistryScript := preload("res://systems/shop_registry.gd")
const ShopItemScript := preload("res://systems/shop_item.gd")
const FoodRegistryScript := preload("res://systems/food_registry.gd")


func _registry() -> ShopRegistry:
	var reg: ShopRegistry = ShopRegistryScript.new()
	reg.load_all(ShopRegistryScript.SHOP_DIR)
	return reg


func test_the_shipped_catalogue_loads_and_is_not_empty() -> void:
	var items := _registry().all()
	assert_gt(items.size(), 0)


func test_every_item_has_an_id_a_name_and_a_non_negative_cost() -> void:
	for item in _registry().all():
		assert_false(String(item.id).is_empty(), "every item needs an id")
		assert_false(item.display_name.is_empty(), "%s needs a display name" % item.id)
		assert_gte(item.cost, 0, "%s cannot have a negative cost" % item.id)


func test_ids_are_unique_and_by_id_finds_each() -> void:
	var reg := _registry()
	var seen := {}
	for item in reg.all():
		assert_false(seen.has(item.id), "duplicate id %s" % item.id)
		seen[item.id] = true
		assert_eq(reg.by_id(item.id), item)
	assert_null(reg.by_id(&"no_such_item"))


func test_all_is_sorted_cheapest_first_then_by_id() -> void:
	var items := _registry().all()
	for i in range(1, items.size()):
		var a := items[i - 1]
		var b := items[i]
		var ordered := a.cost < b.cost or (a.cost == b.cost and String(a.id) < String(b.id))
		assert_true(ordered, "%s should come before %s" % [a.id, b.id])


func test_every_care_item_names_a_food_that_exists() -> void:
	var foods: FoodRegistry = FoodRegistryScript.new()
	foods.load_all("res://data/foods")
	var care := _registry().of_kind(ShopItemScript.Kind.CARE)
	assert_gt(care.size(), 0, "the Market must sell at least one food")
	for item in care:
		assert_not_null(foods.by_id(item.food_id),
			"CARE item %s points at food '%s', which is not in game/data/foods" % [item.id, item.food_id])
		assert_gt(item.quantity, 0, "%s must hand over at least one" % item.id)


func test_every_gear_item_has_a_gear_id() -> void:
	var gear := _registry().of_kind(ShopItemScript.Kind.GEAR)
	assert_gt(gear.size(), 0, "the Market must sell at least one piece of gear")
	for item in gear:
		assert_false(String(item.gear_id).is_empty(), "%s needs a gear_id" % item.id)


func test_at_least_one_item_costs_less_than_one_common_gem_sale_of_five() -> void:
	# Five common gems sell for 25 bits (Economy.GEM_VALUE_BY_RARITY). A catalogue whose
	# cheapest row costs more than that is a shop a new player cannot enter.
	var cheapest := _registry().all()[0]
	assert_lte(cheapest.cost, 25, "cheapest item is %s at %d" % [cheapest.id, cheapest.cost])


func test_a_missing_directory_loads_nothing_and_does_not_crash() -> void:
	var reg: ShopRegistry = ShopRegistryScript.new()
	var loaded := reg.load_all("res://data/no_such_dir")
	assert_eq(loaded.size(), 0)
	assert_eq(reg.all().size(), 0)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_shop_registry.gd -gexit 2>&1 | grep -E "Tests|Passing|Failing|error"`
Expected: preload error.

- [ ] **Step 3: Write ShopItem**

```gdscript
class_name ShopItem
extends Resource
## ONE ROW OF THE MARKET'S BUY TAB. What it is called, what it costs, and what buying it
## does. One .tres per item under game/data/shop/, so adding a thing to sell is authoring
## a data file, never writing code: the same rule PonyData, FoodData and PlotData follow.
##
## `kind` says which of four things the purchase does, and the payload field for that
## kind is the only one that matters; the others stay at their defaults.
##
##   CARE    the player gets `quantity` of `food_id` in her Inventory. Pens feed hungry
##           residents from it (game/world/pen.gd).
##   GEAR    `gear_id` is appended to GameState.unlocks, once. Game code reads unlocks to
##           apply the effect (a bigger saddlebag, a longer beam). Never sold twice.
##   PERMIT  `permit_zone` is appended to GameState.unlocks; a RegionGate for that zone
##           opens. Phase 2 slice 3 adds the gates; the kind exists now so the data model
##           does not change under them.
##   BUILD   `plot_id`, reserved for moving the plot catalogue into this shop. Not sold
##           in this slice; the build menu still owns building.
##
## Thin on purpose. How a purchase is paid for is Shop's business (game/systems/shop.gd),
## and what a gear id does is the business of whatever reads it.

enum Kind { GEAR, PERMIT, BUILD, CARE }

## Unique lookup key, e.g. &"hay" or &"bigger_saddlebag". The ShopRegistry dictionary key.
@export var id: StringName = &""

## What the Buy tab calls it. Never the id.
@export var display_name: String = ""

## One line for the player choosing between rows.
@export_multiline var description: String = ""

## Bits. Zero is legal (a starter handout), negative is not (ShopRegistry refuses it).
@export var cost: int = 0

@export var kind: Kind = Kind.CARE

## CARE: which FoodData this is, and how many one purchase hands over.
@export var food_id: StringName = &""
@export var quantity: int = 1

## GEAR: the unlock id game code looks for.
@export var gear_id: StringName = &""

## PERMIT: the zone whose gate this opens.
@export var permit_zone: StringName = &""

## BUILD: the PlotData this stands for. Unused in slice 1.
@export var plot_id: StringName = &""


func _to_string() -> String:
	return "ShopItem(%s, %s, cost=%d)" % [String(id), Kind.keys()[kind], cost]
```

- [ ] **Step 4: Write ShopRegistry**

Read `game/systems/plot_registry.gd` first and keep the same shape (it handles `.tres` and `.remap` names for exported builds through `_resource_path`; copy that helper verbatim).

```gdscript
class_name ShopRegistry
extends RefCounted
## Loads every ShopItem under game/data/shop/ and hands them out cheapest first. The
## same shape as PlotRegistry (game/systems/plot_registry.gd), for the same reasons: a
## sorted list for a menu, a by_id() for a save, and a loader that refuses a bad file
## loudly rather than letting a typo become a row that sells nothing.

const SHOP_DIR := "res://data/shop"
const ShopItemScript := preload("res://systems/shop_item.gd")

var _items: Dictionary = {}
var _ordered: Array[ShopItem] = []


func load_all(dir: String = SHOP_DIR) -> Dictionary:
	_items.clear()
	_ordered.clear()
	var access := DirAccess.open(dir)
	if access == null:
		push_error("ShopRegistry.load_all: cannot open '%s'" % dir)
		return _items
	for file_name in access.get_files():
		if not (file_name.ends_with(".tres") or file_name.ends_with(".tres.remap")):
			continue
		_load_one(_resource_path(dir, file_name))
	_rebuild_order()
	return _items


## Exported builds rename `x.tres` to `x.tres.remap`; the resource is still loaded by
## its original path. Copied from PlotRegistry so both registries agree.
func _resource_path(dir: String, file_name: String) -> String:
	var stem := file_name
	if stem.ends_with(".remap"):
		stem = stem.substr(0, stem.length() - ".remap".length())
	return dir.path_join(stem)


func _load_one(path: String) -> void:
	var res := load(path)
	var item := res as ShopItem
	if item == null:
		push_error("ShopRegistry: '%s' is not a ShopItem" % path)
		return
	if String(item.id).is_empty():
		push_error("ShopRegistry: '%s' has an empty id" % path)
		return
	if item.cost < 0:
		push_error("ShopRegistry: '%s' has a negative cost" % path)
		return
	if _items.has(item.id):
		push_error("ShopRegistry: duplicate id '%s' in '%s'" % [item.id, path])
		return
	_items[item.id] = item


func _rebuild_order() -> void:
	_ordered.clear()
	for item in _items.values():
		_ordered.append(item)
	_ordered.sort_custom(func(a: ShopItem, b: ShopItem) -> bool:
		if a.cost != b.cost:
			return a.cost < b.cost
		return String(a.id) < String(b.id))


func all() -> Array[ShopItem]:
	return _ordered.duplicate()


func by_id(id: StringName) -> ShopItem:
	return _items.get(id, null)


func of_kind(kind: int) -> Array[ShopItem]:
	var out: Array[ShopItem] = []
	for item in _ordered:
		if item.kind == kind:
			out.append(item)
	return out
```

- [ ] **Step 5: Write the seven catalogue files**

Costs are chosen against `Economy.GEM_VALUE_BY_RARITY` (common gem 5 bits) and `Needs.HUNGER_FULL_TO_STARVING_SECONDS` (600 s): one common pony makes a gem every 20 s when happy, so a 5-bit hay every 10 minutes is affordable from one pony. Gear is priced as a goal, not a purchase.

`game/data/shop/hay.tres`:
```
[gd_resource type="Resource" script_class="ShopItem" load_steps=2 format=3]

[ext_resource type="Script" path="res://systems/shop_item.gd" id="1_shop"]

[resource]
script = ExtResource("1_shop")
id = &"hay"
display_name = "Hay"
description = "A bale of it. Every pony will eat hay, and none of them will thank you for it."
cost = 5
kind = 3
food_id = &"hay"
quantity = 2
```

`apple.tres`: id `apple`, name `Apples`, description `Sweet and crisp. A favourite of the earth ponies.`, cost 8, kind 3, food_id `apple`, quantity 2.
`carrot.tres`: id `carrot`, name `Carrots`, description `Crunchy. Good for the eyes, or so the pegasi say.`, cost 8, kind 3, food_id `carrot`, quantity 2.
`daisy.tres`: id `daisy`, name `Daisies`, description `A posy of them. Delicate ponies are fond of daisies.`, cost 12, kind 3, food_id `daisy`, quantity 2.
`daffodil.tres`: id `daffodil`, name `Daffodils`, description `Bright and rare in the wild. Some ponies think of nothing else.`, cost 15, kind 3, food_id `daffodil`, quantity 2.

`bigger_saddlebag.tres`:
```
[gd_resource type="Resource" script_class="ShopItem" load_steps=2 format=3]

[ext_resource type="Script" path="res://systems/shop_item.gd" id="1_shop"]

[resource]
script = ExtResource("1_shop")
id = &"bigger_saddlebag"
display_name = "Bigger Saddlebag"
description = "Six more pockets. Carry eighteen ponies before you have to walk home."
cost = 120
kind = 0
gear_id = &"bigger_saddlebag"
```

`long_beam.tres`: id `long_beam`, name `Long Beam`, description `A steadier horn. Your magic reaches a full metre further.`, cost 200, kind 0, gear_id `long_beam`.

`kind = 3` is `Kind.CARE`, `kind = 0` is `Kind.GEAR` (enum order GEAR, PERMIT, BUILD, CARE).

- [ ] **Step 6: Reimport so Godot sees the new resources, then run the test**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game --import >/dev/null 2>&1; tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_shop_registry.gd -gexit 2>&1 | grep -E "Tests|Passing|Failing|error"`
Expected: `Tests 8`, `Passing Tests 8`.

- [ ] **Step 7: Commit**

```bash
git add game/systems/shop_item.gd game/systems/shop_registry.gd game/data/shop/ game/test/test_shop_registry.gd
git commit -m "feat: ShopItem resources and ShopRegistry, with a seven-row catalogue"
```

---

### Task 4: Shop, the transaction

**Files:**
- Create: `game/systems/shop.gd`
- Test: `game/test/test_shop.gd`

**Interfaces:**
- Consumes: `Economy` (`sell(rarity, count) -> int`, `can_afford(cost)`, `spend(cost) -> bool`), `GemPouch`, `Inventory`, `ShopItem`.
- Produces: `class_name Shop extends RefCounted`, `_init(economy: Economy, pouch: GemPouch, inventory: Inventory, unlocks: Array)`. Note `unlocks` is the live `GameState.unlocks` Array, mutated in place. `signal sold(rarity: int, count: int, bits: int)`, `signal bought(item: ShopItem)`. `gem_count(rarity) -> int`, `gem_price(rarity) -> int`, `sell(rarity, count) -> int` (bits earned), `sell_all() -> int`, `owns_gear(gear_id) -> bool`, `can_buy(item) -> bool`, `refusal(item) -> String` (why not, for a footer; empty if buyable), `buy(item) -> bool`.

- [ ] **Step 1: Write the failing tests**

```gdscript
extends GutTest
## Tests for game/systems/shop.gd: the transaction between the pouch, the wallet and the
## inventory. Every refusal is re-checked afterwards for "nothing moved", the same way
## test_economy.gd does for spend().

const ShopScript := preload("res://systems/shop.gd")
const EconomyScript := preload("res://systems/economy.gd")
const GemPouchScript := preload("res://systems/gem_pouch.gd")
const InventoryScript := preload("res://systems/inventory.gd")
const ShopItemScript := preload("res://systems/shop_item.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")

var _econ: Economy
var _pouch: GemPouch
var _inv: Inventory
var _unlocks: Array
var _shop: Shop


func before_each() -> void:
	_econ = EconomyScript.new(0)
	_pouch = GemPouchScript.new()
	_inv = InventoryScript.new()
	_unlocks = []
	_shop = ShopScript.new(_econ, _pouch, _inv, _unlocks)


func _care(id: String, cost: int, food: String, qty: int = 1) -> ShopItem:
	var item: ShopItem = ShopItemScript.new()
	item.id = StringName(id)
	item.display_name = id.capitalize()
	item.cost = cost
	item.kind = ShopItemScript.Kind.CARE
	item.food_id = StringName(food)
	item.quantity = qty
	return item


func _gear(id: String, cost: int) -> ShopItem:
	var item: ShopItem = ShopItemScript.new()
	item.id = StringName(id)
	item.display_name = id.capitalize()
	item.cost = cost
	item.kind = ShopItemScript.Kind.GEAR
	item.gear_id = StringName(id)
	return item


# --- selling ------------------------------------------------------------------------------

func test_selling_gems_pays_the_rarity_price_and_empties_that_tier() -> void:
	_pouch.add(PonyDataScript.Rarity.RARE, 2)
	watch_signals(_shop)
	var earned := _shop.sell(PonyDataScript.Rarity.RARE, 2)
	assert_eq(earned, 2 * EconomyScript.GEM_VALUE_BY_RARITY[PonyDataScript.Rarity.RARE])
	assert_eq(_econ.bits, earned)
	assert_eq(_pouch.count(PonyDataScript.Rarity.RARE), 0)
	assert_signal_emitted_with_parameters(_shop, "sold", [PonyDataScript.Rarity.RARE, 2, earned])


func test_selling_more_than_held_sells_only_what_is_held() -> void:
	_pouch.add(PonyDataScript.Rarity.COMMON, 1)
	var earned := _shop.sell(PonyDataScript.Rarity.COMMON, 10)
	assert_eq(earned, EconomyScript.GEM_VALUE_BY_RARITY[PonyDataScript.Rarity.COMMON])
	assert_eq(_pouch.total(), 0)


func test_selling_from_an_empty_tier_earns_nothing_and_does_not_signal() -> void:
	watch_signals(_shop)
	assert_eq(_shop.sell(PonyDataScript.Rarity.LEGENDARY, 1), 0)
	assert_eq(_econ.bits, 0)
	assert_signal_not_emitted(_shop, "sold")


func test_sell_all_sums_every_tier() -> void:
	_pouch.add(PonyDataScript.Rarity.COMMON, 2)
	_pouch.add(PonyDataScript.Rarity.LEGENDARY, 1)
	var expected: int = 2 * EconomyScript.GEM_VALUE_BY_RARITY[PonyDataScript.Rarity.COMMON] \
		+ EconomyScript.GEM_VALUE_BY_RARITY[PonyDataScript.Rarity.LEGENDARY]
	assert_eq(_shop.sell_all(), expected)
	assert_true(_pouch.is_empty())
	assert_eq(_econ.bits, expected)


func test_gem_price_reads_the_economy_table() -> void:
	for rarity in EconomyScript.GEM_VALUE_BY_RARITY.keys():
		assert_eq(_shop.gem_price(rarity), EconomyScript.GEM_VALUE_BY_RARITY[rarity])


# --- buying care --------------------------------------------------------------------------

func test_buying_care_spends_bits_and_adds_the_food() -> void:
	_econ.sell(PonyDataScript.Rarity.COMMON, 4)  # 20 bits
	var hay := _care("hay", 5, "hay", 2)
	assert_true(_shop.can_buy(hay))
	watch_signals(_shop)
	assert_true(_shop.buy(hay))
	assert_eq(_econ.bits, 15)
	assert_eq(_inv.count(&"hay"), 2)
	assert_signal_emitted(_shop, "bought")


func test_buying_what_you_cannot_afford_is_refused_and_nothing_moves() -> void:
	var hay := _care("hay", 5, "hay")
	assert_false(_shop.can_buy(hay))
	assert_false(_shop.buy(hay))
	assert_eq(_econ.bits, 0)
	assert_eq(_inv.count(&"hay"), 0)
	assert_false(_shop.refusal(hay).is_empty(), "the menu needs a reason to show")


func test_care_can_be_bought_repeatedly() -> void:
	_econ.sell(PonyDataScript.Rarity.RARE, 1)  # 30 bits
	var hay := _care("hay", 5, "hay")
	assert_true(_shop.buy(hay))
	assert_true(_shop.buy(hay))
	assert_eq(_inv.count(&"hay"), 2)
	assert_eq(_econ.bits, 20)


# --- buying gear --------------------------------------------------------------------------

func test_buying_gear_records_the_unlock_once() -> void:
	_econ.sell(PonyDataScript.Rarity.LEGENDARY, 3)  # 300 bits
	var bag := _gear("bigger_saddlebag", 120)
	assert_false(_shop.owns_gear(&"bigger_saddlebag"))
	assert_true(_shop.buy(bag))
	assert_true(_shop.owns_gear(&"bigger_saddlebag"))
	assert_eq(_unlocks, ["bigger_saddlebag"], "the live unlocks array is what changed")
	assert_eq(_econ.bits, 180)


func test_gear_already_owned_cannot_be_bought_again() -> void:
	_unlocks.append("long_beam")
	_econ.sell(PonyDataScript.Rarity.LEGENDARY, 5)
	var beam := _gear("long_beam", 200)
	assert_true(_shop.owns_gear(&"long_beam"))
	assert_false(_shop.can_buy(beam))
	assert_false(_shop.buy(beam))
	assert_eq(_econ.bits, 500, "a refused purchase costs nothing")
	assert_eq(_unlocks.size(), 1)


func test_a_care_item_with_no_food_is_refused_before_any_bits_move() -> void:
	_econ.sell(PonyDataScript.Rarity.RARE, 1)
	var broken := _care("broken", 5, "")
	assert_false(_shop.can_buy(broken))
	assert_false(_shop.buy(broken))
	assert_eq(_econ.bits, 30)


func test_permit_and_build_kinds_are_refused_in_this_slice() -> void:
	_econ.sell(PonyDataScript.Rarity.LEGENDARY, 5)
	var permit: ShopItem = ShopItemScript.new()
	permit.id = &"pass"
	permit.cost = 1
	permit.kind = ShopItemScript.Kind.PERMIT
	permit.permit_zone = &"lake"
	assert_false(_shop.buy(permit))
	var build: ShopItem = ShopItemScript.new()
	build.id = &"pen"
	build.cost = 1
	build.kind = ShopItemScript.Kind.BUILD
	build.plot_id = &"pen_small"
	assert_false(_shop.buy(build))
	assert_eq(_econ.bits, 500)
	assert_eq(_unlocks.size(), 0)


func test_buying_null_is_refused() -> void:
	assert_false(_shop.can_buy(null))
	assert_false(_shop.buy(null))
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_shop.gd -gexit 2>&1 | grep -E "Tests|Passing|Failing|error"`
Expected: preload error.

- [ ] **Step 3: Write the implementation**

```gdscript
class_name Shop
extends RefCounted
## THE MARKET'S TRANSACTION, with no shop building and no menu attached. Sell gems from
## the pouch into the wallet; buy items with the wallet into the inventory or the unlocks.
## game/ui/market_menu.gd draws these and emits; game/world/ranch.gd calls this. One
## place for the money to move, so "charged but not delivered" has nowhere to live.
##
## THE ORDER IS CHECK, THEN SPEND, THEN DELIVER. can_buy() answers every reason a purchase
## could fail before a single bit moves, and buy() re-asks it, so a delivery can only fail
## after a spend for a reason this file did not think of, and Economy.spend() is a no-op
## on refusal so even that leaves the wallet as it was.
##
## `unlocks` is GameState's live Array, mutated in place: appending here is what makes the
## purchase survive quitting. Owning gear is the only thing that stops it being sold twice.

const EconomyScript := preload("res://systems/economy.gd")
const ShopItemScript := preload("res://systems/shop_item.gd")

signal sold(rarity: int, count: int, bits: int)
signal bought(item: ShopItem)

var _economy: Economy
var _pouch: GemPouch
var _inventory: Inventory
var _unlocks: Array


func _init(economy: Economy, pouch: GemPouch, inventory: Inventory, unlocks: Array) -> void:
	_economy = economy
	_pouch = pouch
	_inventory = inventory
	_unlocks = unlocks


# --- selling ------------------------------------------------------------------------------

func gem_count(rarity: int) -> int:
	return _pouch.count(rarity)


func gem_price(rarity: int) -> int:
	return int(EconomyScript.GEM_VALUE_BY_RARITY.get(rarity, 0))


## Sell up to `count` gems of `rarity`. Returns the bits earned.
func sell(rarity: int, count: int) -> int:
	var taken := _pouch.take(rarity, count)
	if taken <= 0:
		return 0
	var earned := _economy.sell(rarity, taken)
	sold.emit(rarity, taken, earned)
	return earned


func sell_all() -> int:
	var earned := 0
	for rarity in EconomyScript.GEM_VALUE_BY_RARITY.keys():
		earned += sell(rarity, _pouch.count(rarity))
	return earned


# --- buying -------------------------------------------------------------------------------

func owns_gear(gear_id: StringName) -> bool:
	return _unlocks.has(String(gear_id))


## Why `item` cannot be bought right now, as a line for the menu footer, or "" if it can.
func refusal(item: ShopItem) -> String:
	if item == null:
		return "Nothing to buy."
	match item.kind:
		ShopItemScript.Kind.CARE:
			if String(item.food_id).is_empty() or item.quantity <= 0:
				return "That is not for sale."
		ShopItemScript.Kind.GEAR:
			if String(item.gear_id).is_empty():
				return "That is not for sale."
			if owns_gear(item.gear_id):
				return "You already have that."
		_:
			return "Not for sale yet."
	if not _economy.can_afford(item.cost):
		return "%s costs %d bits. You have %d." % [item.display_name, item.cost, _economy.bits]
	return ""


func can_buy(item: ShopItem) -> bool:
	return refusal(item).is_empty()


func buy(item: ShopItem) -> bool:
	if not can_buy(item):
		return false
	if not _economy.spend(item.cost):
		return false
	match item.kind:
		ShopItemScript.Kind.CARE:
			_inventory.add(item.food_id, item.quantity)
		ShopItemScript.Kind.GEAR:
			_unlocks.append(String(item.gear_id))
	bought.emit(item)
	return true
```

- [ ] **Step 4: Run the test to verify it passes**

Expected: `Tests 13`, `Passing Tests 13`.

- [ ] **Step 5: Commit**

```bash
git add game/systems/shop.gd game/test/test_shop.gd
git commit -m "feat: Shop, the transaction between pouch, wallet, inventory and unlocks"
```

---

### Task 5: GameState carries gems and inventory; save format version 2

**Files:**
- Modify: `game/systems/game_state.gd` (keys near line 70, fields near line 100, `to_dict` ~line 225, `from_dict` ~line 245, `reset` ~line 275)
- Modify: `game/systems/save_io.gd` (`FORMAT_VERSION` line 95, `migrate()` line 322)
- Test: `game/test/test_game_state.gd`, `game/test/test_save_io.gd`

**Interfaces:**
- Produces: `GameState.gems: GemPouch`, `GameState.inventory: Inventory`, `const KEY_GEMS := "gems"`, `const KEY_INVENTORY := "inventory"`. Both are replaced (new objects) on `from_dict()` and `reset()`; callers must re-read them after `state_loaded`.

- [ ] **Step 1: Write the failing tests**

Append to `game/test/test_game_state.gd`:

```gdscript
const GemPouchScript := preload("res://systems/gem_pouch.gd")
const InventoryScript := preload("res://systems/inventory.gd")


func test_gems_and_inventory_round_trip() -> void:
	var state = _fresh_state()
	state.gems.add(PonyDataScript.Rarity.RARE, 3)
	state.inventory.add(&"hay", 4)
	var d := state.to_dict()
	assert_true(d.has("gems"))
	assert_true(d.has("inventory"))
	var back = _fresh_state()
	back.from_dict(d)
	assert_eq(back.gems.count(PonyDataScript.Rarity.RARE), 3)
	assert_eq(back.inventory.count(&"hay"), 4)


func test_a_save_without_gems_or_inventory_loads_with_empty_ones() -> void:
	var state = _fresh_state()
	state.gems.add(PonyDataScript.Rarity.COMMON, 1)
	state.from_dict({"bits": 7})
	assert_eq(state.bits, 7)
	assert_true(state.gems.is_empty(), "a version 1 save has no gems key")
	assert_eq(state.inventory.ids().size(), 0)


func test_reset_empties_gems_and_inventory() -> void:
	var state = _fresh_state()
	state.gems.add(PonyDataScript.Rarity.COMMON, 2)
	state.inventory.add(&"hay", 1)
	state.reset()
	assert_true(state.gems.is_empty())
	assert_eq(state.inventory.ids().size(), 0)
```

Read the top of `test_game_state.gd` to find how it constructs a state (`_fresh_state()` or equivalent; if the helper has another name, use that name and do not add a second helper). Confirm `PonyDataScript` is already preloaded there; if not, add it.

In `game/test/test_save_io.gd`, change the pinned version:

```gdscript
func test_the_version_policy_is_stated_and_pinned() -> void:
	assert_eq(SaveIOScript.FORMAT_VERSION, 2, "the current format version")
```
(the rest of that test is unchanged) and add:

```gdscript
func test_a_version_1_file_loads_and_gains_empty_gems_and_inventory() -> void:
	var v1 := {"version": 1, "bits": 12, "ponies": [], "plots": {}, "unlocks": [], "world_seed": 5}
	var migrated := SaveIOScript.migrate(v1, 1)
	assert_eq(migrated.get("bits"), 12, "existing fields survive")
	assert_true(migrated.has("gems"), "migration adds the gems key")
	assert_true(migrated.has("inventory"), "migration adds the inventory key")
	assert_eq(migrated["gems"], {})
	assert_eq(migrated["inventory"], {})
```

- [ ] **Step 2: Run both test files to verify the new tests fail**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_game_state.gd -gexit 2>&1 | grep -E "Tests|Passing|Failing"` and the same for `test_save_io.gd`.
Expected: the three new game_state tests fail (`gems` not found); `test_the_version_policy_is_stated_and_pinned` fails (1 != 2); the migrate test fails (no `gems` key).

- [ ] **Step 3: Implement in game_state.gd**

Add after `const KEY_WORLD_SEED := "world_seed"`:
```gdscript
const KEY_GEMS := "gems"
const KEY_INVENTORY := "inventory"
```

Add preloads near the top with the other preloads:
```gdscript
const GemPouchScript := preload("res://systems/gem_pouch.gd")
const InventoryScript := preload("res://systems/inventory.gd")
```

Add fields after `var world_seed := DEFAULT_WORLD_SEED`:
```gdscript
## The gems the player holds, by producing rarity (game/systems/gem_pouch.gd). Pens fold
## their trays into this before every save and when the Market opens (ranch.gd), so this
## is the count that survives quitting and the count the Market sells from.
##
## REPLACED, NOT MUTATED, by from_dict() and reset(): a listener holding the old object is
## holding a pouch nothing will fill again. Re-read after state_loaded.
var gems: GemPouch = GemPouchScript.new()

## Consumables the player holds (game/systems/inventory.gd). Same replacement rule.
var inventory: Inventory = InventoryScript.new()
```

In `to_dict()`, add two entries to the returned dictionary:
```gdscript
		KEY_GEMS: gems.to_dict(),
		KEY_INVENTORY: inventory.to_dict(),
```

In `from_dict()`, before `state_loaded.emit()`:
```gdscript
	var saved_gems: Variant = data.get(KEY_GEMS, {})
	gems = GemPouchScript.from_dict(saved_gems if typeof(saved_gems) == TYPE_DICTIONARY else {})
	var saved_inventory: Variant = data.get(KEY_INVENTORY, {})
	inventory = InventoryScript.from_dict(
		saved_inventory if typeof(saved_inventory) == TYPE_DICTIONARY else {})
```

In `reset()`:
```gdscript
	gems = GemPouchScript.new()
	inventory = InventoryScript.new()
```

- [ ] **Step 4: Implement in save_io.gd**

Change `const FORMAT_VERSION := 1` to `const FORMAT_VERSION := 2` and update the comment block above it (the version policy) with one line: `Version 2 (Phase 2 slice 1) adds "gems" and "inventory"; both default to {}.`

Replace `migrate()`:
```gdscript
static func migrate(data: Dictionary, from_version: int) -> Dictionary:
	var out := data.duplicate(true)
	if from_version < 2:
		# Version 2 added the gem pouch and the inventory. An older file has neither, and
		# an empty one of each is exactly what a version 1 ranch had.
		if not out.has("gems"):
			out["gems"] = {}
		if not out.has("inventory"):
			out["inventory"] = {}
	return out
```

- [ ] **Step 5: Run the whole suite**

Run: `bash tools/run_tests.sh 2>&1 | grep -E "^Tests|^Passing|^Failing|All tests passed|FAILED"`
Expected: all passing, count is previous plus 4.

- [ ] **Step 6: Commit**

```bash
git add game/systems/game_state.gd game/systems/save_io.gd game/test/test_game_state.gd game/test/test_save_io.gd
git commit -m "feat: gems and inventory survive quitting; save format version 2"
```

---

### Task 6: Pens count gems by rarity and feed residents from the inventory

**Files:**
- Modify: `game/world/pen.gd` (signals ~line 226, `_gems` line 250, `tick()` ~line 381, `gems()`/`take_gems()` ~line 425)
- Test: `game/test/test_pen.gd`

**Interfaces:**
- Consumes: `Needs.tick(inst, delta)`, `Needs.feed(inst, food_id) -> bool`, `Needs.HUNGRY_THRESHOLD`, `Needs.is_favorite(inst, food_id)`, `Production.tick(inst, delta) -> int`, `PonyInstance.data().rarity`, `Inventory`.
- Produces: `Pen.gems_by_rarity() -> Dictionary` (int rarity to int count), `Pen.take_gems_by_rarity() -> Dictionary` (empties the tray), `Pen.inventory_provider: Callable` (`func() -> Inventory`, may be invalid), `signal fed(uid: StringName, food_id: StringName)`. `gems()` and `take_gems()` keep returning totals so existing callers and tests are untouched.

- [ ] **Step 1: Write the failing tests**

Append to `game/test/test_pen.gd` (read its helpers first: `_pen(capacity)` and `_instance(id)` exist; `ProductionScript` and `NeedsScript` may already be preloaded, add them if not; add `InventoryScript := preload("res://systems/inventory.gd")`):

```gdscript
func test_the_tray_counts_gems_by_the_producing_pony_s_rarity() -> void:
	var pen := _pen(2)
	var her := _instance("twilight")  # RARE in game/data/ponies/twilight.tres
	her.happiness = 1.0
	her.hunger = 0.0
	pen.add_pony(her)
	pen.tick(ProductionScript.PRODUCTION_PERIOD_SECONDS)
	var by_rarity := pen.gems_by_rarity()
	assert_eq(by_rarity.get(her.data().rarity, 0), 1)
	assert_eq(pen.gems(), 1, "the total still adds up")


func test_take_gems_by_rarity_hands_over_the_tray_and_empties_it() -> void:
	var pen := _pen(2)
	var her := _instance("twilight")
	her.happiness = 1.0
	her.hunger = 0.0
	pen.add_pony(her)
	pen.tick(ProductionScript.PRODUCTION_PERIOD_SECONDS * 2.0)
	var taken := pen.take_gems_by_rarity()
	assert_eq(taken.get(her.data().rarity, 0), 2)
	assert_eq(pen.gems(), 0)
	assert_eq(pen.gems_by_rarity().size(), 0)


func test_a_hungry_resident_eats_from_the_inventory() -> void:
	var pen := _pen(2)
	var inv = InventoryScript.new()
	inv.add(&"hay", 1)
	pen.inventory_provider = func() -> Inventory: return inv
	var her := _instance("twilight")
	her.hunger = NeedsScript.HUNGRY_THRESHOLD + 0.1
	pen.add_pony(her)
	watch_signals(pen)
	pen.tick(0.1)
	assert_eq(inv.count(&"hay"), 0, "the hay was eaten")
	assert_lt(her.hunger, NeedsScript.HUNGRY_THRESHOLD, "and she is no longer hungry")
	assert_signal_emitted_with_parameters(pen, "fed", [her.uid, &"hay"])


func test_a_resident_prefers_her_favourite_when_both_are_stocked() -> void:
	var pen := _pen(2)
	var inv = InventoryScript.new()
	inv.add(&"hay", 1)
	inv.add(&"daffodil", 1)  # a Twilight favourite, see twilight.tres
	pen.inventory_provider = func() -> Inventory: return inv
	var her := _instance("twilight")
	her.hunger = NeedsScript.HUNGRY_THRESHOLD + 0.1
	pen.add_pony(her)
	pen.tick(0.1)
	assert_eq(inv.count(&"daffodil"), 0, "she took the daffodil")
	assert_eq(inv.count(&"hay"), 1, "and left the hay")


func test_a_pen_with_no_inventory_does_not_feed_and_does_not_crash() -> void:
	var pen := _pen(2)
	var her := _instance("twilight")
	her.hunger = NeedsScript.HUNGRY_THRESHOLD + 0.1
	pen.add_pony(her)
	pen.tick(0.1)
	assert_gte(her.hunger, NeedsScript.HUNGRY_THRESHOLD, "nothing to eat, still hungry")


func test_a_full_resident_does_not_eat() -> void:
	var pen := _pen(2)
	var inv = InventoryScript.new()
	inv.add(&"hay", 1)
	pen.inventory_provider = func() -> Inventory: return inv
	var her := _instance("twilight")
	her.hunger = 0.0
	pen.add_pony(her)
	pen.tick(0.1)
	assert_eq(inv.count(&"hay"), 1, "food is not wasted on a pony who is not hungry")
```

Check `game/data/ponies/twilight.tres`: `favorite_foods` includes `daffodil` and `rarity = 2` (RARE). If either differs, adjust the test's expectations to the data, not the data to the test.

- [ ] **Step 2: Run the test file to verify the new tests fail**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_pen.gd -gexit 2>&1 | grep -E "Tests|Passing|Failing"`
Expected: six new failures (`gems_by_rarity` not found, and so on), everything else still passing.

- [ ] **Step 3: Implement in pen.gd**

Add a signal next to `gems_produced`:
```gdscript
## A resident ate. Carries who and what, for a toast or a test.
signal fed(uid: StringName, food_id: StringName)
```

Replace `var _gems := 0` with:
```gdscript
## The tray: gems by the rarity of the pony who made them (int rarity to int count). A
## transient staging area; game/world/ranch.gd folds it into GameState.gems before a save
## and when the Market opens, because Economy prices a gem by rarity and a plain total
## would throw that information away at the moment it was made.
var _gems_by_rarity: Dictionary = {}

## `func() -> Inventory`, the shared pantry the residents eat from. Injected by ranch.gd.
## Left invalid, nobody eats, which is what a test pen with no ranch wants.
var inventory_provider := Callable()
```

Replace the body of `tick()`:
```gdscript
func tick(delta: float) -> int:
	if delta <= 0.0 or _residents.is_empty():
		return 0
	var produced := 0
	for inst in _residents:
		NeedsScript.tick(inst, delta)
		_feed_if_hungry(inst)
		var made := ProductionScript.tick(inst, delta)
		if made > 0:
			var data: PonyData = inst.data()
			var rarity: int = data.rarity if data != null else PonyDataScript.Rarity.COMMON
			_gems_by_rarity[rarity] = int(_gems_by_rarity.get(rarity, 0)) + made
			produced += made
	if produced > 0:
		gems_produced.emit(gems())
	return produced


## Feed `inst` one item from the pantry if she is hungry and something is stocked. Her
## favourite first, then whatever is there. Hunger is checked AFTER Needs.tick() above so
## a pony who crossed the threshold this tick eats this tick.
func _feed_if_hungry(inst: PonyInstance) -> void:
	if inst.hunger < NeedsScript.HUNGRY_THRESHOLD:
		return
	if not inventory_provider.is_valid():
		return
	var pantry: Inventory = inventory_provider.call()
	if pantry == null:
		return
	var choice: StringName = &""
	for food_id in pantry.ids():
		if NeedsScript.is_favorite(inst, food_id):
			choice = food_id
			break
	if String(choice).is_empty():
		var stocked := pantry.ids()
		if stocked.is_empty():
			return
		choice = stocked[0]
	# Take first, feed second: a feed that fails (an id Needs cannot resolve) puts the
	# item back rather than leaving it consumed for nothing.
	if not pantry.remove(choice, 1):
		return
	if not NeedsScript.feed(inst, choice):
		pantry.add(choice, 1)
		return
	fed.emit(inst.uid, choice)
```

Add `const PonyDataScript := preload("res://systems/pony_data.gd")` to the preload block if it is not already there.

Replace `gems()` and `take_gems()`:
```gdscript
## Gems sitting in the tray, uncollected, all rarities together.
func gems() -> int:
	var sum := 0
	for value in _gems_by_rarity.values():
		sum += int(value)
	return sum


## The tray by rarity. A copy.
func gems_by_rarity() -> Dictionary:
	return _gems_by_rarity.duplicate()


## Empty the tray and hand its contents over, by rarity.
func take_gems_by_rarity() -> Dictionary:
	var got := _gems_by_rarity
	_gems_by_rarity = {}
	return got


## Empty the tray and hand over the total. Kept for callers that only count.
func take_gems() -> int:
	var total := gems()
	_gems_by_rarity = {}
	return total
```

- [ ] **Step 4: Run test_pen.gd, then the full suite**

Expected: all of `test_pen.gd` passing including the six new tests; full suite green.

- [ ] **Step 5: Commit**

```bash
git add game/world/pen.gd game/test/test_pen.gd
git commit -m "feat: pens count gems by rarity and feed hungry residents from the inventory"
```

---

### Task 7: Gear effects on the magic beam (saddlebag capacity, reach)

**Files:**
- Modify: `game/actors/player/magic_beam.gd` (`REACH` line 159, `storage_capacity` line 454, `_storage = StorageScript.new(storage_capacity)` line 641, and wherever `REACH` is read for the ray)
- Modify: `game/systems/storage.gd` (line 48 `capacity`)
- Test: `game/test/test_storage.gd`, `game/test/test_magic_beam.gd`

**Interfaces:**
- Produces: `Storage.set_capacity(new_capacity: int) -> void` (never below current count), `MagicBeam.apply_unlocks(unlocks: Array) -> void`, `MagicBeam.reach() -> float`, constants `const BIGGER_SADDLEBAG_CAPACITY := 18`, `const LONG_BEAM_BONUS := 1.0`, `const GEAR_BIGGER_SADDLEBAG := &"bigger_saddlebag"`, `const GEAR_LONG_BEAM := &"long_beam"`.

- [ ] **Step 1: Write the failing tests**

Append to `game/test/test_storage.gd`:
```gdscript
func test_capacity_can_grow_but_never_below_what_is_held() -> void:
	var bag = StorageScript.new(2)
	bag.store(_instance("twilight"))
	bag.store(_instance("twilight"))
	bag.set_capacity(5)
	assert_eq(bag.capacity, 5)
	assert_false(bag.is_full())
	bag.set_capacity(1)
	assert_eq(bag.capacity, 2, "shrinking below the contents is clamped to the contents")
	assert_true(bag.is_full())
```
(Read `test_storage.gd` for its instance helper name; use it.)

Append to `game/test/test_magic_beam.gd` (read its setup: it instantiates the player or the beam; reuse the same fixture):
```gdscript
func test_unlocks_grow_the_saddlebag_and_the_reach() -> void:
	var beam := _beam()
	var base_reach := beam.reach()
	var base_capacity: int = beam.get_storage().capacity
	beam.apply_unlocks(["bigger_saddlebag", "long_beam"])
	assert_eq(beam.get_storage().capacity, MagicBeamScript.BIGGER_SADDLEBAG_CAPACITY)
	assert_gt(beam.get_storage().capacity, base_capacity)
	assert_almost_eq(beam.reach(), base_reach + MagicBeamScript.LONG_BEAM_BONUS, 0.0001)


func test_unlocks_are_idempotent_and_unknown_ids_are_ignored() -> void:
	var beam := _beam()
	beam.apply_unlocks(["long_beam"])
	var once := beam.reach()
	beam.apply_unlocks(["long_beam", "long_beam", "hat_of_wonders"])
	assert_almost_eq(beam.reach(), once, 0.0001, "applying twice does not stack")


func test_reach_stays_under_the_notice_invariant_even_with_the_long_beam() -> void:
	# magic_beam.gd's own invariant: every personality notices a running player from
	# further than the beam reaches, by MIN_DETECTION_MARGIN. The long beam must not eat
	# through that margin or a pony can be taken without a chase.
	var beam := _beam()
	beam.apply_unlocks(["long_beam"])
	for personality in PonyDataScript.Personality.values():
		var notice: float = PonyScript.notice_radius_for(personality, false)
		assert_gte(notice - beam.reach(), MagicBeamScript.MIN_DETECTION_MARGIN,
			"personality %d notices from %.1f, long beam reaches %.1f" % [personality, notice, beam.reach()])
```
Add preloads `PonyScript := preload("res://actors/pony/pony.gd")` and `PonyDataScript` if the file lacks them. Find `MIN_DETECTION_MARGIN` in magic_beam.gd (the capture-feel work added it; grep for it) and use its real name.

- [ ] **Step 2: Run both test files to verify the new tests fail**

Expected: `set_capacity` not found; `reach`/`apply_unlocks` not found.

- [ ] **Step 3: Implement Storage.set_capacity**

In `game/systems/storage.gd`, after `_init`:
```gdscript
## Grow (or shrink) the bag. Never below what it already holds: a capacity that dropped
## under the contents would make the next store() refuse while count() > capacity, a
## state no store ever produced. The saddlebag gear calls this.
func set_capacity(new_capacity: int) -> void:
	capacity = maxi(_items.size(), maxi(0, new_capacity))
```

- [ ] **Step 4: Implement the beam side**

In `magic_beam.gd`, next to `const REACH := 8.5`:
```gdscript
## Gear. The shop's unlock ids this beam knows how to apply (game/systems/shop_item.gd's
## GEAR kind, game/data/shop/*.tres). apply_unlocks() reads GameState.unlocks on boot and
## after every purchase; an id it does not know is ignored, so an unlock aimed at some
## other system does not have to be filtered out before it gets here.
const GEAR_BIGGER_SADDLEBAG := &"bigger_saddlebag"
const GEAR_LONG_BEAM := &"long_beam"
const BIGGER_SADDLEBAG_CAPACITY := 18
## Metres added to REACH by the long beam. Sized against MIN_DETECTION_MARGIN (3.0 m): the
## invariant that every pony notices a running player from further than the beam reaches
## has to survive this, and 1.0 m leaves 2.0 m of it. test_magic_beam.gd checks that
## arithmetic against the real notice radii rather than trusting this comment.
const LONG_BEAM_BONUS := 1.0

var _reach_bonus := 0.0
```

Add methods near `get_storage()`:
```gdscript
## How far the beam reaches right now, gear included. Every ray and hold-point
## calculation reads this rather than REACH so an upgrade applies everywhere at once.
func reach() -> float:
	return REACH + _reach_bonus


## Apply every gear unlock in `unlocks` this beam understands. Idempotent.
func apply_unlocks(unlocks: Array) -> void:
	if unlocks.has(String(GEAR_BIGGER_SADDLEBAG)):
		_storage.set_capacity(BIGGER_SADDLEBAG_CAPACITY)
	_reach_bonus = LONG_BEAM_BONUS if unlocks.has(String(GEAR_LONG_BEAM)) else 0.0
```

Then replace every read of `REACH` in the beam's runtime code (the ray length, the hold point projection, any HUD-facing distance) with `reach()`. Grep: `grep -n "REACH" game/actors/player/magic_beam.gd`. Leave the constant's definition and the comments. The unit test on the notice invariant (`test_the_two_gameplay_speeds...` or the detection-margin test the capture-feel work added) may compare against `REACH` directly; that is the base case and stays.

- [ ] **Step 5: Run the two test files and then `scenes/test/capture_test.tscn`**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/capture_test.tscn 2>&1 | grep -E "CAPTURE_(OK|FAILED)"; echo "exit=$?"`
Expected: tests pass; `CAPTURE_OK checks=175`, exit 0 (the gate uses the base reach; nothing about it should change).

- [ ] **Step 6: Commit**

```bash
git add game/systems/storage.gd game/actors/player/magic_beam.gd game/test/test_storage.gd game/test/test_magic_beam.gd
git commit -m "feat: gear unlocks grow the saddlebag and the beam's reach"
```

---

### Task 8: Settings (volume, sensitivity, invert), persisted outside the save

**Files:**
- Create: `game/systems/settings.gd`
- Modify: `game/actors/player/camera_rig.gd` (`add_look_delta` line 470; remove the Escape branch in `_unhandled_input` lines 431 to 436)
- Test: `game/test/test_settings.gd`, `game/test/test_camera_rig.gd`

**Interfaces:**
- Produces: `class_name Settings extends RefCounted`, `const PATH := "user://settings.cfg"`, fields `master_volume: float` (0..1, default 1.0), `mouse_sensitivity: float` (default `0.0035`, range 0.001..0.01), `invert_look: bool` (default false); `signal changed()`; `load_from(path := PATH) -> void`, `save_to(path := PATH) -> bool`, `apply_audio() -> void` (sets Master bus volume in dB, mute at 0), `step_volume(dir: int)`, `step_sensitivity(dir: int)`, `toggle_invert()`. `CameraRig.invert_look: bool` export.

- [ ] **Step 1: Write the failing tests**

`game/test/test_settings.gd`:
```gdscript
extends GutTest
## Tests for game/systems/settings.gd. Settings live in user://settings.cfg, NOT in the
## save: they are about the machine and the person, not the ranch, and a traded save
## must not carry someone else's mouse sensitivity.

const SettingsScript := preload("res://systems/settings.gd")
const SCRATCH := "user://test_scratch/settings_test.cfg"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://test_scratch"))
	if FileAccess.file_exists(SCRATCH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))


func test_defaults() -> void:
	var s = SettingsScript.new()
	assert_almost_eq(s.master_volume, 1.0, 0.0001)
	assert_almost_eq(s.mouse_sensitivity, 0.0035, 0.00001)
	assert_false(s.invert_look)


func test_round_trips_through_a_file() -> void:
	var s = SettingsScript.new()
	s.master_volume = 0.4
	s.mouse_sensitivity = 0.006
	s.invert_look = true
	assert_true(s.save_to(SCRATCH))
	var back = SettingsScript.new()
	back.load_from(SCRATCH)
	assert_almost_eq(back.master_volume, 0.4, 0.0001)
	assert_almost_eq(back.mouse_sensitivity, 0.006, 0.00001)
	assert_true(back.invert_look)


func test_loading_a_missing_file_keeps_defaults() -> void:
	var s = SettingsScript.new()
	s.load_from("user://test_scratch/does_not_exist.cfg")
	assert_almost_eq(s.master_volume, 1.0, 0.0001)


func test_steps_are_clamped_and_signal() -> void:
	var s = SettingsScript.new()
	watch_signals(s)
	for i in range(20):
		s.step_volume(1)
	assert_almost_eq(s.master_volume, 1.0, 0.0001, "volume tops out at 1.0")
	for i in range(20):
		s.step_volume(-1)
	assert_almost_eq(s.master_volume, 0.0, 0.0001, "and bottoms out at 0.0")
	for i in range(50):
		s.step_sensitivity(1)
	assert_lte(s.mouse_sensitivity, SettingsScript.SENSITIVITY_MAX)
	for i in range(50):
		s.step_sensitivity(-1)
	assert_gte(s.mouse_sensitivity, SettingsScript.SENSITIVITY_MIN)
	s.toggle_invert()
	assert_true(s.invert_look)
	assert_signal_emitted(s, "changed")


func test_apply_audio_sets_the_master_bus() -> void:
	var s = SettingsScript.new()
	var master := AudioServer.get_bus_index("Master")
	var was_muted := AudioServer.is_bus_mute(master)
	var was_db := AudioServer.get_bus_volume_db(master)
	s.master_volume = 0.5
	s.apply_audio()
	assert_almost_eq(AudioServer.get_bus_volume_db(master), linear_to_db(0.5), 0.01)
	s.master_volume = 0.0
	s.apply_audio()
	assert_true(AudioServer.is_bus_mute(master), "zero volume mutes rather than sending -inf dB")
	# Put the bus back so this test does not change the rest of the run.
	AudioServer.set_bus_mute(master, was_muted)
	AudioServer.set_bus_volume_db(master, was_db)
```

Append to `game/test/test_camera_rig.gd` (read its fixture for how it gets a rig; call it `_rig()` below if that is its name):
```gdscript
func test_invert_look_flips_pitch_and_leaves_yaw_alone() -> void:
	var rig := _rig()
	var pitch_before := rig.get_look_pitch_degrees()
	rig.add_look_delta(0.0, 0.1)
	var normal_pitch := rig.get_look_pitch_degrees()
	assert_lt(normal_pitch, pitch_before, "positive delta looks down when not inverted")
	rig.invert_look = true
	rig.add_look_delta(0.0, 0.1)
	assert_gt(rig.get_look_pitch_degrees(), normal_pitch, "and up when inverted")
```

- [ ] **Step 2: Run to verify failure**

Expected: preload error for settings; `invert_look` not found on the rig.

- [ ] **Step 3: Write settings.gd**

```gdscript
class_name Settings
extends RefCounted
## WHAT THE PAUSE MENU'S SETTINGS PAGE EDITS: master volume, mouse sensitivity, invert
## look. Persisted in user://settings.cfg, deliberately NOT in the save file: a save is a
## ranch two players trade by pasting; a setting is about one person's hand and one
## machine's speakers.
##
## RefCounted and file-backed, testable without a scene (game/test/test_settings.gd).
## apply_audio() is the only method that touches the engine.

const PATH := "user://settings.cfg"
const SECTION := "settings"

const VOLUME_STEP := 0.1
const SENSITIVITY_MIN := 0.001
const SENSITIVITY_MAX := 0.010
const SENSITIVITY_STEP := 0.0005
const SENSITIVITY_DEFAULT := 0.0035  # camera_rig.gd's exported default

signal changed()

var master_volume := 1.0
var mouse_sensitivity := SENSITIVITY_DEFAULT
var invert_look := false


func load_from(path: String = PATH) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	master_volume = clampf(float(cfg.get_value(SECTION, "master_volume", master_volume)), 0.0, 1.0)
	mouse_sensitivity = clampf(float(cfg.get_value(SECTION, "mouse_sensitivity", mouse_sensitivity)),
		SENSITIVITY_MIN, SENSITIVITY_MAX)
	invert_look = bool(cfg.get_value(SECTION, "invert_look", invert_look))
	changed.emit()


func save_to(path: String = PATH) -> bool:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "master_volume", master_volume)
	cfg.set_value(SECTION, "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value(SECTION, "invert_look", invert_look)
	return cfg.save(path) == OK


func step_volume(direction: int) -> void:
	var next := clampf(master_volume + VOLUME_STEP * signf(direction), 0.0, 1.0)
	if is_equal_approx(next, master_volume):
		return
	master_volume = next
	changed.emit()


func step_sensitivity(direction: int) -> void:
	var next := clampf(mouse_sensitivity + SENSITIVITY_STEP * signf(direction),
		SENSITIVITY_MIN, SENSITIVITY_MAX)
	if is_equal_approx(next, mouse_sensitivity):
		return
	mouse_sensitivity = next
	changed.emit()


func toggle_invert() -> void:
	invert_look = not invert_look
	changed.emit()


## Push the volume to the Master bus. Zero mutes rather than setting -inf dB, because
## -inf is a value the bus accepts and then behaves strangely with.
##
## AudioSafety (game/systems/audio_safety.gd) mutes Master for automated runs; this only
## unmutes when the volume is above zero AND the run is interactive, which is what keeps
## a gate that opened the pause menu from unmuting itself.
func apply_audio() -> void:
	var master := AudioServer.get_bus_index("Master")
	if master < 0:
		return
	if master_volume <= 0.0:
		AudioServer.set_bus_mute(master, true)
		return
	AudioServer.set_bus_volume_db(master, linear_to_db(master_volume))
	if DisplayServer.get_name() != "headless":
		AudioServer.set_bus_mute(master, false)
```

Read `game/systems/audio_safety.gd` in full before finishing this step; if it mutes on a condition other than headless (a command-line flag, a screenshot dir), mirror that same condition in `apply_audio()` so the two agree, and say so in the comment.

- [ ] **Step 4: Camera rig**

In `camera_rig.gd`, in the `@export_group("Look")` block, add:
```gdscript
## Flip vertical look. The pause menu's settings page toggles this.
@export var invert_look := false
```

Change `add_look_delta`:
```gdscript
func add_look_delta(delta_yaw: float, delta_pitch: float) -> void:
	rotation.y -= delta_yaw
	var pitch := -delta_pitch if invert_look else delta_pitch
	_look_pitch = clampf(_look_pitch - rad_to_deg(pitch), PITCH_MIN_DEG, PITCH_MAX_DEG)
	_spring_arm.rotation.x = deg_to_rad(_look_pitch)
```

Delete the `elif event is InputEventKey ... KEY_ESCAPE` branch from `_unhandled_input` (the whole `elif` including its comment). Escape now belongs to the pause menu (Task 10). Leave the mouse-motion branch.

- [ ] **Step 5: Run both test files**

Expected: `test_settings.gd` 5 passing; `test_camera_rig.gd` all passing including the new one.

- [ ] **Step 6: Commit**

```bash
git add game/systems/settings.gd game/actors/player/camera_rig.gd game/test/test_settings.gd game/test/test_camera_rig.gd
git commit -m "feat: Settings (volume, sensitivity, invert look), and Escape no longer toggles the cursor"
```

---

### Task 9: The Market menu (Sell and Buy tabs)

**Files:**
- Create: `game/ui/market_menu.gd`, `game/ui/market_menu.tscn`
- Modify: `game/project.godot` only if Step 1's probe shows `ui_left`/`ui_right` without a pad button
- Test: `game/test/test_market_menu.gd`, `game/test/test_build_menu.gd` (extend the binding test)

**Interfaces:**
- Consumes: `Shop` (`gem_count`, `gem_price`, `can_buy`, `refusal`, `owns_gear`), `ShopRegistry.all()`, `PonyData.Rarity`.
- Produces: `class_name MarketMenu extends CanvasLayer`, `enum Tab { SELL, BUY }`, `var shop: Shop` (set by ranch before `open()`), `open() -> bool` (false with no shop), `close()`, `is_open()`, `tab() -> int`, `set_tab(tab: int)`, `move_selection(step: int)`, `selected_index() -> int`, `sell_rows() -> Array[int]` (rarities, in enum order), `buy_rows() -> Array[ShopItem]`, `confirm() -> bool`, `sell_everything() -> bool`, signals `opened()`, `closed()`, `sell_requested(rarity: int, count: int)`, `sell_all_requested()`, `buy_requested(item: ShopItem)`, `refresh()`.
- Bindings: `ui_up`/`ui_down` rows, `ui_left`/`ui_right` tabs, `ui_accept` confirm (sell one tier, or buy the row), `ui_cancel` close. A dedicated "sell all" is the first row of the Sell tab.

- [ ] **Step 1: Probe ui_left/ui_right bindings**

Run:
```bash
cat > /tmp/probe_lr.gd <<'EOF'
extends SceneTree
func _init():
	for a in ["ui_left", "ui_right"]:
		var out := []
		for e in InputMap.action_get_events(a):
			if e is InputEventKey: out.append("key:%s" % OS.get_keycode_string(e.physical_keycode if e.physical_keycode != 0 else e.keycode))
			elif e is InputEventJoypadButton: out.append("pad_btn:%d" % e.button_index)
			elif e is InputEventJoypadMotion: out.append("pad_axis:%d" % e.axis)
		print("%-10s %s" % [a, ", ".join(out)])
	quit()
EOF
tools/bin/godot --headless --audio-driver Dummy --path game --script /tmp/probe_lr.gd 2>&1 | grep "^ui_"
```
Expected: each lists a key AND a `pad_btn`/`pad_axis`. If either lacks a pad event, add an explicit override in `project.godot` next to the `ui_accept`/`ui_cancel` ones (Task "fix-controls" added those; copy their shape), preserving the keyboard default and adding `button_index` 13 (left) / 14 (right).

- [ ] **Step 2: Write the failing tests**

`game/test/test_market_menu.gd`:
```gdscript
extends GutTest
## Tests for game/ui/market_menu.gd. Driven through the methods ui_* route into, never
## a mouse, for the reason test_build_menu.gd gives. And the menu never moves a bit: it
## emits, ranch.gd calls Shop.

const MarketMenuScene := preload("res://ui/market_menu.tscn")
const ShopScript := preload("res://systems/shop.gd")
const EconomyScript := preload("res://systems/economy.gd")
const GemPouchScript := preload("res://systems/gem_pouch.gd")
const InventoryScript := preload("res://systems/inventory.gd")
const ShopRegistryScript := preload("res://systems/shop_registry.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")

var _menu: MarketMenu
var _econ: Economy
var _pouch: GemPouch
var _shop: Shop


func before_each() -> void:
	_econ = EconomyScript.new(0)
	_pouch = GemPouchScript.new()
	_shop = ShopScript.new(_econ, _pouch, InventoryScript.new(), [])
	_menu = MarketMenuScene.instantiate()
	add_child_autofree(_menu)
	_menu.shop = _shop


func test_it_will_not_open_without_a_shop() -> void:
	_menu.shop = null
	assert_false(_menu.open())
	assert_false(_menu.is_open())


func test_open_and_close_signal_and_start_on_the_sell_tab() -> void:
	watch_signals(_menu)
	assert_true(_menu.open())
	assert_true(_menu.is_open())
	assert_eq(_menu.tab(), MarketMenu.Tab.SELL)
	assert_signal_emitted(_menu, "opened")
	_menu.close()
	assert_false(_menu.is_open())
	assert_signal_emitted(_menu, "closed")


func test_the_sell_tab_lists_every_rarity_in_order_after_a_sell_all_row() -> void:
	_menu.open()
	assert_eq(_menu.sell_rows(), PonyDataScript.Rarity.values())
	assert_eq(_menu.selected_index(), 0, "row 0 is Sell everything")


func test_confirm_on_the_sell_all_row_asks_to_sell_everything() -> void:
	_pouch.add(PonyDataScript.Rarity.COMMON, 2)
	_menu.open()
	watch_signals(_menu)
	assert_true(_menu.confirm())
	assert_signal_emitted(_menu, "sell_all_requested")
	assert_eq(_econ.bits, 0, "the menu did not sell anything itself")


func test_confirm_on_a_rarity_row_asks_to_sell_that_tier() -> void:
	_pouch.add(PonyDataScript.Rarity.RARE, 3)
	_menu.open()
	# rows: 0 sell all, 1 common, 2 uncommon, 3 rare, 4 legendary
	_menu.move_selection(3)
	watch_signals(_menu)
	assert_true(_menu.confirm())
	assert_signal_emitted_with_parameters(_menu, "sell_requested", [PonyDataScript.Rarity.RARE, 3])


func test_confirm_on_an_empty_tier_is_refused_and_does_not_signal() -> void:
	_menu.open()
	_menu.move_selection(1)
	watch_signals(_menu)
	assert_false(_menu.confirm())
	assert_signal_not_emitted(_menu, "sell_requested")


func test_left_and_right_switch_tabs_and_reset_the_cursor() -> void:
	_menu.open()
	_menu.move_selection(2)
	_menu.set_tab(MarketMenu.Tab.BUY)
	assert_eq(_menu.tab(), MarketMenu.Tab.BUY)
	assert_eq(_menu.selected_index(), 0)


func test_the_buy_tab_lists_the_catalogue_cheapest_first() -> void:
	var reg: ShopRegistry = ShopRegistryScript.new()
	reg.load_all(ShopRegistryScript.SHOP_DIR)
	_menu.open()
	_menu.set_tab(MarketMenu.Tab.BUY)
	var rows := _menu.buy_rows()
	assert_eq(rows.size(), reg.all().size())
	for i in range(rows.size()):
		assert_eq(rows[i].id, reg.all()[i].id)


func test_confirm_on_an_affordable_item_asks_to_buy_it() -> void:
	_econ.sell(PonyDataScript.Rarity.LEGENDARY, 1)  # 100 bits
	_menu.open()
	_menu.set_tab(MarketMenu.Tab.BUY)
	var cheapest := _menu.buy_rows()[0]
	watch_signals(_menu)
	assert_true(_menu.confirm())
	assert_signal_emitted_with_parameters(_menu, "buy_requested", [cheapest])
	assert_eq(_econ.bits, 100, "the menu did not spend")


func test_confirm_on_an_unaffordable_item_is_refused_with_a_reason() -> void:
	_menu.open()
	_menu.set_tab(MarketMenu.Tab.BUY)
	watch_signals(_menu)
	assert_false(_menu.confirm())
	assert_signal_not_emitted(_menu, "buy_requested")
	assert_string_contains(_menu.footer_text(), "bits")


func test_selection_wraps() -> void:
	_menu.open()
	_menu.move_selection(-1)
	assert_eq(_menu.selected_index(), _menu.sell_rows().size(), "wrapped to the last row")
```

Extend `game/test/test_build_menu.gd`'s `test_menu_navigation_actions_have_a_keyboard_and_a_gamepad_binding` to include `"ui_left"` and `"ui_right"` in its action list.

- [ ] **Step 3: Run to verify failure**

Expected: preload error on the scene.

- [ ] **Step 4: Write market_menu.tscn**

Copy `game/ui/build_menu.tscn` to `game/ui/market_menu.tscn` and edit: root node name `MarketMenu`, script path `res://ui/market_menu.gd`, and insert a `Tabs` HBoxContainer between `Wallet` and `Rows`:

```
[node name="Tabs" type="HBoxContainer" parent="Centre/Panel/Margin/Column"]
layout_mode = 2
theme_override_constants/separation = 24
mouse_filter = 2

[node name="SellTab" type="Label" parent="Centre/Panel/Margin/Column/Tabs"]
layout_mode = 2
mouse_filter = 2

[node name="BuyTab" type="Label" parent="Centre/Panel/Margin/Column/Tabs"]
layout_mode = 2
mouse_filter = 2
```

Also add a `Gems` Label right after `Wallet` (same shape as Wallet) so the Sell tab can show the pouch total.

- [ ] **Step 5: Write market_menu.gd**

```gdscript
class_name MarketMenu
extends CanvasLayer
## THE MARKET. Two tabs: SELL turns the gems in your pouch into bits, BUY turns bits into
## food for the pens or gear for the hunt. Phase 2 slice 1.
##
## Built on the same rules as game/ui/build_menu.gd, and its class comment is the
## reference for all of them: navigable without a mouse on the engine's ui_* actions;
## this node runs PROCESS_MODE_ALWAYS while game/world/ranch.gd pauses the tree and frees
## the cursor; and it never touches the wallet. It reads from a Shop to draw and emits
## `sell_requested` / `sell_all_requested` / `buy_requested`; ranch.gd calls Shop.
##
## Left and right change tab, up and down change row, accept confirms, cancel closes. The
## first row of SELL is "Sell everything", because that is what most visits are for.

const ShopRegistryScript := preload("res://systems/shop_registry.gd")
const ShopItemScript := preload("res://systems/shop_item.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")

enum Tab { SELL, BUY }

const COLOR_TITLE := Color(1.0, 0.96, 0.86, 1.0)
const COLOR_NAME := Color(1.0, 1.0, 1.0, 0.94)
const COLOR_DIM := Color(1.0, 1.0, 1.0, 0.58)
const COLOR_COST := Color(1.00, 0.80, 0.25, 1.0)
const COLOR_UNAFFORDABLE := Color(1.0, 0.45, 0.42, 0.85)
const COLOR_TAB_ON := Color(1.0, 0.86, 0.55, 1.0)
const COLOR_TAB_OFF := Color(1.0, 1.0, 1.0, 0.40)
const ROW_SELECTED_BG := Color(1.0, 0.86, 0.55, 0.16)
const ROW_SELECTED_BORDER := Color(1.0, 0.86, 0.55, 0.75)
const ROW_IDLE_BG := Color(1.0, 1.0, 1.0, 0.04)
const ROW_IDLE_BORDER := Color(1.0, 1.0, 1.0, 0.10)

## Rarity names for the Sell tab, in enum order.
const RARITY_NAMES := ["Common", "Uncommon", "Rare", "Legendary"]
const FOOTER_DEFAULT := "  ← → / D-pad  tab      ↑ ↓  choose      Enter / A  confirm      Esc / B  back"

@onready var _title: Label = $Centre/Panel/Margin/Column/Title
@onready var _wallet: Label = $Centre/Panel/Margin/Column/Wallet
@onready var _gems: Label = $Centre/Panel/Margin/Column/Gems
@onready var _sell_tab: Label = $Centre/Panel/Margin/Column/Tabs/SellTab
@onready var _buy_tab: Label = $Centre/Panel/Margin/Column/Tabs/BuyTab
@onready var _rows: VBoxContainer = $Centre/Panel/Margin/Column/Rows
@onready var _footer: Label = $Centre/Panel/Margin/Column/Footer

signal opened()
signal closed()
signal sell_requested(rarity: int, count: int)
signal sell_all_requested()
signal buy_requested(item: ShopItem)

## The Shop this menu reads from. Set by ranch.gd before open(); never mutated here.
var shop: Shop = null

var _catalogue: Array[ShopItem] = []
var _tab: int = Tab.SELL
var _selected := 0
var _open := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var registry: ShopRegistry = ShopRegistryScript.new()
	registry.load_all(ShopRegistryScript.SHOP_DIR)
	_catalogue = registry.all()
	_style_label(_title, 34, COLOR_TITLE)
	_style_label(_wallet, 22, COLOR_DIM)
	_style_label(_gems, 22, COLOR_DIM)
	_style_label(_sell_tab, 26, COLOR_TAB_ON)
	_style_label(_buy_tab, 26, COLOR_TAB_OFF)
	_style_label(_footer, 20, COLOR_DIM)
	_title.text = "MARKET"
	_sell_tab.text = "SELL"
	_buy_tab.text = "BUY"
	visible = false


# --- opening and closing ------------------------------------------------------------------

func open() -> bool:
	if shop == null:
		return false
	_tab = Tab.SELL
	_selected = 0
	_open = true
	visible = true
	refresh()
	opened.emit()
	return true


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	closed.emit()


func is_open() -> bool:
	return _open


func tab() -> int:
	return _tab


func set_tab(next: int) -> void:
	if next != Tab.SELL and next != Tab.BUY:
		return
	_tab = next
	_selected = 0
	refresh()


func selected_index() -> int:
	return _selected


func footer_text() -> String:
	return _footer.text


## The Sell tab's rarity rows, in enum order. Row 0 on screen is "Sell everything" and is
## NOT in this list; selected_index() 1..N maps to this list's 0..N-1.
func sell_rows() -> Array[int]:
	var out: Array[int] = []
	for rarity in PonyDataScript.Rarity.values():
		out.append(rarity)
	return out


func buy_rows() -> Array[ShopItem]:
	return _catalogue.duplicate()


func _row_count() -> int:
	return sell_rows().size() + 1 if _tab == Tab.SELL else _catalogue.size()


# --- input ----------------------------------------------------------------------------------

func move_selection(step: int) -> void:
	var n := _row_count()
	if n == 0:
		return
	_selected = posmod(_selected + step, n)
	refresh()


## Confirm the row under the cursor. Emits a request; returns false and explains in the
## footer when there is nothing to do.
func confirm() -> bool:
	if shop == null:
		return false
	if _tab == Tab.SELL:
		if _selected == 0:
			if _pouch_total() <= 0:
				_refuse("You have no gems to sell.")
				return false
			sell_all_requested.emit()
			refresh()
			return true
		var rarity: int = sell_rows()[_selected - 1]
		var count := shop.gem_count(rarity)
		if count <= 0:
			_refuse("No %s gems to sell." % RARITY_NAMES[rarity].to_lower())
			return false
		sell_requested.emit(rarity, count)
		refresh()
		return true
	var item := _selected_item()
	if item == null:
		return false
	var why := shop.refusal(item)
	if not why.is_empty():
		_refuse(why)
		return false
	buy_requested.emit(item)
	refresh()
	return true


func sell_everything() -> bool:
	if shop == null or _pouch_total() <= 0:
		return false
	sell_all_requested.emit()
	refresh()
	return true


func _selected_item() -> ShopItem:
	if _tab != Tab.BUY or _selected < 0 or _selected >= _catalogue.size():
		return null
	return _catalogue[_selected]


func _pouch_total() -> int:
	var sum := 0
	for rarity in sell_rows():
		sum += shop.gem_count(rarity)
	return sum


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_down"):
		move_selection(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_up"):
		move_selection(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"ui_right"):
		set_tab(Tab.BUY if _tab == Tab.SELL else Tab.SELL)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_accept"):
		confirm()
		get_viewport().set_input_as_handled()


# --- drawing ----------------------------------------------------------------------------------

## Rebuild the rows for the current tab from the Shop's current numbers. Called on open,
## on every cursor move, and by ranch.gd after a sale or purchase lands, so the counts on
## screen are never a frame behind the pouch.
func refresh() -> void:
	if shop == null:
		return
	_wallet.text = "%d bits" % shop.bits()
	_gems.text = "%d gems in your pouch" % _pouch_total()
	_style_label(_sell_tab, 26, COLOR_TAB_ON if _tab == Tab.SELL else COLOR_TAB_OFF)
	_style_label(_buy_tab, 26, COLOR_TAB_ON if _tab == Tab.BUY else COLOR_TAB_OFF)
	_style_label(_footer, 20, COLOR_DIM)
	_footer.text = FOOTER_DEFAULT
	for child in _rows.get_children():
		child.queue_free()
	if _tab == Tab.SELL:
		_add_row(0, "Sell everything", "", "%d bits" % _sell_all_value(), _pouch_total() > 0)
		for i in range(sell_rows().size()):
			var rarity: int = sell_rows()[i]
			var count := shop.gem_count(rarity)
			_add_row(i + 1, "%s gems" % RARITY_NAMES[rarity], "you have %d" % count,
				"%d bits each" % shop.gem_price(rarity), count > 0)
	else:
		for i in range(_catalogue.size()):
			var item := _catalogue[i]
			var owned := item.kind == ShopItemScript.Kind.GEAR and shop.owns_gear(item.gear_id)
			var price := "OWNED" if owned else ("FREE" if item.cost == 0 else "%d bits" % item.cost)
			_add_row(i, item.display_name, item.description, price, shop.can_buy(item))


func _sell_all_value() -> int:
	var total := 0
	for rarity in sell_rows():
		total += shop.gem_count(rarity) * shop.gem_price(rarity)
	return total


func _add_row(index: int, name: String, blurb: String, price: String, enabled: bool) -> void:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override(&"panel", _row_style(index == _selected))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 18)
	margin.add_theme_constant_override(&"margin_right", 18)
	margin.add_theme_constant_override(&"margin_top", 10)
	margin.add_theme_constant_override(&"margin_bottom", 10)
	row.add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 24)
	column.add_child(head)
	var title := Label.new()
	title.text = name
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_label(title, 26, COLOR_NAME if enabled else COLOR_DIM)
	head.add_child(title)
	var cost := Label.new()
	cost.text = price
	_style_label(cost, 23, COLOR_COST if enabled else COLOR_UNAFFORDABLE)
	head.add_child(cost)
	if not blurb.is_empty():
		var sub := Label.new()
		sub.text = blurb
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.custom_minimum_size = Vector2(720.0, 0.0)
		_style_label(sub, 19, COLOR_DIM)
		column.add_child(sub)
	_rows.add_child(row)


func _refuse(text: String) -> void:
	_footer.text = "  " + text
	_style_label(_footer, 20, COLOR_UNAFFORDABLE)


func _row_style(selected: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = ROW_SELECTED_BG if selected else ROW_IDLE_BG
	box.border_color = ROW_SELECTED_BORDER if selected else ROW_IDLE_BORDER
	box.set_border_width_all(2 if selected else 1)
	box.set_corner_radius_all(8)
	return box


func _style_label(label: Label, size: int, color: Color) -> void:
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.75))
	label.add_theme_constant_override(&"outline_size", 5)
```

`Shop` needs a `bits()` accessor for the wallet line. Add to `game/systems/shop.gd`:
```gdscript
func bits() -> int:
	return _economy.bits
```
and a one-line test in `test_shop.gd`: `assert_eq(_shop.bits(), _econ.bits)` inside `test_buying_care_spends_bits_and_adds_the_food`.

- [ ] **Step 6: Run the two test files**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game --import >/dev/null 2>&1` then the GUT command for `test_market_menu.gd` and `test_build_menu.gd`.
Expected: 11 new passing in market menu; build menu's binding test passes with the two extra actions.

- [ ] **Step 7: Commit**

```bash
git add game/ui/market_menu.gd game/ui/market_menu.tscn game/systems/shop.gd game/test/test_market_menu.gd game/test/test_shop.gd game/test/test_build_menu.gd game/project.godot
git commit -m "feat: the Market menu, a Sell tab and a Buy tab, driven without a mouse"
```

---

### Task 10: The pause menu

**Files:**
- Create: `game/ui/pause_menu.gd`, `game/ui/pause_menu.tscn`
- Modify: `game/project.godot` (new `pause` action)
- Test: `game/test/test_pause_menu.gd`, `game/test/test_player.gd` (binding test gains `pause`)

**Interfaces:**
- Consumes: `Settings`.
- Produces: `class_name PauseMenu extends CanvasLayer`, `enum Page { MAIN, SETTINGS }`, `enum Row { RESUME, SAVE, SETTINGS, QUIT }`, `var settings: Settings`, `var can_open := Callable()` (ranch says whether another menu is up), `open() -> bool`, `close()`, `is_open()`, `page() -> int`, `selected_index() -> int`, `move_selection(step)`, `adjust(direction: int)` (left/right on a settings row), `confirm() -> bool`, signals `opened()`, `closed()`, `save_requested()`, `quit_requested()`, `settings_changed()`. Input action `pause` bound to Escape and gamepad Start (button 6).

- [ ] **Step 1: Add the `pause` action to project.godot**

In the `[input]` block, next to `toggle_hints`, add (copy the exact `Object(InputEventKey, ...)` shape from `interact`; Escape is keycode `4194305`, Start is `button_index: 6`):

```
pause={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194305,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"button_index":6,"pressure":0.0,"pressed":false,"script":null)
]
}
```

Add `"pause"` to the action list in `test_player.gd`'s `test_every_movement_action_has_a_keyboard_and_a_gamepad_binding` (or the sibling test that enumerates project actions).

- [ ] **Step 2: Write the failing tests**

`game/test/test_pause_menu.gd`:
```gdscript
extends GutTest
## Tests for game/ui/pause_menu.gd. Same rules as the other menus: keyboard and gamepad
## through the methods ui_* route into, and the menu only emits; ranch.gd pauses, saves
## and quits.

const PauseMenuScene := preload("res://ui/pause_menu.tscn")
const SettingsScript := preload("res://systems/settings.gd")

var _menu: PauseMenu
var _settings: Settings


func before_each() -> void:
	_settings = SettingsScript.new()
	_menu = PauseMenuScene.instantiate()
	add_child_autofree(_menu)
	_menu.settings = _settings


func test_opens_on_main_with_resume_selected() -> void:
	watch_signals(_menu)
	assert_true(_menu.open())
	assert_true(_menu.is_open())
	assert_eq(_menu.page(), PauseMenu.Page.MAIN)
	assert_eq(_menu.selected_index(), PauseMenu.Row.RESUME)
	assert_signal_emitted(_menu, "opened")


func test_can_open_callable_can_refuse() -> void:
	_menu.can_open = func() -> bool: return false
	assert_false(_menu.open())
	assert_false(_menu.is_open())


func test_resume_closes() -> void:
	_menu.open()
	watch_signals(_menu)
	assert_true(_menu.confirm())
	assert_false(_menu.is_open())
	assert_signal_emitted(_menu, "closed")


func test_save_and_quit_emit_requests() -> void:
	_menu.open()
	watch_signals(_menu)
	_menu.move_selection(PauseMenu.Row.SAVE)
	_menu.confirm()
	assert_signal_emitted(_menu, "save_requested")
	assert_true(_menu.is_open(), "saving does not close the menu")
	_menu.move_selection(PauseMenu.Row.QUIT - PauseMenu.Row.SAVE)
	_menu.confirm()
	assert_signal_emitted(_menu, "quit_requested")


func test_settings_page_adjusts_the_settings_object() -> void:
	_menu.open()
	_menu.move_selection(PauseMenu.Row.SETTINGS)
	assert_true(_menu.confirm())
	assert_eq(_menu.page(), PauseMenu.Page.SETTINGS)
	watch_signals(_menu)
	# row 0 volume, row 1 sensitivity, row 2 invert
	_menu.adjust(-1)
	assert_almost_eq(_settings.master_volume, 0.9, 0.0001)
	_menu.move_selection(1)
	_menu.adjust(1)
	assert_gt(_settings.mouse_sensitivity, SettingsScript.SENSITIVITY_DEFAULT)
	_menu.move_selection(1)
	_menu.adjust(1)
	assert_true(_settings.invert_look)
	assert_signal_emitted(_menu, "settings_changed")


func test_cancel_on_settings_returns_to_main_and_on_main_closes() -> void:
	_menu.open()
	_menu.move_selection(PauseMenu.Row.SETTINGS)
	_menu.confirm()
	_menu.back()
	assert_eq(_menu.page(), PauseMenu.Page.MAIN)
	assert_true(_menu.is_open())
	_menu.back()
	assert_false(_menu.is_open())


func test_selection_wraps_on_both_pages() -> void:
	_menu.open()
	_menu.move_selection(-1)
	assert_eq(_menu.selected_index(), PauseMenu.Row.QUIT)
```

- [ ] **Step 3: Run to verify failure**

Expected: preload error on the scene.

- [ ] **Step 4: Write pause_menu.tscn**

Copy `game/ui/build_menu.tscn` to `game/ui/pause_menu.tscn`: root `PauseMenu`, script `res://ui/pause_menu.gd`, `layer = 3` (above the market and build menus), panel `custom_minimum_size = Vector2(620, 0)`. Keep `Title`, `Rows`, `Footer`; delete `Wallet`.

- [ ] **Step 5: Write pause_menu.gd**

```gdscript
class_name PauseMenu
extends CanvasLayer
## ESCAPE OPENS THIS. It used to free the cursor and nothing else; the owner: "i also
## want pause menu instead of losing mouse control with escape". Phase 2 slice 1.
##
## Resume, Save, Settings, Quit. The rules are game/ui/build_menu.gd's: navigable without
## a mouse on ui_*, PROCESS_MODE_ALWAYS while ranch.gd pauses the tree, and it only emits.
## ranch.gd saves, quits, applies settings, and pauses or unpauses.
##
## `can_open` is how the ranch says "another menu is up": the build and market menus
## close on ui_cancel and this opens on `pause`, both of which are Escape, so without the
## guard one keypress would close one menu and open this one in the same frame.
##
## Phase 2 slice 5 adds Compendium and Requests pages here; the Page enum is where they go.

const SettingsScript := preload("res://systems/settings.gd")

enum Page { MAIN, SETTINGS }
enum Row { RESUME, SAVE, SETTINGS, QUIT }
enum SettingRow { VOLUME, SENSITIVITY, INVERT }

const MAIN_ROWS := ["Resume", "Save the ranch", "Settings", "Quit to desktop"]
const COLOR_TITLE := Color(1.0, 0.96, 0.86, 1.0)
const COLOR_NAME := Color(1.0, 1.0, 1.0, 0.94)
const COLOR_DIM := Color(1.0, 1.0, 1.0, 0.58)
const COLOR_VALUE := Color(1.00, 0.80, 0.25, 1.0)
const ROW_SELECTED_BG := Color(1.0, 0.86, 0.55, 0.16)
const ROW_SELECTED_BORDER := Color(1.0, 0.86, 0.55, 0.75)
const ROW_IDLE_BG := Color(1.0, 1.0, 1.0, 0.04)
const ROW_IDLE_BORDER := Color(1.0, 1.0, 1.0, 0.10)
const FOOTER_MAIN := "  ↑ ↓  choose      Enter / A  select      Esc / B  resume"
const FOOTER_SETTINGS := "  ↑ ↓  choose      ← →  adjust      Esc / B  back"

@onready var _title: Label = $Centre/Panel/Margin/Column/Title
@onready var _rows: VBoxContainer = $Centre/Panel/Margin/Column/Rows
@onready var _footer: Label = $Centre/Panel/Margin/Column/Footer

signal opened()
signal closed()
signal save_requested()
signal quit_requested()
signal settings_changed()

var settings: Settings = null
## `func() -> bool`. Invalid means "always allowed".
var can_open := Callable()

var _page: int = Page.MAIN
var _selected := 0
var _open := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_style_label(_title, 34, COLOR_TITLE)
	_style_label(_footer, 20, COLOR_DIM)
	_title.text = "PAUSED"
	visible = false


func open() -> bool:
	if _open:
		return false
	if can_open.is_valid() and not bool(can_open.call()):
		return false
	if settings == null:
		settings = SettingsScript.new()
	_page = Page.MAIN
	_selected = Row.RESUME
	_open = true
	visible = true
	_refresh()
	opened.emit()
	return true


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	closed.emit()


func is_open() -> bool:
	return _open


func page() -> int:
	return _page


func selected_index() -> int:
	return _selected


func _row_count() -> int:
	return MAIN_ROWS.size() if _page == Page.MAIN else SettingRow.size()


func move_selection(step: int) -> void:
	_selected = posmod(_selected + step, _row_count())
	_refresh()


## Left or right on a settings row. Nothing on the main page.
func adjust(direction: int) -> void:
	if _page != Page.SETTINGS or settings == null:
		return
	match _selected:
		SettingRow.VOLUME:
			settings.step_volume(direction)
		SettingRow.SENSITIVITY:
			settings.step_sensitivity(direction)
		SettingRow.INVERT:
			settings.toggle_invert()
	settings_changed.emit()
	_refresh()


func confirm() -> bool:
	if _page == Page.SETTINGS:
		if _selected == SettingRow.INVERT:
			adjust(1)
			return true
		return false
	match _selected:
		Row.RESUME:
			close()
		Row.SAVE:
			save_requested.emit()
		Row.SETTINGS:
			_page = Page.SETTINGS
			_selected = 0
			_refresh()
		Row.QUIT:
			quit_requested.emit()
	return true


## Cancel: settings goes back to main; main closes.
func back() -> void:
	if _page == Page.SETTINGS:
		_page = Page.MAIN
		_selected = Row.SETTINGS
		_refresh()
		return
	close()


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		if event.is_action_pressed(&"pause"):
			if open():
				get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		back()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_down"):
		move_selection(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_up"):
		move_selection(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_left"):
		adjust(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_right"):
		adjust(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_accept"):
		confirm()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	for child in _rows.get_children():
		child.queue_free()
	if _page == Page.MAIN:
		_title.text = "PAUSED"
		_footer.text = FOOTER_MAIN
		for i in range(MAIN_ROWS.size()):
			_add_row(i, MAIN_ROWS[i], "")
	else:
		_title.text = "SETTINGS"
		_footer.text = FOOTER_SETTINGS
		_add_row(0, "Master volume", "%d%%" % int(round(settings.master_volume * 100.0)))
		_add_row(1, "Mouse sensitivity", "%.1f" % (settings.mouse_sensitivity * 1000.0))
		_add_row(2, "Invert look", "On" if settings.invert_look else "Off")


func _add_row(index: int, name: String, value: String) -> void:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override(&"panel", _row_style(index == _selected))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 18)
	margin.add_theme_constant_override(&"margin_right", 18)
	margin.add_theme_constant_override(&"margin_top", 10)
	margin.add_theme_constant_override(&"margin_bottom", 10)
	row.add_child(margin)
	var head := HBoxContainer.new()
	margin.add_child(head)
	var title := Label.new()
	title.text = name
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_label(title, 26, COLOR_NAME)
	head.add_child(title)
	if not value.is_empty():
		var val := Label.new()
		val.text = value
		_style_label(val, 24, COLOR_VALUE)
		head.add_child(val)
	_rows.add_child(row)


func _row_style(selected: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = ROW_SELECTED_BG if selected else ROW_IDLE_BG
	box.border_color = ROW_SELECTED_BORDER if selected else ROW_IDLE_BORDER
	box.set_border_width_all(2 if selected else 1)
	box.set_corner_radius_all(8)
	return box


func _style_label(label: Label, size: int, color: Color) -> void:
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.75))
	label.add_theme_constant_override(&"outline_size", 5)
```

- [ ] **Step 6: Run the tests**

Expected: `test_pause_menu.gd` 7 passing; `test_player.gd` binding test passes with `pause`.

- [ ] **Step 7: Commit**

```bash
git add game/ui/pause_menu.gd game/ui/pause_menu.tscn game/project.godot game/test/test_pause_menu.gd game/test/test_player.gd
git commit -m "feat: the pause menu, Resume, Save, Settings and Quit, on Escape and Start"
```

---

### Task 11: HUD shows bits; hint card names PAUSE and TRADE

**Files:**
- Modify: `game/ui/hud.gd` (`HINTS` const ~line 495; `_ready` ~line 185; add a `set_bits()` method), `game/ui/hud.tscn` (a `Bits` label under the `Bag`)
- Test: `game/test/test_hud.gd`

**Interfaces:**
- Produces: `HUD.set_bits(total: int) -> void`, `HUD.get_bits_text() -> String`.

- [ ] **Step 1: Write the failing tests**

Append to `test_hud.gd`:
```gdscript
func test_the_bits_line_shows_the_wallet() -> void:
	_hud.set_bits(0)
	assert_eq(_hud.get_bits_text(), "0 bits")
	_hud.set_bits(1234)
	assert_eq(_hud.get_bits_text(), "1234 bits")


func test_the_hints_card_names_pause_and_trade_and_never_free_cursor() -> void:
	var joined := ""
	for row in _hud.HINTS:
		joined += " ".join(row) + "\n"
	assert_string_contains(joined, "PAUSE")
	assert_string_contains(joined, "TRADE")
	assert_false(joined.contains("FREE CURSOR"), "Escape pauses now; it does not free the cursor")
	assert_false(joined.contains("--"), "no double hyphen on the card")
	assert_false(joined.contains("—"), "no em dash on the card")
```

- [ ] **Step 2: Run to verify failure**

Expected: `set_bits` not found; `PAUSE` not in the card.

- [ ] **Step 3: Edit hud.tscn**

Under the `Bag` VBoxContainer, after `Count`, add:
```
[node name="Bits" type="Label" parent="Bag"]
layout_mode = 2
```

- [ ] **Step 4: Edit hud.gd**

Add `@onready var _bits: Label = $Bag/Bits` with the other onready vars. In `_ready()`, after `_style_label(_bag_count, ...)`: `_style_label(_bits, 22, Color(1.00, 0.80, 0.25, 1.0))` and `_bits.text = "0 bits"`.

Add:
```gdscript
## The wallet line under the saddlebag. Driven by ranch.gd off Economy.bits_changed, so
## it repaints on a change and never per frame.
func set_bits(total: int) -> void:
	_bits.text = "%d bits" % maxi(0, total)


func get_bits_text() -> String:
	return _bits.text
```

Replace the `["FREE CURSOR", "Esc", ""],` row in `HINTS` with:
```gdscript
	["TRADE", "E at the market", "X at the market"],
	["", "sell gems for bits, buy food and gear", ""],
	["PAUSE", "Esc", "Start"],
```
Keep `["THIS CARD", "H", "Back"]` last.

- [ ] **Step 5: Run test_hud.gd**

Expected: all passing, two new.

- [ ] **Step 6: Commit**

```bash
git add game/ui/hud.gd game/ui/hud.tscn game/test/test_hud.gd
git commit -m "feat: HUD shows bits; hint card names TRADE and PAUSE"
```

---

### Task 12: The Market building, interaction, and all the wiring in ranch.gd

**Files:**
- Modify: `game/world/ranch.tscn` (a `Market` under `Buildings`; `MarketMenu` and `PauseMenu` instances)
- Modify: `game/world/ranch.gd` (`_ready` ~line 327, `_bind_game_state` ~line 380, `_bind_build_menu` ~line 560, `_on_plot_built` ~line 550, `_physics_process` ~line 760, `_sync_game_state` ~line 711, `_report` ~line 1090)

**Interfaces:**
- Consumes: everything above.
- Produces: `Ranch.collect_gems() -> int` (folds every pen tray into `GameState.gems`, returns gems moved), `Ranch.get_shop() -> Shop`, `Ranch.get_market_menu() -> MarketMenu`, `Ranch.get_pause_menu() -> PauseMenu`, `Ranch.is_near_market() -> bool`, `const MARKET_RADIUS := 4.5`.

- [ ] **Step 1: Add the building and the menus to ranch.tscn**

Under `Buildings`, after `Farmhouse`, add a third `Building` (ExtResource("7") is `building.gd` in this scene; confirm the id by reading the `[ext_resource]` block at the top of the file):
```
[node name="Market" type="StaticBody3D" parent="Buildings"]
transform = Transform3D(0.7071068, 0, 0.7071068, 0, 1, 0, -0.7071068, 0, 0.7071068, 2, 0, 12)
script = ExtResource("7")
width = 5.5
depth = 4.5
wall_height = 2.8
ridge_height = 4.0
door_width = 2.4
door_height = 2.6
wall_color = Color(0.858824, 0.607843, 0.32549, 1)
roof_color = Color(0.556863, 0.231373, 0.192157, 1)
trim_color = Color(0.435294, 0.32549, 0.243137, 1)
```
Pick the position by reading `ranch.tscn`: it must be on open ground, not on a plot slot (`Plots/Slot1..4` at x -9.5/-18.5, z 8.5/17.5), not inside a zone marker's spawn radius, and within a short walk of `PlayerSpawn`. `(2, 0, 12)` is a proposal; if it collides with a prop in `props.gd`'s layout, move it and say where in the commit message.

Add two `[ext_resource]` lines for `res://ui/market_menu.tscn` and `res://ui/pause_menu.tscn` with fresh ids, and two instances after `BuildMenu`:
```
[node name="MarketMenu" parent="." instance=ExtResource("<id>")]

[node name="PauseMenu" parent="." instance=ExtResource("<id>")]
```

- [ ] **Step 2: Wire ranch.gd**

Add preloads and fields near the existing `_economy`:
```gdscript
const ShopScript := preload("res://systems/shop.gd")
const SettingsScript := preload("res://systems/settings.gd")

## How close to the Market's origin counts as "at the market".
const MARKET_RADIUS := 4.5

@onready var market_menu: CanvasLayer = $MarketMenu
@onready var pause_menu: CanvasLayer = $PauseMenu

var _shop: Shop = null
var _settings: Settings = null
## Whether the market prompt has been shown for this approach. Same hysteresis as the
## plot prompt: once on entering the radius, not once per frame.
var _market_prompted := false
```

In `_bind_build_menu()`, after `_economy` is created and connected, build the shop and bind both new menus:
```gdscript
	_shop = ShopScript.new(_economy, _game_state.gems, _game_state.inventory, _game_state.unlocks) \
		if _game_state != null else null
	_bind_market_menu()
	_bind_pause_menu()
	_apply_unlocks()
	var hud := get_node_or_null(^"HUD")
	if hud != null and hud.has_method("set_bits"):
		hud.set_bits(_economy.bits)
```

Add to `_on_bits_changed()`:
```gdscript
	var hud := get_node_or_null(^"HUD")
	if hud != null and hud.has_method("set_bits"):
		hud.set_bits(new_total)
```

New methods:
```gdscript
## The Market and the pause menu follow the build menu's contract: they emit, this
## transacts and pauses. See _bind_build_menu() for why the wiring is by name.
func _bind_market_menu() -> void:
	if market_menu == null or not market_menu.has_method("open") or _shop == null:
		return
	market_menu.set("shop", _shop)
	for pair in [["opened", _on_market_opened], ["closed", _on_menu_closed],
			["sell_requested", _on_sell_requested], ["sell_all_requested", _on_sell_all_requested],
			["buy_requested", _on_buy_requested]]:
		if not market_menu.is_connected(pair[0], pair[1]):
			market_menu.connect(pair[0], pair[1])


func _bind_pause_menu() -> void:
	if pause_menu == null or not pause_menu.has_method("open"):
		return
	_settings = SettingsScript.new()
	_settings.load_from()
	_apply_settings()
	pause_menu.set("settings", _settings)
	pause_menu.set("can_open", Callable(self, "_no_other_menu_open"))
	for pair in [["opened", _on_pause_opened], ["closed", _on_menu_closed],
			["save_requested", _on_pause_save], ["quit_requested", _on_pause_quit],
			["settings_changed", _on_settings_changed]]:
		if not pause_menu.is_connected(pair[0], pair[1]):
			pause_menu.connect(pair[0], pair[1])


func _no_other_menu_open() -> bool:
	for menu in [build_menu, market_menu]:
		if menu != null and menu.has_method("is_open") and menu.is_open():
			return false
	return true


func _on_market_opened() -> void:
	collect_gems()
	if market_menu.has_method("refresh"):
		market_menu.refresh()
	_on_menu_opened(null)


func _on_pause_opened() -> void:
	_on_menu_opened(null)


func _on_sell_requested(rarity: int, count: int) -> void:
	if _shop == null:
		return
	var earned := _shop.sell(rarity, count)
	if earned > 0:
		_toast("Sold %d gems for %d bits." % [count, earned])
	if market_menu.has_method("refresh"):
		market_menu.refresh()


func _on_sell_all_requested() -> void:
	if _shop == null:
		return
	var earned := _shop.sell_all()
	if earned > 0:
		_toast("Sold everything for %d bits." % earned)
	if market_menu.has_method("refresh"):
		market_menu.refresh()


func _on_buy_requested(item: ShopItem) -> void:
	if _shop == null or item == null:
		return
	if _shop.buy(item):
		_toast("Bought %s." % item.display_name)
		_apply_unlocks()
	if market_menu.has_method("refresh"):
		market_menu.refresh()


func _on_pause_save() -> void:
	var ok := save_game()
	_toast("Ranch saved" if ok else "SAVE FAILED. See the log.")


func _on_pause_quit() -> void:
	# GameState's quit-time autosave is what writes on the way out (see game_state.gd);
	# this only asks the tree to close.
	get_tree().paused = false
	get_tree().quit()


func _on_settings_changed() -> void:
	_apply_settings()
	if _settings != null:
		_settings.save_to()


## Push the settings into the things they control. The camera rig owns sensitivity and
## invert; the audio bus owns volume.
func _apply_settings() -> void:
	if _settings == null:
		return
	if _rig != null:
		_rig.mouse_sensitivity = _settings.mouse_sensitivity
		_rig.invert_look = _settings.invert_look
	if _interactive:
		_settings.apply_audio()


## Read GameState.unlocks into the things that honour them. On boot and after every
## purchase.
func _apply_unlocks() -> void:
	if _game_state == null:
		return
	var beam: Node3D = player.get_magic_beam()
	if beam != null and beam.has_method("apply_unlocks"):
		beam.apply_unlocks(_game_state.unlocks)


## Fold every pen's tray into the pouch. Before a save (so the gems survive quitting) and
## when the Market opens (so it sells what the pens made a second ago). Returns how many
## gems moved.
func collect_gems() -> int:
	if _game_state == null:
		return 0
	var moved := 0
	for slot in _plot_slots():
		var pen := slot.get_built() as Pen
		if pen == null:
			continue
		var tray: Dictionary = pen.take_gems_by_rarity()
		for rarity in tray.keys():
			_game_state.gems.add(int(rarity), int(tray[rarity]))
			moved += int(tray[rarity])
	return moved


func is_near_market() -> bool:
	var market := get_node_or_null(^"Buildings/Market") as Node3D
	if market == null:
		return false
	var gap := Vector2(player.global_position.x - market.global_position.x,
		player.global_position.z - market.global_position.z).length()
	return gap <= MARKET_RADIUS


## E at the market opens it. The prompt shows once per approach, like the plot prompt.
func _update_market_interaction() -> void:
	if not _no_other_menu_open():
		return
	if pause_menu != null and pause_menu.has_method("is_open") and pause_menu.is_open():
		return
	var near := is_near_market()
	if near != _market_prompted:
		_market_prompted = near
		if near:
			_toast("Press E / X to trade.")
	if near and Input.is_action_just_pressed(&"interact") and _prompt_slot == null:
		if market_menu != null and market_menu.has_method("open"):
			market_menu.open()


func get_shop() -> Shop:
	return _shop


func get_market_menu() -> CanvasLayer:
	return market_menu


func get_pause_menu() -> CanvasLayer:
	return pause_menu
```

`_on_menu_opened(_slot)` is typed `PlotSlot`; passing `null` is fine. If the signature is strict, change it to `func _on_menu_opened(_slot: PlotSlot = null)`.

In `_physics_process()`, call `_update_market_interaction()` right after `_update_plot_interaction()`.

In `_on_plot_built()`, hand the pen the pantry:
```gdscript
	if pen != null:
		pen.ground_sampler = Callable(terrain, "height_at")
		pen.inventory_provider = Callable(self, "_current_inventory")
```
with:
```gdscript
func _current_inventory() -> Inventory:
	return _game_state.inventory if _game_state != null else null
```

In `_sync_game_state()`, as the first line after the null check: `collect_gems()`.

After a load replaces `gems`/`inventory` objects (in `_bind_game_state`, right after `load_from_slot()`), nothing else holds a reference yet, so no rebind is needed there; but `_bind_build_menu()` must run AFTER `_bind_game_state()`. Confirm the call order in `_ready()`.

In `_report()`, after the plot checks, add:
```gdscript
	_set_check(checks, "the market building stands", get_node_or_null(^"Buildings/Market") != null)
	_set_check(checks, "the shop is wired", _shop != null)
	_set_check(checks, "the market menu is wired",
		market_menu != null and market_menu.has_method("open") and market_menu.get("shop") == _shop)
	_set_check(checks, "the pause menu is wired",
		pause_menu != null and pause_menu.has_method("open") and pause_menu.get("settings") == _settings)
	var catalogue_count: int = market_menu.buy_rows().size() if market_menu != null \
		and market_menu.has_method("buy_rows") else 0
	_set_check(checks, "the shop catalogue loaded", catalogue_count > 0)
	print("RANCH market shop=%s catalogue=%d gems=%d inventory=%d unlocks=%d"
		% [_shop != null, catalogue_count,
			_game_state.gems.total() if _game_state != null else 0,
			_game_state.inventory.ids().size() if _game_state != null else 0,
			_game_state.unlocks.size() if _game_state != null else 0])
```

The buildings loop in `_ready()` calls `node.build()` on every child of `Buildings`, so the Market is built and seated with no further code. `props=33` in the `RANCH_OK` line becomes `props=34`; update any assertion that pins 33 (grep `props=33` and `expected=33` in `ranch.gd`, and `.github/workflows/smoke_run.sh` if it pins the number).

- [ ] **Step 3: Run the ranch scene headless and the full suite**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game world/ranch.tscn 2>&1 | grep -E "RANCH market|RANCH_(OK|FAILED)|FAILED check"; echo "exit=$?"`
Expected: `RANCH market shop=true catalogue=7 ...`, `RANCH_OK ponies=10 props=34 assets=present`, exit 0. Then `bash tools/run_tests.sh` green.

- [ ] **Step 4: Commit**

```bash
git add game/world/ranch.tscn game/world/ranch.gd .github/workflows/smoke_run.sh
git commit -m "feat: the Market stands on the ranch; E trades, Escape pauses, gems are collected before a save"
```

---

### Task 13: The market gate, end to end

**Files:**
- Create: `game/scenes/test/market_test.gd`, `game/scenes/test/market_test.tscn`

**Interfaces:**
- Consumes: `Ranch` public surface from Task 12.
- Produces: the marker `MARKET_OK checks=N` (or `MARKET_FAILED`), exit code as verdict.

- [ ] **Step 1: Write the scene**

`game/scenes/test/market_test.tscn` instances the real ranch and adds a driver on top:
```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scenes/test/market_test.gd" id="1"]
[ext_resource type="PackedScene" path="res://world/ranch.tscn" id="2"]

[node name="MarketTest" type="Node"]
script = ExtResource("1")

[node name="Ranch" parent="." instance=ExtResource("2")]
```

Read `game/scenes/test/capture_test.gd`'s `_set_check` and its final report to copy the exact idiom (duplicate-label detection included).

- [ ] **Step 2: Write the gate**

```gdscript
extends Node
## THE MARKET GATE. Proves the loop the Phase 1B playtest found broken: 21 ponies penned,
## gems produced, zero bits, because nothing sold them. Runs the real ranch, builds a
## pen, pens a happy pony, ticks her until she makes gems, opens the Market, sells,
## buys hay, watches a hungry pony eat it, buys gear, sees the beam honour it, saves and
## reloads gems and inventory, and opens and closes the pause menu without leaving the
## tree paused.
##
## Marker after verdict, exit code is the verdict. See docs/testing.md.

const GateWatchdogScript := preload("res://scripts/gate_watchdog.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")
const ProductionScript := preload("res://systems/production.gd")
const NeedsScript := preload("res://systems/needs.gd")
const MarketMenuScript := preload("res://ui/market_menu.gd")
const SaveIOScript := preload("res://systems/save_io.gd")

const SLOT := 8  # a scratch slot; the ranch boots from DEFAULT_SLOT and never sees this

var _checks: Dictionary = {}
var _duplicates: Array[String] = []


func _set_check(label: String, ok: bool) -> void:
	if _checks.has(label):
		_duplicates.append(label)
	_checks[label] = ok


func _ready() -> void:
	GateWatchdogScript.arm(self, "MARKET", 120.0)
	var ranch: Node = $Ranch
	# Let the ranch finish its own boot (it awaits inside _ready). Wait for its report
	# marker by polling the shop, which is bound at the end of boot.
	var waited := 0
	while ranch.get_shop() == null and waited < 600:
		await get_tree().physics_frame
		waited += 1
	_set_check("the ranch booted and bound a shop", ranch.get_shop() != null)
	if ranch.get_shop() == null:
		_finish()
		return

	var state: Node = get_node("/root/GameState")
	state.reset()
	var shop = ranch.get_shop()

	# --- produce ------------------------------------------------------------------------
	var slots: Array = ranch._plot_slots()
	_set_check("there is an empty plot to build on", slots.size() > 0 and slots[0].is_empty())
	var free_plot = null
	for plot in ranch._plots_catalogue().all():
		if plot.cost == 0:
			free_plot = plot
			break
	_set_check("a free plot type exists", free_plot != null)
	_set_check("the pen goes up", slots[0].build(free_plot))
	var pen = slots[0].get_built()
	var her = PonyInstanceScript.create(&"twilight")
	her.happiness = 1.0
	her.hunger = 0.0
	_set_check("she moves in", pen.add_pony(her))
	pen.tick(ProductionScript.PRODUCTION_PERIOD_SECONDS * 3.0)
	_set_check("three periods make three gems", pen.gems() == 3)
	var rarity: int = her.data().rarity

	# --- sell ---------------------------------------------------------------------------
	var menu = ranch.get_market_menu()
	_set_check("the market opens", menu.open())
	_set_check("opening collected the tray into the pouch", shop.gem_count(rarity) == 3 and pen.gems() == 0)
	_set_check("the tree is paused while the market is up", get_tree().paused)
	var expected_bits: int = 3 * shop.gem_price(rarity)
	_set_check("sell everything is confirmable", menu.confirm())
	_set_check("selling paid the rarity price", shop.bits() == expected_bits)
	_set_check("the pouch is empty after selling", shop.gem_count(rarity) == 0)
	_set_check("the wallet reached GameState", state.bits == expected_bits)

	# --- buy care -----------------------------------------------------------------------
	menu.set_tab(MarketMenuScript.Tab.BUY)
	var hay_index := -1
	var rows: Array = menu.buy_rows()
	for i in range(rows.size()):
		if rows[i].id == &"hay":
			hay_index = i
	_set_check("hay is in the catalogue", hay_index >= 0)
	menu.move_selection(hay_index)
	var before := shop.bits()
	_set_check("hay is affordable from one common pony's sale", menu.confirm())
	_set_check("hay landed in the inventory", state.inventory.count(&"hay") >= 1)
	_set_check("hay cost bits", shop.bits() < before)

	# --- eat ----------------------------------------------------------------------------
	her.hunger = NeedsScript.HUNGRY_THRESHOLD + 0.1
	var hay_before := state.inventory.count(&"hay")
	pen.tick(0.1)
	_set_check("a hungry resident ate from the inventory", state.inventory.count(&"hay") == hay_before - 1)
	_set_check("and is no longer hungry", her.hunger < NeedsScript.HUNGRY_THRESHOLD)

	# --- buy gear -----------------------------------------------------------------------
	state.bits = 1000
	ranch._economy.bits = 1000  # test-only: fund the wallet directly
	var beam: Node3D = ranch.player.get_magic_beam()
	var capacity_before: int = beam.get_storage().capacity
	var reach_before: float = beam.reach()
	var bag_index := -1
	for i in range(rows.size()):
		if rows[i].id == &"bigger_saddlebag":
			bag_index = i
	menu.set_tab(MarketMenuScript.Tab.BUY)
	menu.move_selection(bag_index)
	_set_check("the saddlebag is buyable when funded", menu.confirm())
	_set_check("the unlock is recorded", state.unlocks.has("bigger_saddlebag"))
	_set_check("the beam grew the bag", beam.get_storage().capacity > capacity_before)
	_set_check("the saddlebag cannot be bought twice", not menu.confirm())
	_set_check("reach is unchanged by the saddlebag", is_equal_approx(beam.reach(), reach_before))
	menu.close()
	_set_check("closing the market unpauses", not get_tree().paused)

	# --- save and reload ----------------------------------------------------------------
	state.gems.add(PonyDataScript.Rarity.LEGENDARY, 2)
	_set_check("the save lands", state.save_to_slot(SLOT))
	var raw := SaveIOScript.load(SLOT)
	_set_check("the file is version 2", int(raw.get("version", 0)) == 2)
	_set_check("gems are in the file", raw.has("gems") and raw["gems"].get("3", 0) == 2)
	_set_check("inventory is in the file", raw.has("inventory"))
	_set_check("unlocks are in the file", raw.get("unlocks", []).has("bigger_saddlebag"))
	state.reset()
	_set_check("a reset emptied the pouch", state.gems.is_empty())
	_set_check("the slot loads back", state.load_from_slot(SLOT))
	_set_check("gems came back", state.gems.count(PonyDataScript.Rarity.LEGENDARY) == 2)
	_set_check("unlocks came back", state.unlocks.has("bigger_saddlebag"))

	# --- pause menu ---------------------------------------------------------------------
	var pause = ranch.get_pause_menu()
	_set_check("the pause menu opens", pause.open())
	_set_check("the tree is paused while paused", get_tree().paused)
	_set_check("the pause menu refuses to open twice", not pause.open())
	pause.close()
	_set_check("resuming unpauses", not get_tree().paused)
	_set_check("the market will not open under the pause menu", true)  # covered by can_open test
	pause.open()
	_set_check("the market refuses while paused", not menu.open())
	pause.close()

	# --- cleanup ------------------------------------------------------------------------
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveIOScript.slot_path(SLOT)))
	_finish()


func _finish() -> void:
	var all_ok := _duplicates.is_empty()
	for label in _checks:
		if not _checks[label]:
			push_error("market_test: FAILED check: %s" % label)
			all_ok = false
	for label in _duplicates:
		push_error("market_test: DUPLICATE CHECK LABEL: %s" % label)
	print(("MARKET_OK " if all_ok else "MARKET_FAILED ") + "checks=%d" % _checks.size())
	get_tree().quit(0 if all_ok else 1)
```

Remove the placeholder line `_set_check("the market will not open under the pause menu", true)`; a check that is always true is the thing this project's gate rules forbid. The line after it (`the market refuses while paused`) is the real check.

`ranch._plot_slots()`, `ranch._plots_catalogue()` and `ranch._economy` are underscore-private by convention but reachable in GDScript; the gate reads them. If the executor prefers, add public `plot_slots()` and `plots_catalogue()` to ranch.gd and use those.

`SaveIO.slot_path()` and `GameState.load_from_slot(slot)` exist (test_save_io.gd uses them); confirm the exact names.

- [ ] **Step 3: Run the gate**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/market_test.tscn 2>&1 | grep -E "MARKET_(OK|FAILED)|FAILED check|DUPLICATE"; echo "exit=${PIPESTATUS[0]}"`
Expected: `MARKET_OK checks=42` (count may differ by a few; what matters is every label passes), exit 0. Iterate on any failing label; do not weaken the check.

- [ ] **Step 4: Run every gate by exit code, plus the suite**

```bash
for s in smoke model_gallery walk_test terrain_probe registry_gallery playground camera_test wild_ponies capture_test market_test; do
  out=$(timeout 900 tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/$s.tscn 2>&1); rc=$?
  printf "%-18s exit=%-3s %s\n" $s $rc "$(echo "$out" | grep -oE '[A-Z_]+_(OK|FAILED)[^ ]*( checks=[0-9]+| count=[0-9]+)?' | head -1)"
done
out=$(timeout 900 tools/bin/godot --headless --audio-driver Dummy --path game world/ranch.tscn 2>&1); echo "ranch exit=$? $(echo "$out" | grep -oE 'RANCH_(OK|FAILED)[^"]*')"
bash tools/run_tests.sh 2>&1 | grep -E "^Tests|^Passing|All tests passed|FAILED"
```
Expected: every gate exit 0; `RANCH_OK ponies=10 props=34 assets=present`; suite green.

- [ ] **Step 5: Commit**

```bash
git add game/scenes/test/market_test.gd game/scenes/test/market_test.tscn
git commit -m "test: the market gate, the whole loop from gem to bits to hay to a fed pony"
```

---

### Task 14: Test floor, docs, merge

**Files:**
- Modify: `tools/run_tests.sh` line 125 (`MIN_TESTS`)
- Modify: `docs/testing.md` (add `market_test` to the gate list if the doc keeps one)

- [ ] **Step 1: Raise the floor to the count the suite now reports**

Read the `Tests` line from the last `run_tests.sh` output and set `MIN_TESTS="${FILLY_MIN_TESTS:-<that number>}"`.

- [ ] **Step 2: Run the suite once more to confirm the floor holds**

Expected: green, no "below this suite's floor" error.

- [ ] **Step 3: Commit and merge**

```bash
git add tools/run_tests.sh docs/testing.md
git commit -m "chore: raise the test floor after slice 1; document the market gate"
git switch master
git merge --no-ff phase2-slice1-market -m "Merge Phase 2 slice 1: the Market and the pause menu"
```

- [ ] **Step 4: Update the play copy and boot it**

```bash
git -C /home/admin/Documents/filly-rancher-play checkout -q --detach master
tools/bin/godot --headless --audio-driver Dummy --path /home/admin/Documents/filly-rancher-play/game --import >/dev/null 2>&1
tools/bin/godot --headless --audio-driver Dummy --path /home/admin/Documents/filly-rancher-play/game world/ranch.tscn 2>&1 | grep -oE 'RANCH_(OK|FAILED)[^"]*'
```
Expected: `RANCH_OK ponies=10 props=34 assets=present`.

---

## Self-review

**Spec coverage.** The Market (Sell, Buy with CARE and GEAR; PERMIT and BUILD kinds exist and are refused): Tasks 3, 4, 9, 12. Pause menu (Resume, Settings, Save, Quit; cursor freed and captured; `camera_rig` toggle replaced; hint row): Tasks 8, 10, 11, 12. Data model (`inventory`, `unlocks` gaining gear ids, version increment with defaults): Tasks 5, 7. Spec says "the build menu keeps its plot-side flow": unchanged. Testing section (pure-logic tests, a headless gate, save round trips including a version 1 file): Tasks 1 to 8, 13, 5. Not in this slice by the spec's own build order: `world_time`, `compendium`, `requests`, Compendium and Requests pages (slice 5); `RegionGate` (slice 3).

**Placeholder scan.** None. Every step has code or an exact command.

**Type consistency.** `Shop` signature `(economy, pouch, inventory, unlocks)` in Tasks 4, 9, 12. `GemPouch.take(rarity, count) -> int` used by `Shop.sell`. `Pen.take_gems_by_rarity() -> Dictionary` used by `Ranch.collect_gems()`. `MagicBeam.reach()` and `apply_unlocks(Array)` used in Task 13. `MarketMenu.buy_rows() -> Array[ShopItem]` used in ranch's report and the gate. `PauseMenu.back()` is defined in Task 10 and used by its test.
