class_name Settings
extends RefCounted
## WHAT THE PAUSE MENU'S SETTINGS PAGE EDITS: master, ambient and effects volume, mouse
## sensitivity, invert look. Persisted in user://settings.cfg, deliberately NOT in the
## save file: a save is a ranch two players trade by pasting; a setting is about one
## person's hand and one machine's speakers.
##
## ON AN AUTOMATED RUN IT MOVES WITH THE SAVES. FILLY_TEST_SAVE_DIR redirects SaveIO's save
## directory for one process (see game/systems/save_io.gd), and settings.cfg follows it into
## that directory. Same defect, same fix: a gate boot that opened the pause menu and nudged a
## slider used to rewrite the settings file of whoever owns the machine.
##
## RefCounted and file-backed, testable without a scene (game/test/test_settings.gd).
## apply_audio() is the only method that touches the engine.

## Where the settings file lives when nothing has been redirected. Kept as the literal it has
## always been: it is the path bug reports and docs name.
const PATH := "user://settings.cfg"

## The file name on its own, for the redirected case below.
const FILE_NAME := "settings.cfg"

## The settings file this process actually reads and writes. Resolved once, at class load, from
## SaveIO's already-resolved session directory -- NOT by reading the environment a second time,
## so there is exactly one read of FILLY_TEST_SAVE_DIR in the project and no way for two
## systems to disagree about whether this run is a test run.
static var settings_path := PATH

const SECTION := "settings"

const VOLUME_STEP := 0.1
const SENSITIVITY_MIN := 0.001
const SENSITIVITY_MAX := 0.010
const SENSITIVITY_STEP := 0.0005
const SENSITIVITY_DEFAULT := 0.0035  # camera_rig.gd's exported default


## Where settings.cfg belongs given the directory the saves are going to. The player's own save
## directory leaves it exactly where it has always been, beside saves/ rather than inside it;
## any other directory takes it along, because a redirected run must not be able to rewrite the
## volume and sensitivity of whoever owns the machine.
static func resolve_settings_path(save_directory: String) -> String:
	if save_directory == SaveIO.DEFAULT_SAVE_DIR:
		return PATH
	return save_directory.path_join(FILE_NAME)


## Referenced by class_name rather than by preload on purpose: SaveIO is a global class, so it
## resolves under tools/run_tests.sh's --check-only parse sweep, which an autoload identifier
## would not. Touching SaveIO here is what loads it, which is what runs its own _static_init and
## fills session_save_dir before this line reads it.
static func _static_init() -> void:
	settings_path = resolve_settings_path(SaveIO.session_save_dir)

signal changed()

var master_volume := 1.0

## THE AMBIENCE STARTS SIX DECIBELS DOWN. The owner, on the first full playtest: the beds sit
## on top of everything. linear_to_db(0.5) is -6.02, which is the number spec section 6 asks
## for, expressed as the linear the slider and the bus actually take.
##
## A DEFAULT AND NOT A CEILING: step_ambient() still walks the whole 0 to 1 range, and a
## settings.cfg that already carries a value keeps it, because load_from() defaults to the
## field rather than overwriting it.
const AMBIENT_DEFAULT := 0.5

## The two sub mixes, on the Ambient and Effects buses. The UI bus rides effects_volume:
## a fourth slider is knob clutter for a channel nobody wants louder than its own game.
var ambient_volume := AMBIENT_DEFAULT
var effects_volume := 1.0
var mouse_sensitivity := SENSITIVITY_DEFAULT
var invert_look := false


