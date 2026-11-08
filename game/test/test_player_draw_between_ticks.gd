extends GutTest
## Item 9 (playtest 2026-11-05: "Player tail stutters between frames while walking"): her body
## moves on the 60 Hz physics tick, so on a 144 Hz display she, the camera that follows her and
## the tail riding on her were drawn standing still for two frames and jumping on the third.
## Her Visuals and the camera pivot are now drawn between the last two ticks; her clip and her
## springs run on every drawn frame. The tail's own motion is the windowed probe
## (scenes/test/tail_frames.gd, headless reads stale bone poses); these pin the mechanism.

const PlayerScene := preload("res://actors/player/player.tscn")
const PlayerScript := preload("res://actors/player/player.gd")

const FLOOR_SIZE := Vector3(40.0, 1.0, 40.0)

var _world: Node3D
var _player: Player


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
	var cam := Camera3D.new()
	_world.add_child(cam)
	cam.global_position = Vector3(0.0, 3.0, 4.0)
	cam.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)
	cam.current = true
	_player = PlayerScene.instantiate() as Player
	_world.add_child(_player)


func after_each() -> void:
	Input.action_release(&"move_forward")


func _walk(frames: int) -> void:
	Input.action_press(&"move_forward")
	for i in frames:
		await wait_physics_frames(1)


func test_drawn_offset_lerps_back_from_the_latest_tick() -> void:
	var prev := Vector3(0.0, 0.0, 0.0)
	var curr := Vector3(0.0, 0.0, -0.09)
	assert_almost_eq(PlayerScript.drawn_offset(prev, curr, 0.0), prev - curr, Vector3.ONE * 1e-6,
		"at the start of a tick she is drawn where the last tick left her")
	assert_almost_eq(PlayerScript.drawn_offset(prev, curr, 1.0), Vector3.ZERO, Vector3.ONE * 1e-6,
		"at the end of a tick she is drawn on her body")
	assert_almost_eq(PlayerScript.drawn_offset(prev, curr, 0.4), Vector3(0.0, 0.0, 0.054), Vector3.ONE * 1e-6,
		"forty percent through, she is drawn 60% of the step behind her body")
	assert_almost_eq(PlayerScript.drawn_offset(prev, curr, 1.7), Vector3.ZERO, Vector3.ONE * 1e-6,
		"a fraction past the tick is clamped, never drawn ahead of her body")


func test_a_teleport_sized_step_is_never_blended() -> void:
	var prev := Vector3.ZERO
	var curr := Vector3(30.0, 0.0, 0.0)
	assert_eq(PlayerScript.drawn_offset(prev, curr, 0.25), Vector3.ZERO,
		"a 30 m step in one tick is a teleport: drawn where it lands")


func test_her_clip_and_springs_run_every_drawn_frame() -> void:
	var anim := _player.get_animation_player()
	assert_not_null(anim)
	assert_eq(anim.callback_mode_process, AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE,
		"her clip advances per drawn frame, on her smoothly drawn body")
	var sks := _player.visuals.find_children("*", "Skeleton3D", true, false)
	assert_gt(sks.size(), 0)
	for sk: Skeleton3D in sks:
		assert_eq(sk.modifier_callback_mode_process, Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_IDLE,
			"her springs step per drawn frame, not 60 times a second")


func test_visuals_and_camera_pivot_are_drawn_between_the_last_two_ticks() -> void:
	await _walk(40)
	var prev: Vector3 = _player.get("_tick_prev")
	var curr: Vector3 = _player.get("_tick_curr")
	assert_gt(prev.distance_to(curr), 0.02, "she is walking: the last tick moved her")
	assert_almost_eq(curr, _player.global_position, Vector3.ONE * 1e-5, "the latest tick is her body")
	var pivot_rest: Vector3 = _player.get("_pivot_rest")
	for f: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
		_player.call("_draw_between_ticks", f)
		var want := prev.lerp(curr, f)
		assert_almost_eq(_player.visuals.global_position, want, Vector3.ONE * 1e-4,
			"Visuals drawn %d%% of the way through the tick" % int(f * 100))
		assert_almost_eq(_player.camera_pivot.global_position, want + pivot_rest, Vector3.ONE * 1e-4,
			"the camera's pivot drawn with her, so she holds still on screen")


func test_the_tick_itself_sees_her_on_her_body() -> void:
	await _walk(30)
	_player.call("_draw_between_ticks", 0.0)
	assert_gt(_player.visuals.position.length(), 0.01, "drawn behind her body between ticks")
	await wait_physics_frames(1)
	# After her own tick, before any drawing: Visuals back on the body, the pivot at its rest.
	_player.call("_restore_tick_pose")
	assert_almost_eq(_player.visuals.position, Vector3.ZERO, Vector3.ONE * 1e-6)
	assert_almost_eq(_player.camera_pivot.position, _player.get("_pivot_rest"), Vector3.ONE * 1e-6)


func test_a_teleport_is_drawn_where_it_lands() -> void:
	await _walk(30)
	Input.action_release(&"move_forward")
	_player.global_position = Vector3(5.0, 0.0, 5.0)
	_player.call("_draw_between_ticks", 0.1)
	assert_almost_eq(_player.visuals.global_position, Vector3(5.0, 0.0, 5.0), Vector3.ONE * 1e-5,
		"set outside her tick: no smear back toward where she was")
	assert_almost_eq(_player.camera_pivot.global_position, Vector3(5.0, 0.0, 5.0) + _player.get("_pivot_rest"),
		Vector3.ONE * 1e-5, "and the camera lands with her")


func test_face_and_an_outside_turn_are_not_blended() -> void:
	await _walk(20)
	_player.face(PI * 0.5)
	_player.call("_draw_between_ticks", 0.2)
	assert_almost_eq(_player.visuals.rotation.y, PI * 0.5, 1e-5, "face() turns her at once")
	_player.visuals.rotation.y = -1.0
	_player.call("_draw_between_ticks", 0.3)
	assert_almost_eq(_player.visuals.rotation.y, -1.0, 1e-5,
		"a yaw set by someone else (a shot script) is kept, not blended away")


func test_off_draws_her_on_the_tick() -> void:
	await _walk(30)
	_player.draw_between_ticks = false
	_player.call("_draw_between_ticks", 0.3)
	assert_almost_eq(_player.visuals.global_position, _player.global_position, Vector3.ONE * 1e-5)


func test_a_held_body_is_reeled_on_drawn_frames_with_her() -> void:
	await wait_physics_frames(2)
	var beam: Node = _player.get_magic_beam()
	var crate := CharacterBody3D.new()
	_world.add_child(crate)
	crate.global_position = _player.global_position + Vector3(0.0, 1.0, -3.0)
	beam.call("_start_beam")
	beam.call("_begin_hold", crate)
	var target: Vector3 = beam.call("get_hold_point")
	var before := crate.global_position.distance_to(target)
	# A drawn frame between ticks: only _process runs.
	beam.call("_process", 1.0 / 144.0)
	var after := crate.global_position.distance_to(beam.call("get_hold_point"))
	assert_lt(after, before - 0.001,
		"the hold reels her on a drawn frame, so she keeps up with the drawn player")
	beam.call("release")
