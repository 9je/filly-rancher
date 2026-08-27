extends GutTest
## Tests for Player (game/actors/player/player.gd) that the playground scene's gate
## cannot make on its own.
##
## `scenes/test/playground.tscn` drives the player with a camera that happens to look
## down -Z, so a controller that ignored the camera entirely and used its own -Z would
## pass it by coincidence. These tests build the player under a camera yawed 90 degrees
## and assert she travels along the CAMERA's forward axis, which is the whole point of
## "camera-relative movement" and the thing Task 5's orbiting rig depends on.
##
## They also pin the node contract later tasks were promised: a `CameraPivot` at head
## height and a `get_beam_origin()` that follows her facing rather than the body.
##
## Preloads by path rather than the global class_name, matching the convention
## documented at the top of game/scripts/pony_rig.gd.

const PlayerScene := preload("res://actors/player/player.tscn")
const PlayerScript := preload("res://actors/player/player.gd")
const GaitScript := preload("res://systems/gait.gd")

## Big enough that nothing in these tests can walk off it.
const FLOOR_SIZE := Vector3(40.0, 1.0, 40.0)
## Long enough for the acceleration ramp to finish and produce unambiguous travel.
const RUN_FRAMES := 45

var _world: Node3D
var _player: CharacterBody3D
var _camera: Camera3D


func before_each() -> void:
	_world = Node3D.new()
	add_child_autofree(_world)

	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = FLOOR_SIZE
	floor_shape.shape = box
	floor_shape.position = Vector3(0.0, -FLOOR_SIZE.y * 0.5, 0.0)
	floor_body.add_child(floor_shape)
	_world.add_child(floor_body)

	_camera = Camera3D.new()
	_world.add_child(_camera)

	_player = PlayerScene.instantiate()
	_world.add_child(_player)


func after_each() -> void:
	# Input actions are global engine state; a leaked press would corrupt every test
	# that ran afterwards (and the scene gates, which share the process under GUT).
	for action in ["move_forward", "move_back", "move_left", "move_right", "jump", "sneak", "beam"]:
		Input.action_release(action)


## Point the camera along `forward` (flattened) and make it the viewport's current
## camera, which is what Player._movement_basis() reads.
func _aim_camera(forward: Vector3) -> void:
	_camera.global_position = Vector3(0.0, 3.0, 0.0) - forward * 4.0
	_camera.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)
	_camera.current = true


## The two gameplay speeds, checked against what the animation can actually depict.
##
## THE PLAYTESTS BOUGHT SPEED WITH FOOT SKATE, ON PURPOSE, AND THIS IS THE RECEIPT. The
## owner's sessions said "move speed a bit slow for my liking" and then "running feels
## good, maybe a tad too slow still", so the running speed went 4.0 -> 4.8 -> 5.2 m/s,
## which is past Gait.TOP_SKATE_FREE_SPEED (4.29 m/s) -- the fastest ground speed any
## authored clip depicts with the hooves planted. Gait's own perceptibility ladder calls a
## skate ratio up to ~1.25 imperceptible in motion and 2.0 unmistakable moonwalking.
##
## So the assertion is not "there is no skate" any more -- that would be a test asserting a
## decision that was deliberately reversed. It is that the skate stays inside the BUDGET
## somebody chose, which matters more now than it did: running is the DEFAULT gait since
## the second playtest, so this skate is what the player sees all the time rather than only
## while a button is held. Somebody nudging RUN_SPEED to 6 "because it still feels a bit
## slow" crosses 1.25 and this goes red, which is the whole point: the budget is the thing
## worth defending, not the number.
func test_the_two_gameplay_speeds_stay_inside_their_animation_budget() -> void:
	assert_eq(GaitScript.clip_for_speed(PlayerScript.SNEAK_SPEED), &"walk",
		"sneaking must play the `walk` clip, not hand over to `gallop`")
	assert_almost_eq(GaitScript.skate_ratio(PlayerScript.SNEAK_SPEED), 1.0, 0.0001,
		"the sneak speed costs nothing and must stay that way")

	assert_eq(GaitScript.clip_for_speed(PlayerScript.RUN_SPEED), &"gallop",
		"running must play the `gallop` clip")
	var skate: float = GaitScript.skate_ratio(PlayerScript.RUN_SPEED)
	assert_lte(skate, 1.25,
		("the run's foot skate must stay inside the imperceptible band -- %.3f m/s " +
		"against a %.3f m/s ceiling is a ratio of %.3f") % [
			PlayerScript.RUN_SPEED, GaitScript.TOP_SKATE_FREE_SPEED, skate])
	assert_gt(PlayerScript.RUN_SPEED, GaitScript.TOP_SKATE_FREE_SPEED,
		"...and the player must out-run the fastest flee Pony.flee_speed_for() can " +
		"produce, which that ceiling is exactly what clamps")
	assert_gt(PlayerScript.RUN_SPEED, PlayerScript.SNEAK_SPEED * 2.0,
		"the sneak has to cost enough speed to be a real trade, not a rounding error")


func test_all_required_input_actions_exist() -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right", "jump", "beam"]:
		assert_true(InputMap.has_action(action), "project.godot must define '%s'" % action)


