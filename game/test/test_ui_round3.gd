extends GutTest
## Fable AAA round 3's UI items, the facts under the renders (docs/fable-aaa-round3-2026-11-09.md
## #6 and #9).

const HudScene := preload("res://ui/hud.tscn")
const RaceMenuScene := preload("res://ui/race_menu.tscn")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")


func _hud() -> CanvasLayer:
	var hud: CanvasLayer = HudScene.instantiate()
	add_child_autofree(hud)
	return hud


## The compass strip and the objective card hang off the HUD (ranch.gd mounts them there), so
## they step out with it for the catch's beat and come back after.
func test_the_compass_and_objective_hide_for_the_catch_beat() -> void:
	var hud := _hud()
	var compass := Control.new()
	compass.name = "Compass"
	hud.add_child(compass)
	var objective := Control.new()
	objective.name = "ObjectiveCard"
	hud.add_child(objective)
	await get_tree().process_frame
	assert_true(compass.is_visible_in_tree())
	var card: Control = hud.call("catch_card")
	card.call("show_catch", PonyInstanceScript.create(&"fluttershy"), null)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(compass.is_visible_in_tree(), "the compass steps out for the beat")
	assert_false(objective.is_visible_in_tree(), "and so does the objective")
	assert_true(card.is_visible_in_tree(), "the card stays")


## The toast sits on the saddlebag, at its left, not over the pony in the middle.
func test_the_toast_sits_above_the_saddlebag() -> void:
	var hud := _hud()
	for i in 4:
		await get_tree().process_frame
	hud.call("toast", "Lark Wish moved into the pen. It is now full.")
	var r: Rect2 = hud.call("toast_rect")
	var bag := hud.get_node(^"BagCard") as Control
	assert_lte(r.end.y, bag.position.y, "its foot is above the bag card")
	assert_almost_eq(r.position.x, bag.position.x, 1.0, "its left end is the bag's")
	assert_lt(r.get_center().x, 960.0 - 100.0, "and it is not centred over the pony")


## The guide is as tall as its cards: no blank hit rows under the stake chips.
func test_the_race_guide_has_no_blank_rows_under_it() -> void:
	var menu: CanvasLayer = RaceMenuScene.instantiate()
	add_child_autofree(menu)
	menu.set("can_open", func() -> bool: return true)
	menu.set("chips_provider", func() -> int: return 400)
	menu.set("entrants_provider", func() -> Array[Dictionary]: return [
		{"uid": &"a", "name": "Mote", "happiness": 0.8, "odds": 3.5, "chance": 0.28},
	] as Array[Dictionary])
	assert_true(bool(menu.call("open")))
	var rows := menu.get_node(^"Centre/Panel/Margin/Column/Rows") as VBoxContainer
	var live := 0
	for child in rows.get_children():
		if not child.is_queued_for_deletion():
			live += 1
	assert_eq(live, 0, "nothing printed, so no rows")
	assert_false(rows.visible)
