class_name SettingsMenu
extends Control
## THE ONE SETTINGS MENU, AND BOTH DOORS OPEN IT. The title screen's Settings row and the
## pause menu's Settings row each instance game/ui/settings_menu.tscn over themselves and
## call open(settings). Before this there were two hand-drawn row lists with two different
## sets of rows (five on the title, twenty three on the pause menu) and neither had tabs.
##
## THE PLAYTEST NOTE IT ANSWERS: "Settings UI is awful and hard to navigate." What made it so
## is in docs/playtest_fixes/settings.md; what this is instead:
##
##   * FOUR TABS: Graphics, Audio, Controls, Gameplay. Q/E or LB/RB switch from anywhere;
##     Left/Right on the tab strip switch too; a click on a tab switches.
##   * EVERY ROW IS A REAL FOCUSABLE CONTROL with a gold focus ring, so the keyboard (arrows,
##     Tab, Enter, Esc), a controller (d-pad or stick, A, B) and the mouse (hover, click, drag)
##     all move the same one highlight. Left/Right changes the focused row's value.
##   * A DRAFT. Every change lands on a copy of the settings; Apply commits it (and writes
##     settings.cfg), Revert throws it away. Volumes are heard live while you drag them.
##   * A DISPLAY CHANGE IS TRIED, NOT TRUSTED. Window mode or resolution: Apply switches, then
##     asks "Keep these display settings?" for DISPLAY_CONFIRM_SECONDS. No answer and it
##     changes itself back, so a mode the monitor cannot show never strands anybody.
##   * Readable: nothing on it is under 22 px at 1080p (the test asserts it).
##
## It edits a Settings object it is handed and never owns one; the host decides what else
## to push the applied settings into (ranch.gd: the camera, the HUD) on `applied`.

signal applied()
signal closed()

const SettingsScript := preload("res://systems/settings.gd")
const MenuStyleScript := preload("res://ui/menu_style.gd")
const InputDeviceScript := preload("res://systems/input_device.gd")

const TAB_NAMES: Array[String] = ["Graphics", "Audio", "Controls", "Gameplay"]
const DISPLAY_CONFIRM_SECONDS := 10.0

# --- the palette: the Palace's plum and gold, the look the owner liked best -----------------
const PLUM := Color(0.20, 0.08, 0.25, 1.0)
const PLUM_DEEP := Color(0.12, 0.04, 0.16, 1.0)
const PLUM_ROW := Color(0.30, 0.13, 0.36, 0.55)
const PLUM_ROW_HOVER := Color(0.38, 0.17, 0.44, 0.80)
const GOLD := Color(0.98, 0.86, 0.45)
const GOLD_SOFT := Color(0.98, 0.86, 0.45, 0.35)
const CREAM := Color(1.0, 0.96, 0.88)
const CREAM_DIM := Color(1.0, 0.96, 0.88, 0.62)
const INK := Color(0.16, 0.06, 0.18)

# --- sizes, in 1920x1080 units -------------------------------------------------------------
const PANEL_SIZE := Vector2(1380, 930)
const TITLE_PX := 46
const TAB_PX := 28
const ROW_PX := 27
const VALUE_PX := 26
const BODY_PX := 23
const SMALL_PX := 22
const ROW_HEIGHT := 76.0
const WIDGET_WIDTH := 400.0

enum Kind { CHOICE, SLIDER, TOGGLE, KEY, INFO }

var settings: Settings = null
var draft: Settings = null

var _open := false
var _tab := 0
var _tab_buttons: Array[Button] = []
var _pages: Array[VBoxContainer] = []
var _rows: Dictionary = {}  # key -> Row
var _scroll: ScrollContainer
var _info_title: Label
var _info_body: Label
var _info_icon: TabIcon
var _info_changed: Label
var _info_default: Label
var _info_how: HBoxContainer
var _defaults: Settings = null
var _bar_buttons: Array[Button] = []
var _apply_button: Button
var _revert_button: Button
var _back_button: Button
var _hint_box: HBoxContainer
var _hint_pad := false
var _pending_label: Label

# The modal: one card, reused for the display confirmation and the unapplied-changes ask.
var _modal: Control
var _modal_title: Label
var _modal_body: Label
var _modal_buttons: HBoxContainer
var _modal_timer: TimerBar
var _modal_kind := &""
var _confirm_left := 0.0
var _display_before := {}

var _capturing: StringName = &""
var _font: FontVariation


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_font = FontVariation.new()
	_font.base_font = MenuStyleScript.title_font().base_font
	_font.variation_opentype = {2003265652: 520}
	var t := Theme.new()
	t.default_font = _font
	t.default_font_size = BODY_PX
	theme = t
	_build()
	set_process(false)


# --- the public surface ---------------------------------------------------------------------

func open(with: Settings) -> void:
	settings = with
	if settings == null:
		settings = SettingsScript.new()
	draft = settings.duplicate_settings()
	_capturing = &""
	_open = true
	visible = true
	set_process(true)
	_close_modal()
	_refresh_all()
	_show_tab(0, false)
	_tab_buttons[0].grab_focus.call_deferred()
	MenuStyleScript.tick_open()


func is_open() -> bool:
	return _open


func current_tab() -> int:
	return _tab


func row_for(key: StringName) -> Control:
	return _rows.get(key)


func confirm_open() -> bool:
	return _modal != null and _modal.visible and _modal_kind == &"display"


func confirm_seconds_left() -> float:
	return _confirm_left if confirm_open() else 0.0


func is_dirty() -> bool:
	return draft != null and settings != null and not draft.differences(settings).is_empty()


## Back, Esc or B: leave, asking first if there is anything not applied.
func request_close() -> void:
	if _modal.visible:
		return
	if is_dirty():
		_open_modal(&"unsaved", "Apply your changes?",
			"Some settings were changed but not applied yet.",
			[["Apply", _modal_apply_and_close], ["Discard", _modal_discard_and_close],
				["Keep editing", _close_modal]])
		return
	_finish_close()


func apply() -> void:
	if draft == null:
		return
	var diffs := draft.differences(settings)
	if diffs.is_empty():
		MenuStyleScript.tick_denied()
		return
	var display := false
	for f in SettingsScript.DISPLAY_FIELDS:
		display = display or f in diffs
	_display_before = {&"window_mode": settings.window_mode, &"resolution": settings.resolution,
		&"size": _effective_resolution(settings)}
	settings.copy_from(draft)
	settings.apply_audio()
	settings.apply_graphics(get_viewport())
	settings.apply_bindings()
	MenuStyleScript.tick_confirm()
	if display:
		# Written with the OLD display values until she says keep: a crash or a power cut
		# while the monitor is black must not boot into the same black.
		_save_with_display(_display_before)
		_confirm_left = DISPLAY_CONFIRM_SECONDS
		_open_modal(&"display", "Keep these display settings?",
			("Windowed, %s." % _resolution_text(settings)) \
				if settings.window_mode == SettingsScript.WindowMode.WINDOWED \
				else "%s, at your desktop's own size." % SettingsScript.WINDOW_MODE_NAMES[settings.window_mode],
			[["Keep it", _keep_display], ["Change back", _revert_display]])
	else:
		settings.save_to()
		applied.emit()
	_refresh_all()


