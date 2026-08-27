extends Node3D
## Task 5 verification scene for CameraRig (game/actors/player/camera_rig.gd).
##
## Headless (`--headless`): runs every assertion the brief asks for -- camera is the
## viewport's current camera, `get_aim_ray()` is normalized and points where the
## camera looks, and the pitch clamp holds at both extremes -- then prints CAMERA_OK
## and quits 0 only if every check held. No rendering happens in this mode, so no
## screenshots are produced (docs/pipeline.md's `--headless` renders are blank; that is
## expected, not a bug -- see the task report for the same caveat's earlier appearance
## with terrain_probe.gd/model_gallery.gd).
##
## Offscreen (`xvfb-run tools/bin/godot --path game scenes/test/camera_test.tscn`,
## NOT `--headless`): runs the same assertions, then additionally drives the rig
## through four named poses and saves one PNG per pose so the framing can actually be
## looked at, not just asserted about:
##   01_rest.png      -- default state: yaw 0, default pitch, default zoom, open field.
##   02_pitch_up.png  -- pitch driven to PITCH_MAX_DEG, the "looking up" clamp.
##   03_pitch_down.png-- pitch driven to the -60 degree clamp (looking down).
##   04_obstacle.png  -- pitch back at the default, but a wall is moved in close
##                       behind the camera's default position so the spring arm must
##                       pull in against it -- proves the collision-aware behaviour,
##                       not just that a wall was nearby.
## Screenshots save to the directory passed via `-- --screenshot-dir=<path>`.

const CameraRigScript := preload("res://actors/player/camera_rig.gd")
const PlayerScript := preload("res://actors/player/player.gd")
const GateWatchdogScript := preload("res://scripts/gate_watchdog.gd")

## Physics frames to let SpringArm3D's collision probe settle after a pose change
## (its cast runs once per physics frame) before a screenshot is taken.
const SETTLE_FRAMES := 6

@onready var player: PlayerScript = $Player
@onready var wall: StaticBody3D = $Wall

var _rig: Node3D
var _screenshot_dir := ""


func _ready() -> void:
	GateWatchdogScript.arm(self, "CAMERA")
	_rig = player.get_camera_pivot().get_node("CameraRig")
	_build_wall()

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot-dir="):
			_screenshot_dir = arg.split("=")[1]

	# One frame for the spring arm's first collision probe against the (currently far)
	# wall and the ground, so the "rest" checks below see its settled state.
	for i in range(SETTLE_FRAMES):
		await get_tree().physics_frame

	var all_ok := true

	# --- camera is current -------------------------------------------------------
	var is_current: bool = _rig.is_camera_current()
	print("CAMERA current=", is_current)
	all_ok = all_ok and is_current

	# --- get_aim_ray(): normalized, and points where the camera actually looks ----
	var camera: Camera3D = _rig.get_node("SpringArm3D/Camera3D")
	var ray = _rig.get_aim_ray()
	var camera_forward: Vector3 = -camera.global_transform.basis.z
	var ray_direction: Vector3 = ray.direction
	var ray_origin: Vector3 = ray.origin
	var ray_len_ok: bool = is_equal_approx(ray_direction.length(), 1.0)
	var ray_points_correctly: bool = ray_direction.dot(camera_forward) > 0.9999
	print("AIM_RAY origin=", ray_origin, " direction=", ray_direction,
		" camera_forward=", camera_forward, " len_ok=", ray_len_ok, " points_ok=", ray_points_correctly)
	all_ok = all_ok and ray_len_ok and ray_points_correctly

	# --- pitch clamp holds at both extremes ---------------------------------------
	_rig.add_look_delta(0.0, deg_to_rad(-1000.0))  # huge "up" input
	var pitch_up_ok := is_equal_approx(_rig.get_look_pitch_degrees(), CameraRigScript.PITCH_MAX_DEG)
	print("PITCH_UP_CLAMP got=", _rig.get_look_pitch_degrees(), " want=", CameraRigScript.PITCH_MAX_DEG, " ok=", pitch_up_ok)
	all_ok = all_ok and pitch_up_ok

	_rig.add_look_delta(0.0, deg_to_rad(2000.0))  # huge "down" input, well past both clamps
	var pitch_down_ok := is_equal_approx(_rig.get_look_pitch_degrees(), CameraRigScript.PITCH_MIN_DEG)
	print("PITCH_DOWN_CLAMP got=", _rig.get_look_pitch_degrees(), " want=", CameraRigScript.PITCH_MIN_DEG, " ok=", pitch_down_ok)
	all_ok = all_ok and pitch_down_ok

	if DisplayServer.get_name() == "headless":
		_finish(all_ok)
		return

	# --- offscreen only: drive poses and capture ----------------------------------
	await _pose_and_capture("01_rest", _rig.default_pitch_deg)
	await _pose_and_capture("02_pitch_up", CameraRigScript.PITCH_MAX_DEG)
	await _pose_and_capture("03_pitch_down", CameraRigScript.PITCH_MIN_DEG)

	# Obstacle pose: back to the default pitch, wall moved in close behind the rig's
	# default (yaw 0) position so the spring arm must pull in against it.
	await _pose_and_capture("04_obstacle", _rig.default_pitch_deg, true)

	_finish(all_ok)


func _finish(all_ok: bool) -> void:
	if all_ok:
		print("CAMERA_OK")
	else:
		print("CAMERA_FAILED")
	get_tree().quit(0 if all_ok else 1)


## Sets the rig to an exact target pitch (in degrees) by computing the delta needed
## from wherever it currently sits -- see camera_rig.gd's add_look_delta doc for the
## sign convention this inverts.
func _set_pitch(target_deg: float) -> void:
	var current: float = _rig.get_look_pitch_degrees()
	_rig.add_look_delta(0.0, deg_to_rad(current - target_deg))


## Applies `target_pitch_deg`, optionally pulls the wall in close (`near_wall`), waits
## for the spring arm to settle, and -- offscreen only -- saves a screenshot named
## `<name>.png` under `_screenshot_dir`.
func _pose_and_capture(name: String, target_pitch_deg: float, near_wall: bool = false) -> void:
	_set_pitch(target_pitch_deg)
	wall.position.z = 1.4 if near_wall else 200.0

	for i in range(SETTLE_FRAMES):
		await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().process_frame

	if _screenshot_dir == "":
		return
	var img := get_viewport().get_texture().get_image()
	var out_path := _screenshot_dir.path_join(name + ".png")
	img.save_png(out_path)
	var arm: SpringArm3D = _rig.get_node("SpringArm3D")
	print("SCREENSHOT_SAVED ", out_path, " pose=", name,
		" spring_length=", _rig.get_zoom_distance(), " hit_length=", arm.get_hit_length(),
		" pitch=", _rig.get_look_pitch_degrees())


## A plain box behind the spawn point, far away by default -- moved close for the
## "pulled in against an obstacle" pose. Built in code rather than the .tscn purely so
## its size/material stay next to the logic that decides where it goes.
func _build_wall() -> void:
	wall.position = Vector3(0, 1.0, 200.0)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(4.0, 3.0, 0.3)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.35, 0.2)
	box.material = mat
	mesh.mesh = box
	wall.add_child(mesh)

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = box.size
	shape.shape = box_shape
	wall.add_child(shape)