func test_every_movement_action_has_a_keyboard_and_a_gamepad_binding() -> void:
	var expectations := {
		"move_forward": true, "move_back": true, "move_left": true, "move_right": true,
		"jump": true, "beam": true, "sneak": true,
	}
	for action in expectations:
		var has_desktop := false
		var has_pad := false
		for event in InputMap.action_get_events(action):
			if event is InputEventKey or event is InputEventMouseButton:
				has_desktop = true
			elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
				has_pad = true
		assert_true(has_desktop, "'%s' needs a keyboard/mouse binding" % action)
		assert_true(has_pad, "'%s' needs a gamepad binding" % action)


func test_scene_contract_for_later_tasks() -> void:
	assert_not_null(_player.get_node_or_null("CameraPivot"),
		"Task 5 mounts its camera rig on a child named exactly 'CameraPivot'")
	var pivot: Node3D = _player.get_node("CameraPivot")
	assert_almost_eq(pivot.position.y, 1.45, 0.001,
		"the camera pivot sits at head height on the metric pony")
	assert_not_null(_player.get_beam_origin(),
		"Task 8 anchors the magic beam at get_beam_origin()")


func test_beam_origin_turns_with_the_pony_not_with_the_body() -> void:
	# The body never yaws (see player.gd) -- the beam origin has to follow her facing
	# anyway, or the beam would leave her horn whenever she faced sideways.
	var visuals: Node3D = _player.get_node("Visuals")
	var before: Vector3 = _player.get_beam_origin().global_position
	visuals.rotation.y = PI * 0.5
	var after: Vector3 = _player.get_beam_origin().global_position
	assert_almost_eq(_player.rotation.y, 0.0, 0.0001, "the body itself must not yaw")
	assert_gt(before.distance_to(after), 0.1,
		"the beam origin must move when the visuals turn")


func test_moves_along_the_camera_forward_axis_when_the_camera_is_yawed() -> void:
	# Camera looks down -X, so "forward" for the player must be -X, not her own -Z.
	_aim_camera(Vector3.LEFT)
	var start: Vector3 = _player.global_position
	Input.action_press("move_forward")
	await wait_physics_frames(RUN_FRAMES)
	var travel: Vector3 = _player.global_position - start
	assert_lt(travel.x, -0.5, "she must travel along the camera's forward axis (-X)")
	assert_almost_eq(travel.z, 0.0, 0.1, "she must not travel along her own -Z")


func test_strafe_is_relative_to_the_camera_too() -> void:
	# Camera looks down -X; the player's right is then -Z.
	_aim_camera(Vector3.LEFT)
	var start: Vector3 = _player.global_position
	Input.action_press("move_right")
	await wait_physics_frames(RUN_FRAMES)
	var travel: Vector3 = _player.global_position - start
	assert_lt(travel.z, -0.5, "'move_right' relative to a camera looking down -X is -Z")
	assert_almost_eq(travel.x, 0.0, 0.1, "strafing must not creep forward")


func test_the_default_gait_is_the_run_and_sneak_slows_her_down() -> void:
	# THE SECOND PLAYTEST'S INVERSION, stated as the thing a player's hands actually do:
	# press a direction and nothing else, and you RUN. This is the test that goes red if
	# somebody restores the old modifier sense while every constant still looks fine.
	_aim_camera(Vector3.FORWARD)
	Input.action_press("move_forward")
	await wait_physics_frames(RUN_FRAMES)
	var default_speed: float = _player.get_ground_speed()
	assert_false(_player.is_sneaking(), "nothing is held, so she is not sneaking")
	Input.action_press("sneak")
	await wait_physics_frames(RUN_FRAMES)
	var sneak_speed: float = _player.get_ground_speed()
	assert_true(_player.is_sneaking(), "holding the modifier must report as sneaking")
	# What the CONTROLLER is asserted to do: reach both commanded speeds and tell them
	# apart. What those speeds cost in animation terms is asserted once, on the constants,
	# in test_the_two_gameplay_speeds_stay_inside_their_animation_budget -- this test used
	# to re-derive the budget here as well ("must stay inside what an authored clip can
	# depict", "must not skate"), which meant the deliberate playtest decision to spend a
	# little skate had to be argued in two places at once.
	assert_almost_eq(default_speed, PlayerScript.RUN_SPEED, 0.01,
		"moving with no modifier held must settle on exactly RUN_SPEED")
	assert_almost_eq(sneak_speed, PlayerScript.SNEAK_SPEED, 0.01,
		"...and holding `sneak` must settle on exactly SNEAK_SPEED")
	assert_lt(sneak_speed, default_speed * 0.5,
		"the sneak must be substantially SLOWER than the default, not faster")

	# ...and letting go of the modifier hands her back the run, or the stealth option would
	# be a one-way trip into the slow gait.
	Input.action_release("sneak")
	await wait_physics_frames(RUN_FRAMES)
	assert_almost_eq(_player.get_ground_speed(), PlayerScript.RUN_SPEED, 0.01,
		"releasing `sneak` must put her back at RUN_SPEED")


