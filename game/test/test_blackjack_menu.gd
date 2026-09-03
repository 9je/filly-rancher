extends GutTest
## THE BLACKJACK TABLE'S PANEL, and the placard beside it.

const BlackjackMenuScene := preload("res://ui/blackjack_menu.tscn")
const BlackjackScript := preload("res://systems/blackjack.gd")
const TableMenuScript := preload("res://ui/table_menu.gd")

var _menu: BlackjackMenu = null
var _chips := 500


func before_each() -> void:
	_chips = 500
	_menu = BlackjackMenuScene.instantiate()
	add_child_autofree(_menu)
	_menu.can_open = func() -> bool: return true
	_menu.chips_provider = func() -> int: return _chips
	_menu.open()


func test_every_stake_at_every_table_is_an_even_number_of_chips() -> void:
	for stake in TableMenuScript.STAKES:
		assert_eq(stake % 2, 0,
			"blackjack pays three to two with integer division; an odd stake would round "
				+ "the bonus down by half a chip")


func test_the_placard_tab_prints_the_house_rules() -> void:
	_menu.set_tab(BlackjackMenu.Tab.PLACARD)
	var drawn: Array[String] = _menu.drawn_lines()
	for line in BlackjackScript.placard_lines():
		assert_true(drawn.has(line), "missing placard line: %s" % line)


func test_confirming_at_the_placard_deals_nothing() -> void:
	watch_signals(_menu)
	_menu.set_tab(BlackjackMenu.Tab.PLACARD)
	assert_false(_menu.confirm())
	assert_signal_not_emitted(_menu, "deal_requested")


func test_confirming_at_the_table_emits_the_stake() -> void:
	watch_signals(_menu)
	_menu.set_tab(BlackjackMenu.Tab.TABLE)
	assert_true(_menu.confirm())
	assert_signal_emitted_with_parameters(_menu, "deal_requested", [_menu.stakes()[0]])


func test_an_empty_purse_refuses_to_deal() -> void:
	_chips = 0
	_menu.refresh()
	watch_signals(_menu)
	assert_false(_menu.confirm())
	assert_signal_not_emitted(_menu, "deal_requested")


func test_a_dealt_hand_is_shown_as_cards_and_a_verdict() -> void:
	_menu.show_result(["You: Ace, King", "Dealer: Nine, Seven", "Blackjack. Pays three to two."])
	var drawn: String = "\n".join(_menu.drawn_lines())
	assert_true(drawn.contains("You: Ace, King"))
	assert_true(drawn.contains("Blackjack. Pays three to two."))


func test_nothing_it_draws_carries_a_dash() -> void:
	for tab in [BlackjackMenu.Tab.TABLE, BlackjackMenu.Tab.PLACARD]:
		_menu.set_tab(tab)
		for line in _menu.drawn_lines():
			assert_false(line.contains("--") or line.contains("—"), line)


## THE REPORT: "each table screen shows your chips, the stake picker, and what keys do
## what". A table that only says "Stake: [10 chips]" leaves a player who has not read a
## document with no way to find out what Enter does here.
func test_the_table_says_what_she_is_holding() -> void:
	assert_true(_menu.chips_line().contains(str(_chips)),
		"her chips must be on the screen she is betting them on: %s" % _menu.chips_line())


func test_the_table_says_what_the_keys_do_on_this_table() -> void:
	var keys: String = _menu.keys_line()
	assert_false(keys.is_empty())
	assert_true(keys.to_lower().contains("stake"),
		"the stake picker is the control a new player cannot guess: %s" % keys)


## THE REPORT: "results render prominently (win/lose line with numbers)".
func test_a_settled_result_renders_as_its_own_block_with_the_numbers_in_it() -> void:
	_menu.show_result(["You win 40 chips!", "Two cherries and a bell."])
	var block: Array[String] = _menu.result_block()
	assert_gt(block.size(), 0, "a settled bet must leave something on the screen")
	assert_true("\n".join(block).contains("40"),
		"the number is the whole point of the line")
	assert_true("\n".join(_menu.drawn_lines()).contains("40"),
		"and it is drawn, not merely stored")


const PaintScript := preload("res://ui/casino_paint.gd")
## The file already preloads the SCENE as BlackjackMenuScene; the SCRIPT is what carries the
## Tab enum this file now reads.
const BlackjackMenuScript := preload("res://ui/blackjack_menu.gd")


