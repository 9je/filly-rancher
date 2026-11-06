extends Node
## WHICH THING IS IN THE PLAYER'S HANDS RIGHT NOW, so a panel can print one set of hints
## instead of both. The owner, 2026-08-31: "show keyboard hints XOR gamepad hints based on
## the last input device used, not both at once". Every shipped footer printed both on one
## line, which is how a menu ends up saying "Enter / A  confirm      Esc / B  leave".
##
## ONE SCRIPT, TWO HALVES, AND THE SPLIT IS THE WHOLE DESIGN. The READERS are static
## (last(), using_gamepad(), hint()), because game/ui/menu_style.gd is a RefCounted helper
## with no node to reach a singleton through, and because a test can then drive the whole
## thing with note() and no autoload at all. The WRITER is a node, because seeing every
## event in the game needs _input(), and it is registered as an autoload in
## game/project.godot beside AudioSafety and GameState.
##
## NO class_name, MATCHING GameState AND AudioSafety, AND FOR A HARDER REASON THAN STYLE
## THIS TIME: Godot 4.5 refuses to compile a script that declares `class_name InputDevice`
## in the same project as an autoload singleton also named InputDevice ("Class 'InputDevice'
## hides an autoload singleton"). Every reader preloads this by path anyway, the same as
## every other script in this project, so the global name was never needed.
##
## PROCESS_MODE_ALWAYS, AND IT IS NOT OPTIONAL. Every menu in this game pauses the tree
## while it is up (game/world/ranch.gd owns that), which is exactly when the hints are on
## screen being read. A tracker that stopped with the tree would freeze on whichever device
## closed the last menu and never move again.
##
## A STICK IS ONLY A STICK PAST THE DEADZONE. An idle thumbstick drifts and emits
## InputEventJoypadMotion forever; a tracker that believed all of them would flip the whole
## HUD to gamepad hints while the controller sat on the table.
##
## Readers preload this by path, like everything else in this project.

enum Kind { KEYBOARD, GAMEPAD }

## How far a stick has to be pushed before it counts as somebody using it.
const STICK_DEADZONE := 0.5

## WHAT EACH THING IS CALLED ON EACH DEVICE, keyboard first, gamepad second.
##
## The first five keys are real actions in game/project.godot's [input] block and
## test_input_device.gd walks the live InputMap to prove each one is really bound on both
## schemes; a binding removed there and not here is a hint that tells the player to press
## something that does nothing.
##
## The last two are COMPOSITES and are deliberately not actions. A footer says "the two
## keys that change row", and spelling that as two separate entries doubles the length of
## every footer in the game to say one thing twice. ACTION_GLYPHS below is the subset that
## is checked against the InputMap.
const GLYPHS := {
	&"interact": ["E", "X"],
	&"ui_accept": ["Enter", "A"],
	&"ui_cancel": ["Esc", "B"],
	&"pause": ["Esc", "Start"],
	&"toggle_hints": ["H", "Back"],
	&"menu_rows": ["Up Down", "D-pad up down"],
	&"menu_tabs": ["Left Right", "D-pad left right"],
}

## The subset of GLYPHS that names a real action. See GLYPHS.
const ACTION_GLYPHS: Array[StringName] = [&"interact", &"ui_accept", &"ui_cancel",
	&"pause", &"toggle_hints"]

## Static, so a reader needs no node. Starts on the keyboard: somebody sitting at one must
## not have to press a key before the game will admit she is there.
static var _last: int = Kind.KEYBOARD


func _ready() -> void:
	# See the class comment: the menus that read this are on screen precisely when the tree
	# is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	note(event)


## Record what sent `event`. Anything that is not one of the five interesting classes
## leaves the answer exactly where it was, which is the right answer for a synthetic
## InputEventAction: it says nothing about who sent it.
static func note(event: InputEvent) -> void:
	if event == null:
		return
	if event is InputEventKey or event is InputEventMouseButton \
			or event is InputEventMouseMotion:
		_last = Kind.KEYBOARD
	elif event is InputEventJoypadButton:
		_last = Kind.GAMEPAD
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) >= STICK_DEADZONE:
			_last = Kind.GAMEPAD


static func last() -> int:
	return _last


static func using_gamepad() -> bool:
	return _last == Kind.GAMEPAD


## What to print for `action` on the device she is holding. An unknown action answers the
## empty string rather than erroring: a footer with a gap in it is a cosmetic fault and a
## crashed menu is not.
static func hint(action: StringName) -> String:
	if GLYPHS.has(action):
		var pair: Array = GLYPHS[action]
		return String(pair[1] if using_gamepad() else pair[0])
	# Owner playtest 2026-10-24: every action missing from GLYPHS printed as nothing, so the
	# very first tip read "Hold  on a pony to Scoop her up". Any other action is named from
	# its live binding instead, so a rebound key is the key the tip names.
	if not InputMap.has_action(action):
		return ""
	return binding_name(action, using_gamepad())


const MOUSE_NAMES := {MOUSE_BUTTON_LEFT: "Left Click", MOUSE_BUTTON_RIGHT: "Right Mouse",
	MOUSE_BUTTON_MIDDLE: "Middle Mouse"}
const PAD_BUTTON_NAMES := {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X",
	JOY_BUTTON_Y: "Y", JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3", JOY_BUTTON_BACK: "Back",
	JOY_BUTTON_START: "Start", JOY_BUTTON_DPAD_LEFT: "D-pad left",
	JOY_BUTTON_DPAD_RIGHT: "D-pad right", JOY_BUTTON_DPAD_UP: "D-pad up",
	JOY_BUTTON_DPAD_DOWN: "D-pad down"}
const PAD_AXIS_NAMES := {JOY_AXIS_TRIGGER_LEFT: "LT", JOY_AXIS_TRIGGER_RIGHT: "RT"}


## The human name of `action`'s first keyboard/mouse binding (or gamepad one, for a pad).
static func pad_button_name(button: int) -> String:
	return String(PAD_BUTTON_NAMES.get(button, "Pad")) if button >= 0 else "-"


static func binding_name(action: StringName, pad: bool) -> String:
	for e: InputEvent in InputMap.action_get_events(action):
		if pad:
			if e is InputEventJoypadButton:
				return String(PAD_BUTTON_NAMES.get((e as InputEventJoypadButton).button_index, "Pad"))
			if e is InputEventJoypadMotion:
				return String(PAD_AXIS_NAMES.get((e as InputEventJoypadMotion).axis, "Stick"))
		else:
			if e is InputEventMouseButton:
				return String(MOUSE_NAMES.get((e as InputEventMouseButton).button_index, "Mouse"))
			if e is InputEventKey:
				var k := e as InputEventKey
				var code := k.keycode if k.keycode != KEY_NONE \
					else DisplayServer.keyboard_get_keycode_from_physical(k.physical_keycode)
				return OS.get_keycode_string(code)
	return ""


## Back to the keyboard. For the tests, which share one static and would otherwise leak a
## GAMEPAD from one case into the next.
static func reset() -> void:
	_last = Kind.KEYBOARD
