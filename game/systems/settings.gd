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

## The sub mixes, one per bus (Ambient, Effects, UI, Music, Voice). v1 gives the UI bus its
## own slider after all: the owner turns menu clicks down without turning the world down.
var ambient_volume := AMBIENT_DEFAULT
var effects_volume := 1.0
var ui_volume := 0.8
var music_volume := 0.8
var voice_volume := 1.0

## GRAPHICS. A preset (0 low, 1 medium, 2 high) sets render scale, anti-aliasing, SSAO,
## glow and shadow resolution together; fullscreen and vsync are their own switches.
enum Quality { LOW, MEDIUM, HIGH }
const QUALITY_NAMES: Array[String] = ["Low", "Medium", "High"]
var quality: int = Quality.HIGH
var fullscreen := false
var vsync := true

## KEY BINDINGS: action -> physical keycode, for the actions a player may rebind. An action
## missing here keeps project.godot's key. Gamepad buttons are never touched.
const REBINDABLE: Array[StringName] = [&"move_forward", &"move_back", &"move_left",
	&"move_right", &"jump", &"sneak", &"interact", &"pause", &"toggle_hints"]
const ACTION_NAMES := {&"move_forward": "Walk forward", &"move_back": "Walk back",
	&"move_left": "Walk left", &"move_right": "Walk right", &"jump": "Jump",
	&"sneak": "Sneak", &"interact": "Interact", &"pause": "Pause", &"toggle_hints": "Controls card"}
var bindings: Dictionary = {}
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
	ui_volume = clampf(float(cfg.get_value(SECTION, "ui_volume", ui_volume)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value(SECTION, "music_volume", music_volume)), 0.0, 1.0)
	voice_volume = clampf(float(cfg.get_value(SECTION, "voice_volume", voice_volume)), 0.0, 1.0)
	quality = clampi(int(cfg.get_value(SECTION, "quality", quality)), 0, Quality.HIGH)
	fullscreen = bool(cfg.get_value(SECTION, "fullscreen", fullscreen))
	vsync = bool(cfg.get_value(SECTION, "vsync", vsync))
	var b: Variant = cfg.get_value(SECTION, "bindings", {})
	bindings = {}
	if b is Dictionary:
		for k in (b as Dictionary):
			if StringName(k) in REBINDABLE:
				bindings[StringName(k)] = int((b as Dictionary)[k])
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
	cfg.set_value(SECTION, "ui_volume", ui_volume)
	cfg.set_value(SECTION, "music_volume", music_volume)
	cfg.set_value(SECTION, "voice_volume", voice_volume)
	cfg.set_value(SECTION, "quality", quality)
	cfg.set_value(SECTION, "fullscreen", fullscreen)
	cfg.set_value(SECTION, "vsync", vsync)
	var b := {}
	for k in bindings:
		b[String(k)] = int(bindings[k])
	cfg.set_value(SECTION, "bindings", b)
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


## One step on any 0..1 volume field (ui_volume, music_volume, voice_volume, ...).
func step_level(field: StringName, direction: int) -> bool:
	var now: float = float(get(field))
	var next := clampf(now + VOLUME_STEP * signf(direction), 0.0, 1.0)
	if is_equal_approx(next, now):
		return false
	set(field, next)
	changed.emit()
	return true


func step_quality(direction: int) -> bool:
	var next := clampi(quality + signi(direction), 0, Quality.HIGH)
	if next == quality:
		return false
	quality = next
	changed.emit()
	return true


func toggle_fullscreen() -> void:
	fullscreen = not fullscreen
	changed.emit()


func toggle_vsync() -> void:
	vsync = not vsync
	changed.emit()


## Bind `action` to `keycode` (physical). A key already bound to another rebindable action
## is taken from it (that action falls back to its project default), so no key does two.
func bind(action: StringName, keycode: int) -> void:
	if not (action in REBINDABLE):
		return
	for other in bindings.keys():
		if other != action and int(bindings[other]) == keycode:
			bindings.erase(other)
	bindings[action] = keycode
	changed.emit()


## The key `action` answers to now (its binding, else the project's first key), or 0.
static func key_of(action: StringName, binds: Dictionary) -> int:
	if binds.has(action):
		return int(binds[action])
	if not InputMap.has_action(action):
		return 0
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			var k := e as InputEventKey
			return int(k.physical_keycode) if k.physical_keycode != 0 else int(k.keycode)
	return 0


static func key_label(keycode: int) -> String:
	if keycode == 0:
		return "-"
	return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(keycode as Key)) \
		if DisplayServer.get_name() != "headless" else OS.get_keycode_string(keycode as Key)


## Put the bindings into the InputMap: each rebound action's keyboard events are replaced by
## its one key; mouse and gamepad events stay.
func apply_bindings() -> void:
	for action in bindings:
		if not InputMap.has_action(action):
			continue
		for e in InputMap.action_get_events(action):
			if e is InputEventKey:
				InputMap.action_erase_event(action, e)
		var ev := InputEventKey.new()
		ev.physical_keycode = int(bindings[action]) as Key
		InputMap.action_add_event(action, ev)


## The graphics preset, the window and vsync, on `viewport` and the scene's environment.
func apply_graphics(viewport: Viewport) -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)
	if viewport == null:
		return
	viewport.scaling_3d_scale = [0.67, 0.85, 1.0][quality]
	viewport.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][quality]
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if quality == Quality.LOW else Viewport.SCREEN_SPACE_AA_DISABLED
	RenderingServer.directional_shadow_atlas_set_size([1024, 2048, 4096][quality], true)
	var tree := viewport.get_tree()
	var scene := tree.current_scene if tree != null else null
	if scene != null:
		for we in scene.find_children("*", "WorldEnvironment", true, false):
			var env := (we as WorldEnvironment).environment
			if env != null:
				env.ssao_enabled = quality >= Quality.MEDIUM
				env.glow_enabled = quality >= Quality.MEDIUM
				env.sdfgi_enabled = false


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
	_apply_bus("UI", ui_volume)
	_apply_bus("Music", music_volume)
	_apply_bus("Voice", voice_volume)
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
