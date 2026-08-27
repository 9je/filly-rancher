extends GutTest
## Tests for the wild pony actor (game/actors/pony/pony.gd).
##
## Split deliberately in two. The first half needs no scene tree at all: the rules that
## separate the three personalities and turn a PonyData `base_speed` into a ground speed
## are pure static functions, and pinning them here means a regression in them is caught
## in milliseconds rather than being inferred from where a pony ended up 300 frames into
## scenes/test/wild_ponies.tscn. The second half does build ponies on a floor, because
## "she stops short instead of walking into him" and "the beam's hold survives gravity"
## are not statements about a function's return value.
##
## Division of labour with wild_ponies.tscn: that scene is the integration gate (a real
## seeded herd, real detection areas, real animation clips, checked in bulk); this file
## covers the rules underneath it plus the two things the scene cannot reach -- GRAZE,
## which a three-second routine window cannot be relied on to contain, and the hold
## reporting, which no wandering herd ever exercises.
##
## The hold tests below are written against the Task 8 ownership split: a pony REPORTS a
## hold (State.HELD, get_held_seconds()) and the magic beam DECIDES what it means, saying
## so with notify_captured() / break_free(). They are deliberately paranoid about the
## thing this file used to do instead -- fire captured() off its own capture_seconds
## timer -- because that was a second capture state machine underneath the beam's, and
## the check that it is really gone is a check that nothing happens.
##
## Preloads by path rather than the global class_name, matching the convention
## documented at the top of game/scripts/pony_rig.gd.

const PonyScene := preload("res://actors/pony/pony.tscn")
const PonyScript := preload("res://actors/pony/pony.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")
const PonyRigScript := preload("res://scripts/pony_rig.gd")
const GaitScript := preload("res://systems/gait.gd")

## Any real pony record, cloned and overridden per test so each case states the
## personality and speed it is about instead of depending on who is on the roster today.
## Cloned rather than authored from scratch so `model_path` stays a real, loadable model
## and the visuals actually build.
const TEMPLATE := preload("res://data/ponies/twilight.tres")

## Big enough that nothing here can walk off it.
const FLOOR_SIZE := Vector3(60.0, 1.0, 60.0)
## Long enough for the 8 m/s^2 acceleration ramp to finish and produce clear travel.
const RUN_FRAMES := 60

var _world: Node3D


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


# --- rules, no scene tree needed ----------------------------------------------------

func test_personality_chooses_the_reaction_and_bold_has_none() -> void:
	assert_eq(PonyScript.reaction_state(PonyDataScript.Personality.SHY), PonyScript.State.FLEE,
		"a SHY pony runs from the player")
	assert_eq(PonyScript.reaction_state(PonyDataScript.Personality.CURIOUS), PonyScript.State.APPROACH,
		"a CURIOUS pony walks toward the player")
	assert_eq(PonyScript.reaction_state(PonyDataScript.Personality.BOLD), PonyScript.NO_REACTION,
		"a BOLD pony ignores the player entirely")


func test_no_reaction_is_not_a_state_value() -> void:
	# If NO_REACTION ever collided with a real State, "she has no reaction" would start
	# silently meaning "transition to that state".
	assert_true(PonyScript.NO_REACTION < 0 or PonyScript.NO_REACTION >= PonyScript.State.size(),
		"NO_REACTION must not be a valid State value")


func test_wander_speed_always_lands_in_the_walk_band_with_no_skate() -> void:
	# The point of clamping rather than trusting base_speed: whatever a roster edit or a
	# Phase 3 rebalance puts in that field, a wandering pony still plays `walk` with her
	# hooves planted.
	for base_speed in [0.0, 0.5, 3.0, 3.4, 6.5, 50.0]:
		var speed: float = PonyScript.wander_speed_for(base_speed)
		assert_eq(GaitScript.clip_for_speed(speed), &"walk",
			"base_speed %s must amble in the walk band (got %.3f m/s)" % [base_speed, speed])
		assert_almost_eq(GaitScript.skate_ratio(speed), 1.0, 0.0001,
			"base_speed %s must amble without foot skate" % base_speed)


