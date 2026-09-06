extends GutTest
## The ground as REGIONS: game/world/terrain.gd read against the region catalogue
## (game/systems/region_registry.gd, game/data/regions/*.tres).
##
## game/test/test_ranch_world.gd already covers the plain heightfield (determinism, the
## flat apron, the relief past it, the walkable slope ceiling) against a Terrain that was
## never added to a tree. This file covers the parts that only exist once a registry has
## been handed over and the mesh has actually been built: the lake basin, the regional
## grass palettes, and the deferred build that lets ranch.gd hand the registry over at all.
##
## Preloads by path rather than by class_name, per the convention at the top of
## game/scripts/pony_rig.gd (the global class cache lives in the gitignored
## game/.godot/ and a fresh clone has not built it yet).

const TerrainScript := preload("res://world/terrain.gd")
const RegionRegistryScript := preload("res://systems/region_registry.gd")

## A parent for every Terrain built here, so the nodes are freed with it rather than
## leaked: a built Terrain owns a mesh, a trimesh shape and four boundary colliders.
var _world: Node3D


func before_each() -> void:
	_world = Node3D.new()
	add_child_autofree(_world)


## A Terrain that builds itself in _ready(), the default when nothing sets defer_build
## (ranch.tscn is the only scene that does): no registry, so the plain map.
func _bare_terrain() -> Terrain:
	var terrain: Terrain = TerrainScript.new()
	terrain.defer_build = false
	_world.add_child(terrain)
	return terrain


## A Terrain built the way ranch.gd builds it: the registry is handed over BEFORE the
## ground is shaped, then build() is called explicitly.
func _terrain_with_regions() -> Terrain:
	var terrain: Terrain = TerrainScript.new()
	terrain.defer_build = true
	var registry: RegionRegistry = RegionRegistryScript.new()
	registry.load_all(RegionRegistryScript.REGION_DIR)
	terrain.regions = registry
	_world.add_child(terrain)
	terrain.build()
	return terrain


func test_the_map_is_two_hundred_and_twenty_metres_across() -> void:
	assert_eq(TerrainScript.HALF, 110.0)


func test_the_lake_region_is_a_basin_and_the_others_are_not() -> void:
	var terrain := _terrain_with_regions()
	var regions: RegionRegistry = terrain.regions
	var lake: RegionData = regions.by_id(&"lake")
	var centre_h: float = terrain.height_at(lake.centre.x, lake.centre.y)
	var rim_h: float = terrain.height_at(lake.centre.x + lake.radius + 5.0, lake.centre.y)
	assert_lt(centre_h, rim_h - lake.lake_depth * 0.8, "the lake centre sits well below its rim")
	var orchard: RegionData = regions.by_id(&"orchard")
	var raw: float = terrain._raw_height(orchard.centre.x, orchard.centre.y) * terrain._relief_weight(orchard.centre.x, orchard.centre.y)
	assert_almost_eq(terrain.height_at(orchard.centre.x, orchard.centre.y), raw, 0.001, "a dry region is untouched")


func test_grass_tints_toward_the_region_palette_inside_and_not_outside() -> void:
	var terrain := _terrain_with_regions()
	var night: RegionData = terrain.regions.by_id(&"nightmeadow")
	var inside: Color = terrain.grass_at(night.centre.x, night.centre.y)
	var outside: Color = terrain.grass_at(0.0, 30.0)
	assert_gt(inside.b, outside.b + 0.1, "the night meadow reads bluer than the ranch")


func test_without_a_registry_the_terrain_builds_as_before() -> void:
	var terrain := _bare_terrain()
	assert_null(terrain.regions)
	assert_almost_eq(terrain.height_at(60.0, -62.0),
		terrain._raw_height(60.0, -62.0) * terrain._relief_weight(60.0, -62.0), 0.001)


func test_a_deferred_terrain_has_no_ground_until_build_is_called() -> void:
	# The whole point of defer_build: a child readies before its parent, so Ranch._ready()
	# has no moment early enough to hand the registry over if the terrain has already
	# shaped itself. If _ready() built the mesh anyway, the ranch's lake would be a bulge.
	var terrain: Terrain = TerrainScript.new()
	terrain.defer_build = true
	_world.add_child(terrain)
	assert_null(terrain.get_node_or_null("Mesh"), "a deferred terrain builds nothing in _ready()")
	assert_eq(terrain.collision_layer, 1, "but it is on the TERRAIN layer from the start")
	terrain.build()
	assert_not_null(terrain.get_node_or_null("Mesh"), "build() shapes the ground")
	assert_not_null(terrain.get_node_or_null("CollisionShape3D"), "and gives it a collider")


