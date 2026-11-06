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
const WorldStateScript := preload("res://systems/world_state.gd")

## Any real pony record, cloned and overridden per test so each case states the
## personality and speed it is about instead of depending on who is on the roster today.
## Cloned rather than authored from scratch so `model_path` stays a real, loadable model
## and the visuals actually build.
const TEMPLATE := preload("res://data/ponies/pokeypierce.tres")

## Big enough that nothing here can walk off it.
const FLOOR_SIZE := Vector3(60.0, 1.0, 60.0)
## Long enough for the 8 m/s^2 acceleration ramp to finish and produce clear travel.
const RUN_FRAMES := 60

## Physics frames a departure is watched for: 8 s at 60 Hz, roughly twice the time a
## 3.3 m/s exit needs to clear Pony.LEAVE_DISTANCE, and far short of LEAVE_SECONDS.
const LEAVE_WATCH_FRAMES := 480

var _world: Node3D



## A pony's own behaviour, without her quirk's (game/test/test_pony_traits.gd has those): a
## Skittish quirk doubles the notice radius these tests measure.
func before_all() -> void:
	PonyTraits.quirks_enabled = false


func after_all() -> void:
	PonyTraits.quirks_enabled = true

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


func test_a_shy_pony_notices_a_running_player_from_further_out_than_the_others() -> void:
	# HALF OF THE SECOND PLAYTEST'S INVERSION, and the half that lives in this file. SHY is
	# now the hardest personality to REACH -- she starts running 2 m before anyone else
	# would -- and the compensating half (she is the easiest to HOLD) is pinned in
	# game/test/test_magic_beam.gd. Neither is meaningful without the other, so both name
	# the other in their comments.
	var shy: float = PonyScript.notice_radius_for(PonyDataScript.Personality.SHY, false)
	var curious: float = PonyScript.notice_radius_for(PonyDataScript.Personality.CURIOUS, false)
	var bold: float = PonyScript.notice_radius_for(PonyDataScript.Personality.BOLD, false)
	assert_gt(shy, curious, "a SHY pony must spot a running player before a CURIOUS one")
	assert_gt(shy, bold, "...and before a BOLD one")
	assert_gte(curious, PonyScript.DETECTION_RADIUS,
		"nobody may notice a running player from LESS than the base radius -- that is the " +
		"number MagicBeam.MIN_DETECTION_MARGIN is asserted against")
	assert_gte(bold, PonyScript.DETECTION_RADIUS, "...including a BOLD one")


func test_sneaking_shortens_every_ponys_notice_radius_by_the_same_fraction() -> void:
	# The sneak is a multiplier rather than a subtraction on purpose: a flat "-6 m" would
	# help least against the jumpiest pony, which is backwards for a stealth option whose
	# whole purpose is getting near a Fluttershy.
	for personality in PonyDataScript.Personality.values():
		var running: float = PonyScript.notice_radius_for(personality, false)
		var sneaking: float = PonyScript.notice_radius_for(personality, true)
		assert_almost_eq(sneaking, running * PonyScript.SNEAK_NOTICE_FACTOR, 0.0001,
			"%s must lose the same FRACTION of her eyesight to a creeping player" % [
				PonyDataScript.Personality.keys()[personality]])
		assert_lt(sneaking, running,
			"sneaking must never make a pony MORE alert (%s)" % [
				PonyDataScript.Personality.keys()[personality]])


func test_the_detection_area_is_wide_enough_to_report_the_widest_notice_radius() -> void:
	# The Area3D is only the broad phase; a pony cannot notice a body the physics server
	# never told her about. If SHY_NOTICE_BONUS were ever raised past the authored sphere,
	# a SHY pony would silently stop noticing the player over the top of her own range and
	# nothing else in the project would say so.
	for personality in PonyDataScript.Personality.values():
		assert_lte(PonyScript.notice_radius_for(personality, false),
			PonyScript.DETECTION_AREA_RADIUS,
			"DetectionArea must reach at least as far as %s can notice" % [
				PonyDataScript.Personality.keys()[personality]])


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


