extends GutTest
## THE WHEEL. Roulette without the layout: twenty five pockets, a bet on a colour or on a
## number, and exactly one pocket of house edge on either bet. The claim worth testing is
## that "either bet" part; a wheel where one of the two bets is worse than the sign says is
## exactly the dishonesty this casino is not allowed to have.

const WheelScript := preload("res://systems/wheel.gd")

const SAMPLE_SPINS := 20000


func test_the_house_pocket_has_no_colour_and_the_rest_run_in_fours() -> void:
	assert_eq(WheelScript.colour_of(WheelScript.HOUSE_POCKET), WheelScript.Colour.HOUSE)
	assert_eq(WheelScript.colour_of(1), WheelScript.Colour.RED)
	assert_eq(WheelScript.colour_of(4), WheelScript.Colour.RED)
	assert_eq(WheelScript.colour_of(5), WheelScript.Colour.ORANGE)
	assert_eq(WheelScript.colour_of(24), WheelScript.Colour.VIOLET)


func test_every_colour_owns_exactly_four_numbers() -> void:
	var counts: Dictionary = {}
	for pocket in range(1, WheelScript.NUMBERS + 1):
		var colour: int = WheelScript.colour_of(pocket)
		counts[colour] = int(counts.get(colour, 0)) + 1
	assert_eq(counts.size(), 6, "six colours, and the house pocket is not one of them")
	for colour in counts:
		assert_eq(int(counts[colour]), WheelScript.COLOUR_RUN)


func test_a_number_bet_pays_twenty_three_to_one_and_nothing_otherwise() -> void:
	assert_eq(WheelScript.payout(WheelScript.Bet.NUMBER, 7, 7, 10), 240)
	assert_eq(WheelScript.payout(WheelScript.Bet.NUMBER, 7, 8, 10), 0)
	assert_eq(WheelScript.payout(WheelScript.Bet.NUMBER, 7, WheelScript.HOUSE_POCKET, 10), 0)


func test_a_colour_bet_pays_five_to_one_and_the_house_pocket_beats_every_colour() -> void:
	assert_eq(WheelScript.payout(WheelScript.Bet.COLOUR, WheelScript.Colour.RED, 3, 10), 60)
	assert_eq(WheelScript.payout(WheelScript.Bet.COLOUR, WheelScript.Colour.RED, 9, 10), 0)
	assert_eq(WheelScript.payout(WheelScript.Bet.COLOUR, WheelScript.Colour.RED,
		WheelScript.HOUSE_POCKET, 10), 0, "you cannot bet the house pocket's colour")


func test_a_bet_on_a_number_that_is_not_on_the_wheel_pays_nothing() -> void:
	assert_eq(WheelScript.payout(WheelScript.Bet.NUMBER, 0, 0, 10), 0,
		"the house pocket is not a number you may back")
	assert_eq(WheelScript.payout(WheelScript.Bet.NUMBER, 25, 25, 10), 0)


func test_a_zero_or_negative_stake_pays_nothing() -> void:
	assert_eq(WheelScript.payout(WheelScript.Bet.NUMBER, 7, 7, 0), 0)
	assert_eq(WheelScript.payout(WheelScript.Bet.NUMBER, 7, 7, -10), 0)


func test_both_bets_carry_exactly_one_pocket_of_edge() -> void:
	assert_almost_eq(WheelScript.house_edge(), 1.0 / 25.0, 1e-12)
	var number_return := float(WheelScript.NUMBER_PAYS_TO_ONE + 1) / float(WheelScript.POCKETS)
	var colour_return := float(WheelScript.COLOUR_PAYS_TO_ONE + 1) \
		* float(WheelScript.COLOUR_RUN) / float(WheelScript.POCKETS)
	assert_almost_eq(number_return, WheelScript.return_to_player(), 1e-12)
	assert_almost_eq(colour_return, WheelScript.return_to_player(), 1e-12,
		"a colour bet and a number bet must be worth exactly the same")


func test_the_published_edge_reads_as_four_per_cent() -> void:
	assert_eq("%.1f" % (WheelScript.house_edge() * 100.0), "4.0")


func test_a_spin_never_leaves_the_wheel_and_a_seed_repeats_it() -> void:
	var a := RandomNumberGenerator.new()
	a.seed = 5150
	var b := RandomNumberGenerator.new()
	b.seed = 5150
	for i in 500:
		var pocket: int = WheelScript.spin(a)
		assert_between(pocket, 0, WheelScript.NUMBERS)
		assert_eq(pocket, WheelScript.spin(b))


func test_a_long_seeded_colour_run_converges_on_the_published_edge() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260901
	var staked := 0
	var returned := 0
	for i in SAMPLE_SPINS:
		staked += 100
		returned += WheelScript.payout(WheelScript.Bet.COLOUR, WheelScript.Colour.GREEN,
			WheelScript.spin(rng), 100)
	var measured: float = 1.0 - (float(returned) / float(staked))
	assert_almost_eq(measured, WheelScript.house_edge(), 0.02,
		"measured %.4f against a published %.4f" % [measured, WheelScript.house_edge()])


func test_the_rules_placard_carries_no_dashes() -> void:
	for line in WheelScript.rules_lines():
		assert_false(line.is_empty())
		assert_false(line.contains("--") or line.contains("—"), line)
