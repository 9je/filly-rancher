extends GutTest
## A RARE PONY HAS TO BE KEPT IN THE CROSSHAIR (PT9; playtest 2026-11-05: "all catches but the
## toughests being ez af and kinda repetitive"). Held, a rarer pony weaves off the aim inside
## the beam and the aim reels her back; only time with her ON the crosshair counts toward
## securing her, while her struggle clock runs regardless. A Drifter or a common stays put,
## exactly as before.

const BeamScript := preload("res://actors/player/magic_beam.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")


func test_commons_do_not_weave_and_rarer_ponies_weave_harder() -> void:
	var c: float = BeamScript.weave_for(PonyDataScript.Rarity.COMMON)
	var u: float = BeamScript.weave_for(PonyDataScript.Rarity.UNCOMMON)
	var r: float = BeamScript.weave_for(PonyDataScript.Rarity.RARE)
	var l: float = BeamScript.weave_for(PonyDataScript.Rarity.LEGENDARY)
	assert_eq(c, 0.0, "a common is caught exactly as before")
	assert_true(u > 0.0 and u < r and r < l, "%.2f < %.2f < %.2f" % [u, r, l])


func test_left_alone_a_weaving_pony_drifts_off_the_aim() -> void:
	# The aim held still: her own drift settles at weave / reel radians off it, which must be
	# past the on-target cone for every weaving rarity, or tracking her would not matter.
	for rarity in [PonyDataScript.Rarity.UNCOMMON, PonyDataScript.Rarity.RARE, PonyDataScript.Rarity.LEGENDARY]:
		var drift: float = BeamScript.weave_for(rarity) / BeamScript.WEAVE_REEL
		assert_gt(drift, BeamScript.ON_TARGET_RAD, "rarity %d drifts off the crosshair if not tracked" % rarity)


func test_on_target_reads_the_angle_between_the_aim_and_her() -> void:
	assert_true(BeamScript.on_target(Vector3.FORWARD, Vector3(0, 0, -10)))
	assert_false(BeamScript.on_target(Vector3.FORWARD, Vector3(4, 0, -10)))
