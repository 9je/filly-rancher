extends GutTest
## Tests for game/systems/settings.gd. Settings live in user://settings.cfg, NOT in the
## save: they are about the machine and the person, not the ranch, and a traded save
## must not carry someone else's mouse sensitivity.

const SettingsScript := preload("res://systems/settings.gd")
const SaveIOScript := preload("res://systems/save_io.gd")
const SCRATCH := "user://test_scratch/settings_test.cfg"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://test_scratch"))
	if FileAccess.file_exists(SCRATCH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))


func test_defaults() -> void:
	var s = SettingsScript.new()
	assert_almost_eq(s.master_volume, 1.0, 0.0001)
	assert_almost_eq(s.mouse_sensitivity, 0.0035, 0.00001)
	assert_false(s.invert_look)


func test_round_trips_through_a_file() -> void:
	var s = SettingsScript.new()
	s.master_volume = 0.4
	s.mouse_sensitivity = 0.006
	s.invert_look = true
	assert_true(s.save_to(SCRATCH))
	var back = SettingsScript.new()
	back.load_from(SCRATCH)
	assert_almost_eq(back.master_volume, 0.4, 0.0001)
	assert_almost_eq(back.mouse_sensitivity, 0.006, 0.00001)
	assert_true(back.invert_look)


func test_loading_a_missing_file_keeps_defaults() -> void:
	var s = SettingsScript.new()
	s.load_from("user://test_scratch/does_not_exist.cfg")
	assert_almost_eq(s.master_volume, 1.0, 0.0001)


func test_steps_are_clamped_and_signal() -> void:
	var s = SettingsScript.new()
	watch_signals(s)
	for i in range(20):
		s.step_volume(1)
	assert_almost_eq(s.master_volume, 1.0, 0.0001, "volume tops out at 1.0")
	for i in range(20):
		s.step_volume(-1)
	assert_almost_eq(s.master_volume, 0.0, 0.0001, "and bottoms out at 0.0")
	for i in range(50):
		s.step_sensitivity(1)
	assert_lte(s.mouse_sensitivity, SettingsScript.SENSITIVITY_MAX)
	for i in range(50):
		s.step_sensitivity(-1)
	assert_gte(s.mouse_sensitivity, SettingsScript.SENSITIVITY_MIN)
	s.toggle_invert()
	assert_true(s.invert_look)
	assert_signal_emitted(s, "changed")


func test_apply_audio_sets_the_master_bus() -> void:
	var s = SettingsScript.new()
	var master := AudioServer.get_bus_index("Master")
	var was_muted := AudioServer.is_bus_mute(master)
	var was_db := AudioServer.get_bus_volume_db(master)
	s.master_volume = 0.5
	s.apply_audio()
	assert_almost_eq(AudioServer.get_bus_volume_db(master), linear_to_db(0.5), 0.01)
	s.master_volume = 0.0
	s.apply_audio()
	assert_true(AudioServer.is_bus_mute(master), "zero volume mutes rather than sending -inf dB")
	# Put the bus back so this test does not change the rest of the run.
	AudioServer.set_bus_mute(master, was_muted)
	AudioServer.set_bus_volume_db(master, was_db)


func test_the_two_new_volumes_default_open() -> void:
	var s = SettingsScript.new()
	assert_almost_eq(s.ambient_volume, Settings.AMBIENT_DEFAULT, 0.0001)
	assert_almost_eq(s.effects_volume, 1.0, 0.0001)


func test_the_two_new_volumes_round_trip_through_a_file() -> void:
	var s = SettingsScript.new()
	s.ambient_volume = 0.3
	s.effects_volume = 0.7
	assert_true(s.save_to(SCRATCH))
	var back = SettingsScript.new()
	back.load_from(SCRATCH)
	assert_almost_eq(back.ambient_volume, 0.3, 0.0001)
	assert_almost_eq(back.effects_volume, 0.7, 0.0001)


func test_ambient_steps_clamp_at_both_ends_and_signal() -> void:
	var s = SettingsScript.new()
	watch_signals(s)
	for i in range(20):
		s.step_ambient(-1)
	assert_almost_eq(s.ambient_volume, 0.0, 0.0001)
	for i in range(20):
		s.step_ambient(1)
	assert_almost_eq(s.ambient_volume, 1.0, 0.0001)
	assert_signal_emitted(s, "changed")


func test_effects_steps_clamp_at_both_ends() -> void:
	var s = SettingsScript.new()
	for i in range(20):
		s.step_effects(-1)
	assert_almost_eq(s.effects_volume, 0.0, 0.0001)
	for i in range(20):
		s.step_effects(1)
	assert_almost_eq(s.effects_volume, 1.0, 0.0001)


