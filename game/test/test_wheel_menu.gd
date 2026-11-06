extends GutTest
## THE BIG WHEEL'S FELT. Stacks of chips on tiers, one Spin that sends them all, a wheel that
## lands where it was told, and nothing printed under it. The owner's playtest (2026-11-05)
## is the brief: no Colour/Number tabs, no rules box running off its edge, no key hint rows.

const WheelScript := preload("res://systems/wheel.gd")
const MouseRowsScript := preload("res://ui/mouse_rows.gd")
const MenuStyleScript := preload("res://ui/menu_style.gd")

var _menu: CanvasLayer
var _chips := 500


func before_each() -> void:
	_chips = 500
	_menu = preload("res://ui/wheel_menu.tscn").instantiate()
	add_child_autofree(_menu)
	_menu.set("can_open", func() -> bool: return true)
	_menu.set("chips_provider", func() -> int: return _chips)
	assert_true(_menu.open())


func after_each() -> void:
	MenuStyleScript.text_scale = 1.0


func test_there_are_no_tabs_and_no_column_under_the_felt() -> void:
	assert_eq(_menu.tab_names().size(), 0, "the Colour and Number tabs are gone")
	assert_false((_menu.get_node("Centre/Panel/Margin/Column/Rows") as Control).visible,
		"no text log under the wheel")
	assert_false((_menu.get_node("Centre/Panel/Margin/Column/Footer") as Control).visible,
		"no key hint row")
	assert_eq(_menu.printed_lines().size(), 0)


func test_clicking_a_tier_stacks_the_chosen_chip_on_it() -> void:
	_menu.set_chip(1)
	assert_true(_menu.add_bet(WheelScript.Tier.FIVE))
	assert_true(_menu.add_bet(WheelScript.Tier.FIVE))
	assert_true(_menu.add_bet(WheelScript.Tier.ONE))
	assert_eq(_menu.bets(), [50, 0, 100, 0, 0] as Array[int])
	assert_eq(_menu.total_bet(), 150)


func test_a_stack_can_never_add_up_to_more_than_the_purse() -> void:
	_menu.set_chip(2)
	assert_true(_menu.add_bet(0))
	assert_true(_menu.add_bet(1))
	assert_false(_menu.add_bet(2), "600 on the felt with 500 in the purse is refused")
	assert_eq(_menu.total_bet(), 400)


func test_a_chip_bigger_than_the_purse_cannot_be_picked() -> void:
	_chips = 120
	assert_false(_menu.set_chip(2), "a 200 chip with 120 in the purse")
	assert_true(_menu.set_chip(1))
	assert_false(_menu.button_enabled(&"chip:2"))
	assert_true(_menu.button_enabled(&"chip:1"))


func test_a_right_click_takes_a_chip_back_and_clear_takes_them_all() -> void:
	_menu.add_bet(3)
	_menu.add_bet(3)
	_menu.on_stage_alt(_menu.button_index(&"tier:3"))
	assert_eq(_menu.bets()[3], 10)
	_menu.add_bet(0)
	assert_true(_menu.clear_bets())
	assert_eq(_menu.total_bet(), 0)


func test_spin_sends_every_stack_in_one_signal_and_rolls_nothing_itself() -> void:
	watch_signals(_menu)
	assert_false(_menu.can_spin(), "nothing on the felt, nothing to spin")
	assert_false(_menu.spin())
	_menu.add_bet(1)
	_menu.add_bet(4)
	assert_true(_menu.spin())
	assert_signal_emit_count(_menu, "bet_requested", 1)
	assert_eq(get_signal_parameters(_menu, "bet_requested", 0)[0],
		[0, 10, 0, 0, 10] as Array[int])
	assert_false(_menu.animating(), "the menu waits to be told the segment")


func test_every_control_is_a_real_drawn_target_the_pointer_can_take() -> void:
	_menu.add_bet(0)
	var buttons: Array[Dictionary] = _menu.stage_buttons()
	assert_eq(buttons.size(), WheelScript.TIERS + 3 + 2)
	var size: Vector2 = _menu.stage_size()
	for b: Dictionary in buttons:
		var rect: Rect2 = b["rect"]
		assert_gt(rect.size.x * rect.size.y, 0.0, String(b["id"]))
		assert_true(Rect2(Vector2.ZERO, size).encloses(rect), "%s is on the stage" % b["id"])
	# THE 50 AND 200 CHIPS (playtest: "it wont let me change bet size"): a click on the drawn
	# chip is a click on the chip.
	_menu.on_stage_hit(_menu.button_index(&"chip:2"))
	assert_eq(_menu.chip_index(), 2)
	_menu.on_stage_hit(_menu.button_index(&"chip:1"))
	assert_eq(_menu.chip_index(), 1)


