extends GutTest
## THE LEASH MUST NOT MAKE A PONY JUDDER ON THE SPOT.
##
## The playtest report was "as i type this ponies are standing in place spazzing out" --
## ponies rooted to one spot, twitching, while the player stood still. It is a leash bug,
## not an animation or a rig bug: Pony._leash() used to be a DISCONTINUOUS steering field,
## and a pony whose reaction state wanted to take her outward across her roam circle got
## caught in its discontinuity and limit-cycled there.
##
## The two discontinuities, both measured before they were fixed (see the probe numbers in
## the commit message):
##
##   1. ACROSS THE CIRCLE. Inside `roam_radius` the leash did nothing at all, so she drove
##      outward at full speed; one centimetre outside it, a purely outward direction was
##      turned into `-outward` -- a 180-degree reversal at full speed, in one frame. A
##      CURIOUS pony walking toward a player who stands outside her territory crossed that
##      line, was flung back inside, walked out again, and never stopped: in a sweep over
##      ten stand-still geometries her velocity reversed 31 to 49 times in 400 physics
##      frames while she covered 7 to 100 cm of ground, and her model whipped through most
##      of a half-turn about three times a second. A SHY pony fleeing a player standing ON
##      her home did the same thing in mirror image (24 reversals for 14 cm of travel).
##
##   2. ACROSS THE HOME->TARGET RAY. Outside the circle the leftover tangential component
##      was NORMALIZED, so it stayed at full magnitude right up to the instant it flipped
##      sign. That made the home->player ray an attractor she could only oscillate about,
##      never settle on -- which is why the APPROACH case above judders at every bearing,
##      not merely at the exactly-radial one.
##
## So the property under test is CONTINUITY OF THE STEERING FIELD, in both position and
## direction, plus the behaviour that follows from it. Continuity is the durable statement:
## a snapshot of where a pony ends up would go stale the first time a speed constant moved,
## whereas "a hair's-breadth change in where she stands cannot reverse where she steers" is
## true of any correct leash. The behavioural tests are here because continuity is
## necessary and not sufficient -- a leash could be continuous and still park her outside
## her territory, or still fail to hold her in.
##
## Preloads by path rather than the global class_name, matching the convention documented
## at the top of game/scripts/pony_rig.gd.

const PonyScene := preload("res://actors/pony/pony.tscn")
const PonyScript := preload("res://actors/pony/pony.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")

const TEMPLATE := preload("res://data/ponies/twilight.tres")

const FLOOR_SIZE := Vector3(80.0, 1.0, 80.0)

## Her territory in these tests. Deliberately smaller than the wild default (8 m) and
## bigger than a pen's (~2 m) so it speaks for both.
const ROAM := 4.0
## A paddock-sized territory -- game/world/pen.gd leashes a resident to about this much.
## The shortest leash in the game, and so the least room the ramp below ever gets.
const PEN_ROAM := 2.0

## Physics frames given to the pony to reach whatever she is going to reach before the
## judder metric starts counting. Three seconds: long enough for a 0.56 m/s walk to cross
## the 4 m of territory in these fixtures, and long enough to be clear of the ONE
## turn-around a pony who arrives at her leash at a gallop legitimately makes. Measured:
## with the ramp in place, a pony flung at the shortest leash in the game at the fastest
## flee speed the roster can produce reverses twice in second two, once in second three,
## and never again -- so what is counted below is steady state, not the transient.
const SETTLE_FRAMES := 180
## Frames the metric is measured over. Four seconds -- the observed limit cycles ran at
## about 3 Hz, so this window holds a dozen of them.
const MEASURE_FRAMES := 240

## How many horizontal velocity reversals are tolerated in MEASURE_FRAMES. Not zero,
## because a state change or a brake overshoot inside the window is one; but every case
## below actually measures zero with the fix in, and measured 8 to 30 without it, so this
## discriminates by an order of magnitude rather than by a hair.
const MAX_REVERSALS := 3

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


# --- the root cause: the steering field must be continuous -------------------------