func test_a_step_that_changes_nothing_emits_nothing() -> void:
	var s = SettingsScript.new()
	s.ambient_volume = 1.0
	watch_signals(s)
	s.step_ambient(1)
	assert_signal_emit_count(s, "changed", 0)


## v1: every bus has its own slider (UI no longer rides Effects).
func test_apply_audio_pushes_every_slider_and_zero_mutes() -> void:
	var s = SettingsScript.new()
	s.master_volume = 1.0
	s.ambient_volume = 0.5
	s.effects_volume = 0.0
	s.ui_volume = 0.0
	s.music_volume = 0.25
	s.apply_audio()
	var ambient: int = AudioServer.get_bus_index("Ambient")
	var effects: int = AudioServer.get_bus_index("Effects")
	var ui: int = AudioServer.get_bus_index("UI")
	assert_gt(ambient, 0)
	assert_false(AudioServer.is_bus_mute(ambient))
	assert_almost_eq(AudioServer.get_bus_volume_db(ambient), linear_to_db(0.5), 0.01)
	# Zero mutes rather than setting -inf dB.
	assert_true(AudioServer.is_bus_mute(effects))
	assert_true(AudioServer.is_bus_mute(ui))
	var music: int = AudioServer.get_bus_index("Music")
	assert_almost_eq(AudioServer.get_bus_volume_db(music), linear_to_db(0.25), 0.01)
	# Put the buses back so a later test in the same run is not reading this one's leavings.
	s.effects_volume = 1.0
	s.ui_volume = 0.8
	s.music_volume = 0.8
	s.apply_audio()


func test_a_loaded_file_missing_the_new_keys_keeps_the_defaults() -> void:
	# A settings.cfg written before this slice has no ambient_volume key at all; it must
	# load as "wide open", not as silence.
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "master_volume", 0.8)
	assert_eq(cfg.save(SCRATCH), OK)
	var s = SettingsScript.new()
	s.load_from(SCRATCH)
	assert_almost_eq(s.master_volume, 0.8, 0.0001)
	assert_almost_eq(s.ambient_volume, Settings.AMBIENT_DEFAULT, 0.0001)
	assert_almost_eq(s.effects_volume, 1.0, 0.0001)


# --- THE TEST MODE REDIRECT ----------------------------------------------------------------
#
# settings.cfg is the same class of defect as the save slots: a gate boot that opened the pause
# menu and changed a knob rewrote the player's own settings file. It follows SaveIO's session
# directory rather than reading the environment a second time, so there is exactly one read of
# FILLY_TEST_SAVE_DIR in the whole project.

func test_a_redirected_save_directory_takes_the_settings_file_with_it() -> void:
	assert_eq(SettingsScript.resolve_settings_path("/tmp/filly-saves-1234"),
		"/tmp/filly-saves-1234/settings.cfg",
		"a run that saves elsewhere must not be able to rewrite the player's own knobs")


func test_the_default_directory_leaves_the_settings_file_where_it_was() -> void:
	assert_eq(SettingsScript.resolve_settings_path(SaveIOScript.DEFAULT_SAVE_DIR),
		SettingsScript.PATH,
		"settings.cfg sits beside saves/, not inside it, when nothing was redirected")


## The wiring, in both directions, exactly like test_save_io.gd's session directory test.
func test_the_session_settings_path_follows_the_session_save_directory() -> void:
	assert_eq(SettingsScript.settings_path,
		SettingsScript.resolve_settings_path(SaveIOScript.session_save_dir),
		"_static_init() must resolve the settings path from SaveIO's session directory")
	if SaveIOScript.session_save_dir == SaveIOScript.DEFAULT_SAVE_DIR:
		assert_eq(SettingsScript.settings_path, SettingsScript.PATH,
			"nothing was exported, so the settings file is the player's own")
	else:
		assert_ne(SettingsScript.settings_path, SettingsScript.PATH,
			"a redirected process must not be able to reach the player's settings file")


## THE AMBIENCE STARTS UNDER THE MIX. The owner, on her first full playtest: the beds are too
## loud. Spec section 6: "ambient beds down (start -6 dB on the Ambient bus default)".
##
## A DEFAULT, NOT A CEILING. The slider still reaches 100%; this is only where it starts, so a
## player who wants the dawn chorus at full can still have it and a player who never opens the
## settings page is not shouted at.
func test_the_ambient_bus_starts_six_decibels_down() -> void:
	var s: Settings = SettingsScript.new()
	assert_almost_eq(s.ambient_volume, Settings.AMBIENT_DEFAULT, 0.0001)
	assert_almost_eq(linear_to_db(Settings.AMBIENT_DEFAULT), -6.0, 0.1,
		"the default is six decibels down, measured rather than asserted")


