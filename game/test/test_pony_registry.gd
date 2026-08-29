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


# COUNTED FROM THE DIRECTORY, NOT HARDCODED. The three tests below used to assert the
# literal 3 the roster happened to have on the day they were written, and all three went
# red the moment it grew to six (docs/pipeline.md 5b's Source-engine characters). A count
# that has to be edited whenever a designer adds a .tres is not testing the registry, it
# is testing the roster -- so what they assert now is the registry's INVARIANTS: it
# returns everything on disk, `by_zone` and `by_rarity` PARTITION that set rather than
# dropping or duplicating anyone, and the characters the game's own balance depends on
# land in the right bucket. Adding a pony needs no edit here; miscataloguing one still
# fails.

## Every pony resource actually on disk. `.remap` is stripped because an exported
## project ships `foo.tres.remap` where a source tree has `foo.tres`.
func _roster_files() -> PackedStringArray:
	var found := PackedStringArray()
	for file_name in DirAccess.get_files_at(PONY_DIR):
		if file_name.trim_suffix(".remap").ends_with(".tres"):
			found.append(file_name.trim_suffix(".remap"))
	return found


func test_load_all_returns_every_pony_file_on_disk() -> void:
	var ponies := registry.load_all(PONY_DIR)
	assert_eq(ponies.size(), _roster_files().size(),
		"load_all must return one entry per .tres in " + PONY_DIR)
	assert_gt(ponies.size(), 0, "the roster directory must not be empty")
	for id in [&"twilight", &"rainbowdash", &"fluttershy",
			&"pinkiepie", &"derpyhooves", &"starlightglimmer"]:
		assert_true(ponies.has(id), "roster is missing " + str(id))


func test_by_zone_filters_to_ranch_zoned_ponies() -> void:
	var ponies := registry.load_all(PONY_DIR)
	var ranch_ponies := registry.by_zone(&"ranch")
	assert_eq(ranch_ponies.size(), ponies.size(),
		"every pony currently on the roster is zoned to ranch")
	# Prove by_zone actually filters (not just returning everything): a zone
	# nothing is assigned to must come back empty.
	var nowhere_ponies := registry.by_zone(&"nonexistent_zone")
	assert_eq(nowhere_ponies.size(), 0, "an unused zone should filter out every pony")


func test_by_rarity_partitions_the_roster() -> void:
	var ponies := registry.load_all(PONY_DIR)
	var buckets := {}
	var total := 0
	for r in [PonyDataScript.Rarity.COMMON, PonyDataScript.Rarity.UNCOMMON,
			PonyDataScript.Rarity.RARE, PonyDataScript.Rarity.LEGENDARY]:
		buckets[r] = registry.by_rarity(r)
		total += (buckets[r] as Array).size()
	assert_eq(total, ponies.size(),
		"the four rarity buckets must partition the roster -- no pony in two, none in none")
	var rare_ids: Array = []
	for p in buckets[PonyDataScript.Rarity.RARE]:
		rare_ids.append(p.id)
	assert_true(rare_ids.has(&"twilight"), "twilight is RARE")
	assert_true(rare_ids.has(&"rainbowdash"), "rainbowdash is RARE")
	var uncommon_ids: Array = []
	for p in buckets[PonyDataScript.Rarity.UNCOMMON]:
		uncommon_ids.append(p.id)
	assert_true(uncommon_ids.has(&"fluttershy"), "fluttershy is UNCOMMON")
	assert_false(uncommon_ids.has(&"twilight"), "by_rarity must not return everything")
	var legendary_ids: Array = []
	for p in buckets[PonyDataScript.Rarity.LEGENDARY]:
		legendary_ids.append(p.id)
	assert_true(legendary_ids.has(&"sunsetshimmer"), "sunsetshimmer is LEGENDARY")
	assert_true(legendary_ids.has(&"songbirdserenade"), "songbirdserenade is LEGENDARY")


func test_load_all_entries_are_pony_data() -> void:
	var ponies := registry.load_all(PONY_DIR)
	var twilight = ponies[&"twilight"]
	assert_true(twilight is PonyDataScript, "loaded entry should be a PonyData resource")
	assert_eq(twilight.id, &"twilight")


func test_unknown_id_returns_null_not_a_crash() -> void:
	var ponies := registry.load_all(PONY_DIR)
	assert_null(ponies.get(&"totally_not_a_real_pony"))


func test_by_id_looks_a_character_up_and_answers_null_for_a_stranger() -> void:
	# The accessor a PonyInstance resolves its data_id through
	# (game/systems/pony_instance.gd). Null for an unknown id is a SUPPORTED answer, not an
	# error path: a save file, or a traded pony blob, can name a character this build does
	# not carry, and the caller has to show a default rather than crash.
	registry.load_all(PONY_DIR)
	var twilight: PonyData = registry.by_id(&"twilight")
	assert_not_null(twilight, "a character on the roster must be findable by id")
	assert_eq(twilight.id, &"twilight", "...and it must be the one that was asked for")
	assert_null(registry.by_id(&"totally_not_a_real_pony"),
		"a character this build has never heard of resolves to null")


func test_by_id_on_a_registry_that_has_loaded_nothing_is_null_not_a_crash() -> void:
	# No load_all() at all -- the state a registry is in between construction and its first
	# scan, and the state it is left in if the roster directory could not be opened.
	assert_null(registry.by_id(&"twilight"),
		"an unloaded registry knows nobody, and must say so rather than crash")


func test_malformed_model_path_is_reported_not_swallowed() -> void:
	var ponies := registry.load_all(MALFORMED_DIR)
	# Reported: load_all must surface the bad model_path via push_error
	# rather than swallowing it silently.
	assert_push_error(1, "load_all should push_error on a missing/malformed model_path")
	# Not swallowed: the malformed entry is still returned to the caller
	# instead of vanishing from the result with no trace at all.
	assert_eq(ponies.size(), 1)
	assert_true(ponies.has(&"brokenpony"))
