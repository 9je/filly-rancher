extends GutTest
## THE SLOT MACHINE. Real strips in clipped windows, chips that are buttons, a lever and a
## Spin that ask for one spin, and a result told by the reels. Every test here is a line of
## the owner's playtest (2026-11-05) that must not come back.

const SlotsMenuScene := preload("res://ui/slots_menu.tscn")
const SlotsScript := preload("res://systems/slots.gd")
const MenuStyleScript := preload("res://ui/menu_style.gd")

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


func _press(at: Vector2, down: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = at
	return event


func _drag(at: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = at
	return event


## "it wont let me change bet size in slots now": the drawn chip is the button.
func test_clicking_the_drawn_50_and_200_chips_changes_the_stake() -> void:
	_chips = 205
	_menu.on_stage_hit(_menu.button_index(&"stake:1"))
	assert_eq(_menu.selected_stake(), 50)
	_menu.on_stage_hit(_menu.button_index(&"stake:2"))
	assert_eq(_menu.selected_stake(), 200, "205 chips cover a 200 stake")
	_menu.on_stage_hit(_menu.button_index(&"stake:0"))
	assert_eq(_menu.selected_stake(), 10)


func test_a_chip_she_cannot_cover_is_greyed_and_refused() -> void:
	_chips = 120
	assert_false(_menu.button_enabled(&"stake:2"))
	_menu.on_stage_hit(_menu.button_index(&"stake:2"))
	assert_ne(_menu.selected_stake(), 200)


func test_an_empty_purse_cannot_spin() -> void:
	_chips = 0
	watch_signals(_menu)
	assert_false(_menu.pull())
	assert_false(_menu.button_enabled(&"spin"))
	assert_signal_emit_count(_menu, "spin_requested", 0)


func test_spin_emits_the_stake_that_is_showing_and_spins_nothing_itself() -> void:
	_menu.on_stage_hit(_menu.button_index(&"stake:1"))
	watch_signals(_menu)
	_menu.on_stage_hit(_menu.button_index(&"spin"))
	assert_signal_emit_count(_menu, "spin_requested", 1)
	assert_eq(get_signal_parameters(_menu, "spin_requested", 0)[0], 50)
	assert_false(_menu.animating(), "the reels wait for ranch.gd's roll")


func test_the_keyboard_opens_on_spin_and_confirm_spins() -> void:
	assert_eq(String(_menu.focused_id()), "spin")
	watch_signals(_menu)
	assert_true(_menu.confirm())
	assert_signal_emit_count(_menu, "spin_requested", 1)


## THE LEVER: press, drag down past half way, let go, and it spins; let go early and it
## springs back without spinning.
func test_dragging_the_lever_down_pulls_it_and_a_short_drag_does_not() -> void:
	watch_signals(_menu)
	var knob: Vector2 = _menu.lever_rect().get_center()
	_menu._on_stage_input(_press(knob, true))
	_menu._on_stage_input(_drag(knob + Vector2(0.0, 30.0)))
	_menu._on_stage_input(_press(knob + Vector2(0.0, 30.0), false))
	assert_signal_emit_count(_menu, "spin_requested", 0, "a short tug is not a pull")
	_menu._on_stage_input(_press(knob, true))
	_menu._on_stage_input(_drag(knob + Vector2(0.0, 140.0)))
	_menu._on_stage_input(_press(knob + Vector2(0.0, 140.0), false))
	assert_signal_emit_count(_menu, "spin_requested", 1, "a full pull spins")


func test_a_click_on_the_lever_spins_at_the_stake_that_is_showing() -> void:
	_menu.on_stage_hit(_menu.button_index(&"stake:0"))
	watch_signals(_menu)
	var knob: Vector2 = _menu.lever_rect().get_center()
	_menu._on_stage_input(_press(knob, true))
	_menu._on_stage_input(_press(knob, false))
	assert_eq(get_signal_parameters(_menu, "spin_requested", 0)[0], 10)


## A SPIN LANDS ON THE VALUE ranch.gd ALREADY ROLLED, read off the drawing's own positions.
func test_a_pushed_spin_lands_every_payline_on_the_symbol_it_was_handed() -> void:
	for line: Array in [[2, 5, 0], [0, 0, 0], [5, 5, 1]]:
		var reels: Array[int] = []
		reels.assign(line)
		_menu.show_spin(reels, 0, 10)
		assert_true(_menu.animating())
		_menu.finish_animation()
		assert_false(_menu.animating())
		assert_eq(_menu.payline_symbols(), reels)


## "the first 2 reels had all 3 the same": after any landing, every window shows three
## different symbols.
func test_every_window_shows_three_different_symbols_after_every_landing() -> void:
	for spin: int in 40:
		var reels: Array[int] = [spin % 6, (spin * 5) % 6, (spin * 7 + 1) % 6]
		_menu.show_spin(reels, 0, 10)
		_menu.finish_animation()
		for reel: int in SlotsScript.REELS:
			var shown: Array[int] = _menu.window_symbols(reel)
			assert_true(shown[0] != shown[1] and shown[1] != shown[2] and shown[0] != shown[2],
				"spin %d reel %d shows %s" % [spin, reel, shown])


func test_a_bad_push_is_a_still_frame() -> void:
	var before: float = _menu.reel_position(0)
	_menu.show_spin([] as Array[int], 0, 10)
	_menu.show_spin([99, -3, 7] as Array[int], 0, 10)
	assert_false(_menu.animating())
	assert_eq(_menu.reel_position(0), before)


## "text spoils the roll": no log, and the counter holds until the reels stop.
func test_nothing_is_printed_and_the_counter_holds_until_the_reels_stop() -> void:
	assert_false((_menu.get_node("Centre/Panel/Margin/Column/Rows") as Control).visible)
	_menu.show_result(["Gem Apple Bell", "Nothing this time."] as Array[String])
	assert_eq(_menu.printed_lines().size(), 0, "a pushed result line is not printed")
	_chips = 640
	_menu.show_spin([1, 1, 1] as Array[int], 100, 10)
	assert_eq(_menu.shown_chips(), 540)
	_menu.finish_animation()
	assert_eq(_menu.shown_chips(), 640)


## "symbols poked out of the reel windows": each window is a clipping Control exactly the
## size of the window.
func test_every_reel_window_clips_its_symbols() -> void:
	for reel: int in SlotsScript.REELS:
		var window := _menu.get_node("Centre/Panel/Margin/Column/Stage/Reel%d" % reel) as Control
		assert_not_null(window)
		assert_true(window.clip_contents, "reel %d clips" % reel)
		assert_eq(Rect2(window.position, window.size), _menu.reel_rect(reel))


## "the rainbow overlapped the SPECTRA SLOTS sign", "a paytable line was cut off".
func test_the_sign_the_windows_the_controls_and_the_paytable_never_overlap() -> void:
	var stage := Rect2(Vector2.ZERO, _menu.stage_size())
	var parts: Array[Rect2] = [_menu.marquee_rect(), _menu.paytable_rect()]
	for reel: int in SlotsScript.REELS:
		parts.append(_menu.reel_rect(reel))
	for b: Dictionary in _menu.stage_buttons():
		parts.append(b["rect"])
	for i: int in parts.size():
		assert_true(stage.encloses(parts[i]), "part %d is on the stage" % i)
		for j: int in range(i + 1, parts.size()):
			assert_false(parts[i].intersects(parts[j]), "parts %d and %d overlap" % [i, j])


func test_the_windows_sit_left_to_right_and_the_payline_crosses_their_middles() -> void:
	for reel: int in range(1, SlotsScript.REELS):
		assert_gt(_menu.reel_rect(reel).position.x, _menu.reel_rect(reel - 1).end.x)
	for reel: int in SlotsScript.REELS:
		assert_almost_eq(_menu.payline_y(), _menu.reel_rect(reel).get_center().y, 0.5)


func test_nothing_it_draws_carries_a_dash() -> void:
	for line: String in _menu.drawn_lines():
		assert_false(line.contains("--") or line.contains("—"), line)


## BIGGER CHIPS (PS5, playtest 2026-11-05 item 46: "... a real lever; bigger chips; a spin
## button" [40]). The batch check found the chips about 50 px across beside 140 px reels. Each
## chip is now at least 45% of a reel's width, and the chips, the counter and the Spin button
## keep clear of each other.
func test_the_chips_are_big_beside_the_reels_and_nothing_in_the_row_overlaps() -> void:
	var SlotsMenuScript := preload("res://ui/slots_menu.gd")
	assert_gte(SlotsMenuScript.CHIP_RADIUS * 2.0, SlotsMenuScript.REEL_SIZE_PX.x * 0.45,
		"a chip %.0f across beside a %.0f reel" % [SlotsMenuScript.CHIP_RADIUS * 2.0, SlotsMenuScript.REEL_SIZE_PX.x])
	var boxes: Array[Rect2] = []
	for i in 3:
		boxes.append(_menu.stake_chip_rect(i))
	boxes.append(SlotsMenuScript.COUNTER)
	boxes.append(SlotsMenuScript.SPIN)
	for a in boxes.size():
		for b in range(a + 1, boxes.size()):
			assert_false(boxes[a].intersects(boxes[b]), "%s and %s overlap" % [boxes[a], boxes[b]])
	for r: Rect2 in boxes:
		assert_lte(r.end.y, SlotsMenuScript.STAGE_HEIGHT, "%s stays on the stage" % r)


## Fable AAA round 1: "slot reels show no blur". A reel at speed is a blur, a landed one is
## sharp, and the snap past the line and the bounce back still end exactly on the symbol.
func test_a_running_reel_blurs_and_a_landed_one_snaps_sharp_onto_its_symbol() -> void:
	_menu.show_spin([2, 4, 1] as Array[int], 0, 10)
	var tween: Tween = _menu.get("_tween")
	tween.custom_step(0.6)
	_menu.call("_measure_reels", 0.0)
	tween.custom_step(1.0 / 60.0)
	_menu.call("_measure_reels", 1.0 / 60.0)
	assert_gt(_menu.reel_blur(0), 0.5, "the first reel is a streak before it lands")
	_menu.finish_animation()
	for i in 4:
		_menu.call("_measure_reels", 1.0 / 60.0)
	for reel: int in SlotsScript.REELS:
		assert_eq(_menu.reel_blur(reel), 0.0, "reel %d is sharp once it stops" % reel)
	assert_eq(_menu.payline_symbols(), [2, 4, 1] as Array[int])