func revert() -> void:
	if draft == null:
		return
	if not is_dirty():
		MenuStyleScript.tick_denied()
		return
	draft.copy_from(settings)
	settings.apply_audio()
	_capturing = &""
	MenuStyleScript.tick_back()
	_refresh_all()


# --- input -----------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not _open:
		return
	if _capturing != &"":
		_capture_input(event)
		get_viewport().set_input_as_handled()
		return
	if _modal.visible:
		if event.is_action_pressed(&"ui_cancel"):
			_modal_cancel()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed(&"ui_focus_next") or event.is_action_pressed(&"ui_focus_prev"):
			_cycle_modal_focus(-1 if event.is_action_pressed(&"ui_focus_prev") else 1)
			get_viewport().set_input_as_handled()
		return
	var step := _tab_step(event)
	if step != 0:
		_switch_tab(posmod(_tab + step, TAB_NAMES.size()))
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_cancel"):
		MenuStyleScript.tick_back()
		request_close()
		get_viewport().set_input_as_handled()


## Q/E on the keyboard, LB/RB on a pad: the tab to the left or right, from anywhere.
func _tab_step(event: InputEvent) -> int:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo:
		var code := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		if code == KEY_Q:
			return -1
		if code == KEY_E:
			return 1
	var b := event as InputEventJoypadButton
	if b != null and b.pressed:
		if b.button_index == JOY_BUTTON_LEFT_SHOULDER:
			return -1
		if b.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			return 1
	return 0


func _process(delta: float) -> void:
	if confirm_open():
		_confirm_left -= delta
		_modal_timer.fraction = clampf(_confirm_left / DISPLAY_CONFIRM_SECONDS, 0.0, 1.0)
		_modal_timer.seconds = ceili(maxf(_confirm_left, 0.0))
		_modal_timer.queue_redraw()
		if _confirm_left <= 0.0:
			_revert_display()
	var pad := InputDeviceScript.using_gamepad()
	if pad != _hint_pad:
		_hint_pad = pad
		_build_hints()


# --- tabs ---------------------------------------------------------------------------------

func _switch_tab(i: int) -> void:
	_show_tab(i, true)
	_tab_buttons[i].grab_focus()


func _show_tab(i: int, tick: bool) -> void:
	var changed := i != _tab
	_tab = i
	for j in _pages.size():
		_pages[j].visible = j == i
	for j in _tab_buttons.size():
		_style_tab(_tab_buttons[j], j == i)
	_scroll.scroll_vertical = 0
	_wire_focus()
	_show_info_for_tab()
	if tick and changed:
		MenuStyleScript.tick_page()


func _page_rows(i: int) -> Array[Row]:
	var out: Array[Row] = []
	for c in _pages[i].get_children():
		if c is Row:
			out.append(c)
	return out


## THE FOCUS MAP, explicit rather than guessed from geometry: tab strip -> first row; rows in
## a column; last row -> Apply; the button bar along the bottom.
func _wire_focus() -> void:
	var rows := _page_rows(_tab)
	var tab_button := _tab_buttons[_tab]
	for j in _tab_buttons.size():
		var b := _tab_buttons[j]
		b.focus_neighbor_left = _tab_buttons[posmod(j - 1, _tab_buttons.size())].get_path()
		b.focus_neighbor_right = _tab_buttons[posmod(j + 1, _tab_buttons.size())].get_path()
		b.focus_neighbor_bottom = rows[0].get_path() if not rows.is_empty() else _apply_button.get_path()
		b.focus_neighbor_top = b.get_path()
	for r in rows.size():
		var row := rows[r]
		row.focus_neighbor_top = (rows[r - 1] if r > 0 else tab_button).get_path()
		row.focus_neighbor_bottom = (rows[r + 1] if r < rows.size() - 1 else _apply_button).get_path()
		row.focus_neighbor_left = row.get_path()
		row.focus_neighbor_right = row.get_path()
	for j in _bar_buttons.size():
		var b := _bar_buttons[j]
		b.focus_neighbor_top = (rows[-1] if not rows.is_empty() else tab_button).get_path()
		b.focus_neighbor_bottom = b.get_path()
		b.focus_neighbor_left = _bar_buttons[maxi(j - 1, 0)].get_path()
		b.focus_neighbor_right = _bar_buttons[mini(j + 1, _bar_buttons.size() - 1)].get_path()


# --- the rows: what each one is, says and does ----------------------------------------------

## [key, label, kind, description] per tab.
func _specs() -> Array:
	var out := [
		[
			[&"window_mode", "Window mode", Kind.CHOICE,
				"Windowed, borderless fullscreen, or exclusive fullscreen. A change is tried first and changes itself back unless you keep it."],
			[&"resolution", "Resolution", Kind.CHOICE,
				"The size of the window when it is windowed. In fullscreen the game uses your desktop's own size."],
			[&"vsync", "VSync", Kind.TOGGLE,
				"Waits for the monitor between frames. Stops tearing; off can feel a touch quicker."],
			[&"quality", "Quality", Kind.CHOICE,
				"Render scale, anti-aliasing, ambient occlusion, glow and shadow detail together. Low runs on modest laptops."],
			[&"fov", "Field of view", Kind.SLIDER,
				"How wide the camera sees. Wider shows more of the ranch; narrower feels closer to her."],
			[&"max_fps", "Frame rate cap", Kind.CHOICE,
				"Holds the frame rate down to save power and heat. Off lets it run free."],
		],
		[
			[&"master_volume", "Master", Kind.SLIDER, "Everything at once."],
			[&"music_volume", "Music", Kind.SLIDER, "The score and the songs."],
			[&"ambient_volume", "Ambience", Kind.SLIDER, "Wind, birds, the creek, the crowd on the Strip."],
			[&"effects_volume", "Effects", Kind.SLIDER, "Hoofsteps, the beam, the market, the casino tables."],
			[&"ui_volume", "Menus", Kind.SLIDER, "The ticks and chimes of every menu, this one included."],
			[&"voice_volume", "Voices", Kind.SLIDER, "Everypony who talks to you."],
			[&"pony_chatter", "Pony chatter", Kind.TOGGLE,
				"A burble of cartoon syllables under every line a pony says. Off reads in quiet."],
		],
		[
			[&"mouse_sensitivity", "Mouse sensitivity", Kind.SLIDER, "How far the camera turns for each move of the mouse."],
			[&"stick_sensitivity", "Controller look speed", Kind.SLIDER, "How fast the right stick turns the camera."],
			[&"invert_look", "Invert look", Kind.TOGGLE, "Push up to look down, like a flight stick."],
		],
		[
			[&"show_controls_chip", "Controls reminder", Kind.TOGGLE,
				"The small card in the corner that names the key for the full controls list. The key works either way."],
			[&"show_checklist", "Getting started list", Kind.TOGGLE,
				"The first three requests, pinned on screen until they are done."],
			[&"show_guide", "Show the way", Kind.TOGGLE,
				"A trail of sparkles on the ground toward whatever is waiting for you next."],
			[&"camera_shake", "Camera shake", Kind.TOGGLE,
				"The camera's little kick when a pony lands in the Scoop."],
			[&"pause_on_focus_loss", "Pause when you switch away", Kind.TOGGLE,
				"Switch to another window and the ranch waits for you under the pause menu."],
		],
	]
	for action in SettingsScript.REBINDABLE:
		(out[2] as Array).append([StringName("key_" + String(action)),
			String(SettingsScript.ACTION_NAMES.get(action, String(action))), Kind.KEY,
			"Select it, then press the new key. Backspace puts the original key back; Esc leaves it as it is. Controller buttons are fixed."])
	for pair in [[&"beam", "Magic beam"], [&"look", "Look around"], [&"zoom", "Camera distance"]]:
		(out[2] as Array).append([StringName("info_" + String(pair[0])), String(pair[1]), Kind.INFO,
			"Fixed: the mouse and the sticks are not rebound."])
	return out