func test_flee_speed_always_lands_in_the_gallop_band_with_no_skate() -> void:
	# This is the assertion that stops the `gallop` clip quietly falling out of use: the
	# lower clamp is what makes even the most timid pony on the roster bolt fast enough
	# for the gallop clip to be the honest one.
	for base_speed in [0.0, 0.5, 3.0, 3.4, 6.5, 50.0]:
		var speed: float = PonyScript.flee_speed_for(base_speed)
		assert_eq(GaitScript.clip_for_speed(speed), &"gallop",
			"base_speed %s must flee in the gallop band (got %.3f m/s)" % [base_speed, speed])
		assert_almost_eq(GaitScript.skate_ratio(speed), 1.0, 0.0001,
			"base_speed %s must flee without foot skate" % base_speed)


func test_a_faster_pony_actually_moves_faster() -> void:
	# base_speed has to still mean something after the clamps, or it would be a field the
	# behaviour merely claims to read.
	assert_gt(PonyScript.wander_speed_for(6.5), PonyScript.wander_speed_for(3.0),
		"Rainbow Dash's base_speed must amble faster than Fluttershy's")
	assert_gt(PonyScript.flee_speed_for(6.5), PonyScript.flee_speed_for(3.0),
		"...and bolt faster too")


func test_flee_is_faster_than_wander_for_the_same_pony() -> void:
	for base_speed in [3.0, 3.4, 6.5]:
		assert_gt(PonyScript.flee_speed_for(base_speed), PonyScript.wander_speed_for(base_speed),
			"base_speed %s must flee faster than she ambles" % base_speed)


func test_state_name_covers_every_state_and_flags_anything_else() -> void:
	for value in range(PonyScript.State.size()):
		assert_eq(PonyScript.state_name(value), PonyScript.State.keys()[value])
	assert_string_contains(PonyScript.state_name(99), "INVALID")


# --- behaviour, on a floor ----------------------------------------------------------

func test_setup_builds_her_through_ponyvisuals_and_starts_on_idle() -> void:
	var pony := _spawn(PonyDataScript.Personality.BOLD, 3.4, Vector3.ZERO)
	var anim: AnimationPlayer = pony.get_animation_player()
	assert_not_null(anim, "setup() must build a body with a reachable AnimationPlayer")
	assert_eq(anim.current_animation, "idle", "a pony who has not moved yet plays 'idle'")
	assert_eq(pony.state, PonyScript.State.IDLE, "she starts in IDLE")
	# The mane/tail spring simulation is the whole reason PonyVisuals.build() is the only
	# sanctioned spawn path (docs/notes-hair-sim.md) -- assert the pony actually went
	# through it rather than that setup() loaded a .glb some other way.
	var skeleton: Skeleton3D = pony.get_node("Visuals").find_child("Skeleton3D", true, false)
	assert_not_null(skeleton, "setup() must produce a pony with a Skeleton3D")
	assert_true(skeleton.get_node_or_null(NodePath(PonyRigScript.SIMULATOR_NAME)) is SpringBoneSimulator3D,
		"the body must carry the spring-bone hair simulation PonyVisuals attaches")


func test_a_pony_left_alone_wanders_off_and_walks_while_she_does() -> void:
	var pony := _spawn(PonyDataScript.Personality.BOLD, 3.4, Vector3.ZERO)
	var start: Vector3 = pony.global_position
	await wait_physics_frames(RUN_FRAMES * 2)
	assert_gt(pony.global_position.distance_to(start), 0.5,
		"a pony with nothing to react to must still get somewhere")
	assert_almost_eq(pony.global_position.y, 0.0, 0.05,
		"...on the ground, not through it or above it")
	assert_eq(pony.get_animation_player().current_animation, "walk",
		"she plays 'walk' while ambling")
	# PINNED TO LITERALS, NOT TO GaitScript. This used to read `assert_almost_eq(
	# ...speed_scale, GaitScript.playback_scale_for_speed(pony.get_ground_speed()), 0.001)`
	# -- the engine's answer against the very function that produced it, so stubbing
	# playback_scale_for_speed() to return a flat 1.0 made both sides 1.0 and this passed
	# while measuring nothing. Phase 1A's final review found it, along with the siblings in
	# game/test/test_player.gd and game/scenes/test/playground.gd.
	#
	# Derived once, by hand: pony.gd ambles at NOMINAL_WANDER_SPEED (the `walk` clip's own
	# 0.66 m/s) scaled by base_speed / REFERENCE_BASE_SPEED, so 3.4 / 4.0 x 0.66 = 0.561 m/s
	# -- inside the clamp band at both ends, so this is a real scaled value and not a bound
	# reading itself back. 0.561 m/s of a 0.66 m/s clip is 0.85x playback. NOT 1.0, which is
	# what makes the stub above fail here rather than coincide.
	assert_almost_eq(pony.get_ground_speed(), 0.561, 0.02,
		"a base_speed 3.4 pony ambles at 0.561 m/s -- 0.85x of the walk clip's own speed")
	assert_almost_eq(pony.get_animation_player().speed_scale, 0.85, 0.01,
		"...so her walk plays at 0.85x, a literal expected value rather than whatever "
		+ "Gait would have answered for the speed we just read off her")


