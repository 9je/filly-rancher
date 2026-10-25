extends GutTest
## The shared tabbed Settings menu (game/ui/settings_menu.gd): the draft, Apply, Revert, the
## display confirmation and its timeout, the unapplied-changes ask, key capture. The real
## input proof (keyboard, controller, mouse, focus rings, font sizes) is
## game/test_input/test_settings.gd; this pins the logic underneath it, headless.

const SettingsScript := preload("res://systems/settings.gd")
const MenuScene := preload("res://ui/settings_menu.tscn")

var _menu: SettingsMenu
var _settings: Settings
var _path := ""


func before_each() -> void:
	_path = "user://test_settings_menu_%d.cfg" % Time.get_ticks_usec()
	SettingsScript.settings_path = _path
	_settings = SettingsScript.new()
	_menu = MenuScene.instantiate()
	add_child_autofree(_menu)
	_menu.open(_settings)


func after_each() -> void:
	SettingsScript.settings_path = SettingsScript.resolve_settings_path(SaveIO.session_save_dir)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_path))


func _file() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(_path)
	return cfg


func test_four_tabs_in_order() -> void:
	assert_eq(SettingsMenu.TAB_NAMES, ["Graphics", "Audio", "Controls", "Gameplay"] as Array[String])
	for key: StringName in [&"window_mode", &"resolution", &"vsync", &"quality", &"fov",
			&"master_volume", &"music_volume", &"mouse_sensitivity", &"invert_look",
			&"show_controls_chip", &"pause_on_focus_loss", &"key_jump"]:
		assert_not_null(_menu.row_for(key), "a row for %s" % key)


func test_a_change_lands_on_the_draft_not_the_settings() -> void:
	assert_true(_menu._step(&"master_volume", -1))
	assert_almost_eq(_menu.draft.master_volume, 0.9, 0.0001)
	assert_almost_eq(_settings.master_volume, 1.0, 0.0001)
	assert_true(_menu.is_dirty())


func test_apply_commits_and_writes_the_file() -> void:
	watch_signals(_menu)
	_menu._step(&"fov", 1)
	_menu._step(&"show_checklist", -1)
	_menu.apply()
	assert_almost_eq(_settings.fov, 80.0, 0.001)
	assert_false(_settings.show_checklist)
	assert_almost_eq(float(_file().get_value("settings", "fov", 0.0)), 80.0, 0.001)
	assert_false(_menu.is_dirty())
	assert_signal_emitted(_menu, "applied")


func test_revert_puts_the_draft_back() -> void:
	_menu._step(&"music_volume", -1)
	_menu.revert()
	assert_almost_eq(_menu.draft.music_volume, _settings.music_volume, 0.0001)
	assert_false(_menu.is_dirty())
	assert_false(FileAccess.file_exists(_path), "Revert writes nothing")


func test_a_display_change_asks_and_saves_the_old_mode_until_kept() -> void:
	watch_signals(_menu)
	_menu._step(&"window_mode", 1)
	_menu.apply()
	assert_true(_menu.confirm_open())
	assert_eq(int(_file().get_value("settings", "window_mode", -1)), 0,
		"the unconfirmed mode is not on disk")
	assert_signal_not_emitted(_menu, "applied")
	_menu._keep_display()
	assert_false(_menu.confirm_open())
	assert_eq(int(_file().get_value("settings", "window_mode", -1)), 1)
	assert_signal_emitted(_menu, "applied")


func test_an_unanswered_display_change_changes_itself_back() -> void:
	_menu._step(&"window_mode", 1)
	_menu.apply()
	assert_true(_menu.confirm_open())
	var t := 0.0
	while t < SettingsMenu.DISPLAY_CONFIRM_SECONDS + 0.5:
		_menu._process(0.25)
		t += 0.25
	assert_false(_menu.confirm_open())
	assert_eq(_settings.window_mode, 0)
	assert_eq(_menu.draft.window_mode, 0)
	assert_eq(int(_file().get_value("settings", "window_mode", -1)), 0)


func test_leaving_with_unapplied_changes_asks_first() -> void:
	watch_signals(_menu)
	_menu._step(&"vsync", -1)
	_menu.request_close()
	assert_true(_menu.is_open(), "it asks instead of leaving")
	_menu._modal_discard_and_close()
	assert_false(_menu.is_open())
	assert_true(_settings.vsync, "discarded")
	assert_signal_emitted(_menu, "closed")


func test_leaving_with_nothing_changed_just_leaves() -> void:
	_menu.request_close()
	assert_false(_menu.is_open())


func test_a_key_row_rebinds_into_the_draft() -> void:
	_menu._activate(&"key_jump")
	var k := InputEventKey.new()
	k.pressed = true
	k.physical_keycode = KEY_J
	_menu._capture_input(k)
	assert_eq(int(_menu.draft.bindings.get(&"jump", 0)), KEY_J)
	assert_false(_settings.bindings.has(&"jump"), "not until Apply")
	_menu.apply()
	assert_eq(int(_settings.bindings.get(&"jump", 0)), KEY_J)


func test_resolution_only_moves_when_windowed() -> void:
	_menu.draft.window_mode = SettingsScript.WindowMode.FULLSCREEN
	assert_false(_menu._step(&"resolution", 1))
	_menu.draft.window_mode = SettingsScript.WindowMode.WINDOWED
	assert_true(_menu._step(&"resolution", 1))


func test_settings_round_trip_the_new_fields() -> void:
	var a := SettingsScript.new()
	a.window_mode = SettingsScript.WindowMode.EXCLUSIVE
	a.resolution = Vector2i(1920, 1080)
	a.fov = 90.0
	a.max_fps = 60
	a.stick_sensitivity = 3.0
	a.show_controls_chip = false
	a.pause_on_focus_loss = false
	a.save_to(_path)
	var b := SettingsScript.new()
	b.load_from(_path)
	assert_true(b.differences(a).is_empty(), "differs in %s" % [b.differences(a)])
	assert_true(b.fullscreen, "the old switch still reads the mode")
