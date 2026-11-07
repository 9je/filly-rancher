extends GutTest
## A STREET AND YARDS IN THE TOWN ROW (PS4 item 36; playtest 2026-11-05: "Ponyville row: ... no
## streets or yards, grey road meets dirt road badly" [33]). On the booted ranch: the road
## through the row is paved from a kerb across it; every row house has a fenced yard whose
## gate opens at its door; the fences are SCALE.md fence height.

const RanchScene := preload("res://world/ranch.tscn")
const StreetScript := preload("res://world/street.gd")
const TerrainScript := preload("res://world/terrain.gd")
const PH := 2.19

var _ranch: Node = null


func before_all() -> void:
	_ranch = RanchScene.instantiate()
	add_child(_ranch)
	await wait_for_signal(_ranch.gate_report_finished, 180.0)


func after_all() -> void:
	if _ranch != null:
		_ranch.free()
		_ranch = null


func _street() -> Node:
	return _ranch.get_node_or_null(^"Street")


func test_the_row_has_a_paved_street_from_a_kerb() -> void:
	var street := _street()
	assert_not_null(street, "the town row has a street")
	if street == null:
		return
	for part in ["Paving", "Kerb", "YardFences"]:
		var mi := street.get_node_or_null(NodePath(part)) as MeshInstance3D
		assert_true(mi != null and mi.mesh != null and mi.mesh.get_surface_count() > 0, "%s is laid" % part)
	assert_gte(StreetScript.HALF_WIDTH * 2.0, TerrainScript.PATH_HALF_WIDTH * 2.0,
		"the paving covers the dirt road it replaces")
	assert_gt(StreetScript.TO_Z, TerrainScript.STRIP_EDGE_Z - 1.0, "and runs on into the Strip's paving")


func test_every_row_house_has_a_yard_gated_at_its_door() -> void:
	var street := _street()
	if street == null:
		fail_test("no street")
		return
	var yards: Array = street.call("yards")
	assert_eq(yards.size(), 4, "the four row houses")
	for y: Dictionary in yards:
		var gate := Vector2(float(y.fence_x), (y.door as Vector2).y)
		assert_between((y.door as Vector2).y, float(y.z0), float(y.z1), "%s's door is along its front" % y.house)
		for run: Array in y.runs:
			var a: Vector2 = run[0]
			var b: Vector2 = run[1]
			var t := clampf((gate - a).dot(b - a) / maxf((b - a).length_squared(), 1e-6), 0.0, 1.0)
			assert_gt(gate.distance_to(a + (b - a) * t), 0.8, "%s: no fence across the gate" % y.house)


func test_the_yard_fences_are_fence_height() -> void:
	assert_between(StreetScript.FENCE_HEIGHT / PH, 0.4, 1.3, "SCALE.md's fence row")


## THE GREY ROAD MEETS THE DIRT ROAD CLEANLY. The Strip's paving was a grid of 1.5 m squares
## cut at a circle, so its rim, the edge the road runs into, was a staircase. Its rim squares
## are trimmed to the circle now: no vertex outside it, and vertices ON it all the way round.
func test_the_strips_paving_ends_in_a_circle_not_a_staircase() -> void:
	var paving := _ranch.get_node_or_null(^"Strip/Paving") as MeshInstance3D
	assert_not_null(paving)
	if paving == null:
		return
	var region: RegionData = _ranch.call("_regions_registry").by_id(&"strip")
	var c := region.centre
	var r: float = region.radius * 0.97
	var verts: PackedVector3Array = paving.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var worst := 0.0
	var on_rim := {}
	for v: Vector3 in verts:
		var d := Vector2(v.x, v.z).distance_to(c)
		worst = maxf(worst, d - r)
		if absf(d - r) < 0.02:
			on_rim[int(round(rad_to_deg(Vector2(v.x, v.z).angle_to_point(c))))] = true
	assert_lt(worst, 0.02, "nothing past the circle (worst %.2f m)" % worst)
	assert_gt(on_rim.size(), 200, "the rim is traced round the circle, %d whole degrees of it" % on_rim.size())
