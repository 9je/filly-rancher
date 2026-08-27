extends GutTest
## Tests for CameraRig (game/actors/player/camera_rig.gd) that don't need a full
## headless render to prove -- the render itself is checked by hand against the
## screenshots in the task report (scenes/test/camera_test.tscn), per docs/testing.md's
## "structural gates cannot see a rendering bug" caveat.
##
## Preloads by path rather than the global class_name, matching the convention
## documented at the top of game/scripts/pony_rig.gd (and followed by
## game/test/test_player.gd).

const CameraRigScene := preload("res://actors/player/camera_rig.tscn")
const CameraRigScript := preload("res://actors/player/camera_rig.gd")

var _rig: Node3D


func before_each() -> void:
	_rig = CameraRigScene.instantiate()
	add_child_autofree(_rig)


func test_camera_becomes_the_viewports_current_camera() -> void:
	assert_true(_rig.is_camera_current(),
		"the rig's own Camera3D must be the viewport's active camera once mounted")


func test_pitch_clamps_at_the_upward_extreme() -> void:
	# Negative delta_pitch = mouse/stick moved up = look up (see add_look_delta's doc).
	_rig.add_look_delta(0.0, deg_to_rad(-1000.0))
	assert_almost_eq(_rig.get_look_pitch_degrees(), CameraRigScript.PITCH_MAX_DEG, 0.01,
		"pitch must clamp at PITCH_MAX_DEG (looking up) no matter how large the input")


func test_pitch_clamps_at_the_downward_extreme() -> void:
	_rig.add_look_delta(0.0, deg_to_rad(1000.0))
	assert_almost_eq(_rig.get_look_pitch_degrees(), CameraRigScript.PITCH_MIN_DEG, 0.01,
		"pitch must clamp at PITCH_MIN_DEG (looking down) no matter how large the input")


func test_pitch_clamp_is_not_a_saturating_dead_end() -> void:
	# A naive clamp implemented by just refusing input past the limit (rather than
	# clamping the accumulated value) could get stuck slightly past the boundary and
	# never recover. Drive it hard past the top, then pull it back down by a known
	# amount, and it must land exactly where a fresh delta from the clamp would.
	_rig.add_look_delta(0.0, deg_to_rad(-1000.0))
	_rig.add_look_delta(0.0, deg_to_rad(10.0))
	assert_almost_eq(_rig.get_look_pitch_degrees(), CameraRigScript.PITCH_MAX_DEG - 10.0, 0.01,
		"pitch must resume normal accumulation immediately after leaving the clamp")


func test_small_look_delta_moves_pitch_by_exactly_the_input() -> void:
	var before: float = _rig.get_look_pitch_degrees()
	_rig.add_look_delta(0.0, deg_to_rad(-10.0))
	assert_almost_eq(_rig.get_look_pitch_degrees(), before + 10.0, 0.01,
		"a negative delta_pitch (mouse/stick moved up) must look UP")


func test_positive_yaw_delta_turns_the_view_right() -> void:
	var before: float = _rig.rotation.y
	_rig.add_look_delta(deg_to_rad(10.0), 0.0)
	# rotation.y DECREASES to turn the view right -- see camera_rig.gd's class comment
	# for the sign derivation.
	assert_lt(_rig.rotation.y, before, "a positive delta_yaw must turn the view right")


func test_look_pitch_starts_at_the_configured_default() -> void:
	assert_almost_eq(_rig.get_look_pitch_degrees(), _rig.default_pitch_deg, 0.01,
		"the rig must start at its exported default pitch, not level")


func test_sensitivity_scales_the_applied_delta() -> void:
	# Exercises the actual exported knob, not just add_look_delta's own clamp math:
	# doubling mouse_sensitivity must double the pitch moved by the same raw input.
	var rig_a := CameraRigScene.instantiate()
	var rig_b := CameraRigScene.instantiate()
	add_child_autofree(rig_a)
	add_child_autofree(rig_b)
	rig_a.mouse_sensitivity = 0.01
	rig_b.mouse_sensitivity = 0.02
	var raw_pixels := 5.0
	rig_a.add_look_delta(0.0, raw_pixels * rig_a.mouse_sensitivity)
	rig_b.add_look_delta(0.0, raw_pixels * rig_b.mouse_sensitivity)
	assert_almost_eq(rig_b.get_look_pitch_degrees() - rig_a.default_pitch_deg,
		2.0 * (rig_a.get_look_pitch_degrees() - rig_a.default_pitch_deg), 0.01,
		"doubling mouse_sensitivity must double the pitch moved by identical raw input")


func test_zoom_clamps_within_limits() -> void:
	_rig.add_zoom_delta(-100.0)
	assert_almost_eq(_rig.get_zoom_distance(), 1.2, 0.01, "zoom must clamp at SPRING_MIN")
	_rig.add_zoom_delta(100.0)
	assert_almost_eq(_rig.get_zoom_distance(), 6.5, 0.01, "zoom must clamp at SPRING_MAX")


func test_zoom_starts_at_the_default_distance() -> void:
	assert_almost_eq(_rig.get_zoom_distance(), 3.5, 0.01,
		"the rig must start at SPRING_DEFAULT, not at zero or SPRING_MIN")


