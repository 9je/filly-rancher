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
