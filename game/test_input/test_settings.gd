extends "res://test_input/input_test.gd"
## PLAYTEST NOTE: "Settings UI is awful and hard to navigate." The order: a clear tabbed menu
## (Graphics, Audio, Controls, Gameplay), readable text, full keyboard and controller
## navigation with a visible focus, Apply and Revert, and a timed confirmation for display
## changes.
##
## Played three times, the three ways a person holds the game:
##   1. KEYBOARD ONLY, from the title screen: arrows, Tab, Enter, Esc.
##   2. CONTROLLER ONLY, from the in-game pause menu: d-pad, left stick, A, B, LB/RB.
##   3. MOUSE ONLY, from the pause menu again: clicks on tabs, rows and buttons.
## Every tab is visited and has a value changed on it each time. At EVERY step the control
## holding focus must exist, be on screen inside the settings menu, and carry a focus box
## that actually draws. Apply must reach the settings file; Revert must put the draft back;
## a display change must ask, and change itself back when nobody answers.
##
## The test READS the UI (which tab is up, which row has focus, what the draft says, the
## settings file) and ACTS only through RealInput.

const TABS: Array[String] = ["Graphics", "Audio", "Controls", "Gameplay"]
const MIN_FONT_PX := 22

var menu: Control = null
var _shots := ""


func _play() -> void:
	_deadline_s = 900.0
	_shots = OS.get_environment("FILLY_SETTINGS_SHOTS")
	if not await _keyboard_from_title():
		return
	if not await _controller_from_pause():
		return
	if not await _mouse_from_pause():
		return
	ok("keyboard, controller and mouse all drove every tab; apply, revert and the display timeout hold")


# --- 1. keyboard, title screen ----------------------------------------------------------------

func _keyboard_from_title() -> bool:
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await frames(12)
	var title := current_scene
	if not check(title != null and title.has_method("selected_index"), "the title screen never came up"):
		return false
	# Down until the cursor sits on Settings, the way a person reads the list.
	var rows: Array = _const(title, "ROWS")
	var want := rows.find("Settings")
	var guard := 0
	while int(title.call("selected_index")) != want and guard < 8:
		await key_tap(KEY_DOWN)
		guard += 1
	await key_tap(KEY_ENTER)
	if not await _wait_menu("the title screen's Settings"):
		return false
	note("title -> settings by keyboard")
	await shot("title_open")
	if not _focus_ok("on open"):
		return false
	if not _fonts_ok():
		return false
	# The keyboard plan: per tab, the row to change and the key that changes it.
	var plan := [
		[&"fov", KEY_RIGHT],
		[&"master_volume", KEY_LEFT],
		[&"invert_look", KEY_ENTER],
		[&"show_controls_chip", KEY_ENTER],
	]
	for i in TABS.size():
		if not await _keyboard_reach_tab(i):
			return false
		if not _fonts_ok():
			return false
		var key_name: StringName = plan[i][0]
		var before: Variant = _draft(key_name)
		if not await _keyboard_reach_row(key_name):
			return false
		await key_tap(plan[i][1])
		if not _focus_ok("after changing %s" % key_name):
			return false
		if not check(_draft(key_name) != before, "%s did not change on the %s tab (still %s)"
				% [key_name, TABS[i], before]):
			return false
		note("%s: %s %s -> %s" % [TABS[i], key_name, before, _draft(key_name)])
		await shot("tab_%s" % TABS[i].to_lower())
		# Tab moves focus on to the next control and keeps it visible.
		var was := _focus()
		await key_tap(KEY_TAB)
		if not check(_focus() != was, "Tab did not move focus on the %s tab" % TABS[i]):
			return false
		if not _focus_ok("after Tab"):
			return false
		await key_tap(KEY_TAB, true)
		if not _focus_ok("after Shift+Tab"):
			return false
	# Apply: down to the button bar, across to Apply, Enter.
	if not await _keyboard_reach_button("Apply"):
		return false
	await key_tap(KEY_ENTER)
	await frames(4)
	var cfg := _file()
	if not check(is_equal_approx(float(cfg.get_value("settings", "fov", 0.0)), float(_draft(&"fov")))
			and is_equal_approx(float(cfg.get_value("settings", "master_volume", -1.0)), 0.9)
			and bool(cfg.get_value("settings", "invert_look", false))
			and not bool(cfg.get_value("settings", "show_controls_chip", true)),
			"Apply did not write the four changes to %s" % _settings_path()):
		return false
	note("apply persisted")
	# Revert: change something, then Revert puts the draft back to what is applied.
	if not await _keyboard_reach_tab(1):
		return false
	if not await _keyboard_reach_row(&"music_volume"):
		return false
	var music := float(_draft(&"music_volume"))
	await key_tap(KEY_LEFT)
	await key_tap(KEY_LEFT)
	if not check(not is_equal_approx(float(_draft(&"music_volume")), music), "music did not move"):
		return false
	if not await _keyboard_reach_button("Revert"):
		return false
	await key_tap(KEY_ENTER)
	if not check(is_equal_approx(float(_draft(&"music_volume")), music),
			"Revert left music at %s, not %s" % [_draft(&"music_volume"), music]):
		return false
	if not check(is_equal_approx(float(_file().get_value("settings", "music_volume", -1.0)), music),
			"the reverted change reached the file anyway"):
		return false
	if not _focus_ok("after Revert"):
		return false
	note("revert restored")
	await key_tap(KEY_ESCAPE)
	await frames(4)
	if not check(not _open(), "Esc did not close Settings on the title screen"):
		return false
	if not check(int(title.call("selected_index")) == want, "closing Settings lost the title cursor"):
		return false
	return true


