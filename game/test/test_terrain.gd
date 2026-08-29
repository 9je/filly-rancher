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
