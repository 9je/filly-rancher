extends GutTest
## THE LOBBY: the cage, the house sign, and the four doors. The menu draws and emits; it
## never touches a wallet, a purse or a GameState, and the whole of it is driven here from
## four lambdas.

const CasinoMenuScene := preload("res://ui/casino_menu.tscn")
const CasinoSignScript := preload("res://systems/casino_sign.gd")
const SlotsScript := preload("res://systems/slots.gd")
const WheelScript := preload("res://systems/wheel.gd")
const BlackjackScript := preload("res://systems/blackjack.gd")
const RaceCardScript := preload("res://systems/race_card.gd")

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
	_menu.sign_provider = func() -> Array[String]: return CasinoSignScript.lines()
	_menu.open()


func test_it_opens_on_the_lobby_and_refuses_to_open_twice() -> void:
	assert_true(_menu.is_open())
	assert_eq(_menu.tab(), CasinoMenu.Tab.LOBBY)
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


func test_the_rules_tab_draws_whatever_the_sign_provider_says() -> void:
	_menu.set_tab(CasinoMenu.Tab.RULES)
	assert_true(_menu.drawn_lines().has(CasinoSignScript.HEADLINE))


func test_the_selection_wraps_rather_than_falling_off_the_end() -> void:
	_menu.move_selection(-1)
	assert_eq(_menu.selected_index(), CasinoMenu.LOBBY_ROWS.size() - 1)


func test_switching_tabs_wraps_and_resets_the_selection() -> void:
	_menu.set_tab(CasinoMenu.Tab.CAGE)
	_menu.move_selection(2)
	_menu.switch_tab(1)
	assert_eq(_menu.tab(), CasinoMenu.Tab.RULES, "cage steps forward to rules")
	assert_eq(_menu.selected_index(), 0, "switching tabs resets the selection")
	_menu.switch_tab(1)
	assert_eq(_menu.tab(), CasinoMenu.Tab.LOBBY, "three tabs, and it comes round")


func test_closing_announces_itself_once() -> void:
	watch_signals(_menu)
	_menu.close()
	_menu.close()
	assert_signal_emit_count(_menu, "closed", 1)
	assert_false(_menu.is_open())


## THE REPORT: "entering the Palace opens ONE lobby screen with big obvious rows".
func test_it_opens_on_the_lobby_with_one_row_per_room() -> void:
	assert_eq(_menu.tab(), CasinoMenu.Tab.LOBBY)
	var drawn: Array[String] = _menu.drawn_lines()
	assert_eq(drawn.size(), CasinoMenu.LOBBY_ROWS.size())
	for wanted: String in ["Cage", "Slots", "Wheel", "Blackjack", "Racing", "House rules"]:
		assert_true("\n".join(drawn).contains(wanted), "the lobby must offer %s" % wanted)


func test_every_lobby_row_says_what_it_is_for() -> void:
	for line: String in _menu.drawn_lines():
		assert_gt(line.length(), 12,
			"a bare noun is not a row a new player can choose from: %s" % line)


func test_the_lobby_shows_what_she_is_holding_in_both_currencies() -> void:
	var header: String = _menu.header_line()
	assert_true(header.contains(str(_bits)), "her bits: %s" % header)
	assert_true(header.contains(str(_chips)), "her chips: %s" % header)


func test_choosing_a_game_row_asks_for_that_room() -> void:
	watch_signals(_menu)
	_menu.move_selection(CasinoMenu.Row.WHEEL)
	assert_true(_menu.confirm())
	assert_signal_emitted_with_parameters(_menu, "room_requested", [CasinoMenu.Row.WHEEL])


func test_choosing_the_cage_row_opens_the_cage_rather_than_a_table() -> void:
	watch_signals(_menu)
	_menu.move_selection(CasinoMenu.Row.CAGE)
	assert_true(_menu.confirm())
	assert_signal_emitted_with_parameters(_menu, "room_requested", [CasinoMenu.Row.CAGE])
	_menu.set_tab(CasinoMenu.Tab.CAGE)
	assert_eq(_menu.tab(), CasinoMenu.Tab.CAGE)


## THE REPORT: "the cage explains itself (bits to chips, one to one, both ways)".
func test_the_cage_explains_itself_before_it_offers_a_single_amount() -> void:
	_menu.set_tab(CasinoMenu.Tab.CAGE)
	var drawn: String = "\n".join(_menu.drawn_lines())
	assert_true(drawn.to_lower().contains("one for one"), drawn)
	assert_true(drawn.to_lower().contains("both ways"), drawn)


func test_the_cage_still_offers_only_what_she_can_cover_in_both_directions() -> void:
	_bits = 250
	_chips = 0
	_menu.set_tab(CasinoMenu.Tab.CAGE)
	_menu.refresh()
	var drawn: String = "\n".join(_menu.drawn_lines())
	assert_true(drawn.contains("Buy"))
	assert_false(drawn.contains("Cash out"), "there is nothing to cash out")


func test_the_house_rules_tab_carries_every_game_s_real_edge() -> void:
	_menu.set_tab(CasinoMenu.Tab.RULES)
	var drawn: String = "\n".join(_menu.drawn_lines())
	for edge: float in [SlotsScript.house_edge(), WheelScript.house_edge(),
			BlackjackScript.house_edge(), RaceCardScript.TAKEOUT]:
		assert_true(drawn.contains("%.1f" % (edge * 100.0)),
			"the published edge %.1f is missing from the rules page" % (edge * 100.0))


func test_nothing_the_lobby_draws_carries_a_dash() -> void:
	for tab: int in [CasinoMenu.Tab.LOBBY, CasinoMenu.Tab.CAGE, CasinoMenu.Tab.RULES]:
		_menu.set_tab(tab)
		for line: String in _menu.drawn_lines() + [_menu.header_line()]:
			assert_false(line.contains("--") or line.contains("—"), line)
