extends GutTest
## Tests for game/ui/pause_menu.gd. Same rules as the other menus: keyboard and gamepad
## through the methods ui_* route into, and the menu only emits; ranch.gd pauses, saves
## and quits.

const PauseMenuScene := preload("res://ui/pause_menu.tscn")
const SettingsScript := preload("res://systems/settings.gd")

var _menu: PauseMenu
var _settings: Settings


func before_each() -> void:
	_settings = SettingsScript.new()
	_menu = PauseMenuScene.instantiate()
	add_child_autofree(_menu)
	_menu.settings = _settings


func test_opens_on_main_with_resume_selected() -> void:
	watch_signals(_menu)
	assert_true(_menu.open())
	assert_true(_menu.is_open())
	assert_eq(_menu.page(), PauseMenu.Page.MAIN)
	assert_eq(_menu.selected_index(), PauseMenu.Row.RESUME)
	assert_signal_emitted(_menu, "opened")


func test_can_open_callable_can_refuse() -> void:
	_menu.can_open = func() -> bool: return false
	assert_false(_menu.open())
	assert_false(_menu.is_open())


func test_resume_closes() -> void:
	_menu.open()
	watch_signals(_menu)
	assert_true(_menu.confirm())
	assert_false(_menu.is_open())
	assert_signal_emitted(_menu, "closed")


func test_save_and_quit_emit_requests() -> void:
	_menu.open()
	watch_signals(_menu)
	_menu.move_selection(PauseMenu.Row.SAVE)
	_menu.confirm()
	assert_signal_emitted(_menu, "save_requested")
	assert_true(_menu.is_open(), "saving does not close the menu")
	_menu.move_selection(PauseMenu.Row.QUIT - PauseMenu.Row.SAVE)
	_menu.confirm()
	assert_signal_emitted(_menu, "quit_requested")


func test_settings_page_adjusts_the_settings_object() -> void:
	_menu.open()
	_menu.move_selection(PauseMenu.Row.SETTINGS)
	assert_true(_menu.confirm())
	assert_eq(_menu.page(), PauseMenu.Page.SETTINGS)
	watch_signals(_menu)
	# row 0 volume, row 1 sensitivity, row 2 invert
	_menu.adjust(-1)
	assert_almost_eq(_settings.master_volume, 0.9, 0.0001)
	_menu.move_selection(1)
	_menu.adjust(1)
	assert_gt(_settings.mouse_sensitivity, SettingsScript.SENSITIVITY_DEFAULT)
	_menu.move_selection(1)
	_menu.adjust(1)
	assert_true(_settings.invert_look)
	assert_signal_emitted(_menu, "settings_changed")


func test_cancel_on_settings_returns_to_main_and_on_main_closes() -> void:
	_menu.open()
	_menu.move_selection(PauseMenu.Row.SETTINGS)
	_menu.confirm()
	_menu.back()
	assert_eq(_menu.page(), PauseMenu.Page.MAIN)
	assert_true(_menu.is_open())
	_menu.back()
	assert_false(_menu.is_open())


func test_selection_wraps_on_both_pages() -> void:
	_menu.open()
	_menu.move_selection(-1)
	assert_eq(_menu.selected_index(), PauseMenu.Row.QUIT)
