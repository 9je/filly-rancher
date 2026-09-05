extends GutTest
## THE FOUR TABLES, AND THE POINTER. The owner's playtest called the casino the one bright
## spot and also said every menu was keyboard only; this file is the claim that both are now
## true of it. Acceptance item 13: "Casino UI keeps its crown and gains mouse play."
##
## IT DRIVES THE HOLDERS THE MENU ACTUALLY BUILT, not a rect computed here. A test that
## measured its own idea of where row 2 is would go green on a menu that drew row 2 somewhere
## else, which is the defect game/test/test_table_caret.gd already exists for.

const MouseRowsScript := preload("res://ui/mouse_rows.gd")
const SlotsScript := preload("res://ui/slots_menu.gd")

var _menu: SlotsMenu


func before_each() -> void:
	_menu = preload("res://ui/slots_menu.tscn").instantiate()
	add_child_autofree(_menu)
	_menu.chips_provider = func() -> int: return 5000
	_menu.can_open = func() -> bool: return true
	_menu.open()


func _row_holders() -> Array[PanelContainer]:
	var out: Array[PanelContainer] = []
	for child in _menu.get_node("Centre/Panel/Margin/Column/Rows").get_children():
		var panel := child as PanelContainer
		if panel != null and MouseRowsScript.row_index(panel) >= 0:
			out.append(panel)
	return out


func test_every_selectable_row_is_armed_and_no_unselectable_line_is() -> void:
	var armed: Array[PanelContainer] = _row_holders()
	assert_eq(armed.size(), _menu.row_count(),
		"exactly the rows the keyboard can reach are the rows the mouse can reach")
	var seen: Array[int] = []
	for holder: PanelContainer in armed:
		seen.append(MouseRowsScript.row_index(holder))
	seen.sort()
	assert_eq(seen, range(_menu.row_count()) as Array[int])


func test_pointing_at_a_row_moves_the_keyboard_cursor_to_it() -> void:
	_menu.point_at_row(1)
	assert_eq(_menu.selected_index(), 1, "one cursor, two ways to move it")
	assert_eq(_menu.hovered_index(), 1)


func test_the_arrow_keys_still_move_the_cursor_after_the_mouse_has_touched_it() -> void:
	_menu.point_at_row(1)
	_menu.move_selection(1)
	assert_eq(_menu.selected_index(), 2 % _menu.row_count(),
		"the mouse must never take the keyboard away")


## THE STAGE ALREADY SHOWS THE SELECTION. These holders exist to be clicked, not to be
## looked at: slots_menu.gd prints nothing for its stake rows (the stage draws the chips), so
## the column's copy of them must stay visually silent -- no caret text, no box at rest, none
## even while picked, and at most the plain hover box while the pointer is actually on one.
##
## await A FRAME BEFORE THE SECOND LOOK. refresh() frees the old holders with queue_free(),
## which does not actually remove them until the frame ends, so a second refresh() run
## synchronously right after the first (exactly what point_at_row() does here) leaves both
## generations of PanelContainer sitting under Rows at once; asking the pending-deletion set
## about its stylebox is asking last frame's answer, not this one's.
func test_padded_rows_paint_nothing_until_hovered() -> void:
	var holders: Array[PanelContainer] = _row_holders()
	assert_gt(holders.size(), 0)
	for holder: PanelContainer in holders:
		var label := holder.get_child(0) as Label
		assert_not_null(label)
		assert_eq(label.text, "", "the row already has words on the stage")
		assert_true(holder.get_theme_stylebox(&"panel") is StyleBoxEmpty,
			"nothing paints here until the pointer actually rests on the row")
	_menu.point_at_row(1)
	await get_tree().process_frame
	var seen := 0
	for holder: PanelContainer in _row_holders():
		var box: StyleBox = holder.get_theme_stylebox(&"panel")
		if MouseRowsScript.row_index(holder) == _menu.hovered_index():
			assert_false(box is StyleBoxEmpty, "the hovered row gets the plain hover box")
		else:
			assert_true(box is StyleBoxEmpty, "a row nothing is over stays blank")
		seen += 1
	assert_eq(seen, _menu.row_count(), "the freed generation is gone, not just outnumbered")


func test_clicking_a_row_takes_it() -> void:
	watch_signals(_menu)
	_menu.take_row(_menu.row_count() - 1)
	assert_eq(_menu.selected_index(), _menu.row_count() - 1)
	assert_gt(_menu.result_lines().size() + get_signal_emit_count(_menu, "spin_requested"),
		0, "a click on a row has to actually do the thing the row says")


func test_a_left_click_on_a_row_holder_reaches_take_row() -> void:
	var holders: Array[PanelContainer] = _row_holders()
	assert_gt(holders.size(), 1, "the slot machine has rows")
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	holders[1].gui_input.emit(event)
	assert_eq(_menu.selected_index(), MouseRowsScript.row_index(holders[1]))


func test_the_close_button_exists_says_close_and_closes() -> void:
	var button: Button = _menu.close_button_node()
	assert_not_null(button, "every screen gets a pointer usable way out")
	assert_eq(button.text, MouseRowsScript.CLOSE_TEXT)
	assert_eq(button.focus_mode, Control.FOCUS_NONE)
	button.pressed.emit()
	assert_false(_menu.is_open())


func test_the_dim_behind_the_panel_swallows_clicks_meant_for_nothing() -> void:
	var dim := _menu.get_node("Dim") as Control
	assert_eq(dim.mouse_filter, Control.MOUSE_FILTER_STOP,
		"a click beside the panel must not reach the world behind it")


func test_the_stage_answers_the_pointer_and_the_base_offers_no_hits() -> void:
	var stage := _menu.get_node("Centre/Panel/Margin/Column/Stage") as Control
	assert_eq(stage.mouse_filter, Control.MOUSE_FILTER_STOP,
		"a felt nothing can click is a felt with no mouse play on it")
	assert_gt(_menu.stage_hit_rects().size(), 0,
		"the slot machine paints something worth clicking")
	for rect: Rect2 in _menu.stage_hit_rects():
		assert_gt(rect.size.x * rect.size.y, 0.0, "an empty hit rect can never be hit")


func test_the_footer_still_prints_the_keys() -> void:
	var footer := _menu.get_node("Centre/Panel/Margin/Column/Footer") as Label
	assert_false(footer.text.strip_edges().is_empty(),
		"the key hints stay; the mouse was added, not traded")