func test_flee_speed_clears_the_gallop_handover_rather_than_sitting_on_it() -> void:
	# The clamp above does not merely reach the gallop band, it clears its lower edge by a
	# stated margin. clip_for_speed() resolves the handover downwards (`speed <
	# GALLOP_HANDOVER_SPEED` plays `walk`), so a floor set AT the handover asks for exactly
	# the speed where the walk band ends and reads as `walk` on any frame that lands a hair
	# short of the request.
	#
	# The assertion is against the FULL five per cent rather than "greater than the
	# handover", because the second form is satisfied by a floor one nanometre per second
	# above it, which would pin nothing and would pass a change that reintroduced the bug.
	# The margin is the property; assert the margin.
	var floored: float = PonyScript.flee_speed_for(0.0)
	assert_gte(floored, GaitScript.GALLOP_HANDOVER_SPEED * 1.05 - 0.000001,
		"the flee floor must clear the gallop handover by the stated five per cent")

	# The slowest base_speed on the roster, which is where the honest gallop has to start.
	var slowest: float = PonyScript.flee_speed_for(3.0)
	assert_eq(GaitScript.clip_for_speed(slowest), &"gallop",
		"the roster's slowest pony must flee in the gallop band (got %.3f m/s)" % slowest)

	# And the ceiling still holds at the other end, so no roster edit can buy foot skate.
	# Pinned against PonyScript.FLEE_TOP_SPEED, not Gait.TOP_SKATE_FREE_SPEED (see the
	# dedicated test right below this one for why that distinction is the whole point).
	assert_almost_eq(PonyScript.flee_speed_for(500.0), PonyScript.FLEE_TOP_SPEED,
		0.0001, "an absurd base_speed must still be capped at FLEE_TOP_SPEED")


## FLEE_TOP_SPEED IS PINNED AS A LITERAL, NOT READ OFF GAIT (final review F3, controller
## ruling). Before this test, the assertion above compared flee_speed_for()'s ceiling
## against Gait.TOP_SKATE_FREE_SPEED -- the very constant flee_speed_for() used to consume,
## so a retune of GALLOP_MAX_PLAYBACK moved both sides together and the check kept passing
## through a real capture-balance regression (slice R3's own animation retune, 1.3 -> 1.45,
## silently raised the fastest fliers' bolt from 4.29 to 4.785 m/s with no test catching
## it). CAPTURE BALANCE IS GAMEPLAY, NOT ANIMATION, so this pins the number by hand, once,
## here, and never from the function -- or the file -- under test.
func test_flee_speed_ceiling_is_pinned_and_does_not_track_the_animation_retune() -> void:
	assert_almost_eq(PonyScript.flee_speed_for(500.0), 4.29, 0.0001,
		"an absurd base_speed must still be capped at 4.29 m/s, the pre-slice effective " +
		"ceiling, whatever GALLOP_MAX_PLAYBACK is set to")
	assert_almost_eq(PonyScript.FLEE_TOP_SPEED, 4.29, 0.0001,
		"the constant itself is pinned at the pre-slice effective value")
	# The fast fliers the review named by name: whatever their base_speed scales to, they
	# must still clamp at 4.29, not at Gait's animation-driven ceiling.
	for base_speed in [6.0, 6.2, 6.3]:
		assert_almost_eq(PonyScript.flee_speed_for(base_speed), 4.29, 0.0001,
			"base_speed %s must clamp at the pinned ceiling, not Gait's" % base_speed)


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


func test_grazing_stands_still_and_plays_graze_then_hands_back_to_idle() -> void:
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
	assert_eq(pony.get_animation_player().current_animation, "graze",
		"a grazing pony puts her head down")

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


func test_a_resident_does_not_bolt_from_her_farmer() -> void:
	# PT4: a pen's leash is sized for a walk (Pen.roam_radius_for), so a resident must never
	# gallop: a shy one running laps of a full paddock was half of the eight-pony heap.
	var pony := _spawn(PonyDataScript.Personality.SHY, 3.0, Vector3.ZERO)
	pony.add_to_group(&"penned")
	_add_player(Vector3(2.0, 0.0, 0.0))
	await wait_physics_frames(RUN_FRAMES)
	assert_ne(pony.state, PonyScript.State.FLEE, "a penned pony stays put when her farmer comes close")


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
	_add_player(Vector3(PonyScript.DETECTION_AREA_RADIUS + 4.0, 0.0, 0.0))
	await wait_physics_frames(RUN_FRAMES)
	assert_ne(pony.state, PonyScript.State.FLEE,
		"a player well outside DetectionArea must not spook her")


