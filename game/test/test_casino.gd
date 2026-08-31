extends GutTest
## THE CHIP PURSE. Every refusal in here is a hole somebody would otherwise walk through
## with a hand edited save or a menu race, so each one gets its own case.

const CasinoScript := preload("res://systems/casino.gd")
const EconomyScript := preload("res://systems/economy.gd")


func test_a_new_purse_is_empty() -> void:
	var purse: Casino = CasinoScript.new()
	assert_eq(purse.chips, 0)


func test_a_negative_starting_count_is_clamped_rather_than_trusted() -> void:
	var purse: Casino = CasinoScript.new(-500)
	assert_eq(purse.chips, 0, "a hand edited save must not open the cage in debt")


func test_adding_chips_moves_the_count_and_announces_it() -> void:
	var purse: Casino = CasinoScript.new()
	watch_signals(purse)
	assert_true(purse.add_chips(250))
	assert_eq(purse.chips, 250)
	assert_signal_emitted_with_parameters(purse, "chips_changed", [250])


func test_adding_zero_or_fewer_chips_is_refused_and_announces_nothing() -> void:
	var purse: Casino = CasinoScript.new(100)
	watch_signals(purse)
	assert_false(purse.add_chips(0), "a buy in of nothing is a caller who thinks it paid")
	assert_false(purse.add_chips(-40), "a negative buy in is a cash out in disguise")
	assert_eq(purse.chips, 100)
	assert_signal_not_emitted(purse, "chips_changed")


func test_removing_more_chips_than_are_held_changes_nothing() -> void:
	var purse: Casino = CasinoScript.new(100)
	watch_signals(purse)
	assert_false(purse.remove_chips(101))
	assert_eq(purse.chips, 100, "a refusal is a no op, never a partial deduction")
	assert_signal_not_emitted(purse, "chips_changed")


func test_removing_a_negative_count_is_refused() -> void:
	var purse: Casino = CasinoScript.new(100)
	assert_false(purse.remove_chips(-25))
	assert_eq(purse.chips, 100)


func test_removing_zero_succeeds_and_announces_nothing() -> void:
	var purse: Casino = CasinoScript.new(100)
	watch_signals(purse)
	assert_true(purse.remove_chips(0), "nothing moved, and nothing failed either")
	assert_eq(purse.chips, 100)
	assert_signal_not_emitted(purse, "chips_changed")


func test_can_stake_refuses_zero_negative_and_more_than_is_held() -> void:
	var purse: Casino = CasinoScript.new(100)
	assert_true(purse.can_stake(1))
	assert_true(purse.can_stake(100))
	assert_false(purse.can_stake(0))
	assert_false(purse.can_stake(-1))
	assert_false(purse.can_stake(101))


func test_bits_and_chips_round_trip_exactly_at_one_for_one() -> void:
	var wallet: Economy = EconomyScript.new(1000)
	var purse: Casino = CasinoScript.new()
	assert_true(wallet.spend(400))
	assert_true(purse.add_chips(400))
	assert_eq(wallet.bits, 600)
	assert_eq(purse.chips, 400)
	assert_true(purse.remove_chips(400))
	wallet.grant(400)
	assert_eq(wallet.bits, 1000, "one bit in, one bit out, nothing kept at the window")
	assert_eq(purse.chips, 0)


func test_a_buy_in_the_wallet_cannot_afford_leaves_both_sides_untouched() -> void:
	var wallet: Economy = EconomyScript.new(50)
	var purse: Casino = CasinoScript.new()
	if wallet.spend(400):
		purse.add_chips(400)
	assert_eq(wallet.bits, 50)
	assert_eq(purse.chips, 0, "spend first, add second: a refused spend adds no chips")


func test_the_purse_round_trips_through_a_dictionary() -> void:
	var purse: Casino = CasinoScript.new(1234)
	var back: Casino = CasinoScript.from_dict(purse.to_dict())
	assert_eq(back.chips, 1234)


func test_a_missing_key_loads_as_an_empty_purse() -> void:
	assert_eq(CasinoScript.from_dict({}).chips, 0)


func test_a_load_can_never_mint_chips() -> void:
	assert_eq(CasinoScript.from_dict({"chips": -900}).chips, 0, "negative clamps to nothing")
	assert_eq(CasinoScript.from_dict({"chips": "9999"}).chips, 0, "a string is not a count")
	assert_eq(CasinoScript.from_dict({"chips": [1, 2]}).chips, 0, "an array is not a count")
	assert_eq(CasinoScript.from_dict({"chips": 40.0}).chips, 40, "JSON hands ints back as floats")
