extends GutTest
## THE LOAD ROW, AT THE RANCH END. game/ui/pause_menu.gd emits load_requested; this is the
## claim that ranch.gd hears it, and that it refuses when there is nothing on disk to load.
##
## IT NEVER RELOADS THE SCENE HERE. reload_current_scene() on a Ranch built by a test would
## take the GUT runner's own tree with it, so the handler is split: _can_load() is the
## decision and _on_load_requested() is the act, and this file drives the decision.

const RanchScript := preload("res://world/ranch.gd")


func test_a_ranch_with_no_game_state_cannot_load() -> void:
	var ranch: Ranch = RanchScript.new()
	assert_false(ranch._can_load(), "no state, no load")
	ranch.free()