## THE FELT, THE SHOE, THE STAKE AND BOTH HANDS ALL STAY ON THE STAGE, and neither hand is
## drawn on top of the other. Two hands sharing a row is the failure that looks correct in a
## screenshot of a two card push and wrong the first time somebody draws three.
func test_both_hands_stay_on_the_stage_and_never_overlap_each_other() -> void:
	var stage := Rect2(Vector2.ZERO, _menu.stage_size())
	assert_true(stage.encloses(_menu.shoe_rect()), "the shoe leaves the stage")
	assert_true(stage.encloses(_menu.stake_rect()), "the stake leaves the stage")
	for index: int in 8:
		var player: Rect2 = _menu.card_rect(0, index)
		var dealer: Rect2 = _menu.card_rect(1, index)
		assert_true(stage.encloses(player), "player card %d leaves the stage" % index)
		assert_true(stage.encloses(dealer), "dealer card %d leaves the stage" % index)
		assert_false(player.intersects(dealer),
			"the player's card %d is drawn over the dealer's" % index)


## A SUIT IS PRESENTATION AND CANNOT REACH A NUMBER. Blackjack numbers cards 0 to 51 and never
## names a suit at all; the stage derives one from card / RANKS. This test is the written
## proof that the derivation is one way: two cards of the same rank in different suits are
## worth the same, so a suit cannot move a total, a payout or the published edge.
func test_the_suit_the_stage_derives_cannot_change_a_hand_total() -> void:
	for rank: int in BlackjackScript.RANKS:
		var totals: Array[int] = []
		for suit: int in 4:
			totals.append(BlackjackScript.hand_total([rank + suit * BlackjackScript.RANKS]))
		for total: int in totals:
			assert_eq(total, totals[0],
				"rank %d is worth the same in every suit" % rank)


## THE PLACARD IS READING MATTER AND IS DRAWN AS A PLATE. Its seven lines are unchanged and
## are still what drawn_lines() returns on that tab, because test_published_payouts.gd parses
## the three to two out of them.
func test_the_placard_tab_still_returns_every_placard_line() -> void:
	_menu.set_tab(BlackjackMenuScript.Tab.PLACARD)
	var model: Array[String] = _menu.drawn_lines()
	for line: String in BlackjackScript.placard_lines():
		assert_true(model.has(line), "the model still carries '%s'" % line)
	assert_eq(_menu.row_count(), 0, "the placard is unselectable, as it always was")


## THE PUSHED HAND IS THE HAND THAT LANDS, in the order the strategy card played it.
func test_a_pushed_hand_deals_every_card_it_was_handed() -> void:
	var hand: Dictionary = {
		"player": [0, 12, 25] as Array[int],
		"dealer": [7, 20] as Array[int],
		"outcome": BlackjackScript.Outcome.PLAYER_WIN,
	}
	_menu.show_hand(hand, 20, 10)
	assert_true(_menu.animating(), "the deal is running")
	# Run the tween out rather than waiting on wall clock. A fixed frame count tied to an
	# assumed frame rate is exactly the flake this avoids: headless CI has been observed well
	# north of 100 fps here, so a bound on FRAMES rather than on seconds still settles the deal
	# quickly and a genuinely stuck tween still trips the 2000 frame cap instead of hanging
	# the suite.
	var frames := 0
	while _menu.animating() and frames < 2000:
		await get_tree().process_frame
		frames += 1
	assert_false(_menu.animating(), "the deal has finished")
	assert_eq(_menu.cards_dealt(), 5, "three to the player and two to the dealer")


## A HAND WITH NO CARDS IN IT IS A STILL FRAME. This arrives over a dynamic call() from
## ranch.gd and a gate calling play_blackjack() directly can produce one.
func test_an_empty_or_broken_hand_starts_no_deal() -> void:
	_menu.show_hand({} as Dictionary, 0, 10)
	assert_false(_menu.animating())
	_menu.show_hand({"player": [] as Array[int], "dealer": [] as Array[int], "outcome": 0},
		0, 10)
	assert_false(_menu.animating())


func test_the_focus_id_names_the_stake_on_the_table_tab_and_nothing_on_the_placard() -> void:
	_menu.set_tab(BlackjackMenuScript.Tab.TABLE)
	assert_eq(String(_menu.focused_id()), "stake:0")
	_menu.set_tab(BlackjackMenuScript.Tab.PLACARD)
	assert_eq(String(_menu.focused_id()), "", "reading matter has no cursor")
