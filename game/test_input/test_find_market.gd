extends "res://test_input/input_test.gd"
## OWNER PLAYTEST 2026-10-25: "i cant find the market". From a fresh save, with the mouse and
## W only and nothing but what is on the screen: turn until the compass's coin (the Market)
## sits in the middle of the strip, walk at it, and the interaction line must offer the
## Market inside 25 seconds. The same for the pens' fence icon and the build prompt.


func _play() -> void:
	_deadline_s = 300.0
	if not await boot_new_game():
		return
	if not await finish_creator():
		return
	await close_letter()
	await talk_through(40.0)
	var compass: Node = ranch.get_node_or_null(^"HUD/Compass")
	if not check(compass != null, "there is no compass on the HUD"):
		return
	var hud: Node = ranch.get_node(^"HUD")
	for goal: Array in [["Market", "Market"], ["Pens", "build here"]]:
		var idx := -1
		var places: Array = compass.get("places")
		for i in places.size():
			if String(places[i].name) == goal[0]:
				idx = i
		if not check(idx >= 0, "the compass has no %s" % goal[0]):
			return
		var t := 0.0
		var found := false
		while t < 25.0:
			if bool(ranch.get("people").call("is_talking")):
				await talk_through(20.0)
			var st: Dictionary = compass.call("icon_state", idx)
			# Steer by the icon: off centre, turn toward it; centred, run.
			var off: float = (float(st.get("x", 0.0)) - 310.0) if bool(st.get("visible", false)) else 400.0
			if absf(off) > 12.0:
				RI.look(Vector2(clampf(off * 0.6, -60.0, 60.0), 0))
				RI.release(&"move_forward")
			else:
				RI.press(&"move_forward")
			await wait(0.1)
			t += 0.1
			if String(hud.call("prompt_text")).contains(goal[1]):
				found = true
				break
		RI.release(&"move_forward")
		if not check(found, "following the compass never reached the %s (prompt '%s')"
				% [goal[0], hud.call("prompt_text")]):
			return
		note("reached the %s in %.1f s" % [goal[0], t])
	ok("the compass leads to the Market and to the pens")
