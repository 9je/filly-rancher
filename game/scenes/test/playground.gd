extends Node3D
## Task 4 verification scene: a ground plane, a light, a fixed camera and the player.
##
## Windowed, this is the scene the owner plays to judge feel -- WASD/left stick to
## move, Shift/LB to gallop, Space/A to jump, and a low ledge off to the right at
## x=+5 to jump onto. The camera is fixed and deliberately dumb; Task 5 replaces it
## with a real spring-arm rig.
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
## The camera looks down the -Z axis, so "forward" for the player is -Z: a controller
## that ignored the camera basis and used its own -Z would pass by coincidence here,
## which is why the camera-relative behaviour is additionally covered by the GUT test
## in game/test/test_player.gd against a rotated camera.

const GaitScript := preload("res://systems/gait.gd")
const PlayerScript := preload("res://actors/player/player.gd")

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
	var expected_scale := GaitScript.playback_scale_for_speed(_drive_speed)

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
		"scaled walk playback to its ground speed": is_equal_approx(_drive_scale, expected_scale),
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
