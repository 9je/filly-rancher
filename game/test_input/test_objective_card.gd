extends "res://test_input/input_test.gd"
## THE OBJECTIVE CARD IN PLAY (owner playtest 2026-10-25: "idk what to do anymore"). From a
## fresh save, once Marigold hands over the Scoop the card under the compass names the next
## step and how far it is; following the compass's gold goal ring with the mouse and W only,
## the distance on the card falls.


func _play() -> void:
	_deadline_s = 300.0
	if not await boot_new_game():
		return
	if not await finish_creator():
		return
	await close_letter()
	# Marigold walks over and opens the welcome, which hands over the Scoop.
	var people: Node = ranch.get("people")
	var lp: Node = ranch.get("letter_panel")
	var waited := 0.0
	while waited < 60.0 and not ranch.call("get_story").has_flag("has_scoop"):
		if bool(people.call("is_talking")):
			await talk_through()
		elif bool(lp.call("is_open")):
			await click(lp.call("close_button_node"))
		await wait(0.2)
		waited += 0.2
	if not check(ranch.call("get_story").has_flag("has_scoop"), "Marigold never handed over the Scoop"):
		return
	var card: Node = ranch.get_node_or_null(^"HUD/ObjectiveCard")
	var compass: Node = ranch.get_node_or_null(^"HUD/Compass")
	if not check(card != null and compass != null, "no objective card or compass on the HUD"):
		return
	await wait(1.0)
	if not check(bool(card.get("visible")), "the card is hidden after the Scoop"):
		return
	var words := String(card.call("words"))
	if not check(words.length() > 3, "the card has no words"):
		return
	var first := _metres(card)
	note("guide goal %s, ring %s, objective %s" % [ranch.call("guide_goal"), compass.call("goal_state"), ranch.call("current_objective")])
	note("the card says '%s' at %s" % [words, card.call("distance_text")])
	var t := 0.0
	while t < 12.0:
		if bool(ranch.get("people").call("is_talking")):
			await talk_through(20.0)
		var st: Dictionary = compass.call("goal_state")
		var off: float = (float(st.get("x", 0.0)) - 310.0) if bool(st.get("visible", false)) else 400.0
		if absf(off) > 12.0:
			RI.look(Vector2(clampf(off * 0.6, -60.0, 60.0), 0))
			RI.release(&"move_forward")
		else:
			RI.press(&"move_forward")
		await wait(0.1)
		t += 0.1
	RI.release(&"move_forward")
	var last := _metres(card)
	note("after: guide goal %s, ring %s, card %s" % [ranch.call("guide_goal"), compass.call("goal_state"), card.call("distance_text")])
	if first > 6.0:
		if not check(last < first - 3.0, "following the goal ring the card went %.0f m to %.0f m" % [first, last]):
			return
	ok("the card names '%s', and walking the way it shows took it from %.0f m to %.0f m" % [words, first, last])


func _metres(card: Node) -> float:
	var txt := String(card.call("distance_text"))
	if txt == "here":
		return 0.0
	return float(txt.trim_suffix(" m")) if txt.ends_with(" m") else -1.0