func test_grazing_stands_still_and_plays_idle_then_hands_back_to_idle() -> void:
	# GRAZE is the one routine state wild_ponies.tscn cannot be relied on to reach inside
	# its window, so it is driven directly here.
	var pony := _spawn(PonyDataScript.Personality.BOLD, 3.4, Vector3.ZERO)
	await wait_physics_frames(2)
	pony._transition_to(PonyScript.State.GRAZE)
	var start: Vector3 = pony.global_position
	await wait_physics_frames(30)
	assert_eq(pony.state, PonyScript.State.GRAZE, "a graze lasts at least half a second")
	assert_almost_eq(pony.global_position.distance_to(start), 0.0, 0.02,
		"a grazing pony stands still")
	assert_eq(pony.get_animation_player().current_animation, "idle",
		"a grazing pony plays 'idle'")

	# Grazing must END, or a pony who put her head down would never lift it. Polled
	# rather than sampled once at the far end of GRAZE_SECONDS: by then IDLE may already
	# have chosen a second graze, and "she is grazing again" is not the same failure as
	# "she never stopped".
	var left_the_graze := false
	for i in range(int(PonyScript.GRAZE_SECONDS.y * 60.0) + 30):
		await wait_physics_frames(1)
		if pony.state != PonyScript.State.GRAZE:
			left_the_graze = true
			break
	assert_true(left_the_graze, "grazing must end within GRAZE_SECONDS, not last forever")


func test_the_routine_picks_both_wandering_and_grazing() -> void:
	# Distribution rather than a magic seed: whatever RNG stream she is given, both
	# routine states have to be reachable, or one of them is dead code.
	var pony := _spawn(PonyDataScript.Personality.BOLD, 3.4, Vector3.ZERO)
	pony._has_wandered = true
	var seen := {}
	for i in range(200):
		seen[pony._pick_routine()] = true
	assert_true(seen.has(PonyScript.State.WANDER), "the routine must be able to pick WANDER")
	assert_true(seen.has(PonyScript.State.GRAZE), "the routine must be able to pick GRAZE")


func test_a_shy_pony_flees_and_gallops_away_from_the_player() -> void:
	var pony := _spawn(PonyDataScript.Personality.SHY, 3.0, Vector3.ZERO)
	var player := _add_player(Vector3(2.0, 0.0, 0.0))
	await wait_physics_frames(RUN_FRAMES)

	assert_eq(pony.state, PonyScript.State.FLEE, "a SHY pony flees a nearby player")
	assert_gt(pony.global_position.distance_to(player.global_position), 2.0,
		"she must put ground between them, not orbit at the same distance")
	assert_eq(pony.get_animation_player().current_animation, "gallop",
		"fleeing is what the 'gallop' clip is for")
	assert_almost_eq(pony.get_ground_speed(), PonyScript.flee_speed_for(3.0), 0.05,
		"she flees at the speed her base_speed prescribes")


func test_a_curious_pony_approaches_and_stops_short() -> void:
	var pony := _spawn(PonyDataScript.Personality.CURIOUS, 3.4, Vector3.ZERO)
	var player := _add_player(Vector3(4.0, 0.0, 0.0))
	await wait_physics_frames(RUN_FRAMES * 4)

	assert_eq(pony.state, PonyScript.State.APPROACH, "a CURIOUS pony walks up to the player")
	var gap: float = pony.global_position.distance_to(player.global_position)
	assert_almost_eq(gap, PonyScript.APPROACH_STOP_DISTANCE, 0.3,
		"she stops APPROACH_STOP_DISTANCE short rather than walking into him")
	assert_almost_eq(pony.get_ground_speed(), 0.0, 0.05, "and then stands still")


