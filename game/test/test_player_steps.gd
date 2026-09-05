extends GutTest
## The hoofstep cadence: a step every STEP_STRIDE metres actually travelled, no step
## standing still, no step in the air, and a surface the ranch chooses rather than the
## player guessing at one.

const PlayerScript := preload("res://actors/player/player.gd")
const SoundScript := preload("res://systems/sound.gd")


func test_the_two_surfaces_are_library_ids() -> void:
	assert_true(SoundScript.LIBRARY.has(PlayerScript.SURFACE_GRASS))
	assert_true(SoundScript.LIBRARY.has(PlayerScript.SURFACE_HARD))


func test_the_stride_is_a_quadruped_stride_and_not_a_machine_gun() -> void:
	# At RUN_SPEED this is about five steps a second across four hooves, which is a gallop.
	# Under half a metre would be a drill and over two would be a limp.
	assert_gte(PlayerScript.STEP_STRIDE, 0.6)
	assert_lte(PlayerScript.STEP_STRIDE, 2.0)
	assert_gt(PlayerScript.STEP_MIN_SPEED, 0.0)


func test_a_fresh_player_starts_on_grass() -> void:
	var player = PlayerScript.new()
	assert_eq(player.step_surface(), PlayerScript.SURFACE_GRASS)
	player.free()


func test_the_surface_is_the_rancher_s_to_set() -> void:
	var player = PlayerScript.new()
	player.set_step_surface(PlayerScript.SURFACE_HARD)
	assert_eq(player.step_surface(), PlayerScript.SURFACE_HARD)
	# An id that is not a real surface is refused rather than played into a push_error on
	# every single step for the rest of the session. push_error is expected here, once,
	# for the refusal itself.
	player.set_step_surface(&"not_a_surface")
	assert_push_error(1, "an unknown surface id is reported loudly, not swallowed")
	assert_eq(player.step_surface(), PlayerScript.SURFACE_HARD)
	player.free()


func test_standing_still_never_accumulates_a_step() -> void:
	var player = PlayerScript.new()
	for i in range(120):
		player.accumulate_step(0.0, 1.0 / 60.0, true)
	assert_almost_eq(player.step_distance(), 0.0, 0.0001)
	player.free()


func test_leaving_the_ground_resets_the_accumulator() -> void:
	var player = PlayerScript.new()
	player.accumulate_step(3.0, 1.0 / 60.0, true)
	assert_gt(player.step_distance(), 0.0)
	player.accumulate_step(3.0, 1.0 / 60.0, false)
	assert_almost_eq(player.step_distance(), 0.0, 0.0001)
	player.free()


func test_a_step_fires_once_per_stride_and_the_remainder_carries() -> void:
	var player = PlayerScript.new()
	var steps := 0
	# Ten metres at one metre per frame.
	for i in range(10):
		if player.accumulate_step(60.0, 1.0 / 60.0, true):
			steps += 1
	assert_eq(steps, int(floor(10.0 / PlayerScript.STEP_STRIDE)),
		"a step every STEP_STRIDE metres, and the remainder carried into the next one")
	player.free()