func test_aim_ray_direction_is_normalized() -> void:
	var ray = _rig.get_aim_ray()
	assert_almost_eq(ray.direction.length(), 1.0, 0.0001,
		"get_aim_ray()'s direction must be unit length")


func test_aim_ray_points_where_the_camera_looks() -> void:
	# The screen-centre ray must agree with the camera's own forward vector -- if it
	# did not, Task 8's beam would visibly miss the crosshair.
	var camera: Camera3D = _rig.get_node("SpringArm3D/Camera3D")
	var ray = _rig.get_aim_ray()
	var camera_forward := -camera.global_transform.basis.z
	assert_almost_eq(ray.direction.dot(camera_forward), 1.0, 0.001,
		"the aim ray must point the same way the camera looks")
	assert_almost_eq(ray.origin.distance_to(camera.global_position), 0.0, 0.01,
		"the aim ray must originate at the camera")


func test_aim_ray_tracks_look_changes() -> void:
	var before = _rig.get_aim_ray()
	_rig.add_look_delta(deg_to_rad(45.0), 0.0)
	var after = _rig.get_aim_ray()
	assert_lt(before.direction.dot(after.direction), 0.999,
		"turning the rig must change where get_aim_ray() points")


func test_all_look_and_zoom_input_actions_exist() -> void:
	for action in ["look_left", "look_right", "look_up", "look_down", "zoom_in", "zoom_out"]:
		assert_true(InputMap.has_action(action), "project.godot must define '%s'" % action)


func test_look_and_zoom_actions_have_a_keyboard_or_mouse_and_a_gamepad_binding() -> void:
	for action in ["look_left", "look_right", "look_up", "look_down", "zoom_in", "zoom_out"]:
		var has_desktop := false
		var has_pad := false
		for event in InputMap.action_get_events(action):
			if event is InputEventKey or event is InputEventMouseButton:
				has_desktop = true
			elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
				has_pad = true
		assert_true(has_desktop, "'%s' needs a keyboard/mouse binding" % action)
		assert_true(has_pad, "'%s' needs a gamepad binding" % action)


# --- subject fade -----------------------------------------------------------------
# The fix for the camera-inside-the-pony close-up (CameraRig's FADE_START comment). The
# ramp is a pure static function precisely so the RULE can be pinned here without a
# spring arm, a wall or a rendered frame; whether it actually looks right against the
# barn is checked by game/world/ranch.gd's camera probe, which measures the opacity at a
# real pull-in, and by the render it saves.

func test_the_subject_is_fully_drawn_at_a_normal_camera_distance() -> void:
	assert_almost_eq(CameraRigScript.subject_opacity_for_distance(
		CameraRigScript.SPRING_DEFAULT), 1.0, 0.0001,
		"at the default distance the player must be drawn normally")
	assert_almost_eq(CameraRigScript.subject_opacity_for_distance(
		CameraRigScript.SPRING_MAX), 1.0, 0.0001,
		"zoomed out, the player must be drawn normally")


func test_the_subject_is_gone_once_the_camera_is_inside_her() -> void:
	# 0.73 m is the pull-in game/world/ranch.gd actually measures with the player's back
	# against the barn -- the exact case this ramp exists for.
	assert_almost_eq(CameraRigScript.subject_opacity_for_distance(0.73), 0.0, 0.0001,
		"pressed against a wall the player must not be drawn at all")
	assert_almost_eq(CameraRigScript.subject_opacity_for_distance(0.0), 0.0, 0.0001,
		"a camera at the pivot must not be looking at the inside of the subject")


func test_the_fade_is_complete_by_the_tightest_zoom_the_player_can_choose() -> void:
	# FADE_END is SPRING_MIN by construction: anything closer than the player's own
	# tightest zoom is geometry shoving the camera, and must end with her not drawn. A
	# half-transparent subject is the one state worth avoiding.
	assert_eq(CameraRigScript.FADE_END, CameraRigScript.SPRING_MIN,
		"the fade must complete exactly at the tightest selectable zoom")
	assert_almost_eq(CameraRigScript.subject_opacity_for_distance(
		CameraRigScript.SPRING_MIN), 0.0, 0.0001,
		"maximum zoom-in is a first-person view, not a ghost")


func test_the_fade_is_gradual_rather_than_a_pop() -> void:
	var mid: float = (CameraRigScript.FADE_END + CameraRigScript.FADE_START) * 0.5
	var opacity: float = CameraRigScript.subject_opacity_for_distance(mid)
	assert_gt(opacity, 0.05, "mid-band must be partially visible, not snapped off")
	assert_lt(opacity, 0.95, "mid-band must be partially faded, not snapped on")
	# Monotonic: closer is never MORE opaque.
	var previous := 0.0
	for i in range(21):
		var d: float = CameraRigScript.FADE_END - 0.2 + 0.05 * float(i)
		var here: float = CameraRigScript.subject_opacity_for_distance(d)
		assert_true(here >= previous - 0.0001,
			"opacity must never decrease as the camera backs away (at %.2f m)" % d)
		previous = here
