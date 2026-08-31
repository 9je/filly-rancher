extends GutTest
## The debt clock. Arithmetic only: no scene, no clock, no RNG.

const LedgerScript := preload("res://systems/ledger.gd")
const EconomyScript := preload("res://systems/economy.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")
const ProductionScript := preload("res://systems/production.gd")
const WorldStateScript := preload("res://systems/world_state.gd")


func test_a_new_ledger_opens_at_the_sponsorship_balance() -> void:
	var l := LedgerScript.new()
	assert_eq(l.balance, LedgerScript.STARTING_BALANCE)
	assert_eq(l.quota, LedgerScript.STARTING_QUOTA)
	assert_eq(l.delivered_this_period, 0)
	assert_eq(l.tier, 0)


func test_collection_day_is_every_three_cycles_and_one_real_hour_in() -> void:
	assert_false(LedgerScript.is_collection_cycle(0), "the day you start is not a collection day")
	assert_false(LedgerScript.is_collection_cycle(1))
	assert_false(LedgerScript.is_collection_cycle(2))
	assert_true(LedgerScript.is_collection_cycle(3))
	assert_true(LedgerScript.is_collection_cycle(6))
	var seconds: float = float(LedgerScript.PERIOD_CYCLES) * WorldStateScript.CYCLE_SECONDS
	assert_eq(seconds, 3600.0, "the first collection day lands at one real hour of play")


func test_upkeep_is_a_base_plus_a_charge_per_plot_and_per_permit() -> void:
	var l := LedgerScript.new()
	assert_eq(l.upkeep_for(0, 0), LedgerScript.UPKEEP_BASE)
	assert_eq(l.upkeep_for(2, 0),
		LedgerScript.UPKEEP_BASE + 2 * LedgerScript.UPKEEP_PER_PLOT)
	assert_eq(l.upkeep_for(2, 3),
		LedgerScript.UPKEEP_BASE + 2 * LedgerScript.UPKEEP_PER_PLOT
			+ 3 * LedgerScript.UPKEEP_PER_PERMIT)
	assert_eq(l.upkeep_for(2, 3, 2.0), 2 * l.upkeep_for(2, 3),
		"the rank multiplier scales the whole charge; slice 4 sets it, slice 1 leaves it at 1")


func test_the_service_charge_is_a_percentage_with_a_floor() -> void:
	var l := LedgerScript.new()
	assert_eq(l.service_charge(),
		int(round(float(LedgerScript.STARTING_BALANCE) * LedgerScript.INTEREST_RATE)))
	l.balance = 10
	assert_eq(l.service_charge(), LedgerScript.MIN_SERVICE_CHARGE,
		"a nearly settled balance still costs something to carry")
	l.balance = 0
	assert_eq(l.service_charge(), 0, "and a settled one costs nothing")


func test_the_first_collection_day_outruns_a_starter_ranch() -> void:
	# One free Paddock, three ponies, the best production rate, common gems.
	var gems_per_period: int = int(float(LedgerScript.PERIOD_CYCLES)
		* WorldStateScript.CYCLE_SECONDS / ProductionScript.PRODUCTION_PERIOD_SECONDS)
	var income: int = 3 * gems_per_period \
		* int(EconomyScript.GEM_VALUE_BY_RARITY[PonyDataScript.Rarity.COMMON])
	var l := LedgerScript.new()
	var summary: Dictionary = l.run_collection_day(LedgerScript.PERIOD_CYCLES, 1, 0)
	assert_gt(int(summary["upkeep"]) + int(summary["service_charge"]), income,
		"the first hour must leave the player owing more, not less")
	assert_gt(l.balance, LedgerScript.STARTING_BALANCE)


func test_a_stock_delivery_credits_three_hundred() -> void:
	var l := LedgerScript.new()
	var before: int = l.balance
	assert_eq(l.credit_delivery(PonyDataScript.Rarity.COMMON, true),
		LedgerScript.DELIVERY_CREDIT_STOCK)
	assert_eq(l.balance, before - LedgerScript.DELIVERY_CREDIT_STOCK)
	assert_eq(l.delivered_this_period, 1)


func test_a_named_delivery_is_priced_by_rarity_and_a_legendary_clears_four_thousand() -> void:
	assert_eq(LedgerScript.delivery_credit(PonyDataScript.Rarity.LEGENDARY, false), 4000)
	assert_eq(LedgerScript.delivery_credit(PonyDataScript.Rarity.RARE, false), 1200)
	assert_eq(LedgerScript.delivery_credit(PonyDataScript.Rarity.UNCOMMON, false), 480)
	assert_eq(LedgerScript.delivery_credit(PonyDataScript.Rarity.COMMON, false), 200)
	assert_gt(LedgerScript.delivery_credit(PonyDataScript.Rarity.LEGENDARY, false),
		LedgerScript.DELIVERY_CREDIT_STOCK * 10,
		"a named delivery is the best money in the game by a wide margin, deliberately")


