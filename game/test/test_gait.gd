extends GutTest
## Tests for Gait (game/systems/gait.gd) -- the single runtime home for the implied
## ground speed of each locomotion clip and the playback-scaling rules built on them.
## Pure arithmetic with no scene dependency, so these run headlessly with nothing built.
## Preloads by path rather than the global class_name, matching the convention
## documented at the top of game/scripts/pony_rig.gd.
##
## The point of these tests is not that division works. It is that the numbers every
## consumer scales its animation against (0.66 m/s for `walk`, 3.30 for `gallop`) stay
## pinned to what tools/author_anims.py prints as WALK_IMPLIED_SPEED and
## GALLOP_IMPLIED_SPEED, and that the speed ladder really is continuous and skate-free
## the way player.gd's comments claim -- all things a future retune could silently
## break on the far side of a language boundary while every scene gate still passed.

const GaitScript := preload("res://systems/gait.gd")


func test_walk_clip_speed_matches_the_exporters_implied_speed() -> void:
	# tools/author_anims.py prints "WALK_IMPLIED_SPEED 0.66 m/s" on every export.
	assert_almost_eq(GaitScript.WALK_CLIP_SPEED, 0.66, 0.005,
		"the derived clip speed must stay pinned to what the exporter reports")


func test_stance_divisor_is_half_a_cycle_not_a_whole_one() -> void:
	# Dividing by the whole cycle instead of the stance half understates the clip's
	# speed by exactly 2x -- the original "mincing shuffle" bug (docs/pipeline.md s6).
	var whole_cycle_mistake := GaitScript.WALK_STRIDE / GaitScript.WALK_CYCLE_SECONDS
	assert_almost_eq(GaitScript.WALK_CLIP_SPEED / whole_cycle_mistake, 2.0, 0.0001,
		"WALK_CLIP_SPEED must be twice what dividing by the full cycle would give")


func test_playback_scale_is_one_at_the_clips_own_speed() -> void:
	assert_almost_eq(GaitScript.playback_scale_for_speed(GaitScript.WALK_CLIP_SPEED), 1.0, 0.0001,
		"moving at exactly the clip's speed must play it at 1.0x")


func test_playback_scale_clamps_at_both_ends() -> void:
	assert_eq(GaitScript.playback_scale_for_speed(0.0), GaitScript.MIN_PLAYBACK,
		"a standstill must not request an arbitrarily slow playback rate")
	assert_eq(GaitScript.playback_scale_for_speed(1000.0), GaitScript.MAX_PLAYBACK,
		"an absurd speed must not request an arbitrarily fast playback rate")


func test_walk_band_is_continuous_at_the_idle_handover() -> void:
	# IDLE_SPEED is defined as the speed at which MIN_PLAYBACK would be requested, so
	# the clip is never asked for a rate below the floor while `walk` is playing.
	assert_almost_eq(GaitScript.playback_scale_for_speed(GaitScript.IDLE_SPEED),
		GaitScript.MIN_PLAYBACK, 0.0001,
		"the idle/walk handover speed must land exactly on the playback floor")


func test_no_skate_anywhere_in_the_honest_band() -> void:
	for speed in [GaitScript.IDLE_SPEED, 0.66, 1.32, GaitScript.SKATE_FREE_TOP_SPEED]:
		assert_almost_eq(GaitScript.skate_ratio(speed), 1.0, 0.0001,
			"speed %f is inside the honest band and must not skate" % speed)


func test_skate_appears_only_above_the_honest_ceiling() -> void:
	assert_almost_eq(GaitScript.SKATE_FREE_TOP_SPEED, 1.98, 0.005,
		"the walk clip's own ceiling is MAX_PLAYBACK x its clip speed")
	assert_almost_eq(GaitScript.TOP_SKATE_FREE_SPEED, 4.785, 0.005,
		"the ladder's ceiling is GALLOP_MAX_PLAYBACK x the gallop clip speed")
	# 4.0 m/s used to be player.gd's GALLOP_SPEED and is still a fact about the LADDER:
	# everything up to TOP_SKATE_FREE_SPEED is depicted honestly. Before the `gallop` clip
	# existed the ratio here was 2.02 -- the documented cost of galloping on a walk clip,
	# and the whole reason that clip was authored. (The player now runs at 4.8 m/s, past
	# this ceiling by a deliberate, budgeted amount; that budget is pinned in
	# game/test/test_player.gd, next to the constant that spends it, rather than here,
	# because this file is about the clips and not about who is riding them.)
	assert_almost_eq(GaitScript.skate_ratio(4.0), 1.0, 0.0001,
		"4.0 m/s is inside what the gallop clip can depict")
	assert_gt(GaitScript.skate_ratio(GaitScript.TOP_SKATE_FREE_SPEED * 1.5), 1.4,
		"past the ladder's ceiling the gallop clip saturates and skate returns")


func test_skate_ratio_is_one_for_a_stationary_character() -> void:
	assert_eq(GaitScript.skate_ratio(0.0), 1.0,
		"a character who is not moving cannot be skating")


# --- `gallop` ----------------------------------------------------------------------

func test_gallop_clip_speed_matches_the_exporters_implied_speed() -> void:
	# tools/author_anims.py prints "GALLOP_IMPLIED_SPEED 3.3000 m/s" on every export.
	assert_almost_eq(GaitScript.GALLOP_CLIP_SPEED, 3.30, 0.005,
		"the derived gallop speed must stay pinned to what the exporter reports")


