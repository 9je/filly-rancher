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


func test_apply_audio_pushes_all_three_sliders_and_zero_mutes() -> void:
	var s = SettingsScript.new()
	s.master_volume = 1.0
	s.ambient_volume = 0.5
	s.effects_volume = 0.0
	s.apply_audio()
	var ambient: int = AudioServer.get_bus_index("Ambient")
	var effects: int = AudioServer.get_bus_index("Effects")
	var ui: int = AudioServer.get_bus_index("UI")
	assert_gt(ambient, 0)
	assert_false(AudioServer.is_bus_mute(ambient))
	assert_almost_eq(AudioServer.get_bus_volume_db(ambient), linear_to_db(0.5), 0.01)
	# Zero mutes rather than setting -inf dB, and the UI bus rides the effects slider.
	assert_true(AudioServer.is_bus_mute(effects))
	assert_true(AudioServer.is_bus_mute(ui))
	# Put the buses back so a later test in the same run is not reading this one's leavings.
	s.effects_volume = 1.0
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
	var path := "user://test_settings_ambient.cfg"
	var s: Settings = SettingsScript.new()
	s.ambient_volume = 1.0
	assert_true(s.save_to(path))
	var back: Settings = SettingsScript.new()
	back.load_from(path)
	assert_almost_eq(back.ambient_volume, 1.0, 0.0001,
		"a player who already turned it up keeps it turned up")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
