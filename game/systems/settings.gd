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
var vsync := true

## THE WINDOW. Windowed at `resolution`, borderless fullscreen at the desktop's own size, or
## exclusive fullscreen (the monitor switched to the game, lowest latency, slowest alt-tab).
## Both of these are DISPLAY settings: the settings menu applies them on a timer and changes
## them back if nobody says keep (game/ui/settings_menu.gd).
enum WindowMode { WINDOWED, FULLSCREEN, EXCLUSIVE }
const WINDOW_MODE_NAMES: Array[String] = ["Windowed", "Fullscreen", "Exclusive fullscreen"]
var window_mode: int = WindowMode.WINDOWED

## The windowed size. Ignored in either fullscreen, which is the desktop's size. ZERO, the
## default, means "whatever size the window opened at" (project.godot's 1600x900, or a
## --resolution on the command line): nothing is resized until somebody picks a size.
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1366, 768),
	Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]
const RESOLUTION_DEFAULT := Vector2i.ZERO
var resolution := RESOLUTION_DEFAULT

## The old switch, kept as a view of window_mode so a settings.cfg written before window_mode
## existed, and every caller that still says fullscreen, mean the same thing.
var fullscreen: bool:
	get:
		return window_mode != WindowMode.WINDOWED
	set(value):
		window_mode = WindowMode.FULLSCREEN if value else WindowMode.WINDOWED

## The camera's vertical field of view, in degrees. 75 is camera_rig.tscn's own.
## 60, NOT 75 (PT7; playtest 2026-11-05: "this looks like shit", houses and lamp posts leaning
## out at the edges). 75 degrees tall is about 106 across at 16:9, and a third person camera
## looking down at that width splays every upright in the town. A save holding the old
## default is moved to the new one once (FOV_MIGRATED); a value she chose herself is kept.
const FOV_DEFAULT := 60.0
const FOV_OLD_DEFAULT := 75.0
const FOV_MIN := 50.0
const FOV_MAX := 100.0
const FOV_STEP := 5.0
var fov := FOV_DEFAULT

## A frame rate cap; 0 is none. Engine.max_fps.
const FPS_CAPS: Array[int] = [0, 30, 60, 120, 144]
var max_fps := 0

## The right stick's turn speed, radians per second at full tilt (camera_rig.gd's own 2.2).
const STICK_DEFAULT := 2.2
const STICK_MIN := 1.0
const STICK_MAX := 4.0
const STICK_STEP := 0.2
var stick_sensitivity := STICK_DEFAULT

## GAMEPLAY. Each is read by something real: the HUD's corner "H controls" chip, the HUD's
## Getting started list, and the ranch opening the pause menu when the window loses focus.
var show_controls_chip := true
var show_checklist := true
## The guide's trail of motes and the lit compass icon (game/systems/guide.gd).
var show_guide := true
## TEXT SIZE (FS8.2): percent, one of TEXT_SIZES.
var text_size := 100
## The camera's kick on a catch and other big moments (game/actors/player/camera_rig.gd).
var camera_shake := true
var pause_on_focus_loss := true
## The cartoon babble under every talk line. OFF by default since the owner's 2026-10-25
## playtest ("the animal crossing style talking is super annoying and obnoxious"); the
## mouths still move with the words either way.
var pony_chatter := false

## Every field the settings menu edits, in one list, so a draft can be copied and compared
## without each caller naming them all. `fullscreen` is not here: it is a view of window_mode.
const FIELDS: Array[StringName] = [&"master_volume", &"music_volume", &"ambient_volume",
	&"effects_volume", &"ui_volume", &"voice_volume", &"quality", &"vsync", &"window_mode",
	&"resolution", &"fov", &"max_fps", &"mouse_sensitivity", &"stick_sensitivity",
	&"invert_look", &"bindings", &"pad_bindings", &"show_controls_chip", &"show_checklist", &"pause_on_focus_loss",
	&"pony_chatter", &"show_guide", &"camera_shake", &"text_size"]
const TEXT_SIZES: Array[int] = [100, 125, 150]

## The two that change the window itself, and so get the timed confirmation.
const DISPLAY_FIELDS: Array[StringName] = [&"window_mode", &"resolution"]

## KEY BINDINGS: action -> physical keycode, for the actions a player may rebind. An action
## missing here keeps project.godot's key. PAD BINDINGS (FS8.1): action -> joypad button, by
## the same rules, for the actions the project gives a button (pad_rebindable); the sticks and
## triggers stay as authored.
const REBINDABLE: Array[StringName] = [&"move_forward", &"move_back", &"move_left",
	&"move_right", &"jump", &"sneak", &"gallop", &"interact", &"treat", &"whistle", &"pause",
	&"toggle_hints"]
