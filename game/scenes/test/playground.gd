extends Node3D
## Task 4/5 verification scene: a ground plane, a light, and the player (whose
## `player.tscn` now carries its own third-person `CameraRig`, see below).
##
## Windowed, this is the scene the owner plays to judge feel -- WASD/left stick to
## move, Shift/LB to gallop, Space/A to jump, mouse/right-stick to look, scroll/d-pad
## to zoom, Escape to release the mouse, and a low ledge off to the right at x=+5 to
## jump onto. The camera is `player.tscn`'s own `CameraRig` (Task 5,
## game/actors/player/camera_rig.gd) mounted on `CameraPivot` -- this scene no longer
## carries a separate fixed Camera3D of its own.
##
## Headless, it drives the player through a scripted two-phase run and gates on the
## result, printing PLAYER_OK dist=<metres> and quitting 0 only if every check holds.
##
## WHAT THE GATE ACTUALLY PROVES. "The player moved" on its own is a near-worthless
## assertion -- a player who fell through the floor, drifted with no input, or slid
## sideways would all pass it. So the two phases check the two halves of that:
##
##   Phase 1 (60 physics frames, `move_forward` held): she must have covered a
##     plausible distance for one second at WALK_SPEED (not zero, and not a runaway),
##     travelled along the CAMERA's forward axis rather than her own or some world
##     axis, still be on the floor, still be at ground level (so falling through the
##     world fails rather than reading as "moved a long way"), and be playing `walk`
##     at the playback rate game/systems/gait.gd prescribes for her speed.
##
##   Phase 2 (60 more frames, no input at all): she must brake to a stop and stay
##     put. Coasting more than a hand's width, or any residual velocity, fails --
##     which is what catches a controller that drifts without input.
##
## `CameraRig` starts at yaw 0 (a slight default downward pitch, but no yaw), so its
## flattened-onto-the-ground forward -- what `Player._movement_basis()` actually reads
## -- is exactly -Z: a controller that ignored the camera basis and used its own -Z
## would pass by coincidence here, which is why the camera-relative behaviour is
## additionally covered by the GUT test in game/test/test_player.gd against a rotated
## camera.

# game/systems/gait.gd is deliberately NOT preloaded here any more. This gate's playback
# check used to call into it for its own expected value, which made the check a tautology
# (see EXPECTED_DRIVE_SCALE below); the expected values are literals now, so a gate that
# cannot reach Gait at all is exactly the property that keeps them honest.
const PlayerScript := preload("res://actors/player/player.gd")
const GateWatchdogScript := preload("res://scripts/gate_watchdog.gd")

## One second at 60 Hz, per the task brief's "~60 physics frames of forward input".
const DRIVE_FRAMES := 60
## A second of no input at all, to prove she stops rather than drifts.
const COAST_FRAMES := 60

## Bounds on the distance covered during phase 1. At WALK_SPEED (1.32 m/s) with an
## acceleration of 12 m/s^2 the ramp costs ~0.073 m, so one second covers ~1.25 m.
## The window is wide enough not to be brittle and narrow enough that a stationary
## player, a galloping one, or one in freefall all fail it.
const MIN_DRIVE_DISTANCE := 1.0
const MAX_DRIVE_DISTANCE := 1.6

## THE PLAYBACK RATE PHASE 1 IS PINNED AGAINST -- A LITERAL, AND THAT MATTERS.
##
## This check used to read `is_equal_approx(_drive_scale, GaitScript.playback_scale_for_speed(
## _drive_speed))`: the engine's answer compared against the very function that produced it.
## Stub playback_scale_for_speed() to return a flat 1.0 and BOTH sides become 1.0 and the
## gate still printed PLAYER_OK -- a tautology, and the sixth gate in this project found
## measuring nothing (Phase 1A's final review found this one and its two siblings in
## game/test/test_player.gd and game/test/test_pony.gd; all three are fixed the same way).
##
## The numbers below are derived by hand, once, here, and never from the function under
## test. The player holds WALK_SPEED, which player.gd defines as exactly 2.0 x the `walk`
## clip's own 0.66 m/s speed = 1.32 m/s; a clip played at the speed it depicts, times two,
## plays at 2.0x. Both are pinned independently by game/test/test_gait.gd against the
## exporter's printed WALK_IMPLIED_SPEED, so if the authored stride or cycle is ever
## retuned, THAT file goes red first and tells you to change these.
const EXPECTED_DRIVE_SPEED := 1.32
const EXPECTED_DRIVE_SCALE := 2.0
## Tolerances: she reaches WALK_SPEED exactly (move_toward clamps to the target) and holds
## it, so these only have to absorb float noise, not a ramp.
const DRIVE_SPEED_TOLERANCE := 0.01
const DRIVE_SCALE_TOLERANCE := 0.01