func test_the_other_sliders_still_start_open() -> void:
	var s: Settings = SettingsScript.new()
	assert_almost_eq(s.master_volume, 1.0, 0.0001,
		"only the ambience moved; the master and the effects did not")
	assert_almost_eq(s.effects_volume, 1.0, 0.0001)


func test_a_saved_ambient_setting_still_wins_over_the_new_default() -> void:
	# M15, final-review.md M7: SaveIO.session_save_dir, NOT A HARD-CODED user:// PATH.
	# FILLY_TEST_SAVE_DIR redirects SaveIO.save_dir and Settings.settings_path, not a literal
	# "user://" string, so the old path was the one hole left in R0's "a sweep leaves the
	# player's directory alone" property: this file was created for real, on every suite run,
	# in ~/.local/share/godot/app_userdata/Filly Rancher/. session_save_dir is exactly the
	# directory every other test in this file already trusts (see
	# test_the_session_settings_path_follows_the_session_save_directory above), and it is a
	# real native mktemp path on any run that sets FILLY_TEST_SAVE_DIR, which every documented
	# gate and suite command does.
	var path := SaveIOScript.session_save_dir.path_join("test_settings_ambient.cfg")
	var s: Settings = SettingsScript.new()
	s.ambient_volume = 1.0
	assert_true(s.save_to(path))
	var back: Settings = SettingsScript.new()
	back.load_from(path)
	assert_almost_eq(back.ambient_volume, 1.0, 0.0001,
		"a player who already turned it up keeps it turned up")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## v1: the new fields survive a save, and a key bound twice moves rather than doubles.
func test_v1_fields_round_trip_and_a_key_does_one_thing() -> void:
	var path := OS.get_temp_dir().path_join("filly_settings_v1_%d.cfg" % randi())
	var a := SettingsScript.new()
	a.music_volume = 0.3
	a.ui_volume = 0.2
	a.voice_volume = 0.6
	a.quality = SettingsScript.Quality.LOW
	a.fullscreen = true
	a.vsync = false
	a.bind(&"jump", KEY_J)
	a.bind(&"interact", KEY_J)
	assert_eq(int(a.bindings.get(&"jump", 0)), KEY_E, "J moved to interact, and jump took interact's old E")
	assert_true(a.save_to(path))
	var b := SettingsScript.new()
	b.load_from(path)
	assert_almost_eq(b.music_volume, 0.3, 0.001)
	assert_almost_eq(b.ui_volume, 0.2, 0.001)
	assert_eq(b.quality, SettingsScript.Quality.LOW)
	assert_true(b.fullscreen)
	assert_false(b.vsync)
	assert_eq(int(b.bindings.get(&"interact", 0)), KEY_J)
	DirAccess.remove_absolute(path)


## A key taken from an action that only had its project default swaps that action onto the
## thief's old key, so no key does two things and no action is left without one.
func test_stealing_a_default_key_swaps_it() -> void:
	var a := SettingsScript.new()
	var w := SettingsScript.key_of(&"move_forward", {})
	var space := SettingsScript.key_of(&"jump", {})
	assert_gt(w, 0)
	a.bind(&"jump", w)
	assert_eq(SettingsScript.key_of(&"jump", a.bindings), w)
	assert_eq(SettingsScript.key_of(&"move_forward", a.bindings), space)
	a.unbind(&"jump")
	assert_eq(SettingsScript.key_of(&"jump", a.bindings), space)


## apply_bindings rebuilds from the project's own events: an action back on its default gets
## its default key again, not whatever the InputMap held last.
func test_apply_bindings_rebuilds_from_the_defaults() -> void:
	var a := SettingsScript.new()
	a.bind(&"jump", KEY_J)
	a.apply_bindings()
	var has_j := false
	for e in InputMap.action_get_events(&"jump"):
		if e is InputEventKey and (e as InputEventKey).physical_keycode == KEY_J:
			has_j = true
	assert_true(has_j)
	a.unbind(&"jump")
	a.apply_bindings()
	var keys: Array[int] = []
	for e in InputMap.action_get_events(&"jump"):
		if e is InputEventKey:
			keys.append(int((e as InputEventKey).physical_keycode))
	assert_false(KEY_J in keys, "J is gone")
	assert_true(SettingsScript.key_of(&"jump", {}) in keys, "the default is back")


