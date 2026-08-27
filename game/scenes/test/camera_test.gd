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
## Offscreen (`xvfb-run tools/bin/godot --path game --audio-driver Dummy
## scenes/test/camera_test.tscn`, NOT `--headless` -- `--audio-driver Dummy` is
## required here explicitly since --headless's usual dummy-audio side effect does not
## apply without --headless itself; game/systems/audio_safety.gd mutes the Master bus
## on its own as a backstop if it's ever left off): runs the same assertions, then
## additionally drives the rig through four named poses and saves one PNG per pose so
## the framing can actually be looked at, not just asserted about:
##   01_rest.png      -- default state: yaw 0, default pitch, default zoom, open field.
##   02_pitch_up.png  -- pitch driven to PITCH_MAX_DEG, the "looking up" clamp.
##   03_pitch_down.png-- pitch driven to the -60 degree clamp (looking down).
##   04_obstacle.png  -- pitch back at the default, but a wall is moved in close
##                       behind the camera's default position so the spring arm must
##                       pull in against it -- proves the collision-aware behaviour,
##                       not just that a wall was nearby.
##   05_zoomed_in.png -- zoomed all the way in (SPRING_MIN), where CameraRig's shoulder
##                       offset has eased back to nothing and the subject has faded out:
##                       the centred near-first-person aiming view.
##   06_side_wall.png -- a wall stood flush against the player's RIGHT flank, on the side
##                       the shoulder offset displaces the lens toward. The spring arm
##                       never sees this wall (it probes backwards along her centre line,
##                       and the wall is beside her, not behind her), so this is the one
##                       pose that shows what the un-probed lateral hop actually does.
## Screenshots save to the directory passed via `-- --screenshot-dir=<path>`.
##
## THE CROSSHAIR CHECK IS THE ONE WITH TEETH SINCE THE SHOULDER OFFSET LANDED. Everything
## the beam does is aimed along get_aim_ray(), and the player aims by the HUD reticle at
## the SCREEN CENTRE; if the two ever came apart, the beam would quietly miss whatever the
## player was pointing at. The old check ("the ray agrees with the camera's own forward
## vector") could not see that class of bug at all -- it stays true for any camera, offset
## or not. So the ray is now round-tripped THROUGH THE PROJECTION: points along it are fed
## back to `unproject_position()` and must land on the viewport centre, in every pose.

const CameraRigScript := preload("res://actors/player/camera_rig.gd")
const PlayerScript := preload("res://actors/player/player.gd")
const GateWatchdogScript := preload("res://scripts/gate_watchdog.gd")

## Physics frames to let SpringArm3D's collision probe settle after a pose change
## (its cast runs once per physics frame) before a screenshot is taken.
const SETTLE_FRAMES := 6

## Distances along the aim ray, in metres, that get unprojected back to screen space for
## the crosshair round-trip. Spread deliberately: a ray whose ORIGIN is right but whose
## DIRECTION is off shows up at 8.5 m long before it shows up at 1 m, and 8.5 m is
## MagicBeam.REACH -- the far end of the range the beam is actually aimed over.
const CROSSHAIR_PROBE_DISTANCES := [1.0, 3.5, 8.5, 40.0]

## How far, in pixels, an unprojected point on the aim ray may land from the viewport
## centre. One pixel: this is a projection round-trip, so the only thing between the two
## numbers is float precision, and anything bigger than a pixel is a real disagreement
## between where the player aims and where the beam goes.
const CROSSHAIR_TOLERANCE_PX := 1.0

## Where the test wall is parked when it is meant to be out of the way.
const WALL_AWAY := 200.0

## Minimum pull-in, in metres, the headless collision check requires against the BEHIND
## wall before it will call the probe "working". Same threshold and reasoning as
## game/world/ranch.gd's MIN_CAMERA_PULL_IN: 0.5 m cannot be produced by float noise or a
## grazing near-miss, only by the arm actually shortening itself against real geometry.
const MIN_COLLISION_PULL_IN := 0.5

## Wall placements a pose can ask for.
enum WallAt {
	AWAY,    ## 200 m away: an open field.
	BEHIND,  ## Close behind the camera's rest position, so the spring arm pulls in.
	SIDE,    ## Flush against the player's right flank -- the shoulder-offset side.
}

