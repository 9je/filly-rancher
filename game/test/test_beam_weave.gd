extends GutTest
## EVERY PONY HAS TO BE KEPT IN THE CROSSHAIR (PS9; playtest 2026-11-05 item 69: "Catching is
## too easy (all but the toughest) and repetitive"). Held, every wild pony weaves off the aim
## inside the beam and the aim reels her back; only time with her ON the crosshair counts
## toward securing her, while her struggle clock runs regardless. The weave scales with her
## rarity (a Drifter weakest), and even a common needs two seconds on the crosshair.

const BeamScript := preload("res://actors/player/magic_beam.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")

const RARITIES := [PonyDataScript.Rarity.COMMON, PonyDataScript.Rarity.UNCOMMON,
	PonyDataScript.Rarity.RARE, PonyDataScript.Rarity.LEGENDARY]


func test_every_rarity_weaves_and_a_drifter_weaves_least() -> void:
	assert_eq(BeamScript.weave_for(PonyDataScript.Rarity.COMMON, true), 0.35, "a Drifter")
	var want := [0.55, 0.8, 1.0, 1.2]
	for i in RARITIES.size():
		assert_eq(BeamScript.weave_for(RARITIES[i], false), want[i], "rarity %d" % RARITIES[i])


func test_left_alone_every_pony_drifts_off_the_aim() -> void:
	# The aim held still: her own drift settles at weave / reel radians off it, which must be
	# past the on-target cone for every pony, or tracking her would not matter.
	assert_gt(BeamScript.weave_for(PonyDataScript.Rarity.COMMON, true) / BeamScript.WEAVE_REEL,
		BeamScript.ON_TARGET_RAD, "a Drifter drifts off the crosshair if not tracked")
	for rarity in RARITIES:
		var drift: float = BeamScript.weave_for(rarity, false) / BeamScript.WEAVE_REEL
		assert_gt(drift, BeamScript.ON_TARGET_RAD, "rarity %d drifts off the crosshair if not tracked" % rarity)


func test_even_the_quickest_common_takes_two_seconds_on_the_crosshair() -> void:
	for personality in [PonyDataScript.Personality.SHY, PonyDataScript.Personality.CURIOUS,
			PonyDataScript.Personality.BOLD]:
		var clocks: Dictionary = BeamScript.roll_clocks(personality, 99, 1.0, 0.0, 0.0, 0,
			BeamScript.WEAVE_STEADY_EXTRA)
		assert_gte(float(clocks["secure"]), 2.0, "personality %d" % personality)
		assert_gt(float(clocks["struggle"]), float(clocks["secure"]),
			"and she still struggles longer than that, so a steady hold can win")


func test_a_wrench_still_comes_before_the_secure() -> void:
	var clocks: Dictionary = BeamScript.roll_clocks(PonyDataScript.Personality.BOLD, 0, 0.0, 0.5, 0.5, 0,
		BeamScript.WEAVE_STEADY_EXTRA)
	assert_true(bool(clocks["wrenches"]), "a BOLD first hold with the lowest roll wrenches")
	assert_lt(float(clocks["struggle"]), float(clocks["secure"]),
		"the extra steady time does not turn a wrench into a catch")


func test_on_target_reads_the_angle_between_the_aim_and_her() -> void:
	assert_true(BeamScript.on_target(Vector3.FORWARD, Vector3(0, 0, -10)))
	assert_false(BeamScript.on_target(Vector3.FORWARD, Vector3(4, 0, -10)))
