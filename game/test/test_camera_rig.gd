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
	var camera: Camera3D = _rig.get_camera()
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


func test_the_aim_ray_lands_on_the_screen_centre() -> void:
	# THE check the shoulder offset made necessary, and the one the two above cannot make:
	# both stay true for a camera whose ray no longer agrees with the CROSSHAIR. The HUD
	# draws its reticle at the centre of the viewport (game/ui/hud.gd), so the ray is
	# round-tripped through the projection here -- points along it, unprojected, must come
	# back to that centre. A rig that grew a convergence angle, or that hand-derived the
	# ray from a basis, would fail this and pass the others.
	var camera: Camera3D = _rig.get_camera()
	var centre: Vector2 = _rig.get_viewport().get_visible_rect().size * 0.5
	var ray = _rig.get_aim_ray()
	for distance in [1.0, 3.5, 8.5, 40.0]:
		var on_screen: Vector2 = camera.unproject_position(ray.origin + ray.direction * distance)
		assert_almost_eq(on_screen.distance_to(centre), 0.0, 1.0,
			"a point %.1f m along the aim ray must project onto the crosshair" % distance)


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
	# 0.55 m is the pull-in game/world/ranch.gd actually measures with the player's back
	# against the barn -- the exact case this ramp exists for. (0.73 m until the shoulder
	# offset nested the camera and woke the spring arm's `margin` up -- see CameraRig's
	# note on that; both are inside her, which is the point.)
	assert_almost_eq(CameraRigScript.subject_opacity_for_distance(0.55), 0.0, 0.0001,
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


# --- the shoulder offset ------------------------------------------------------------
# The fix for aiming through your own pony (CameraRig's SHOULDER_SIDE comment). Same
# split as the fade above: the RULE is a pure static function and is pinned here, while
# whether it actually reads right on screen is checked by the renders
# game/scenes/test/camera_test.tscn saves, and whether it survives a wall beside the
# camera is checked by that scene's `06_side_wall` pose.

func test_the_camera_is_off_the_players_centre_line_at_a_normal_distance() -> void:
	var offset: Vector3 = CameraRigScript.shoulder_offset_for_distance(
		CameraRigScript.SPRING_DEFAULT)
	assert_almost_eq(offset.x, CameraRigScript.SHOULDER_SIDE, 0.0001,
		"at the default zoom the camera must sit the full shoulder offset to the side")
	assert_almost_eq(offset.y, CameraRigScript.SHOULDER_LIFT, 0.0001,
		"...and the full lift above")
	assert_almost_eq(offset.z, 0.0, 0.0001,
		"the shoulder offset must not push the camera along its own view axis")


func test_the_shoulder_offset_clears_the_players_own_silhouette() -> void:
	# The whole point of the feature, as a number. Displacing the camera sideways by S
	# displaces the aim LINE sideways by S at every depth, so the crosshair misses her
	# body exactly when S beats her half-width. Her collision capsule radius is 0.42 m
	# (player.gd) and her rendered silhouette measures about the same.
	var capsule_radius := 0.42
	for distance in [CameraRigScript.FADE_START, CameraRigScript.SPRING_DEFAULT,
			CameraRigScript.SPRING_MAX, 20.0]:
		var offset: Vector3 = CameraRigScript.shoulder_offset_for_distance(distance)
		assert_gt(offset.x, capsule_radius,
			"the aim line must clear her body at an arm distance of %.1f m" % distance)


func test_the_shoulder_offset_eases_out_exactly_where_she_fades_out() -> void:
	# One ramp, not two: the offset exists to keep the crosshair off her body, so it is
	# gone by the time she is (FADE_END), and full by the time she is fully drawn
	# (FADE_START). Maximum zoom-in is therefore a CENTRED first-person view.
	assert_almost_eq(CameraRigScript.shoulder_offset_for_distance(
		CameraRigScript.SPRING_MIN).length(), 0.0, 0.0001,
		"at maximum zoom-in the camera must be back on her centre line")
	assert_almost_eq(CameraRigScript.shoulder_offset_for_distance(0.55).length(), 0.0, 0.0001,
		"shoved against the barn, the camera must not also be shoved sideways")
	assert_almost_eq(CameraRigScript.shoulder_offset_for_distance(
		CameraRigScript.FADE_START).length(),
		Vector2(CameraRigScript.SHOULDER_SIDE, CameraRigScript.SHOULDER_LIFT).length(), 0.0001,
		"the offset must be at full size by the distance she is fully drawn at")


func test_the_shoulder_offset_grows_smoothly_and_never_backwards() -> void:
	# A pop in the offset is a camera that jumps sideways, which is worse than no offset
	# at all -- and the arm jitters across this band whenever it is riding a wall.
	var previous := 0.0
	for i in range(31):
		var d: float = CameraRigScript.FADE_END - 0.2 + 0.05 * float(i)
		var here: float = CameraRigScript.shoulder_offset_for_distance(d).length()
		assert_true(here >= previous - 0.0001,
			"the offset must never shrink as the camera backs away (at %.2f m)" % d)
		previous = here
	var mid: float = (CameraRigScript.FADE_END + CameraRigScript.FADE_START) * 0.5
	var partial: float = CameraRigScript.shoulder_offset_for_distance(mid).length()
	var full := Vector2(CameraRigScript.SHOULDER_SIDE, CameraRigScript.SHOULDER_LIFT).length()
	assert_gt(partial, 0.05 * full, "mid-band must be partially offset, not snapped off")
	assert_lt(partial, 0.95 * full, "mid-band must be partially offset, not snapped on")


func test_the_offset_ramp_and_the_fade_ramp_are_the_same_ramp() -> void:
	# Stated as an equality rather than as prose, because the two are tied together by
	# design (see CameraRig.shoulder_offset_for_distance) and a later edit to one of the
	# two smoothsteps would otherwise silently untie them.
	var full := Vector2(CameraRigScript.SHOULDER_SIDE, CameraRigScript.SHOULDER_LIFT).length()
	for i in range(21):
		var d: float = CameraRigScript.FADE_END - 0.2 + 0.05 * float(i)
		assert_almost_eq(CameraRigScript.shoulder_offset_for_distance(d).length(),
			CameraRigScript.subject_opacity_for_distance(d) * full, 0.0001,
			"offset and opacity must ride the same ramp (at %.2f m)" % d)


func test_the_live_rig_applies_the_offset_its_own_ramp_asks_for() -> void:
	# The static ramp above is only half the claim: this is the half that says the rig
	# actually WRITES it onto the camera. A rig whose _process stopped running, or whose
	# offset was silently stomped by the spring arm (which overwrites its direct
	# children's transforms every physics frame -- the reason CameraMount exists), passes
	# every test above and fails this one.
	await wait_physics_frames(2)
	await wait_process_frames(2)
	var expected: Vector3 = CameraRigScript.shoulder_offset_for_distance(_rig.get_arm_distance())
	assert_almost_eq(_rig.get_shoulder_offset().distance_to(expected), 0.0, 0.001,
		"the rig must apply the offset its own ramp asks for at the current arm distance")
	assert_gt(_rig.get_shoulder_offset().x, 0.0,
		"a rig hanging in open space at its default zoom must be offset, not centred")


func test_the_lens_sits_further_out_than_the_arm_in_open_space() -> void:
	# get_arm_distance() (what the fade is driven by) and get_camera_distance() (where the
	# lens really is) are deliberately different numbers once there is an offset, and the
	# difference is exactly the offset. Driving the fade off the lens instead would feed
	# the offset back into its own input -- see CameraRig.get_arm_distance().
	await wait_physics_frames(2)
	await wait_process_frames(2)
	var arm: float = _rig.get_arm_distance()
	var lens: float = _rig.get_camera_distance()
	var offset: float = _rig.get_shoulder_offset().length()
	assert_gt(lens, arm, "the offset lens must be further from the pivot than the mount is")
	assert_almost_eq(lens, sqrt(arm * arm + offset * offset), 0.01,
		"the lens is the arm plus a perpendicular offset, so the three form a right angle")


# --- SpringArm3D margin flip (MOUNT_MIN_Z) -------------------------------------------
# The follow-up fix for a flip SpringArm3D's own margin math can cause: when it has a
# hit nearer than SPRING_ARM_MARGIN (0.2 m), the arm leaves the mount at local z = (hit
# distance - margin), which goes NEGATIVE -- through the pivot, to the FRONT of the
# player, looking back through her own body. See camera_rig.gd's MOUNT_MIN_Z comment for
# the full derivation and the throwaway scene (_proof_margin.gd, not kept in the tree)
# that measured it: hit=0.05/0.10/0.15 m against margin=0.2 m left the mount at local z
# -0.15/-0.10/-0.05 before this fix.

func test_the_mount_never_flips_in_front_of_the_pivot_on_a_close_hit() -> void:
	var rig := CameraRigScene.instantiate()
	rig.default_pitch_deg = 0.0  # straight-on ray -- keeps the geometry simple
	add_child_autofree(rig)

	# A wall placed well inside SPRING_ARM_MARGIN (0.2 m) of the pivot -- the exact regime
	# the reviewer measured the flip in (hit=0.05 m). Box is thin in Z, like
	# game/scenes/test/camera_test.gd's own wall; its near face lands at exactly 0.05 m.
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(12.0, 3.0, 0.3)
	shape.shape = box
	wall.add_child(shape)
	add_child_autofree(wall)
	wall.position = Vector3(0.0, 0.0, 0.05 + 0.15)

	# Alternated rather than "N physics frames then 2 idle frames": SpringArm3D can run
	# more than one physics tick per rendered frame (see camera_test.gd's _settle() doc,
	# which was bitten by exactly this once already), so a fixed physics/idle split can
	# land the read between the arm's last tick and this rig's next _process() clamp.
	# Alternating guarantees an idle frame follows every physics tick actually taken.
	var mount: Node3D = rig.get_node("SpringArm3D/CameraMount")
	for i in range(10):
		await wait_physics_frames(1)
		await wait_process_frames(1)

	assert_gt(mount.position.z, 0.0,
		"the mount must never end up in front of the pivot (a negative local z)")
	assert_almost_eq(mount.position.z, CameraRigScript.MOUNT_MIN_Z, 0.0001,
		"a hit well inside the margin must clamp to exactly MOUNT_MIN_Z, not float past it")


func test_invert_look_flips_pitch_and_leaves_yaw_alone() -> void:
	# `_rig` is declared as Node3D (see before_each), so its type-specific methods are
	# resolved dynamically; explicit type annotations keep GDScript from refusing to
	# infer a type for the result the way `:=` would.
	var pitch_before: float = _rig.get_look_pitch_degrees()
	var yaw_before: float = _rig.rotation.y
	_rig.add_look_delta(0.0, 0.1)
	var normal_pitch: float = _rig.get_look_pitch_degrees()
	assert_lt(normal_pitch, pitch_before, "positive delta looks down when not inverted")
	_rig.invert_look = true
	_rig.add_look_delta(0.0, 0.1)
	assert_gt(_rig.get_look_pitch_degrees(), normal_pitch, "and up when inverted")
	# The second half of the name, which nothing used to check. The setting is called
	# INVERT LOOK and players read that as "invert the vertical axis"; a build that also
	# flipped horizontal would make every one of them think the option was broken.
	assert_almost_eq(_rig.rotation.y, yaw_before, 0.000001,
		"neither look, inverted or not, may move the yaw the caller passed zero for")


## A KICK, NOT A WOBBLE (feel pass 2026-10-26): trauma rattles the lens a few centimetres
## and settles within a second, and a player who switched shake off gets none of it.
func test_trauma_shakes_the_lens_and_settles() -> void:
	_rig.add_trauma(0.6)
	_rig._apply_shake(1.0 / 60.0)
	var cam: Camera3D = _rig.get_camera()
	var off := Vector2(cam.h_offset, cam.v_offset).length()
	assert_gt(off, 0.0, "a fresh kick moves the lens")
	assert_lt(off, CameraRigScript.SHAKE_METRES + 0.001, "...by centimetres, not metres")
	for i in 90:
		_rig._apply_shake(1.0 / 60.0)
	assert_almost_eq(Vector2(cam.h_offset, cam.v_offset).length(), 0.0, 0.0001,
		"a second and a half later it has settled back to the shoulder")


func test_shake_switched_off_never_moves_the_lens() -> void:
	_rig.shake_enabled = false
	_rig.add_trauma(1.0)
	_rig._apply_shake(1.0 / 60.0)
	var cam: Camera3D = _rig.get_camera()
	assert_eq(Vector2(cam.h_offset, cam.v_offset), Vector2.ZERO)