func test_gallop_buys_its_speed_from_the_cycle_not_the_stride() -> void:
	# The rig's front leg chain is 98.8% extended at rest, so the stride CANNOT grow.
	# If a future retune lengthens it, that assumption needs re-measuring in Blender
	# before this test is relaxed -- see the GALLOP_* block in tools/author_anims.py.
	assert_eq(GaitScript.GALLOP_STRIDE, GaitScript.WALK_STRIDE,
		"the gallop deliberately reuses the walk's stride; only the cycle differs")
	assert_almost_eq(GaitScript.GALLOP_CLIP_SPEED / GaitScript.WALK_CLIP_SPEED, 5.0, 0.0001,
		"a 1/6 stance over a 0.5 s cycle against a 1/2 stance over a 0.833 s one is 5x")


func test_the_two_locomotion_bands_meet_exactly() -> void:
	# Not "roughly meet". If these two ever disagree there is a speed range in which
	# neither clip is honest, and a character accelerating through it skates for a
	# moment -- the kind of defect that is invisible in a still and obvious in motion.
	assert_almost_eq(GaitScript.GALLOP_HANDOVER_SPEED, GaitScript.SKATE_FREE_TOP_SPEED, 0.0001,
		"the gallop must take over exactly where the walk clip runs out of honesty")
	assert_almost_eq(GaitScript.gallop_playback_scale_for_speed(GaitScript.GALLOP_HANDOVER_SPEED),
		GaitScript.GALLOP_MIN_PLAYBACK, 0.0001,
		"the handover speed must land exactly on the gallop's playback floor")


func test_clip_for_speed_walks_the_whole_ladder() -> void:
	assert_eq(GaitScript.clip_for_speed(0.0), &"idle")
	assert_eq(GaitScript.clip_for_speed(GaitScript.IDLE_SPEED - 0.01), &"idle")
	assert_eq(GaitScript.clip_for_speed(GaitScript.IDLE_SPEED), &"walk")
	assert_eq(GaitScript.clip_for_speed(1.32), &"walk")
	assert_eq(GaitScript.clip_for_speed(GaitScript.TROT_HANDOVER_SPEED - 0.01), &"walk")
	assert_eq(GaitScript.clip_for_speed(GaitScript.TROT_HANDOVER_SPEED), &"trot")
	assert_eq(GaitScript.clip_for_speed(GaitScript.GALLOP_HANDOVER_SPEED - 0.01), &"trot")
	assert_eq(GaitScript.clip_for_speed(GaitScript.GALLOP_HANDOVER_SPEED - 0.01, false), &"walk",
		"a body with no trot clip walks the old ladder")
	assert_eq(GaitScript.clip_for_speed(GaitScript.GALLOP_HANDOVER_SPEED), &"gallop")
	assert_eq(GaitScript.clip_for_speed(4.0), &"gallop")
	assert_eq(GaitScript.clip_for_speed(-4.0), &"gallop",
		"speed is a magnitude here; a negative one must not fall off the ladder")


func test_nothing_skates_anywhere_on_the_ladder() -> void:
	# Sweep the whole honest range rather than sampling the corners, so a future retune
	# that opens a gap in the middle of a band is caught wherever it opens.
	var speed := GaitScript.IDLE_SPEED
	while speed <= GaitScript.TOP_SKATE_FREE_SPEED:
		assert_almost_eq(GaitScript.skate_ratio(speed), 1.0, 0.0001,
			"speed %.3f is inside the honest ladder and must not skate" % speed)
		speed += 0.05


func test_playback_scale_for_clip_dispatches_to_the_right_band() -> void:
	assert_almost_eq(GaitScript.playback_scale_for_clip(&"walk", 1.32), 2.0, 0.0001)
	assert_almost_eq(GaitScript.playback_scale_for_clip(&"gallop", 4.0), 4.0 / 3.3, 0.0001)
	assert_eq(GaitScript.playback_scale_for_clip(&"idle", 0.0), 1.0,
		"`idle` depicts no ground motion, so it always plays at its authored rate")
	assert_eq(GaitScript.clip_speed(&"idle"), 0.0,
		"`idle` has no implied ground speed to scale against")


func test_the_trot_matches_the_exporters_implied_speed_and_fills_its_band() -> void:
	# tools/author_anims.py build_trot(): 0.5 m stride over a 0.42 stance of 16 frames at 24.
	assert_almost_eq(GaitScript.TROT_CLIP_SPEED, 0.5 / ((16.0 / 24.0) * 0.42), 0.0001)
	assert_gt(GaitScript.TROT_HANDOVER_SPEED, 1.32, "above every wander speed")
	assert_lt(GaitScript.TROT_HANDOVER_SPEED, GaitScript.GALLOP_HANDOVER_SPEED)
	var lo := GaitScript.TROT_HANDOVER_SPEED / GaitScript.TROT_CLIP_SPEED
	var hi := GaitScript.GALLOP_HANDOVER_SPEED / GaitScript.TROT_CLIP_SPEED
	assert_between(lo, 0.7, 1.0, "the trot never plays slow-motion at its floor")
	assert_between(hi, 1.0, 1.25, "nor sped-up at its ceiling")
