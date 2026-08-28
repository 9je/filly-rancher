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
