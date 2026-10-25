extends GutTest
## OWNER PLAYTEST 2026-10-25, note 1: catching was "super easy" (17 ponies in 11.6 minutes).
## Past the first few catches the beam takes longer to subdue the bolder grades, ramping with
## story var "catches": about 1.0 s for the shy ones always, up to about 2 s for the bold ones
## later. The first catch stays exactly as it was (first_catch_grace, test_first_pony).

const BeamScript := preload("res://actors/player/magic_beam.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")

const SHY := PonyDataScript.Personality.SHY
const CURIOUS := PonyDataScript.Personality.CURIOUS
const BOLD := PonyDataScript.Personality.BOLD


func test_the_first_few_catches_are_the_original_beam() -> void:
	for catches in range(0, BeamScript.RAMP_FROM_CATCHES + 1):
		for p in [SHY, CURIOUS, BOLD]:
			assert_almost_eq(BeamScript.secure_seconds_for(p, catches),
				BeamScript.SECURE_SECONDS, 0.0001, "catch %d, personality %d" % [catches, p])


func test_shy_ponies_never_get_harder_to_hold() -> void:
	for catches in [0, 5, 10, 20, 100]:
		assert_almost_eq(BeamScript.secure_seconds_for(SHY, catches), 1.0, 0.0001)


func test_the_bold_ones_take_about_two_seconds_later() -> void:
	var late := 40
	var medium: float = BeamScript.secure_seconds_for(CURIOUS, late)
	var hard: float = BeamScript.secure_seconds_for(BOLD, late)
	assert_gt(medium, 1.3, "a curious pony takes noticeably longer")
	assert_lt(medium, hard, "and a bold one longer still")
	assert_between(hard, 1.7, 1.9)
	# The longest a single roll can be: still about two seconds, never a chore.
	var worst: Dictionary = BeamScript.roll_clocks(BOLD, 99, 1.0, 1.0, 1.0, late)
	assert_lte(float(worst["secure"]), 2.05)


func test_the_ramp_rises_monotonically() -> void:
	var last := 0.0
	for catches in range(0, 30):
		var s: float = BeamScript.secure_seconds_for(BOLD, catches)
		assert_gte(s, last, "catch %d" % catches)
		last = s


func test_the_ramp_reaches_the_rolled_clocks() -> void:
	var early: Dictionary = BeamScript.roll_clocks(BOLD, 99, 1.0, 0.5, 0.5, 0)
	var late: Dictionary = BeamScript.roll_clocks(BOLD, 99, 1.0, 0.5, 0.5, 30)
	assert_gt(float(late["secure"]), float(early["secure"]) + 0.7,
		"a practised steward's bold pony takes most of a second longer")
	assert_almost_eq(float(late["struggle"]) - float(late["secure"]),
		float(early["struggle"]) - float(early["secure"]), 0.0001,
		"the window to let go in is the same: longer, not twitchier")


func test_the_beam_uses_its_catch_count() -> void:
	var beam = BeamScript.new()
	autofree(beam)
	assert_eq(beam.catch_count, 0, "a fresh beam is the original beam")