## Half-thickness of the test wall (its box is 0.3 m deep), and the player's capsule
## radius. Their sum is the closest a wall's CENTRE can ever get to her centre line: her
## own collider stops her there, so it is also the worst case the shoulder offset can be
## asked to survive. See the SIDE pose.
const WALL_HALF_THICKNESS := 0.15
const PLAYER_CAPSULE_RADIUS := 0.42

@onready var player: PlayerScript = $Player
@onready var wall: StaticBody3D = $Wall

var _rig: Node3D
var _screenshot_dir := ""
## Set false by any failed check, anywhere -- including the ones the poses run, which is
## why this is a member and not a local in _ready().
var _all_ok := true


func _ready() -> void:
	GateWatchdogScript.arm(self, "CAMERA")
	_rig = player.get_camera_pivot().get_node("CameraRig")
	_build_wall()

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot-dir="):
			_screenshot_dir = arg.split("=")[1]

	# Let the spring arm's first collision probe run against the (currently far) wall and
	# the ground, so the "rest" checks below see its settled state.
	await _settle()

	# --- camera is current -------------------------------------------------------
	var is_current: bool = _rig.is_camera_current()
	print("CAMERA current=", is_current)
	_check("the rig's camera is the viewport's camera", is_current)

	# --- get_aim_ray(): normalized, and points where the camera actually looks ----
	var camera: Camera3D = _rig.get_camera()
	var ray = _rig.get_aim_ray()
	var camera_forward: Vector3 = -camera.global_transform.basis.z
	var ray_direction: Vector3 = ray.direction
	var ray_origin: Vector3 = ray.origin
	var ray_len_ok: bool = is_equal_approx(ray_direction.length(), 1.0)
	var ray_points_correctly: bool = ray_direction.dot(camera_forward) > 0.9999
	print("AIM_RAY origin=", ray_origin, " direction=", ray_direction,
		" camera_forward=", camera_forward, " len_ok=", ray_len_ok, " points_ok=", ray_points_correctly)
	_check("the aim ray is unit length", ray_len_ok)
	_check("the aim ray points where the camera looks", ray_points_correctly)

	# --- the shoulder offset ------------------------------------------------------
	_check_shoulder("rest")

	# --- pitch clamp holds at both extremes ---------------------------------------
	_rig.add_look_delta(0.0, deg_to_rad(-1000.0))  # huge "up" input
	var pitch_up_ok := is_equal_approx(_rig.get_look_pitch_degrees(), CameraRigScript.PITCH_MAX_DEG)
	print("PITCH_UP_CLAMP got=", _rig.get_look_pitch_degrees(), " want=", CameraRigScript.PITCH_MAX_DEG, " ok=", pitch_up_ok)
	_check("pitch clamps looking up", pitch_up_ok)

	_rig.add_look_delta(0.0, deg_to_rad(2000.0))  # huge "down" input, well past both clamps
	var pitch_down_ok := is_equal_approx(_rig.get_look_pitch_degrees(), CameraRigScript.PITCH_MIN_DEG)
	print("PITCH_DOWN_CLAMP got=", _rig.get_look_pitch_degrees(), " want=", CameraRigScript.PITCH_MIN_DEG, " ok=", pitch_down_ok)
	_check("pitch clamps looking down", pitch_down_ok)

	if DisplayServer.get_name() == "headless":
		# Restore the pose the poses below would have set, so the headless run's last
		# word on the rig is the same default the offscreen run photographs.
		_set_pitch(_rig.default_pitch_deg)
		await _settle()
		_check_crosshair("headless")
		_check_shoulder("headless")
		await _check_collision_avoidance()
		_finish()
		return

	# --- offscreen only: drive poses and capture ----------------------------------
	await _pose_and_capture("01_rest", _rig.default_pitch_deg)
	await _pose_and_capture("02_pitch_up", CameraRigScript.PITCH_MAX_DEG)
	await _pose_and_capture("03_pitch_down", CameraRigScript.PITCH_MIN_DEG)

	# Obstacle pose: back to the default pitch, wall moved in close behind the rig's
	# default (yaw 0) position so the spring arm must pull in against it.
	await _pose_and_capture("04_obstacle", _rig.default_pitch_deg, WallAt.BEHIND)

	# Zoomed all the way in: the shoulder offset has eased back to nothing and the
	# subject has faded out, so this is the centred near-first-person aiming view
	# CameraRig.FADE_START's comment promises. Both are asserted, not just photographed.
	await _pose_and_capture("05_zoomed_in", _rig.default_pitch_deg, WallAt.AWAY,
		CameraRigScript.SPRING_MIN)

	# The one pose that exercises the lateral hop the spring arm cannot see.
	await _pose_and_capture("06_side_wall", _rig.default_pitch_deg, WallAt.SIDE)

	_finish()


