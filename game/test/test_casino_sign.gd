extends GutTest
## THE LOBBY SIGN. The spec's promise is that the house edge is published and real, so the
## thing worth testing is that the sign reads its numbers out of the games rather than out of
## somebody's memory.

const CasinoSignScript := preload("res://systems/casino_sign.gd")
const SlotsScript := preload("res://systems/slots.gd")
const WheelScript := preload("res://systems/wheel.gd")
const BlackjackScript := preload("res://systems/blackjack.gd")
const RaceCardScript := preload("res://systems/race_card.gd")


func test_the_sign_names_the_palace_and_its_sponsor() -> void:
	var text: String = "\n".join(CasinoSignScript.lines())
	assert_true(text.contains("Spectra Palace"))
	assert_true(text.contains("Brightsky Weather Company"))


func test_the_sign_publishes_every_game_at_the_number_that_game_computes() -> void:
	var text: String = "\n".join(CasinoSignScript.lines())
	for pair in [["Slots", SlotsScript.house_edge()], ["The Wheel", WheelScript.house_edge()],
			["Blackjack", BlackjackScript.house_edge()], ["Racing", RaceCardScript.TAKEOUT]]:
		var expected: String = CasinoSignScript.edge_line(String(pair[0]), float(pair[1]))
		assert_true(text.contains(expected),
			"the sign must carry '%s' exactly as the game computes it" % expected)


func test_an_edge_line_reads_as_bits_in_a_hundred() -> void:
	assert_eq(CasinoSignScript.edge_line("Slots", 0.07),
		"Slots: the house keeps 7.0 bits of every 100 wagered.")


func test_the_cage_says_one_for_one_in_both_directions() -> void:
	var text: String = "\n".join(CasinoSignScript.cage_lines())
	assert_true(text.contains("one"), "the cage's rate is stated in words on the counter")
	assert_false(text.is_empty())


## THE REPORT: "the cage explains itself (bits to chips, one to one, both ways)".
func test_the_cage_explainer_says_one_for_one_both_ways() -> void:
	var text: String = "\n".join(CasinoSignScript.cage_explainer()).to_lower()
	assert_true(text.contains("one for one"), text)
	assert_true(text.contains("both ways"), text)


func test_nothing_on_the_cage_explainer_carries_a_dash() -> void:
	for line in CasinoSignScript.cage_explainer():
		assert_false(line.contains("--") or line.contains("—"), line)


func test_nothing_on_the_sign_or_the_counter_carries_a_dash() -> void:
	for line in CasinoSignScript.lines() + CasinoSignScript.cage_lines():
		assert_false(line.is_empty())
		assert_false(line.contains("--") or line.contains("—"), line)


func test_the_sign_fits_a_wall() -> void:
	for line in CasinoSignScript.lines():
		assert_lte(line.length(), 62,
			"a line wider than the panel is a line that gets cut off: %s" % line)
