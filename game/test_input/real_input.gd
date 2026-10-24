class_name RealInput
extends RefCounted
## THE ONLY WAY A REAL-INPUT TEST TOUCHES THE GAME (PLAYTEST_FIXES.md, rule 2). Every action
## is an InputEvent handed to Input.parse_input_event(), built from the project's own InputMap
## (so a rebound key is the key the test presses), or a raw mouse event at a screen position.
## Nothing here calls a game function. A test may LOOK at anything (the bot's eyes: where a
## pony stands, what the HUD tip says), but it may only ACT through this file.

## Keyboard and mouse first, the way the owner plays; a joypad binding only when an action
## has nothing else.
static func event_for(action: StringName) -> InputEvent:
	var fallback: InputEvent = null
	for e: InputEvent in InputMap.action_get_events(action):
		if e is InputEventKey or e is InputEventMouseButton:
			return e.duplicate()
		if fallback == null:
			fallback = e.duplicate()
	assert(fallback != null, "no binding for action %s" % action)
	return fallback


static func press(action: StringName) -> void:
	_send(action, true)


static func release(action: StringName) -> void:
	_send(action, false)


static func _send(action: StringName, pressed: bool) -> void:
	var e := event_for(action)
	if e is InputEventKey:
		var k := e as InputEventKey
		k.pressed = pressed
		# A physical-only binding carries keycode 0; a real keyboard event carries both.
		if k.keycode == KEY_NONE:
			k.keycode = DisplayServer.keyboard_get_keycode_from_physical(k.physical_keycode)
		if k.physical_keycode == KEY_NONE:
			k.physical_keycode = k.keycode
	elif e is InputEventMouseButton:
		var b := e as InputEventMouseButton
		b.pressed = pressed
		b.position = mouse_position()
		b.global_position = b.position
		b.button_mask = (1 << (b.button_index - 1)) if pressed else 0
	elif e is InputEventJoypadButton:
		(e as InputEventJoypadButton).pressed = pressed
	elif e is InputEventJoypadMotion:
		(e as InputEventJoypadMotion).axis_value = 1.0 if pressed else 0.0
	Input.parse_input_event(e)


static func key(keycode: Key, pressed: bool) -> void:
	var k := InputEventKey.new()
	k.keycode = keycode
	k.physical_keycode = keycode
	k.pressed = pressed
	Input.parse_input_event(k)


## Mouse look: relative motion only, the way a captured mouse reports it.
static func look(relative: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.relative = relative
	m.screen_relative = relative
	m.position = mouse_position()
	m.global_position = m.position
	Input.parse_input_event(m)


static var _mouse := Vector2(640, 360)


static func mouse_position() -> Vector2:
	return _mouse


static func move_mouse(to: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.relative = to - _mouse
	m.screen_relative = m.relative
	m.position = to
	m.global_position = to
	_mouse = to
	Input.parse_input_event(m)


static func mouse_button(button: MouseButton, pressed: bool, at: Vector2) -> void:
	var b := InputEventMouseButton.new()
	b.button_index = button
	b.pressed = pressed
	b.position = at
	b.global_position = at
	b.button_mask = (1 << (button - 1)) if pressed else 0
	Input.parse_input_event(b)


## Where a Control's centre is on the window, through any canvas and stretch transform.
static func screen_centre(c: Control) -> Vector2:
	var vp := c.get_viewport()
	var local := c.size * 0.5
	return vp.get_screen_transform() * (c.get_global_transform_with_canvas() * local)


## The first visible Control under `root` whose text is `text` (a Button or a Label row).
static func find_text(root: Node, text: String) -> Control:
	for n in root.find_children("*", "Control", true, false):
		var c := n as Control
		if not c.is_visible_in_tree():
			continue
		var t = c.get("text")
		if t is String and (t as String).strip_edges().contains(text):
			return c
	return null


## A key or button's printed name, the way a keyboard or mouse labels it. The test's own
## copy, so a test reads a prompt without trusting the game's naming code.
static func binding_name(action: StringName) -> String:
	for e: InputEvent in InputMap.action_get_events(action):
		if e is InputEventMouseButton:
			return {MOUSE_BUTTON_LEFT: "Left Click", MOUSE_BUTTON_RIGHT: "Right Mouse",
				MOUSE_BUTTON_MIDDLE: "Middle Mouse"}.get((e as InputEventMouseButton).button_index, "Mouse")
		if e is InputEventKey:
			var k := e as InputEventKey
			var code := k.keycode if k.keycode != KEY_NONE \
				else DisplayServer.keyboard_get_keycode_from_physical(k.physical_keycode)
			return OS.get_keycode_string(code)
	return ""