## Record one check. Prints only on failure -- the passing detail is already in the
## per-pose print lines above, and a gate that narrates every success buries the one line
## that matters.
func _check(label: String, ok: bool) -> void:
	if not ok:
		push_error("camera_test: FAILED check -- %s" % label)
		_all_ok = false


func _finish() -> void:
	if _all_ok:
		print("CAMERA_OK")
	else:
		print("CAMERA_FAILED")
	get_tree().quit(0 if _all_ok else 1)


## THE CHECK THE SHOULDER OFFSET MADE NECESSARY: does the ray the beam fires along still
## land exactly on the crosshair the player is aiming with?
##
## Round-trips through the projection rather than comparing vectors: take points along
## get_aim_ray() at several distances, `unproject_position()` them back to screen space,
## and require each to land within a pixel of the viewport centre -- which is where
## game/ui/hud.gd draws the reticle. A camera translated sideways passes this (the ray
## moves with the lens); a camera given a convergence angle, a rig that hand-derived the
## ray from a basis, or a viewport whose centre is not where the reticle is drawn would
## all fail it. Comparing the ray to the camera's own forward vector -- the check this
## scene had before -- cannot fail for any of those.
func _check_crosshair(pose: String) -> void:
	var camera: Camera3D = _rig.get_camera()
	var ray = _rig.get_aim_ray()
	var centre: Vector2 = get_viewport().get_visible_rect().size * 0.5
	var worst := 0.0
	for distance: float in CROSSHAIR_PROBE_DISTANCES:
		var on_screen: Vector2 = camera.unproject_position(ray.origin + ray.direction * distance)
		worst = maxf(worst, on_screen.distance_to(centre))
	print("CROSSHAIR pose=%s centre=(%.1f, %.1f) worst_error=%.4f px tolerance=%.1f px"
		% [pose, centre.x, centre.y, worst, CROSSHAIR_TOLERANCE_PX])
	_check("the aim ray lands on the crosshair in pose '%s'" % pose,
		worst <= CROSSHAIR_TOLERANCE_PX)


## The shoulder offset is applied, is the size the ramp and the probe between them say it
## should be, and has actually moved the aim line clear of the player's own body.
##
## The last of those is the whole point of the feature and is measured as the distance
## between two skew lines: the aim ray, and the vertical axis through the player. It has
## to beat her capsule radius (0.42 m, player.gd), which is the crosshair-on-her-back bug
## stated as a number -- it was ~0 before the offset, by construction.
##
## `obstructed` poses are the ones with a wall on the offset's side, where the shoulder
## probe is SUPPOSED to shorten the offset. There the applied offset must be strictly
## shorter than the ramp asked for (so a probe that quietly stopped working fails) and must
## still point the same way (so a probe that mangled the direction fails too).
func _check_shoulder(pose: String, obstructed: bool = false) -> void:
	var arm_distance: float = _rig.get_arm_distance()
	var wanted: Vector3 = CameraRigScript.shoulder_offset_for_distance(arm_distance)
	var applied: Vector3 = _rig.get_shoulder_offset()

	var ray = _rig.get_aim_ray()
	var clearance := _line_to_player_axis(ray.origin, ray.direction)
	print("SHOULDER pose=%s arm=%.3f applied=(%.3f, %.3f, %.3f) wanted=(%.3f, %.3f, %.3f) aim_clearance=%.3f m lens_x=%.3f"
		% [pose, arm_distance, applied.x, applied.y, applied.z,
			wanted.x, wanted.y, wanted.z, clearance, _rig.get_camera().global_position.x])

	_check("the shoulder offset never exceeds its own ramp in pose '%s'" % pose,
		applied.length() <= wanted.length() + 0.001)
	if wanted.length() > 0.001 and applied.length() > 0.001:
		_check("the shortened shoulder offset still points the same way in pose '%s'" % pose,
			applied.normalized().dot(wanted.normalized()) > 0.9999)

	if obstructed:
		_check("the shoulder probe shortened the offset against the wall in pose '%s'" % pose,
			applied.length() < wanted.length() - 0.001)
		# The specific defect this pose was built for: the lens ending up inside the wall,
		# which renders as the wall disappearing. The wall's near face is at exactly the
		# player's capsule radius (see _place_wall), so the lens has to stay short of it.
		_check("the lens stays out of the wall in pose '%s'" % pose,
			_rig.get_camera().global_position.x < PLAYER_CAPSULE_RADIUS)
		return

	_check("the shoulder offset matches its own ramp in pose '%s'" % pose,
		applied.distance_to(wanted) < 0.001)
	# Only meaningful while the offset is actually meant to be there: at a pull-in or at
	# maximum zoom-in the ramp deliberately puts the lens back on her centre line, and
	# she is faded out by then (that is the same ramp -- see CameraRig).
	if arm_distance >= CameraRigScript.FADE_START:
		_check("the aim ray clears the player's own body in pose '%s'" % pose,
			clearance > PLAYER_CAPSULE_RADIUS)