func _keyboard_reach_tab(i: int) -> bool:
	# Up until focus is on the tab strip, then Left or Right until the tab is up.
	var guard := 0
	while not _focus_is_tab() and guard < 30:
		await key_tap(KEY_UP)
		guard += 1
		if not _focus_ok("climbing to the tabs"):
			return false
	if not check(_focus_is_tab(), "Up never reached the tab strip"):
		return false
	guard = 0
	while int(menu.call("current_tab")) != i and guard < 8:
		await key_tap(KEY_RIGHT if int(menu.call("current_tab")) < i else KEY_LEFT)
		guard += 1
		if not _focus_ok("moving along the tabs"):
			return false
	return check(int(menu.call("current_tab")) == i, "the arrows never reached the %s tab" % TABS[i])


func _keyboard_reach_row(key_name: StringName) -> bool:
	var guard := 0
	while _focus_key() != key_name and guard < 30:
		await key_tap(KEY_DOWN)
		guard += 1
		if not _focus_ok("walking down to %s" % key_name):
			return false
	return check(_focus_key() == key_name, "Down never reached the %s row (stopped on %s)"
		% [key_name, _focus_desc()])


func _keyboard_reach_button(text: String) -> bool:
	var guard := 0
	while not _focus_is_button_bar() and guard < 30:
		await key_tap(KEY_DOWN)
		guard += 1
		if not _focus_ok("walking down to the buttons"):
			return false
	guard = 0
	while _focus_text() != text and guard < 6:
		await key_tap(KEY_RIGHT if _button_index(text) > _button_index(_focus_text()) else KEY_LEFT)
		guard += 1
		if not _focus_ok("moving along the buttons"):
			return false
	return check(_focus_text() == text, "never reached the %s button (on %s)" % [text, _focus_desc()])


# --- 2. controller, pause menu ----------------------------------------------------------------

