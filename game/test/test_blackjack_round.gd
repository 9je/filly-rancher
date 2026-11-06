extends GutTest
## ONE HAND SHE PLAYS HERSELF. The owner's playtest (2026-11-05): "why blackjack i cant make
## decisions?" and "dealer 'stand' after he bust". So: Hit, Stand and Double work and are
## refused when they should be; the dealer's hole card is not in the view until she is done;
## the dealer draws below 17 and stands on any 17; and the banner says "Dealer busts" for a
## dealer who went over, never anything about standing.
##
## Hands are found by seed rather than stacked by hand, so every one is a real deal from the
## real deck code.

const BlackjackScript := preload("res://systems/blackjack.gd")
const RoundScript := preload("res://systems/blackjack_round.gd")

const STAKE := 50


func _deal(seed_value: int) -> RoundScript:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return RoundScript.deal(rng, STAKE) as RoundScript


## The first seed whose fresh deal satisfies `want`, or null.
func _find(want: Callable) -> RoundScript:
	for seed_value in range(1, 20000):
		var hand: RoundScript = _deal(seed_value)
		if want.call(hand):
			return _deal(seed_value)
	return null


func _live(hand: RoundScript) -> bool:
	return not hand.is_settled()


func test_a_fresh_deal_waits_for_her_with_two_cards_each() -> void:
	var hand: RoundScript = _find(_live)
	assert_not_null(hand)
	assert_eq(hand.player.size(), 2)
	assert_eq(hand.dealer.size(), 2)
	assert_true(hand.can_hit() and hand.can_stand() and hand.can_double())
	assert_eq(hand.payout(), 0, "nothing is paid while the hand is being played")


func test_the_hole_card_is_not_in_the_view_until_the_hand_is_over() -> void:
	var hand: RoundScript = _find(_live)
	var seen: Dictionary = hand.view()
	assert_true(bool(seen["hole_hidden"]))
	assert_eq((seen["dealer"] as Array).size(), 1, "only the up card is handed to the table")
	assert_eq(int((seen["dealer"] as Array)[0]), hand.dealer[0])
	hand.stand()
	seen = hand.view()
	assert_false(bool(seen["hole_hidden"]))
	assert_eq((seen["dealer"] as Array).size(), hand.dealer.size(), "every card once she stands")


func test_hit_draws_one_card_and_a_bust_settles_at_once_without_the_dealer_drawing() -> void:
	var hand: RoundScript = _find(func(h) -> bool:
		if h.is_settled():
			return false
		while not h.is_settled():
			h.hit()
		return h.ending == RoundScript.Ending.PLAYER_BUST)
	assert_not_null(hand, "a seed exists where hitting to the end busts")
	var before: int = hand.player.size()
	while not hand.is_settled():
		assert_true(hand.hit())
	assert_gt(hand.player.size(), before)
	assert_gt(hand.player_total(), 21)
	assert_eq(hand.dealer.size(), 2, "a player bust ends it; the dealer draws nothing")
	assert_eq(hand.outcome, BlackjackScript.Outcome.DEALER_WIN)
	assert_eq(hand.payout(), 0)
	assert_eq(RoundScript.headline(hand.ending), "Bust")
	assert_false(hand.hit(), "a settled hand refuses another card")
	assert_false(hand.stand())
	assert_false(hand.double_down())


func test_the_dealer_draws_below_seventeen_and_stands_on_any_seventeen() -> void:
	for seed_value in range(1, 600):
		var hand: RoundScript = _deal(seed_value)
		if hand.is_settled():
			continue
		hand.stand()
		var total: int = hand.dealer_total()
		if total <= 21:
			assert_gte(total, BlackjackScript.DEALER_STANDS_ON, "seed %d" % seed_value)
		# THE LAST CARD WAS NEEDED: without it the dealer was below seventeen.
		if hand.dealer.size() > 2:
			var before: Array[int] = hand.dealer.slice(0, hand.dealer.size() - 1)
			assert_lt(BlackjackScript.hand_total(before), BlackjackScript.DEALER_STANDS_ON,
				"seed %d drew past seventeen" % seed_value)