func test_a_pony_ignores_a_player_who_is_inside_the_area_but_outside_her_notice_radius() -> void:
	# THE CHECK WITH THE TEETH FOR THE TWO-STAGE DETECTION. DetectionArea is now wider than
	# any personality's notice radius (it has to be -- it is one shared sphere serving the
	# widest of them), so "the area reported him" and "she can see him" became two different
	# facts. A build that went back to treating the area's enter/exit as the whole answer
	# would pass every other test in this file and fail this one: the player below is INSIDE
	# the sphere and OUTSIDE what a CURIOUS pony can notice.
	var pony := _spawn(PonyDataScript.Personality.CURIOUS, 3.4, Vector3.ZERO)
	var notice: float = PonyScript.notice_radius_for(PonyDataScript.Personality.CURIOUS, false)
	assert_lt(notice, PonyScript.DETECTION_AREA_RADIUS,
		"this test is only meaningful while some personality sees less far than the area")
	var at := (notice + PonyScript.DETECTION_AREA_RADIUS) * 0.5
	_add_player(Vector3(at, 0.0, 0.0))
	await wait_physics_frames(RUN_FRAMES)
	assert_ne(pony.state, PonyScript.State.APPROACH,
		"a player at %.2f m is inside the %.2f m area but past her %.2f m notice radius" % [
			at, PonyScript.DETECTION_AREA_RADIUS, notice])


func test_a_sneaking_player_can_get_closer_before_a_shy_pony_bolts() -> void:
	# THE SNEAK, MEASURED AS BEHAVIOUR rather than as arithmetic. The stand-in stands at a
	# distance that is inside a SHY pony's running notice radius and outside her sneaking
	# one, and the ONLY thing that changes between the two halves is what is_sneaking()
	# answers -- so a build that read the radius but never asked about the gait fails the
	# first half, and one that hard-coded "sneaking means invisible" fails the second.
	var pony := _spawn(PonyDataScript.Personality.SHY, 3.0, Vector3.ZERO)
	var running: float = PonyScript.notice_radius_for(PonyDataScript.Personality.SHY, false)
	var sneaking: float = PonyScript.notice_radius_for(PonyDataScript.Personality.SHY, true)
	var at := (running + sneaking) * 0.5
	var player := _add_player(Vector3(at, 0.0, 0.0))
	player.sneaking = true

	await wait_physics_frames(RUN_FRAMES)
	assert_ne(pony.state, PonyScript.State.FLEE,
		"a creeping player at %.2f m must not spook a SHY pony (she notices a sneak at " % at +
		"%.2f m)" % sneaking)

	player.sneaking = false
	var bolted := false
	for i in range(RUN_FRAMES):
		await wait_physics_frames(1)
		if pony.state == PonyScript.State.FLEE:
			bolted = true
			break
	assert_true(bolted,
		"...and the same player at the same spot must spook her the moment he runs " +
		"(she notices a runner at %.2f m)" % running)


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


# --- being noticed by the player ------------------------------------------------------
#
# noticed_player is what puts a character into the compendium as SEEN (the ranch's
# _on_pony_noticed, game/world/ranch.gd). SEEN happens once per character and never
# unhappens, so the signal is a latch rather than an event stream; both halves of that are
# pinned here.

func test_a_pony_who_can_see_the_player_says_so_exactly_once() -> void:
	var pony := _spawn(PonyDataScript.Personality.BOLD, 3.0, Vector3.ZERO)
	watch_signals(pony)
	# BOLD on purpose: she has no reaction to the player at all, so nothing about her state
	# machine can be what makes this pass. A latch that fired only for a pony who fled or
	# approached would leave every bold character permanently out of the book.
	_add_player(Vector3(1.0, 0.0, 0.0))
	await wait_physics_frames(RUN_FRAMES)
	assert_signal_emit_count(pony, "noticed_player", 1,
		"she is well inside every notice radius, and being noticed happens once")


func test_a_player_who_leaves_and_comes_back_does_not_notice_her_twice() -> void:
	var pony := _spawn(PonyDataScript.Personality.BOLD, 3.0, Vector3.ZERO)
	watch_signals(pony)
	var body := _add_player(Vector3(1.0, 0.0, 0.0))
	await wait_physics_frames(RUN_FRAMES)
	assert_signal_emit_count(pony, "noticed_player", 1, "the first sight of her")

	body.position = Vector3(PonyScript.DETECTION_AREA_RADIUS + 10.0, 0.0, 0.0)
	await wait_physics_frames(RUN_FRAMES)
	body.position = Vector3(1.0, 0.0, 0.0)
	await wait_physics_frames(RUN_FRAMES)
	assert_signal_emit_count(pony, "noticed_player", 1,
		"walking away and back is not a second discovery; the compendium would throw it away")


