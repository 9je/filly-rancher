extends GutTest
## THE VENDOR AND THE TELLER: dressed pony bodies standing at a counter, and deliberately
## not ponies. Same construction as game/world/race_runner.gd and for the same reason: the
## project rule is that only Pony._state_leaving may free a pony, so anything standing in
## the world that is not part of the herd must not be one.

const AttendantScript := preload("res://world/attendant.gd")
const PonyScript := preload("res://actors/pony/pony.gd")
const PonyRegistryScript := preload("res://systems/pony_registry.gd")
const StockPaletteScript := preload("res://systems/stock_palette.gd")
const StockTintScript := preload("res://systems/stock_tint.gd")
const LayersScript := preload("res://world/collision_layers.gd")

const LOOK := {"coat": 2, "mane": 5, "eyes": 1, "mane_style": 1}

var _who: Attendant = null


func before_each() -> void:
	_who = AttendantScript.new()
	add_child_autofree(_who)


func _record() -> PonyData:
	var registry := PonyRegistryScript.new()
	registry.load_all("res://data/ponies")
	return registry.by_id(StockPaletteScript.IDS[1])


func test_she_is_a_body_and_never_a_pony() -> void:
	# is_instance_of() rather than `_who is PonyScript`, matching test_race_runner.gd's own
	# fix: Attendant (StaticBody3D) and Pony (CharacterBody3D) share no ancestor/descendant
	# relation, so GDScript's static analyzer proves the `is` form always false and refuses
	# to parse it as a Parse Error. The runtime check says exactly the same thing without
	# tripping that.
	assert_false(is_instance_of(_who, PonyScript),
		"nothing standing at a counter may be something the herd counts or the beam takes")
	assert_true(_who is StaticBody3D)


func test_she_blocks_the_player_and_offers_the_beam_nothing() -> void:
	assert_eq(_who.collision_layer, LayersScript.PROPS,
		"she is scenery you cannot walk through, on the layer scenery lives on")
	assert_eq(_who.collision_mask, 0, "she is not looking for anything")


func test_dressing_her_builds_a_body_tinted_from_her_own_look() -> void:
	var data: PonyData = _record()
	if data == null or not ResourceLoader.exists(StockPaletteScript.mane_style_path(1)):
		pass_test("no converted assets on this machine")
		return
	assert_true(_who.dress(data, LOOK, Vector3.FORWARD))
	assert_true(_who.has_model())
	var body: Node3D = _who.get_child(0)
	assert_not_null(StockTintScript.override_of(body, &"body"),
		"she goes through the same one recolour pipeline the crowd does")


func test_dressing_her_twice_replaces_the_body_rather_than_stacking_two() -> void:
	var data: PonyData = _record()
	if data == null or not ResourceLoader.exists(StockPaletteScript.mane_style_path(1)):
		pass_test("no converted assets on this machine")
		return
	_who.dress(data, LOOK, Vector3.FORWARD)
	_who.dress(data, LOOK, Vector3.BACK)
	var bodies := 0
	for child in _who.get_children():
		if child is Node3D and not (child is CollisionShape3D):
			bodies += 1
	assert_eq(bodies, 1, "one attendant, one body")


func test_she_faces_where_she_is_told() -> void:
	var data: PonyData = _record()
	if data == null or not ResourceLoader.exists(StockPaletteScript.mane_style_path(1)):
		pass_test("no converted assets on this machine")
		return
	_who.dress(data, LOOK, Vector3(1.0, 0.0, 0.0))
	assert_almost_eq(_who.facing().dot(Vector3(1.0, 0.0, 0.0)), 1.0, 0.01)


func test_a_facing_of_nowhere_leaves_her_where_she_was_rather_than_erroring() -> void:
	var data: PonyData = _record()
	if data == null or not ResourceLoader.exists(StockPaletteScript.mane_style_path(1)):
		pass_test("no converted assets on this machine")
		return
	var before: float = _who.rotation.y
	_who.dress(data, LOOK, Vector3.ZERO)
	assert_almost_eq(_who.rotation.y, before, 0.0001)


func test_a_null_record_is_refused_and_leaves_no_body() -> void:
	assert_false(_who.dress(null, LOOK, Vector3.FORWARD))
	assert_false(_who.has_model())
