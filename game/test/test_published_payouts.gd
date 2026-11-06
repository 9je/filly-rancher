extends GutTest
## THE WALL MUST NOT LIE TO THE DEALER. One test per game, all of them doing the same thing:
## take the lines the Palace actually PRINTS, read the price back out of the English, apply
## it to a stake, and check it against what that game's own payout() hands over for exactly
## that outcome.
##
## THE BUG THIS EXISTS BECAUSE OF. Slots.paytable_lines() printed "Apple Apple Apple pays 4
## to 1" for a TRIPLE_PAYS entry of 4, and Slots.payout() returns 4 x stake TOTAL, the stake
## included. "n to 1" is net odds: the winner takes n and her stake, so the wall was
## promising five stakes back where the machine hands over four. Seven of the eight lines on
## that paytable overstated the pay by exactly one stake. Nothing was wrong with the
## machine, the arithmetic in the class comment, the published house edge or any unit test:
## the only thing wrong was the sentence the player reads before she decides to spend money.
##
## SO THIS TEST READS THE SENTENCE. Not the constants (a test of a constant against itself
## proves nothing about the copy), not a hard coded expected string (that only pins today's
## wording, and would have been written to match the wrong line): the actual published
## lines, parsed. Two conventions are legal in this Palace and both are in use:
##
##   "n to m"   NET odds. A winner takes n for every m staked AND her stake back, so the
##              total return is 1 + n/m stakes. The Wheel and the Blackjack placard use it.
##   "n for 1"  TOTAL return. n stakes come back, the stake among them. The slot machine and
##              the race card use it (RaceCard.odds_text is where the wording comes from).
##
## Printing one and paying the other is the whole of the defect, so the parser knows both
## and the assertion is always the same: number applied to stake == payout().
##
## A PRICED LINE THIS FILE CANNOT TIE TO AN OUTCOME IS A FAILURE, not a skip. That is what
## keeps the guard from rotting quietly: a new priced line nobody wired up here fails loudly
## rather than sailing past unchecked.

const SlotsScript := preload("res://systems/slots.gd")
const WheelScript := preload("res://systems/wheel.gd")
const BlackjackScript := preload("res://systems/blackjack.gd")
const RaceCardScript := preload("res://systems/race_card.gd")
const CompanyRunnersScript := preload("res://systems/company_runners.gd")

## Chips on the line while checking. A hundred, so blackjack's three to two lands on a whole
## chip and the race card's two decimal places are worth half a chip of rounding.
const STAKE := 100

## What _quoted_return() answers for a line that names no price at all.
const NO_PRICE := -1.0

var _to_one: RegEx = null
var _for_one: RegEx = null


func before_all() -> void:
	# "n to m": digits both sides, so "Dealer draws to 16" (no number before the "to") is
	# correctly read as pricing nothing.
	_to_one = RegEx.create_from_string("([0-9]+) to ([0-9]+)")
	# "n for 1", with the decimals the race card prints.
	_for_one = RegEx.create_from_string("([0-9]+(?:\\.[0-9]+)?) for 1")


## One published line, split into the sentences a reader reads it as. Split on ". " rather
## than on "." so a printed price of "3.14 for 1" survives in one piece.
func _clauses(line: String) -> Array[String]:
	var out: Array[String] = []
	for part in line.split(". ", false):
		var text: String = String(part).strip_edges()
		if not text.is_empty():
			out.append(text)
	return out


## How many stakes this sentence PROMISES come back, the stake included, or NO_PRICE if it
## quotes nothing at all.
func _quoted_return(clause: String) -> float:
	var net: RegExMatch = _to_one.search(clause)
	if net != null:
		return 1.0 + float(net.get_string(1)) / float(net.get_string(2))
	var total: RegExMatch = _for_one.search(clause)
	if total != null:
		return float(total.get_string(1))
	# The two prices this Palace writes in words rather than in numbers. Both mean "your
	# stake, and nothing on top of it".
	var lower: String = clause.to_lower()
	if lower.contains("stake back") or lower.contains("is a push"):
		return 1.0
	return NO_PRICE


## Which line on the reels a paytable sentence is pricing, or an empty array if this file
## cannot tell. The triples are matched first, so "Rainbow Rainbow Rainbow" is a triple and
## never the two rainbow line.
func _slots_outcome(clause: String) -> Array[int]:
	var out: Array[int] = []
	for symbol in SlotsScript.SYMBOL_NAMES.size():
		var who: String = String(SlotsScript.SYMBOL_NAMES[symbol])
		if clause.begins_with("%s %s %s" % [who, who, who]):
			out = [symbol, symbol, symbol]
			return out
	if clause.begins_with("Two Rainbows"):
		out = [SlotsScript.Symbol.RAINBOW, SlotsScript.Symbol.RAINBOW,
			SlotsScript.Symbol.APPLE]
		return out
	if clause.begins_with("One Rainbow"):
		out = [SlotsScript.Symbol.RAINBOW, SlotsScript.Symbol.APPLE,
			SlotsScript.Symbol.HORSESHOE]
		return out
	return out


