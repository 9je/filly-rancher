class_name PauseMenu
extends CanvasLayer
## ESCAPE OPENS THIS. It used to free the cursor and nothing else; the owner: "i also
## want pause menu instead of losing mouse control with escape". Phase 2 slice 1.
##
## Resume, Save, Settings, Quit. The rules are game/ui/build_menu.gd's: navigable without
## a mouse on ui_*, PROCESS_MODE_ALWAYS while ranch.gd pauses the tree, and it only emits.
## ranch.gd saves, quits, applies settings, and pauses or unpauses.
##
## `can_open` is how the ranch says "another menu is up": the build and market menus
## close on ui_cancel and this opens on `pause`, both of which are Escape, so without the
## guard one keypress would close one menu and open this one in the same frame.
##
## Phase 2 slice 5 adds Compendium and Requests pages here; the Page enum is where they go.

const SettingsScript := preload("res://systems/settings.gd")

enum Page { MAIN, SETTINGS }
enum Row { RESUME, SAVE, SETTINGS, QUIT }
enum SettingRow { VOLUME, SENSITIVITY, INVERT }

const MAIN_ROWS := ["Resume", "Save the ranch", "Settings", "Quit to desktop"]
const COLOR_TITLE := Color(1.0, 0.96, 0.86, 1.0)
const COLOR_NAME := Color(1.0, 1.0, 1.0, 0.94)
const COLOR_DIM := Color(1.0, 1.0, 1.0, 0.58)
const COLOR_VALUE := Color(1.00, 0.80, 0.25, 1.0)
const ROW_SELECTED_BG := Color(1.0, 0.86, 0.55, 0.16)
const ROW_SELECTED_BORDER := Color(1.0, 0.86, 0.55, 0.75)
const ROW_IDLE_BG := Color(1.0, 1.0, 1.0, 0.04)
const ROW_IDLE_BORDER := Color(1.0, 1.0, 1.0, 0.10)
const FOOTER_MAIN := "  ↑ ↓  choose      Enter / A  select      Esc / B  resume"
const FOOTER_SETTINGS := "  ↑ ↓  choose      ← →  adjust      Esc / B  back"

@onready var _title: Label = $Centre/Panel/Margin/Column/Title
@onready var _rows: VBoxContainer = $Centre/Panel/Margin/Column/Rows
@onready var _footer: Label = $Centre/Panel/Margin/Column/Footer

signal opened()
signal closed()
signal save_requested()
signal quit_requested()
signal settings_changed()

var settings: Settings = null
## `func() -> bool`. Invalid means "always allowed".
var can_open := Callable()

var _page: int = Page.MAIN
var _selected := 0
var _open := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_style_label(_title, 34, COLOR_TITLE)
	_style_label(_footer, 20, COLOR_DIM)
	_title.text = "PAUSED"
	visible = false


func open() -> bool:
	if _open:
		return false
	if can_open.is_valid() and not bool(can_open.call()):
		return false
	if settings == null:
		settings = SettingsScript.new()
	_page = Page.MAIN
	_selected = Row.RESUME
	_open = true
	visible = true
	_refresh()
	opened.emit()
	return true


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	closed.emit()


func is_open() -> bool:
	return _open


func page() -> int:
	return _page


func selected_index() -> int:
	return _selected


func _row_count() -> int:
	return MAIN_ROWS.size() if _page == Page.MAIN else SettingRow.size()


func move_selection(step: int) -> void:
	_selected = posmod(_selected + step, _row_count())
	_refresh()


## Left or right on a settings row. Nothing on the main page.
func adjust(direction: int) -> void:
	if _page != Page.SETTINGS or settings == null:
		return
	match _selected:
		SettingRow.VOLUME:
			settings.step_volume(direction)
		SettingRow.SENSITIVITY:
			settings.step_sensitivity(direction)
		SettingRow.INVERT:
			settings.toggle_invert()
	settings_changed.emit()
	_refresh()


func confirm() -> bool:
	if _page == Page.SETTINGS:
		if _selected == SettingRow.INVERT:
			adjust(1)
			return true
		return false
	match _selected:
		Row.RESUME:
			close()
		Row.SAVE:
			save_requested.emit()
		Row.SETTINGS:
			_page = Page.SETTINGS
			_selected = 0
			_refresh()
		Row.QUIT:
			quit_requested.emit()
	return true


## Cancel: settings goes back to main; main closes.
func back() -> void:
	if _page == Page.SETTINGS:
		_page = Page.MAIN
		_selected = Row.SETTINGS
		_refresh()
		return
	close()


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		if event.is_action_pressed(&"pause"):
			if open():
				get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		back()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_down"):
		move_selection(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_up"):
		move_selection(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_left"):
		adjust(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_right"):
		adjust(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_accept"):
		confirm()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	# remove_child BEFORE queue_free: a queued node is still a child until the end of the
	# frame, so freeing alone would leave the old rows laid out underneath the new ones for
	# one frame every time the cursor moves. Same fix as market_menu.gd's refresh().
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	if _page == Page.MAIN:
		_title.text = "PAUSED"
		_footer.text = FOOTER_MAIN
		for i in range(MAIN_ROWS.size()):
			_add_row(i, MAIN_ROWS[i], "")
	else:
		_title.text = "SETTINGS"
		_footer.text = FOOTER_SETTINGS
		_add_row(0, "Master volume", "%d%%" % int(round(settings.master_volume * 100.0)))
		_add_row(1, "Mouse sensitivity", "%.1f" % (settings.mouse_sensitivity * 1000.0))
		_add_row(2, "Invert look", "On" if settings.invert_look else "Off")


func _add_row(index: int, row_name: String, value: String) -> void:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override(&"panel", _row_style(index == _selected))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 18)
	margin.add_theme_constant_override(&"margin_right", 18)
	margin.add_theme_constant_override(&"margin_top", 10)
	margin.add_theme_constant_override(&"margin_bottom", 10)
	row.add_child(margin)
	var head := HBoxContainer.new()
	margin.add_child(head)
	var title := Label.new()
	title.text = row_name
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_label(title, 26, COLOR_NAME)
	head.add_child(title)
	if not value.is_empty():
		var val := Label.new()
		val.text = value
		_style_label(val, 24, COLOR_VALUE)
		head.add_child(val)
	_rows.add_child(row)


func _row_style(selected: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = ROW_SELECTED_BG if selected else ROW_IDLE_BG
	box.border_color = ROW_SELECTED_BORDER if selected else ROW_IDLE_BORDER
	box.set_border_width_all(2 if selected else 1)
	box.set_corner_radius_all(8)
	return box


func _style_label(label: Label, size: int, color: Color) -> void:
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.75))
	label.add_theme_constant_override(&"outline_size", 5)
