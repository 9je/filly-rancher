extends GutTest
## THE SLOT MACHINE'S PANEL. It shows the paytable, offers a stake it knows she can cover,
## emits, and shows what came back. It never spins anything itself.

const SlotsMenuScene := preload("res://ui/slots_menu.tscn")
const SlotsScript := preload("res://systems/slots.gd")
const PaintScript := preload("res://ui/casino_paint.gd")

var _menu: SlotsMenu = null
var _chips := 500


func before_each() -> void:
	_chips = 500
	_menu = SlotsMenuScene.instantiate()
	add_child_autofree(_menu)
	_menu.can_open = func() -> bool: return true
	_menu.chips_provider = func() -> int: return _chips
	_menu.open()
	await get_tree().process_frame


func test_it_offers_only_stakes_she_can_cover() -> void:
	_chips = 60
	_menu.refresh()
	assert_eq(_menu.stakes(), [10, 50])


func test_an_empty_purse_offers_no_stake_and_confirming_does_nothing() -> void:
	_chips = 0
	_menu.refresh()
	watch_signals(_menu)
	assert_true(_menu.stakes().is_empty())
	assert_false(_menu.confirm())
	assert_signal_not_emitted(_menu, "spin_requested")


func test_confirming_emits_the_highlighted_stake_and_spins_nothing_itself() -> void:
	watch_signals(_menu)
	_menu.move_selection(1)
	assert_true(_menu.confirm())
	assert_signal_emitted_with_parameters(_menu, "spin_requested", [_menu.stakes()[1]])
	assert_eq(_chips, 500, "the menu draws and emits")


func test_it_draws_the_whole_paytable() -> void:
	var drawn: String = "\n".join(_menu.drawn_lines())
	for line in SlotsScript.paytable_lines():
		assert_true(drawn.contains(line), "the paytable line '%s' is not on the panel" % line)


func test_a_result_is_shown_until_the_next_one() -> void:
	_menu.show_result(["Apple Apple Apple", "You win 40 chips."])
	assert_true("\n".join(_menu.drawn_lines()).contains("You win 40 chips."))
	_menu.show_result(["Bell Gem Star", "Nothing this time."])
	assert_false("\n".join(_menu.drawn_lines()).contains("You win 40 chips."))


func test_nothing_it_draws_carries_a_dash() -> void:
	_menu.show_result(["Apple Apple Apple", "You win 40 chips."])
	for line in _menu.drawn_lines():
		assert_false(line.contains("--") or line.contains("—"), line)


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


## THE CABINET AND THE PAYTABLE DIVIDE THE STAGE AND NEITHER LEAVES IT. Laid out by eye, a
## panel that is 20 px too wide looks fine on the machine it was authored on and clips on the
## next one, because every 2D size in this project is in 1920x1080 base pixels and the window
## is 1600x900.
func test_every_drawn_region_sits_inside_the_stage() -> void:
	var stage := Rect2(Vector2.ZERO, _menu.stage_size())
	for pair: Array in [[_menu.cabinet_rect(), "cabinet"],
			[_menu.paytable_rect(), "paytable"]]:
		assert_true(stage.encloses(pair[0] as Rect2),
			"the %s leaves the stage: %s" % [pair[1], pair[0]])
	for i: int in 3:
		assert_true(_menu.cabinet_rect().encloses(_menu.reel_rect(i)),
			"reel window %d leaves the cabinet" % i)


## THREE WINDOWS, NO OVERLAP, IN ORDER. Reels drawn on top of each other are the failure a
## rect test catches and a screenshot does not, because two reels landing on the same symbol
## look correct.
func test_the_three_reel_windows_are_separate_and_left_to_right() -> void:
	for i: int in 2:
		var here: Rect2 = _menu.reel_rect(i)
		var next: Rect2 = _menu.reel_rect(i + 1)
		assert_lt(here.position.x + here.size.x, next.position.x,
			"reel %d overlaps reel %d" % [i, i + 1])


## THE PAYLINE IS THE MIDDLE ROW OF EVERY WINDOW, and the player has to be able to see which
## row counts BEFORE she spins.
func test_the_payline_crosses_the_middle_of_every_reel_window() -> void:
	for i: int in 3:
		var window: Rect2 = _menu.reel_rect(i)
		assert_almost_eq(_menu.payline_y(), window.position.y + window.size.y * 0.5, 1.0)


## THE PAYTABLE MOVED TO THE STAGE AND THE MODEL STILL CARRIES IT. This is the whole reason
## printed_lines() exists beside drawn_lines(): test_published_payouts.gd parses the price out
## of these eight strings and a menu that stopped returning them would take that guard with
## it silently.
func test_the_paytable_leaves_the_column_and_stays_in_the_model() -> void:
	var model: Array[String] = _menu.drawn_lines()
	var printed: Array[String] = _menu.printed_lines()
	for line: String in SlotsScript.paytable_lines():
		assert_true(model.has(line), "the model still carries '%s'" % line)
		assert_false(printed.has(line), "the column stopped printing '%s'" % line)


## A SPIN LANDS ON THE VALUE ranch.gd ALREADY ROLLED, and nothing here rolls anything. The
## stage is TOLD the reels; the tween's target is that value and no other.
func test_a_pushed_spin_lands_every_reel_on_the_symbol_it_was_handed() -> void:
	var reels: Array[int] = [2, 5, 0]
	_menu.show_spin(reels, 0, 10)
	assert_true(_menu.animating(), "the reels are running")
	# Run the tween out rather than waiting on wall clock. A fixed frame count tied to an
	# assumed frame rate is exactly the flake this avoids: headless CI has been observed
	# well north of 100 fps here, so a bound on FRAMES rather than on seconds still settles
	# the spin quickly and a genuinely stuck tween still trips the 2000 frame cap instead
	# of hanging the suite.
	var frames := 0
	while _menu.animating() and frames < 2000:
		await get_tree().process_frame
		frames += 1
	assert_false(_menu.animating(), "the reels have settled")
	var strip: Array[int] = SlotsScript.strip()
	for reel: int in 3:
		var landed: int = strip[posmod(roundi(_menu.reel_offset(reel)),
			SlotsScript.REEL_SIZE)]
		assert_eq(landed, reels[reel],
			"reel %d settled on %s and was handed %s" % [reel,
				SlotsScript.SYMBOL_NAMES[landed], SlotsScript.SYMBOL_NAMES[reels[reel]]])


## AN EMPTY OR OUT OF RANGE PUSH IS A STILL FRAME, not an error. These arrive over a dynamic
## call() and a gate calling ranch.play_slots() directly can produce one.
func test_a_bad_push_leaves_the_reels_where_they_were() -> void:
	var before: float = _menu.reel_offset(0)
	_menu.show_spin([] as Array[int], 0, 10)
	assert_false(_menu.animating(), "an empty reel array starts no spin")
	assert_eq(_menu.reel_offset(0), before)
	_menu.show_spin([99, -3, 7] as Array[int], 0, 10)
	assert_false(_menu.animating(), "a symbol that is not on the strip starts no spin")


## THE STAKE IS STILL THE ONLY THING THE CURSOR MOVES.
func test_the_focus_id_names_the_stake_the_cursor_is_on() -> void:
	assert_eq(String(_menu.focused_id()), "stake:0")
	_menu.move_selection(1)
	assert_eq(String(_menu.focused_id()), "stake:1")
