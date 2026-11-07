extends GutTest
## THE PALACE IS ALIVE (PS5, playtest 2026-11-05 item 44: "Casino patrons frozen in place"
## [38]). The hall's staff and regulars each run a routine of clips (a look round, a nod, a
## laugh, a word, a shake of the head) on their own staggered timing, and the regulars at the
## slots move to a free machine in their row every 30 to 90 s. The machines a regular is at are
## never offered to the player.
##
## Two minutes of the hall are stepped through tick() rather than waited out.

const PalaceInteriorScript := preload("res://world/palace_interior.gd")

var _hall: Node3D = null


func before_all() -> void:
	_hall = PalaceInteriorScript.new()
	add_child(_hall)
	_hall.call("build")


func after_all() -> void:
	if _hall != null:
		_hall.free()
		_hall = null


func _regulars() -> Array[Node]:
	var out: Array[Node] = []
	for n in _hall.get_node(^"Staff").get_children():
		if String(n.name).begins_with("Regular"):
			out.append(n)
	return out


func test_every_patron_acts_and_a_slot_regular_changes_machine() -> void:
	var regulars := _regulars()
	assert_gte(regulars.size(), 4, "regulars stand in the hall")
	var start_taken: Array = (_hall.call("slots_taken") as Array).duplicate()
	var moved := false
	for step in 1200:
		_hall.call("tick_patrons", 0.1)
		if (_hall.call("slots_taken") as Array) != start_taken:
			moved = true
	for r: Node in regulars:
		assert_gte(int(r.call("clips_started")), 3, "%s did something at least three times in two minutes" % r.name)
	for staff: Node in _hall.get_node(^"Staff").get_children():
		assert_gte(int(staff.call("clips_started")), 2, "%s is not a statue either" % staff.name)
	assert_true(moved, "a slot regular moved to another machine")


func test_a_machine_a_regular_is_at_is_never_offered() -> void:
	for step in 600:
		_hall.call("tick_patrons", 0.1)
		var taken: Array = _hall.call("slots_taken")
		var offered: Array = _hall.call("station_points", &"slots")
		for i: int in taken:
			var row: Array = PalaceInteriorScript.SLOT_ROW[i]
			var at := Vector3(float(row[0]), 0.0, float(row[1]))
			for p: Vector3 in offered:
				assert_gt(_hall.to_local(p).distance_to(at), 1.0, "machine %d is a regular's" % i)
				if _hall.to_local(p).distance_to(at) <= 1.0:
					return
