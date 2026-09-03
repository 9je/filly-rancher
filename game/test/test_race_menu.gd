extends GutTest
## THE FORM GUIDE. Every penned pony, her live odds, and a stake. There is no lane to pick:
## your pony IS your bet (spec, amended 2026-08-31, after the playtest verdict that backing
## a Company runner against your own pony felt wrong).
##
## The odds are PUSHED IN with the rows, not worked out here: ranch.gd builds each field and
## asks RaceCard for the price, so this file never sees a PonyInstance and cannot compute a
## number that disagrees with the one the race settles at.

const RaceMenuScene := preload("res://ui/race_menu.tscn")
const RaceCardScript := preload("res://systems/race_card.gd")
const InputDeviceScript := preload("res://systems/input_device.gd")

var _menu: RaceMenu = null
var _chips := 500


func _entrants() -> Array[Dictionary]:
	return [
		{"uid": &"a#000001", "name": "Bramble", "happiness": 0.5,
			"odds": 7.25, "chance": 0.1297},
		{"uid": &"b#000002", "name": "Pip", "happiness": 0.9,
			"odds": 4.10, "chance": 0.2293},
	]


func before_each() -> void:
	InputDeviceScript.reset()
	_chips = 500
	_menu = RaceMenuScene.instantiate()
	add_child_autofree(_menu)
	_menu.can_open = func() -> bool: return true
	_menu.chips_provider = func() -> int: return _chips
	_menu.entrants_provider = func() -> Array[Dictionary]: return _entrants()
	_menu.open()


func test_it_opens_on_the_form_guide() -> void:
	assert_eq(_menu.tab(), RaceMenu.Tab.ENTER)


func test_there_is_no_bet_tab_any_more() -> void:
	# The enum is a plain int enum, so the real claim is about how many tabs there are and
	# what cycling through them reaches.
	var seen := {}
	for i in 6:
		seen[_menu.tab()] = true
		_menu.switch_tab(1)
	assert_eq(seen.size(), 2, "two tabs: the form guide and the card")


## THE SPEC: "the enter screen lists every penned pony with her live odds".
func test_the_form_guide_lists_every_penned_pony_with_her_price() -> void:
	var lines: Array[String] = _menu.form_lines()
	assert_eq(lines.size(), 2, "one row per pony in a pen, and no lanes at all")
	assert_true(lines[0].contains("Bramble"))
	assert_true(lines[0].contains(RaceCardScript.odds_text(7.25)),
		"her price has to be on her own row: %s" % lines[0])
	assert_true(lines[1].contains("Pip"))
	assert_true(lines[1].contains(RaceCardScript.odds_text(4.10)))


## Her happiness is the only thing about her the player can change before the off, so it is
## the only hint the guide carries.
func test_each_row_carries_a_happiness_hint() -> void:
	assert_true(_menu.form_lines()[1].contains("9"),
		"Pip is at 0.9 happiness and the row should say so")


func test_a_stake_row_sits_under_the_last_pony() -> void:
	var drawn: Array[String] = _menu.drawn_lines()
	assert_eq(_menu.row_count(), 3, "two ponies and the stake")
	assert_true(drawn[drawn.size() - 1].to_lower().contains("stake"),
		"the stake is the last row and it is drawn, so the caret can land on it")


func test_with_no_penned_ponies_it_says_so_and_enters_nobody() -> void:
	_menu.entrants_provider = func() -> Array[Dictionary]: return []
	_menu.refresh()
	watch_signals(_menu)
	assert_false(_menu.confirm())
	assert_signal_not_emitted(_menu, "race_requested")
	assert_true("\n".join(_menu.drawn_lines()).contains("pen"))


func test_confirming_on_a_pony_backs_her_at_the_stake_on_the_screen() -> void:
	_menu.set_stake_index(1)
	_menu.move_selection(1)
	watch_signals(_menu)
	assert_true(_menu.confirm())
	assert_signal_emitted_with_parameters(_menu, "race_requested",
		[&"b#000002", _menu.stakes()[1]])
	assert_eq(_menu.selected_entrant_uid(), &"b#000002")


## THE STAKE ROW IS REACHABLE AND SELF EXPLANATORY. It was reachable before only by moving
## past the last lane with nothing drawn under the cursor, which nobody found.
func test_the_stake_row_can_be_moved_with_left_and_right_and_with_confirm() -> void:
	_menu.move_selection(2)
	assert_eq(_menu.selected_index(), 2, "one past the last pony is the stake row")
	assert_eq(_menu.stake_index(), 0)
	_menu.switch_tab(1)
	assert_eq(_menu.tab(), RaceMenu.Tab.ENTER,
		"left and right adjust the stake while the cursor is on it")
	assert_eq(_menu.stake_index(), 1)
	watch_signals(_menu)
	assert_true(_menu.confirm())
	assert_eq(_menu.stake_index(), 2, "confirm on the stake row steps it too")
	assert_signal_not_emitted(_menu, "race_requested",
		"confirming the stake row must not place a bet")


