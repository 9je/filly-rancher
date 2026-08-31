extends GutTest
## THE SLOT MACHINE'S PANEL. It shows the paytable, offers a stake it knows she can cover,
## emits, and shows what came back. It never spins anything itself.

const SlotsMenuScene := preload("res://ui/slots_menu.tscn")
const SlotsScript := preload("res://systems/slots.gd")

var _menu: SlotsMenu = null
var _chips := 500


func before_each() -> void:
	_chips = 500
	_menu = SlotsMenuScene.instantiate()
	add_child_autofree(_menu)
	_menu.can_open = func() -> bool: return true
	_menu.chips_provider = func() -> int: return _chips
	_menu.open()


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
