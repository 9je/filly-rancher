extends Node3D
## Task 4/5 verification scene: a ground plane, a light, and the player (whose
## `player.tscn` now carries its own third-person `CameraRig`, see below).
##
## Windowed, this is the scene the owner plays to judge feel -- WASD/left stick to
## run, Shift/LB to walk/sneak, Space/A to jump, mouse/right-stick to look, scroll/d-pad
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
##   Phase 1 (60 physics frames, `move_forward` held, nothing else): she must have
##     covered a plausible distance for one second at RUN_SPEED (not zero, and not a
##     runaway), travelled along the CAMERA's forward axis rather than her own or some
##     world axis, still be on the floor, still be at ground level (so falling through
##     the world fails rather than reading as "moved a long way"), and be playing the
##     clip game/systems/gait.gd picks for her speed at the rate it prescribes.
##
##     RUN_SPEED, not the walk, since the second playtest: running is the DEFAULT gait
##     now and `sneak` (Shift) is the held modifier. That is the whole reason this scene
##     drives with no modifier and expects the `gallop` clip.
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

# game/systems/gait.gd is deliberately NOT preloaded here any more. This gate's clip and
# playback checks used to call into it for their own expected values, which made them
# tautologies (see EXPECTED_DRIVE_SCALE below); the expected values are literals now, so a
# gate that cannot reach Gait at all is exactly the property that keeps them honest.
const PlayerScript := preload("res://actors/player/player.gd")
const GateWatchdogScript := preload("res://scripts/gate_watchdog.gd")

## One second at 60 Hz, per the task brief's "~60 physics frames of forward input".
const DRIVE_FRAMES := 60
## A second of no input at all, to prove she stops rather than drifts.
const COAST_FRAMES := 60

## Bounds on the distance covered during phase 1, as fractions of one second at
## Player.RUN_SPEED.
##
## DERIVED RATHER THAN TYPED, and that is a fix rather than a flourish: they were hard
## numbers (1.0 and 1.6) sized against a 1.32 m/s walk, and when the first playtest raised
## the walk to 1.65 m/s they survived only because the new distance happened to land inside
## the old window with 0.2 m to spare. A check that keeps passing by luck through a retune
## it was not updated for is one retune away from passing through a real regression -- and
## the second playtest proved the point by quadrupling the speed this phase measures. The
## band is what has to hold: she covers most of a second's travel (the acceleration ramp
## from a standstill eats the rest) and cannot cover more than all of it.
##
## The floor moved 0.70 -> 0.60 with the speed. It is not a loosening: the acceleration
## ramp costs a FIXED distance (v^2/2a, plus the first few frames at `air_control` while
## she drops the 0.1 m she is spawned above the plane), and the second of travel it is
## subtracted from grew by 3.2x -- so the same physics now eats a bigger FRACTION. Measured
## at 5.2 m/s the run covers 3.50 m of a possible 5.20, i.e. 0.674, so this floor sits
## 0.38 m under a correct run -- the same absolute slack 0.70 left under the old walk's
## 1.44 m of 1.65.
##
## Still narrow enough to fail on everything it was written to fail on: a stationary
## player, one stuck at the sneak speed (Player.SNEAK_SPEED is a quarter of this, and 0.25
## is nowhere near 0.60), and one in freefall.
const MIN_DRIVE_FRACTION := 0.60
const MAX_DRIVE_FRACTION := 1.06