func test_every_price_on_the_slot_machine_s_paytable_is_what_the_reels_actually_pay() -> void:
	var checked := 0
	for line in SlotsScript.paytable_lines():
		for clause in _clauses(line):
			var quoted: float = _quoted_return(clause)
			if quoted < 0.0:
				continue
			var reels: Array[int] = _slots_outcome(clause)
			assert_false(reels.is_empty(),
				"a paytable line quotes a price no outcome in this file is tied to: '%s'"
					% clause)
			if reels.is_empty():
				continue
			var paid: int = SlotsScript.payout(reels, STAKE)
			assert_eq(paid, roundi(quoted * float(STAKE)),
				"'%s' promises %.2f x %d chips back; %s actually pays %d"
					% [clause, quoted, STAKE, SlotsScript.line_text(reels), paid])
			checked += 1
	assert_eq(checked, SlotsScript.SYMBOL_NAMES.size() + 2,
		"one priced line per triple, plus the two rainbow lines")


func test_every_price_on_the_wheel_s_rules_is_what_the_segment_actually_pays() -> void:
	var checked := 0
	for line in WheelScript.rules_lines():
		for clause in _clauses(line):
			var quoted: float = _quoted_return(clause)
			if quoted < 0.0:
				continue
			var tier: int = -1
			for t: int in WheelScript.TIERS:
				if clause.begins_with(WheelScript.TIER_LABELS[t] + " "):
					tier = t
			assert_true(tier >= 0,
				"a priced rule must name exactly one of the wheel's tiers: '%s'" % clause)
			if tier < 0:
				continue
			var bets: Array[int] = WheelScript.empty_bets()
			bets[tier] = STAKE
			var paid: int = WheelScript.payout(bets, WheelScript.LAYOUT.find(tier))
			assert_eq(paid, roundi(quoted * float(STAKE)),
				"'%s' promises %.2f x %d chips back; the winning bet pays %d"
					% [clause, quoted, STAKE, paid])
			checked += 1
	assert_eq(checked, WheelScript.TIERS, "the rules price every tier on the wheel")


func test_every_price_on_the_blackjack_placard_is_what_the_table_actually_pays() -> void:
	var checked := 0
	for line in BlackjackScript.placard_lines():
		for clause in _clauses(line):
			var quoted: float = _quoted_return(clause)
			if quoted < 0.0:
				continue
			var lower: String = clause.to_lower()
			var outcome := -1
			if lower.contains("blackjack pays"):
				outcome = BlackjackScript.Outcome.PLAYER_BLACKJACK
			elif lower.contains("push"):
				outcome = BlackjackScript.Outcome.PUSH
			assert_true(outcome >= 0,
				"a placard line quotes a price no outcome in this file is tied to: '%s'"
					% clause)
			if outcome < 0:
				continue
			var paid: int = BlackjackScript.payout(outcome, STAKE)
			assert_eq(paid, roundi(quoted * float(STAKE)),
				"'%s' promises %.2f x %d chips back; the table pays %d"
					% [clause, quoted, STAKE, paid])
			checked += 1
	assert_gte(checked, 2, "the placard prices a blackjack and a push, at the least")


## THE FOURTH GAME. The race card prints a price per lane rather than a fixed paytable, so
## the lines are generated here rather than read off a constant; everything else is the same
## check. The tolerance is one chip because odds_text() rounds to two decimal places, which
## at a hundred chips is worth half a chip, and payout() does its own rounding on top.
func test_every_price_on_the_race_card_is_what_the_window_actually_pays() -> void:
	var field: Array[Dictionary] = RaceCardScript.build_field({
		"name": "Bramble", "uid": &"a#000001", "data_id": &"stock_bold",
		"speed": 4.0, "stamina": 1.0, "spirit": 1.0, "happiness": 0.5, "stock": {},
	}, CompanyRunnersScript.load_shipped())
	assert_eq(field.size(), RaceCardScript.LANES, "precondition: a full card")
	for lane in field.size():
		var odds: float = RaceCardScript.decimal_odds(field, lane)
		var line: String = RaceCardScript.odds_text(odds)
		var quoted: float = _quoted_return(line)
		assert_gte(quoted, 0.0, "the card's own price line quotes nothing: '%s'" % line)
		if quoted < 0.0:
			continue
		assert_almost_eq(float(RaceCardScript.payout(field, lane, STAKE, lane)),
			quoted * float(STAKE), 1.0,
			"lane %d is priced '%s' and pays %d on a %d chip bet"
				% [lane + 1, line, RaceCardScript.payout(field, lane, STAKE, lane), STAKE])


## The convention itself, pinned in one place so the parser above cannot quietly change its
## mind about what a sentence means.
func test_the_two_conventions_the_parser_knows_are_the_two_the_palace_writes_in() -> void:
	assert_almost_eq(_quoted_return("A number pays 23 to 1"), 24.0, 1e-9,
		"net odds: the winner takes 23 and her stake back")
	assert_almost_eq(_quoted_return("Blackjack pays 3 to 2"), 2.5, 1e-9,
		"net odds again, at a ratio that is not over one")
	assert_almost_eq(_quoted_return("Apple Apple Apple returns 4 for 1"), 4.0, 1e-9,
		"total return: four stakes come back, the stake among them")
	assert_almost_eq(_quoted_return("3.14 for 1"), 3.14, 1e-9,
		"the race card prices to two decimal places")
	assert_almost_eq(_quoted_return("One Rainbow anywhere hands your stake back"), 1.0, 1e-9)
	assert_almost_eq(_quoted_return("A tie is a push"), 1.0, 1e-9)
	assert_eq(_quoted_return("Dealer draws to 16 and stands on 17, hard or soft"), NO_PRICE,
		"a sentence about the rules is not a sentence about a price")
	assert_eq(_quoted_return("One deck, shuffled before every hand"), NO_PRICE)