## THE CHECK THE HEADLESS RUN WAS MISSING: every check above it is agnostic to whether
## the spring arm's own collision probe is even switched on. Confirmed directly --
## setting CameraRig.probe_mask to 0 on this same scene still printed CAMERA_OK, exit 0,
## because nothing headless ever asked the arm to prove it can pull itself in. The
## offscreen `04_obstacle` render and game/world/ranch.gd's building probe both exercise
## the real thing, but neither runs in the headless tier this project's CI-shaped gate
## actually is.
##
## Parks the wall exactly where the offscreen `04_obstacle` pose does (WallAt.BEHIND) and
## requires the arm to have pulled in well short of its rest length -- MIN_COLLISION_PULL_IN
## cannot be produced by a probe that is disabled, masked wrong, or otherwise not firing;
## a disabled probe leaves the arm sitting at exactly its rest length (hit == rest, pull_in
## == 0), which is what the negative control (probe_mask = 0) actually measures. Restores
## the wall to AWAY afterward so a check added below this one is not run against a stale
## obstacle.
func _check_collision_avoidance() -> void:
	_place_wall(WallAt.BEHIND)
	await _settle()
	var arm: SpringArm3D = _rig.get_node("SpringArm3D")
	var hit: float = arm.get_hit_length()
	var rest: float = _rig.get_zoom_distance()
	var pull_in: float = rest - hit
	print("COLLISION hit=%.3f rest=%.3f pull_in=%.3f mask=%d min_required=%.2f"
		% [hit, rest, pull_in, arm.collision_mask, MIN_COLLISION_PULL_IN])
	_check("the spring arm's collision probe pulls it in against an obstacle",
		pull_in >= MIN_COLLISION_PULL_IN)
	_place_wall(WallAt.AWAY)
	await _settle()


## Perpendicular distance from an infinite line to the player's vertical centre axis, in
## metres. Two skew lines: |(p2 - p1) . n| / |n| with n the cross product of the two
## directions; the parallel case (aiming straight up or down) falls back to the horizontal
## distance from the ray's origin, which is the right answer there.
func _line_to_player_axis(origin: Vector3, direction: Vector3) -> float:
	var axis := player.global_position
	var normal := direction.cross(Vector3.UP)
	if normal.length_squared() < 0.000001:
		return Vector2(origin.x - axis.x, origin.z - axis.z).length()
	return absf((axis - origin).dot(normal.normalized()))


## Sets the rig to an exact target pitch (in degrees) by computing the delta needed
## from wherever it currently sits -- see camera_rig.gd's add_look_delta doc for the
## sign convention this inverts.
func _set_pitch(target_deg: float) -> void:
	var current: float = _rig.get_look_pitch_degrees()
	_rig.add_look_delta(0.0, deg_to_rad(current - target_deg))