func _controller_from_pause() -> bool:
	if not await boot_new_game():
		return false
	if not await finish_creator():
		return false
	await wait(1.0)
	await close_letter()
	await wait(0.5)
	# Start opens the pause menu (Esc on the keyboard).
	await joy_tap(JOY_BUTTON_START)
	var pause: Node = ranch.get("pause_menu")
	if not check(pause != null and bool(pause.call("is_open")), "Start did not open the pause menu"):
		return false
	var want: int = int((_const(pause, "Row") as Dictionary)["SETTINGS"])
	var guard := 0
	while int(pause.call("selected_index")) != want and guard < 12:
		await joy_tap(JOY_BUTTON_DPAD_DOWN)
		guard += 1
	await joy_tap(JOY_BUTTON_A)
	if not await _wait_menu("the pause menu's Settings"):
		return false
	note("pause -> settings by controller")
	await shot("pause_open")
	if not _focus_ok("on open (pause)"):
		return false
	var plan := [
		[&"quality", JOY_BUTTON_DPAD_LEFT],
		[&"effects_volume", JOY_BUTTON_DPAD_LEFT],
		[&"stick_sensitivity", JOY_BUTTON_DPAD_RIGHT],
		[&"show_checklist", JOY_BUTTON_A],
	]
	for i in TABS.size():
		# The shoulder buttons switch tabs from wherever focus is.
		guard = 0
		while int(menu.call("current_tab")) != i and guard < 8:
			await joy_tap(JOY_BUTTON_RIGHT_SHOULDER if int(menu.call("current_tab")) < i
				else JOY_BUTTON_LEFT_SHOULDER)
			guard += 1
			if not _focus_ok("after a shoulder button"):
				return false
		if not check(int(menu.call("current_tab")) == i, "LB/RB never reached %s" % TABS[i]):
			return false
		var key_name: StringName = plan[i][0]
		var before: Variant = _draft(key_name)
		# Walk down with the stick on the first tab, the d-pad on the rest.
		guard = 0
		while _focus_key() != key_name and guard < 30:
			if i == 0:
				await stick_down()
			else:
				await joy_tap(JOY_BUTTON_DPAD_DOWN)
			guard += 1
			if not _focus_ok("walking down to %s by controller" % key_name):
				return false
		if not check(_focus_key() == key_name, "the controller never reached %s (on %s)"
				% [key_name, _focus_desc()]):
			return false
		await joy_tap(plan[i][1])
		if not check(_draft(key_name) != before, "%s did not change by controller" % key_name):
			return false
		note("pad %s: %s %s -> %s" % [TABS[i], key_name, before, _draft(key_name)])
	if not await _pad_reach_button("Apply"):
		return false
	await joy_tap(JOY_BUTTON_A)
	var cfg := _file()
	if not check(int(cfg.get_value("settings", "quality", -1)) == int(_draft(&"quality"))
			and not bool(cfg.get_value("settings", "show_checklist", true)),
			"Apply by controller did not persist"):
		return false
	# A DISPLAY CHANGE ASKS, AND UNANSWERED IT GOES BACK. Window mode to fullscreen, Apply,
	# then hands off the pad.
	var mode_before := DisplayServer.window_get_mode()
	var size_before := DisplayServer.window_get_size()
	if not await _pad_change_window_mode():
		return false
	if not await _pad_reach_button("Apply"):
		return false
	await joy_tap(JOY_BUTTON_A)
	await frames(6)
	if not check(bool(menu.call("confirm_open")), "a window mode change applied without asking"):
		return false
	await shot("display_confirm")
	if not _focus_ok("on the display confirmation"):
		return false
	if not _fonts_ok():
		return false
	if not check(DisplayServer.window_get_mode() != mode_before, "the new window mode was never tried"):
		return false
	var secs: float = float(_const(menu, "DISPLAY_CONFIRM_SECONDS"))
	note("confirmation up; waiting out %.0fs without answering" % secs)
	await wait(secs + 1.5)
	if not check(not bool(menu.call("confirm_open")), "the confirmation never timed out"):
		return false
	if not check(DisplayServer.window_get_mode() == mode_before,
			"the timeout left the window in mode %d, not %d" % [DisplayServer.window_get_mode(), mode_before]):
		return false
	if not check(DisplayServer.window_get_size() == size_before,
			"the timeout left the window %s, not %s" % [DisplayServer.window_get_size(), size_before]):
		return false
	if not check(int(_draft(&"window_mode")) == 0
			and int(_file().get_value("settings", "window_mode", 0)) == 0,
			"the timeout reverted the window but not the setting"):
		return false
	if not _focus_ok("after the timeout"):
		return false
	note("display timeout reverted")
	# B leaves Settings, back on the pause menu's Settings row; B again resumes.
	await joy_tap(JOY_BUTTON_B)
	if not check(not _open() and bool(pause.call("is_open"))
			and int(pause.call("selected_index")) == want, "B did not return to the pause menu"):
		return false
	await joy_tap(JOY_BUTTON_B)
	return check(not bool(pause.call("is_open")), "B did not resume")


func _pad_change_window_mode() -> bool:
	var guard := 0
	while int(menu.call("current_tab")) != 0 and guard < 8:
		await joy_tap(JOY_BUTTON_LEFT_SHOULDER)
		guard += 1
	guard = 0
	while _focus_key() != &"window_mode" and guard < 30:
		await joy_tap(JOY_BUTTON_DPAD_UP if _focus_is_button_bar() or _row_order(_focus_key()) > 0
			else JOY_BUTTON_DPAD_DOWN)
		guard += 1
		if _focus_is_tab():
			await joy_tap(JOY_BUTTON_DPAD_DOWN)
	if not check(_focus_key() == &"window_mode", "never reached Window mode by pad"):
		return false
	await joy_tap(JOY_BUTTON_DPAD_RIGHT)
	return check(int(_draft(&"window_mode")) != 0, "Window mode did not change")