func _step(key: StringName, dir: int) -> bool:
	var d := draft
	match key:
		&"window_mode":
			return _set_int(&"window_mode", clampi(d.window_mode + dir, 0, SettingsScript.WindowMode.EXCLUSIVE))
		&"resolution":
			if d.window_mode != SettingsScript.WindowMode.WINDOWED:
				return false
			var list := SettingsScript.RESOLUTIONS
			var i := _resolution_index(d)
			var next := clampi(i + dir, 0, list.size() - 1)
			if list[next] == _effective_resolution(d):
				return false
			d.resolution = list[next]
			return true
		&"quality":
			return _set_int(&"quality", clampi(d.quality + dir, 0, SettingsScript.Quality.HIGH))
		&"max_fps":
			var caps := SettingsScript.FPS_CAPS
			var i := maxi(caps.find(d.max_fps), 0)
			return _set_int(&"max_fps", caps[clampi(i + dir, 0, caps.size() - 1)])
		&"fov":
			return _set_float(&"fov", d.fov + SettingsScript.FOV_STEP * dir,
				SettingsScript.FOV_MIN, SettingsScript.FOV_MAX)
		&"mouse_sensitivity":
			return _set_float(&"mouse_sensitivity", d.mouse_sensitivity + SettingsScript.SENSITIVITY_STEP * dir,
				SettingsScript.SENSITIVITY_MIN, SettingsScript.SENSITIVITY_MAX)
		&"stick_sensitivity":
			return _set_float(&"stick_sensitivity", d.stick_sensitivity + SettingsScript.STICK_STEP * dir,
				SettingsScript.STICK_MIN, SettingsScript.STICK_MAX)
		&"vsync", &"invert_look", &"show_controls_chip", &"show_checklist", &"pause_on_focus_loss", \
				&"pony_chatter", &"show_guide", &"camera_shake":
			var want := dir > 0
			if bool(d.get(key)) == want:
				return false
			d.set(key, want)
			return true
	if String(key).ends_with("_volume"):
		return _set_float(key, float(d.get(key)) + SettingsScript.VOLUME_STEP * dir, 0.0, 1.0)
	return false


## Enter, A or a click on the row: a switch flips, a list moves on one (and wraps), a key row
## starts listening.
func _activate(key: StringName) -> void:
	var row: Row = _rows.get(key)
	if row == null:
		return
	match row.kind:
		Kind.TOGGLE:
			_change(key, -1 if bool(draft.get(key)) else 1)
		Kind.CHOICE:
			if not _change(key, 1):
				# At the end of the list: wrap to the start.
				var guard := 0
				while _step(key, -1) and guard < 10:
					guard += 1
				if guard > 0:
					_after_change(key)
		Kind.KEY:
			_capturing = StringName(String(key).trim_prefix("key_"))
			MenuStyleScript.tick_confirm()
			_refresh_all()
		_:
			MenuStyleScript.tick_denied()


func _change(key: StringName, dir: int) -> bool:
	if _step(key, dir):
		_after_change(key)
		return true
	MenuStyleScript.tick_denied()
	return false


func _after_change(key: StringName) -> void:
	MenuStyleScript.tick_move()
	if String(key).ends_with("_volume"):
		# Heard while she drags it; Revert and Discard put the applied levels back.
		draft.apply_audio()
	_refresh_all()


func _set_slider_fraction(key: StringName, f: float) -> void:
	var r := _slider_range(key)
	var v := lerpf(r.x, r.y, clampf(f, 0.0, 1.0))
	v = r.x + roundf((v - r.x) / r.z) * r.z
	if _set_float(key, v, r.x, r.y):
		_after_change(key)


## min, max, step for each slider.
func _slider_range(key: StringName) -> Vector3:
	match key:
		&"fov":
			return Vector3(SettingsScript.FOV_MIN, SettingsScript.FOV_MAX, SettingsScript.FOV_STEP)
		&"mouse_sensitivity":
			return Vector3(SettingsScript.SENSITIVITY_MIN, SettingsScript.SENSITIVITY_MAX, SettingsScript.SENSITIVITY_STEP)
		&"stick_sensitivity":
			return Vector3(SettingsScript.STICK_MIN, SettingsScript.STICK_MAX, SettingsScript.STICK_STEP)
	return Vector3(0.0, 1.0, 0.05)


func _set_int(key: StringName, v: int) -> bool:
	if int(draft.get(key)) == v:
		return false
	draft.set(key, v)
	return true


func _set_float(key: StringName, v: float, lo: float, hi: float) -> bool:
	var c := clampf(v, lo, hi)
	if is_equal_approx(float(draft.get(key)), c):
		return false
	draft.set(key, c)
	return true


func _value_text(s: Settings, key: StringName) -> String:
	match key:
		&"window_mode":
			return SettingsScript.WINDOW_MODE_NAMES[s.window_mode]
		&"resolution":
			return _resolution_text(s)
		&"quality":
			return SettingsScript.QUALITY_NAMES[s.quality]
		&"max_fps":
			return "Off" if s.max_fps == 0 else "%d fps" % s.max_fps
		&"fov":
			return "%d°" % roundi(s.fov)
		&"mouse_sensitivity":
			return "%.1f" % (s.mouse_sensitivity * 1000.0)
		&"stick_sensitivity":
			return "%.1f" % s.stick_sensitivity
	if String(key).ends_with("_volume"):
		return "%d%%" % roundi(float(s.get(key)) * 100.0)
	var v: Variant = s.get(key)
	if v is bool:
		return "On" if v else "Off"
	return str(v)


func _resolution_text(s: Settings) -> String:
	if s.window_mode != SettingsScript.WindowMode.WINDOWED:
		return "Desktop"
	var r := _effective_resolution(s)
	return "%d × %d" % [r.x, r.y]


## The size a ZERO ("as the game opened") resolution actually is right now.
func _effective_resolution(s: Settings) -> Vector2i:
	if s.resolution != Vector2i.ZERO:
		return s.resolution
	if DisplayServer.get_name() == "headless":
		return Vector2i(ProjectSettings.get_setting("display/window/size/window_width_override", 1600),
			ProjectSettings.get_setting("display/window/size/window_height_override", 900))
	return DisplayServer.window_get_size()


