extends GutTest
## THE VENDOR AND THE TELLER: dressed pony bodies standing at a counter, and deliberately
## not ponies. Same construction as game/world/race_runner.gd and for the same reason: the
## project rule is that only Pony._state_leaving may free a pony, so anything standing in
## the world that is not part of the herd must not be one.

const AttendantScript := preload("res://world/attendant.gd")
const BuildingScript := preload("res://world/building.gd")
const RanchScene := preload("res://world/ranch.tscn")
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


# --- where she stands, on the shipped map (Ruling 29) ---------------------------------------

## THE STAGING FAULT THIS PINS. The door apron grew to 2.8 m and the attendants were standing
## in front of the door, so they were standing ON it. Measuring their standoff past the ramp's
## FOOT fixed the clipping and broke the staging: the Teller ended up 8.24 m from the Palace,
## outside PALACE_RADIUS, outside the marquee, outside the clear ground the Strip keeps around
## the building, and the Vendor 5.99 m from the Market, outside MARKET_RADIUS. Both read as
## stranded in the open rather than as staffing a door.
##
## THE ANSWER IS SIDEWAYS. She steps out from the wall and along it, into the strip of ground
## beside the doorway that the ramp does not cover, which is where a doorman stands anyway.
## The four claims below are the ones that make that a place rather than a coordinate: inside
## the radius that opens her building, outside the plinth, outside the apron, and short of the
## ramp's foot.
const ATTENDANTS := {
	"Vendor": {"building": ^"Buildings/Market", "radius": 6.0},  # ranch.gd MARKET_RADIUS (SCALE.md)
	"Teller": {"building": ^"Buildings/Palace", "radius": 6.0},
}


func _shipped_ranch() -> Node3D:
	var ranch: Node3D = RanchScene.instantiate()
	add_child_autofree(ranch)
	await get_tree().process_frame
	return ranch


## Her world position expressed in her building's own frame, which is the only frame the
## plinth and the apron are rectangles in: five of the six buildings on this map are turned,
## so a world axis box around either one is a looser shape than the shape itself.
func _local_spot(ranch: Node3D, who: String) -> Dictionary:
	var node := ranch.get_node_or_null(NodePath("Attendants/%s" % who)) as Node3D
	var building := ranch.get_node_or_null(ATTENDANTS[who]["building"]) as Building
	if node == null or building == null:
		return {}
	var flat := Vector3(node.global_position.x - building.global_position.x, 0.0,
		node.global_position.z - building.global_position.z)
	return {
		"building": building,
		"local": building.global_transform.basis.inverse() * flat,
		"gap": Vector2(flat.x, flat.z).length(),
	}


func test_both_attendants_stand_inside_the_radius_that_opens_their_building() -> void:
	var ranch: Node3D = await _shipped_ranch()
	for who: String in ATTENDANTS:
		var spot: Dictionary = _local_spot(ranch, who)
		assert_false(spot.is_empty(), "%s is standing somewhere" % who)
		if spot.is_empty():
			continue
		var radius: float = float(ATTENDANTS[who]["radius"])
		assert_lt(float(spot["gap"]), radius,
			"%s stands %.2f m out, past the %.1f m that opens her own counter: she reads as "
				% [who, float(spot["gap"]), radius] + "stranded in a field")


func test_neither_attendant_stands_on_the_plinth_or_on_the_ramp() -> void:
	var ranch: Node3D = await _shipped_ranch()
	for who: String in ATTENDANTS:
		var spot: Dictionary = _local_spot(ranch, who)
		if spot.is_empty():
			continue
		var b: Building = spot["building"]
		var local: Vector3 = spot["local"]
		# OUTSIDE THE PLINTH, and outside the wall standing on it: the plinth is inset behind
		# the wall plane, so the wall's own outer face at half the depth is the line to clear.
		assert_gt(local.z, b.depth * 0.5,
			"%s stands inside %s's own front wall" % [who, b.name])
		# OUTSIDE THE APRON. It is exactly door_width wide and centred, so clearing it is a
		# lateral claim; her collider is a capsule, so the edge has to be cleared by its
		# radius rather than merely touched.
		assert_gt(absf(local.x), b.door_width * 0.5 + AttendantScript.BODY_RADIUS,
			"%s is standing on %s's door ramp" % [who, b.name])
		# AND STILL BESIDE THE BUILDING rather than off its corner.
		assert_lt(absf(local.x), b.width * 0.5,
			"%s has stepped past the end of %s's front wall" % [who, b.name])


