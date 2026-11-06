class_name MouseRows
extends RefCounted
## THE POINTER, TAUGHT ONCE. The owner's first full playtest, 2026-09-04: "all ui being
## keyboard only is tough". Every menu in this game already builds its rows the same way, a
## PanelContainer carrying the shared StyleBoxFlat with a Label inside it, so this file arms
## that holder with hover and click and every menu changes one line of its refresh().
##
## THE KEYBOARD IS ADDED TO, NEVER TRADED. Every Control built here sets FOCUS_NONE. Godot's
## own focus walk would otherwise take ui_up and ui_down off the _unhandled_input() cursor
## each menu runs, which would be removing the keyboard in the act of adding the mouse. The
## footers keep printing their key hints for the same reason.
##
## THE CALLBACKS TAKE AN INDEX AND NOTHING ELSE. A menu knows what its own row 3 means; this
## file must not, or it becomes a second place row order is decided.
##
## Static only, no state, no scene. Preload by path.

const MenuStyleScript := preload("res://ui/menu_style.gd")

## Stamped on every armed holder so a test, and a menu rebuilding its column, can ask a
## Control which row it is without keeping a parallel array beside the VBox.
const ROW_INDEX_META := &"filly_row_index"

## "Back", not "Close" (PT5; owner: "back button please"), on every panel.
const CLOSE_TEXT := "Back"


## Whether `event` is the one gesture this kit acts on: a LEFT button going DOWN. A release
## is deliberately not a click here, because every menu below this pauses the tree and a
## press that opened a menu must not have its release taken as a choice inside it.
static func is_left_click(event: InputEvent) -> bool:
	var button := event as InputEventMouseButton
	return button != null and button.pressed \
		and button.button_index == MOUSE_BUTTON_LEFT


## Make `holder` answer the pointer as row `index`. Safe to call on a Control already in a
## tree and on one that is not; safe with invalid callables, which simply arm nothing.
##
## M14, final-review.md M6: `on_exit`, called with no arguments other than `index` when the
## pointer LEAVES `holder`, same as `on_hover` fires when it arrives. Optional (an invalid
## Callable arms nothing extra) because the two direct callers that keep one Control armed
## across a rebuild (build_menu.gd, table_menu.gd) have no per-row idle stylebox to fall
## back to here; `row()` below, which is what almost every menu in the game calls, supplies
## one.
static func arm(holder: Control, index: int, on_hover: Callable, on_click: Callable,
		on_exit: Callable = Callable()) -> void:
	if holder == null:
		return
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.focus_mode = Control.FOCUS_NONE
	holder.set_meta(ROW_INDEX_META, index)
	if on_hover.is_valid():
		holder.mouse_entered.connect(func() -> void: on_hover.call(index))
	if on_click.is_valid():
		holder.gui_input.connect(func(event: InputEvent) -> void:
			if is_left_click(event):
				on_click.call(index)
				holder.accept_event())
	if on_exit.is_valid():
		holder.mouse_exited.connect(func() -> void: on_exit.call(index))


## Which row `holder` is, or -1 if nothing armed it.
static func row_index(holder: Control) -> int:
	if holder == null or not holder.has_meta(ROW_INDEX_META):
		return -1
	return int(holder.get_meta(ROW_INDEX_META))


## THE ROW EVERY MENU NOW BUILDS. Replaces MenuStyle.row_panel(picked), which stays for the
## two panels that draw rows nobody may pick.
##
## SELECTION BEATS HOVER. A row that is both is drawn selected: the pointer says what you
## would take and the cursor says what is taken, and when they are the same row there is
## only one thing to say.
static func row(index: int, picked: bool, hovered: bool, on_hover: Callable,
		on_click: Callable) -> PanelContainer:
	var holder := PanelContainer.new()
	var box: StyleBoxFlat = MenuStyleScript.row_box(true) if picked \
		else (MenuStyleScript.row_box_hover() if hovered else MenuStyleScript.row_box(false))
	holder.add_theme_stylebox_override(&"panel", box)
	# M14: A ROW THAT IS NOT THE PICK REVERTS TO IDLE WHEN THE POINTER LEAVES IT, rather than
	# keeping whatever box it was built with (row_box_hover() when `hovered` said this was
	# the last row the pointer touched) until some unrelated interaction forces a full
	# _refresh(). The picked row is left alone: its box says what is TAKEN, not where the
	# pointer is, and leaving it must not touch that.
	var on_exit := Callable()
	if not picked:
		on_exit = func(_index: int) -> void:
			holder.add_theme_stylebox_override(&"panel", MenuStyleScript.row_box(false))
	arm(holder, index, on_hover, on_click, on_exit)
	return holder


