extends GutTest
## SOMETHING TO SPEND ON LATER (FS7.1; systems/decor.gd). After an ending bits piled up with
## nothing to buy (a bot save finished on 27,000). The Market sells twelve decorations, 200 to
## 20,000 bits, each with its own hand-placed spot round the homestead: buying one stands it
## there. Spots, not free placement, so a decoration can never block a road, a pen gate or a
## townspony (DECISIONS.md 2026-11-05).

const DecorScript := preload("res://systems/decor.gd")
const TerrainScript := preload("res://world/terrain.gd")
const PropsScript := preload("res://world/props.gd")
const PeopleScript := preload("res://world/people.gd")

const BUILDINGS := {"Farmhouse": Vector2(2, -16), "Board": Vector2(-8, -13), "Market": Vector2(18, -3),
	"Depot": Vector2(-14, -3), "Barn": Vector2(-17, -19)}
const SMALL_THINGS := {"Mailbox": Vector2(8, 7), "Spike": Vector2(5.5, 3.5),
	"Signpost": Vector2(4.6, 0.9), "Yard sign": Vector2(-3.4, 12.6)}
const PLOTS := [Vector2(-9.5, 11), Vector2(-9.5, 20), Vector2(-18.5, 11), Vector2(-18.5, 20)]


func _at(d: Dictionary) -> Vector2:
	return Vector2((d.at as Vector3).x, (d.at as Vector3).z)


func test_there_are_twelve_from_200_to_20000_bits() -> void:
	var costs: Array = DecorScript.CATALOGUE.map(func(d: Dictionary) -> int: return int(d.cost))
	assert_eq(costs.size(), 12)
	assert_eq(costs.min(), 200)
	assert_eq(costs.max(), 20000)


func test_every_spot_keeps_clear_of_the_roads_buildings_pens_and_people() -> void:
	for d: Dictionary in DecorScript.CATALOGUE:
		var p := _at(d)
		var clear := float(d.get("clear", 1.5))
		assert_gt(TerrainScript.path_distance(p), 1.6 + clear, "%s off the road" % d.id)
		for b: String in BUILDINGS:
			assert_gt(p.distance_to(BUILDINGS[b]), 6.0 + clear, "%s clear of the %s" % [d.id, b])
		for b: String in SMALL_THINGS:
			assert_gt(p.distance_to(SMALL_THINGS[b]), 1.5 + clear, "%s clear of the %s" % [d.id, b])
		for plot: Vector2 in PLOTS:
			assert_gt(p.distance_to(plot), 7.0 + clear, "%s clear of the pen plots" % d.id)
		for who: StringName in PeopleScript.SPOTS:
			var h: Vector3 = PeopleScript.SPOTS[who][0]
			assert_gt(p.distance_to(Vector2(h.x, h.z)), 1.5 + clear, "%s clear of %s's spot" % [d.id, who])
		for e: Dictionary in PropsScript.LAYOUT:
			assert_gt(p.distance_to(e.at), 1.2 + clear, "%s clear of the %s" % [d.id, e.file])
		for o: Dictionary in DecorScript.CATALOGUE:
			if o.id != d.id:
				assert_gt(p.distance_to(_at(o)), clear + float(o.get("clear", 1.5)), "%s clear of %s" % [d.id, o.id])


func test_buying_one_stands_it_and_it_is_not_sold_twice() -> void:
	var story := Story.new()
	assert_false(DecorScript.owns(story, &"well"))
	DecorScript.add(story, &"well")
	assert_true(DecorScript.owns(story, &"well"))
	DecorScript.add(story, &"well")
	assert_eq(DecorScript.owned(story).size(), 1, "one well, not two")


func test_what_she_owns_comes_back_with_the_save() -> void:
	var story := Story.new()
	DecorScript.add(story, &"chicken_coop")
	var back: Story = Story.from_dict(story.to_dict())
	assert_true(DecorScript.owns(back, &"chicken_coop"))


func test_the_layer_stands_what_she_owns_and_only_that() -> void:
	var story := Story.new()
	DecorScript.add(story, &"hay_bales")
	DecorScript.add(story, &"statue_fluttershy")
	var layer: Node3D = preload("res://world/decor_layer.gd").new()
	add_child_autofree(layer)
	layer.call("build", story)
	assert_not_null(layer.get_node_or_null(^"hay_bales"))
	assert_not_null(layer.get_node_or_null(^"statue_fluttershy"))
	assert_null(layer.get_node_or_null(^"well"))


func test_the_market_sells_each_decoration_as_decor() -> void:
	var reg := ShopRegistry.new()
	reg.load_all("res://data/shop")
	var n := 0
	for it: ShopItem in reg.all():
		if it.kind == ShopItem.Kind.DECOR:
			n += 1
			assert_false(DecorScript.find(it.decor_id).is_empty(), "%s is in the catalogue" % it.id)
	assert_eq(n, 12)
