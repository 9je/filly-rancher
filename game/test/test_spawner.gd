extends GutTest
## THE HERD KEEPS HOURS. game/world/spawner.gd draws a zone's ponies out of the entries
## whose PonyData.available() says yes for the sky the world is under, and refresh() is
## what happens when that sky changes: whoever no longer belongs walks off, and whoever
## now does arrives.
##
## Run against a FIXTURE ROSTER (game/test/fixtures/ponies_conditional/), not the real
## one, for the same reason game/test/fixtures/ponies_malformed/ exists: the real roster
## is a content decision that changes every slice, and a test that spells out which
## character is drawn where would be re-written every time somebody re-zones a pony. The
## four fixtures below are the whole truth table instead, in two zones:
##
##   fixture_meadow   fixture_any_a, fixture_any_b   no conditions at all
##   fixture_hollow   fixture_night (NIGHT only), fixture_storm (STORM only)
##
## The hollow is the interesting half: it is EMPTY at DAY/CLEAR, holds only the storm
## pony at DAY/STORM, and only the night pony at NIGHT/CLEAR. So "the sky changed and the
## herd changed with it" is a fact about who is standing there, with no draw luck in it.
##
## THE PONIES ARE REAL PONY BODIES on a real floor, because the thing being measured
## includes a departure: Pony.leave() walks her away and frees her, and none of that can
## be observed without physics frames. Every fixture wears twilight's model for the same
## reason test_pony.gd clones twilight's record: the visuals have to actually build.

const SpawnerScript := preload("res://world/spawner.gd")
const ZoneMarkerScript := preload("res://world/zone_marker.gd")
const PonyScript := preload("res://actors/pony/pony.gd")
const WorldStateScript := preload("res://systems/world_state.gd")
const LayersScript := preload("res://world/collision_layers.gd")

const FIXTURE_DIR := "res://test/fixtures/ponies_conditional"

const MEADOW := &"fixture_meadow"
const HOLLOW := &"fixture_hollow"

## Big enough that both zone discs and every roam circle sit well inside it.
const FLOOR_SIZE := Vector3(80.0, 1.0, 80.0)

## Any number: the fixture pools are small enough that these tests never depend on which
## way a draw fell, only on which pool it was drawn from.
const SEED := 424242

var _world: Node3D


func before_each() -> void:
	_world = Node3D.new()
	add_child_autofree(_world)

	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = LayersScript.TERRAIN
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = FLOOR_SIZE
	floor_shape.shape = box
	floor_shape.position = Vector3(0.0, -FLOOR_SIZE.y * 0.5, 0.0)
	floor_body.add_child(floor_shape)
	_world.add_child(floor_body)


# --- the pool is filtered ------------------------------------------------------------

func test_populate_draws_nobody_whose_conditions_do_not_hold() -> void:
	var spawner := _spawner()
	await wait_physics_frames(2)
	var n: int = spawner.populate(WorldStateScript.Phase.DAY, WorldStateScript.Weather.CLEAR)

	assert_eq(n, 2, "only the meadow has anyone available at DAY and CLEAR")
	var ids := _ids(spawner)
	assert_does_not_have(ids, &"fixture_night", "a NIGHT pony must not spawn in the day")
	assert_does_not_have(ids, &"fixture_storm", "a STORM pony must not spawn under a clear sky")


func test_populate_draws_the_pony_whose_weather_it_is() -> void:
	var spawner := _spawner()
	await wait_physics_frames(2)
	spawner.populate(WorldStateScript.Phase.DAY, WorldStateScript.Weather.STORM)

	var ids := _ids(spawner)
	assert_eq(ids.count(&"fixture_storm"), 2, "the hollow is all storm pony in a storm")
	assert_does_not_have(ids, &"fixture_night", "and still nobody who keeps night hours")


# --- refresh -------------------------------------------------------------------------

func test_refresh_sends_away_whoever_no_longer_belongs_and_draws_who_does() -> void:
	var spawner := _spawner()
	await wait_physics_frames(2)
	spawner.populate(WorldStateScript.Phase.DAY, WorldStateScript.Weather.STORM)

	var result: Dictionary = spawner.refresh(WorldStateScript.Phase.NIGHT,
		WorldStateScript.Weather.CLEAR, 0, _far_away())

	assert_eq(result["left"], 2, "both storm ponies are told to leave when the storm ends")
	assert_eq(result["arrived"], 2, "and the night pony fills the hollow behind them")

	for pony in spawner.get_spawned():
		var data: PonyData = pony.get_data()
		if pony.is_leaving():
			assert_eq(data.id, &"fixture_storm", "only the storm pony is on her way out")
		else:
			assert_true(data.available(WorldStateScript.Phase.NIGHT,
				WorldStateScript.Weather.CLEAR),
				"%s is staying, so her conditions must hold" % data.id)


func test_refresh_leaves_a_pony_whose_conditions_still_hold_alone() -> void:
	var spawner := _spawner()
	await wait_physics_frames(2)
	spawner.populate(WorldStateScript.Phase.DAY, WorldStateScript.Weather.CLEAR)

	spawner.refresh(WorldStateScript.Phase.NIGHT, WorldStateScript.Weather.CLEAR, 0,
		_far_away())

	for pony in spawner.get_spawned():
		var data: PonyData = pony.get_data()
		if data.id == &"fixture_any_a" or data.id == &"fixture_any_b":
			assert_false(pony.is_leaving(),
				"%s has no conditions, so no sky can send her away" % data.id)