func _pad_reach_button(text: String) -> bool:
	var guard := 0
	while not _focus_is_button_bar() and guard < 30:
		await joy_tap(JOY_BUTTON_DPAD_DOWN)
		guard += 1
		if not _focus_ok("pad down to the buttons"):
			return false
	guard = 0
	while _focus_text() != text and guard < 6:
		await joy_tap(JOY_BUTTON_DPAD_RIGHT if _button_index(text) > _button_index(_focus_text())
			else JOY_BUTTON_DPAD_LEFT)
		guard += 1
	return check(_focus_text() == text, "the pad never reached %s (on %s)" % [text, _focus_desc()])


# --- 3. mouse, pause menu ---------------------------------------------------------------------

func _mouse_from_pause() -> bool:
	await key_tap(KEY_ESCAPE)
	var pause: Node = ranch.get("pause_menu")
	if not check(bool(pause.call("is_open")), "Esc did not open the pause menu"):
		return false
	if not await click_text("Settings"):
		return false
	if not await _wait_menu("a click on Settings"):
		return false
	var plan := [&"vsync", &"ambient_volume", &"invert_look", &"pause_on_focus_loss"]
	for i in TABS.size():
		var tab := _tab_button(i)
		await click(tab)
		if not check(int(menu.call("current_tab")) == i, "a click on %s did not open it" % TABS[i]):
			return false
		var key_name: StringName = plan[i]
		var before: Variant = _draft(key_name)
		var row: Control = menu.call("row_for", key_name)
		if not check(row != null and row.is_visible_in_tree(), "no visible %s row" % key_name):
			return false
		# A slider is clicked a quarter of the way along; anything else on its value side.
		var target: Control = row.find_child("Slider", true, false) as Control
		if target != null:
			var at := RI.screen_centre(target) - Vector2(target.size.x * 0.25, 0.0) \
				* target.get_viewport().get_screen_transform().get_scale()
			RI.move_mouse(at)
			await frames(2)
			RI.mouse_button(MOUSE_BUTTON_LEFT, true, at)
			await frames(2)
			RI.mouse_button(MOUSE_BUTTON_LEFT, false, at)
			await frames(3)
		else:
			await click(row)
		if not check(_draft(key_name) != before, "a click did not change %s" % key_name):
			return false
		if not _focus_ok("after a click on %s" % key_name):
			return false
		note("mouse %s: %s %s -> %s" % [TABS[i], key_name, before, _draft(key_name)])
	# A resolution change by its arrow, Apply, then Keep it.
	await click(_tab_button(0))
	var res_row: Control = menu.call("row_for", &"resolution")
	var res_before: Vector2i = _draft(&"resolution")
	var next := res_row.find_child("Next", true, false) as Control
	if not check(next != null, "the Resolution row has no arrow to click"):
		return false
	await click(next)
	if not check(_draft(&"resolution") != res_before, "the arrow did not change Resolution"):
		return false
	if not await click_text("Apply"):
		return false
	await frames(6)
	if not check(bool(menu.call("confirm_open")), "a resolution change applied without asking"):
		return false
	if not await click_text("Keep it"):
		return false
	await frames(4)
	var cfg := _file()
	if not check(not bool(menu.call("confirm_open"))
			and cfg.get_value("settings", "resolution", Vector2i.ZERO) == _draft(&"resolution")
			and bool(cfg.get_value("settings", "invert_look", true)) == bool(_draft(&"invert_look")),
			"Keep it did not persist the resolution and the clicked changes"):
		return false
	if not check(DisplayServer.window_get_size() == _draft(&"resolution"),
			"the window is %s, not the kept %s" % [DisplayServer.window_get_size(), _draft(&"resolution")]):
		return false
	note("mouse resolution kept")
	if not await click_text("Back"):
		return false
	return check(not _open() and bool(pause.call("is_open")), "Back did not return to the pause menu")


# --- reading the screen -----------------------------------------------------------------------

func _wait_menu(door: String) -> bool:
	var t := 0.0
	while t < 5.0:
		menu = root.find_child("SettingsMenu", true, false) as Control
		if menu != null and menu.is_visible_in_tree() and menu.has_method("current_tab"):
			await frames(3)
			return true
		await wait(0.1)
		t += 0.1
	fail("%s opened no tabbed Settings menu (Graphics, Audio, Controls, Gameplay)" % door)
	return false