func test_a_pony_nobody_has_come_near_is_never_noticed() -> void:
	var pony := _spawn(PonyDataScript.Personality.BOLD, 3.0, Vector3.ZERO)
	watch_signals(pony)
	_add_player(Vector3(PonyScript.DETECTION_AREA_RADIUS + 10.0, 0.0, 0.0))
	await wait_physics_frames(RUN_FRAMES)
	assert_signal_emit_count(pony, "noticed_player", 0,
		"a character the player has never laid eyes on stays UNSEEN")


# --- when she appears, and when she goes home ----------------------------------------
# PonyData.available() is the whole of "this character only turns up at night, in fog,
# by the lake", and Pony.leave() is what the world does about it when the sky changes
# under a pony already standing in it. See game/test/test_spawner.gd for the two of them
# working together against a fixture roster.

func test_a_character_with_no_conditions_is_available_at_every_hour_and_sky() -> void:
	var data: PonyData = TEMPLATE.duplicate()
	data.phases = []
	data.weathers = []
	for phase in range(4):
		for weather in range(4):
			assert_true(data.available(phase, weather),
				"an unconditioned character must be drawable at phase %d weather %d"
				% [phase, weather])


func test_a_listed_phase_with_an_unlisted_weather_is_refused() -> void:
	# The AND, which is the half of the truth table an "empty means any" reading gets
	# wrong: two non empty lists are both conditions, not alternatives.
	var data: PonyData = TEMPLATE.duplicate()
	data.phases = [WorldStateScript.Phase.NIGHT]
	data.weathers = [WorldStateScript.Weather.STORM]

	assert_true(data.available(WorldStateScript.Phase.NIGHT, WorldStateScript.Weather.STORM),
		"her hour and her weather together")
	assert_false(data.available(WorldStateScript.Phase.NIGHT, WorldStateScript.Weather.CLEAR),
		"her hour, somebody else's weather")
	assert_false(data.available(WorldStateScript.Phase.DAY, WorldStateScript.Weather.STORM),
		"her weather, somebody else's hour")
	assert_false(data.available(WorldStateScript.Phase.DAY, WorldStateScript.Weather.CLEAR),
		"neither")


func test_an_empty_list_on_one_axis_still_means_any_on_that_axis() -> void:
	var nocturnal: PonyData = TEMPLATE.duplicate()
	nocturnal.phases = [WorldStateScript.Phase.NIGHT]
	nocturnal.weathers = []
	for weather in range(4):
		assert_true(nocturnal.available(WorldStateScript.Phase.NIGHT, weather),
			"a night pony keeps night hours in any weather")
		assert_false(nocturnal.available(WorldStateScript.Phase.DAY, weather),
			"and no weather makes it daytime for her")

	var foggy: PonyData = TEMPLATE.duplicate()
	foggy.phases = []
	foggy.weathers = [WorldStateScript.Weather.FOG]
	for phase in range(4):
		assert_true(foggy.available(phase, WorldStateScript.Weather.FOG),
			"a fog pony wants fog at any hour")
		assert_false(foggy.available(phase, WorldStateScript.Weather.CLEAR),
			"and will not come out under a clear sky at any hour")


func test_leave_puts_her_in_leaving_and_is_leaving_reads_back() -> void:
	var pony := _spawn(PonyDataScript.Personality.BOLD, 4.0, Vector3.ZERO)
	_add_player(Vector3(0.0, 0.0, -2.0))
	await wait_physics_frames(5)

	assert_false(pony.is_leaving(), "she is not going anywhere until she is asked to")
	assert_true(pony.leave(), "and she agrees when she is")
	assert_eq(pony.state, PonyScript.State.LEAVING)
	assert_true(pony.is_leaving())


func test_a_held_pony_refuses_to_leave() -> void:
	# The beam owns her transform and owns what happens to her next. A pony who walked out
	# of a hold would be a pony the beam could capture into the bag after she had already
	# freed her own body.
	var pony := _spawn(PonyDataScript.Personality.BOLD, 4.0, Vector3.ZERO)
	await wait_physics_frames(2)
	pony.set_held(true)

	assert_false(pony.leave(), "leave() must refuse while the beam has her")
	assert_eq(pony.state, PonyScript.State.HELD, "and must not have moved her out of HELD")
	assert_false(pony.is_leaving())


