extends GutTest
## THE THREE TABLES, AND THE POINTER. Since the rebuild of 2026-11-05 every control on the
## slot machine, the wheel and the blackjack table is a drawn thing on the felt, listed once in
## stage_buttons(); this file is the claim that the pointer reaches exactly those, that hover
## and the arrow keys move one cursor, and that nothing is left of the old row column, its
## invisible hit targets or its key hints.

const MouseRowsScript := preload("res://ui/mouse_rows.gd")

const SCENES: Array[String] = ["res://ui/slots_menu.tscn", "res://ui/wheel_menu.tscn",
	"res://ui/blackjack_menu.tscn"]


func _open(path: String) -> CanvasLayer:
	var menu: CanvasLayer = (load(path) as PackedScene).instantiate()
	add_child_autofree(menu)
	menu.set("chips_provider", func() -> int: return 5000)
	menu.set("can_open", func() -> bool: return true)
	menu.call("open")
	return menu


func _motion(at: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = at
	return event


func test_the_pointer_hits_exactly_the_drawn_controls() -> void:
	for path: String in SCENES:
		var menu: CanvasLayer = _open(path)
		var buttons: Array = menu.call("stage_buttons")
		var rects: Array[Rect2] = menu.call("stage_hit_rects")
		assert_gt(buttons.size(), 0, path)
		assert_eq(rects.size(), buttons.size(), path)
		for i: int in buttons.size():
			assert_eq(rects[i], buttons[i]["rect"], "%s control %d" % [path, i])
			assert_gt(rects[i].size.x * rects[i].size.y, 0.0, "%s control %d" % [path, i])


func test_hovering_a_control_moves_the_one_cursor_to_it() -> void:
	for path: String in SCENES:
		var menu: CanvasLayer = _open(path)
		var buttons: Array = menu.call("stage_buttons")
		var last: int = buttons.size() - 1
		menu.call("_on_stage_input", _motion((buttons[last]["rect"] as Rect2).get_center()))
		assert_eq(int(menu.call("selected_index")), last, path)
		assert_eq(int(menu.call("hovered_index")), last, path)
		menu.call("_on_stage_input", _motion(Vector2(-50.0, -50.0)))
		assert_eq(int(menu.call("hovered_index")), -1, "%s: off the controls is off" % path)


func test_the_arrow_keys_still_move_the_cursor_after_the_mouse_has() -> void:
	for path: String in SCENES:
		var menu: CanvasLayer = _open(path)
		menu.call("point_at_row", 0)
		var before: StringName = menu.call("focused_id")
		menu.call("move_selection", 1)
		assert_ne(menu.call("focused_id"), before, "%s: the mouse never takes the keys" % path)


func test_there_is_no_row_column_and_no_key_hint_row() -> void:
	for path: String in SCENES:
		var menu: CanvasLayer = _open(path)
		var rows := menu.get_node("Centre/Panel/Margin/Column/Rows") as Control
		assert_false(rows.visible, "%s: no text column under the felt" % path)
		assert_eq(rows.get_child_count(), 0, "%s: no invisible hit rows either" % path)
		var footer := menu.get_node("Centre/Panel/Margin/Column/Footer") as Label
		assert_false(footer.is_visible_in_tree(), "%s: no key hints" % path)


func test_the_close_button_says_back_and_closes() -> void:
	for path: String in SCENES:
		var menu: CanvasLayer = _open(path)
		var button: Button = menu.call("close_button_node")
		assert_eq(button.text, MouseRowsScript.CLOSE_TEXT)
		assert_eq(button.focus_mode, Control.FOCUS_NONE)
		button.pressed.emit()
		assert_false(bool(menu.call("is_open")), path)


func test_the_dim_swallows_clicks_and_the_felt_answers_the_pointer() -> void:
	for path: String in SCENES:
		var menu: CanvasLayer = _open(path)
		assert_eq((menu.get_node("Dim") as Control).mouse_filter, Control.MOUSE_FILTER_STOP)
		assert_eq((menu.get_node("Centre/Panel/Margin/Column/Stage") as Control).mouse_filter,
			Control.MOUSE_FILTER_STOP, path)


## THE WHOLE PANEL FITS THE 1920 x 1080 CANVAS AT EVERY TEXT SIZE: the title, the tabs, the
## felt and the Back button, with nothing pushed off the bottom at 150.
func test_every_table_fits_the_canvas_at_every_text_size() -> void:
	const MenuStyleScript := preload("res://ui/menu_style.gd")
	for scale: float in [1.0, 1.25, 1.5]:
		MenuStyleScript.text_scale = scale
		for path: String in SCENES:
			var menu: CanvasLayer = _open(path)
			menu.call("refresh")
			await get_tree().process_frame
			await get_tree().process_frame
			var panel := menu.get_node("Centre/Panel") as Control
			assert_lte(panel.get_combined_minimum_size().y, 1080.0,
				"%s at %.2f is %.0f tall" % [path, scale, panel.get_combined_minimum_size().y])
			assert_lte(panel.get_combined_minimum_size().x, 1920.0, path)
	MenuStyleScript.text_scale = 1.0