const ACTION_NAMES := {&"move_forward": "Walk forward", &"move_back": "Walk back",
	&"move_left": "Walk left", &"move_right": "Walk right", &"jump": "Jump",
	&"sneak": "Sneak", &"gallop": "Gallop", &"interact": "Interact", &"treat": "Toss a treat",
	&"whistle": "Whistle", &"pause": "Pause", &"toggle_hints": "Controls card"}
var bindings: Dictionary = {}
var pad_bindings: Dictionary = {}
## Buttons never bound: B backs out of every menu, Guide belongs to the system, and the
## D-pad's up and down are the camera's zoom.
## Actions that share another's pad button and follow it when it is rebound: on a pad, L3 is
## both the run (sprint) and the Gallop Shoes' burst (gallop), and the Controls menu shows the
## one row (review 2026-11-06: rebinding Gallop left L3 still sprinting).
const PAD_SHADOWS := {&"sprint": &"gallop"}
const PAD_RESERVED: Array[int] = [JOY_BUTTON_B, JOY_BUTTON_GUIDE, JOY_BUTTON_DPAD_UP,
	JOY_BUTTON_DPAD_DOWN]
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
	window_mode = clampi(int(cfg.get_value(SECTION, "window_mode", window_mode)), 0, WindowMode.EXCLUSIVE)
	vsync = bool(cfg.get_value(SECTION, "vsync", vsync))
	var res: Variant = cfg.get_value(SECTION, "resolution", resolution)
	if res is Vector2i and ((res as Vector2i) == Vector2i.ZERO
			or ((res as Vector2i).x >= 640 and (res as Vector2i).y >= 360)):
		resolution = res
	fov = clampf(float(cfg.get_value(SECTION, "fov", fov)), FOV_MIN, FOV_MAX)
	if not bool(cfg.get_value(SECTION, "fov_migrated", false)) and is_equal_approx(fov, FOV_OLD_DEFAULT):
		fov = FOV_DEFAULT
	var cap := int(cfg.get_value(SECTION, "max_fps", max_fps))
	max_fps = cap if cap in FPS_CAPS else 0
	stick_sensitivity = clampf(float(cfg.get_value(SECTION, "stick_sensitivity", stick_sensitivity)),
		STICK_MIN, STICK_MAX)
	show_controls_chip = bool(cfg.get_value(SECTION, "show_controls_chip", show_controls_chip))
	show_checklist = bool(cfg.get_value(SECTION, "show_checklist", show_checklist))
	show_guide = bool(cfg.get_value(SECTION, "show_guide", show_guide))
	text_size = int(cfg.get_value(SECTION, "text_size", text_size))
	if not text_size in TEXT_SIZES:
		text_size = 100
	camera_shake = bool(cfg.get_value(SECTION, "camera_shake", camera_shake))
	pony_chatter = bool(cfg.get_value(SECTION, "pony_chatter", pony_chatter))
	pause_on_focus_loss = bool(cfg.get_value(SECTION, "pause_on_focus_loss", pause_on_focus_loss))
	var b: Variant = cfg.get_value(SECTION, "bindings", {})
	bindings = {}
	if b is Dictionary:
		for k in (b as Dictionary):
			var code := int((b as Dictionary)[k]) if (b as Dictionary)[k] is int or (b as Dictionary)[k] is float else 0
			if StringName(k) in REBINDABLE and code > 0 and code != KEY_ESCAPE:
				bindings[StringName(k)] = code
	var pb: Variant = cfg.get_value(SECTION, "pad_bindings", {})
	pad_bindings = {}
	if pb is Dictionary:
		for k in (pb as Dictionary):
			var v: Variant = (pb as Dictionary)[k]
			var button := int(v) if v is int or v is float else -1
			if pad_rebindable(StringName(k)) and _pad_bindable(button):
				pad_bindings[StringName(k)] = button
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
	cfg.set_value(SECTION, "window_mode", window_mode)
	cfg.set_value(SECTION, "resolution", resolution)
	cfg.set_value(SECTION, "fov", fov)
	cfg.set_value(SECTION, "fov_migrated", true)
	cfg.set_value(SECTION, "max_fps", max_fps)
	cfg.set_value(SECTION, "stick_sensitivity", stick_sensitivity)
	cfg.set_value(SECTION, "show_controls_chip", show_controls_chip)
	cfg.set_value(SECTION, "show_checklist", show_checklist)
	cfg.set_value(SECTION, "show_guide", show_guide)
	cfg.set_value(SECTION, "text_size", text_size)
	cfg.set_value(SECTION, "camera_shake", camera_shake)
	cfg.set_value(SECTION, "pony_chatter", pony_chatter)
	cfg.set_value(SECTION, "pause_on_focus_loss", pause_on_focus_loss)
	var b := {}
	for k in bindings:
		b[String(k)] = int(bindings[k])
	cfg.set_value(SECTION, "bindings", b)
	var pb := {}
	for k in pad_bindings:
		pb[String(k)] = int(pad_bindings[k])
	cfg.set_value(SECTION, "pad_bindings", pb)
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


