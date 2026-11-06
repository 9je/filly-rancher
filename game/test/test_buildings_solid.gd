extends GutTest
## NOBODY GETS INSIDE A BUILDING (PT2; playtest 2026-11-05 items 31, 41, 43, 68). Every shell
## left its doorway open, so the player walked into the Depot's hollow model, it rained inside,
## she fell off its floor and could not get out; the camera followed her into the Market; a
## townspony stood half inside the Palace. No building on the map is entered on foot (the
## Palace's hall is its own room, reached by Ranch.enter_palace), so every doorway is sealed,
## and anybody who ends up inside a footprint anyway is set down outside the door.

const RanchScene := preload("res://world/ranch.tscn")
const LayersScript := preload("res://world/collision_layers.gd")


func _buildings(ranch: Node) -> Array[Building]:
	var out: Array[Building] = []
	for n: Node in ranch.find_children("*", "StaticBody3D", true, false):
		if n is Building:
			out.append(n)
	return out


func test_every_doorway_stops_a_walker() -> void:
	var ranch = RanchScene.instantiate()
	add_child_autofree(ranch)
	await wait_physics_frames(4)
	var bs := _buildings(ranch)
	assert_gt(bs.size(), 4, "the map's buildings were found")
	var space: PhysicsDirectSpaceState3D = ranch.get_world_3d().direct_space_state
	for b in bs:
		if b.door_width <= 0.001:
			continue
		# From the ramp's top, toward the middle of the room, at a pony's chest.
		var from: Vector3 = b.to_global(Vector3(0, Building.FLOOR_TOP + 1.0, b.depth * 0.5 + 0.6))
		var to: Vector3 = b.to_global(Vector3(0, Building.FLOOR_TOP + 1.0, 0))
		var q := PhysicsRayQueryParameters3D.create(from, to, LayersScript.PROPS)
		var hit := space.intersect_ray(q)
		assert_false(hit.is_empty(), "%s's doorway is shut to a walker" % b.name)
		if not hit.is_empty():
			assert_eq(hit.collider, b, "%s's own doorway stops her" % b.name)


func test_anyone_inside_a_building_is_set_down_outside_its_door() -> void:
	var ranch = RanchScene.instantiate()
	add_child_autofree(ranch)
	await wait_physics_frames(4)
	for b in _buildings(ranch):
		var inside: Vector3 = b.to_global(Vector3(0.3, Building.FLOOR_TOP, -0.2))
		assert_true(b.contains_point(inside), "%s knows its own middle" % b.name)
		var out: Vector3 = Building.rescue_point(inside)
		assert_ne(out, Vector3.INF, "%s offers a way out" % b.name)
		assert_false(b.contains_point(out), "%s's way out is outside it" % b.name)
		assert_lt(out.distance_to(b.global_position), maxf(b.width, b.depth) + 4.0,
			"%s's way out is beside it, not across the map" % b.name)
	assert_eq(Building.rescue_point(Vector3(5000, 0, 5000)), Vector3.INF, "open ground needs no rescue")


func test_the_player_put_inside_the_depot_is_out_within_a_second() -> void:
	var ranch = RanchScene.instantiate()
	add_child_autofree(ranch)
	await wait_physics_frames(4)
	var depot: Building = null
	for b in _buildings(ranch):
		if b.name == "Depot":
			depot = b
	assert_not_null(depot)
	var player: Node3D = ranch.player
	player.global_position = depot.to_global(Vector3(0, Building.FLOOR_TOP + 0.2, 0))
	await wait_physics_frames(75)
	assert_false(depot.contains_point(player.global_position), "she is outside the Depot again")


## THE LAKE IS WADED, NOT WALKED UNDER (item 61): a floor a little under every lake's surface,
## and water you cannot see the basin's grass through.
func test_every_lake_holds_a_walker_at_wading_depth() -> void:
	var ranch = RanchScene.instantiate()
	add_child_autofree(ranch)
	await wait_physics_frames(4)
	var space: PhysicsDirectSpaceState3D = ranch.get_world_3d().direct_space_state
	var lakes := 0
	for w: Node in ranch.find_children("Water_*", "MeshInstance3D", true, false):
		if not ((w as MeshInstance3D).mesh is CylinderMesh):
			continue
		lakes += 1
		var top: float = (w as Node3D).global_position.y
		var c: Vector3 = (w as Node3D).global_position
		var q := PhysicsRayQueryParameters3D.create(c + Vector3(0, 5, 0), c + Vector3(0, -20, 0),
			LayersScript.TERRAIN)
		var hit := space.intersect_ray(q)
		assert_false(hit.is_empty(), "%s has a floor" % w.name)
		if not hit.is_empty():
			var depth := top - float((hit.position as Vector3).y)
			assert_between(depth, 0.2, 0.5, "%s is waded knee deep (%.2f m), not over her head" % [w.name, depth])
		var mat := ((w as MeshInstance3D).mesh as CylinderMesh).material as ShaderMaterial
		assert_eq(float(mat.get_shader_parameter(&"opacity")), 1.0, "%s's water is not see-through" % w.name)
	assert_gt(lakes, 0, "the map has a lake to test")


## THE ORCHARD'S HAY, CRATES AND BASKETS ARE THINGS, NOT PICTURES (item 57: a pony spawned
## inside a haystack). Every whole prop scene in the regions taller than a pony's knee is solid
## where it stands, so nothing walks or spawns inside one.
func test_every_standing_region_prop_is_solid() -> void:
	var ranch = RanchScene.instantiate()
	add_child_autofree(ranch)
	await wait_physics_frames(4)
	var dressing: Node = ranch.find_child("Dressing", true, false)
	assert_not_null(dressing)
	var space: PhysicsDirectSpaceState3D = ranch.get_world_3d().direct_space_state
	var probe := SphereShape3D.new()
	probe.radius = 0.2
	var checked := 0
	for placed: Dictionary in dressing.get("placements"):
		var model := String(placed.model)
		if not (model in ["saa_hay_pile", "mlp_crate", "mlp_basket"]):
			continue
		var at: Vector3 = placed.at
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = probe
		q.transform = Transform3D(Basis(), at + Vector3(0, 0.3, 0))
		q.collision_mask = LayersScript.PROPS
		assert_false(space.intersect_shape(q, 1).is_empty(), "%s at %s is solid" % [model, at])
		checked += 1
	assert_gt(checked, 0, "the orchard's props were found")