func _const(o: Object, n: String) -> Variant:
	return (o.get_script() as Script).get_script_constant_map().get(n)


func _open() -> bool:
	return menu != null and is_instance_valid(menu) and menu.is_visible_in_tree()


func _draft(key_name: StringName) -> Variant:
	return (menu.get("draft") as Object).get(key_name)


func _focus() -> Control:
	return root.gui_get_focus_owner()


func _focus_key() -> StringName:
	var f := _focus()
	return StringName(f.get_meta(&"setting_key", &"")) if f != null else &""


func _focus_text() -> String:
	var f := _focus()
	return String(f.get("text")) if f is Button else ""


func _focus_desc() -> String:
	var f := _focus()
	if f == null:
		return "nothing"
	return "%s '%s' key=%s" % [f.name, _focus_text(), _focus_key()]


func _focus_is_tab() -> bool:
	var f := _focus()
	return f != null and f.has_meta(&"tab_index")


func _focus_is_button_bar() -> bool:
	var f := _focus()
	return f != null and f.has_meta(&"bar_button")


func _button_index(text: String) -> int:
	return ["Back", "Revert", "Apply"].find(text)


func _row_order(key_name: StringName) -> int:
	var f := menu.call("row_for", key_name) as Control
	return f.get_index() if f != null else -1


func _tab_button(i: int) -> Control:
	for n in menu.find_children("*", "Button", true, false):
		if n.has_meta(&"tab_index") and int(n.get_meta(&"tab_index")) == i:
			return n
	return null


## THE FOCUS IS VISIBLE: something has it, it is inside the menu and on screen, and the box
## Godot draws for focus is a real outline, not StyleBoxEmpty.
func _focus_ok(when: String) -> bool:
	var f := _focus()
	if not check(f != null, "nothing has focus %s" % when):
		return false
	if not check(f.is_visible_in_tree() and (menu.is_ancestor_of(f) or f == menu),
			"focus is off the settings menu %s (%s)" % [when, _focus_desc()]):
		return false
	var vis := f.get_viewport().get_visible_rect()
	if not check(vis.encloses(f.get_global_rect().grow(-2.0)),
			"the focused control is off screen %s (%s at %s)" % [when, _focus_desc(), f.get_global_rect()]):
		return false
	var box := f.get_theme_stylebox(&"focus")
	var drawn := box is StyleBoxFlat and (box as StyleBoxFlat).border_color.a > 0.5 \
		and maxi((box as StyleBoxFlat).border_width_left, (box as StyleBoxFlat).border_width_top) >= 2
	return check(drawn, "the focused control draws no visible focus %s (%s, box %s)"
		% [when, _focus_desc(), box])


## EVERY WORD ON THE MENU IS AT LEAST MIN_FONT_PX IN 1080p UNITS (canvas_items stretch
## against 1920x1080, so a theme size is a 1080p pixel size).
func _fonts_ok() -> bool:
	for n in menu.find_children("*", "Control", true, false):
		var c := n as Control
		if not c.is_visible_in_tree():
			continue
		if c is Label or (c is Button and not String((c as Button).text).is_empty()):
			var px := c.get_theme_font_size(&"font_size")
			if not check(px >= MIN_FONT_PX, "'%s' (%s) is %d px, under %d" %
					[c.get("text"), c.name, px, MIN_FONT_PX]):
				return false
	return true


func _settings_path() -> String:
	return Settings.settings_path


func _file() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(_settings_path())
	return cfg


# --- acting -------------------------------------------------------------------------------------

func key_tap(k: Key, shift := false) -> void:
	RI.key_mod(k, true, shift)
	await frames(2)
	RI.key_mod(k, false, shift)
	await frames(3)


func joy_tap(b: JoyButton) -> void:
	RI.joy_button(b, true)
	await frames(2)
	RI.joy_button(b, false)
	await frames(3)


func stick_down() -> void:
	RI.joy_axis(JOY_AXIS_LEFT_Y, 1.0)
	await frames(2)
	RI.joy_axis(JOY_AXIS_LEFT_Y, 0.0)
	await frames(3)


func shot(tag: String) -> void:
	if _shots.is_empty():
		return
	await frames(4)
	DirAccess.make_dir_recursive_absolute(_shots)
	var img := root.get_texture().get_image()
	img.save_png(_shots.path_join("%s.png" % tag))