func test_a_grab_during_a_departure_wins_and_the_departure_is_cancelled() -> void:
	var pony := _spawn(PonyDataScript.Personality.BOLD, 4.0, Vector3.ZERO)
	_add_player(Vector3(0.0, 0.0, -2.0))
	await wait_physics_frames(5)
	pony.leave()
	assert_true(pony.is_leaving(), "she has set off")

	pony.set_held(true)
	assert_eq(pony.state, PonyScript.State.HELD, "the beam takes her mid departure")
	assert_false(pony.is_leaving(), "which cancels the departure")
	await wait_physics_frames(60)
	assert_true(is_instance_valid(pony),
		"and the departure must not free a pony the beam is holding")

	pony.set_held(false)
	assert_eq(pony.state, PonyScript.State.IDLE,
		"letting go drops her back into her routine, not back into the departure")


func test_a_leaving_pony_nobody_can_see_goes_at_once() -> void:
	# No player anywhere in this world, so she is already further off than the widest
	# notice radius on the roster and nothing pops out of anybody's view.
	var pony := _spawn(PonyDataScript.Personality.BOLD, 4.0, Vector3.ZERO)
	await wait_physics_frames(2)
	pony.leave()
	await wait_physics_frames(4)

	assert_false(is_instance_valid(pony),
		"a wild body with nobody watching is discarded on her next frame")


func test_a_leaving_pony_the_player_is_watching_walks_rather_than_vanishing() -> void:
	# The guarantee LEAVE_DISTANCE exists for: while she is still inside her own detection
	# area there is somebody close enough to be looking at her, so she is not allowed to
	# stop existing. A player standing 3 m off is as close as that gets.
	var pony := _spawn(PonyDataScript.Personality.BOLD, 4.0, Vector3.ZERO)
	pony.roam_radius = 2.0
	var player := _add_player(Vector3(0.0, 0.0, -3.0))
	await wait_physics_frames(5)
	var start: Vector3 = pony.global_position
	pony.leave()
	await wait_physics_frames(60)

	assert_true(is_instance_valid(pony), "she is still well inside the detection area")
	assert_true(pony.is_leaving(), "and still on her way out")
	assert_lt(pony.global_position.distance_to(player.global_position),
		PonyScript.LEAVE_DISTANCE,
		"...which is the premise of this test rather than a claim about it")
	assert_gt(pony.global_position.z, start.z + 1.0,
		"she heads directly away from the player, who is standing behind her")
	var from_home: float = Vector2(pony.global_position.x - start.x,
		pony.global_position.z - start.z).length()
	assert_gt(from_home, pony.roam_radius,
		"and she is off her leash: no other state may leave her roam circle")


func test_a_leaving_pony_is_freed_once_she_is_out_of_the_detection_area() -> void:
	# The other half of the same guarantee, and the ordinary way a departure ends. She sets
	# off 3 m from a player who does not move, and the last distance measured before she
	# goes says she covered the ground rather than being written off where she stood.
	var pony := _spawn(PonyDataScript.Personality.BOLD, 4.0, Vector3.ZERO)
	var player := _add_player(Vector3(0.0, 0.0, -3.0))
	await wait_physics_frames(5)
	pony.leave()

	var last_distance := 0.0
	var frames := 0
	# 8 s at 60 Hz: about twice what 3.3 m/s needs to clear the 14 m, and a small
	# fraction of LEAVE_SECONDS, so this cannot pass by way of the safety ceiling.
	for i in range(LEAVE_WATCH_FRAMES):
		await wait_physics_frames(1)
		frames += 1
		if not is_instance_valid(pony):
			break
		last_distance = pony.global_position.distance_to(player.global_position)

	assert_false(is_instance_valid(pony),
		"a pony past her detection radius is out of sight, and goes")
	assert_gt(last_distance, 10.0,
		"and she walked there: the last look at her had her most of the way out")
	assert_lt(float(frames) / 60.0, PonyScript.LEAVE_SECONDS,
		"the departure ended on the distance, not on the safety ceiling")


func test_a_pony_can_be_sent_to_a_named_point_rather_than_merely_away() -> void:
	var pony: Pony = _pony_on_a_floor()  # the file's existing helper
	var crate := Vector3(6.0, 0.0, 0.0)
	assert_true(pony.leave_toward(crate))
	assert_true(pony.is_leaving())
	assert_eq(pony.state, Pony.State.LEAVING)


