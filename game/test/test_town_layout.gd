extends GutTest
## THE PLAZA PLAN (P8 S7; playtest 2026-11-08 items 27, 42, 45, 52, 53, 55, 66). The town was
## crowded into thirty metres while the map round it stood empty. These hold the re-laid town to
## its promises on the booted ranch: the Market and the Depot face each other close across a
## paved plaza; the house and the pens stand out along their roads on level ground; one pen ends
## where the next begins; the request board is on its wall; the sighting trail goes through a
## gate; the lake's jetty is planks and its reeds are cards; the Market plays its own tune.

const RanchScene := preload("res://world/ranch.tscn")
const StreetScript := preload("res://world/street.gd")
const TerrainScript := preload("res://world/terrain.gd")
const PenScript := preload("res://world/pen.gd")
const MusicScript := preload("res://systems/music.gd")

var _ranch: Node = null


func before_all() -> void:
	_ranch = RanchScene.instantiate()
	add_child(_ranch)
	await wait_for_signal(_ranch.gate_report_finished, 180.0)


func after_all() -> void:
	if _ranch != null:
		_ranch.free()
		_ranch = null


func _door(who: String) -> Vector2:
	var b: Node3D = _ranch.get_node(NodePath("Buildings/" + who))
	var front: Vector3 = b.global_position + b.global_basis.z * (float(b.get("depth")) * 0.5)
	return Vector2(front.x, front.z)


func test_the_market_and_the_depot_face_each_other_close_across_the_plaza() -> void:
	var m := _door("Market")
	var d := _door("Depot")
	assert_lt(m.distance_to(d), 22.0, "the owner: Market to Depot far would be annoying")
	var plaza: Vector2 = StreetScript.PLAZA_CENTRE
	assert_lt(plaza.distance_to((m + d) * 0.5), 1.0, "the plaza is between their doors")
	var mb: Node3D = _ranch.get_node(^"Buildings/Market")
	var db: Node3D = _ranch.get_node(^"Buildings/Depot")
	assert_lt(mb.global_basis.z.dot(db.global_basis.z), -0.99, "facing each other")
	assert_not_null(_ranch.get_node_or_null(^"Street/PlazaPaving"), "the plaza is paved")
	assert_not_null(_ranch.get_node_or_null(^"Street/PlazaKerb"), "and kerbed")


func test_the_house_and_the_pens_stand_out_on_level_ground() -> void:
	var plaza: Vector2 = StreetScript.PLAZA_CENTRE
	var terrain: Node = _ranch.get("terrain")
	for who: String in ["Farmhouse", "Barn"]:
		var b: Node3D = _ranch.get_node(NodePath("Buildings/" + who))
		var at := Vector2(b.global_position.x, b.global_position.z)
		assert_gt(at.distance_to(plaza), 25.0, "%s out of the plaza" % who)
		var lo := INF
		var hi := -INF
		for dx: float in [-8.0, 0.0, 8.0]:
			for dz: float in [-5.0, 0.0, 5.0]:
				var h := float(terrain.call("height_at", at.x + dx, at.y + dz))
				lo = minf(lo, h)
				hi = maxf(hi, h)
		assert_lt(hi - lo, 0.05, "%s stands on level ground (item 52)" % who)
	for slot: Node3D in _ranch.call("plot_slots"):
		var p := Vector2(slot.global_position.x, slot.global_position.z)
		assert_gt(p.distance_to(plaza), 22.0, "%s out of the plaza" % slot.name)
		var h0 := float(terrain.call("height_at", p.x - 3.9, p.y - 3.9))
		var h1 := float(terrain.call("height_at", p.x + 3.9, p.y + 3.9))
		assert_lt(absf(h1 - h0), 0.05, "%s is level" % slot.name)


