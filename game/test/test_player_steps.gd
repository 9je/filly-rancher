extends GutTest
## THE HOOFSTEP CADENCE, AND WHAT IT IS A FUNCTION OF.
##
## History, in one paragraph: one sound per 1.1 m travelled lined up with nothing (playtest
## 2); one sound per clip cycle (slice R3) landed on one hoof of four at the run, so the
## run was a single sample looping at the cycle rate, and that sample was a field recording
## lifted 16 dB with its room tone (the playtest of 2026-10-24: "the running sound is noisy
## and bad"). Now every footfall the clip itself depicts makes a sound: the moments its IK
## hoof targets come down, read straight out of the clip's position tracks
## (Player.footfalls_in), with hooves that land together counted once.
##
## This file checks that reading against the real clips, the crossing logic with numbers,
## and the surface pick. game/test_input/test_footsteps.gd is the end to end proof: real
## keys, the visible hoof bones, the Sound pool.

const PlayerScript := preload("res://actors/player/player.gd")
const GaitScript := preload("res://systems/gait.gd")
const SoundScript := preload("res://systems/sound.gd")
const TerrainScript := preload("res://world/terrain.gd")

const WALK := &"walk"
const GALLOP := &"gallop"

var _scene_player: Node = null


func after_each() -> void:
	if _scene_player != null:
		_scene_player.queue_free()
		_scene_player = null


## A real player with her real body (so her real clips), in the tree.
func _real_player() -> Node:
	_scene_player = (load("res://actors/player/player.tscn") as PackedScene).instantiate()
	add_child(_scene_player)
	return _scene_player


func test_every_surface_is_a_library_id() -> void:
	for id: StringName in PlayerScript.SURFACES:
		assert_true(SoundScript.LIBRARY.has(id), "'%s' is not in Sound.LIBRARY" % id)
	assert_eq(PlayerScript.SURFACES.size(), 5)


func test_a_fresh_player_starts_on_grass() -> void:
	var player = PlayerScript.new()
	assert_eq(player.step_surface(), PlayerScript.SURFACE_GRASS)
	player.free()


func test_the_open_ground_surface_is_the_rancher_s_to_set() -> void:
	var player = PlayerScript.new()
	player.set_step_surface(PlayerScript.SURFACE_STONE)
	assert_eq(player.step_surface(), PlayerScript.SURFACE_STONE)
	player.set_step_surface(&"not_a_surface")
	assert_push_error(1, "an unknown surface id is reported loudly, not swallowed")
	assert_eq(player.step_surface(), PlayerScript.SURFACE_STONE)
	player.free()


## The walk is a diagonal gait: front-left with rear-right, then the other pair, half a
## cycle apart. Two footfalls, each a pair landing together.
func test_the_walk_clip_has_two_footfalls_half_a_cycle_apart() -> void:
	var player := _real_player()
	var falls: Array = player.footfalls_for(WALK)
	assert_eq(falls.size(), 2, "%s" % [falls])
	if falls.size() == 2:
		var gap := float(falls[1].t) - float(falls[0].t)
		assert_almost_eq(gap, GaitScript.WALK_CYCLE_SECONDS * 0.5, 0.01)
		assert_false(bool(falls[0].rear), "a pair with a front hoof in it takes the front accent")


## The gallop's four hooves land apart, two hind and two fore.
func test_the_gallop_clip_has_four_footfalls_two_hind_two_fore() -> void:
	var player := _real_player()
	var falls: Array = player.footfalls_for(GALLOP)
	assert_eq(falls.size(), 4, "%s" % [falls])
	if falls.size() == 4:
		var rear := 0
		for f: Dictionary in falls:
			rear += 1 if bool(f.rear) else 0
		assert_eq(rear, 2, "two hind, two fore: %s" % [falls])
		for f: Dictionary in falls:
			assert_between(float(f.t), 0.0, GaitScript.GALLOP_CYCLE_SECONDS)


## Hand built: two hooves touching down 5 ms apart are one sound, a third 0.2 s later is
## another, and a clip with no hoof tracks falls back to one footfall at the loop point.
func test_footfalls_merge_hooves_that_land_together() -> void:
	var anim := Animation.new()
	anim.length = 0.5
	for spec: Array in [["IK_FrontHoof.L", 0.100], ["IK_RearHoof.R", 0.105], ["IK_FrontHoof.R", 0.300]]:
		var track := anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(track, NodePath("Armature/Skeleton3D:%s" % spec[0]))
		var land: float = spec[1]
		anim.position_track_insert_key(track, 0.0, Vector3(0, 0.08, 0))
		anim.position_track_insert_key(track, land, Vector3.ZERO)
		anim.position_track_insert_key(track, land + 0.1, Vector3.ZERO)
		anim.position_track_insert_key(track, 0.5, Vector3(0, 0.08, 0))
	var falls: Array = PlayerScript.footfalls_in(anim)
	assert_eq(falls.size(), 2, "%s" % [falls])
	if falls.size() == 2:
		assert_almost_eq(float(falls[0].t), 0.100, 0.01)
		assert_almost_eq(float(falls[1].t), 0.300, 0.01)
	var player = PlayerScript.new()
	assert_eq(player.footfalls_for(WALK), [{"t": 0.0, "rear": false}],
		"no body, no clip: the old one-a-cycle rule")
	player.free()


