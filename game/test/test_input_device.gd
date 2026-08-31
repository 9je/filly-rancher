extends GutTest
## WHICH THING IS IN THE PLAYER'S HANDS, and the glyphs the menus print because of it.
##
## The state is static, so every test here resets it first: a leaked GAMEPAD from one case
## would make the next one pass for the wrong reason.

const InputDeviceScript := preload("res://systems/input_device.gd")


func before_each() -> void:
	InputDeviceScript.reset()


func test_it_starts_on_the_keyboard() -> void:
	assert_eq(InputDeviceScript.last(), InputDeviceScript.Kind.KEYBOARD,
		"somebody at a keyboard must not have to press a key to be recognised")
	assert_false(InputDeviceScript.using_gamepad())


func test_a_key_press_is_the_keyboard() -> void:
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	InputDeviceScript.note(pad)
	var key := InputEventKey.new()
	key.keycode = KEY_E
	InputDeviceScript.note(key)
	assert_eq(InputDeviceScript.last(), InputDeviceScript.Kind.KEYBOARD)


func test_a_mouse_click_and_a_mouse_move_are_both_the_keyboard() -> void:
	for event: InputEvent in [InputEventMouseButton.new(), InputEventMouseMotion.new()]:
		var pad := InputEventJoypadButton.new()
		InputDeviceScript.note(pad)
		InputDeviceScript.note(event)
		assert_eq(InputDeviceScript.last(), InputDeviceScript.Kind.KEYBOARD,
			"a mouse is part of the keyboard scheme, not a third one")


func test_a_pad_button_is_the_gamepad() -> void:
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	InputDeviceScript.note(pad)
	assert_true(InputDeviceScript.using_gamepad())


## AN IDLE STICK DRIFTS. Without the deadzone the whole HUD would flip to gamepad hints
## while the controller sat on the table, and flip back the moment the mouse moved.
func test_a_stick_inside_the_deadzone_changes_nothing() -> void:
	var drift := InputEventJoypadMotion.new()
	drift.axis = JOY_AXIS_LEFT_X
	drift.axis_value = InputDeviceScript.STICK_DEADZONE - 0.01
	InputDeviceScript.note(drift)
	assert_eq(InputDeviceScript.last(), InputDeviceScript.Kind.KEYBOARD)


func test_a_stick_pushed_past_the_deadzone_is_the_gamepad_in_both_directions() -> void:
	for value: float in [InputDeviceScript.STICK_DEADZONE, -1.0]:
		InputDeviceScript.reset()
		var push := InputEventJoypadMotion.new()
		push.axis = JOY_AXIS_LEFT_Y
		push.axis_value = value
		InputDeviceScript.note(push)
		assert_true(InputDeviceScript.using_gamepad(), "axis_value %.2f" % value)


func test_an_event_of_no_interest_leaves_the_answer_where_it_was() -> void:
	var pad := InputEventJoypadButton.new()
	InputDeviceScript.note(pad)
	InputDeviceScript.note(InputEventAction.new())
	assert_true(InputDeviceScript.using_gamepad(),
		"a synthetic action event says nothing about who sent it")


func test_null_is_survivable() -> void:
	InputDeviceScript.note(null)
	assert_eq(InputDeviceScript.last(), InputDeviceScript.Kind.KEYBOARD)


# --- the glyphs -----------------------------------------------------------------------------

func test_the_hint_follows_the_device() -> void:
	assert_eq(InputDeviceScript.hint(&"interact"), "E")
	var pad := InputEventJoypadButton.new()
	InputDeviceScript.note(pad)
	assert_eq(InputDeviceScript.hint(&"interact"), "X")


func test_an_unknown_action_answers_an_empty_string_rather_than_erroring() -> void:
	assert_eq(InputDeviceScript.hint(&"no_such_action_anywhere"), "")


## THE CARD THAT LIES. Every glyph in ACTION_GLYPHS names a real action in
## game/project.godot, and every one of those actions really does carry both a keyboard
## style event and a joypad event; a binding that is removed there and not here is a hint
## that tells the player to press a key that does nothing.
func test_every_named_action_exists_and_is_bound_on_both_schemes() -> void:
	for action: StringName in InputDeviceScript.ACTION_GLYPHS:
		assert_true(InputMap.has_action(action), "%s is not an action at all" % action)
		var keyboard := false
		var gamepad := false
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey or event is InputEventMouseButton:
				keyboard = true
			elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
				gamepad = true
		assert_true(keyboard, "%s has no keyboard binding but the hints promise one" % action)
		assert_true(gamepad, "%s has no gamepad binding but the hints promise one" % action)


func test_no_glyph_carries_a_dash() -> void:
	for key: StringName in InputDeviceScript.GLYPHS:
		for glyph: String in InputDeviceScript.GLYPHS[key]:
			assert_false(glyph.contains("--") or glyph.contains("—"), glyph)