## How far off the commanded axis she may drift over phase 1.
const MAX_LATERAL_DRIFT := 0.1
## How far she may coast after input stops (deceleration 18 m/s^2 from 1.32 m/s
## needs ~0.048 m), and the residual speed allowed once stopped.
const MAX_COAST_DISTANCE := 0.15
const MAX_RESIDUAL_SPEED := 0.02
## The capsule's bottom sits at the player's origin, so a player standing on the
## ground plane has y == 0. Anything outside this band is falling or floating.
const MAX_GROUND_OFFSET := 0.03

@onready var player: PlayerScript = $Player

var _headless := false
var _frames := 0
var _start := Vector3.ZERO
var _after_drive := Vector3.ZERO
var _drive_on_floor := false
var _drive_clip := ""
var _drive_scale := 0.0
var _drive_speed := 0.0


func _ready() -> void:
	GateWatchdogScript.arm(self, "PLAYER")
	if DisplayServer.get_name() != "headless":
		return
	_headless = true
	_start = player.global_position
	Input.action_press("move_forward")


func _physics_process(_delta: float) -> void:
	if not _headless:
		return
	_frames += 1

	if _frames == DRIVE_FRAMES:
		_after_drive = player.global_position
		_drive_on_floor = player.is_on_floor()
		_drive_speed = player.get_ground_speed()
		var anim: AnimationPlayer = player.get_animation_player()
		if anim != null:
			_drive_clip = anim.current_animation
			_drive_scale = anim.speed_scale
		Input.action_release("move_forward")
	elif _frames == DRIVE_FRAMES + COAST_FRAMES:
		_finish()


func _finish() -> void:
	var travel := _after_drive - _start
	var dist := Vector2(travel.x, travel.z).length()
	var coast := player.global_position - _after_drive
	var coast_dist := Vector2(coast.x, coast.z).length()
	var residual := player.get_ground_speed()
	var anim: AnimationPlayer = player.get_animation_player()
	var rest_clip: String = anim.current_animation if anim != null else ""
	print("PLAYER drive dist=%.3f travel=(%.3f, %.3f, %.3f) speed=%.3f on_floor=%s clip=%s scale=%.3f" % [
		dist, travel.x, travel.y, travel.z, _drive_speed, _drive_on_floor, _drive_clip, _drive_scale
	])
	print("PLAYER coast dist=%.4f residual_speed=%.4f y=%.4f clip=%s" % [
		coast_dist, residual, player.global_position.y, rest_clip
	])

	var checks := {
		"moved a plausible distance": dist >= MIN_DRIVE_DISTANCE and dist <= MAX_DRIVE_DISTANCE,
		"moved along the camera's forward axis (-Z)": travel.z <= -MIN_DRIVE_DISTANCE,
		"did not drift sideways": absf(travel.x) <= MAX_LATERAL_DRIFT,
		"was on the floor while driving": _drive_on_floor,
		"stayed at ground level": absf(player.global_position.y) <= MAX_GROUND_OFFSET,
		"is on the floor at rest": player.is_on_floor(),
		"played 'walk' while moving": _drive_clip == "walk",
		# Two halves, and both are needed. The speed check is what gives the scale check
		# its teeth: pinning the rate alone would still pass if she were ambling at some
		# other speed and the rate happened to land on 2.0 anyway.
		"held exactly WALK_SPEED while driving":
			absf(_drive_speed - EXPECTED_DRIVE_SPEED) <= DRIVE_SPEED_TOLERANCE,
		"scaled walk playback to 2.0x, the rate that speed honestly needs":
			absf(_drive_scale - EXPECTED_DRIVE_SCALE) <= DRIVE_SCALE_TOLERANCE,
		"stopped instead of drifting": coast_dist <= MAX_COAST_DISTANCE,
		"has no residual velocity": residual <= MAX_RESIDUAL_SPEED,
		"returned to 'idle' at rest": rest_clip == "idle",
	}

	var all_ok := true
	for label in checks:
		if not checks[label]:
			push_error("playground: FAILED check -- %s" % label)
			all_ok = false

	# Only ever print the OK marker when every check actually held -- a success marker
	# on a failed run is exactly the "success claim outrunning what was verified"
	# failure mode docs/testing.md was written to stop.
	if all_ok:
		print("PLAYER_OK dist=%.3f" % dist)
	else:
		print("PLAYER_FAILED dist=%.3f" % dist)
	get_tree().quit(0 if all_ok else 1)