func _resolution_index(s: Settings) -> int:
	var list := SettingsScript.RESOLUTIONS
	var res := _effective_resolution(s)
	var i := list.find(res)
	if i >= 0:
		return i
	var best := 0
	for j in list.size():
		if absi(list[j].x - res.x) < absi(list[best].x - res.x):
			best = j
	return best


func _fraction(key: StringName) -> float:
	var r := _slider_range(key)
	return clampf((float(draft.get(key)) - r.x) / (r.y - r.x), 0.0, 1.0)


func _choice_pips(key: StringName) -> Vector2i:
	match key:
		&"window_mode":
			return Vector2i(draft.window_mode, 3)
		&"resolution":
			return Vector2i(_resolution_index(draft), SettingsScript.RESOLUTIONS.size())
		&"quality":
			return Vector2i(draft.quality, 3)
		&"max_fps":
			return Vector2i(maxi(SettingsScript.FPS_CAPS.find(draft.max_fps), 0), SettingsScript.FPS_CAPS.size())
	return Vector2i(0, 1)


func _is_changed(key: StringName) -> bool:
	if String(key).begins_with("key_"):
		var action := StringName(String(key).trim_prefix("key_"))
		return SettingsScript.key_of(action, draft.bindings) != SettingsScript.key_of(action, settings.bindings)
	if not (key in SettingsScript.FIELDS):
		return false
	return key in draft.differences(settings)


func _key_caps(key: StringName) -> Array[String]:
	var k := String(key)
	if k.begins_with("key_"):
		var action := StringName(k.trim_prefix("key_"))
		var keyname := "Press a key" if _capturing == action else \
			SettingsScript.key_label(SettingsScript.key_of(action, draft.bindings))
		return [keyname, InputDeviceScript.binding_name(action, true)]
	match key:
		&"info_beam":
			return [InputDeviceScript.binding_name(&"beam", false), InputDeviceScript.binding_name(&"beam", true)]
		&"info_look":
			return ["Mouse", "Right stick"]
		&"info_zoom":
			return ["Wheel", "D-pad"]
	return []


# --- key capture -------------------------------------------------------------------------------

func _capture_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null:
		if not k.pressed or k.echo:
			return
		var code := int(k.physical_keycode) if k.physical_keycode != KEY_NONE else int(k.keycode)
		if code == KEY_ESCAPE:
			MenuStyleScript.tick_back()
		elif code == KEY_BACKSPACE:
			draft.unbind(_capturing)
			MenuStyleScript.tick_move()
		else:
			draft.bind(_capturing, code)
			MenuStyleScript.tick_confirm()
		_end_capture()
		return
	if event.is_action_pressed(&"ui_cancel"):
		MenuStyleScript.tick_back()
		_end_capture()


func _end_capture() -> void:
	var row: Row = _rows.get(StringName("key_" + String(_capturing)))
	_capturing = &""
	_refresh_all()
	if row != null:
		row.grab_focus()


# --- the modal --------------------------------------------------------------------------------

func _open_modal(kind: StringName, title: String, body: String, buttons: Array) -> void:
	_modal_kind = kind
	_modal_title.text = title
	_modal_body.text = body
	_modal_timer.visible = kind == &"display"
	_modal_timer.fraction = 1.0
	_modal_timer.seconds = ceili(DISPLAY_CONFIRM_SECONDS)
	for c in _modal_buttons.get_children():
		_modal_buttons.remove_child(c)
		c.queue_free()
	var made: Array[Button] = []
	for i in buttons.size():
		var b := _make_button(String(buttons[i][0]), i == 0)
		b.pressed.connect(buttons[i][1])
		b.custom_minimum_size = Vector2(220, 64)
		_modal_buttons.add_child(b)
		made.append(b)
	for i in made.size():
		made[i].focus_neighbor_left = made[maxi(i - 1, 0)].get_path()
		made[i].focus_neighbor_right = made[mini(i + 1, made.size() - 1)].get_path()
		made[i].focus_neighbor_top = made[i].get_path()
		made[i].focus_neighbor_bottom = made[i].get_path()
		made[i].focus_next = made[(i + 1) % made.size()].get_path()
		made[i].focus_previous = made[posmod(i - 1, made.size())].get_path()
	_modal.visible = true
	made[0].grab_focus()
	MenuStyleScript.tick_open()


func _close_modal() -> void:
	if _modal == null:
		return
	var was := _modal.visible
	_modal.visible = false
	_modal_kind = &""
	if was and _open:
		_apply_button.grab_focus()


func _modal_cancel() -> void:
	match _modal_kind:
		&"display":
			_revert_display()
		_:
			MenuStyleScript.tick_back()
			_close_modal()


func _cycle_modal_focus(dir: int) -> void:
	var bs := _modal_buttons.get_children()
	if bs.is_empty():
		return
	var at := bs.find(get_viewport().gui_get_focus_owner())
	(bs[posmod(at + dir, bs.size())] as Control).grab_focus()


func _keep_display() -> void:
	settings.save_to()
	MenuStyleScript.tick_confirm()
	_close_modal()
	applied.emit()
	_refresh_all()


func _revert_display() -> void:
	settings.window_mode = int(_display_before.get(&"window_mode", settings.window_mode))
	settings.resolution = _display_before.get(&"resolution", settings.resolution)
	draft.window_mode = settings.window_mode
	draft.resolution = settings.resolution
	settings.apply_window()
	if settings.resolution == Vector2i.ZERO and settings.window_mode == SettingsScript.WindowMode.WINDOWED \
			and DisplayServer.get_name() != "headless":
		# "As the game opened" has no size of its own to go back to; the one it had is kept.
		DisplayServer.window_set_size(_display_before.get(&"size", DisplayServer.window_get_size()))
	settings.save_to()
	MenuStyleScript.tick_back()
	_close_modal()
	applied.emit()
	_refresh_all()


func _save_with_display(before: Dictionary) -> void:
	var now_mode := settings.window_mode
	var now_res := settings.resolution
	settings.window_mode = int(before[&"window_mode"])
	settings.resolution = before[&"resolution"]
	settings.save_to()
	settings.window_mode = now_mode
	settings.resolution = now_res


func _modal_apply_and_close() -> void:
	_close_modal()
	apply()
	if not _modal.visible:
		_finish_close()


## Leave now, dropping anything not applied, without asking: the host is going away.
func discard_and_close() -> void:
	if not _open:
		return
	if confirm_open():
		_revert_display()
	_modal_discard_and_close()


func _modal_discard_and_close() -> void:
	draft.copy_from(settings)
	settings.apply_audio()
	_close_modal()
	_finish_close()


func _finish_close() -> void:
	_open = false
	_capturing = &""
	visible = false
	set_process(false)
	closed.emit()


# --- drawing ---------------------------------------------------------------------------------