## An empty path means "this process's settings file" (settings_path). A caller that names one
## -- the tests do -- is taken at its word.
func load_from(path: String = "") -> void:
	var target := settings_path if path.is_empty() else path
	var cfg := ConfigFile.new()
	if cfg.load(target) != OK:
		return
	master_volume = clampf(float(cfg.get_value(SECTION, "master_volume", master_volume)), 0.0, 1.0)
	ambient_volume = clampf(float(cfg.get_value(SECTION, "ambient_volume", ambient_volume)), 0.0, 1.0)
	effects_volume = clampf(float(cfg.get_value(SECTION, "effects_volume", effects_volume)), 0.0, 1.0)
	mouse_sensitivity = clampf(float(cfg.get_value(SECTION, "mouse_sensitivity", mouse_sensitivity)),
		SENSITIVITY_MIN, SENSITIVITY_MAX)
	invert_look = bool(cfg.get_value(SECTION, "invert_look", invert_look))
	changed.emit()


## Same rule as load_from(): empty means this process's settings file.
func save_to(path: String = "") -> bool:
	var target := settings_path if path.is_empty() else path
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "master_volume", master_volume)
	cfg.set_value(SECTION, "ambient_volume", ambient_volume)
	cfg.set_value(SECTION, "effects_volume", effects_volume)
	cfg.set_value(SECTION, "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value(SECTION, "invert_look", invert_look)
	return cfg.save(target) == OK


func step_volume(direction: int) -> void:
	var next := clampf(master_volume + VOLUME_STEP * signf(direction), 0.0, 1.0)
	if is_equal_approx(next, master_volume):
		return
	master_volume = next
	changed.emit()


func step_ambient(direction: int) -> void:
	var next := clampf(ambient_volume + VOLUME_STEP * signf(direction), 0.0, 1.0)
	if is_equal_approx(next, ambient_volume):
		return
	ambient_volume = next
	changed.emit()


func step_effects(direction: int) -> void:
	var next := clampf(effects_volume + VOLUME_STEP * signf(direction), 0.0, 1.0)
	if is_equal_approx(next, effects_volume):
		return
	effects_volume = next
	changed.emit()


func step_sensitivity(direction: int) -> void:
	var next := clampf(mouse_sensitivity + SENSITIVITY_STEP * signf(direction),
		SENSITIVITY_MIN, SENSITIVITY_MAX)
	if is_equal_approx(next, mouse_sensitivity):
		return
	mouse_sensitivity = next
	changed.emit()


func toggle_invert() -> void:
	invert_look = not invert_look
	changed.emit()


## Push the volume to the Master bus. Zero mutes rather than setting -inf dB, because
## -inf is a value the bus accepts and then behaves strangely with.
##
## AudioSafety (game/systems/audio_safety.gd) mutes Master for automated runs, using two
## conditions: DisplayServer.get_name() == "headless", OR any command-line user arg
## begins with "--screenshot" (an offscreen/windowed capture run). This method mirrors
## both of those same conditions before unmuting, so a gate that opens the pause menu
## during one of those runs cannot undo AudioSafety's mute.
func apply_audio() -> void:
	_apply_bus("Ambient", ambient_volume)
	_apply_bus("Effects", effects_volume)
	# The UI bus deliberately rides the effects slider; see the field comment.
	_apply_bus("UI", effects_volume)
	var master := AudioServer.get_bus_index("Master")
	if master < 0:
		return
	if master_volume <= 0.0:
		AudioServer.set_bus_mute(master, true)
		return
	AudioServer.set_bus_volume_db(master, linear_to_db(master_volume))
	var automated := DisplayServer.get_name() == "headless"
	if not automated:
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--screenshot"):
				automated = true
				break
	if not automated:
		AudioServer.set_bus_mute(master, false)


## One sub bus, same "zero mutes rather than -inf dB" rule Master gets. Silent about a bus
## that is not in the layout, so a settings object built in a test with no bus layout
## loaded is still usable.
func _apply_bus(name: String, level: float) -> void:
	var index := AudioServer.get_bus_index(name)
	if index < 0:
		return
	if level <= 0.0:
		AudioServer.set_bus_mute(index, true)
		return
	AudioServer.set_bus_mute(index, false)
	AudioServer.set_bus_volume_db(index, linear_to_db(level))
