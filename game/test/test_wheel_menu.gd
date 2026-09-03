extends GutTest
## THE WHEEL'S FELT. Two tabs, because there are two bets, and the guess is part of the bet.

const WheelMenuScene := preload("res://ui/wheel_menu.tscn")
const WheelScript := preload("res://systems/wheel.gd")
const MenuStyleScript := preload("res://ui/menu_style.gd")

var _menu: WheelMenu = null
var _chips := 500


func before_each() -> void:
	_chips = 500
	_menu = WheelMenuScene.instantiate()
	add_child_autofree(_menu)
	_menu.can_open = func() -> bool: return true
	_menu.chips_provider = func() -> int: return _chips
	_menu.open()
	await get_tree().process_frame


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


## MOVED (Task 4): the footer is now MenuStyle's shared builder, the same as every other
## table's, and no longer carries a hand written note about the stake. Where the stake
## lives is still on screen: the stake row itself is always drawn (WheelMenu.drawn_lines()),
## right after the last guess.
func test_the_footer_documents_where_the_stake_actually_lives() -> void:
	assert_eq(_menu._footer.text, MenuStyleScript.footer_tabs_and_rows("confirm", "leave"),
		"the footer now comes from the shared builder, not a hand written line")
	assert_true("\n".join(_menu.drawn_lines()).to_lower().contains("stake"),
		"the stake row itself must still say what it is, even off the footer")


const PaintScript := preload("res://ui/casino_paint.gd")
## The file already preloads the SCENE as WheelMenuScene; the SCRIPT is what carries the Tab
## enum and the new constants, and a preload by path is how this project reaches either.
const WheelMenuScript := preload("res://ui/wheel_menu.gd")


## THE DEAD FOOTER IS GONE. It was assigned in _ready() and overwritten by refresh() before
## any player could see it, and it hard coded both input schemes at once, which is precisely
## what MenuStyle.footer() exists to prevent.
func test_the_wheel_has_no_footer_of_its_own_and_shows_one_scheme() -> void:
	assert_false("WHEEL_FOOTER" in _menu, "the dead constant is deleted, not left lying")
	var footer := _menu.get_node(^"Centre/Panel/Margin/Column/Footer") as Label
	assert_false(footer.text.contains("Enter / A"),
		"one scheme, never both: the footer comes from MenuStyle now")
	assert_false(footer.text.contains("Esc / B"))


## TWENTY FIVE POCKETS ON THE WHEEL AND TWENTY FOUR PADS ON THE FELT. The house pocket is on
## the wheel and not on the felt, which is what makes it the house's.
func test_the_number_felt_has_a_pad_per_number_and_none_for_the_house() -> void:
	_menu.set_tab(WheelMenuScript.Tab.NUMBER)
	assert_eq(_menu.guess_count(), WheelScript.NUMBERS)
	var stage := Rect2(Vector2.ZERO, _menu.stage_size())
	for i: int in WheelScript.NUMBERS:
		assert_true(stage.encloses(_menu.pad_rect(i)),
			"number pad %d leaves the stage: %s" % [i, _menu.pad_rect(i)])


func test_the_colour_felt_has_a_pad_per_colour_and_none_overlaps() -> void:
	_menu.set_tab(WheelMenuScript.Tab.COLOUR)
	assert_eq(_menu.guess_count(), int(WheelScript.Colour.HOUSE))
	for a: int in _menu.guess_count():
		for b: int in _menu.guess_count():
			if a >= b:
				continue
			assert_false(_menu.pad_rect(a).intersects(_menu.pad_rect(b)),
				"colour pads %d and %d overlap" % [a, b])


## THE WHEEL AND THE FELT DO NOT SIT ON TOP OF EACH OTHER, and neither leaves the stage.
func test_the_wheel_and_the_rules_plate_stay_inside_the_stage() -> void:
	var stage := Rect2(Vector2.ZERO, _menu.stage_size())
	var centre: Vector2 = _menu.wheel_centre()
	var r: float = _menu.wheel_outer()
	assert_true(stage.encloses(Rect2(centre - Vector2(r, r), Vector2(r, r) * 2.0)),
		"the wheel leaves the stage")
	assert_true(stage.encloses(_menu.rules_rect()), "the rules plate leaves the stage")
	assert_gt(_menu.wheel_outer(), _menu.wheel_inner(), "the ring has a width")


## A SPIN STOPS WITH THE PUSHED POCKET UNDER THE POINTER, and the number of turns is a
## constant. A spin whose length varied would be a generator under game/ui/.
func test_a_pushed_spin_stops_with_that_pocket_under_the_pointer() -> void:
	_menu.show_spin(13, 0, 10)
	assert_true(_menu.animating())
	# Run the tween out rather than waiting on wall clock. A fixed frame count tied to an
	# assumed frame rate is exactly the flake this avoids: headless CI has been observed well
	# north of 100 fps here, so a bound on FRAMES rather than on seconds still settles the
	# spin quickly and a genuinely stuck tween still trips the 2000 frame cap instead of
	# hanging the suite.
	var frames := 0
	while _menu.animating() and frames < 2000:
		await get_tree().process_frame
		frames += 1
	assert_false(_menu.animating(), "the wheel has stopped")
	assert_eq(_menu.pocket_under_pointer(), 13,
		"the wheel stopped on the pocket ranch.gd already spun")


func test_an_impossible_pocket_starts_no_spin() -> void:
	var before: float = _menu.wheel_angle()
	_menu.show_spin(99, 0, 10)
	assert_false(_menu.animating())
	assert_eq(_menu.wheel_angle(), before)
	_menu.show_spin(-2, 0, 10)
	assert_false(_menu.animating())


## THE CURSOR MODEL IS UNCHANGED: the guesses, then one more position which is the stake.
func test_the_focus_walks_the_guesses_and_then_the_stake() -> void:
	_menu.set_tab(WheelMenuScript.Tab.COLOUR)
	assert_eq(String(_menu.focused_id()), "guess:0")
	_menu.move_selection(int(WheelScript.Colour.HOUSE))
	assert_eq(String(_menu.focused_id()), "stake:%d" % _menu.stake_index())
	assert_eq(_menu.row_count(), _menu.guess_count() + 1)
