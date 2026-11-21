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


## PLAYTEST 2026-11-10 ITEM 13: "i can walk through almost all props up here". Every piece of
## furniture stands on a solid box, and a pony-sized body walking at one is stopped by it.
func test_the_furniture_is_solid() -> void:
	var fi: Node3D = InteriorScript.new()
	add_child_autofree(fi)
	var solids := fi.find_children("Solid", "StaticBody3D", true, false)
	assert_gt(solids.size(), 15, "only %d solid pieces" % solids.size())
	await wait_physics_frames(2)
	var column: StaticBody3D = null
	for b in solids:
		if String(b.get_parent().name).begins_with("fx_column") or "column" in String(b.get_parent().scene_file_path):
			column = b
			break
	if column == null:
		column = solids[0]
	var walker := CharacterBody3D.new()
	var cap := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.42
	shape.height = 1.6
	cap.shape = shape
	walker.add_child(cap)
	walker.collision_mask = 0xFFFF
	add_child_autofree(walker)
	var at := (column.get_child(0) as CollisionShape3D).global_position
	walker.global_position = Vector3(at.x + 3.0, at.y, at.z)
	await wait_physics_frames(1)
	assert_true(walker.test_move(walker.global_transform, Vector3(-4.0, 0, 0)),
		"a body walking at %s passes through it" % column.get_parent().name)


## PRE-REVIEW 2026-11-21 ITEM 2: the camera, still in the last room as she walks through an
## arch, saw the arch's wall across half the screen. The wall between lens and player turns
## shadow-only, and comes back once both are on the same side.
func test_the_wall_between_the_lens_and_her_is_cut_away() -> void:
	var fi: Node3D = InteriorScript.new()
	add_child_autofree(fi)
	assert_gt(fi.divider_count(), 0)
	var half := InteriorScript.ROOM_SIZE * 0.5
	# Divider 0 is the landing's far wall, at z = -half. She is just through it, the lens 3 m behind.
	fi.cutaway(Vector3(0.7, 2.0, -half + 2.0), Vector3(0.0, 0.0, -half - 1.0))
	assert_true(fi.is_cut(0), "the arch wall between them is cut away")
	var tile: Node3D = fi.get_node("Rooms").get_child(0)
	var any_cut := false
	for m: GeometryInstance3D in fi.find_children("*", "GeometryInstance3D", true, false):
		if m.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			any_cut = true
	assert_true(any_cut, "its meshes still cast shadows but are not drawn")
	assert_not_null(tile)
	fi.cutaway(Vector3(0.7, 2.0, -half - 0.5), Vector3(0.0, 0.0, -half - 3.0))
	assert_false(fi.is_cut(0), "with both through, the wall is back")
	for m: GeometryInstance3D in fi.find_children("*", "GeometryInstance3D", true, false):
		assert_ne(m.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
