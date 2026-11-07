extends GutTest
## THE LAKE IS A POND WITH BANKS (playtest 2026-11-05 item 61, the owner's words: "Lake: ponies
## and the player walk under the water; ponies half sunk; grass shows through; no banks
## [48][49]"). The PS batch check after the first fix: "water opaque, but a flat disc with a
## lip, no bank, and black wedges by the shore".
##
## The root cause those tests pin: the lake was a bowl SUBTRACTED from the rolling relief and a
## flat disc laid over it at one height, so where the relief ran high the ground stood over the
## water (wedges of bank cutting the disc) and where it ran low the disc's rim stood in the air
## over dry ground (the lip), with no shore anywhere the two actually met. And the bowl was
## 2.2 m deep under a 0.8 m wading shelf that only the player's collider knew about: the ponies
## and their hooves stand on height_at(), the bowl, so they stood sunk to the withers.
##
## So these ask the shapes themselves: the ground meets the water at its shoreline on every
## heading, rises out of it over a real bank, lies at wading depth under all of it, buries the
## water's own rim, and the ponies are kept on the dry side of it.

const TerrainScript := preload("res://world/terrain.gd")
const RegionRegistryScript := preload("res://systems/region_registry.gd")
const LayersScript := preload("res://world/collision_layers.gd")
const RanchScene := preload("res://world/ranch.tscn")

## Deepest the water may stand over the ground she walks on: a pony is 2.19 m tall and this is
## below her knee.
const MAX_WADE := 0.55
## Steepest the ground may rise anywhere round the lake: a bank, not a step.
const MAX_SLOPE_DEG := 32.0
const HEADINGS := 64

var _world: Node3D


func before_each() -> void:
	_world = Node3D.new()
	add_child_autofree(_world)


func _terrain() -> Terrain:
	var terrain: Terrain = TerrainScript.new()
	terrain.defer_build = true
	var registry: RegionRegistry = RegionRegistryScript.new()
	registry.load_all(RegionRegistryScript.REGION_DIR)
	terrain.regions = registry
	_world.add_child(terrain)
	terrain.build()
	return terrain


func _lake(terrain: Terrain) -> RegionData:
	return terrain.regions.by_id(&"lake")


## The water as the ranch builds it: its node's height is the surface, its shader's radius the
## shoreline.
func _water(terrain: Terrain) -> MeshInstance3D:
	var water: MeshInstance3D = terrain.build_water(_lake(terrain))
	_world.add_child(water)
	return water


func _shore(water: MeshInstance3D) -> float:
	return float((water.mesh.surface_get_material(0) as ShaderMaterial).get_shader_parameter(&"radius"))


func _dir(k: int) -> Vector2:
	var a := TAU * float(k) / float(HEADINGS)
	return Vector2(cos(a), sin(a))


## "no banks" / "a flat disc with a lip": wherever you stand on the shore, the ground there is
## at the water's own height, all the way round.
func test_the_ground_meets_the_water_at_its_shoreline_on_every_heading() -> void:
	var terrain := _terrain()
	var water := _water(terrain)
	var lake := _lake(terrain)
	var level := water.global_position.y
	var shore := _shore(water)
	var worst := 0.0
	for k in HEADINGS:
		var at := lake.centre + _dir(k) * shore
		worst = maxf(worst, absf(terrain.height_at(at.x, at.y) - level))
	assert_lt(worst, 0.06, "the ground at the shoreline is at the water's height (worst %.2f m off)" % worst)


