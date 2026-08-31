extends GutTest
## THE LOBBY: the cage, the house sign, and the four doors. The menu draws and emits; it
## never touches a wallet, a purse or a GameState, and the whole of it is driven here from
## four lambdas.

const CasinoMenuScene := preload("res://ui/casino_menu.tscn")

var _menu: CasinoMenu = null
var _bits := 1000
var _chips := 250


func before_each() -> void:
	_bits = 1000
	_chips = 250
	_menu = CasinoMenuScene.instantiate()
	add_child_autofree(_menu)
	_menu.can_open = func() -> bool: return true
	_menu.bits_provider = func() -> int: return _bits
	_menu.chips_provider = func() -> int: return _chips
	_menu.sign_provider = func() -> Array[String]: return ["Spectra Palace", "Honest odds."]
	_menu.open()


func test_it_opens_on_the_cage_and_refuses_to_open_twice() -> void:
	assert_true(_menu.is_open())
	assert_eq(_menu.tab(), CasinoMenu.Tab.CAGE)
	assert_false(_menu.open(), "already open")


func test_a_shut_door_refuses_to_open() -> void:
	_menu.close()
	_menu.can_open = func() -> bool: return false
	assert_false(_menu.open(), "the Palace can be shut to her; the ban slice needs this")
	assert_false(_menu.is_open())


func test_the_cage_never_offers_a_buy_in_she_cannot_afford() -> void:
	_bits = 700
	_menu.refresh()
	for amount in _menu.buy_amounts():
		assert_lte(amount, 700)
		assert_gt(amount, 0)


func test_the_cage_offers_everything_she_has_when_that_beats_every_step() -> void:
	_bits = 50000
	_menu.refresh()
	var amounts: Array[int] = _menu.buy_amounts()
	assert_eq(amounts[amounts.size() - 1], 50000)


func test_an_empty_wallet_offers_no_buy_in_at_all() -> void:
	_bits = 0
	_menu.refresh()
	assert_true(_menu.buy_amounts().is_empty(), "a row that always refuses is a row that lies")


func test_the_cage_never_offers_a_cash_out_larger_than_the_purse() -> void:
	_chips = 130
	_menu.refresh()
	for amount in _menu.cash_amounts():
		assert_lte(amount, 130)
		assert_gt(amount, 0)


func test_confirming_a_buy_in_emits_the_amount_and_transacts_nothing_itself() -> void:
	watch_signals(_menu)
	_menu.set_tab(CasinoMenu.Tab.CAGE)
	var amount: int = _menu.buy_amounts()[0]
	assert_true(_menu.confirm())
	assert_signal_emitted_with_parameters(_menu, "buy_chips_requested", [amount])
	assert_eq(_bits, 1000, "the menu draws and emits; ranch.gd is what moves money")
	assert_eq(_chips, 250)


func test_the_house_tab_draws_whatever_the_sign_provider_says() -> void:
	_menu.set_tab(CasinoMenu.Tab.HOUSE)
	assert_true(_menu.drawn_lines().has("Honest odds."))


func test_the_games_tab_lists_four_doors_and_emits_the_one_chosen() -> void:
	watch_signals(_menu)
	_menu.set_tab(CasinoMenu.Tab.GAMES)
	assert_eq(_menu.drawn_lines().size(), CasinoMenu.GAME_NAMES.size())
	assert_eq(CasinoMenu.GAME_NAMES.size(), 4)
	_menu.move_selection(1)
	assert_true(_menu.confirm())
	assert_signal_emitted_with_parameters(_menu, "game_requested", [CasinoMenu.Game.WHEEL])


func test_the_selection_wraps_rather_than_falling_off_the_end() -> void:
	_menu.set_tab(CasinoMenu.Tab.GAMES)
	_menu.move_selection(-1)
	assert_eq(_menu.selected_index(), CasinoMenu.GAME_NAMES.size() - 1)


func test_switching_tabs_wraps_and_resets_the_selection() -> void:
	_menu.set_tab(CasinoMenu.Tab.GAMES)
	_menu.move_selection(2)
	_menu.switch_tab(1)
	assert_eq(_menu.tab(), CasinoMenu.Tab.CAGE, "three tabs, and it comes round")
	assert_eq(_menu.selected_index(), 0)


func test_nothing_it_draws_carries_a_dash() -> void:
	for tab in [CasinoMenu.Tab.CAGE, CasinoMenu.Tab.HOUSE, CasinoMenu.Tab.GAMES]:
		_menu.set_tab(tab)
		for line in _menu.drawn_lines():
			assert_false(line.contains("--") or line.contains("—"), line)


func test_closing_announces_itself_once() -> void:
	watch_signals(_menu)
	_menu.close()
	_menu.close()
	assert_signal_emit_count(_menu, "closed", 1)
	assert_false(_menu.is_open())