func test_a_dealer_who_goes_over_busts_and_is_never_said_to_stand() -> void:
	var hand: RoundScript = _find(func(h) -> bool:
		if h.is_settled():
			return false
		h.stand()
		return h.dealer_total() > 21)
	assert_not_null(hand)
	hand.stand()
	assert_eq(hand.ending, RoundScript.Ending.DEALER_BUST)
	assert_eq(hand.outcome, BlackjackScript.Outcome.PLAYER_WIN)
	assert_eq(hand.payout(), STAKE * 2)
	var line: String = RoundScript.headline(hand.ending) + " " + RoundScript.detail(hand.view())
	assert_eq(RoundScript.headline(hand.ending), "Dealer busts")
	assert_false(line.to_lower().contains("stand"), line)


func test_double_doubles_the_stake_takes_exactly_one_card_and_finishes_the_hand() -> void:
	var hand: RoundScript = _find(_live)
	assert_true(hand.double_down())
	assert_true(hand.doubled)
	assert_eq(hand.player.size(), 3, "one card and one only")
	assert_true(hand.is_settled(), "a double stands for her")
	assert_eq(hand.total_staked(), STAKE * 2)
	assert_eq(hand.payout(), BlackjackScript.payout(hand.outcome, STAKE * 2))


func test_double_is_offered_on_the_first_two_cards_only() -> void:
	var hand: RoundScript = _find(func(h) -> bool:
		if h.is_settled():
			return false
		h.hit()
		return not h.is_settled())
	hand.hit()
	assert_false(hand.can_double(), "three cards: too late to double")
	assert_false(hand.double_down())
	assert_false(hand.doubled)


func test_a_natural_settles_on_the_deal() -> void:
	var hand: RoundScript = _find(func(h) -> bool:
		return h.ending == RoundScript.Ending.PLAYER_BLACKJACK)
	assert_not_null(hand)
	assert_true(hand.is_settled())
	assert_eq(hand.payout(), STAKE + STAKE * 3 / 2)
	assert_eq(RoundScript.headline(hand.ending), "Blackjack!")
	var theirs: RoundScript = _find(func(h) -> bool:
		return h.ending == RoundScript.Ending.DEALER_BLACKJACK)
	assert_not_null(theirs)
	assert_false(bool(theirs.view()["hole_hidden"]), "a dealer natural is shown, not hidden")
	assert_eq(theirs.payout(), 0)


func test_twenty_one_stands_for_her() -> void:
	var hand: RoundScript = _find(func(h) -> bool:
		if h.is_settled():
			return false
		h.hit()
		return h.player_total() == 21)
	assert_not_null(hand)
	hand.hit()
	assert_true(hand.is_settled(), "nothing left to decide at 21, so the dealer plays")
	assert_ne(hand.ending, RoundScript.Ending.PLAYER_BUST)


func test_every_ending_has_a_headline_and_none_carries_a_dash() -> void:
	for ending: int in range(1, RoundScript.Ending.TIE + 1):
		var line: String = RoundScript.headline(ending)
		assert_false(line.is_empty(), "ending %d" % ending)
		assert_false(line.contains("--") or line.contains("—"), line)


func test_act_routes_each_action() -> void:
	var hand: RoundScript = _find(_live)
	assert_true(hand.act(RoundScript.Action.STAND))
	assert_true(hand.is_settled())
	assert_false(hand.act(RoundScript.Action.HIT))
	assert_false(hand.act(99))


## THE REFERENCE PLAYER STILL PLAYS THROUGH THIS CLASS, so the dealer on the sign and the
## dealer at the table are one dealer. test_blackjack.gd re measures the published edge.
func test_the_strategy_card_hand_is_the_same_cards_as_a_round_played_by_the_card() -> void:
	for seed_value in [3, 17, 99, 1234]:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var card: Dictionary = BlackjackScript.play_hand(rng)
		var hand: RoundScript = _deal(seed_value)
		while not hand.is_settled() and hand.player_total() < 17:
			hand.hit()
		if not hand.is_settled():
			hand.stand()
		assert_eq(card["player"], hand.player)
		assert_eq(card["dealer"], hand.dealer)
		assert_eq(int(card["outcome"]), hand.outcome)
