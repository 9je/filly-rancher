extends GutTest
## THE HOOFSTEP CADENCE, AND WHAT IT IS A FUNCTION OF.
##
## It used to be a function of DISTANCE: one sound every STEP_STRIDE (1.1 m) travelled,
## whatever the legs were doing. That is a cadence with no gesture behind it, and it is
## wrong in both directions at once. At the sneak she covers 1.32 m/s and the walk clip
## turns over 2.4 times a second, so she got one sound for every two strides. At the run she
## covers 5.2 m/s and got 4.7 sounds a second against a gallop cycle turning over 2.6 times
## a second. The owner, on the second playtest: "walk animations seems worse than before"
## and "that sound is terrible". The animation had not changed; the audio landing off it had
## arrived.
##
## It is now a function of the CLIP. One hoofstep per cycle of whatever locomotion clip is
## playing, fired at the same phase of that cycle every single time, read off the
## AnimationPlayer's own position rather than accumulated -- so a crossfade, a playback
## rescale or a seek cannot make it drift.
##
## WHY ONE PER CYCLE AND NOT FOUR. The authored walk is a 0.833 s cycle depicting 0.66 m/s
## (game/systems/gait.gd: the rig's front leg chain sits at 98.8% extension, so the stride
## physically cannot lengthen and the cycle is short). Four beats per cycle at the sneak's
## 2.0x playback is 9.6 sounds a second, which is a drill and not a pony. One per cycle is
## one of her four hooves, always the same one, always at the same moment of the gait -- 2.4
## a second at a creep and 2.9 at a gallop, and the density barely moves between them, which
## is what "she is moving" sounds like.

const PlayerScript := preload("res://actors/player/player.gd")
const GaitScript := preload("res://systems/gait.gd")
const SoundScript := preload("res://systems/sound.gd")

const WALK := &"walk"
const GALLOP := &"gallop"


func test_the_two_surfaces_are_library_ids() -> void:
	assert_true(SoundScript.LIBRARY.has(PlayerScript.SURFACE_GRASS))
	assert_true(SoundScript.LIBRARY.has(PlayerScript.SURFACE_HARD))


func test_a_fresh_player_starts_on_grass() -> void:
	var player = PlayerScript.new()
	assert_eq(player.step_surface(), PlayerScript.SURFACE_GRASS)
	player.free()


func test_the_surface_is_the_rancher_s_to_set() -> void:
	var player = PlayerScript.new()
	player.set_step_surface(PlayerScript.SURFACE_HARD)
	assert_eq(player.step_surface(), PlayerScript.SURFACE_HARD)
	player.set_step_surface(&"not_a_surface")
	assert_push_error(1, "an unknown surface id is reported loudly, not swallowed")
	assert_eq(player.step_surface(), PlayerScript.SURFACE_HARD)
	player.free()


## Walk one clip round twice at a constant rate and count the sounds. Two cycles, two
## sounds, and the second one lands at the same phase as the first.
func test_one_step_per_cycle_of_the_walk_clip() -> void:
	var player = PlayerScript.new()
	var cycle: float = GaitScript.WALK_CYCLE_SECONDS
	var steps := 0
	var fired_at: Array[float] = []
	var ticks := 120
	for i in range(ticks):
		# i + 1: the position sampled at the tick the wrap actually lands on, not the one
		# before it -- range(120) is ticks 1..120 of a 60-tick cycle, i.e. two closed
		# cycles, and phasing from i=0 would only ever see the first one finish.
		var position: float = fmod(float(i + 1) * cycle / 60.0, cycle)
		if player.step_on_clip(WALK, position, PlayerScript.SNEAK_SPEED, true):
			steps += 1
			fired_at.append(position)
	assert_eq(steps, 2, "60 ticks to the cycle over 120 ticks is exactly two cycles")
	assert_eq(fired_at.size(), 2, "the phases were recorded")
	assert_almost_eq(fired_at[0], fired_at[1], 0.0001,
		"both sounds land on the same moment of the gait")
	player.free()


func test_one_step_per_cycle_of_the_gallop_clip() -> void:
	var player = PlayerScript.new()
	var cycle: float = GaitScript.GALLOP_CYCLE_SECONDS
	var steps := 0
	for i in range(180):
		# Same i + 1 phasing as the walk test above, and for the same reason.
		if player.step_on_clip(GALLOP, fmod(float(i + 1) * cycle / 60.0, cycle),
				PlayerScript.RUN_SPEED, true):
			steps += 1
	assert_eq(steps, 3, "60 ticks to the cycle over 180 ticks is exactly three cycles")
	player.free()


func test_standing_still_never_makes_a_sound() -> void:
	var player = PlayerScript.new()
	var cycle: float = GaitScript.WALK_CYCLE_SECONDS
	for i in range(240):
		assert_false(player.step_on_clip(WALK, fmod(float(i) * cycle / 60.0, cycle), 0.0, true),
			"a hoof that is not travelling has not landed on anything")
	player.free()


func test_the_idle_clip_never_makes_a_sound() -> void:
	# She is not going anywhere, so nothing is planting. Guarded separately from the speed
	# floor because the idle band (below Gait.IDLE_SPEED, 0.33 m/s) and STEP_MIN_SPEED
	# (0.4 m/s) are different numbers and the gap between them is real.
	var player = PlayerScript.new()
	for i in range(240):
		assert_false(player.step_on_clip(&"idle", fmod(float(i) * 0.02, 1.0), 5.0, true))
	player.free()


func test_leaving_the_ground_stops_the_hoofsteps() -> void:
	var player = PlayerScript.new()
	var cycle: float = GaitScript.GALLOP_CYCLE_SECONDS
	var steps := 0
	for i in range(180):
		if player.step_on_clip(GALLOP, fmod(float(i) * cycle / 60.0, cycle),
				PlayerScript.RUN_SPEED, false):
			steps += 1
	assert_eq(steps, 0, "airborne hooves land on nothing")
	player.free()


## THE HANDOVER. Gait.clip_for_speed() swaps walk for gallop mid stride and the
## AnimationPlayer's position resets when it does. A wrap detector that did not know the
## clip had changed would fire a spurious sound on that exact frame -- audibly, a stumble
## every time she breaks into a run.
func test_changing_clip_does_not_fire_a_stray_step() -> void:
	var player = PlayerScript.new()
	assert_false(player.step_on_clip(WALK, 0.80, PlayerScript.SNEAK_SPEED, true))
	assert_false(player.step_on_clip(GALLOP, 0.01, PlayerScript.RUN_SPEED, true),
		"the position fell because the clip changed, not because a cycle finished")
	player.free()


## The cadence at each of the two speeds the game actually offers, in sounds per second,
## computed from the clip the gait ladder picks and the rate it plays it at. This is the
## claim the whole task is about, so it is asserted rather than described.
func test_the_cadence_at_the_two_speeds_the_game_offers() -> void:
	for speed: float in [PlayerScript.SNEAK_SPEED, PlayerScript.RUN_SPEED]:
		var clip: StringName = GaitScript.clip_for_speed(speed)
		var cycle: float = GaitScript.WALK_CYCLE_SECONDS if clip == WALK \
			else GaitScript.GALLOP_CYCLE_SECONDS
		var per_second: float = GaitScript.playback_scale_for_clip(clip, speed) / cycle
		assert_between(per_second, 1.5, 4.0,
			("%.2f m/s plays '%s' at %.2f steps a second, which is a drill or a limp"
				% [speed, clip, per_second]))
