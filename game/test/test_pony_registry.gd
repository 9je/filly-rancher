extends GutTest
## Tests for PonyData (game/systems/pony_data.gd) and PonyRegistry
## (game/systems/pony_registry.gd). Preloads by path rather than referencing
## the global class_name, matching the convention documented at the top of
## game/scripts/pony_rig.gd (the global class cache lives in the gitignored
## game/.godot/ and a fresh clone hasn't built it yet).

const PonyRegistryScript := preload("res://systems/pony_registry.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")

const PONY_DIR := "res://data/ponies/"
const MALFORMED_DIR := "res://test/fixtures/ponies_malformed/"

var registry: PonyRegistry


func before_each() -> void:
	registry = PonyRegistryScript.new()


func test_load_all_returns_three_entries() -> void:
	var ponies := registry.load_all(PONY_DIR)
	assert_eq(ponies.size(), 3, "expected 3 pony data files in " + PONY_DIR)
	assert_true(ponies.has(&"twilight"))
	assert_true(ponies.has(&"rainbowdash"))
	assert_true(ponies.has(&"fluttershy"))


func test_load_all_entries_are_pony_data() -> void:
	var ponies := registry.load_all(PONY_DIR)
	var twilight = ponies[&"twilight"]
	assert_true(twilight is PonyDataScript, "loaded entry should be a PonyData resource")
	assert_eq(twilight.id, &"twilight")


func test_by_zone_filters_to_ranch_zoned_ponies() -> void:
	registry.load_all(PONY_DIR)
	var ranch_ponies := registry.by_zone(&"ranch")
	assert_eq(ranch_ponies.size(), 3, "all three current ponies are zoned to ranch")
	# Prove by_zone actually filters (not just returning everything): a zone
	# nothing is assigned to must come back empty.
	var nowhere_ponies := registry.by_zone(&"nonexistent_zone")
	assert_eq(nowhere_ponies.size(), 0, "an unused zone should filter out every pony")


func test_by_rarity_filters_correctly() -> void:
	registry.load_all(PONY_DIR)
	var rare := registry.by_rarity(PonyDataScript.Rarity.RARE)
	var uncommon := registry.by_rarity(PonyDataScript.Rarity.UNCOMMON)
	var legendary := registry.by_rarity(PonyDataScript.Rarity.LEGENDARY)
	assert_eq(rare.size(), 2, "twilight and rainbowdash are both RARE")
	assert_eq(uncommon.size(), 1, "fluttershy is UNCOMMON")
	assert_eq(legendary.size(), 0, "no LEGENDARY ponies exist yet")
	var rare_ids: Array = []
	for p in rare:
		rare_ids.append(p.id)
	assert_true(rare_ids.has(&"twilight"))
	assert_true(rare_ids.has(&"rainbowdash"))


func test_unknown_id_returns_null_not_a_crash() -> void:
	var ponies := registry.load_all(PONY_DIR)
	assert_null(ponies.get(&"totally_not_a_real_pony"))


func test_malformed_model_path_is_reported_not_swallowed() -> void:
	var ponies := registry.load_all(MALFORMED_DIR)
	# Reported: load_all must surface the bad model_path via push_error
	# rather than swallowing it silently.
	assert_push_error(1, "load_all should push_error on a missing/malformed model_path")
	# Not swallowed: the malformed entry is still returned to the caller
	# instead of vanishing from the result with no trace at all.
	assert_eq(ponies.size(), 1)
	assert_true(ponies.has(&"brokenpony"))