## Take every FIELDS value from `other` (the settings menu's draft and its snapshot).
func copy_from(other: Settings) -> void:
	for f in FIELDS:
		var v: Variant = other.get(f)
		set(f, v.duplicate() if v is Dictionary else v)
	changed.emit()


func duplicate_settings() -> Settings:
	var out: Settings = (get_script() as Script).new()
	out.copy_from(self)
	return out


## The FIELDS that differ from `other`, in FIELDS order.
func differences(other: Settings) -> Array[StringName]:
	var out: Array[StringName] = []
	for f in FIELDS:
		var a: Variant = get(f)
		var b: Variant = other.get(f)
		if a is float or b is float:
			if not is_equal_approx(float(a), float(b)):
				out.append(f)
		elif a != b:
			out.append(f)
	return out


func toggle_fullscreen() -> void:
	fullscreen = not fullscreen
	changed.emit()


func toggle_vsync() -> void:
	vsync = not vsync
	changed.emit()


## Bind `action` to `keycode` (physical). A key already bound to another rebindable action
## is taken from it (that action falls back to its project default), so no key does two.
## The action that last gave its key up to a bind() (it took the old key), or &"".
var last_swapped: StringName = &""


func bind(action: StringName, keycode: int) -> void:
	last_swapped = &""
	if not (action in REBINDABLE) or keycode <= 0:
		return
	# A key does one thing: whichever action answered to it (bound, or by the project's
	# default) takes this action's old key instead, so nothing is left doubled or keyless.
	var old := key_of(action, bindings)
	for other in REBINDABLE:
		if other != action and key_of(other, bindings) == keycode:
			bindings[other] = old
			last_swapped = other
	bindings[action] = keycode
	changed.emit()


## The same for a pad button: whichever action answered to `button` takes this one's old one.
func pad_bind(action: StringName, button: int) -> void:
	last_swapped = &""
	if not pad_rebindable(action) or not _pad_bindable(button):
		return
	var old := pad_button_of(action, pad_bindings)
	for other in REBINDABLE:
		if other != action and pad_rebindable(other) and pad_button_of(other, pad_bindings) == button:
			pad_bindings[other] = old
			last_swapped = other
	pad_bindings[action] = button
	changed.emit()


## Back to the project's own key and button for `action`.
func unbind(action: StringName) -> void:
	var a := bindings.erase(action)
	var b := pad_bindings.erase(action)
	if a or b:
		changed.emit()


## True when the project gives `action` a pad button (the sticks are not rebound).
static func pad_rebindable(action: StringName) -> bool:
	return action in REBINDABLE and pad_button_of(action, {}) >= 0


static func _pad_bindable(button: int) -> bool:
	return button >= 0 and button < JOY_BUTTON_SDL_MAX and not button in PAD_RESERVED


## The button `action` answers to now (its binding, else the project's first), or -1.
static func pad_button_of(action: StringName, binds: Dictionary) -> int:
	if binds.has(action):
		return int(binds[action])
	for e in default_events(action):
		if e is InputEventJoypadButton:
			return int((e as InputEventJoypadButton).button_index)
	return -1


## The key `action` answers to now (its binding, else the project's first key), or 0.
static func key_of(action: StringName, binds: Dictionary) -> int:
	if binds.has(action):
		return int(binds[action])
	for e in default_events(action):
		if e is InputEventKey:
			var k := e as InputEventKey
			return int(k.physical_keycode) if k.physical_keycode != 0 else int(k.keycode)
	return 0


## The project's own events for `action` (project.godot), whatever the InputMap holds now.
static func default_events(action: StringName) -> Array:
	var d: Variant = ProjectSettings.get_setting("input/" + String(action), null)
	if d is Dictionary:
		return (d as Dictionary).get("events", [])
	return []


static func key_label(keycode: int) -> String:
	if keycode == 0:
		return "-"
	return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(keycode as Key)) \
		if DisplayServer.get_name() != "headless" else OS.get_keycode_string(keycode as Key)


