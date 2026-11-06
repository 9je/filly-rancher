extends GutTest
## NOTHING ON THE HUD SITS ON ANYTHING ELSE (PT5; playtest 2026-11-05 items 22, 24, 42, 60).
## Everything up at once -- the checklist, the objective card, a long toast, the catch card,
## an eighteen slot saddlebag -- at every text size: every card is on screen and no two of
## them overlap. The UI canvas is 1920x1080 at every window size (project.godot).

const HudScene := preload("res://ui/hud.tscn")
const StorageScript := preload("res://systems/storage.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const ObjectiveCardScript := preload("res://ui/objective_card.gd")
const CANVAS := Rect2(0, 0, 1920, 1080)
const LONG := "Pip: \"Smile! Cloudsdale wants you for the newsletter!\" Steward of the Week: 12 ponies placed, \"a yield of 124% above the valley average.\""


func _rect(c: Control) -> Rect2:
	return c.get_global_rect()


func test_every_card_is_on_screen_and_clear_of_every_other() -> void:
	for scale: float in [1.0, 1.25, 1.5]:
		MenuStyle.text_scale = scale
		var hud: CanvasLayer = HudScene.instantiate()
		add_child_autofree(hud)
		var card: Control = ObjectiveCardScript.new()
		hud.add_child(card)
		await wait_process_frames(2)
		hud.call("set_tasks", [{"id": &"catch", "done": false}, {"id": &"pen", "done": false},
			{"id": &"sell", "done": false}])
		card.show_objective({"id": &"talk", "icon": 0, "words": "Somepony has news"}, 11.0)
		hud.call("toast", LONG)
		var bag := StorageScript.new(18)
		hud.set("_storage", bag)
		hud.call("_on_storage_changed")
		hud.call("_on_captured", PonyInstanceScript.create(&"twilight"))
		await wait_process_frames(30)
		var named := {
			"toast": hud.get_node("Toast") as Control,
			"bag": hud.get_node("Bag") as Control,
			"tasks": hud.get_node("Tasks") as Control,
			"objective": card.get_child(0) as Control,
			"catch card": hud.call("catch_card") as Control,
		}
		var rects := {}
		for k: String in named:
			var c: Control = named[k]
			if c == null or not c.is_visible_in_tree():
				continue
			var r := _rect(c)
			rects[k] = r
			var screen: Rect2 = hud.get_viewport().get_visible_rect()
			assert_true(screen.encloses(r), "%s is on screen at %d%% (%s)" % [k, int(scale * 100), r])
		var keys := rects.keys()
		for i in keys.size():
			for j in range(i + 1, keys.size()):
				assert_false((rects[keys[i]] as Rect2).intersects(rects[keys[j]]),
					"%s and %s overlap at %d%%" % [keys[i], keys[j], int(scale * 100)])
		# The pips stay inside the bag card.
		var pips := hud.get_node("Bag/Pips") as Control
		assert_lte(pips.custom_minimum_size.x, (hud.get_node("Bag") as Control).size.x + 1.0,
			"the eighteen slots stay on the card")
	MenuStyle.text_scale = 1.0


func test_a_long_toast_wraps_rather_than_crossing_the_screen() -> void:
	var hud: CanvasLayer = HudScene.instantiate()
	add_child_autofree(hud)
	await wait_process_frames(2)
	hud.call("toast", LONG)
	var t := hud.get_node("Toast") as Control
	assert_lte(t.size.x, 905.0)


func test_a_long_toast_stays_long_enough_to_read_and_waits_out_a_pause() -> void:
	assert_gt(preload("res://ui/hud.gd").toast_hold_for(LONG), 5.0, "about a third of a second a word")
	var hud: CanvasLayer = HudScene.instantiate()
	add_child_autofree(hud)
	await wait_process_frames(2)
	hud.call("toast", "Short line.")
	var left: float = hud.call("toast_seconds_left")
	hud.call("set_overlay_open", true)
	await wait_process_frames(30)
	assert_almost_eq(float(hud.call("toast_seconds_left")), left, 0.05, "a menu up holds the line")
	hud.call("set_overlay_open", false)
