extends GutTest
## THE LATCH BETWEEN THE TITLE SCREEN AND THE RANCH. There is no field on GameState for this
## and there must not be: game/systems/ is read only for the whole presentation phase. A
## static on a script under game/world/ survives a change_scene_to_file() the same way, costs
## nothing, and is consumed exactly once.

const BootIntentScript := preload("res://world/boot_intent.gd")


func before_each() -> void:
	BootIntentScript.clear()


func after_each() -> void:
	BootIntentScript.clear()


func test_a_fresh_process_intends_nothing() -> void:
	assert_false(BootIntentScript.peek_new_game(),
		"a bare boot of ranch.tscn must behave exactly as it always has")


func test_requesting_a_new_game_is_visible_to_a_peek() -> void:
	BootIntentScript.request_new_game()
	assert_true(BootIntentScript.peek_new_game())
	assert_true(BootIntentScript.peek_new_game(), "peeking does not consume")


func test_consuming_answers_once_and_then_stops() -> void:
	BootIntentScript.request_new_game()
	assert_true(BootIntentScript.consume_new_game())
	assert_false(BootIntentScript.consume_new_game(),
		"a reloaded scene must not start a second new game")
	assert_false(BootIntentScript.peek_new_game())


func test_clear_forgets_a_request_nobody_consumed() -> void:
	BootIntentScript.request_new_game()
	BootIntentScript.clear()
	assert_false(BootIntentScript.peek_new_game())