func test_one_pen_ends_before_the_next_begins() -> void:
	var slots: Array = _ranch.call("plot_slots")
	for i in slots.size():
		for j in range(i + 1, slots.size()):
			var a: Node3D = slots[i]
			var b: Node3D = slots[j]
			var gap: float = maxf(absf(a.global_position.x - b.global_position.x),
				absf(a.global_position.z - b.global_position.z)) - PenScript.HALF_EXTENT * 2.0
			assert_gt(gap, 3.5, "a walk between %s and %s (item 53)" % [a.name, b.name])


func test_a_pen_has_a_floor_and_taller_corner_posts() -> void:
	var pen: Node3D = (load("res://world/pen.tscn") as PackedScene).instantiate()
	add_child_autofree(pen)
	assert_not_null(pen.get_node_or_null(^"PenFloor"), "trodden earth inside the fence")
	var corner := pen.get_node_or_null(^"Side0Post390") as MeshInstance3D
	var middle := pen.get_node_or_null(^"Side1Post0") as MeshInstance3D
	assert_not_null(corner)
	assert_not_null(middle)
	if corner != null and middle != null:
		assert_gt(corner.get_aabb().size.y, middle.get_aabb().size.y, "the corners stand taller")


func test_the_request_board_hangs_on_its_wall_and_is_its_only_sign() -> void:
	var board: Node3D = _ranch.get_node(^"Buildings/Board")
	var panel := board.get_node_or_null(^"RequestBoard") as Node3D
	assert_not_null(panel)
	if panel != null:
		assert_lt(panel.position.z - float(board.get("depth")) * 0.5, 0.1, "flat to the wall (item 45)")
	assert_null(_ranch.get_node_or_null(^"SignRequests"), "no second sign in front of it")


func test_the_trail_goes_through_the_gate_not_over_the_fence() -> void:
	var fence: Node = null
	for f: Node in _ranch.call("get_region_fences"):
		if String(f.call("region").id) == "nightmeadow":
			fence = f
	assert_not_null(fence)
	if fence == null:
		return
	var c: Vector2 = fence.call("region").centre
	var inside := Vector3(c.x, 0.0, c.y)
	var gate: Vector3 = fence.call("gate_point", 0.0)
	# From the far side of the ring: to the gate first, on her side of it.
	var out_dir := (Vector2(c.x, c.y) - Vector2(gate.x, gate.z)).normalized()
	var far := c + out_dir * (float(fence.call("ring_radius")) + 8.0)
	var aim: Vector3 = _ranch.call("walkable_aim", Vector3(far.x, 0.0, far.y), inside)
	assert_almost_eq(aim.distance_to(fence.call("gate_point", 2.5)), 0.0, 0.01, "to the gate (item 27)")
	# At the gate: through it.
	aim = _ranch.call("walkable_aim", fence.call("gate_point", 1.0), inside)
	assert_almost_eq(aim.distance_to(fence.call("gate_point", -2.5)), 0.0, 0.01, "then through it")
	# Inside: straight at the goal.
	aim = _ranch.call("walkable_aim", fence.call("gate_point", -3.0), inside)
	assert_eq(aim, inside, "and on to the goal")


func test_the_lake_has_a_plank_jetty_and_reed_cards() -> void:
	var dressing := _ranch.get_node_or_null(^"Regions/Dressing")
	assert_not_null(dressing)
	if dressing == null:
		return
	var models := {}
	for c: Node in dressing.get_children():
		if c is MultiMeshInstance3D:
			models[String(c.get_meta(&"dress_model", ""))] = (c as MultiMeshInstance3D).multimesh.instance_count
	assert_gt(int(models.get("reed_card", 0)), 50, "reeds as card clumps (item 55)")
	assert_gt(int(models.get("path_wood", 0)), 15, "a jetty of planks across it")
	assert_false(models.has("plant_flatTall"), "no blown-up shard plants on the shore")


func test_the_market_plays_its_own_tune() -> void:
	for ctx: StringName in [&"market", &"depot", &"town"]:
		assert_eq(String(MusicScript.TRACKS[ctx]), "res://assets/audio/music/market_stalls.ogg",
			"%s: not the stock track (item 66)" % ctx)
	assert_true(ResourceLoader.exists("res://assets/audio/music/market_stalls.ogg"))
