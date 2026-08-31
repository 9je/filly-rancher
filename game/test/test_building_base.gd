extends GutTest
## THE PLINTH UNDER EVERY BUILDING ON THE MAP, against the real terrain.
##
## THE BUG: the shipped Floor slab was 0.14 m thick with its bottom face at exactly local
## y = 0, and Props.seat() drops a building by the ground height at ONE point. The ground
## under Buildings/Palace SPANS 1.264 m across its 14 by 9 m footprint (measured), so it
## crossed that 0.14 m floor and the two surfaces fought for the same pixels. The owner,
## 2026-08-31: "z fighting at the palace base, a flickering skirt where the building meets
## terrain".
##
## 1.264 IS THE SPAN. 0.633 IS THE HALF SPAN, and the two are not interchangeable. The
## number ranch.gd's PALACE_MAX_RELIEF is written against is the largest DEVIATION of a
## corner from the height under the building's own centre, which is half of the lowest to
## highest distance the plinth actually has to bridge. Every check in this file is stated
## against the SPAN, because that is the thing a plinth is deep enough for or is not.
##
## THE INVARIANT WITH TEETH is stated per building rather than for the Palace alone: the
## plinth's top must clear the HIGHEST ground under the footprint and its bottom must sit
## below the LOWEST, both with margin. A building that satisfies that cannot fight the
## terrain no matter what relief it is standing on.

const BuildingScript := preload("res://world/building.gd")
const TerrainScript := preload("res://world/terrain.gd")
const PropsScript := preload("res://world/props.gd")
const RanchScene := preload("res://world/ranch.tscn")

## Metres of clear air demanded on each side of the ground, on top of the relief itself.
## Bigger than Props.SINK_BIAS (0.05) so a passing check is a real gap rather than a
## rounding accident.
const MARGIN := 0.15

## LOWEST TO HIGHEST under the Palace's own 14 by 9 m footprint, sampled at the same nine
## points Building.footprint_relief() walks. Measured, 2026-08-31: lowest 1.073, highest
## 2.337. See the class comment for why this is not 0.633.
const PALACE_SPAN := 1.264


## THE REAL INVARIANT, RESTATED. This test used to read `FLOOR_TOP > 0.633 + MARGIN`, which
## compared the plinth's own top against a HALF span as if it were the span, and it passed
## for the wrong reason: the height available to bridge the ground is not FLOOR_TOP at all.
## ranch.gd seats a building against its LOWEST corner, so local y = 0 comes to rest
## GROUND_DROP above that corner and the plinth's top stands FLOOR_TOP + GROUND_DROP over
## it. THAT is the number the lowest to highest span has to fit inside, with margin.
func test_the_plinth_bridges_the_worst_span_on_the_map() -> void:
	var headroom: float = BuildingScript.FLOOR_TOP + BuildingScript.GROUND_DROP
	assert_gt(headroom, PALACE_SPAN + MARGIN,
		"a plinth top standing %.3f m over the lowest corner must clear the %.3f m span "
		% [headroom, PALACE_SPAN] + "measured under the Palace")
	# The other half of the same seating arithmetic: the skirt's underside sits
	# SEAT_CLEARANCE + SINK_BIAS below the lowest corner, and that gap is what stops an
	# uphill corner showing daylight under the building.
	assert_gt(BuildingScript.SEAT_CLEARANCE + PropsScript.SINK_BIAS, MARGIN,
		"the skirt's underside must clear the lowest corner by more than a rounding error")
	assert_gt(BuildingScript.SKIRT_DEPTH, BuildingScript.FLOOR_TOP,
		"the plinth reaches further below the origin than above it, or an uphill corner "
		+ "shows daylight underneath")


func test_a_built_shell_has_its_floor_where_the_constants_say() -> void:
	var b: Building = BuildingScript.new()
	b.width = 6.0
	b.depth = 4.0
	add_child_autofree(b)
	b.build()
	var floor_node := b.get_node_or_null(^"Floor") as MeshInstance3D
	assert_not_null(floor_node, "every building lays a Floor slab")
	var box: BoxMesh = floor_node.mesh
	assert_almost_eq(floor_node.position.y + box.size.y * 0.5, BuildingScript.FLOOR_TOP,
		0.0001, "the top of the plinth is FLOOR_TOP above the origin")
	assert_almost_eq(floor_node.position.y - box.size.y * 0.5, -BuildingScript.SKIRT_DEPTH,
		0.0001, "and the bottom is SKIRT_DEPTH below it")


