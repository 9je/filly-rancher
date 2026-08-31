extends GutTest
## BLACKJACK, as arithmetic. Two things are being pinned: that the hand plays by the rules
## on the placard, and that the edge the placard publishes is the edge this code actually
## deals, measured rather than asserted.

const BlackjackScript := preload("res://systems/blackjack.gd")

## Enough hands for the measured edge to sit inside a couple of points. The gate runs the
## full REFERENCE_HANDS; the suite runs this so it stays a suite.
const SAMPLE_HANDS := 20000


func test_an_ace_is_eleven_until_it_has_to_be_one() -> void:
	assert_eq(BlackjackScript.hand_total([0, 12]), 21, "ace and king is twenty one")
	assert_eq(BlackjackScript.hand_total([0, 0]), 12, "two aces is twelve, not twenty two")
	assert_eq(BlackjackScript.hand_total([0, 0, 0]), 13)
	assert_eq(BlackjackScript.hand_total([0, 9, 9]), 21, "ace demotes rather than busting")


func test_the_court_cards_and_the_pips_are_worth_what_they_look_like() -> void:
	assert_eq(BlackjackScript.card_value(0), 11, "rank 0 is the ace")
	assert_eq(BlackjackScript.card_value(1), 2)
	assert_eq(BlackjackScript.card_value(8), 9)
	assert_eq(BlackjackScript.card_value(9), 10, "the ten")
	assert_eq(BlackjackScript.card_value(12), 10, "the king")
	assert_eq(BlackjackScript.card_value(13), 11, "the second suit's ace")


func test_a_blackjack_is_two_cards_and_only_two() -> void:
	assert_true(BlackjackScript.is_blackjack([0, 12]))
	assert_false(BlackjackScript.is_blackjack([9, 4, 5]), "twenty one on three cards is not it")
	assert_false(BlackjackScript.is_blackjack([9, 9]))


func test_the_payout_table_is_the_one_on_the_placard() -> void:
	assert_eq(BlackjackScript.payout(BlackjackScript.Outcome.PLAYER_BLACKJACK, 100), 250,
		"stake back plus three to two")
	assert_eq(BlackjackScript.payout(BlackjackScript.Outcome.PLAYER_WIN, 100), 200)
	assert_eq(BlackjackScript.payout(BlackjackScript.Outcome.PUSH, 100), 100, "a tie is a push")
	assert_eq(BlackjackScript.payout(BlackjackScript.Outcome.DEALER_WIN, 100), 0)


func test_a_zero_or_negative_stake_pays_nothing() -> void:
	assert_eq(BlackjackScript.payout(BlackjackScript.Outcome.PLAYER_BLACKJACK, 0), 0)
	assert_eq(BlackjackScript.payout(BlackjackScript.Outcome.PLAYER_WIN, -100), 0)


func test_a_hand_deals_real_cards_and_never_deals_one_twice() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 500:
		var hand: Dictionary = BlackjackScript.play_hand(rng)
		var seen: Dictionary = {}
		for card in (hand["player"] as Array) + (hand["dealer"] as Array):
			assert_between(int(card), 0, BlackjackScript.DECK_SIZE - 1)
			assert_false(seen.has(card), "one deck, so no card comes out twice in a hand")
			seen[card] = true
		assert_gt((hand["player"] as Array).size(), 1)
		assert_gt((hand["dealer"] as Array).size(), 1)


func test_the_dealer_stands_on_seventeen_and_draws_below_it() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for i in 2000:
		var hand: Dictionary = BlackjackScript.play_hand(rng)
		var dealer: Array = hand["dealer"]
		var total: int = BlackjackScript.hand_total(dealer)
		if int(hand["outcome"]) == BlackjackScript.Outcome.PLAYER_BLACKJACK:
			continue
		if total <= 21 and dealer.size() > 2:
			assert_gte(total, BlackjackScript.DEALER_STANDS_ON,
				"the dealer never stopped below seventeen")


func test_the_house_strategy_card_is_what_the_player_actually_plays() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5678
	for i in 2000:
		var hand: Dictionary = BlackjackScript.play_hand(rng)
		var player: Array = hand["player"]
		var total: int = BlackjackScript.hand_total(player)
		if total <= 21 and player.size() > 2:
			assert_gte(total, BlackjackScript.STRATEGY_DRAWS_BELOW,
				"the card says draw below seventeen and stand on it")


func test_the_same_seed_deals_the_same_hand() -> void:
	var a := RandomNumberGenerator.new()
	a.seed = 31337
	var b := RandomNumberGenerator.new()
	b.seed = 31337
	for i in 100:
		var left: Dictionary = BlackjackScript.play_hand(a)
		var right: Dictionary = BlackjackScript.play_hand(b)
		assert_eq(left["player"], right["player"])
		assert_eq(left["dealer"], right["dealer"])
		assert_eq(left["outcome"], right["outcome"])


func test_the_placard_publishes_the_edge_this_code_actually_deals() -> void:
	var measured: float = BlackjackScript.measure_edge(BlackjackScript.REFERENCE_SEED,
		BlackjackScript.REFERENCE_HANDS)
	assert_almost_eq(BlackjackScript.PUBLISHED_EDGE, measured, 0.0005,
		"PUBLISHED_EDGE must be this measurement written down; it measured %.6f" % measured)


func test_the_published_edge_is_a_sane_number_for_this_strategy() -> void:
	assert_between(BlackjackScript.PUBLISHED_EDGE, 0.01, 0.10,
		"a player mimicking the dealer gives up a few points; far outside that band means "
			+ "the dealing or the settling is wrong, not that the game is unusual")


func test_the_measurement_is_stable_across_seeds() -> void:
	for seed_value in [11, 222, 3333]:
		var measured: float = BlackjackScript.measure_edge(seed_value, SAMPLE_HANDS)
		assert_almost_eq(measured, BlackjackScript.PUBLISHED_EDGE, 0.02,
			"seed %d measured %.4f" % [seed_value, measured])


func test_the_placard_reads_cleanly_and_carries_no_dashes() -> void:
	var lines: Array[String] = BlackjackScript.placard_lines()
	assert_gt(lines.size(), 4)
	for line in lines:
		assert_false(line.is_empty())
		assert_false(line.contains("--") or line.contains("—"), line)