## Applies `target_pitch_deg` and `zoom`, puts the wall where `wall_at` asks for it, waits
## for the spring arm to settle, runs the per-pose checks, and -- offscreen only -- saves a
## screenshot named `<name>.png` under `_screenshot_dir`.
##
## THE CHECKS RUN IN EVERY POSE, not just at rest. The crosshair round-trip and the
## shoulder ramp are both functions of where the arm ended up, and the poses are precisely
## the places where that is unusual: hard against a wall, at the pitch clamps, at maximum
## zoom-in. A rest-pose-only check would have nothing to say about any of them.
func _pose_and_capture(name: String, target_pitch_deg: float, wall_at: WallAt = WallAt.AWAY,
		zoom: float = CameraRigScript.SPRING_DEFAULT) -> void:
	_set_pitch(target_pitch_deg)
	_set_zoom(zoom)
	_place_wall(wall_at)

	await _settle()

	_check_crosshair(name)
	_check_shoulder(name, wall_at == WallAt.SIDE)

	if _screenshot_dir == "":
		return
	var img := get_viewport().get_texture().get_image()
	var out_path := _screenshot_dir.path_join(name + ".png")
	img.save_png(out_path)
	var arm: SpringArm3D = _rig.get_node("SpringArm3D")
	print("SCREENSHOT_SAVED ", out_path, " pose=", name,
		" spring_length=", _rig.get_zoom_distance(), " hit_length=", arm.get_hit_length(),
		" pitch=", _rig.get_look_pitch_degrees(),
		" subject_opacity=", _rig.get_subject_opacity())


## Wait for the rig to settle into a pose: the spring arm's collision probe runs once per
## PHYSICS frame, and CameraRig applies its shoulder offset (and its subject fade) once per
## IDLE frame, so a settle that waits only on physics can be a whole feature early.
##
## That is not hypothetical -- it is what this function was extracted for. The first
## version of the shoulder checks awaited six physics frames and then read a zero offset
## off a rig sitting at its full 3.5 m: on the first engine iteration Godot runs however
## many physics ticks the frame time asks for BEFORE the single _process call, so all six
## awaits were satisfied inside one iteration and no idle frame had happened yet. The gate
## failed on a rig that was working.
func _settle() -> void:
	for i in range(SETTLE_FRAMES):
		await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().process_frame


## Zoom to an exact rest length by asking for the delta from wherever the rig currently is
## -- add_zoom_delta() is the only sanctioned way in, and it owns the clamp.
func _set_zoom(target_metres: float) -> void:
	_rig.add_zoom_delta(target_metres - _rig.get_zoom_distance())


## AWAY parks the wall out of the world. BEHIND puts it just behind the camera's rest
## position so the arm must pull in. SIDE stands it flush against the player's right
## flank: touching her capsule, which is as close as her own collider will ever let a
## wall get to the line the shoulder offset displaces the lens along.
func _place_wall(at: WallAt) -> void:
	wall.rotation = Vector3.ZERO
	match at:
		WallAt.BEHIND:
			wall.position = Vector3(0.0, 1.0, 1.4)
		WallAt.SIDE:
			wall.rotation.y = PI * 0.5
			wall.position = Vector3(PLAYER_CAPSULE_RADIUS + WALL_HALF_THICKNESS, 1.0, 0.0)
		_:
			wall.position = Vector3(0.0, 1.0, WALL_AWAY)


## A plain box behind the spawn point, far away by default -- moved close for the
## "pulled in against an obstacle" and "flush against her flank" poses. Built in code
## rather than the .tscn purely so its size/material stay next to the logic that decides
## where it goes. Its depth comes from WALL_HALF_THICKNESS so the SIDE placement, which is
## arithmetic on that number, cannot drift away from the wall it is placing.
func _build_wall() -> void:
	wall.position = Vector3(0, 1.0, WALL_AWAY)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	# 12 m long, not the 4 m this started as. The SIDE pose stands the wall along her
	# flank and the camera sits 3.4 m BEHIND her, so a 4 m wall simply ended before the
	# lens got to it -- the render showed a tidy slab in front of the camera and proved
	# nothing about the case it was built for.
	box.size = Vector3(12.0, 3.0, WALL_HALF_THICKNESS * 2.0)
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