func test_she_frees_herself_on_reaching_the_crate() -> void:
	var pony: Pony = _pony_on_a_floor()
	var ghost: WeakRef = weakref(pony)
	pony.leave_toward(pony.global_position + Vector3(2.0, 0.0, 0.0))
	for i in 600:
		await wait_physics_frames(1)
		if ghost.get_ref() == null:
			break
	assert_null(ghost.get_ref(), "arriving at the crate is what ends the walk")


func test_a_held_pony_refuses_to_be_delivered() -> void:
	var pony: Pony = _pony_on_a_floor()
	pony.set_held(true)
	assert_false(pony.leave_toward(Vector3.ZERO), "capture wins over leaving, always")
	assert_ne(pony.state, Pony.State.LEAVING)
	pony.set_held(false)


func test_grabbing_a_pony_on_her_way_to_the_crate_cancels_the_walk() -> void:
	var pony: Pony = _pony_on_a_floor()
	pony.leave_toward(pony.global_position + Vector3(20.0, 0.0, 0.0))
	pony.set_held(true)
	assert_false(pony.is_leaving(), "the beam takes her out of LEAVING")
	pony.set_held(false)
	assert_false(pony.is_leaving(), "and puts her back into her own life, not back on the walk")


func test_a_plain_departure_still_walks_away_from_the_player() -> void:
	var pony: Pony = _pony_on_a_floor()
	assert_true(pony.leave())
	assert_true(pony.is_leaving())


# --- stock ---------------------------------------------------------------------------

func test_a_pony_told_she_is_stock_carries_the_triple_and_reads_back() -> void:
	var pony: Pony = PonyScene.instantiate()
	pony.set_stock({"coat": 2, "mane": 5, "eyes": 1})
	assert_true(pony.is_stock())
	assert_eq(pony.get_stock(), {"coat": 2, "mane": 5, "eyes": 1})
	pony.free()


func test_a_named_pony_is_not_stock() -> void:
	var pony: Pony = PonyScene.instantiate()
	assert_false(pony.is_stock())
	assert_eq(pony.get_stock(), {})
	pony.free()


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
	# An earth pony, whatever the template: Pokey Pierce is a unicorn by her show race
	# (PonyTraits.CANON_RACE), and a unicorn blinks away as she bolts, which these
	# personality tests are not about.
	pony.set("race", &"earth")
	return pony


## A bare BOLD pony standing on the test floor, with no player anywhere in the world. The
## Depot delivery tests below are about leave_toward() itself, not about a personality's
## reaction, so BOLD (no reaction state) keeps the two apart.
func _pony_on_a_floor() -> Pony:
	return _spawn(PonyDataScript.Personality.BOLD, 4.0, Vector3.ZERO) as Pony


## A stand-in that can also answer is_sneaking(), which is how Pony._player_is_sneaking()
## asks about the player's gait. Deliberately NOT the real Player: driving her through
## Input.action_press() would make these ponies' behaviour depend on global engine state
## that every other test in this process shares, and what is under test here is the PONY's
## rule, not the player's input mapping. `sneaking` is a plain flag a test flips.
class Sneaker:
	extends CharacterBody3D
	var sneaking := false
	func is_sneaking() -> bool:
		return sneaking


## A body the DetectionArea will accept as the player, via the `player` group rather
## than by being an actual player.tscn -- see Pony.PLAYER_GROUP.
func _add_player(position: Vector3) -> Sneaker:
	var body := Sneaker.new()
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


## THE FLAG THE BEAM READS. A delivered pony is walking to the crate having already been
## paid for, and game/actors/player/magic_beam.gd declines to grab her; an ordinary
## departure answers false here and stays catchable. Two states that look identical from
## outside (both are LEAVING) and must not be treated identically.
func test_only_a_pony_sent_somewhere_counts_as_being_delivered() -> void:
	var pony: Pony = _pony_on_a_floor()
	assert_false(pony.is_being_delivered(), "standing in a field is not a delivery")
	pony.leave()
	assert_true(pony.is_leaving(), "she is on her way out")
	assert_false(pony.is_being_delivered(),
		"...but she chose it herself, and the beam may still have her")


func test_a_pony_pointed_at_the_crate_is_being_delivered_for_the_whole_walk() -> void:
	var pony: Pony = _pony_on_a_floor()
	pony.leave_toward(pony.global_position + Vector3(20.0, 0.0, 0.0))
	assert_true(pony.is_being_delivered(), "the walk begins under the Company's hand")
	await wait_physics_frames(10)
	assert_true(is_instance_valid(pony) and pony.is_being_delivered(),
		"and stays that way while she walks, which is when the exploit would land")