func _refresh_all() -> void:
	if draft == null:
		return
	for key: StringName in _rows:
		(_rows[key] as Row).refresh()
	var dirty := is_dirty()
	_style_bar_button(_apply_button, true, dirty)
	_style_bar_button(_revert_button, false, dirty)
	_pending_label.visible = dirty
	var f := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if f is Row:
		_show_info(f as Row)


func _show_info(row: Row) -> void:
	_info_icon.kind = _tab
	_info_icon.queue_redraw()
	_info_title.text = row.label_text
	_info_body.text = row.description
	_info_changed.visible = _is_changed(row.key)
	if _defaults == null:
		_defaults = SettingsScript.new()
	var k := String(row.key)
	var def := ""
	if k.begins_with("key_"):
		def = SettingsScript.key_label(SettingsScript.key_of(StringName(k.trim_prefix("key_")), {}))
	elif row.kind != Kind.INFO:
		def = _value_text(_defaults, row.key)
		if row.key == &"resolution":
			def = "As the game opens"
	_info_default.text = "Default:  %s" % def if not def.is_empty() else ""
	_info_default.visible = not def.is_empty()
	var pad := InputDeviceScript.using_gamepad()
	var how: Array = []
	match row.kind:
		Kind.SLIDER:
			how = [["D-pad" if pad else "Left Right", "adjust"]] + ([] if pad else [["Drag", ""]])
		Kind.CHOICE:
			how = [["D-pad" if pad else "Left Right", "choose"]]
		Kind.TOGGLE:
			how = [["A" if pad else "Enter", "switch"]]
		Kind.KEY:
			how = [["Enter", "rebind"], ["Backspace", "reset"]] if not pad else [["A", "rebind"]]
	_set_how(how)


func _set_how(how: Array) -> void:
	for c in _info_how.get_children():
		_info_how.remove_child(c)
		c.queue_free()
	for pair: Array in how:
		_info_how.add_child(_keycap(String(pair[0]), false))
		if not String(pair[1]).is_empty():
			_info_how.add_child(_label(String(pair[1]) + "   ", SMALL_PX, CREAM_DIM))


func _show_info_for_tab() -> void:
	_info_icon.kind = _tab
	_info_icon.queue_redraw()
	_info_title.text = TAB_NAMES[_tab]
	_info_body.text = ["How the ranch looks, and the window it is drawn in.",
		"Six levels, one per kind of sound. You hear each change as you make it.",
		"Look speed for the mouse and the sticks, and every key the game answers to.",
		"The reminders on screen, and what happens when you look away."][_tab]
	_info_changed.visible = false
	_info_default.visible = false
	var pad := InputDeviceScript.using_gamepad()
	_set_how([["LB RB" if pad else "Q E", "switch tabs"]])


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.0, 0.05, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = PANEL_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override(&"panel", _panel_box())
	centre.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 46)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(col)

	# Header: the title, and the "not applied" pill on the right.
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(header)
	var gear := TabIcon.new()
	gear.kind = TabIcon.GEAR
	gear.custom_minimum_size = Vector2(52, 52)
	gear.colour = GOLD
	header.add_child(gear)
	var title := _label("Settings", TITLE_PX, GOLD)
	title.add_theme_font_override(&"font", MenuStyleScript.title_font())
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_pending_label = _label("Changes not applied", SMALL_PX, INK)
	_pending_label.add_theme_constant_override("outline_size", 0)
	var pill := StyleBoxFlat.new()
	pill.bg_color = GOLD
	pill.set_corner_radius_all(20)
	pill.content_margin_left = 18
	pill.content_margin_right = 18
	pill.content_margin_top = 6
	pill.content_margin_bottom = 6
	_pending_label.add_theme_stylebox_override(&"normal", pill)
	_pending_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_pending_label)

	# Tabs.
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 14)
	tabs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(tabs)
	for i in TAB_NAMES.size():
		var b := Button.new()
		b.name = "Tab" + TAB_NAMES[i]
		b.text = TAB_NAMES[i]
		b.set_meta(&"tab_index", i)
		b.custom_minimum_size = Vector2(0, 68)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_ALL
		b.add_theme_font_size_override("font_size", TAB_PX)
		b.add_theme_constant_override("h_separation", 12)
		b.add_theme_constant_override("outline_size", 0)
		var icon := TabIcon.new()
		icon.kind = i
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.custom_minimum_size = Vector2(34, 34)
		b.add_child(icon)
		b.set_meta(&"icon", icon)
		b.resized.connect(_place_tab_icon.bind(b))
		b.pressed.connect(func() -> void: _show_tab(i, true))
		b.focus_entered.connect(func() -> void:
			if _tab != i:
				_show_tab(i, true))
		b.mouse_entered.connect(func() -> void:
			if not _modal.visible and _capturing == &"":
				b.grab_focus())
		tabs.add_child(b)
		_tab_buttons.append(b)

	# Body: rows on the left, the explainer card on the right.
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 26)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(body)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	_scroll.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	body.add_child(_scroll)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(stack)
	var specs := _specs()
	for i in specs.size():
		var page := VBoxContainer.new()
		page.name = "Page" + TAB_NAMES[i]
		page.add_theme_constant_override("separation", 10)
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(page)
		_pages.append(page)
		for spec: Array in specs[i]:
			if spec[2] == Kind.KEY and page.get_child_count() == 3:
				page.add_child(_section_label("Keys"))
			var row := Row.new()
			row.setup(self, spec[0], spec[1], spec[2], spec[3])
			page.add_child(row)
			_rows[spec[0]] = row
	body.add_child(_build_info_card())

	# The button bar.
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 16)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(bar)
	_hint_box = HBoxContainer.new()
	_hint_box.add_theme_constant_override("separation", 22)
	_hint_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(_hint_box)
	_build_hints()
	_back_button = _make_button("Back", false)
	_back_button.pressed.connect(func() -> void:
		MenuStyleScript.tick_back()
		request_close())
	_revert_button = _make_button("Revert", false)
	_revert_button.pressed.connect(revert)
	_apply_button = _make_button("Apply", true)
	_apply_button.pressed.connect(apply)
	for b in [_back_button, _revert_button, _apply_button]:
		b.set_meta(&"bar_button", true)
		b.custom_minimum_size = Vector2(190, 64)
		bar.add_child(b)
		_bar_buttons.append(b)

	_build_modal()


func _build_info_card() -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(400, 0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = PLUM_DEEP
	box.border_color = GOLD_SOFT
	box.set_border_width_all(2)
	box.set_corner_radius_all(18)
	box.content_margin_left = 28
	box.content_margin_right = 28
	box.content_margin_top = 28
	box.content_margin_bottom = 28
	card.add_theme_stylebox_override(&"panel", box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	_info_icon = TabIcon.new()
	_info_icon.custom_minimum_size = Vector2(0, 150)
	_info_icon.colour = GOLD
	_info_icon.large = true
	v.add_child(_info_icon)
	_info_title = _label("", 30, GOLD)
	_info_title.add_theme_font_override(&"font", MenuStyleScript.title_font())
	_info_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_info_title)
	_info_body = _label("", BODY_PX, CREAM_DIM)
	_info_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_body.custom_minimum_size = Vector2(340, 0)
	v.add_child(_info_body)
	_info_changed = _label("Changed, not applied yet", SMALL_PX, GOLD)
	v.add_child(_info_changed)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(spacer)
	_info_default = _label("", SMALL_PX, CREAM_DIM)
	v.add_child(_info_default)
	var rule := ColorRect.new()
	rule.color = GOLD_SOFT
	rule.custom_minimum_size = Vector2(0, 2)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(rule)
	_info_how = HBoxContainer.new()
	_info_how.add_theme_constant_override("separation", 8)
	_info_how.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_info_how)
	return card


