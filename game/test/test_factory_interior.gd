extends GutTest
## The Factory interior's layout (game/world/factory_interior.gd): the processing hall the
## gallery window looks onto must not sit inside another room (it once overlapped the
## holding room, so the window looked into holding instead of at the ring).

const InteriorScript := preload("res://world/factory_interior.gd")


func test_the_processing_hall_is_clear_of_every_room() -> void:
	var fi: Node3D = InteriorScript.new()
	add_child_autofree(fi)
	var hall := fi.get_node("Rooms/gallery/ProcessingFloor") as Node3D
	assert_not_null(hall)
	var c := hall.global_position
	var half := InteriorScript.ROOM_SIZE * 0.5
	for room_name in fi.rooms:
		var r := (fi.rooms[room_name] as Node3D).global_position
		# The hall is 16 m square around its centre; a room is ROOM_SIZE square. Clear means
		# their footprints are apart on at least one axis.
		var apart_x := absf(c.x - r.x) >= half + 8.0 - 1.0
		var apart_z := absf(c.z - r.z) >= half + 8.0
		assert_true(apart_x or apart_z, "the hall overlaps %s" % room_name)
	assert_lt(c.y, 0.0, "the hall is below the gallery floor")
