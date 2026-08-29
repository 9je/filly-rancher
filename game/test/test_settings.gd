extends GutTest
## Tests for game/systems/settings.gd. Settings live in user://settings.cfg, NOT in the
## save: they are about the machine and the person, not the ranch, and a traded save
## must not carry someone else's mouse sensitivity.

const SettingsScript := preload("res://systems/settings.gd")
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