func test_a_bold_pony_ignores_the_player_completely() -> void:
	var pony := _spawn(PonyDataScript.Personality.BOLD, 6.5, Vector3.ZERO)
	_add_player(Vector3(1.5, 0.0, 0.0))
	var reacted := false
	for i in range(RUN_FRAMES * 3):
		await wait_physics_frames(1)
		if pony.state == PonyScript.State.FLEE or pony.state == PonyScript.State.APPROACH:
			reacted = true
			break
	assert_false(reacted, "a BOLD pony must never enter a reaction state")


func test_a_pony_only_reacts_to_a_player_inside_her_detection_radius() -> void:
	var pony := _spawn(PonyDataScript.Personality.SHY, 3.0, Vector3.ZERO)
	_add_player(Vector3(PonyScript.DETECTION_RADIUS + 4.0, 0.0, 0.0))
	await wait_physics_frames(RUN_FRAMES)
	assert_ne(pony.state, PonyScript.State.FLEE,
		"a player well outside DetectionArea must not spook her")


func test_a_fleeing_pony_stays_inside_her_roam_radius() -> void:
	# The leash is what stops a spooked pony running off the edge of the map when the
	# player simply stands there and refuses to leave her detection radius.
	#
	# The bound is derived rather than picked. The leash removes the OUTWARD component of
	# her intended heading the instant she crosses the boundary, but her velocity only
	# turns at ACCELERATION, so she coasts a braking distance of v^2 / 2a past it before
	# the outward component is gone. That overshoot is inherent to steering a body with
	# momentum and is not a leak: it is bounded, it does not accumulate, and it is what
	# a real animal wheeling around at a fence line looks like. What would be a leak is
	# any excursion that grows with time, which this asserts against.
	var pony := _spawn(PonyDataScript.Personality.SHY, 6.5, Vector3.ZERO)
	pony.roam_radius = 3.0
	_add_player(Vector3(0.5, 0.0, 0.0))
	var braking: float = pow(PonyScript.flee_speed_for(6.5), 2.0) / (2.0 * PonyScript.ACCELERATION)
	var worst := 0.0
	for i in range(RUN_FRAMES * 5):
		await wait_physics_frames(1)
		worst = maxf(worst, Vector2(pony.global_position.x, pony.global_position.z).length())
	assert_lt(worst, pony.roam_radius + braking + 0.2,
		"the leash must hold a fleeing pony near her territory (worst was %.2f m, bound %.2f m)" % [
			worst, pony.roam_radius + braking + 0.2
		])


func test_being_held_turns_her_physics_off_so_the_beam_owns_her() -> void:
	var pony := _spawn(PonyDataScript.Personality.SHY, 3.0, Vector3.ZERO)
	pony.set_held(true)
	assert_eq(pony.state, PonyScript.State.HELD, "set_held(true) puts her in HELD")

	# Lifted clear of the ground: if gravity or move_and_slide were still running she
	# would fall, and the beam would be fighting the character controller every frame.
	pony.global_position = Vector3(0.0, 3.0, 0.0)
	await wait_physics_frames(30)
	assert_almost_eq(pony.global_position.y, 3.0, 0.001,
		"a held pony must not fall -- the beam owns her transform")
	assert_almost_eq(pony.get_ground_speed(), 0.0, 0.001, "and must not steer herself")


func test_a_held_pony_reports_how_long_the_hold_has_lasted() -> void:
	# This is now the WHOLE of what she contributes to a capture: a clock the beam reads.
	# Pinned because the beam's struggle timer is built on it -- a get_held_seconds()
	# stuck at zero would make every pony unescapable and no other check would notice.
	var pony := _spawn(PonyDataScript.Personality.SHY, 3.0, Vector3.ZERO)
	assert_almost_eq(pony.get_held_seconds(), 0.0, 0.0001, "nobody is holding her yet")

	pony.set_held(true)
	await wait_physics_frames(30)
	var elapsed: float = pony.get_held_seconds()
	assert_almost_eq(elapsed, 0.5, 0.1,
		"30 physics frames of hold is about half a second (got %.3f)" % elapsed)

	# A fresh grab is a fresh hold, or the second pony you pick up would inherit the
	# first one's struggle clock and break free instantly.
	pony.set_held(false)
	pony.set_held(true)
	assert_almost_eq(pony.get_held_seconds(), 0.0, 0.0001, "a new hold restarts the clock")


