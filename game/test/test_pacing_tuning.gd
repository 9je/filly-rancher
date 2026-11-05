extends GutTest
## THE FIRST PENS SHOULD TAKE SOME ROAMING (owner playtest 2026-10-25: "its super easy to
## catch ponies so you can collect all the spots before you get upgrades"). After the catch
## ramp, a bot still filled both starter pens by 3:36 and could not afford the first
## upgrade until about minute ten: the pasture by the yard held five ponies and refilled
## every 45 s, so the next catch was always a few steps away. The pasture now holds a few,
## and an emptied field stays empty long enough that filling pens means heading out.

const SpawnerScript := preload("res://world/spawner.gd")


func _zone_prop(zone: String, prop: StringName) -> Variant:
	var state := (load("res://world/ranch.tscn") as PackedScene).get_state()
	for i in state.get_node_count():
		if String(state.get_node_name(i)) == zone:
			for p in state.get_node_property_count(i):
				if state.get_node_property_name(i, p) == prop:
					return state.get_node_property_value(i, p)
	return null


func test_the_pasture_by_the_yard_holds_only_a_few_wild_ponies() -> void:
	var stock: Variant = _zone_prop("HomePasture", &"stock_count")
	assert_not_null(stock)
	assert_lte(int(stock), 2, "one for the first lesson and a spare, not a herd")


func test_an_emptied_field_stays_empty_for_a_walk_and_back() -> void:
	assert_gte(SpawnerScript.STOCK_RESPAWN_SECONDS, 90.0)
