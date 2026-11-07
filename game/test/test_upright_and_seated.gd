extends GutTest
## UPRIGHT AND ON THE GROUND (PS4 items 36 and 37; playtest 2026-11-05: "houses lean and sink
## into the slope, lamp posts lean" [33], "the Strip: tilted arcade machines on a grey slab, a
## floating track, leaning lamps" [34]). On the booted ranch every building, every placed prop
## (the Strip's cabinets and the town row among them) and every Strip lamp stands within 2
## degrees of plumb, and the race track's surface lies on the ground it is drawn over.

const RanchScene := preload("res://world/ranch.tscn")
const PLUMB_DEG := 2.0

var _ranch: Node = null


func before_all() -> void:
	_ranch = RanchScene.instantiate()
	add_child(_ranch)
	await wait_for_signal(_ranch.gate_report_finished, 180.0)


func after_all() -> void:
	if _ranch != null:
		_ranch.free()
		_ranch = null


func _lean_deg(n: Node3D) -> float:
	return rad_to_deg(n.global_basis.y.normalized().angle_to(Vector3.UP))


func test_buildings_props_and_lamps_stand_plumb() -> void:
	var things: Array[Node3D] = []
	for b in _ranch.get_node(^"Buildings").get_children():
		if b is Node3D:
			things.append(b)
	for p: Node3D in _ranch.get("props").call("get_placed"):
		things.append(p)
	var lamps := 0
	for s in _ranch.get_node(^"Strip").get_children():
		if String(s.name).begins_with("Lamp") and s is Node3D:
			things.append(s)
			lamps += 1
	assert_gt(lamps, 4, "the Strip's lamps are checked")
	var bad: Array[String] = []
	for n: Node3D in things:
		var lean := _lean_deg(n)
		if lean > PLUMB_DEG:
			bad.append("%s leans %.1f degrees" % [n.name, lean])
	assert_true(bad.is_empty(), "got " + " | ".join(bad))


func test_the_race_track_lies_on_the_ground() -> void:
	var dirt := _ranch.get_node_or_null(^"Strip/Track/Dirt") as MeshInstance3D
	assert_not_null(dirt, "the track's surface")
	if dirt == null:
		return
	var terrain: Node = _ranch.get("terrain")
	var worst := 0.0
	for v: Vector3 in dirt.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		var w: Vector3 = dirt.global_transform * v
		worst = maxf(worst, absf(w.y - float(terrain.call("height_at", w.x, w.z))))
	assert_lt(worst, 0.12, "no corner of the track stands off the ground (worst %.2f m)" % worst)
