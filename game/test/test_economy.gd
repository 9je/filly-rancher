extends GutTest
## Tests for the wallet (game/systems/economy.gd) -- Phase 1B Task 6's pure-logic half.
## The market stall and shop UI (world/UI, a different task) are the only things that will
## ever call sell()/spend() for real; this file pins the arithmetic and the refusal rules
## in isolation, the same way test_storage.gd pins "full means full" without a beam.
##
## WHY SPEND IS TESTED AS HARD AGAINST PARTIAL DEDUCTION AS AGAINST THE HAPPY PATH. A
## spend() that decremented bits and only THEN discovered it went negative would leave the
## wallet in a state no purchase ever produced -- worse than refusing, because the player
## paid for nothing. Every refusal test below re-checks `bits` afterwards for exactly this.
##
## Preloads by path rather than by the global class_name, matching the convention
## documented at the top of game/scripts/pony_rig.gd.

const EconomyScript := preload("res://systems/economy.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")


# --- construction ----------------------------------------------------------------------

func test_a_new_economy_starts_at_zero_bits_by_default() -> void:
	var econ = EconomyScript.new()
	assert_eq(econ.bits, 0)


func test_a_new_economy_can_start_with_a_given_balance() -> void:
	var econ = EconomyScript.new(50)
	assert_eq(econ.bits, 50)


func test_a_negative_starting_balance_is_clamped_rather_than_trusted() -> void:
	# Mirrors Storage's negative-capacity clamp (test_storage.gd) -- a corrupt or
	# hand-edited save must not produce a wallet already in debt.
	var econ = EconomyScript.new(-30)
	assert_eq(econ.bits, 0)


# --- selling: gem value is keyed by the producing pony's RARITY -------------------------

func test_selling_one_gem_of_each_rarity_pays_that_rarity_s_value() -> void:
	for rarity: int in EconomyScript.GEM_VALUE_BY_RARITY.keys():
		var econ = EconomyScript.new()
		var expected: int = EconomyScript.GEM_VALUE_BY_RARITY[rarity]
		var earned := econ.sell(rarity, 1)
		assert_eq(earned, expected, "selling one gem must pay exactly that rarity's listed value")
		assert_eq(econ.bits, expected)


func test_legendary_gems_are_worth_strictly_more_than_common_gems() -> void:
	# THE backbone-of-the-economy relationship the task exists to establish: a legendary
	# pony's gems must out-earn a common pony's, or rarity means nothing to the wallet.
	var common_value: int = EconomyScript.GEM_VALUE_BY_RARITY[PonyDataScript.Rarity.COMMON]
	var uncommon_value: int = EconomyScript.GEM_VALUE_BY_RARITY[PonyDataScript.Rarity.UNCOMMON]
	var rare_value: int = EconomyScript.GEM_VALUE_BY_RARITY[PonyDataScript.Rarity.RARE]
	var legendary_value: int = EconomyScript.GEM_VALUE_BY_RARITY[PonyDataScript.Rarity.LEGENDARY]
	assert_gt(uncommon_value, common_value)
	assert_gt(rare_value, uncommon_value)
	assert_gt(legendary_value, rare_value)


func test_selling_multiple_gems_multiplies_the_unit_value() -> void:
	var econ = EconomyScript.new()
	var unit: int = EconomyScript.GEM_VALUE_BY_RARITY[PonyDataScript.Rarity.RARE]
	var earned := econ.sell(PonyDataScript.Rarity.RARE, 4)
	assert_eq(earned, unit * 4)
	assert_eq(econ.bits, unit * 4)


func test_selling_zero_or_negative_gems_earns_nothing_and_changes_nothing() -> void:
	var econ = EconomyScript.new(10)
	assert_eq(econ.sell(PonyDataScript.Rarity.COMMON, 0), 0)
	assert_eq(econ.sell(PonyDataScript.Rarity.COMMON, -3), 0)
	assert_eq(econ.bits, 10, "a refused sale must not move the balance")


func test_selling_an_unrecognised_gem_type_earns_nothing_rather_than_crashing() -> void:
	var econ = EconomyScript.new(10)
	var earned := econ.sell(9999, 3)
	assert_eq(earned, 0, "an unknown gem type is worth nothing, not a crash")
	assert_eq(econ.bits, 10)


# --- affordability and spending ---------------------------------------------------------

func test_can_afford_true_at_or_below_balance_false_above_it() -> void:
	var econ = EconomyScript.new(20)
	assert_true(econ.can_afford(0))
	assert_true(econ.can_afford(20), "affording exactly the whole balance is affording")
	assert_false(econ.can_afford(21))


func test_spend_deducts_exactly_the_cost_on_success() -> void:
	var econ = EconomyScript.new(100)
	assert_true(econ.spend(35))
	assert_eq(econ.bits, 65)


func test_spend_refuses_when_short_and_does_not_partially_deduct() -> void:
	var econ = EconomyScript.new(10)
	assert_false(econ.spend(11), "spending more than the balance must be refused")
	assert_eq(econ.bits, 10, "a refused spend must leave the balance completely untouched")


func test_spend_of_exactly_the_whole_balance_succeeds_and_empties_it() -> void:
	var econ = EconomyScript.new(40)
	assert_true(econ.spend(40))
	assert_eq(econ.bits, 0)


func test_spend_of_a_negative_cost_is_refused() -> void:
	# A "negative purchase" would be a free deposit wearing a spend() costume; refuse it
	# rather than let it top up the wallet.
	var econ = EconomyScript.new(10)
	assert_false(econ.spend(-5))
	assert_eq(econ.bits, 10)


# --- the bits_changed signal --------------------------------------------------------------

func test_bits_changed_fires_on_a_successful_sell() -> void:
	var econ = EconomyScript.new()
	watch_signals(econ)
	econ.sell(PonyDataScript.Rarity.COMMON, 1)
	assert_signal_emit_count(econ, "bits_changed", 1)


func test_bits_changed_fires_on_a_successful_spend() -> void:
	var econ = EconomyScript.new(50)
	watch_signals(econ)
	econ.spend(10)
	assert_signal_emit_count(econ, "bits_changed", 1)


func test_bits_changed_carries_the_new_total() -> void:
	var econ = EconomyScript.new(10)
	watch_signals(econ)
	econ.spend(4)
	assert_signal_emitted_with_parameters(econ, "bits_changed", [6])


func test_bits_changed_does_not_fire_when_nothing_actually_changed() -> void:
	var econ = EconomyScript.new(5)
	watch_signals(econ)
	econ.sell(PonyDataScript.Rarity.COMMON, 0)
	econ.spend(9999)  # refused, too expensive
	assert_signal_emit_count(econ, "bits_changed", 0,
		"a refused spend and a no-op sale must not announce a change that never happened")


# --- round trip -----------------------------------------------------------------------------

func test_a_full_round_trip_of_selling_then_spending_leaves_the_right_balance() -> void:
	var econ = EconomyScript.new()
	var earned := econ.sell(PonyDataScript.Rarity.UNCOMMON, 3)
	assert_eq(econ.bits, earned)

	assert_true(econ.spend(earned - 2))
	assert_eq(econ.bits, 2)

	assert_false(econ.spend(3), "only 2 bits remain")
	assert_eq(econ.bits, 2, "the failed spend above must not have touched the balance")
