extends GutTest
## A REPEAT DELIVERY PAYS LESS (PS9, playtest 2026-11-05 item 69: "49 deliveries came fast;
## ~800 gems per Market trip mid-game"). The owner's money came from sending up every pony
## who was not one of a kind. So within one cycle the same kind pays full, then 70%, 50%, and
## 35% from the fourth on; every Drifter is one kind; a new cycle starts the count again.

const LedgerScript := preload("res://systems/ledger.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")

const COMMON := PonyDataScript.Rarity.COMMON


func test_the_same_pony_pays_less_each_time_in_a_cycle() -> void:
	var l := LedgerScript.new()
	var full: int = LedgerScript.delivery_credit(COMMON, false)
	var paid: Array[int] = []
	for i in 5:
		paid.append(l.credit_delivery(COMMON, false, &"lyra", 1))
	assert_eq(paid, [full, int(round(full * 0.7)), int(round(full * 0.5)),
		int(round(full * 0.35)), int(round(full * 0.35))])


func test_a_different_pony_is_paid_in_full() -> void:
	var l := LedgerScript.new()
	var full: int = LedgerScript.delivery_credit(COMMON, false)
	l.credit_delivery(COMMON, false, &"lyra", 1)
	l.credit_delivery(COMMON, false, &"lyra", 1)
	assert_eq(l.credit_delivery(COMMON, false, &"bonbon", 1), full)


func test_every_drifter_counts_as_one_kind() -> void:
	var l := LedgerScript.new()
	var full: int = LedgerScript.delivery_credit(COMMON, true)
	assert_eq(l.credit_delivery(COMMON, true, LedgerScript.DRIFTER_KIND, 2), full)
	assert_eq(l.credit_delivery(COMMON, true, LedgerScript.DRIFTER_KIND, 2), int(round(full * 0.7)))


func test_a_new_cycle_pays_in_full_again() -> void:
	var l := LedgerScript.new()
	var full: int = LedgerScript.delivery_credit(COMMON, false)
	for i in 3:
		l.credit_delivery(COMMON, false, &"lyra", 1)
	assert_eq(l.credit_delivery(COMMON, false, &"lyra", 2), full)


func test_the_quote_matches_what_is_paid_and_spends_nothing() -> void:
	var l := LedgerScript.new()
	l.credit_delivery(COMMON, false, &"lyra", 1)
	var quoted: int = l.quote_delivery(COMMON, false, &"lyra", 1)
	assert_eq(quoted, l.quote_delivery(COMMON, false, &"lyra", 1), "a quote does not count")
	assert_eq(l.credit_delivery(COMMON, false, &"lyra", 1), quoted)


func test_the_count_survives_a_save() -> void:
	var l := LedgerScript.new()
	l.credit_delivery(COMMON, false, &"lyra", 1)
	var back: Ledger = LedgerScript.from_dict(JSON.parse_string(JSON.stringify(l.to_dict())))
	assert_eq(back.quote_delivery(COMMON, false, &"lyra", 1),
		int(round(LedgerScript.delivery_credit(COMMON, false) * 0.7)))