func test_neither_attendant_stands_past_the_foot_of_the_ramp() -> void:
	var ranch: Node3D = await _shipped_ranch()
	for who: String in ATTENDANTS:
		var spot: Dictionary = _local_spot(ranch, who)
		if spot.is_empty():
			continue
		var b: Building = spot["building"]
		assert_lt(float(spot["local"].z), b.apron_foot_z(),
			"%s stands further out than the ramp reaches, which is the fault this replaced"
				% who)


## HER COLLIDER, NOT HER ORIGIN. She is a capsule of Attendant.BODY_RADIUS and the wall she
## stands beside is solid, so a placement that put her origin outside it by less than that
## would leave her leaning through it.
func test_she_stands_clear_of_the_wall_by_her_own_width() -> void:
	var ranch: Node3D = await _shipped_ranch()
	for who: String in ATTENDANTS:
		var spot: Dictionary = _local_spot(ranch, who)
		if spot.is_empty():
			continue
		var b: Building = spot["building"]
		assert_gte(float(spot["local"].z) - b.depth * 0.5, AttendantScript.BODY_RADIUS,
			"%s is leaning through %s's front wall" % [who, b.name])


## NOT INSIDE ANY BUILDING ON THE MAP, not merely her own. The Market's Vendor put on the
## Market's own local plus X lands 0.28 m from Buildings/Board's plinth corner, which is
## inside her collider: she would be standing in the notice board's foundation. "Beside her
## own door" is not the same claim as "somewhere a body can stand", so both are made.
##
## Stated in each BUILDING's frame in turn, because five of the six are turned and a world
## axis box around a turned rectangle is a looser shape than the rectangle.
func test_neither_attendant_is_standing_inside_anything_on_the_map() -> void:
	var ranch: Node3D = await _shipped_ranch()
	var buildings := ranch.get_node_or_null(^"Buildings") as Node3D
	assert_not_null(buildings)
	for who: String in ATTENDANTS:
		var node := ranch.get_node_or_null(NodePath("Attendants/%s" % who)) as Node3D
		assert_not_null(node, "%s is standing somewhere" % who)
		if node == null:
			continue
		for child in buildings.get_children():
			var b := child as Building
			if b == null:
				continue
			var flat := Vector3(node.global_position.x - b.global_position.x, 0.0,
				node.global_position.z - b.global_position.z)
			var local: Vector3 = b.global_transform.basis.inverse() * flat
			var plinth_x: float = b.width * 0.5 - BuildingScript.PLINTH_INSET
			var plinth_z: float = b.depth * 0.5 - BuildingScript.PLINTH_INSET
			var r: float = AttendantScript.BODY_RADIUS
			assert_true(
				absf(local.x) > plinth_x + r or absf(local.z) > plinth_z + r,
				"%s is standing in %s's plinth (local %.2f, %.2f)"
					% [who, b.name, local.x, local.z])
			if b.door_width <= 0.001:
				continue
			# The apron: door_width wide, from the plinth's front face out to its foot.
			var on_apron: bool = absf(local.x) < b.door_width * 0.5 + r \
				and local.z > plinth_z - r and local.z < b.apron_foot_z() + r
			assert_false(on_apron, "%s is standing on %s's door ramp" % [who, b.name])


## THE CENSUS IS UNTOUCHED BY ALL OF THIS. She is under `Attendants`, which is neither
## `Props` nor `Buildings`, and moving her must not change that.
func test_moving_them_did_not_move_the_census() -> void:
	var ranch: Node3D = await _shipped_ranch()
	assert_eq(ranch.attendant_count(), 2, "two attendants, as the gate prints")
	var attendants := ranch.get_node_or_null(^"Attendants") as Node3D
	assert_not_null(attendants)
	assert_eq(attendants.get_child_count(), 2)