## THE POINTER USABLE WAY OUT OF EVERY SCREEN. The spec asks for one on every panel, and a
## player who reached a menu with the mouse must be able to leave it with the mouse.
static func close_button(label: String, on_click: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	if on_click.is_valid():
		button.pressed.connect(func() -> void: on_click.call(-1))
	return button


## I5, final-review.md I3: A TAB STRIP THE POINTER CAN TAKE. `container` is the same `Tabs`
## node every tabbed panel already carries (a Label until this fix, an HBoxContainer since);
## `names[i]` becomes a FOCUS_NONE Button reading exactly what MenuStyle.tab_strip() would
## have printed for that index -- "[Name]" when `i == active`, " Name " otherwise -- so the
## caret/screenshot contract that string carried is unchanged, it is just spread across
## `names.size()` Controls now instead of baked into one Label's text. Rebuilds `container`'s
## children on every call, the same discipline every menu's own refresh() already applies to
## its Rows column.
##
## queue_free(), NOT free(). A click on a tab runs take_take() -> set_tab() -> refresh() ->
## straight back into THIS function, from inside the very Button's own gui_input signal that
## is still on the call stack -- freeing that Button synchronously here is freeing a locked
## object mid-emission, which the engine refuses. SwatchGrid.set_swatches() can free()
## immediately because nothing there ever rebuilds the grid a cell's own click just fired
## from; a tab strip is exactly that case.
static func tab_strip(container: Control, names: Array[String], active: int,
		on_point: Callable, on_take: Callable) -> void:
	if container == null:
		return
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
	# REAL TABS, NOT BRACKETS (PT5; playtest 2026-11-05: "[Colour]  Number", "[Deliver]  Pay"
	# read as debug text). The active tab is a lit pill in the HUD's violet; the others are
	# quiet labels that brighten under the pointer.
	container.add_theme_constant_override(&"separation", 8)
	for i in names.size():
		var button := Button.new()
		button.text = names[i]
		button.flat = false
		button.add_theme_font_size_override(&"font_size", MenuStyleScript.font_px(MenuStyleScript.ROW_SIZE))
		var on := i == active
		for state: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
			button.add_theme_stylebox_override(state, _tab_box(on, state == &"hover"))
		button.add_theme_color_override(&"font_color",
			Color(1, 1, 1) if on else Color(0.82, 0.76, 0.90))
		button.add_theme_color_override(&"font_hover_color", Color(1, 1, 1))
		button.add_theme_constant_override(&"outline_size", 0)
		button.set_meta(&"active_tab", on)
		arm(button, i, on_point, on_take)
		container.add_child(button)


static func _tab_box(on: bool, hover: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(14)
	box.content_margin_left = 18.0
	box.content_margin_right = 18.0
	box.content_margin_top = 6.0
	box.content_margin_bottom = 6.0
	if on:
		box.bg_color = Color(0.48, 0.30, 0.66)
		box.set_border_width_all(2)
		box.border_color = Color(0.80, 0.66, 0.95)
	else:
		box.bg_color = Color(1, 1, 1, 0.10 if hover else 0.04)
	return box


## Which tab button is lit, or -1.
static func active_tab(container: Control) -> int:
	if container == null:
		return -1
	var i := 0
	for c in container.get_children():
		if c is Button and not c.is_queued_for_deletion():
			if bool(c.get_meta(&"active_tab", false)):
				return i
			i += 1
	return -1


## WHICH RECT THE POINTER IS IN, for the screens that paint their rows instead of stacking
## them: the casino felt, the mail stationery. Returns the FIRST hit, so a caller with
## overlapping rects gets the one it listed first rather than an arbitrary one.
static func hit(rects: Array[Rect2], point: Vector2) -> int:
	for i in rects.size():
		if rects[i].has_point(point):
			return i
	return -1