func _build_hints() -> void:
	if _hint_box == null:
		return
	for c in _hint_box.get_children():
		_hint_box.remove_child(c)
		c.queue_free()
	var pairs: Array = [["LB", "RB", "tabs"], ["D-pad", "", "move"], ["A", "", "select"], ["B", "", "back"]] \
		if _hint_pad else [["Q", "E", "tabs"], ["Arrows", "", "move"], ["Enter", "", "select"], ["Esc", "", "back"]]
	for p: Array in pairs:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(_keycap(String(p[0]), false))
		if not String(p[1]).is_empty():
			h.add_child(_keycap(String(p[1]), false))
		var l := _label(String(p[2]), SMALL_PX, CREAM_DIM)
		h.add_child(l)
		_hint_box.add_child(h)


func _build_modal() -> void:
	_modal = Control.new()
	_modal.name = "Modal"
	_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal.visible = false
	add_child(_modal)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.0, 0.04, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal.add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal.add_child(centre)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(760, 0)
	card.add_theme_stylebox_override(&"panel", _panel_box(true))
	centre.add_child(card)
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 40)
	card.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 22)
	m.add_child(v)
	_modal_title = _label("", 36, GOLD)
	_modal_title.add_theme_font_override(&"font", MenuStyleScript.title_font())
	_modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_modal_title)
	_modal_body = _label("", 26, CREAM)
	_modal_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_modal_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_modal_body)
	_modal_timer = TimerBar.new()
	_modal_timer.custom_minimum_size = Vector2(0, 96)
	_modal_timer.font = _font
	v.add_child(_modal_timer)
	_modal_buttons = HBoxContainer.new()
	_modal_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_modal_buttons.add_theme_constant_override("separation", 18)
	v.add_child(_modal_buttons)


func _place_tab_icon(b: Button) -> void:
	var icon: Control = b.get_meta(&"icon")
	var font := b.get_theme_font(&"font")
	var w := font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, TAB_PX).x
	icon.size = Vector2(34, 34)
	icon.position = Vector2((b.size.x - w) * 0.5 - 48.0, (b.size.y - 34.0) * 0.5)


func _section_label(text: String) -> Control:
	var l := _label(text.to_upper(), SMALL_PX, GOLD)
	l.add_theme_constant_override("outline_size", 0)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", 10)
	m.add_theme_constant_override("margin_left", 8)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(l)
	return m


func _label(text: String, px: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.45))
	l.add_theme_constant_override("outline_size", 4 if px >= 30 else 0)
	return l


