extends GutTest
## THE RACE PANEL: pick a pony, read the odds, back a lane. It never runs a race, never
## touches a pen and never moves a chip.

const RaceMenuScene := preload("res://ui/race_menu.tscn")
const RaceCardScript := preload("res://systems/race_card.gd")
const CompanyRunnersScript := preload("res://systems/company_runners.gd")

var _menu: RaceMenu = null
var _chips := 500


func _entrants() -> Array[Dictionary]:
	return [
		{"uid": &"a#000001", "name": "Bramble", "happiness": 0.5},
		{"uid": &"b#000002", "name": "Pip", "happiness": 0.9},
	]


func _field() -> Array[Dictionary]:
	return RaceCardScript.build_field({
		"name": "Bramble", "uid": &"a#000001", "data_id": &"stock_bold",
		"speed": 4.0, "stamina": 1.0, "spirit": 1.0, "happiness": 0.5, "stock": {},
	}, CompanyRunnersScript.load_shipped())


func before_each() -> void:
	_chips = 500
	_menu = RaceMenuScene.instantiate()
	add_child_autofree(_menu)
	_menu.can_open = func() -> bool: return true
	_menu.chips_provider = func() -> int: return _chips
	_menu.entrants_provider = func() -> Array[Dictionary]: return _entrants()
	_menu.open()


func test_it_opens_on_the_entry_list() -> void:
	assert_eq(_menu.tab(), RaceMenu.Tab.ENTER)
	assert_eq(_menu.drawn_lines().size(), 2)


func test_with_no_penned_ponies_it_says_so_and_enters_nobody() -> void:
	_menu.entrants_provider = func() -> Array[Dictionary]: return []
	_menu.refresh()
	watch_signals(_menu)
	assert_false(_menu.confirm())
	assert_signal_not_emitted(_menu, "entrant_chosen")
	assert_true("\n".join(_menu.drawn_lines()).contains("pen"))


func test_choosing_an_entrant_emits_her_uid() -> void:
	watch_signals(_menu)
	_menu.move_selection(1)
	assert_true(_menu.confirm())
	assert_signal_emitted_with_parameters(_menu, "entrant_chosen", [&"b#000002"])
	assert_eq(_menu.selected_entrant_uid(), &"b#000002")


func test_the_bet_tab_shows_six_lanes_with_the_odds_they_were_given() -> void:
	var field: Array[Dictionary] = _field()
	var odds: Array[float] = []
	for lane in RaceCardScript.LANES:
		odds.append(RaceCardScript.decimal_odds(field, lane))
	_menu.set_field(field, odds)
	_menu.set_tab(RaceMenu.Tab.BET)
	var drawn: Array[String] = _menu.drawn_lines()
	assert_eq(drawn.size(), RaceCardScript.LANES)
	assert_true(drawn[0].contains(RaceCardScript.odds_text(odds[0])),
		"the panel shows the odds it was handed: %s" % drawn[0])


func test_the_bet_tab_with_no_field_yet_asks_her_to_enter_a_pony_first() -> void:
	_menu.set_tab(RaceMenu.Tab.BET)
	assert_true("\n".join(_menu.drawn_lines()).contains("Enter"))


func test_backing_a_lane_emits_the_entrant_the_lane_and_the_stake() -> void:
	var field: Array[Dictionary] = _field()
	var odds: Array[float] = []
	for lane in RaceCardScript.LANES:
		odds.append(RaceCardScript.decimal_odds(field, lane))
	_menu.move_selection(0)
	_menu.confirm()
	_menu.set_field(field, odds)
	_menu.set_tab(RaceMenu.Tab.BET)
	_menu.move_selection(2)
	_menu.set_stake_index(1)
	watch_signals(_menu)
	assert_true(_menu.confirm())
	assert_signal_emitted_with_parameters(_menu, "race_requested",
		[&"a#000001", 2, _menu.stakes()[1]])


func test_an_empty_purse_cannot_back_anything() -> void:
	var field: Array[Dictionary] = _field()
	var odds: Array[float] = []
	for lane in RaceCardScript.LANES:
		odds.append(RaceCardScript.decimal_odds(field, lane))
	_menu.set_field(field, odds)
	_menu.set_tab(RaceMenu.Tab.BET)
	_chips = 0
	_menu.refresh()
	watch_signals(_menu)
	assert_false(_menu.confirm())
	assert_signal_not_emitted(_menu, "race_requested")


func test_the_card_tab_explains_where_the_odds_come_from() -> void:
	_menu.set_tab(RaceMenu.Tab.CARD)
	var drawn: String = "\n".join(_menu.drawn_lines())
	assert_true(drawn.contains("%.1f" % (RaceCardScript.TAKEOUT * 100.0)))


func test_nothing_it_draws_carries_a_dash() -> void:
	var field: Array[Dictionary] = _field()
	var odds: Array[float] = []
	for lane in RaceCardScript.LANES:
		odds.append(RaceCardScript.decimal_odds(field, lane))
	_menu.set_field(field, odds)
	for tab in [RaceMenu.Tab.ENTER, RaceMenu.Tab.BET, RaceMenu.Tab.CARD]:
		_menu.set_tab(tab)
		for line in _menu.drawn_lines():
			assert_false(line.contains("--") or line.contains("—"), line)