## "no banks": out of the water the ground rises, steadily, to the grass; nowhere round the
## lake does it step.
func test_a_bank_rises_from_the_water_to_the_grass_without_a_step() -> void:
	var terrain := _terrain()
	var water := _water(terrain)
	var lake := _lake(terrain)
	var level := water.global_position.y
	var shore := _shore(water)
	var max_rise := tan(deg_to_rad(MAX_SLOPE_DEG)) * 0.25
	var steps := 0
	var low_banks := 0
	var falls := 0
	for k in HEADINGS:
		var d := _dir(k)
		var last := NAN
		var r := shore - 4.0
		while r < lake.radius + 8.0:
			var at := lake.centre + d * r
			var h: float = terrain.height_at(at.x, at.y)
			if not is_nan(last) and absf(h - last) > max_rise:
				steps += 1
			if not is_nan(last) and r > shore and r <= shore + 2.5 and h < last - 0.001:
				falls += 1
			last = h
			r += 0.25
		var top := lake.centre + d * (shore + 3.0)
		if terrain.height_at(top.x, top.y) < level + 0.4:
			low_banks += 1
	assert_eq(steps, 0, "no step steeper than %d degrees anywhere round the lake" % int(MAX_SLOPE_DEG))
	assert_eq(falls, 0, "out of the water the bank only climbs")
	assert_eq(low_banks, 0, "3 m from the water the bank stands 0.4 m or more over it on every heading")


## "walk under the water", "ponies half sunk", "grass shows through": every bit of ground under
## the water is under it (no grass islands in it), and none of it deeper than her knee. Asked of
## height_at(), which the ponies, their hooves and the player's collider all stand on.
func test_the_ground_under_the_water_is_wading_depth_and_covered() -> void:
	var terrain := _terrain()
	var water := _water(terrain)
	var lake := _lake(terrain)
	var level := water.global_position.y
	var shore := _shore(water)
	var deepest := 0.0
	var dry := 0
	var x := -shore
	while x <= shore:
		var z := -shore
		while z <= shore:
			var r := Vector2(x, z).length()
			if r < shore - 0.5:
				var h: float = terrain.height_at(lake.centre.x + x, lake.centre.y + z)
				deepest = maxf(deepest, level - h)
				if h > level - 0.02:
					dry += 1
			z += 1.0
		x += 1.0
	assert_lt(deepest, MAX_WADE, "the water is at most %.2f m deep (deepest %.2f m)" % [MAX_WADE, deepest])
	assert_eq(dry, 0, "no ground pokes up through the water")
	assert_almost_eq(terrain.walk_height_at(lake.centre.x, lake.centre.y),
		terrain.height_at(lake.centre.x, lake.centre.y), 0.01,
		"what a hoof stands on in the water is the ground everybody else stands on")


## "black wedges by the shore", "a lip": the water's own edge is buried in the bank all the way
## round, and it is a sheet with no side to stand up out of the ground.
func test_the_waters_edge_is_buried_in_the_bank_all_the_way_round() -> void:
	var terrain := _terrain()
	var water := _water(terrain)
	var lake := _lake(terrain)
	var level := water.global_position.y
	var aabb := water.mesh.get_aabb()
	assert_lt(aabb.size.y, 0.01, "the water is a sheet, not a slab with a rim")
	var edge := aabb.size.x * 0.5
	var exposed := 0
	for k in HEADINGS * 2:
		var a := TAU * float(k) / float(HEADINGS * 2)
		var at := lake.centre + Vector2(cos(a), sin(a)) * edge
		# The ground as DRAWN (the mesh's triangles), which is what would show a gap.
		if terrain.surface_height_at(at.x, at.y) < level + 0.08:
			exposed += 1
	assert_eq(exposed, 0, "the water's rim is under the bank everywhere (%d of %d points showing)" % [exposed, HEADINGS * 2])


