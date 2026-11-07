extends GutTest
## SPLIT (PS5, playtest 2026-11-05 item 48: "Blackjack plays itself: no Hit/Stand/Double/
## Split"). A pair on her first two cards may be split, once, into two hands, each staked at
## the hand's own stake and each dealt one more card; she plays the first to its end, then the
## second; the dealer plays once, after both, and each hand settles on its own. Split aces take
## one card each and stand. Twenty one on a split hand is a win, not a blackjack.
##
## Hands are found by seed, as in test_blackjack_round.gd: every one is a real deal.

const BlackjackScript := preload("res://systems/blackjack.gd")
const RoundScript := preload("res://systems/blackjack_round.gd")

const STAKE := 50


func _deal(seed_value: int) -> RoundScript:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return RoundScript.deal(rng, STAKE) as RoundScript


func _find(want: Callable) -> RoundScript:
	for seed_value in range(1, 40000):
		var hand: RoundScript = _deal(seed_value)
		if want.call(hand):
			return _deal(seed_value)
	return null


func _pair(hand: RoundScript) -> bool:
	return not hand.is_settled() and hand.player[0] % BlackjackScript.RANKS == hand.player[1] % BlackjackScript.RANKS


func _pair_not_aces(hand: RoundScript) -> bool:
	return _pair(hand) and not BlackjackScript.is_ace(hand.player[0])


func test_split_is_offered_on_a_pair_and_only_on_a_pair() -> void:
	var pair := _find(_pair_not_aces)
	assert_not_null(pair, "a seed deals a pair")
	assert_true(pair.can_split(), "a pair can be split")
	var other := _find(func(h: RoundScript) -> bool: return not h.is_settled() and not _pair(h))
	assert_false(other.can_split(), "two different ranks cannot")
	pair.hit()
	assert_false(pair.can_split(), "not after a third card")


func test_a_split_makes_two_staked_hands_of_two_cards() -> void:
	var hand := _find(_pair_not_aces)
	var first: int = hand.player[0]
	var second: int = hand.player[1]
	assert_true(hand.split())
	assert_eq(hand.hand_count(), 2)
	assert_eq(hand.hand_cards(0).size(), 2, "the first hand gets one more card")
	assert_eq(hand.hand_cards(1).size(), 2, "and the second")
	assert_eq(hand.hand_cards(0)[0], first)
	assert_eq(hand.hand_cards(1)[0], second)
	assert_eq(hand.total_staked(), STAKE * 2, "each hand carries the stake")
	assert_eq(hand.active_hand(), 0, "she plays the first hand first")
	assert_false(hand.can_split(), "no splitting again")


func test_she_plays_the_first_hand_then_the_second_and_the_dealer_plays_once() -> void:
	var hand := _find(func(h: RoundScript) -> bool:
		return _pair_not_aces(h) and BlackjackScript.hand_total(h.dealer) < 17)
	assert_not_null(hand)
	hand.split()
	assert_true(hand.stand(), "the first hand stands")
	assert_false(hand.is_settled(), "the second is still to play")
	assert_eq(hand.active_hand(), 1)
	var dealer_before: int = hand.dealer.size()
	assert_true(hand.stand(), "the second hand stands")
	assert_true(hand.is_settled(), "then the round is over")
	assert_gt(hand.dealer.size(), dealer_before, "the dealer drew to seventeen, once, after both hands")
	var paid := 0
	for i in 2:
		paid += BlackjackScript.payout(hand.hand_outcome(i), STAKE)
	assert_eq(hand.payout(), paid, "each hand settles on its own and the payouts add")


func test_split_aces_take_one_card_each_and_stand() -> void:
	var hand := _find(func(h: RoundScript) -> bool: return _pair(h) and BlackjackScript.is_ace(h.player[0]))
	assert_not_null(hand, "a seed deals two aces")
	assert_true(hand.split())
	assert_true(hand.is_settled(), "both aces stood on one card")
	assert_eq(hand.hand_cards(0).size(), 2)
	assert_eq(hand.hand_cards(1).size(), 2)


func test_twenty_one_on_a_split_hand_is_a_win_not_a_blackjack() -> void:
	for seed_value in range(1, 40000):
		var hand := _deal(seed_value)
		if not _pair(hand):
			continue
		hand.split()
		for i in hand.hand_count():
			if BlackjackScript.hand_total(hand.hand_cards(i)) == 21 and hand.hand_cards(i).size() == 2:
				while not hand.is_settled():
					hand.stand()
				assert_ne(hand.hand_outcome(i), BlackjackScript.Outcome.PLAYER_BLACKJACK,
					"seed %d: a split 21 pays even money" % seed_value)
				return
	fail_test("no seed split into a two-card 21")


func test_the_table_sees_both_hands() -> void:
	var hand := _find(_pair_not_aces)
	hand.split()
	var view: Dictionary = hand.view()
	assert_eq((view.get("hands", []) as Array).size(), 2)
	assert_eq(int(view.get("active", -1)), 0)
	assert_false(bool(view.get("can_split", true)))


func test_act_routes_split() -> void:
	var hand := _find(_pair_not_aces)
	assert_true(hand.act(RoundScript.Action.SPLIT))
	assert_eq(hand.hand_count(), 2)