## THE STRIPING FROM THE 2026-08-31 REVIEW (Ruling 22, round 1): the plinth's outer face
## and the wall standing on it were exactly coplanar over y in [0, FLOOR_TOP], which is two
## opaque faces fighting for the same pixels the whole height of the step. The plinth must
## sit strictly behind the wall plane on every side, not just close to it, or a future edit
## that shaves PLINTH_INSET back toward zero could reintroduce the exact same flicker
## without a single test noticing.
func test_the_plinth_sits_inset_behind_every_wall_plane() -> void:
	var b: Building = BuildingScript.new()
	b.width = 6.0
	b.depth = 4.0
	add_child_autofree(b)
	b.build()
	var floor_node := b.get_node_or_null(^"Floor") as MeshInstance3D
	var box: BoxMesh = floor_node.mesh
	assert_gt(BuildingScript.PLINTH_INSET, 0.0, "there is a real inset, not a zero one")
	assert_lt(box.size.x, b.width, "the plinth's outer face on x sits strictly inside the "
		+ "wall plane -- flush is what striped")
	assert_lt(box.size.z, b.depth, "the plinth's outer face on z sits strictly inside the "
		+ "wall plane -- flush is what striped")
	assert_almost_eq(box.size.x, b.width - BuildingScript.PLINTH_INSET * 2.0, 0.0001,
		"the inset is exactly PLINTH_INSET on both x faces")
	assert_almost_eq(box.size.z, b.depth - BuildingScript.PLINTH_INSET * 2.0, 0.0001,
		"the inset is exactly PLINTH_INSET on both z faces")


## THE FOLDED FIX FROM THE SAME REVIEW (Ruling 22): the plinth is one solid slab across the
## whole footprint, door gap or not, so raising it to FLOOR_TOP turned every doorway into a
## sheer, unmarked step. A leaning box, built the same way the roof already is, standing in
## for a ramp -- and a slope test is the only way "it exists" and "it is a ladder, not a
## ramp" stay two different failures.
##
## AND THE FIRST APRON BOUGHT NOTHING, which is what the whole-branch review of 2026-08-31
## found: it climbed from local y = 0 INWARD to FLOOR_TOP, and both of those numbers are
## inside the solid plinth. The doorway stayed a 1.80 m sheer step on all six buildings and
## the only part of the apron anybody could ever see was a 5 cm lip through the interior
## floor. Sizes and slopes all passed, because nothing asked WHERE the box was. Everything
## below asks where.
func test_the_door_gets_an_apron_down_from_the_interior_floor() -> void:
	var b: Building = BuildingScript.new()
	b.width = 6.0
	b.depth = 4.0
	b.door_width = 2.8
	add_child_autofree(b)
	b.build()
	var apron := b.get_node_or_null(^"DoorApron") as MeshInstance3D
	assert_not_null(apron, "every doorway gets a way down from the interior floor")
	var box: BoxMesh = apron.mesh
	assert_almost_eq(box.size.x, b.door_width, 0.0001, "the apron is exactly door_width wide")
	# Undo the rotation to recover the apron's own rise and run: box.size.z is the
	# hypotenuse (the leaning box's long axis), so this is the same decomposition build()
	# used to size it in the first place.
	var rise: float = box.size.z * sin(apron.rotation.x)
	var run: float = box.size.z * cos(apron.rotation.x)
	assert_almost_eq(rise, BuildingScript.FLOOR_TOP + BuildingScript.GROUND_DROP, 0.01,
		"the apron climbs from the ground the building was seated against, not from local "
		+ "y = 0, which is buried GROUND_DROP inside the plinth")
	assert_gt(run, 0.5, "a run this short reads as a ladder, not a ramp")
	var angle_deg: float = rad_to_deg(apron.rotation.x)
	assert_gt(angle_deg, 10.0, "too shallow to read as a ramp rather than flat ground")
	assert_lt(angle_deg, 60.0, "too steep to read as a ramp rather than a wall")


