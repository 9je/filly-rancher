extends GutTest
## THE MOUSE KIT, WHICH IS THE WHOLE OF HOW THIRTEEN HAND DRAWN SCREENS LEARNED THE POINTER.
##
## Every menu in this game builds its rows the same way: a PanelContainer carrying the shared
## StyleBoxFlat, with a Label inside it. So the pointer is taught once, here, and every menu
## swaps one call in its refresh(). The alternative was thirteen scripts each inventing a hit
## test, which is how the palette drifted before menu_style.gd existed.
##
## THE KEYBOARD IS NOT TRADED. Every Control this kit builds sets FOCUS_NONE, so Godot's own
## focus walk never takes the arrow keys away from the _unhandled_input() cursor each menu
## already runs. That is the single most important claim in this file and it is asserted.

const MouseRowsScript := preload("res://ui/mouse_rows.gd")
const MenuStyleScript := preload("res://ui/menu_style.gd")

var _hovered: Array[int] = []
var _clicked: Array[int] = []


func before_each() -> void:
	_hovered = []
	_clicked = []


func _hover(index: int) -> void:
	_hovered.append(index)


func _click(index: int) -> void:
	_clicked.append(index)


func test_an_armed_row_reports_its_index_and_stops_the_mouse() -> void:
	var holder := PanelContainer.new()
	MouseRowsScript.arm(holder, 3, _hover, _click)
	assert_eq(MouseRowsScript.row_index(holder), 3)
	assert_eq(holder.mouse_filter, Control.MOUSE_FILTER_STOP,
		"a row that ignores the mouse cannot be clicked")
	holder.free()


func test_an_unarmed_control_reports_minus_one_rather_than_crashing() -> void:
	var holder := PanelContainer.new()
	assert_eq(MouseRowsScript.row_index(holder), -1)
	holder.free()


func test_hovering_an_armed_row_calls_back_with_its_index() -> void:
	var holder := PanelContainer.new()
	MouseRowsScript.arm(holder, 2, _hover, _click)
	holder.mouse_entered.emit()
	assert_eq(_hovered, [2] as Array[int])
	assert_eq(_clicked, [] as Array[int], "hovering is not choosing")
	holder.free()


func test_a_left_click_on_an_armed_row_calls_back_with_its_index() -> void:
	var holder := PanelContainer.new()
	MouseRowsScript.arm(holder, 5, _hover, _click)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	holder.gui_input.emit(event)
	assert_eq(_clicked, [5] as Array[int])
	holder.free()


func test_a_right_click_and_a_release_do_nothing() -> void:
	var holder := PanelContainer.new()
	MouseRowsScript.arm(holder, 5, _hover, _click)
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	holder.gui_input.emit(right)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	holder.gui_input.emit(release)
	assert_eq(_clicked, [] as Array[int], "only a left press takes a row")
	holder.free()


func test_row_builds_the_holder_the_menus_already_draw() -> void:
	var idle: PanelContainer = MouseRowsScript.row(0, false, false, _hover, _click)
	var picked: PanelContainer = MouseRowsScript.row(1, true, false, _hover, _click)
	var hovered: PanelContainer = MouseRowsScript.row(2, false, true, _hover, _click)
	assert_eq(idle.get_theme_stylebox(&"panel"), MenuStyleScript.row_box(false))
	assert_eq(picked.get_theme_stylebox(&"panel"), MenuStyleScript.row_box(true))
	var hover_box: StyleBoxFlat = hovered.get_theme_stylebox(&"panel") as StyleBoxFlat
	assert_eq(hover_box.bg_color, MenuStyleScript.row_box_hover().bg_color)
	assert_eq(MouseRowsScript.row_index(hovered), 2)
	for holder: PanelContainer in [idle, picked, hovered]:
		holder.free()


func test_selection_beats_hover_when_a_row_is_both() -> void:
	var both: PanelContainer = MouseRowsScript.row(0, true, true, _hover, _click)
	assert_eq(both.get_theme_stylebox(&"panel"), MenuStyleScript.row_box(true),
		"the row she is on is the row she is on, pointer or no pointer")
	both.free()


func test_nothing_the_kit_builds_takes_keyboard_focus() -> void:
	var holder: PanelContainer = MouseRowsScript.row(0, false, false, _hover, _click)
	var button: Button = MouseRowsScript.close_button("Close", _click)
	assert_eq(holder.focus_mode, Control.FOCUS_NONE,
		"a focusable row would steal the arrow keys from the menu cursor")
	assert_eq(button.focus_mode, Control.FOCUS_NONE)
	holder.free()
	button.free()


func test_the_close_button_says_what_it_does_and_calls_back() -> void:
	var button: Button = MouseRowsScript.close_button("Close", _click)
	assert_eq(button.text, "Close")
	button.pressed.emit()
	assert_eq(_clicked.size(), 1, "the close button has to actually close")
	button.free()


func test_hit_finds_the_rect_under_the_point_and_answers_minus_one_outside() -> void:
	var rects: Array[Rect2] = [Rect2(0, 0, 10, 10), Rect2(20, 0, 10, 10),
		Rect2(40, 0, 10, 10)]
	assert_eq(MouseRowsScript.hit(rects, Vector2(5, 5)), 0)
	assert_eq(MouseRowsScript.hit(rects, Vector2(25, 5)), 1)
	assert_eq(MouseRowsScript.hit(rects, Vector2(45, 9)), 2)
	assert_eq(MouseRowsScript.hit(rects, Vector2(15, 5)), -1, "the gap between rows")
	assert_eq(MouseRowsScript.hit(rects, Vector2(5, 50)), -1, "below every row")


func test_hit_on_an_empty_list_is_a_miss_and_not_an_error() -> void:
	assert_eq(MouseRowsScript.hit([] as Array[Rect2], Vector2.ZERO), -1)


func test_is_left_click_reads_only_a_left_press() -> void:
	var left := InputEventMouseButton.new()
	left.button_index = MOUSE_BUTTON_LEFT
	left.pressed = true
	assert_true(MouseRowsScript.is_left_click(left))
	var motion := InputEventMouseMotion.new()
	assert_false(MouseRowsScript.is_left_click(motion))
	var key := InputEventKey.new()
	key.pressed = true
	assert_false(MouseRowsScript.is_left_click(key))
