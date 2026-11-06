class_name GaitBlend
extends RefCounted
## STARTS, STOPS AND TURNS (FS4.2; gap list item 4: "animation is clips sped up, no
## transitions or reactions"). One per body, between its ground speed and Gait's clip:
##   - the speed her legs SHOW rises at once but falls at FALL, so a stop from a gallop is a
##     few settle steps rather than a snap to standing;
##   - stepping down, the clip goes one rung at a time (gallop, trot, walk, idle), each only
##     once a lower gait has been wanted for DWELL without a break, so the trot between is
##     seen even though its band is narrow, and a dip in speed shorter than DWELL is no
##     flicker (a one-frame trot mid gallop, found by test_footsteps);
##   - a turn faster than LEAN_FROM banks her into it, more the faster she goes.
## Gait still owns every speed band; this only decides how she moves between them.

const GaitScript := preload("res://systems/gait.gd")

## m/s per second the shown speed falls (and rises: RISE, near instant so a start is crisp).
const FALL := 12.0
const RISE := 40.0
## Seconds a lower gait must be wanted, unbroken, before she steps down a rung.
const DWELL := 0.12
## Turn rate (rad/s) under which she does not lean, roll per extra rad/s, and the cap.
const LEAN_FROM := PI / 2.0
const LEAN_PER := 0.05
const LEAN_MAX := deg_to_rad(10.0)
## Ground speed (m/s) at which the full lean applies; standing, none.
const LEAN_FULL_SPEED := 5.0
const LEAN_RESPONSE := 8.0

const LADDER: Array[StringName] = [&"idle", &"walk", &"trot", &"gallop"]

var _shown := 0.0
var _clip: StringName = &"idle"
var _below := 0.0
var _roll := 0.0


## Standing, upright, no memory of the last stride: for a body lifted, dropped or put
## somewhere rather than walked there.
func reset() -> void:
	_shown = 0.0
	_clip = &"idle"
	_below = 0.0
	_roll = 0.0


## The speed her legs show for a true ground speed of `speed`, advanced by `delta`.
func shown_speed(speed: float, delta: float) -> float:
	var s := absf(speed)
	_shown = move_toward(_shown, s, (RISE if s > _shown else FALL) * delta)
	_below += delta
	return _shown


## The clip for the shown speed: up at once, down one rung per unbroken DWELL.
func clip(shown: float, has_trot: bool) -> StringName:
	var want := GaitScript.clip_for_speed(shown, has_trot)
	var ladder := LADDER.duplicate()
	if not has_trot:
		ladder.erase(&"trot")
	var at := ladder.find(_clip)
	var to := ladder.find(want)
	if at < 0 or to >= at:
		_clip = want
		_below = 0.0
	elif _below >= DWELL:
		_clip = ladder[at - 1]
		_below = 0.0
	return _clip


## Roll (rad, about her forward axis; positive leans left) for a turn of `yaw_rate` rad/s
## at `speed` m/s, eased.
func lean(yaw_rate: float, speed: float, delta: float) -> float:
	var target := 0.0
	var over := absf(yaw_rate) - LEAN_FROM
	if over > 0.0:
		target = signf(yaw_rate) * minf(LEAN_MAX,
			over * LEAN_PER * clampf(absf(speed) / LEAN_FULL_SPEED, 0.0, 1.0))
	_roll = lerpf(_roll, target, 1.0 - exp(-LEAN_RESPONSE * delta))
	return _roll