## THE APRON IS OUTSIDE THE PLINTH AND UNDER ITS TOP, in the building's own basis. Both
## halves are what the entombed first version failed.
##
## WHY THE XZ HALF IS CHECKED IN THE BUILDING'S OWN FRAME rather than against a world AABB:
## five of the six buildings on this map are turned, and the world AABB of a turned
## rectangle is a LOOSER box than the rectangle. Escaping the true footprint is the property
## that matters, and it is exactly what the local frame states.
func _apron_corners_local(b: Building) -> Array[Vector3]:
	var apron := b.get_node_or_null(^"DoorApron") as MeshInstance3D
	var out: Array[Vector3] = []
	if apron == null:
		return out
	var box: BoxMesh = apron.mesh
	var h: Vector3 = box.size * 0.5
	for sx: float in [-h.x, h.x]:
		for sy: float in [-h.y, h.y]:
			for sz: float in [-h.z, h.z]:
				out.append(apron.transform * Vector3(sx, sy, sz))
	return out


func test_the_apron_starts_at_the_plinths_front_face_and_runs_out_and_down() -> void:
	var b: Building = BuildingScript.new()
	b.width = 6.0
	b.depth = 4.0
	b.door_width = 2.8
	add_child_autofree(b)
	b.build()
	var corners: Array[Vector3] = _apron_corners_local(b)
	assert_eq(corners.size(), 8, "the apron is one box")
	var front_z: float = b.depth * 0.5 - BuildingScript.PLINTH_INSET
	var lowest := INF
	var furthest := -INF
	for c: Vector3 in corners:
		lowest = minf(lowest, c.y)
		furthest = maxf(furthest, c.z)
	assert_lt(lowest, -BuildingScript.GROUND_DROP + 0.001,
		"the apron's foot reaches the ground the building was seated against")
	assert_gt(furthest, front_z + BuildingScript.DOOR_APRON_RUN * 0.9,
		"the apron runs OUT past the plinth's front face, not in under the floor")
	# THE 5 CM LIP, MADE IMPOSSIBLE RATHER THAN TOLERATED. Nothing belonging to the apron may
	# be both above the boards and inside the footprint they cover; the top face descends
	# with z, so its highest point at z <= front_z is a corner, and no corner is up there.
	for c: Vector3 in corners:
		if c.y > BuildingScript.FLOOR_TOP + 0.001:
			assert_gt(c.z, front_z - 0.001,
				"an apron corner at y=%.3f sits above the boards and inside the plinth: "
					% c.y + "that is the lip that poked through the interior floor")


## A BUILDING WITH NO DOOR GETS NO APRON. Buildings/Board is a notice board built out of the
## same script with door_width 0, and a ramp leaning on a solid block would read as a bug.
func test_a_building_with_no_doorway_stands_no_apron() -> void:
	var b: Building = BuildingScript.new()
	b.width = 3.0
	b.depth = 1.2
	b.door_width = 0.0
	add_child_autofree(b)
	b.build()
	assert_null(b.get_node_or_null(^"DoorApron"),
		"a wall with no gap in it has nothing to climb to")


## EVERY BUILDING IN ranch.tscn, ON THE REAL TERRAIN, at the four corners of its own
## footprint and at its centre. This is the check that answers "does any other building
## show it", which no amount of staring at the Palace can.
func test_no_building_on_the_shipped_map_can_fight_the_ground() -> void:
	var ranch: Node3D = RanchScene.instantiate()
	add_child_autofree(ranch)
	await get_tree().process_frame
	var terrain := ranch.get_node_or_null(^"Terrain") as Terrain
	var buildings := ranch.get_node_or_null(^"Buildings") as Node3D
	assert_not_null(terrain)
	assert_not_null(buildings)
	for child in buildings.get_children():
		var b := child as Building
		if b == null:
			continue
		var origin: Vector3 = b.global_position
		var half := Vector2(b.width * 0.5, b.depth * 0.5)
		var lowest := INF
		var highest := -INF
		for dx: float in [-half.x, 0.0, half.x]:
			for dz: float in [-half.y, 0.0, half.y]:
				# The footprint is turned with the building, so the corner offsets go
				# through its own basis rather than being added in world axes.
				var corner: Vector3 = origin + b.global_transform.basis * Vector3(dx, 0.0, dz)
				var h: float = terrain.height_at(corner.x, corner.z)
				lowest = minf(lowest, h)
				highest = maxf(highest, h)
		var top: float = origin.y + BuildingScript.FLOOR_TOP
		var bottom: float = origin.y - BuildingScript.SKIRT_DEPTH
		assert_gt(top, highest + MARGIN,
			"%s: the plinth top (%.3f) does not clear the highest ground under it (%.3f)"
				% [b.name, top, highest])
		assert_lt(bottom, lowest - MARGIN,
			"%s: the plinth bottom (%.3f) does not reach below the lowest ground (%.3f)"
				% [b.name, bottom, lowest])


