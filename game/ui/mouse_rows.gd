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

const CLOSE_TEXT := "Close"


## Whether `event` is the one gesture this kit acts on: a LEFT button going DOWN. A release
## is deliberately not a click here, because every menu below this pauses the tree and a
## press that opened a menu must not have its release taken as a choice inside it.
static func is_left_click(event: InputEvent) -> bool:
	var button := event as InputEventMouseButton
	return button != null and button.pressed \
		and button.button_index == MOUSE_BUTTON_LEFT


## Make `holder` answer the pointer as row `index`. Safe to call on a Control already in a
## tree and on one that is not; safe with invalid callables, which simply arm nothing.
static func arm(holder: Control, index: int, on_hover: Callable,
		on_click: Callable) -> void:
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
	arm(holder, index, on_hover, on_click)
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


## WHICH RECT THE POINTER IS IN, for the screens that paint their rows instead of stacking
## them: the casino felt, the mail stationery. Returns the FIRST hit, so a caller with
## overlapping rects gets the one it listed first rather than an arbitrary one.
static func hit(rects: Array[Rect2], point: Vector2) -> int:
	for i in rects.size():
		if rects[i].has_point(point):
			return i
	return -1
