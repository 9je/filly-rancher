extends GutTest
## Regression test for the cursor wiring around the creation screen
## (game/world/ranch.gd's _maybe_open_creation()/_on_creation_confirmed()/
## _set_cursor_captured()).
##
## THE BUG THIS PINS. game/actors/player/camera_rig.gd captures the mouse in its own
## _ready(), which runs before ranch's _maybe_open_creation() ever does, and unlike every
## other menu (build/market/depot/pause, all wired through ranch's own
## _on_menu_opened()/_on_menu_closed()), the creation screen never touched Input.mouse_mode
## at all -- so on a real interactive new game nothing on the screen was clickable: the
## pointer stayed locked to the paused, invisible ranch behind it.
##
## WHY _cursor_captured, NOT Input.mouse_mode. Godot's headless display driver always
## reports Input.mouse_mode as MOUSE_MODE_VISIBLE, whatever was last assigned to it --
## confirmed empirically (a standalone script that sets MOUSE_MODE_CAPTURED and reads it
## straight back gets 0/VISIBLE every time under `--headless`, which is exactly how this
## whole suite and every gate run). Asserting on Input.mouse_mode here would therefore
## either pass vacuously or fail regardless of what ranch.gd actually does. `_cursor_captured`
## is the plain bool _set_cursor_captured() maintains ALONGSIDE the (headless-unobservable)
## Input.mouse_mode assignment, so this file is testing the real decision ranch.gd makes,
## not the one piece of engine state headless cannot see.
##
## WHY A DETACHED RANCH, RATHER THAN world/ranch.tscn. See test_ranch_collection.gd's class
## comment for the reasoning this file borrows -- a full ranch scene boots terrain, a
## spawner and a physics warmup this bug has nothing to do with. Ranch.new() never enters a
## tree, so _ready() never runs and every @onready var stays null except the ones this file
## sets by hand, the same pattern test_ranch_collection.gd's FakePlayer/_ranch() use.
##
## Preloads by path rather than by the global class_name, per the convention at the top of
## game/scripts/pony_rig.gd.

const RanchScript := preload("res://world/ranch.gd")
const GameStateScript := preload("res://systems/game_state.gd")
const SaveIOScript := preload("res://systems/save_io.gd")
const CreationScreenScene := preload("res://ui/creation_screen.tscn")

const SCRATCH_DIR := "user://test_scratch/ranch_creation"


func before_each() -> void:
	SaveIOScript.save_dir = SCRATCH_DIR
	_wipe()


func after_each() -> void:
	_wipe()
	SaveIOScript.save_dir = SaveIOScript.DEFAULT_SAVE_DIR


func _wipe() -> void:
	var da := DirAccess.open(SCRATCH_DIR)
	if da == null:
		return
	da.list_dir_begin()
	var entry := da.get_next()
	while entry != "":
		if not da.current_is_dir():
			da.remove(entry)
		entry = da.get_next()
	da.list_dir_end()


## A detached Ranch wired to a real, tree-attached CreationScreen and a real GameState --
## enough to drive _maybe_open_creation()/_on_creation_confirmed() without booting the
## whole map, the same shape test_ranch_collection.gd's _ranch() wires a FakePlayer with.
func _ranch_with_screen(interactive: bool) -> Dictionary:
	var ranch: RanchScript = autofree(RanchScript.new())
	ranch._game_state = autofree(GameStateScript.new())
	ranch._interactive = interactive
	var screen: CreationScreen = CreationScreenScene.instantiate()
	add_child_autofree(screen)
	ranch.creation_screen = screen
	return {"ranch": ranch, "screen": screen}


func test_a_fresh_ranch_starts_with_the_cursor_captured() -> void:
	var built := _ranch_with_screen(true)
	assert_true(built["ranch"]._cursor_captured,
		"sanity: camera_rig.gd already captured the mouse before any menu ran")


func test_opening_the_creation_screen_frees_the_cursor() -> void:
	var built := _ranch_with_screen(true)
	built["ranch"]._maybe_open_creation()
	assert_true(built["screen"].is_open())
	assert_false(built["ranch"]._cursor_captured,
		"the screen is unusable with the mouse still captured to the ranch behind it")


func test_confirming_recaptures_the_cursor() -> void:
	var built := _ranch_with_screen(true)
	built["ranch"]._maybe_open_creation()
	assert_true(built["screen"].confirm())
	assert_false(built["screen"].is_open())
	assert_true(built["ranch"]._cursor_captured,
		"confirming must hand the mouse back to the game")


func test_a_non_interactive_session_never_touches_the_cursor() -> void:
	# A hosted/headless/screenshot run must not fight whatever the host already set --
	# see _set_cursor_captured()'s _interactive guard.
	var built := _ranch_with_screen(false)
	built["ranch"]._maybe_open_creation()
	assert_false(built["screen"].is_open(),
		"a non-interactive session must never open the screen at all")
	assert_true(built["ranch"]._cursor_captured,
		"...and so must never have released the cursor either")