func test_stands_still_and_stays_on_the_floor_with_no_input() -> void:
	_aim_camera(Vector3.FORWARD)
	var start: Vector3 = _player.global_position
	await wait_physics_frames(RUN_FRAMES)
	assert_true(_player.is_on_floor(), "gravity must settle her onto the floor, not through it")
	assert_almost_eq(_player.global_position.distance_to(start), 0.0, 0.05,
		"she must not drift when nothing is pressed")
	assert_almost_eq(_player.get_ground_speed(), 0.0, 0.001, "no input means no velocity")


func test_plays_idle_at_rest_and_walk_when_sneaking() -> void:
	# `sneak` held, because the walk clip is the SNEAKING gait since the second playtest --
	# a moving player with nothing held runs, and that path is covered by
	# test_plays_gallop_by_default_and_drops_to_walk_when_sneaking.
	_aim_camera(Vector3.FORWARD)
	var anim: AnimationPlayer = _player.get_animation_player()
	assert_not_null(anim, "the player's body must build with a reachable AnimationPlayer")
	await wait_physics_frames(5)
	assert_eq(anim.current_animation, "idle", "a standing player plays 'idle'")

	Input.action_press("sneak")
	Input.action_press("move_forward")
	await wait_physics_frames(RUN_FRAMES)
	assert_eq(anim.current_animation, "walk", "a sneaking player plays 'walk'")
	# PINNED TO LITERALS, NOT TO GaitScript. This assertion used to compare anim.speed_scale
	# against playback_scale_for_speed(_player.get_ground_speed()) -- the engine's answer
	# measured against the very function that produced it, so stubbing that function to
	# return a flat 1.0 made both sides 1.0 and the test still passed. Phase 1A's final
	# review found it (and the two siblings in game/scenes/test/playground.gd and
	# game/test/test_pony.gd); all three are fixed the same way.
	#
	# The numbers are derived once, by hand, from the authoring constants rather than from
	# the function under test: sneaking holds player.gd's SNEAK_SPEED, defined as exactly
	# 2.0x the `walk` clip's own 0.66 m/s = 1.32 m/s, and a clip driven at twice the speed it
	# depicts plays at 2.0x -- zero skate by construction, well inside gait.gd's 0.5..3.0
	# walk window. test_gait.gd pins 0.66 against the exporter's printed WALK_IMPLIED_SPEED,
	# so a retuned stride goes red THERE and points at these.
	assert_almost_eq(_player.get_ground_speed(), 1.32, 0.01,
		"holding 'sneak' must settle her at SNEAK_SPEED, 1.32 m/s")
	assert_almost_eq(anim.speed_scale, 2.0, 0.01,
		"...and 1.32 m/s of a 0.66 m/s clip is exactly 2.0x playback -- a literal, because "
		+ "asking Gait for the expected value is what made this check a tautology")


func test_plays_gallop_by_default_and_drops_to_walk_when_sneaking() -> void:
	# The clip choice is Gait's, not this controller's, but the wiring between them is
	# exactly what a future edit to _update_animation() would break -- so assert the
	# observable end of it: move with nothing held, get the gallop clip, at the rate that
	# keeps its hooves as planted as 5.2 m/s allows.
	_aim_camera(Vector3.FORWARD)
	var anim: AnimationPlayer = _player.get_animation_player()
	assert_not_null(anim, "the player's body must build with a reachable AnimationPlayer")
	Input.action_press("move_forward")
	await wait_physics_frames(RUN_FRAMES)

	var speed: float = _player.get_ground_speed()
	assert_gt(speed, GaitScript.GALLOP_HANDOVER_SPEED,
		"the default gait must be past the speed the walk clip can depict")
	assert_eq(anim.current_animation, "gallop", "above the walk band she plays 'gallop'")
	# Same tautology, same fix, one band up. The second playtest bought running its speed-up
	# (4.8 -> 5.2 m/s) at the cost of headroom: 5.2 / 3.3 = 1.576x would be the honest rate,
	# but gait.gd's gallop window tops out at GALLOP_MAX_PLAYBACK (1.3x) before the legs
	# start reading as a blur, and player.gd's own comment is explicit that RUN_SPEED is
	# DEFINED as the clip saturated at that bound, not merely clamped incidentally. The
	# expected playback is therefore that bound itself -- still a literal, not a call to the
	# gallop playback helper, so a build that broke the clamp (or unclamped it) cannot mark
	# its own homework here.
	assert_almost_eq(speed, 5.2, 0.01,
		"moving with nothing held must settle her at RUN_SPEED, 5.2 m/s")
	assert_almost_eq(anim.speed_scale, 1.3, 0.01,
		"gallop playback must be scaled to ground speed too, not left at 1.0 -- and the "
		+ "expected rate is a literal (GALLOP_MAX_PLAYBACK), not the helper itself")

	# ...and down to the walk clip when she creeps. A handover that only worked upwards
	# would leave her galloping on the spot at 1.32 m/s, which no headless distance check
	# would notice.
	Input.action_press("sneak")
	await wait_physics_frames(RUN_FRAMES)
	assert_eq(anim.current_animation, "walk", "holding 'sneak' must drop her to 'walk'")
