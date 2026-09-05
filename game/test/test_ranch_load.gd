extends GutTest
## THE LOAD ROW, AT THE RANCH END. This drives _can_load(), the decision that gates
## _on_load_requested() -- both branches of it, no state and a real save on disk.
##
## IT NEVER RELOADS THE SCENE HERE. reload_current_scene() on a Ranch built by a test would
## take the GUT runner's own tree with it, so the handler is split: _can_load() is the
## decision and _on_load_requested() is the act, and this file only ever drives the decision.
## Proving pause_menu.gd's own load_requested actually fires, and only when a save exists, is
## test_pause_menu.gd's job (test_load_game_asks_the_ranch_to_load_and_only_when_there_is_a_save
## and test_load_game_refuses_when_no_save_exists) -- the wiring in _bind_pause_menu() that
## connects that signal to this file's _on_load_requested() is not re-proven here either; it is
## the same is_connected()-guarded pattern every other pair in that function uses.

const RanchScript := preload("res://world/ranch.gd")
const GameStateScript := preload("res://systems/game_state.gd")


func test_a_ranch_with_no_game_state_cannot_load() -> void:
	var ranch: Ranch = RanchScript.new()
	assert_false(ranch._can_load(), "no state, no load")
	ranch.free()


## THE TRUE BRANCH, EARNED RATHER THAN STUBBED: save_to_slot() writes a real file under
## FILLY_TEST_SAVE_DIR (see game/systems/save_io.gd), the same thing
## test_game_state.gd's test_has_save_reports_what_is_actually_on_disk() checks, so this is
## the one place both halves of _can_load()'s "and" meet: a _game_state that exists, and one
## that actually has something on disk. _can_load() reads has_save() at GameState's own
## DEFAULT_SLOT, so the save has to land there too.
func test_a_ranch_with_a_save_on_disk_can_load() -> void:
	var ranch: Ranch = RanchScript.new()
	var state = autofree(GameStateScript.new())
	state.save_to_slot(GameStateScript.DEFAULT_SLOT)
	ranch._game_state = state
	assert_true(ranch._can_load(), "a save is on disk, so there is something to load")
	ranch.free()
