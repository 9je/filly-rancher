extends GutTest
## THE OWNER'S OWN RUN, REPLAYED ON TODAY'S NUMBERS (PS9; playtest 2026-11-05 item 69: "49
## deliveries came fast; ~800 gems per Market trip mid-game. Pacing and difficulty need a
## pass"). Not a bot playthrough (the owner has banned those): the owner's strategy, as he
## described it, is fed through the game's own pricing functions. His money came from
## sending up every pony that was not one of a kind and keeping the best earners.
##
## What this pins: (1) that first hour of deliveries now credits well under two thirds of
## what it did; (2) a mid-game Market trip of ~800 gems sells for 15% less; (3) at that pace
## the debt still comes down each collection period, so the story stays finishable. How
## many deliveries a player MAKES in an hour depends on the catching (test_beam_weave,
## test_flee_smarter) and is the owner's next playtest to judge; no model of hands can.

const LedgerScript := preload("res://systems/ledger.gd")
const EconomyScript := preload("res://systems/economy.gd")
const ProductionScript := preload("res://systems/production.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")

const COMMON := PonyDataScript.Rarity.COMMON
## The owner's first hour: 49 deliveries, three cycles. Mostly Drifters (the herds are mostly
## Drifters), the rest the commons that turned up again and again.
const DRIFTERS_PER_CYCLE := 10
const NAMED_PER_CYCLE := [&"lyra", &"bonbon", &"lyra", &"minuette", &"carrottop", &"lyra"]
## Mid game as he played it: a Paddock, a Big Pen and a Grand Pen, full (17), and a Market
## trip every quarter hour: 765 gems, his "~800".
const RESIDENTS := 17
const TRIP_SECONDS := 900.0


func _first_hour(l: Ledger) -> int:
	var total := 0
	for cycle in 3:
		for i in DRIFTERS_PER_CYCLE:
			total += l.credit_delivery(COMMON, true, LedgerScript.DRIFTER_KIND, cycle)
		for kind: StringName in NAMED_PER_CYCLE:
			total += l.credit_delivery(COMMON, false, kind, cycle)
	return total


func _first_hour_before() -> int:
	return 3 * (DRIFTERS_PER_CYCLE * LedgerScript.DELIVERY_CREDIT_STOCK
		+ NAMED_PER_CYCLE.size() * LedgerScript.delivery_credit(COMMON, false))


func _trip_gems() -> int:
	return int(RESIDENTS * TRIP_SECONDS / ProductionScript.PRODUCTION_PERIOD_SECONDS)


func test_the_owners_first_hour_of_repeats_earns_well_under_two_thirds() -> void:
	var now := _first_hour(LedgerScript.new())
	var before := _first_hour_before()
	gut.p("first hour of deliveries: %d bits now, %d before (%.0f%%)" % [now, before, 100.0 * now / before])
	assert_lt(float(now), before * 0.65)
	assert_gt(float(now), before * 0.4, "but sending ponies up still pays")


func test_a_mid_game_market_trip_sells_for_fifteen_percent_less() -> void:
	var gems := _trip_gems()
	assert_between(gems, 700, 900, "the owner's ~800 gems")
	var e := EconomyScript.new()
	var now := e.sell(COMMON, gems)
	var before: int = gems * 5  # a common gem sold for 5 before PS9
	gut.p("a %d-gem trip: %d bits now, %d before" % [gems, now, before])
	assert_between(float(now), before * 0.75, before * 0.9, "about 15% less")


func test_at_the_owners_pace_the_debt_still_comes_down_each_period() -> void:
	# One collection period mid game: his deliveries, four Market trips of gems paid in, and
	# the period's upkeep (three pens, two permits) and service charge.
	var l := LedgerScript.new()
	var start := l.balance
	_first_hour(l)
	var e := EconomyScript.new()
	l.pay(4 * e.sell(COMMON, _trip_gems()))
	l.run_collection_day(LedgerScript.PERIOD_CYCLES, 3, 2)
	gut.p("debt %d -> %d over one mid-game period" % [start, l.balance])
	assert_lt(l.balance, start)