## THE CLIP AND PLAYBACK RATE THIS GATE IS PINNED AGAINST -- LITERALS, AND THAT MATTERS.
##
## These checks used to ask gait.gd itself for the clip and the rate they then compared the
## engine's answer against -- the answer measured against the very functions that produced
## it. Stub the playback helper to return a flat 1.0 and BOTH sides become 1.0 and the gate
## still printed PLAYER_OK: a tautology, and the sixth gate in this project found measuring
## nothing (Phase 1A's final review found this one and its two siblings in
## game/test/test_player.gd and game/test/test_pony.gd; all three are fixed the same way).
##
## The numbers below are derived by hand, once, here, and never from the function under
## test. Running is the DEFAULT gait since the second playtest, so this phase drives at
## player.gd's RUN_SPEED = 5.2 m/s. That is past the gallop handover, so Gait's ladder picks
## `gallop`, whose clip depicts 3.30 m/s. The honest rate would be 5.2 / 3.3 = 1.576x, but
## the gallop window tops out at GALLOP_MAX_PLAYBACK (1.3x) before the legs read as a blur
## -- and player.gd's own comment is explicit that RUN_SPEED is DEFINED as that clip
## saturated at the bound, not merely clamped incidentally. So 1.3 is the expected rate, as
## a literal. game/test/test_gait.gd pins the clip speeds themselves against the exporter's
## printed GALLOP_IMPLIED_SPEED, so a retuned stride goes red THERE first and tells you to
## change these.
const EXPECTED_DRIVE_CLIP := "gallop"
const EXPECTED_DRIVE_SPEED := 5.2
const EXPECTED_DRIVE_SCALE := 1.3
## Tolerances: she reaches RUN_SPEED exactly (move_toward clamps to the target) and holds
## it, so these only have to absorb float noise, not a ramp.
const DRIVE_SPEED_TOLERANCE := 0.01
const DRIVE_SCALE_TOLERANCE := 0.01

## How far off the commanded axis she may drift over phase 1.
const MAX_LATERAL_DRIFT := 0.1
## Residual speed allowed once stopped. (How far she may COAST is not a constant any more
## -- braking distance is v^2/2a and the speed it is measured from just went up by 3.9x,
## so _finish() derives it from her actual speed and her own `deceleration` instead. A
## typed 0.15 m here was sized for a 1.65 m/s walk and would fail a correct build.)
const MAX_RESIDUAL_SPEED := 0.02
## Slack on that derived braking distance, in metres: one frame of travel plus a little.
const COAST_TOLERANCE := 0.1
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
	# The expected clip and rate were computed from gait.gd right here -- that was the
	# tautology (see EXPECTED_DRIVE_SCALE above): the engine's answer compared against the
	# very functions that produced it. They are literals now, and Gait is unreachable from
	# this gate at all, which is what keeps them honest.
	# Braking distance for the speed she was ACTUALLY at, using her OWN deceleration --
	# both of which changed under this check once without it noticing (see the constants).
	var coast_budget: float = pow(_drive_speed, 2.0) / (2.0 * player.deceleration) + COAST_TOLERANCE

	print("PLAYER drive dist=%.3f window=[%.3f, %.3f] travel=(%.3f, %.3f, %.3f) speed=%.3f on_floor=%s clip=%s scale=%.3f" % [
		dist, PlayerScript.RUN_SPEED * MIN_DRIVE_FRACTION,
		PlayerScript.RUN_SPEED * MAX_DRIVE_FRACTION,
		travel.x, travel.y, travel.z, _drive_speed, _drive_on_floor, _drive_clip, _drive_scale
	])
	print("PLAYER coast dist=%.4f budget=%.4f residual_speed=%.4f y=%.4f clip=%s" % [
		coast_dist, coast_budget, residual, player.global_position.y, rest_clip
	])

	# One second of running, bounded as a fraction of the run speed -- see the constants.
	var min_dist: float = PlayerScript.RUN_SPEED * MIN_DRIVE_FRACTION
	var max_dist: float = PlayerScript.RUN_SPEED * MAX_DRIVE_FRACTION

	var checks := {
		"moved a plausible distance": dist >= min_dist and dist <= max_dist,
		"moved along the camera's forward axis (-Z)": travel.z <= -min_dist,
		"did not drift sideways": absf(travel.x) <= MAX_LATERAL_DRIFT,
		"was on the floor while driving": _drive_on_floor,
		"stayed at ground level": absf(player.global_position.y) <= MAX_GROUND_OFFSET,
		"is on the floor at rest": player.is_on_floor(),
		"played the clip her default running speed calls for": _drive_clip == EXPECTED_DRIVE_CLIP,
		# Two halves, and both are needed. The speed check is what gives the scale check its
		# teeth: pinning the rate alone would still pass if she were ambling at some other
		# speed and the rate happened to saturate at 1.3 anyway.
		"held exactly RUN_SPEED while driving":
			absf(_drive_speed - EXPECTED_DRIVE_SPEED) <= DRIVE_SPEED_TOLERANCE,
		"scaled gallop playback to the rate 5.2 m/s saturates at":
			absf(_drive_scale - EXPECTED_DRIVE_SCALE) <= DRIVE_SCALE_TOLERANCE,
		"stopped instead of drifting": coast_dist <= coast_budget,
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