## Ponies stay out of it: a body with a pony's mask walking at the lake from the bank stops at the
## shore, the player's walks in, and a pony that is somehow in the water (dropped there by the
## beam) can walk out.
func test_a_pony_stops_at_the_shore_and_the_player_wades_in() -> void:
	var terrain := _terrain()
	var water := _water(terrain)
	var lake := _lake(terrain)
	var shore := _shore(water)
	await wait_physics_frames(2)
	var pony := _walker(LayersScript.PONY_WALKABLE)
	var player := _walker(LayersScript.WALKABLE)
	var leaver := _walker(LayersScript.PONY_WALKABLE)
	var d := _dir(5)
	var start := lake.centre + d * (shore + 4.0)
	pony.global_position = Vector3(start.x, terrain.height_at(start.x, start.y) + 0.8, start.y)
	var start2 := lake.centre + _dir(37) * (shore + 4.0)
	player.global_position = Vector3(start2.x, terrain.height_at(start2.x, start2.y) + 0.8, start2.y)
	var start3 := lake.centre + _dir(20) * (shore - 5.0)
	leaver.global_position = Vector3(start3.x, terrain.height_at(start3.x, start3.y) + 0.8, start3.y)
	for i in 240:
		_step(pony, lake.centre, 1.0)
		_step(player, lake.centre, 1.0)
		_step(leaver, lake.centre, -1.0)
		await wait_physics_frames(1)
	var pr := Vector2(pony.global_position.x, pony.global_position.z).distance_to(lake.centre)
	var plr := Vector2(player.global_position.x, player.global_position.z).distance_to(lake.centre)
	var lr := Vector2(leaver.global_position.x, leaver.global_position.z).distance_to(lake.centre)
	assert_gt(pr, shore, "a pony walking at the lake stops on the bank (%.1f m out, shore %.1f)" % [pr, shore])
	assert_lt(plr, shore - 3.0, "the player wades in (%.1f m out)" % plr)
	assert_gt(lr, shore + 1.0, "a pony in the water walks out of it (%.1f m out)" % lr)


func _walker(mask: int) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.collision_layer = LayersScript.PONY
	body.collision_mask = mask
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.42
	cap.height = 1.3
	col.shape = cap
	body.add_child(col)
	_world.add_child(body)
	return body


func _step(body: CharacterBody3D, centre: Vector2, toward: float) -> void:
	var to := Vector3(centre.x - body.global_position.x, 0.0, centre.y - body.global_position.z)
	var v := to.normalized() * 4.0 * toward
	body.velocity = Vector3(v.x, body.velocity.y - 9.8 / 60.0, v.z)
	if body.is_on_floor():
		body.velocity.y = 0.0
	body.move_and_slide()


## The spawner never stands a wild pony in the water.
func test_no_wild_pony_is_spawned_in_the_lake() -> void:
	var ranch = RanchScene.instantiate()
	add_child_autofree(ranch)
	await wait_physics_frames(4)
	var lake: RegionData = ranch.terrain.regions.by_id(&"lake")
	var waters: Array = ranch.find_children("Water_lake", "MeshInstance3D", true, false)
	assert_eq(waters.size(), 1, "the ranch has its lake")
	if waters.is_empty():
		return
	var shore := _shore(waters[0])
	var near := 0
	var wet := 0
	for p: CharacterBody3D in ranch.spawner.get_spawned():
		var r := Vector2(p.global_position.x, p.global_position.z).distance_to(lake.centre)
		if r < lake.radius:
			near += 1
		if r < shore + 0.3:
			wet += 1
			gut.p("%s stands in the lake, %.1f m from its middle" % [p.name, r])
	assert_gt(near, 0, "the lake has its wild ponies")
	assert_eq(wet, 0, "none of them stands in the water")


## A lake pony's wander never picks a spot in the water (she would only walk to the shore ring
## and stand there).
func test_a_lake_pony_never_wanders_toward_the_water() -> void:
	var ranch = RanchScene.instantiate()
	add_child_autofree(ranch)
	await wait_physics_frames(4)
	var lake: RegionData = ranch.terrain.regions.by_id(&"lake")
	var waters: Array = ranch.find_children("Water_lake", "MeshInstance3D", true, false)
	if waters.is_empty():
		fail_test("no lake")
		return
	var keep_out := float((waters[0] as Node).get_meta(&"pony_keep_out", 0.0))
	var at: Vector3 = (waters[0] as Node3D).global_position
	var picked := 0
	var wet := 0
	for p: CharacterBody3D in ranch.spawner.get_spawned():
		if Vector2(p.global_position.x, p.global_position.z).distance_to(lake.centre) > lake.radius:
			continue
		for i in 50:
			var t: Vector3 = p.call("_pick_wander_target")
			picked += 1
			if Vector2(t.x - at.x, t.z - at.z).length() < keep_out:
				wet += 1
	assert_gt(picked, 0, "the lake has its wild ponies")
	assert_eq(wet, 0, "no wander spot in the water (%d of %d)" % [wet, picked])