func test_the_leash_never_reverses_a_heading_over_a_hairs_breadth_of_movement() -> void:
	# DISCONTINUITY 1. Walk a pony radially out through her own leash boundary a
	# centimetre at a time, asking each time which way the leash would send her. The
	# steering must never jump: the pre-fix leash answered "straight out" at
	# roam_radius - 0.005 and "straight home" at roam_radius + 0.005, a 2.0-magnitude
	# flip over one centimetre of ground, which is exactly the frame-to-frame reversal
	# the playtester was watching.
	var pony := _spawn(PonyDataScript.Personality.CURIOUS, 3.4)
	var outward := Vector3(1.0, 0.0, 0.0)

	var previous: Vector3 = pony._leash(outward)
	var worst := 0.0
	var worst_at := 0.0
	var step := 0.01
	var distance := ROAM * 0.5
	while distance <= ROAM * 2.0:
		pony.global_position = Vector3(distance, pony.global_position.y, 0.0)
		var steer: Vector3 = pony._leash(outward)
		var jump: float = (steer - previous).length()
		if jump > worst:
			worst = jump
			worst_at = distance
		previous = steer
		distance += step

	assert_lt(worst, 0.05,
		"steering must change smoothly as she crosses her leash boundary -- the worst "
		+ "jump over one centimetre of ground was %.3f at r=%.3f (roam_radius %.1f)"
		% [worst, worst_at, ROAM])


func test_the_leash_never_reverses_a_heading_over_a_hairs_breadth_of_turn() -> void:
	# DISCONTINUITY 2. Stand her just outside the circle and sweep the direction she
	# WANTS through the outward ray. The pre-fix leash normalized whatever tangential
	# component was left, so the answer stayed at full magnitude and simply changed sign
	# as the wanted direction crossed the ray -- an attractor she could only buzz across.
	var pony := _spawn(PonyDataScript.Personality.CURIOUS, 3.4)
	pony.global_position = Vector3(ROAM * 1.02, pony.global_position.y, 0.0)

	var previous: Vector3 = pony._leash(Vector3(cos(-0.3), 0.0, sin(-0.3)))
	var worst := 0.0
	var angle := -0.3
	while angle <= 0.3:
		var steer: Vector3 = pony._leash(Vector3(cos(angle), 0.0, sin(angle)))
		worst = maxf(worst, (steer - previous).length())
		previous = steer
		angle += 0.002

	assert_lt(worst, 0.05,
		"steering must change smoothly as the direction she wants sweeps through the "
		+ "outward ray -- the worst jump over 0.002 rad of turn was %.3f" % worst)


# --- what that discontinuity did to a pony -----------------------------------------

func test_a_curious_pony_stopped_by_her_leash_settles_instead_of_juddering() -> void:
	# THE REPORTED BUG, in the geometry that produced it most often: the player stands
	# still OUTSIDE a CURIOUS pony's territory and inside her notice radius, so APPROACH
	# points her straight out through her own leash. Pre-fix this test measured 25
	# reversals in its 240-frame window; with the ramp in, zero.
	var pony := _spawn(PonyDataScript.Personality.CURIOUS, 3.4)
	_add_player(Vector3(ROAM + 4.0, 0.0, 0.0))
	await wait_physics_frames(SETTLE_FRAMES)

	assert_eq(pony.state, PonyScript.State.APPROACH,
		"she must actually be reacting -- a metric taken on a pony who never noticed him "
		+ "would be vacuous")
	var judder := await _measure_judder(pony)
	assert_lte(judder.reversals, MAX_REVERSALS,
		"a pony held back by her leash must settle, not judder: her velocity reversed %d "
		% judder.reversals + "times in %d frames" % MEASURE_FRAMES)
	assert_lte(judder.max_radius, ROAM + 0.5,
		"...and the leash must still hold her inside her territory while it does it")


func test_a_shy_pony_cornered_against_her_leash_settles_instead_of_juddering() -> void:
	# The mirror image: the player stands ON her home, so FLEE points her straight out
	# through the leash. Pre-fix she ran 3.6 m of path to end up 14 cm from where she
	# started; this test measured 30 reversals in its window, and zero with the ramp in.
	var pony := _spawn(PonyDataScript.Personality.SHY, 3.0)
	pony.global_position = Vector3(ROAM * 1.02, pony.global_position.y, 0.0)
	_add_player(Vector3.ZERO)
	await wait_physics_frames(SETTLE_FRAMES)

	assert_eq(pony.state, PonyScript.State.FLEE, "she must actually be fleeing")
	var judder := await _measure_judder(pony)
	assert_lte(judder.reversals, MAX_REVERSALS,
		"a cornered pony must settle, not judder: her velocity reversed %d times in %d "
		% [judder.reversals, MEASURE_FRAMES] + "frames")


