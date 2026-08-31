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
