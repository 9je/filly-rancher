extends GutTest
## Tests for Gait (game/systems/gait.gd) -- the single runtime home for the `walk`
## clip's implied ground speed and the playback-scaling rules built on it. Pure
## arithmetic with no scene dependency, so these run headlessly with nothing built.
## Preloads by path rather than the global class_name, matching the convention
## documented at the top of game/scripts/pony_rig.gd.
##
## The point of these tests is not that division works. It is that the ONE number
## every consumer scales its animation against (0.66 m/s) is pinned to the value
## tools/author_anims.py prints as WALK_IMPLIED_SPEED, and that the walk band really
## is continuous and skate-free the way player.gd's comments claim -- both things a
## future retune could silently break while every scene gate still passed.

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
		"the skate-free ceiling is MAX_PLAYBACK x the clip speed")
	# player.gd's GALLOP_SPEED. This is the documented cost of galloping on a walk
	# clip; if it ever drifts far from ~2x, the speeds and this comment disagree.
	assert_almost_eq(GaitScript.skate_ratio(4.0), 2.02, 0.02,
		"top gallop on the walk clip should skate by about 2x")


func test_skate_ratio_is_one_for_a_stationary_character() -> void:
	assert_eq(GaitScript.skate_ratio(0.0), 1.0,
		"a character who is not moving cannot be skating")
