extends GutTest
## THE WHEEL'S FELT. Two tabs, because there are two bets, and the guess is part of the bet.

const WheelMenuScene := preload("res://ui/wheel_menu.tscn")
const WheelScript := preload("res://systems/wheel.gd")

var _menu: WheelMenu = null
var _chips := 500


func before_each() -> void:
	_chips = 500
	_menu = WheelMenuScene.instantiate()
	add_child_autofree(_menu)
	_menu.can_open = func() -> bool: return true
	_menu.chips_provider = func() -> int: return _chips
	_menu.open()


func test_it_opens_on_the_colour_bet() -> void:
	assert_eq(_menu.tab(), WheelMenu.Tab.COLOUR)


func test_the_colour_tab_offers_six_colours_and_never_the_house_pocket() -> void:
	_menu.set_tab(WheelMenu.Tab.COLOUR)
	assert_eq(_menu.guess_count(), 6)
	for i in _menu.guess_count():
		assert_ne(i, WheelScript.Colour.HOUSE)


func test_the_number_tab_offers_every_number_and_no_zero() -> void:
	_menu.set_tab(WheelMenu.Tab.NUMBER)
	assert_eq(_menu.guess_count(), WheelScript.NUMBERS)
	_menu.move_selection(0)
	assert_eq(_menu.selected_guess(), 1, "the numbers start at one; zero is the house's")


func test_confirming_a_colour_bet_emits_kind_guess_and_stake() -> void:
	watch_signals(_menu)
	_menu.set_tab(WheelMenu.Tab.COLOUR)
	_menu.move_selection(3)
	_menu.set_stake_index(0)
	assert_true(_menu.confirm())
	assert_signal_emitted_with_parameters(_menu, "bet_requested",
		[WheelMenu.Tab.COLOUR, 3, _menu.stakes()[0]])


func test_an_empty_purse_refuses_to_bet() -> void:
	_chips = 0
	_menu.refresh()
	watch_signals(_menu)
	assert_false(_menu.confirm())
	assert_signal_not_emitted(_menu, "bet_requested")


func test_the_felt_carries_the_wheel_s_own_rules() -> void:
	var drawn: String = "\n".join(_menu.drawn_lines())
	for line in WheelScript.rules_lines():
		assert_true(drawn.contains(line), "missing rule line: %s" % line)


func test_nothing_it_draws_carries_a_dash() -> void:
	_menu.show_result([WheelScript.pocket_text(7), "You win 60 chips."])
	for tab in [WheelMenu.Tab.COLOUR, WheelMenu.Tab.NUMBER]:
		_menu.set_tab(tab)
		for line in _menu.drawn_lines():
			assert_false(line.contains("--") or line.contains("—"), line)