func test_a_delivery_may_take_the_balance_below_the_principal_floor() -> void:
	var l := LedgerScript.new()
	l.balance = 200
	l.credit_delivery(PonyDataScript.Rarity.LEGENDARY, false)
	assert_lt(l.balance, 0, "stock settles the principal, and may overshoot into credit")


func test_bits_never_take_the_balance_below_the_principal_floor() -> void:
	var l := LedgerScript.new()
	var allowed: int = l.payable()
	assert_eq(allowed, LedgerScript.STARTING_BALANCE - LedgerScript.PRINCIPAL_FLOOR)
	assert_eq(l.pay(1000000), allowed,
		"pay() takes what it may and answers with what it actually took")
	assert_eq(l.balance, LedgerScript.PRINCIPAL_FLOOR)
	assert_eq(l.pay(5000), 0, "and refuses to go further")
	assert_eq(l.balance, LedgerScript.PRINCIPAL_FLOOR)


func test_paying_zero_or_less_changes_nothing() -> void:
	var l := LedgerScript.new()
	assert_eq(l.pay(0), 0)
	assert_eq(l.pay(-500), 0)
	assert_eq(l.balance, LedgerScript.STARTING_BALANCE)


func test_the_quota_is_counted_per_period_and_reset_by_the_collection_day() -> void:
	var l := LedgerScript.new()
	l.credit_delivery(PonyDataScript.Rarity.COMMON, true)
	l.credit_delivery(PonyDataScript.Rarity.COMMON, true)
	var summary: Dictionary = l.run_collection_day(3, 1, 0)
	assert_true(bool(summary["quota_met"]))
	assert_eq(int(summary["delivered"]), 2)
	assert_eq(l.delivered_this_period, 0, "the count starts again for the next period")


func test_the_collector_ladder_climbs_in_the_order_the_spec_names() -> void:
	var l := LedgerScript.new()
	var seen: Array[int] = []
	for i in 6:
		var summary: Dictionary = l.run_collection_day(3 * (i + 1), 1, 0)
		seen.append(int(summary["punishment"]))
	assert_eq(seen[0], LedgerScript.Punishment.FEE)
	assert_eq(seen[1], LedgerScript.Punishment.PERMIT_REVOKED)
	assert_eq(seen[2], LedgerScript.Punishment.PEN_PADLOCKED)
	assert_eq(seen[3], LedgerScript.Punishment.BEAM_RECALLED)
	assert_eq(seen[4], LedgerScript.Punishment.BEAM_RECALLED, "the top rung is the top rung")


func test_meeting_the_quota_steps_back_down_the_ladder() -> void:
	var l := LedgerScript.new()
	l.run_collection_day(3, 1, 0)
	l.run_collection_day(6, 1, 0)
	assert_eq(l.tier, 2)
	l.credit_delivery(PonyDataScript.Rarity.COMMON, true)
	l.credit_delivery(PonyDataScript.Rarity.COMMON, true)
	var summary: Dictionary = l.run_collection_day(9, 1, 0)
	assert_eq(int(summary["punishment"]), LedgerScript.Punishment.NONE)
	assert_eq(l.tier, 1, "a good period walks the ladder back down one rung, not all of it")


func test_a_balance_over_the_ceiling_calls_a_collector_even_with_the_quota_met() -> void:
	var l := LedgerScript.new()
	l.balance = LedgerScript.CEILING + 1
	l.credit_delivery(PonyDataScript.Rarity.COMMON, true)
	l.credit_delivery(PonyDataScript.Rarity.COMMON, true)
	var summary: Dictionary = l.run_collection_day(3, 1, 0)
	assert_true(bool(summary["quota_met"]))
	assert_true(bool(summary["over_ceiling"]))
	assert_eq(int(summary["punishment"]), LedgerScript.Punishment.FEE)


func test_a_pending_punishment_is_taken_exactly_once() -> void:
	var l := LedgerScript.new()
	l.run_collection_day(3, 1, 0)
	assert_eq(l.take_pending_punishment(), LedgerScript.Punishment.FEE)
	assert_eq(l.take_pending_punishment(), LedgerScript.Punishment.NONE,
		"a collector who has already called does not call twice at the same dawn")