## THE GROUND IS A SHADER NOW, AND THE ONE FAILURE MODE THAT MATTERS IS INVISIBLE OTHERWISE.
## Godot compiles shaders lazily and the headless renderer never rasterises, so a
## ShaderMaterial on a mesh in a headless run is inert: a shader that fails to PARSE prints an
## error at load and every gate that only checks RANCH_OK still goes green. So the mesh is
## asked what material it is actually wearing.
func test_the_ground_wears_a_shader_with_code_in_it() -> void:
	var terrain: Terrain = _bare_terrain()
	var mesh := terrain.get_node(^"Mesh") as MeshInstance3D
	var mat := mesh.mesh.surface_get_material(0) as ShaderMaterial
	assert_not_null(mat, "surface 0 is a ShaderMaterial")
	assert_not_null(mat.shader, "the ShaderMaterial carries a shader")
	assert_gt(mat.shader.code.length(), 0, "the shader has code in it")


## THE sRGB TRAP, PINNED BY NAME. vertex_color_is_srgb is a StandardMaterial3D flag with NO
## shader equivalent: the shader has to do the conversion itself or Godot treats the vertex
## colours as already linear and the ground comes out roughly twice as bright as authored.
## terrain.gd's own comment records what that looked like the first time: "a pale mint sheet,
## not grass". This is the one trap in the whole slice most likely to be missed, so it is
## asserted by name rather than left to whoever looks at the next render.
func test_the_shader_converts_its_vertex_colour_out_of_srgb() -> void:
	var terrain: Terrain = _bare_terrain()
	var mesh := terrain.get_node(^"Mesh") as MeshInstance3D
	var mat := mesh.mesh.surface_get_material(0) as ShaderMaterial
	assert_true(mat.shader.code.contains("srgb_to_linear"),
		"drop this and the ground renders as a pale mint sheet")
	assert_true(mat.shader.code.contains("COLOR"),
		"grass_at() and the region palettes stay the single authority on ground colour")


## THE HEIGHTFIELD IS UNTOUCHED. Moving CELL, HALF, FLAT_RADIUS or height_at() would move the
## mesh, the collider, the props, the pens, the spawner and every gate that reads them, and
## the look pass has no business anywhere near any of that. The palette is deliberately NOT
## pinned here any more: GRASS_LOW/GRASS_HIGH are what task 9 tunes, and the tests below
## (test_the_grass_gradient_still_runs_from_shade_to_light and its neighbours) are what
## actually cover the palette's shape rather than freezing today's exact numbers.
func test_the_heightfield_is_exactly_what_it_was() -> void:
	assert_eq(TerrainScript.HALF, 110.0)
	assert_eq(TerrainScript.CELL, 2.0)
	assert_eq(TerrainScript.FLAT_RADIUS, 30.0)


## THE GROUND AND THE THINGS STANDING ON IT SHARE LIGHT, OR THEY DO NOT LOOK LIKE ONE PLACE.
## This cannot say whether the grass is pretty. It can say the two ends of the gradient still
## bracket each other, that the dirt is still earth rather than grass, and that the numbers a
## human tuned in terrain.gd are the numbers the shader is actually handed -- which is the
## pair that silently drifts.

## A Terrain built plain (no registry), with its Mesh node handed back rather than the
## Terrain itself: every test below wants the rendered surface, not the body it rides on.
func _built_terrain_mesh() -> MeshInstance3D:
	var terrain := _bare_terrain()
	return terrain.get_node(^"Mesh") as MeshInstance3D


func test_the_grass_gradient_still_runs_from_shade_to_light() -> void:
	assert_lt(TerrainScript.GRASS_LOW.v, TerrainScript.GRASS_HIGH.v,
		"GRASS_LOW is the shaded end and GRASS_HIGH the lit one")
	assert_gt(TerrainScript.GRASS_LOW.s, 0.35, "grass at either end is grass, not a grey")
	assert_gt(TerrainScript.GRASS_HIGH.s, 0.35, "grass at either end is grass, not a grey")


func test_the_dirt_is_earth_and_never_another_green() -> void:
	var h: float = TerrainScript.DIRT.h
	assert_true(h < 0.14 or h > 0.95,
		"a hue in the greens would make the slope mask invisible")