## Walk the real gallop clip round three times at its saturated playback and count.
func test_three_gallop_cycles_make_twelve_hoofsteps() -> void:
	var player := _real_player()
	var cycle: float = GaitScript.GALLOP_CYCLE_SECONDS
	var steps := 0
	var ticks := 180
	for i in range(ticks + 1):
		if player.step_on_clip(GALLOP, fmod(float(i) * cycle / 60.0, cycle),
				PlayerScript.RUN_SPEED, true):
			steps += 1
	assert_eq(steps, 12, "four footfalls a cycle, three cycles")


func test_standing_still_never_makes_a_sound() -> void:
	var player = PlayerScript.new()
	var cycle: float = GaitScript.WALK_CYCLE_SECONDS
	for i in range(240):
		assert_false(player.step_on_clip(WALK, fmod(float(i) * cycle / 60.0, cycle), 0.0, true),
			"a hoof that is not travelling has not landed on anything")
	player.free()


func test_the_idle_clip_never_makes_a_sound() -> void:
	var player = PlayerScript.new()
	for i in range(240):
		assert_false(player.step_on_clip(&"idle", fmod(float(i) * 0.02, 1.0), 5.0, true))
	player.free()


func test_leaving_the_ground_stops_the_hoofsteps() -> void:
	var player = PlayerScript.new()
	var cycle: float = GaitScript.GALLOP_CYCLE_SECONDS
	var steps := 0
	for i in range(180):
		if player.step_on_clip(GALLOP, fmod(float(i) * cycle / 60.0, cycle),
				PlayerScript.RUN_SPEED, false):
			steps += 1
	assert_eq(steps, 0, "airborne hooves land on nothing")
	player.free()


## THE HANDOVER. The AnimationPlayer's position resets when walk becomes gallop; that is
## a change of clip, not a footfall.
func test_changing_clip_does_not_fire_a_stray_step() -> void:
	var player = PlayerScript.new()
	assert_false(player.step_on_clip(WALK, 0.80, PlayerScript.SNEAK_SPEED, true))
	assert_false(player.step_on_clip(GALLOP, 0.01, PlayerScript.RUN_SPEED, true),
		"the position fell because the clip changed, not because a hoof landed")
	player.free()


## The cadence at the two speeds the game offers, in sounds a second: footfalls a cycle
## times cycles a second. A real horse's gallop is ten to twelve beats a second.
func test_the_cadence_at_the_two_speeds_the_game_offers() -> void:
	var player := _real_player()
	for spec: Array in [[PlayerScript.SNEAK_SPEED, 3.0, 6.0], [PlayerScript.RUN_SPEED, 8.0, 13.0]]:
		var speed: float = spec[0]
		var clip: StringName = GaitScript.clip_for_speed(speed)
		var cycle: float = GaitScript.WALK_CYCLE_SECONDS if clip == WALK \
			else GaitScript.GALLOP_CYCLE_SECONDS
		var per_second: float = player.footfalls_for(clip).size() \
			* GaitScript.playback_scale_for_clip(clip, speed) / cycle
		assert_between(per_second, float(spec[1]), float(spec[2]),
			"%.2f m/s plays '%s' at %.2f hoofsteps a second" % [speed, clip, per_second])


func test_the_surface_comes_from_what_she_stands_on() -> void:
	var tagged := StaticBody3D.new()
	tagged.set_meta(PlayerScript.SURFACE_META, PlayerScript.SURFACE_METAL)
	var child := StaticBody3D.new()
	tagged.add_child(child)
	assert_eq(PlayerScript.surface_for(child, Vector3.ZERO, PlayerScript.SURFACE_GRASS),
		PlayerScript.SURFACE_METAL, "a tag on an ancestor names the surface")
	var plain := StaticBody3D.new()
	assert_eq(PlayerScript.surface_for(plain, Vector3.ZERO, PlayerScript.SURFACE_GRASS),
		PlayerScript.SURFACE_WOOD, "an untagged prop is timber")
	assert_eq(PlayerScript.surface_for(null, Vector3.ZERO, PlayerScript.SURFACE_STONE),
		PlayerScript.SURFACE_STONE)
	var terrain = TerrainScript.new()
	var on_path := Vector3(TerrainScript.PATH_POINTS[0].x, 0.0, 30.0)
	assert_eq(PlayerScript.surface_for(terrain, on_path, PlayerScript.SURFACE_GRASS),
		PlayerScript.SURFACE_DIRT, "the painted path is dirt")
	assert_eq(PlayerScript.surface_for(terrain, on_path + Vector3(12, 0, 0),
		PlayerScript.SURFACE_GRASS), PlayerScript.SURFACE_GRASS, "the meadow is open ground")
	assert_eq(PlayerScript.surface_for(terrain, on_path + Vector3(12, 0, 0),
		PlayerScript.SURFACE_STONE), PlayerScript.SURFACE_STONE, "the Strip's open ground is paved")
	terrain.free()
	tagged.free()
	plain.free()


func test_buildings_and_factory_floors_tag_themselves() -> void:
	var building = load("res://world/building.gd").new()
	add_child(building)
	assert_eq(StringName(building.get_meta(PlayerScript.SURFACE_META, &"")), PlayerScript.SURFACE_WOOD)
	building.queue_free()
	var src := FileAccess.get_file_as_string("res://world/factory_interior.gd")
	assert_true(src.contains("\"hoof_metal\" if spec.metal else &\"hoof_stone\""),
		"the Factory's floors say metal (grating) or stone (tile)")