func test_a_saved_binding_that_is_nonsense_is_dropped() -> void:
	var path := OS.get_temp_dir().path_join("filly_settings_bad_%d.cfg" % randi())
	var cfg := ConfigFile.new()
	cfg.set_value(SettingsScript.SECTION, "bindings", {"jump": "banana", "interact": -4,
		"pause": KEY_ESCAPE, "sneak": KEY_K, "not_an_action": KEY_L})
	cfg.save(path)
	var b := SettingsScript.new()
	b.load_from(path)
	assert_eq(b.bindings, {&"sneak": KEY_K})
	DirAccess.remove_absolute(path)


## PT7 (playtest 2026-11-05: the town leaning out at the screen's edges): the old 75 degree
## default moves to 60 once; a field of view she picked herself is never touched.
func test_the_old_default_fov_moves_to_the_new_one_once() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "fov", SettingsScript.FOV_OLD_DEFAULT)
	cfg.save(SCRATCH)
	var s = SettingsScript.new()
	s.load_from(SCRATCH)
	assert_almost_eq(s.fov, SettingsScript.FOV_DEFAULT, 0.001)
	s.fov = SettingsScript.FOV_OLD_DEFAULT
	assert_true(s.save_to(SCRATCH))
	var back = SettingsScript.new()
	back.load_from(SCRATCH)
	assert_almost_eq(back.fov, SettingsScript.FOV_OLD_DEFAULT, 0.001,
		"chosen again after the move, it is hers")


func test_a_chosen_fov_is_kept() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "fov", 90.0)
	cfg.save(SCRATCH)
	var s = SettingsScript.new()
	s.load_from(SCRATCH)
	assert_almost_eq(s.fov, 90.0, 0.001)


## FS8.1 GAMEPAD REBINDING: the buttons move too, by the keyboard's rules. Only an action the
## project gives a pad button is rebound (the sticks stay as authored); a button another action
## held moves that action onto the old one; the binds save, and nonsense in the file is dropped.
func test_a_pad_button_rebinds_and_swaps() -> void:
	var a := SettingsScript.new()
	assert_true(SettingsScript.pad_rebindable(&"jump"))
	assert_false(SettingsScript.pad_rebindable(&"move_forward"), "a stick is not a button")
	var jump := SettingsScript.pad_button_of(&"jump", {})
	var talk := SettingsScript.pad_button_of(&"interact", {})
	a.pad_bind(&"jump", talk)
	assert_eq(SettingsScript.pad_button_of(&"jump", a.pad_bindings), talk)
	assert_eq(SettingsScript.pad_button_of(&"interact", a.pad_bindings), jump, "interact took jump's old button")
	assert_eq(a.last_swapped, &"interact")
	a.pad_bind(&"move_forward", JOY_BUTTON_A)
	assert_false(a.pad_bindings.has(&"move_forward"))
	a.pad_bind(&"jump", JOY_BUTTON_B)
	assert_eq(SettingsScript.pad_button_of(&"jump", a.pad_bindings), talk, "B backs out of menus, never bound")
	a.unbind(&"jump")
	assert_eq(SettingsScript.pad_button_of(&"jump", a.pad_bindings), jump, "the default is back")


func test_pad_binds_apply_save_and_load() -> void:
	var a := SettingsScript.new()
	a.pad_bind(&"treat", JOY_BUTTON_RIGHT_SHOULDER)
	a.apply_bindings()
	var buttons: Array[int] = []
	for e in InputMap.action_get_events(&"treat"):
		if e is InputEventJoypadButton:
			buttons.append(int((e as InputEventJoypadButton).button_index))
	assert_eq(buttons, [JOY_BUTTON_RIGHT_SHOULDER] as Array[int], "only the new button")
	a.save_to(SCRATCH)
	var b := SettingsScript.new()
	b.load_from(SCRATCH)
	assert_true(b.differences(a).is_empty(), "differs in %s" % [b.differences(a)])
	a.unbind(&"treat")
	a.apply_bindings()


func test_a_saved_pad_bind_that_is_nonsense_is_dropped() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SettingsScript.SECTION, "pad_bindings", {"jump": "banana", "treat": JOY_BUTTON_B,
		"move_back": JOY_BUTTON_X, "sneak": JOY_BUTTON_Y, "nope": JOY_BUTTON_A})
	cfg.save(SCRATCH)
	var b := SettingsScript.new()
	b.load_from(SCRATCH)
	assert_eq(b.pad_bindings, {&"sneak": JOY_BUTTON_Y})
