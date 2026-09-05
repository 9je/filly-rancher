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


## I5, final-review.md I3: THE TABS ARE CLICK TARGETS NOW. MenuStyle.tab_strip() used to
## render the whole strip into one inert Label; the Tabs node is an HBoxContainer of Buttons
## since this fix, one per name, each armed through MouseRows.arm() the same way every row in
## the game is.
func test_the_tab_strip_is_a_row_of_clickable_buttons() -> void:
	var buttons: Array[Button] = []
	for child in _menu.get_node("Centre/Panel/Margin/Column/Tabs").get_children():
		var button := child as Button
		if button != null:
			buttons.append(button)
	assert_eq(buttons.size(), CasinoMenu.TAB_NAMES.size())
	for button: Button in buttons:
		assert_eq(button.focus_mode, Control.FOCUS_NONE,
			"a focusable tab would steal the arrow keys from the menu cursor")


func test_clicking_a_tab_button_switches_to_it() -> void:
	var buttons: Array[Button] = []
	for child in _menu.get_node("Centre/Panel/Margin/Column/Tabs").get_children():
		var button := child as Button
		if button != null:
			buttons.append(button)
	watch_signals(_menu)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	buttons[CasinoMenu.Tab.RULES].gui_input.emit(event)
	assert_eq(_menu.tab(), CasinoMenu.Tab.RULES, "a click on House rules must open House rules")


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


const PaintScript := preload("res://ui/casino_paint.gd")
## The file already preloads the SCENE as CasinoMenuScene; the SCRIPT is what carries
## LOBBY_ROWS and the Tab enum.
const CasinoMenuScript := preload("res://ui/casino_menu.gd")


## SIX TILES IN A 3 BY 2 GRID, none overlapping, none off the stage. The lobby is the first
## screen a player sees in this building and it used to be six sentences in a column.
func test_the_six_lobby_tiles_tile_the_stage_without_overlapping() -> void:
	var stage := Rect2(Vector2.ZERO, _menu.stage_size())
	for i: int in CasinoMenuScript.LOBBY_ROWS.size():
		assert_true(stage.encloses(_menu.tile_rect(i)), "tile %d leaves the stage" % i)
		for j: int in CasinoMenuScript.LOBBY_ROWS.size():
			if i >= j:
				continue
			assert_false(_menu.tile_rect(i).intersects(_menu.tile_rect(j)),
				"tiles %d and %d overlap" % [i, j])


## LOBBY_ROWS IS NOT REWRITTEN. The six strings are what the tiles are TITLED and DESCRIBED
## from, split at their own colon, and the wording is already good.
func test_the_lobby_rows_are_unchanged_and_every_one_splits_at_a_colon() -> void:
	assert_eq(CasinoMenuScript.LOBBY_ROWS.size(), 6)
	assert_eq(CasinoMenuScript.LOBBY_ROWS[1], "Slots: three reels, one lever, the fast one")
	for row: String in CasinoMenuScript.LOBBY_ROWS:
		assert_true(row.contains(": "), "'%s' has no title and description to split" % row)
		assert_false(row.contains("--"), "'%s' carries a dash" % row)


## THE HOUSE RULES PAGE IS WHERE THE PUBLISHED EDGES LIVE NOW. This is the surface the sign
## outside used to be, and it is reachable from the lobby's own picker.
func test_the_rules_tab_still_returns_every_line_the_sign_publishes() -> void:
	_menu.set_tab(CasinoMenuScript.Tab.RULES)
	var model: Array[String] = _menu.drawn_lines()
	assert_eq(model.size(), CasinoSignScript.lines().size())
	for line: String in CasinoSignScript.lines():
		assert_true(model.has(line), "the rules page still carries '%s'" % line)


func test_the_focus_id_names_the_tile_the_cursor_is_on() -> void:
	_menu.set_tab(CasinoMenuScript.Tab.LOBBY)
	assert_eq(String(_menu.focused_id()), "tile:0")
	_menu.move_selection(2)
	assert_eq(String(_menu.focused_id()), "tile:2")
