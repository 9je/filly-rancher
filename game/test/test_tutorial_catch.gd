extends GutTest
## "CATCH A PONY WITH YOUR MAGIC BEAM" NEVER TICKED (bot render review, 2026-10-26). The
## Getting started list's first task is a CATCH_ANY request, and ranch.gd's
## _on_pony_captured() returned before telling the board whenever the pony was a stock
## Drifter, which in the first minutes is every pony there is: six catches in and the first
## lesson still sat unticked under a ticked second one. The early return was for the
## Compendium (a Drifter has no page); the board was caught in it by being below it.

const RanchScript := preload("res://world/ranch.gd")
const GameStateScript := preload("res://systems/game_state.gd")
const RequestBoardScript := preload("res://systems/request_board.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")


class FakePlayer:
	extends CharacterBody3D

	func get_magic_beam() -> Node3D:
		return null


func test_a_drifter_caught_ticks_the_first_lesson() -> void:
	var ranch: RanchScript = autofree(RanchScript.new())
	var p := FakePlayer.new()
	add_child_autofree(p)
	ranch.player = p
	var state: Node = autofree(GameStateScript.new())
	ranch._game_state = state
	var none: Array[StringName] = []
	var roster: PonyRegistry = (load("res://systems/pony_registry.gd") as GDScript).new()
	roster.load_all("res://data/ponies")
	ranch._board = RequestBoardScript.new(7, roster, none, {})
	ranch._board.seed_tutorial()
	var drifter: PonyInstance = PonyInstanceScript.create(&"twilight", 1)
	drifter.stock = {"seed": 4242}
	assert_true(drifter.is_stock(), "sanity: one of the crowd")
	ranch._on_pony_captured(drifter)
	var first: Dictionary = ranch._board.tutorial_rows()[0] if not ranch._board.tutorial_rows().is_empty() else {}
	assert_true(first.is_empty() or String(first.get("id", "")) != "tutorial_catch",
		"the catch lesson is done and paid, so it has left the list")