## EVERY DOORWAY ON THE SHIPPED MAP, WHERE ITS APRON ACTUALLY IS. Walked the same way the
## plinth check above walks the live scene, because "the apron exists and its slope is
## sensible" is exactly what the entombed version passed: all six aprons were inside the
## solid plinth, and the six doorways were still 1.80 m sheer steps.
##
## THE TWO ASSERTIONS THE OLD TEST LACKED, per building:
##   1. the apron's world AABB reaches BELOW the plinth's top, and all the way down to the
##      ground the building was seated against;
##   2. it reaches OUTSIDE the plinth's own XZ footprint, stated in the building's basis
##      (see _apron_corners_local() for why a world AABB is the wrong box for a turned
##      building).
func test_no_doorway_on_the_shipped_map_is_still_a_sheer_step() -> void:
	var ranch: Node3D = RanchScene.instantiate()
	add_child_autofree(ranch)
	await get_tree().process_frame
	var terrain := ranch.get_node_or_null(^"Terrain") as Terrain
	var buildings := ranch.get_node_or_null(^"Buildings") as Node3D
	assert_not_null(terrain)
	assert_not_null(buildings)
	var doorways := 0
	for child in buildings.get_children():
		var b := child as Building
		if b == null or b.door_width <= 0.001:
			continue
		doorways += 1
		var apron := b.get_node_or_null(^"DoorApron") as MeshInstance3D
		assert_not_null(apron, "%s has a doorway and therefore owes it an apron" % b.name)
		if apron == null:
			continue

		# The world AABB of each box, built from its own eight corners rather than from
		# get_aabb(), so the rotation the apron leans on is actually applied.
		var apron_world := AABB(apron.global_transform * Vector3.ZERO, Vector3.ZERO)
		for c: Vector3 in _apron_corners_local(b):
			apron_world = apron_world.expand(b.global_transform * c)
		var floor_node := b.get_node_or_null(^"Floor") as MeshInstance3D
		var plinth_box: BoxMesh = floor_node.mesh
		var plinth_world := AABB(floor_node.global_position, Vector3.ZERO)
		var ph: Vector3 = plinth_box.size * 0.5
		for sx: float in [-ph.x, ph.x]:
			for sy: float in [-ph.y, ph.y]:
				for sz: float in [-ph.z, ph.z]:
					plinth_world = plinth_world.expand(
						b.global_transform * (floor_node.transform * Vector3(sx, sy, sz)))

		# 1. BELOW THE BOARDS, AND ALL THE WAY TO THE GROUND.
		var lowest: float = b.footprint_relief(Callable(terrain, "height_at")).x
		assert_lt(apron_world.position.y, plinth_world.end.y - MARGIN,
			"%s: the apron's lowest point (%.3f) is not below the plinth top (%.3f): "
				% [b.name, apron_world.position.y, plinth_world.end.y]
				+ "it is entombed in the plinth, which is what shipped")
		assert_lt(apron_world.position.y, lowest + 0.05,
			"%s: the apron stops %.3f m above the ground it is supposed to reach (%.3f)"
				% [b.name, apron_world.position.y - lowest, lowest])

		# 2. OUTSIDE THE FOOTPRINT, in the building's own basis.
		var front_z: float = b.depth * 0.5 - BuildingScript.PLINTH_INSET
		var half_w: float = b.width * 0.5 - BuildingScript.PLINTH_INSET
		var furthest := -INF
		for c: Vector3 in _apron_corners_local(b):
			furthest = maxf(furthest, c.z)
			if c.y > BuildingScript.FLOOR_TOP + 0.001:
				assert_gt(c.z, front_z - 0.001,
					"%s: an apron corner sits above the boards and inside the plinth" % b.name)
			assert_lte(absf(c.x), half_w + 0.001,
				"%s: the apron is wider than the plinth it leans on" % b.name)
		assert_gt(furthest, front_z + BuildingScript.DOOR_APRON_RUN * 0.9,
			"%s: the apron does not leave the plinth's own footprint (reaches %.3f, the "
				% [b.name, furthest] + "front face is at %.3f)" % front_z)
	assert_gt(doorways, 0, "the shipped map has doorways to check")
