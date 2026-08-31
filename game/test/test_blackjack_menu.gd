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
