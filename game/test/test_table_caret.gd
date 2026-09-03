extends GutTest
## WHERE THE CARET POINTS, at all three tables in the Palace.
##
## THE BUG THIS PINS. TableMenu.refresh() drew the "> " marker on drawn line number
## `_selected`, and `_selected` counts SELECTABLE ROWS while drawn_lines() counts PRINTED
## LINES. Those two agree exactly until the first spin, hand or bet, after which every table
## prints the last result above its rows: two result lines and a blank. From then on the
## caret sat three lines above the row it was actually on, so the slot machine highlighted
## the words "Apple Apple Apple" while the player was adjusting her stake.
##
## READ OFF THE DRAWING, NOT OFF A NUMBER, and that rule survived the stage. The whole defect
## lived in the gap between the number and the drawing, and a test that asked the menu where
## it THOUGHT the caret was would have agreed with the bug. So this file asks two things that
## are both downstream of the paint: the text of the row the marker was actually drawn on,
## and focus_rect(), which is where the focus ring was actually put.
##
## Nodes already queue_free()d are skipped: refresh() frees the previous row of holders and
## builds new ones in the same call, and a freed child is still among get_children() until
## the next idle frame.

const SlotsMenuScene := preload("res://ui/slots_menu.tscn")
const WheelMenuScene := preload("res://ui/wheel_menu.tscn")
const BlackjackMenuScene := preload("res://ui/blackjack_menu.tscn")
const WheelScript := preload("res://systems/wheel.gd")

const CHIPS := 500


## The line the caret is actually drawn on, marker stripped, or "" if nothing is marked.
## Every cursor driven row is a Label inside a PanelContainer since the chrome pass.
func _caret_line(menu: CanvasLayer) -> String:
	for holder in menu._rows.get_children():
		if holder.is_queued_for_deletion():
			continue
		for child in holder.get_children():
			var label := child as Label
			if label != null and label.text.begins_with("> "):
				return label.text.substr(2)
	return ""


func _open(scene: PackedScene) -> CanvasLayer:
	var menu: CanvasLayer = scene.instantiate()
	add_child_autofree(menu)
	menu.set("can_open", func() -> bool: return true)
	menu.set("chips_provider", func() -> int: return CHIPS)
	menu.call("open")
	await get_tree().process_frame
	return menu


func test_the_slot_machine_marks_the_stake_row_before_and_after_a_spin() -> void:
	var menu: CanvasLayer = await _open(SlotsMenuScene)
	assert_true(_caret_line(menu).begins_with("Stake:"),
		"before any spin the caret is on the stake row: '%s'" % _caret_line(menu))
	var spun: Array[String] = ["Apple Apple Apple", "You win 40 chips."]
	menu.call("show_result", spun)
	assert_true(_caret_line(menu).begins_with("Stake:"),
		"after a spin the caret must still be on the stake row, not up in the result: '%s'"
			% _caret_line(menu))


func test_the_blackjack_table_marks_the_stake_row_before_and_after_a_hand() -> void:
	var menu: CanvasLayer = await _open(BlackjackMenuScene)
	assert_true(_caret_line(menu).begins_with("Stake:"),
		"before any hand the caret is on the stake row: '%s'" % _caret_line(menu))
	var dealt: Array[String] = ["You: Ace, King", "Dealer: Nine, Seven", "Blackjack."]
	menu.call("show_result", dealt)
	assert_true(_caret_line(menu).begins_with("Stake:"),
		"after a hand the caret must still be on the stake row: '%s'" % _caret_line(menu))


func test_the_wheel_marks_the_guess_it_is_backing_before_and_after_a_spin() -> void:
	var menu: CanvasLayer = await _open(WheelMenuScene)
	assert_eq(String(menu.call("focused_id")), "guess:0",
		"before any spin the focus is on the first bet")
	var spun: Array[String] = [WheelScript.pocket_text(7), "The house takes that one."]
	menu.call("show_result", spun)
	assert_eq(String(menu.call("focused_id")), "guess:0",
		"after a spin the focus must still be on the bet, not up in the result")


## And it follows the cursor all the way onto the stake row, which is the row that only
## exists because of the other half of this fix. See test_wheel_menu.gd.
func test_the_wheel_s_caret_follows_the_cursor_onto_the_stake_row() -> void:
	var menu: CanvasLayer = await _open(WheelMenuScene)
	var spun: Array[String] = [WheelScript.pocket_text(7), "The house takes that one."]
	menu.call("show_result", spun)
	menu.call("move_selection", int(menu.call("guess_count")))
	assert_eq(String(menu.call("focused_id")), "stake:0",
		"one press past the last colour is the stake row")


## THE RING IS SOMEWHERE, and it is somewhere on the panel. A focus_rect() of zero size is a
## menu that thinks it has a cursor and paints none, which is the same class of defect as the
## caret pointing at the wrong line: the number says one thing and the drawing says nothing.
func test_every_table_paints_its_focus_ring_somewhere_real() -> void:
	for scene: PackedScene in [SlotsMenuScene, WheelMenuScene, BlackjackMenuScene]:
		var menu: CanvasLayer = await _open(scene)
		var rect: Rect2 = menu.call("focus_rect")
		assert_gt(rect.size.x, 0.0, "%s painted a zero width focus" % scene.resource_path)
		assert_gt(rect.size.y, 0.0, "%s painted a zero height focus" % scene.resource_path)
		assert_ne(String(menu.call("focused_id")), "",
			"%s knows what it is focused on" % scene.resource_path)
