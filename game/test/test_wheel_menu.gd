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


## THE GAP THIS PINS. WheelMenu's class comment promised that "the stake is the left and
## right of the stake line, so a whole bet is three key presses", and nothing on this panel
## ever called set_stake_index() from an input path: up and down picked a guess and left and
## right always switched the felt's two tabs, so `_stake_index` sat at zero for the whole
## life of the panel and no key on the keyboard could raise the bet above the cheapest one.
## The same defect RaceMenu had, fixed the same way and pinned the same way.
##
## THIS DRIVES THE REAL INPUT METHODS ONLY: move_selection(), switch_tab() and confirm(),
## never set_stake_index() itself, which is exactly what an up/down/left/right/Enter press
## through TableMenu's own _unhandled_input() would reach.
func test_moving_past_the_last_guess_reaches_the_stake_and_raises_it() -> void:
	_menu.set_tab(WheelMenu.Tab.COLOUR)
	_menu.move_selection(3)
	assert_eq(_menu.selected_guess(), 3, "sanity: three presses down lands on the fourth colour")

	# ONE MORE PRESS OF THE SAME SIZE CARRIES PAST THE REMAINING COLOURS ONTO THE STAKE ROW
	# (row_count() is guess_count() + 1), and must not quietly change what a bet lands on.
	_menu.move_selection(3)
	assert_eq(_menu.selected_index(), _menu.guess_count(),
		"the cursor is one row past the last colour: the stake")
	assert_eq(_menu.selected_guess(), 3,
		"the cursor moved on to the stake row; the backed colour must not have moved with it")

	assert_eq(_menu.stake_index(), 0, "sanity: still the cheapest stake before touching it")
	_menu.switch_tab(1)
	assert_eq(_menu.tab(), WheelMenu.Tab.COLOUR,
		"left/right on the stake row must move the stake, not leave the tab")
	assert_eq(_menu.stake_index(), 1, "one press on the stake row must raise the stake")

	watch_signals(_menu)
	assert_true(_menu.confirm())
	assert_signal_emitted_with_parameters(_menu, "bet_requested",
		[WheelMenu.Tab.COLOUR, 3, _menu.stakes()[1]])


func test_left_and_right_still_switch_the_felt_s_tabs_anywhere_but_the_stake_row() -> void:
	_menu.set_tab(WheelMenu.Tab.COLOUR)
	_menu.move_selection(2)
	_menu.switch_tab(1)
	assert_eq(_menu.tab(), WheelMenu.Tab.NUMBER, "over a guess, left and right are the tabs")
	assert_eq(_menu.stake_index(), 0, "and they leave the stake alone")


func test_the_number_tab_reaches_the_stake_the_same_way() -> void:
	_menu.set_tab(WheelMenu.Tab.NUMBER)
	_menu.move_selection(-1)
	assert_eq(_menu.selected_index(), _menu.guess_count(),
		"one press UP from the first number wraps straight onto the stake row")
	assert_eq(_menu.selected_guess(), 1,
		"wrapping past every number must not change which pocket is backed")
	_menu.switch_tab(1)
	assert_eq(_menu.stake_index(), 1)
	assert_eq(_menu.tab(), WheelMenu.Tab.NUMBER)


func test_the_footer_documents_where_the_stake_actually_lives() -> void:
	assert_true(_menu._footer.text.to_lower().contains("stake"),
		"the footer must say where left/right moves the stake, or nobody will find it")
