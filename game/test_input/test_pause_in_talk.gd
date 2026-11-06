extends "res://test_input/input_test.gd"
## OWNER PLAYTEST 2026-11-05 (item 12): "i cant pause in convo". From a fresh save, wait for
## Marigold's welcome; press the pause key mid conversation: the pause menu opens and the talk
## box steps aside; press it again: the same conversation is back on screen.


func _play() -> void:
	if not await boot_new_game():
		return
	if not await finish_creator():
		return
	await wait(1.0)
	await close_letter()
	var people: Node = ranch.get("people")
	var t := 0.0
	while t < 60.0 and not bool(people.call("is_talking")):
		await wait(0.25)
		t += 0.25
	if not check(bool(people.call("is_talking")), "nobody started a conversation in a minute"):
		return
	var talk: CanvasLayer = people.get("talk_box")
	var pause: CanvasLayer = ranch.call("get_pause_menu")
	await tap(&"pause")
	await wait(0.4)
	if not check(bool(pause.call("is_open")), "the pause key did nothing mid conversation"):
		return
	if not check(not talk.visible, "the talk box stayed over the pause menu"):
		return
	await tap(&"pause")
	await wait(0.4)
	if not check(not bool(pause.call("is_open")), "the pause menu did not close"):
		return
	if not check(bool(people.call("is_talking")) and talk.visible, "the conversation did not come back"):
		return
	if not check(not ranch.get_tree().paused, "the world stayed paused after the pause menu closed (checkpoint review soft-lock)"):
		return
	ok("paused mid conversation and came back to the same line, the world running")