func test_an_empty_purse_cannot_back_anybody() -> void:
	_chips = 0
	_menu.refresh()
	watch_signals(_menu)
	assert_false(_menu.confirm())
	assert_signal_not_emitted(_menu, "race_requested")


func test_the_card_tab_explains_where_the_odds_come_from_and_that_she_backs_her_own() -> void:
	_menu.set_tab(RaceMenu.Tab.CARD)
	var drawn: String = "\n".join(_menu.drawn_lines())
	assert_true(drawn.contains("%.1f" % (RaceCardScript.TAKEOUT * 100.0)))
	assert_true(drawn.to_lower().contains("your own"),
		"the card has to say that the only pony you can back is yours")


func test_the_table_furniture_is_on_this_panel_too() -> void:
	var drawn: String = "\n".join(_menu.drawn_lines())
	assert_true(drawn.contains(str(_chips)), "her chips are on the screen")
	assert_true(drawn.to_lower().contains("stake"))


func test_nothing_it_draws_carries_a_dash() -> void:
	for tab: int in [RaceMenu.Tab.ENTER, RaceMenu.Tab.CARD]:
		_menu.set_tab(tab)
		for line in _menu.drawn_lines():
			assert_false(line.contains("--") or line.contains("—"), line)


const PaintScript := preload("res://ui/casino_paint.gd")
## The file already preloads the SCENE as RaceMenuScene; the SCRIPT is what carries
## CARDS_VISIBLE and the Tab enum.
const RaceMenuScript := preload("res://ui/race_menu.gd")


## ONE CARD PER ENTRANT, STACKED, NONE OVERLAPPING, NONE OFF THE STAGE.
func test_the_form_cards_stack_without_overlapping() -> void:
	var stage := Rect2(Vector2.ZERO, _menu.stage_size())
	for i: int in mini(_menu.entrants().size(), RaceMenuScript.CARDS_VISIBLE):
		assert_true(stage.encloses(_menu.card_rect(i)), "card %d leaves the stage" % i)
		if i == 0:
			continue
		assert_false(_menu.card_rect(i - 1).intersects(_menu.card_rect(i)),
			"cards %d and %d overlap" % [i - 1, i])


## THE WINDOW FOLLOWS THE CURSOR. More ponies than CARDS_VISIBLE is an ordinary state (a pen
## holds more than five), and a cursor that walked off the bottom of a fixed window would be a
## cursor the player cannot see.
func test_the_visible_window_keeps_the_focused_card_on_screen() -> void:
	var many: Array[Dictionary] = []
	for i: int in 9:
		many.append({"uid": StringName("p%d" % i), "name": "Pony %d" % i,
			"happiness": 0.5, "odds": 4.0, "chance": 0.2})
	_menu.entrants_provider = func() -> Array[Dictionary]: return many
	_menu.refresh()
	for row: int in 9:
		_menu.move_selection(1 if row > 0 else 0)
		var first: int = _menu.first_visible_card()
		assert_between(_menu.selected_index() - first, 0,
			RaceMenuScript.CARDS_VISIBLE - 1,
			"row %d is outside the visible window starting at %d" % [row, first])


## form_lines() IS UNCHANGED, and that is what keeps this file's older tests and the odds
## parser green. The swatch is drawn from two NEW keys and nothing else moved.
func test_the_form_lines_are_unchanged_and_a_missing_swatch_falls_back() -> void:
	var lines: Array[String] = _menu.form_lines()
	assert_gt(lines.size(), 0)
	for line: String in lines:
		assert_true(line.contains(" pays "), "'%s' still reads as the shipped sentence" % line)
		assert_true(line.contains("spirits"))
	# The fixture's entrants carry no coat or mane; the card still draws.
	_menu.refresh()
	assert_ne(String(_menu.focused_id()), "", "a colourless entrant still gets a card")


func test_the_focus_walks_the_cards_and_then_the_stake() -> void:
	assert_eq(String(_menu.focused_id()), "entrant:0")
	_menu.move_selection(_menu.entrants().size())
	assert_eq(String(_menu.focused_id()), "stake:%d" % _menu.stake_index())