## Put the bindings into the InputMap. Every rebindable action is rebuilt from the
## project's own events first, so an action whose key or button was taken, or that went back
## to its default, never keeps one it no longer has; mouse and stick events stay as authored.
func apply_bindings() -> void:
	for shadow: StringName in PAD_SHADOWS:
		if not InputMap.has_action(shadow):
			continue
		for e in InputMap.action_get_events(shadow):
			if e is InputEventJoypadButton:
				InputMap.action_erase_event(shadow, e)
		var pe := InputEventJoypadButton.new()
		pe.button_index = pad_button_of(PAD_SHADOWS[shadow], pad_bindings) as JoyButton
		pe.device = -1
		InputMap.action_add_event(shadow, pe)
	for action in REBINDABLE:
		if not InputMap.has_action(action):
			continue
		for e in InputMap.action_get_events(action):
			if e is InputEventKey or e is InputEventJoypadButton:
				InputMap.action_erase_event(action, e)
		if pad_bindings.has(action):
			var pe := InputEventJoypadButton.new()
			pe.button_index = int(pad_bindings[action]) as JoyButton
			pe.device = -1
			InputMap.action_add_event(action, pe)
		else:
			for e in default_events(action):
				if e is InputEventJoypadButton:
					InputMap.action_add_event(action, e)
		if bindings.has(action):
			var ev := InputEventKey.new()
			ev.physical_keycode = int(bindings[action]) as Key
			InputMap.action_add_event(action, ev)
			continue
		for e in default_events(action):
			if e is InputEventKey:
				InputMap.action_add_event(action, e)


## The graphics preset, the window and vsync, on `viewport` and the scene's environment.
## `with_window` false leaves the OS window alone (PT11; playtest 2026-11-05: fullscreen chosen
## during the load "went small when it loaded in"). The ranch applies the rest of the
## graphics on load, but the window is set at boot and by the Settings menu, never by a scene
## arriving.
func apply_graphics(viewport: Viewport, with_window := true) -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = max_fps
	if with_window:
		apply_window()
	if viewport == null:
		return
	viewport.scaling_3d_scale = [0.67, 0.85, 1.0][quality]
	viewport.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][quality]
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if quality == Quality.LOW else Viewport.SCREEN_SPACE_AA_DISABLED
	# P9 item 57: High is the project's own 8192 (P8 S4 chose it for clean hard edges); this
	# preset used to cut it to 4096, which doubled every stair on a shadow's edge at 1440p.
	RenderingServer.directional_shadow_atlas_set_size([2048, 4096, 8192][quality], true)
	# P9 item 57, round 4: the stair left on a long grazing edge (3-4 px at 1440p at dusk) is
	# the sun's texel stretched by its low angle, so no map size or split removes it (40 m and
	# tighter splits were measured: no better). High filters the sun's edge instead, at the
	# HIGH soft quality: its many samples average out, so with the toon step's 0.3 window
	# the edge comes out a clean 2 px ramp, not the salt-and-pepper the VERY LOW filter gave
	# in P8 S4 (project.godot keeps 0 for Low and Medium). The ranch's sun sets the radius
	# (shadow_blur); a light that keeps blur 0 stays hard.
	RenderingServer.directional_soft_shadow_filter_set_quality(
		[RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_HARD,
		RenderingServer.SHADOW_QUALITY_SOFT_HIGH][quality])
	var tree := viewport.get_tree()
	var scene := tree.current_scene if tree != null else null
	if scene != null:
		for we in scene.find_children("*", "WorldEnvironment", true, false):
			var env := (we as WorldEnvironment).environment
			if env != null:
				# The scene's own look is the ceiling: a preset can switch an effect off, never
				# on where the scene was authored without it.
				if not env.has_meta(&"authored_ssao"):
					env.set_meta(&"authored_ssao", env.ssao_enabled)
					env.set_meta(&"authored_glow", env.glow_enabled)
				env.ssao_enabled = bool(env.get_meta(&"authored_ssao")) and quality >= Quality.MEDIUM
				env.glow_enabled = bool(env.get_meta(&"authored_glow")) and quality >= Quality.MEDIUM


## The window mode and, windowed, the window's size, centred on its screen.
func apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var want: int = [DisplayServer.WINDOW_MODE_WINDOWED, DisplayServer.WINDOW_MODE_FULLSCREEN,
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN][window_mode]
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)
	if window_mode == WindowMode.WINDOWED and resolution != Vector2i.ZERO \
			and DisplayServer.window_get_size() != resolution:
		DisplayServer.window_set_size(resolution)
		var screen := DisplayServer.window_get_current_screen()
		var area := DisplayServer.screen_get_usable_rect(screen)
		DisplayServer.window_set_position(area.position + ((area.size - resolution) / 2).max(Vector2i.ZERO))


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
## Every label the menus style from now on, at the player's text size (MenuStyle.text_scale).
func apply_text() -> void:
	MenuStyle.text_scale = float(text_size) / 100.0


func apply_audio() -> void:
	_apply_bus("Ambient", ambient_volume)
	_apply_bus("Effects", effects_volume)
	_apply_bus("UI", ui_volume)
	_apply_bus("Music", music_volume)
	_apply_bus("Voice", voice_volume)
	Babble.audible = pony_chatter
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