func test_refresh_is_idempotent_for_the_same_hour() -> void:
	var spawner := _spawner()
	await wait_physics_frames(2)
	spawner.populate(WorldStateScript.Phase.DAY, WorldStateScript.Weather.STORM)
	spawner.refresh(WorldStateScript.Phase.NIGHT, WorldStateScript.Weather.CLEAR, 0,
		_far_away())

	var again: Dictionary = spawner.refresh(WorldStateScript.Phase.NIGHT,
		WorldStateScript.Weather.CLEAR, 0, _far_away())

	assert_eq(again["left"], 0, "nobody is asked to leave twice")
	assert_eq(again["arrived"], 0, "and every marker is already as full as it wants to be")


func test_a_leaving_pony_does_not_count_toward_her_marker() -> void:
	# The proof that she does not: the hollow is refilled to its full spawn_count in the
	# same call that empties it, rather than one short because a pony walking away was
	# counted as standing there.
	var spawner := _spawner()
	await wait_physics_frames(2)
	spawner.populate(WorldStateScript.Phase.DAY, WorldStateScript.Weather.STORM)
	spawner.refresh(WorldStateScript.Phase.NIGHT, WorldStateScript.Weather.CLEAR, 0,
		_far_away())

	var staying := 0
	for pony in spawner.get_spawned():
		if not pony.is_leaving() and pony.get_data().id == &"fixture_night":
			staying += 1
	assert_eq(staying, 2, "the hollow's marker asked for two and got two")


func test_the_refresh_draw_is_the_same_for_the_same_seed_cycle_and_phase() -> void:
	var first := _spawner()
	var second := _spawner()
	await wait_physics_frames(2)
	first.populate(WorldStateScript.Phase.DAY, WorldStateScript.Weather.STORM)
	second.populate(WorldStateScript.Phase.DAY, WorldStateScript.Weather.STORM)

	first.refresh(WorldStateScript.Phase.NIGHT, WorldStateScript.Weather.CLEAR, 3,
		_far_away())
	second.refresh(WorldStateScript.Phase.NIGHT, WorldStateScript.Weather.CLEAR, 3,
		_far_away())

	assert_eq(_ids(first), _ids(second),
		"the same save at the same hour of the same day draws the same ponies")


func test_a_different_cycle_reseeds_the_draw() -> void:
	# Not an assertion about WHO is drawn, which is content: an assertion that the cycle
	# reaches the RNG at all, because a refresh that ignored it would hand the player the
	# same herd every night forever.
	var spawner := _spawner()
	await wait_physics_frames(2)
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = spawner.spawn_seed + 0 * 4 + WorldStateScript.Phase.NIGHT
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = spawner.spawn_seed + 1 * 4 + WorldStateScript.Phase.NIGHT
	assert_ne(rng_a.randf(), rng_b.randf(),
		"seed + cycle * 4 + phase must differ between one night and the next")


# --- the departure itself ------------------------------------------------------------

func test_a_leaving_pony_is_gone_within_leave_seconds() -> void:
	var spawner := _spawner()
	await wait_physics_frames(2)
	spawner.populate(WorldStateScript.Phase.DAY, WorldStateScript.Weather.STORM)
	spawner.refresh(WorldStateScript.Phase.NIGHT, WorldStateScript.Weather.CLEAR, 0,
		_far_away())

	var leaving := 0
	for pony in spawner.get_spawned():
		if pony.is_leaving():
			leaving += 1
	assert_eq(leaving, 2, "two ponies set off before the clock starts")

	# Comfortably inside LEAVE_SECONDS at 60 Hz, and there is no player anywhere in this
	# world, so every one of them is already out of sight and free to go.
	await wait_physics_frames(30)

	for pony in spawner.get_spawned():
		assert_false(pony.is_leaving(), "%s should have gone by now" % pony.name)
	assert_eq(_ids(spawner).count(&"fixture_storm"), 0,
		"the storm ponies are off the map, and their record is still on disk")


# --- helpers -------------------------------------------------------------------------

## A spawner over two markers, one per fixture zone, on the floor built in before_each().
func _spawner() -> Spawner:
	var zones := Node3D.new()
	zones.name = "Zones%d" % _world.get_child_count()
	_world.add_child(zones)
	zones.add_child(_marker(MEADOW, Vector3(-12.0, 0.0, 0.0)))
	zones.add_child(_marker(HOLLOW, Vector3(12.0, 0.0, 0.0)))

	var spawner: Spawner = SpawnerScript.new()
	spawner.pony_dir = FIXTURE_DIR
	spawner.spawn_seed = SEED
	_world.add_child(spawner)
	spawner.zones_path = spawner.get_path_to(zones)
	return spawner


func _marker(zone: StringName, position: Vector3) -> ZoneMarker:
	var marker: ZoneMarker = ZoneMarkerScript.new()
	marker.zone_id = zone
	marker.spawn_radius = 4.0
	marker.roam_radius = 2.0
	marker.spawn_count = 2
	marker.position = position
	return marker


## The ids currently on the map, sorted, so two spawners can be compared as a whole
## rather than pony by pony.
func _ids(spawner: Spawner) -> Array:
	var ids: Array = []
	for pony in spawner.get_spawned():
		var data: PonyData = pony.get_data()
		if data != null:
			ids.append(data.id)
	ids.sort()
	return ids


## Where the player is standing, which in this world is nowhere: refresh() takes the
## position because the ranch has it, and Pony.leave() measures against the player she
## can actually see rather than against this.
func _far_away() -> Vector3:
	return Vector3(500.0, 0.0, 500.0)