func test_no_two_controls_overlap() -> void:
	var buttons: Array[Dictionary] = _menu.stage_buttons()
	for i: int in buttons.size():
		for j: int in range(i + 1, buttons.size()):
			assert_false((buttons[i]["rect"] as Rect2).intersects(buttons[j]["rect"] as Rect2),
				"%s and %s overlap" % [buttons[i]["id"], buttons[j]["id"]])
	var wheel := Rect2(_menu.wheel_centre() - Vector2.ONE * (_menu.wheel_outer() + 20.0),
		Vector2.ONE * (_menu.wheel_outer() + 20.0) * 2.0)
	for b: Dictionary in buttons:
		assert_false(wheel.intersects(b["rect"]), "%s is clear of the wheel" % b["id"])


func test_the_keyboard_walks_the_felt_and_skips_what_is_greyed() -> void:
	assert_eq(String(_menu.focused_id()), "tier:0")
	_menu.move_selection(-1)
	assert_eq(String(_menu.focused_id()), "chip:2",
		"Spin and Clear are greyed with nothing on the felt, so the cursor skips them")
	_menu.focus_on(&"tier:2")
	assert_true(_menu.confirm())
	assert_eq(_menu.bets()[2], 10, "confirm on a tier stacks a chip on it")
	_menu.move_selection(-1)
	_menu.move_selection(-1)
	_menu.move_selection(-1)
	assert_eq(String(_menu.focused_id()), "spin", "with a stack down, Spin is reachable")


func test_a_pushed_spin_stops_with_that_segment_under_the_pointer() -> void:
	for segment: int in [0, 7, 22, 44]:
		_menu.show_spin(segment, 0, 10)
		assert_true(_menu.animating())
		_menu.finish_animation()
		assert_false(_menu.animating())
		assert_eq(_menu.segment_under_pointer(), segment)
		assert_eq(_menu.landed_segment(), segment)
	assert_eq(_menu.history()[0], WheelScript.tier_of(44), "the last spin heads the strip")


func test_nothing_is_actionable_while_it_spins() -> void:
	_menu.add_bet(0)
	_menu.show_spin(3, 0, 10)
	assert_false(_menu.add_bet(1))
	assert_false(_menu.spin())
	assert_false(_menu.clear_bets())
	for b: Dictionary in _menu.stage_buttons():
		assert_false(bool(b["enabled"]), "%s is greyed mid spin" % b["id"])


## THE COUNTER DOES NOT GIVE THE RESULT AWAY: ranch.gd has already paid by the time the wheel
## starts turning, so the menu holds the pre win figure until it stops.
func test_the_chip_counter_holds_until_the_wheel_stops() -> void:
	_chips = 640
	_menu.show_spin(0, 210, 10)
	assert_eq(_menu.shown_chips(), 430)
	_menu.finish_animation()
	assert_eq(_menu.shown_chips(), 640)


func test_stacks_stay_for_another_spin_unless_the_purse_cannot_cover_them() -> void:
	_menu.set_chip(2)
	_menu.add_bet(0)
	_menu.add_bet(1)
	_menu.show_spin(1, 0, 400)
	_menu.finish_animation()
	assert_eq(_menu.total_bet(), 400, "the same bet is one press away")
	_chips = 100
	_menu.show_spin(1, 0, 400)
	_menu.finish_animation()
	assert_eq(_menu.total_bet(), 0, "a bet she can no longer cover is cleared")


func test_an_impossible_segment_starts_no_spin() -> void:
	_menu.show_spin(-1, 0, 10)
	_menu.show_spin(WheelScript.SEGMENTS, 0, 10)
	assert_false(_menu.animating())


func test_nothing_it_draws_carries_a_dash() -> void:
	for line: String in _menu.drawn_lines():
		assert_false(line.contains("--") or line.contains("—"), line)


func test_the_close_button_says_back_and_closes() -> void:
	var button: Button = _menu.close_button_node()
	assert_eq(button.text, MouseRowsScript.CLOSE_TEXT)
	button.pressed.emit()
	assert_false(_menu.is_open())


## A SPIN PUSHED INTO A CLOSED FELT (a gate or a save hook calling ranch.play_wheel() directly)
## lands at once, so the felt is not still "spinning" when she next walks up to it.
func test_a_spin_pushed_into_a_closed_felt_lands_at_once() -> void:
	_menu.close()
	_menu.show_spin(9, 0, 10)
	assert_false(_menu.animating())
	assert_eq(_menu.segment_under_pointer(), 9)
	assert_true(_menu.open())
	assert_true(_menu.add_bet(0), "and the next bet is taken")
