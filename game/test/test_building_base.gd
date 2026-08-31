extends GutTest
## THE PLINTH UNDER EVERY BUILDING ON THE MAP, against the real terrain.
##
## THE BUG: the shipped Floor slab was 0.14 m thick with its bottom face at exactly local
## y = 0, and Props.seat() drops a building by the ground height at ONE point. The terrain
## under Buildings/Palace has 0.633 m of relief across its 14 by 9 m footprint (measured;
## see ranch.gd's PALACE_MAX_RELIEF), so the ground crossed that 0.14 m floor and the two
## surfaces fought for the same pixels. The owner, 2026-08-31: "z fighting at the palace
## base, a flickering skirt where the building meets terrain".
##
## THE INVARIANT WITH TEETH is stated per building rather than for the Palace alone: the
## plinth's top must clear the HIGHEST ground under the footprint and its bottom must sit
## below the LOWEST, both with margin. A building that satisfies that cannot fight the
## terrain no matter what relief it is standing on.

const BuildingScript := preload("res://world/building.gd")
const TerrainScript := preload("res://world/terrain.gd")
const RanchScene := preload("res://world/ranch.tscn")

## Metres of clear air demanded on each side of the ground, on top of the relief itself.
## Bigger than Props.SINK_BIAS (0.05) so a passing check is a real gap rather than a
## rounding accident.
const MARGIN := 0.15


func test_the_plinth_is_thicker_than_the_worst_relief_on_the_map() -> void:
	assert_gt(BuildingScript.FLOOR_TOP, 0.633 + MARGIN,
		"the plinth top must clear the 0.633 m measured under the Palace")
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
