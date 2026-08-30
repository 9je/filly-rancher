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


## by_zone() USED TO BE ASKED WHETHER IT RETURNED THE WHOLE ROSTER, because until slice 3
## every character was zoned `ranch` and "filters correctly" and "returns everything" were
## the same answer. Now that the roster lives in five places, the question worth asking is
## that the zones PARTITION it: every character is somewhere, no character is counted
## twice, and every zone the roster names has somebody in it.
func test_by_zone_partitions_the_roster_across_the_places_it_names() -> void:
	var ponies := registry.load_all(PONY_DIR)
	var expected := {}
	for id in ponies:
		for zone in ponies[id].spawn_zones:
			expected[zone] = int(expected.get(zone, 0)) + 1
	assert_gt(expected.size(), 1, "the roster names more than one place to live")
	var total := 0
	for zone in expected:
		var found: Array[PonyData] = registry.by_zone(zone)
		assert_eq(found.size(), int(expected[zone]), "by_zone('%s') must find them all" % zone)
		assert_gt(found.size(), 0, "zone '%s' has nobody in it" % zone)
		total += found.size()
	# Equal only while nobody is zoned to two places at once, which is the arrangement the
	# .tres files carry: one zone each. A character in two zones would make this a sum
	# larger than the roster, and that is the point at which this assertion should be
	# rewritten rather than deleted.
	assert_eq(total, ponies.size(), "every pony is zoned to exactly one place")
	assert_gt(registry.by_zone(&"ranch").size(), 0, "the homestead still has residents")
	# Prove by_zone actually filters (not just returning everything): a zone
	# nothing is assigned to must come back empty.
	var nowhere_ponies := registry.by_zone(&"nonexistent_zone")
	assert_eq(nowhere_ponies.size(), 0, "an unused zone should filter out every pony")


func test_ids_are_every_id_on_disk_sorted_by_their_text() -> void:
	# WHAT all() AND ids() REPLACED: four by_rarity() calls unioned by hand, written out in
	# the compendium, in the pause menu and in the collection gate, each relying on the
	# accident that rarity partitions the roster and each leaving the order inside a tier to
	# whatever DirAccess handed back. This is the one order the book, the page and the gate
	# now share.
	var ponies := registry.load_all(PONY_DIR)
	var ids: Array[StringName] = registry.ids()

	assert_eq(ids.size(), ponies.size(), "every character on disk, exactly once")
	assert_eq(ids.size(), 43, "the shipped roster, per docs/pipeline.md")

	var as_text: Array[String] = []
	for id: StringName in ids:
		as_text.append(String(id))
	var sorted := as_text.duplicate()
	sorted.sort()
	# SORTED BY TEXT, not by StringName. StringName orders by interned pointer, which is
	# stable inside one process and different between two, so a raw sort would pass this
	# test and still shuffle the compendium between launches; comparing against a String
	# sort is what makes the cast in ids() load bearing.
	assert_eq(as_text, sorted, "the ids come back in text order")

	var uniq := {}
	for id: StringName in ids:
		uniq[id] = true
	assert_eq(uniq.size(), ids.size(), "and nobody is in the list twice")


func test_all_is_the_same_roster_in_the_same_order_as_ids() -> void:
	registry.load_all(PONY_DIR)
	var data: Array[PonyData] = registry.all()
	var ids: Array[StringName] = registry.ids()

	assert_eq(data.size(), ids.size(), "one record per id")
	var from_data: Array[StringName] = []
	for entry: PonyData in data:
		from_data.append(entry.id)
	assert_eq(from_data, ids, "all() walks the roster in ids() order")
	assert_eq(registry.by_id(ids[0]), data[0], "and hands back the registry's own records")


func test_an_unloaded_registry_answers_both_with_an_empty_list() -> void:
	# The state a registry is in between construction and its first scan, and the state a
	# directory that could not be opened leaves it in. Every caller iterates these results
	# unconditionally, so neither may be null.
	assert_eq(registry.ids(), [] as Array[StringName])
	assert_eq(registry.all(), [] as Array[PonyData])


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
	for legendary in [&"sunsetshimmer", &"trixie", &"shiningarmor"]:
		assert_true(legendary_ids.has(legendary), "%s is LEGENDARY" % legendary)
	# Three, and the number is load bearing rather than incidental: SpawnTable splits a
	# tier's weight among its members, so the size of this tier IS the per pony rarity of
	# everyone in it. At one member a legendary was drawn more often than any individual
	# RARE pony; at three the ordering comes out right. See the ordering test in
	# game/test/test_spawn_table.gd.
	assert_eq(legendary_ids.size(), 3, "the LEGENDARY tier is exactly these three")


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