func test_the_shader_is_handed_the_colours_terrain_gd_holds() -> void:
	var mesh := _built_terrain_mesh()
	var mat := mesh.mesh.surface_get_material(0) as ShaderMaterial
	assert_not_null(mat, "the ground wears the shader")
	assert_eq(mat.get_shader_parameter(&"grass_high"), TerrainScript.GRASS_HIGH,
		"the lit end of the gradient is one number in one place")
	assert_eq(mat.get_shader_parameter(&"dirt_color"), TerrainScript.DIRT,
		"the earth is one number in one place")


## THE ROAD IS PAINTED, NOT LAID: see PATH_POINTS' own comment for the ladder-of-plates
## defect this replaced. What a test CAN hold is that the polyline, the width and the edge
## numbers a human tuned in terrain.gd are the exact numbers the shader was actually handed
## -- the pair that silently drifts is the one no render can catch, because a wrong number
## still paints SOME road, just not the one terrain.gd says it painted.
func test_the_path_polyline_reaches_the_shader_padded_to_its_fixed_length() -> void:
	var mesh := _built_terrain_mesh()
	var mat := mesh.mesh.surface_get_material(0) as ShaderMaterial
	var points: PackedVector2Array = mat.get_shader_parameter(&"path_points")
	assert_eq(points.size(), TerrainScript.PATH_SHADER_SLOTS,
		"the shader's own array uniform is a fixed length; this must match it exactly")
	for i in range(TerrainScript.PATH_POINTS.size()):
		assert_eq(points[i], TerrainScript.PATH_POINTS[i],
			"slot %d must be the real route, not padding" % i)
	# EVERY SLOT PAST THE REAL ROUTE REPEATS ITS OWN LAST POINT, a zero-length segment the
	# shader's own path_distance() treats as inert (see its comment) rather than as a
	# divide-by-zero: padding with the origin or any other point would draw a second,
	# spurious road segment from the route's real end to wherever the padding sat.
	var last: Vector2 = TerrainScript.PATH_POINTS[TerrainScript.PATH_POINTS.size() - 1]
	for i in range(TerrainScript.PATH_POINTS.size(), TerrainScript.PATH_SHADER_SLOTS):
		assert_eq(points[i], last, "padding slot %d must repeat the route's last point" % i)
	assert_eq(mat.get_shader_parameter(&"path_point_count"), TerrainScript.PATH_POINTS.size(),
		"the shader must stop walking the array at the real route, not its padding")
	assert_eq(mat.get_shader_parameter(&"path_half_width"), TerrainScript.PATH_HALF_WIDTH)
	assert_eq(mat.get_shader_parameter(&"path_edge_softness"), TerrainScript.PATH_EDGE_SOFTNESS)
	assert_eq(mat.get_shader_parameter(&"path_edge_noise"), TerrainScript.PATH_EDGE_NOISE)
	assert_eq(mat.get_shader_parameter(&"path_glow"), TerrainScript.PATH_GLOW)


## THE SHADER'S OWN ARRAY SIZE, PINNED BY NAME so PATH_SHADER_SLOTS cannot drift out of step
## with terrain.gdshader's `const int PATH_MAX_POINTS` the way test_terrain.gd already pins
## srgb_to_linear() by name above -- a mismatch here does not error, it silently truncates or
## under-fills the array, which no render catches either.
func test_the_shader_array_size_matches_terrain_gd_own_constant() -> void:
	var mesh := _built_terrain_mesh()
	var mat := mesh.mesh.surface_get_material(0) as ShaderMaterial
	assert_true(mat.shader.code.contains(
			"const int PATH_MAX_POINTS = %d;" % TerrainScript.PATH_SHADER_SLOTS),
		"terrain.gdshader's PATH_MAX_POINTS must equal terrain.gd's PATH_SHADER_SLOTS")


## THE ROUTE ITSELF: along the north road's own centreline, wide enough to read as a track
## and narrow enough to stay clear of the town row's buildings at x = 15 and x = -12.
func test_the_path_route_runs_the_north_roads_own_line_clear_of_the_town_row() -> void:
	for p: Vector2 in TerrainScript.PATH_POINTS:
		assert_almost_eq(p.x, 1.5, 0.01, "the route stays on the road's own x")
	var clearance: float = 15.0 - 1.5 - TerrainScript.PATH_HALF_WIDTH \
		- TerrainScript.PATH_EDGE_SOFTNESS
	assert_gt(clearance, 0.0,
		"the painted road's fattest edge must not reach the town row's east side")
	assert_gt(TerrainScript.PATH_POINTS.size(), 1, "a polyline needs at least two points")