func test_letting_go_of_a_held_pony_is_silent() -> void:
	# The capture-ownership split: set_held(false) means only "the beam stopped writing
	# her transform". Whether that was a capture or an escape is the beam's call, made
	# through notify_captured()/break_free(), and this file must not guess at it -- it
	# used to, via a capture_seconds timer of its own, and that was a second capture
	# state machine underneath the beam's.
	var pony := _spawn(PonyDataScript.Personality.SHY, 3.0, Vector3.ZERO)
	watch_signals(pony)
	pony.set_held(true)
	await wait_physics_frames(10)
	pony.set_held(false)

	assert_signal_not_emitted(pony, "escaped", "letting go is not by itself an escape")
	assert_signal_not_emitted(pony, "captured", "...nor by itself a capture")
	assert_eq(pony.state, PonyScript.State.IDLE, "she drops back into her routine")


func test_break_free_reports_an_escape_and_hands_her_physics_back() -> void:
	var pony := _spawn(PonyDataScript.Personality.SHY, 3.0, Vector3.ZERO)
	watch_signals(pony)
	pony.set_held(true)
	await wait_physics_frames(10)
	pony.break_free()

	assert_signal_emit_count(pony, "escaped", 1, "breaking free reports exactly one escape")
	assert_signal_not_emitted(pony, "captured")
	assert_eq(pony.state, PonyScript.State.IDLE, "and she is steering herself again")

	# A beam that has already let go for another reason must not be able to report a
	# second escape for the same pony.
	pony.break_free()
	assert_signal_emit_count(pony, "escaped", 1, "break_free() on a free pony is a no-op")


func test_notify_captured_reports_a_capture_and_nothing_else() -> void:
	var pony := _spawn(PonyDataScript.Personality.SHY, 3.0, Vector3.ZERO)
	watch_signals(pony)
	pony.set_held(true)
	await wait_physics_frames(5)
	pony.notify_captured()

	assert_signal_emit_count(pony, "captured", 1, "the beam's capture is reported once")
	assert_signal_not_emitted(pony, "escaped")
	assert_eq(pony.state, PonyScript.State.HELD,
		"notify_captured() reports; the beam is still holding her until it frees her")


func test_no_capture_fires_on_its_own_however_long_the_hold_lasts() -> void:
	# The landmine this refactor removed: an exported capture_seconds defaulting low (or
	# to 0) fired captured() from the pony's own _physics_process, so a beam that merely
	# picked her up had already "captured" her before it decided anything.
	var pony := _spawn(PonyDataScript.Personality.SHY, 3.0, Vector3.ZERO)
	watch_signals(pony)
	pony.set_held(true)
	await wait_physics_frames(120)

	assert_signal_not_emitted(pony, "captured",
		"a pony must never declare her own capture, no matter how long the hold runs")
	assert_signal_not_emitted(pony, "escaped")
	assert_gt(pony.get_held_seconds(), 1.5, "...while still reporting the hold honestly")


# --- helpers ------------------------------------------------------------------------

## A pony wearing a real model but the personality and base_speed this test is about.
func _spawn(personality: int, base_speed: float, position: Vector3) -> CharacterBody3D:
	var data: PonyData = TEMPLATE.duplicate()
	data.personality = personality
	data.base_speed = base_speed

	var pony: CharacterBody3D = PonyScene.instantiate()
	pony.position = position
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	pony.set_rng(rng)
	_world.add_child(pony)
	pony.setup(data)
	return pony


## A body the DetectionArea will accept as the player, via the `player` group rather
## than by being an actual player.tscn -- see Pony.PLAYER_GROUP.
func _add_player(position: Vector3) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.add_to_group(PonyScript.PLAYER_GROUP)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.3
	shape.shape = capsule
	shape.position = Vector3(0.0, 0.65, 0.0)
	body.add_child(shape)
	body.position = position
	_world.add_child(body)
	return body