func test_relief_arrives_when_the_balance_is_back_under_the_ceiling() -> void:
	var l := LedgerScript.new()
	l.balance = LedgerScript.CEILING + 5000
	l.revoked_permits = ["permit_orchard"]
	l.padlocked_slots = ["plot_a"]
	l.beam_recalled_until = 12
	assert_eq(l.relieve(), {}, "nothing is given back while she is over the ceiling")
	l.credit_delivery(PonyDataScript.Rarity.LEGENDARY, false)
	l.credit_delivery(PonyDataScript.Rarity.LEGENDARY, false)
	var given: Dictionary = l.relieve()
	assert_eq(given["permits"], ["permit_orchard"])
	assert_eq(given["slots"], ["plot_a"])
	assert_true(bool(given["beam"]))
	assert_eq(l.revoked_permits, [])
	assert_eq(l.padlocked_slots, [])
	assert_eq(l.beam_recalled_until, -1)
	assert_eq(l.relieve(), {}, "and nothing is given back twice")


## AN EXPIRED RECALL IS NOT SOMETHING TO GIVE BACK. beam_recalled_until is a cycle number
## that goes stale on its own clock: one cycle after the visit the horn is already back in
## her hands. Left on file, it made the next relieve() report `beam: true` and the ranch
## announce it was handing back something she had been using for the last twenty minutes.
func test_relieve_does_not_report_a_recall_that_had_already_expired() -> void:
	var l := LedgerScript.new()
	l.balance = LedgerScript.CEILING - 1
	l.beam_recalled_until = 4
	var given: Dictionary = l.relieve(9)
	assert_true(given.is_empty(),
		"the horn came back on cycle 4 by itself; there is nothing to announce on cycle 9")
	assert_eq(l.beam_recalled_until, -1, "and the stale note is cleared off the file")


func test_relieve_still_reports_a_recall_that_is_running() -> void:
	var l := LedgerScript.new()
	l.balance = LedgerScript.CEILING - 1
	l.beam_recalled_until = 12
	var given: Dictionary = l.relieve(9)
	assert_true(bool(given.get("beam", false)),
		"a recall with cycles left on it is a real thing to hand back")
	assert_eq(l.beam_recalled_until, -1)


func test_relieve_with_no_clock_reads_every_recall_as_running() -> void:
	# The safe way round for a caller with no world clock: hand the horn back rather than
	# forget to.
	var l := LedgerScript.new()
	l.balance = LedgerScript.CEILING - 1
	l.beam_recalled_until = 4
	assert_true(bool(l.relieve().get("beam", false)))


## The arming cycle is set by the collection day that arms the rung, and cleared with it.
func test_a_collection_day_records_which_cycle_armed_the_collector() -> void:
	var l := LedgerScript.new()
	var summary: Dictionary = l.run_collection_day(6, 1, 0)
	assert_ne(int(summary["punishment"]), LedgerScript.Punishment.NONE,
		"sanity: an unmet quota arms somebody")
	assert_eq(l.pending_punishment_cycle, 6, "the cycle that armed him is on file")
	l.take_pending_punishment()
	assert_eq(l.pending_punishment_cycle, -1, "and goes when he is served")


func test_a_good_period_arms_nobody_and_records_no_cycle() -> void:
	var l := LedgerScript.new()
	for i in LedgerScript.STARTING_QUOTA:
		l.credit_delivery(PonyDataScript.Rarity.COMMON, true)
	l.run_collection_day(3, 1, 0)
	assert_eq(l.pending_punishment, LedgerScript.Punishment.NONE)
	assert_eq(l.pending_punishment_cycle, -1,
		"nothing is armed, so there is no dawn to hold anybody until")


func test_the_beam_recall_lasts_exactly_one_cycle() -> void:
	var l := LedgerScript.new()
	l.beam_recalled_until = 5 + LedgerScript.BEAM_RECALL_CYCLES
	assert_true(l.beam_is_recalled(5))
	assert_false(l.beam_is_recalled(6), "one cycle later she has her horn back")