func _keycap(text: String, bright: bool) -> Label:
	var l := _label(text, SMALL_PX, INK if bright else CREAM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(44, 0)
	var box := StyleBoxFlat.new()
	box.bg_color = GOLD if bright else Color(1, 1, 1, 0.10)
	box.border_color = Color(1, 1, 1, 0.0) if bright else Color(1, 1, 1, 0.28)
	box.set_border_width_all(0 if bright else 1)
	box.border_width_bottom = 3
	box.set_corner_radius_all(8)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 3
	box.content_margin_bottom = 4
	l.add_theme_stylebox_override(&"normal", box)
	return l


func _panel_box(modal := false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = PLUM
	box.border_color = GOLD
	box.set_border_width_all(3)
	box.set_corner_radius_all(26)
	box.shadow_color = Color(0, 0, 0, 0.55)
	box.shadow_size = 30
	box.shadow_offset = Vector2(0, 10)
	if modal:
		box.bg_color = PLUM_DEEP
	return box


## THE FOCUS RING. Gold, three pixels, a soft glow, drawn just outside the control.
static func focus_box(radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = GOLD
	box.set_border_width_all(3)
	box.set_corner_radius_all(radius)
	box.shadow_color = Color(0.98, 0.86, 0.45, 0.30)
	box.shadow_size = 12
	box.set_expand_margin_all(3)
	return box


static func flat_box(bg: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 20
	box.content_margin_right = 20
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box


func _make_button(text: String, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", ROW_PX)
	b.add_theme_constant_override("outline_size", 0)
	_style_bar_button(b, primary, true)
	b.mouse_entered.connect(func() -> void:
		if _capturing == &"" and (not _modal.visible or _modal.is_ancestor_of(b)):
			b.grab_focus())
	return b


func _style_bar_button(b: Button, primary: bool, live: bool) -> void:
	var fill := GOLD if primary and live else Color(1, 1, 1, 0.06)
	var text := INK if primary and live else (CREAM if live else CREAM_DIM)
	var edge := GOLD if primary and live else Color(1, 1, 1, 0.22)
	b.add_theme_stylebox_override(&"normal", flat_box(fill, edge, 2, 16))
	b.add_theme_stylebox_override(&"hover", flat_box(fill.lightened(0.12) if primary and live
		else Color(1, 1, 1, 0.12), GOLD, 2, 16))
	b.add_theme_stylebox_override(&"pressed", flat_box(fill.darkened(0.1), GOLD, 2, 16))
	b.add_theme_stylebox_override(&"focus", focus_box(16))
	for c in [&"font_color", &"font_hover_color", &"font_focus_color", &"font_pressed_color",
			&"font_hover_pressed_color"]:
		b.add_theme_color_override(c, text)


func _style_tab(b: Button, on: bool) -> void:
	var fill := GOLD if on else Color(1, 1, 1, 0.05)
	var text := INK if on else CREAM
	b.add_theme_stylebox_override(&"normal", flat_box(fill, GOLD if on else GOLD_SOFT, 2, 34))
	b.add_theme_stylebox_override(&"hover", flat_box(fill if on else Color(1, 1, 1, 0.12), GOLD, 2, 34))
	b.add_theme_stylebox_override(&"pressed", flat_box(fill, GOLD, 2, 34))
	b.add_theme_stylebox_override(&"focus", focus_box(34))
	for c in [&"font_color", &"font_hover_color", &"font_focus_color", &"font_pressed_color",
			&"font_hover_pressed_color"]:
		b.add_theme_color_override(c, text)
	var icon: TabIcon = b.get_meta(&"icon")
	icon.colour = INK if on else GOLD
	icon.queue_redraw()


# --- the row ---------------------------------------------------------------------------------

## ONE SETTING: a focusable card with the name on the left and its control on the right.
class Row extends Button:
	var menu: SettingsMenu
	var key: StringName
	var label_text := ""
	var kind: int
	var description := ""
	var _name_label: Label
	var _dot: Control
	var _value: Label
	var _slider: SlideBar
	var _switch: Switch
	var _prev: Arrow
	var _next: Arrow
	var _pips: Pips
	var _caps: HBoxContainer

	func setup(owner_menu: SettingsMenu, k: StringName, text_: String, kind_: int, desc: String) -> void:
		menu = owner_menu
		key = k
		label_text = text_
		kind = kind_
		description = desc
		name = "Row_" + String(k)
		set_meta(&"setting_key", k)
		focus_mode = Control.FOCUS_ALL
		custom_minimum_size = Vector2(0, ROW_HEIGHT)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_theme_stylebox_override(&"normal", SettingsMenu.flat_box(PLUM_ROW, Color(1, 1, 1, 0.0), 0, 16))
		add_theme_stylebox_override(&"hover", SettingsMenu.flat_box(PLUM_ROW_HOVER, Color(1, 1, 1, 0), 0, 16))
		add_theme_stylebox_override(&"pressed", SettingsMenu.flat_box(PLUM_ROW_HOVER, Color(1, 1, 1, 0), 0, 16))
		add_theme_stylebox_override(&"focus", SettingsMenu.focus_box(16))
		var h := HBoxContainer.new()
		h.set_anchors_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 18
		h.offset_right = -18
		h.add_theme_constant_override("separation", 12)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(h)
		_dot = Dot.new()
		_dot.custom_minimum_size = Vector2(12, 0)
		_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(_dot)
		_name_label = menu._label(text_, ROW_PX, CREAM)
		_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		h.add_child(_name_label)
		var w := HBoxContainer.new()
		w.custom_minimum_size = Vector2(WIDGET_WIDTH, 0)
		w.alignment = BoxContainer.ALIGNMENT_END
		w.add_theme_constant_override("separation", 10)
		w.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(w)
		match kind:
			Kind.SLIDER:
				_slider = SlideBar.new()
				_slider.name = "Slider"
				_slider.custom_minimum_size = Vector2(270, 44)
				_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				_slider.on_fraction = func(f: float) -> void:
					grab_focus()
					menu._set_slider_fraction(key, f)
				w.add_child(_slider)
				_value = menu._label("", VALUE_PX, GOLD)
				_value.custom_minimum_size = Vector2(96, 0)
				_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				_value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				w.add_child(_value)
			Kind.CHOICE:
				_prev = Arrow.new()
				_prev.name = "Prev"
				_prev.left = true
				_prev.pressed.connect(func() -> void:
					grab_focus()
					menu._change(key, -1))
				w.add_child(_prev)
				var mid := VBoxContainer.new()
				mid.custom_minimum_size = Vector2(250, 0)
				mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
				mid.alignment = BoxContainer.ALIGNMENT_CENTER
				mid.add_theme_constant_override("separation", 4)
				w.add_child(mid)
				_value = menu._label("", VALUE_PX, GOLD)
				_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				mid.add_child(_value)
				_pips = Pips.new()
				_pips.custom_minimum_size = Vector2(0, 8)
				_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
				mid.add_child(_pips)
				_next = Arrow.new()
				_next.name = "Next"
				_next.pressed.connect(func() -> void:
					grab_focus()
					menu._change(key, 1))
				w.add_child(_next)
			Kind.TOGGLE:
				_value = menu._label("", VALUE_PX, GOLD)
				_value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				w.add_child(_value)
				_switch = Switch.new()
				_switch.custom_minimum_size = Vector2(84, 44)
				_switch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				_switch.mouse_filter = Control.MOUSE_FILTER_IGNORE
				w.add_child(_switch)
			Kind.KEY, Kind.INFO:
				_caps = HBoxContainer.new()
				_caps.add_theme_constant_override("separation", 10)
				_caps.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_caps.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				w.add_child(_caps)
		pressed.connect(func() -> void: menu._activate(key))
		focus_entered.connect(func() -> void:
			_name_label.add_theme_color_override("font_color", GOLD)
			menu._show_info(self))
		focus_exited.connect(func() -> void:
			_name_label.add_theme_color_override("font_color", CREAM))
		mouse_entered.connect(func() -> void:
			if not menu._modal.visible and menu._capturing == &"":
				grab_focus())

	func _gui_input(event: InputEvent) -> void:
		if event.is_action_pressed(&"ui_left", true):
			if kind != Kind.KEY and kind != Kind.INFO:
				menu._change(key, -1)
			accept_event()
		elif event.is_action_pressed(&"ui_right", true):
			if kind != Kind.KEY and kind != Kind.INFO:
				menu._change(key, 1)
			accept_event()

	func refresh() -> void:
		var d := menu.draft
		(_dot as Dot).on = menu._is_changed(key)
		_dot.queue_redraw()
		match kind:
			Kind.SLIDER:
				_slider.fraction = menu._fraction(key)
				_slider.queue_redraw()
				_value.text = menu._value_text(d, key)
			Kind.CHOICE:
				_value.text = menu._value_text(d, key)
				var p := menu._choice_pips(key)
				_pips.at = p.x
				_pips.count = p.y
				var off := key == &"resolution" and d.window_mode != SettingsScript.WindowMode.WINDOWED
				_pips.visible = not off
				_value.add_theme_color_override("font_color", CREAM_DIM if off else GOLD)
				_prev.dim = off or p.x <= 0
				_next.dim = off or p.x >= p.y - 1
				_pips.queue_redraw()
				_prev.queue_redraw()
				_next.queue_redraw()
			Kind.TOGGLE:
				var on := bool(d.get(key))
				_value.text = "On" if on else "Off"
				_value.add_theme_color_override("font_color", GOLD if on else CREAM_DIM)
				_switch.on = on
				_switch.queue_redraw()
			Kind.KEY, Kind.INFO:
				for c in _caps.get_children():
					_caps.remove_child(c)
					c.queue_free()
				var caps := menu._key_caps(key)
				for i in caps.size():
					if caps[i].is_empty():
						continue
					var cap := menu._keycap(caps[i], i == 0 and kind == Kind.KEY)
					cap.custom_minimum_size = Vector2(64, 40)
					cap.add_theme_font_size_override("font_size", SMALL_PX if i > 0 else VALUE_PX)
					_caps.add_child(cap)
				if kind == Kind.INFO:
					_name_label.add_theme_color_override("font_color", CREAM_DIM)


## A drawn slider: a rounded track, a gold fill, a cream knob. Click or drag anywhere on it.
class SlideBar extends Control:
	var fraction := 0.5
	var on_fraction: Callable
	var _dragging := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _gui_input(event: InputEvent) -> void:
		var b := event as InputEventMouseButton
		if b != null and b.button_index == MOUSE_BUTTON_LEFT:
			_dragging = b.pressed
			if b.pressed:
				_send(b.position.x)
			accept_event()
			return
		var m := event as InputEventMouseMotion
		if m != null and _dragging:
			_send(m.position.x)
			accept_event()

	func _send(x: float) -> void:
		var pad := 16.0
		if on_fraction.is_valid():
			on_fraction.call(clampf((x - pad) / maxf(size.x - pad * 2.0, 1.0), 0.0, 1.0))

	func _draw() -> void:
		var pad := 16.0
		var h := 12.0
		var y := size.y * 0.5
		var track := Rect2(pad, y - h * 0.5, size.x - pad * 2.0, h)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0.35)
		sb.set_corner_radius_all(6)
		sb.draw(get_canvas_item(), track)
		var fill := track
		fill.size.x = maxf(track.size.x * fraction, h)
		sb.bg_color = GOLD
		sb.draw(get_canvas_item(), fill)
		var kx := track.position.x + track.size.x * fraction
		draw_circle(Vector2(kx, y + 2.0), 15.0, Color(0, 0, 0, 0.30))
		draw_circle(Vector2(kx, y), 15.0, CREAM)
		draw_circle(Vector2(kx, y), 6.0, GOLD)


## An on/off pill.
class Switch extends Control:
	var on := false

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var sb := StyleBoxFlat.new()
		sb.bg_color = GOLD if on else Color(0, 0, 0, 0.35)
		sb.border_color = GOLD if on else Color(1, 1, 1, 0.25)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(int(size.y * 0.5))
		sb.draw(get_canvas_item(), r)
		var rad := size.y * 0.5 - 6.0
		var cx := size.x - size.y * 0.5 if on else size.y * 0.5
		draw_circle(Vector2(cx, size.y * 0.5 + 1.5), rad, Color(0, 0, 0, 0.25))
		draw_circle(Vector2(cx, size.y * 0.5), rad, INK if on else CREAM)


## The < and > on a list row: drawn chevrons, mouse only (the keyboard uses Left/Right).
class Arrow extends Button:
	var left := false
	var dim := false

	func _init() -> void:
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(44, 44)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		flat = true
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for s in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
			add_theme_stylebox_override(s, StyleBoxEmpty.new())

	func _draw() -> void:
		var c := size * 0.5
		var hot := is_hovered() and not dim
		if hot:
			draw_circle(c, 21.0, Color(1, 1, 1, 0.12))
		var s := 1.0 if not left else -1.0
		var col := Color(1, 1, 1, 0.22) if dim else GOLD
		var pts := PackedVector2Array([c + Vector2(-5 * s, -10), c + Vector2(6 * s, 0), c + Vector2(-5 * s, 10)])
		draw_polyline(pts, col, 4.0, true)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_ENTER or what == NOTIFICATION_MOUSE_EXIT:
			queue_redraw()


## Where in its list a choice sits: one dot per option, the current one gold and long.
class Pips extends Control:
	var at := 0
	var count := 1

	func _draw() -> void:
		if count <= 1:
			return
		var gap := 8.0
		var w := 10.0
		var wide := 26.0
		var total := (count - 1) * (w + gap) + wide
		var x := (size.x - total) * 0.5
		for i in count:
			var ww := wide if i == at else w
			var sb := StyleBoxFlat.new()
			sb.bg_color = GOLD if i == at else Color(1, 1, 1, 0.25)
			sb.set_corner_radius_all(3)
			sb.draw(get_canvas_item(), Rect2(x, size.y * 0.5 - 3.0, ww, 6.0))
			x += ww + gap


## The little gold dot on a row that has been changed and not applied.
class Dot extends Control:
	var on := false

	func _draw() -> void:
		if on:
			draw_circle(Vector2(size.x * 0.5, size.y * 0.5), 5.0, GOLD)


## The countdown under the display question: a draining bar and the seconds left.
class TimerBar extends Control:
	var fraction := 1.0
	var seconds := 10
	var font: Font

	func _draw() -> void:
		var bar := Rect2(40, 62, size.x - 80, 14)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0.4)
		sb.set_corner_radius_all(7)
		sb.draw(get_canvas_item(), bar)
		var f := bar
		f.size.x = maxf(bar.size.x * fraction, 14.0)
		sb.bg_color = GOLD
		sb.draw(get_canvas_item(), f)
		if font != null:
			var text := "Changing back in %d" % seconds
			var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
			draw_string(font, Vector2((size.x - w) * 0.5, 40), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, CREAM)


## The drawn icons: a monitor, a speaker, a controller, a star, and the title's gear.
class TabIcon extends Control:
	const GEAR := 9
	var kind := 0
	var colour := GOLD
	var large := false

	func _draw() -> void:
		var s := minf(size.x, size.y)
		var c := size * 0.5
		var u := s / 34.0
		var col := colour
		match kind:
			0:  # monitor
				var r := Rect2(c + Vector2(-15, -12) * u, Vector2(30, 20) * u)
				var sb := StyleBoxFlat.new()
				sb.draw_center = false
				sb.border_color = col
				sb.set_border_width_all(maxi(int(3 * u), 2))
				sb.set_corner_radius_all(int(4 * u))
				sb.draw(get_canvas_item(), r)
				draw_line(c + Vector2(0, 8) * u, c + Vector2(0, 13) * u, col, 3 * u)
				draw_line(c + Vector2(-8, 14) * u, c + Vector2(8, 14) * u, col, 3 * u, true)
			1:  # speaker
				var body := PackedVector2Array([c + Vector2(-14, -5) * u, c + Vector2(-7, -5) * u,
					c + Vector2(1, -12) * u, c + Vector2(1, 12) * u, c + Vector2(-7, 5) * u, c + Vector2(-14, 5) * u])
				draw_colored_polygon(body, col)
				draw_arc(c + Vector2(2, 0) * u, 7 * u, -0.9, 0.9, 12, col, 2.6 * u, true)
				draw_arc(c + Vector2(2, 0) * u, 13 * u, -0.9, 0.9, 16, col, 2.6 * u, true)
			2:  # controller
				var sb := StyleBoxFlat.new()
				sb.bg_color = col
				sb.set_corner_radius_all(int(9 * u))
				sb.draw(get_canvas_item(), Rect2(c + Vector2(-16, -9) * u, Vector2(32, 18) * u))
				var hole := INK if col != INK else GOLD
				if large:
					hole = PLUM_DEEP
				draw_rect(Rect2(c + Vector2(-11, -1.5) * u, Vector2(9, 3) * u), hole)
				draw_rect(Rect2(c + Vector2(-8, -4.5) * u, Vector2(3, 9) * u), hole)
				draw_circle(c + Vector2(7, -2) * u, 2 * u, hole)
				draw_circle(c + Vector2(11, 2) * u, 2 * u, hole)
			3:  # star
				var pts := PackedVector2Array()
				for i in 10:
					var a := -PI * 0.5 + i * PI / 5.0
					var rad := (15.0 if i % 2 == 0 else 6.5) * u
					pts.append(c + Vector2(cos(a), sin(a)) * rad)
				draw_colored_polygon(pts, col)
			GEAR:
				for i in 8:
					var a := i * TAU / 8.0
					draw_line(c + Vector2(cos(a), sin(a)) * 9 * u, c + Vector2(cos(a), sin(a)) * 15 * u, col, 6 * u)
				draw_circle(c, 11 * u, col)
				draw_circle(c, 4.5 * u, PLUM)
