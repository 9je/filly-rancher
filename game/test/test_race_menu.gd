extends GutTest
## THE RACE PANEL: pick a pony, read the odds, back a lane. It never runs a race, never
## touches a pen and never moves a chip.

const RaceMenuScene := preload("res://ui/race_menu.tscn")
const RaceCardScript := preload("res://systems/race_card.gd")
const CompanyRunnersScript := preload("res://systems/company_runners.gd")
const MenuStyleScript := preload("res://ui/menu_style.gd")

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


## THE GAP THIS PINS. row_count() used to claim the stake "is moved with left and right the
## way every other table's is", but nothing on the BET tab ever called set_stake_index() from
## an input path: up/down picked a lane and left/right always switched the casino's own tab,
## so a player could never actually reach anything above the cheapest stake. This drives the
## real input methods (move_selection()/switch_tab()/confirm()), never set_stake_index()
## itself, the way a real up/down/left/right/Enter press through TableMenu's own
## _unhandled_input() would.
func test_moving_past_the_last_lane_reaches_the_stake_and_raises_it() -> void:
	var field: Array[Dictionary] = _field()
	var odds: Array[float] = []
	for lane in RaceCardScript.LANES:
		odds.append(RaceCardScript.decimal_odds(field, lane))
	_menu.move_selection(1)
	_menu.confirm()
	_menu.set_field(field, odds)
	_menu.set_tab(RaceMenu.Tab.BET)

	_menu.move_selection(3)
	assert_eq(_menu.selected_lane(), 3, "sanity: three presses down lands on lane 3")
	# ONE MORE STEP OF THE SAME SIZE CARRIES PAST THE REMAINING LANES ONTO THE STAKE ROW
	# (row_count() is LANES + 1), and must not quietly change which lane a bet would land on.
	_menu.move_selection(3)
	assert_eq(_menu.selected_lane(), 3,
		"the cursor moved on to the stake row; the backed lane must not have moved with it")

	assert_eq(_menu.stake_index(), 0, "sanity: still the cheapest stake before touching it")
	_menu.switch_tab(1)
	assert_eq(_menu.tab(), RaceMenu.Tab.BET,
		"left/right on the stake row must move the stake, not leave the tab")
	assert_eq(_menu.stake_index(), 1, "one press on the stake row must raise the stake")

	watch_signals(_menu)
	assert_true(_menu.confirm())
	assert_signal_emitted_with_parameters(_menu, "race_requested",
		[&"b#000002", 3, _menu.stakes()[1]])


## MOVED (Task 4): the footer is now MenuStyle's shared builder, the same as every other
## table's, and no longer carries a hand written note about the stake. Where the stake
## lives is documented in the tab strip instead, which prints it on the BET tab whenever
## a field is up (see RaceMenu.tabs_text()).
func test_the_footer_documents_where_the_stake_actually_lives() -> void:
	assert_eq(_menu._footer.text, MenuStyleScript.footer_tabs_and_rows("confirm", "leave"),
		"the footer now comes from the shared builder, not a hand written line")
	var field: Array[Dictionary] = _field()
	var odds: Array[float] = []
	for lane in RaceCardScript.LANES:
		odds.append(RaceCardScript.decimal_odds(field, lane))
	_menu.set_field(field, odds)
	_menu.set_tab(RaceMenu.Tab.BET)
	assert_true(_menu._tabs.text.to_lower().contains("stake"),
		"the stake position must still be documented somewhere, even off the footer")