func test_gems_alone_never_clear_the_balance() -> void:
	# THE BEST RANCH THE GAME PERMITS: six plot slots, all Grand Pens (eight spaces each),
	# every space filled with the most valuable pony the roster can supply (one of each of
	# the 3 legendary, 8 rare, 15 uncommon and 17 common characters, the remainder stock),
	# every resident at happiness 1.0 and hunger 0.0, every gem sold at full price, every
	# permit open, and not one pony ever delivered.
	var per_pony: int = int(float(LedgerScript.PERIOD_CYCLES) * WorldStateScript.CYCLE_SECONDS
		/ ProductionScript.PRODUCTION_PERIOD_SECONDS)
	var values: Array[int] = []
	for i in 3:
		values.append(int(EconomyScript.GEM_VALUE_BY_RARITY[PonyDataScript.Rarity.LEGENDARY]))
	for i in 8:
		values.append(int(EconomyScript.GEM_VALUE_BY_RARITY[PonyDataScript.Rarity.RARE]))
	for i in 15:
		values.append(int(EconomyScript.GEM_VALUE_BY_RARITY[PonyDataScript.Rarity.UNCOMMON]))
	while values.size() < 48:
		values.append(int(EconomyScript.GEM_VALUE_BY_RARITY[PonyDataScript.Rarity.COMMON]))
	var income := 0
	for value in values:
		income += per_pony * value
	var l := LedgerScript.new()
	# WHAT THE FLOOR IS ACTUALLY DOING HERE, said as an assertion rather than left to be
	# inferred from the ending balance. One period of that ranch out-earns one period of
	# upkeep AND its service charge several times over, so the balance below is NOT held up
	# by the arithmetic being tight: on interest and upkeep alone this player clears the
	# account and the promise the class comment makes would be false. It is PRINCIPAL_FLOOR
	# and nothing else that keeps it true, which is exactly what the class comment says and
	# what a later retune of UPKEEP_BASE (Ruling 13 parks one) must not be allowed to hide.
	var one_period_cost: int = l.upkeep_for(6, 4) + l.service_charge()
	assert_gt(income, one_period_cost,
		"the best ranch in the game out-earns its own upkeep and service charge; the floor,"
		+ " not the tuning, is the mechanism this test is about")
	for period in 50:
		l.run_collection_day(LedgerScript.PERIOD_CYCLES * (period + 1), 6, 4)
		l.pay(income)
	assert_gt(l.balance, 0,
		"a player who never delivers a pony cannot pay the balance off; that is the game")
	assert_eq(l.balance, LedgerScript.PRINCIPAL_FLOOR,
		"and she settles exactly at the principal, which is what the Depot tells her")


func test_shipments_count_up_across_periods_and_never_reset() -> void:
	var l := LedgerScript.new()
	assert_eq(l.shipments, 0)
	l.credit_delivery(PonyDataScript.Rarity.COMMON, true)
	l.credit_delivery(PonyDataScript.Rarity.COMMON, true)
	l.run_collection_day(3, 1, 0)
	assert_eq(l.delivered_this_period, 0, "the quota count starts again")
	assert_eq(l.shipments, 2, "the shipment count does not; the receipts keep counting")


func test_a_statement_names_the_player_and_carries_no_dashes() -> void:
	var l := LedgerScript.new()
	var lines: Array[String] = l.statement_lines("Moonbeam", 2, 1, 4)
	assert_gt(lines.size(), 4)
	var joined: String = "\n".join(lines)
	assert_true(joined.contains("Moonbeam"), "the statement is made out to her")
	assert_false(joined.contains("--"), "no double hyphen in anything a player reads")
	assert_false(joined.contains(char(0x2014)), "and no em dash")


func test_the_whole_ledger_round_trips() -> void:
	var l := LedgerScript.new()
	l.balance = 31234
	l.quota = 5
	l.delivered_this_period = 3
	l.periods_run = 7
	l.shipments = 21
	l.tier = 2
	l.pending_punishment = LedgerScript.Punishment.PEN_PADLOCKED
	l.pending_punishment_cycle = 6
	l.revoked_permits = ["permit_lake"]
	l.padlocked_slots = ["plot_b"]
	l.beam_recalled_until = 19
	var back: Ledger = LedgerScript.from_dict(l.to_dict())
	assert_eq(back.balance, 31234)
	assert_eq(back.quota, 5)
	assert_eq(back.delivered_this_period, 3)
	assert_eq(back.periods_run, 7)
	assert_eq(back.shipments, 21)
	assert_eq(back.tier, 2)
	assert_eq(back.pending_punishment, LedgerScript.Punishment.PEN_PADLOCKED)
	assert_eq(back.pending_punishment_cycle, 6,
		"which dawn he may call on travels with the rung he is calling about")
	assert_eq(back.revoked_permits, ["permit_lake"])
	assert_eq(back.padlocked_slots, ["plot_b"])
	assert_eq(back.beam_recalled_until, 19)


func test_an_empty_dictionary_loads_as_a_brand_new_ledger() -> void:
	var back: Ledger = LedgerScript.from_dict({})
	assert_eq(back.balance, LedgerScript.STARTING_BALANCE)
	assert_eq(back.quota, LedgerScript.STARTING_QUOTA)


func test_junk_is_clamped_rather_than_trusted() -> void:
	var back: Ledger = LedgerScript.from_dict({"quota": -4, "tier": 900,
		"revoked_permits": "not an array"})
	assert_eq(back.quota, 0, "a negative quota is no quota, not a bonus")
	assert_eq(back.tier, LedgerScript.LADDER.size(), "the ladder has a top")
	assert_eq(back.revoked_permits, [])