func test_a_pony_whose_target_is_off_the_ray_still_arcs_around_her_territory() -> void:
	# The leash's POINT, asserted alongside the fix so a leash that stopped juddering by
	# doing nothing at all would still fail: a pony fleeing a player who is NOT on the
	# home ray must be bent around her territory rather than let out of it, and she must
	# actually travel while she does it.
	var pony := _spawn(PonyDataScript.Personality.SHY, 3.0)
	pony.global_position = Vector3(ROAM * 0.9, pony.global_position.y, 0.0)
	_add_player(Vector3(ROAM * 0.9, 0.0, -2.0))
	await wait_physics_frames(SETTLE_FRAMES)

	var judder := await _measure_judder(pony)
	assert_gt(judder.path, 1.0,
		"a fleeing pony bent along her boundary must keep moving, not stall on it")
	assert_lte(judder.max_radius, ROAM + 1.2,
		"...and must not be let out of her territory while she does it "
		+ "(ZoneMarker.ROAM_OVERSHOOT is the slack the rest of the world budgets for)")


func test_a_pony_who_hits_her_leash_at_a_gallop_does_not_bounce_off_it() -> void:
	# THE HARD CASE, and the one the tight territories in scenes/test/wild_ponies.tscn and
	# in a pen actually produce: she starts on her home with the player on the far side of
	# it, so she has a full run-up and arrives at her boundary at a gallop rather than
	# creeping onto it. A leash that only looks continuous when approached slowly would
	# still ring here (pre-fix: 8 reversals in the window; with the ramp in, zero).
	# PEN_ROAM rather than ROAM because a paddock is the shortest leash
	# anything in this game is given, and the shorter the leash the less room the ramp has;
	# base_speed 6.5 because that is the top of today's roster (Rainbow Dash), which
	# saturates flee_speed_for()'s upper clamp -- so this is the fastest arrival at the
	# shortest leash that any authored pony can produce, not merely a typical one.
	var pony := _spawn(PonyDataScript.Personality.SHY, 6.5, PEN_ROAM)
	_add_player(Vector3(-PEN_ROAM, 0.0, 0.0))
	await wait_physics_frames(SETTLE_FRAMES)

	assert_eq(pony.state, PonyScript.State.FLEE, "she must actually be fleeing")
	var judder := await _measure_judder(pony)
	assert_lte(judder.reversals, MAX_REVERSALS,
		"a pony who arrives at her leash at speed must be turned, not bounced: her "
		+ "velocity reversed %d times in %d frames" % [judder.reversals, MEASURE_FRAMES])


# --- helpers -----------------------------------------------------------------------

## Runs MEASURE_FRAMES of physics and reports how much the pony fought herself:
## `reversals` (horizontal velocity direction flips), `path` (metres actually walked)
## and `max_radius` (furthest she got from home).
func _measure_judder(pony: CharacterBody3D) -> Dictionary:
	var reversals := 0
	var path := 0.0
	var max_radius := 0.0
	var previous_velocity := Vector2(pony.velocity.x, pony.velocity.z)
	var previous_position: Vector3 = pony.global_position
	for i in range(MEASURE_FRAMES):
		await wait_physics_frames(1)
		var velocity := Vector2(pony.velocity.x, pony.velocity.z)
		if velocity.dot(previous_velocity) < 0.0:
			reversals += 1
		previous_velocity = velocity
		var moved: Vector3 = pony.global_position - previous_position
		path += Vector2(moved.x, moved.z).length()
		previous_position = pony.global_position
		var from_home: Vector3 = pony.global_position - pony.get_home()
		max_radius = maxf(max_radius, Vector2(from_home.x, from_home.z).length())
	return {"reversals": reversals, "path": path, "max_radius": max_radius}


## A pony whose HOME is the origin -- she is added there so _ready() records it -- with
## the short territory these tests are written against. Move her afterwards to place her
## relative to her own leash.
func _spawn(personality: int, base_speed: float, roam: float = ROAM) -> CharacterBody3D:
	var data: PonyData = TEMPLATE.duplicate()
	data.personality = personality
	data.base_speed = base_speed

	var pony: CharacterBody3D = PonyScene.instantiate()
	pony.position = Vector3.ZERO
	pony.roam_radius = roam
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	pony.set_rng(rng)
	_world.add_child(pony)
	pony.setup(data)
	return pony


## A body the DetectionArea accepts as the player via Pony.PLAYER_GROUP, exactly as
## game/test/test_pony.gd's stand-in does.
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
