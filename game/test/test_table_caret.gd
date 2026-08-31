extends GutTest
## WHERE THE CARET POINTS, at all three tables in the Palace.
##
## THE BUG THIS PINS. TableMenu.refresh() drew the "> " marker on drawn line number
## `_selected`, and `_selected` counts SELECTABLE ROWS while drawn_lines() counts PRINTED
## LINES. Those two agree exactly until the first spin, hand or bet, after which every table
## prints the last result above its rows: two result lines and a blank. From then on the
## caret sat three lines above the row it was actually on, so the slot machine highlighted
## the words "Apple Apple Apple" while the player was adjusting her stake, and the wheel
## highlighted the pocket the ball had just landed in while she was choosing the next one.
## Nothing behaved wrongly; the panel simply pointed at the wrong thing, which on a menu
## driven entirely by a cursor is the same thing as behaving wrongly.
##
## THE FIX IS ONE VIRTUAL. TableMenu.first_row_line_index() says how many lines a table
## prints above its first selectable row (zero by default), and refresh() adds it.
##
## READ OFF THE LABELS, NOT OFF A NUMBER. This walks the Label nodes refresh() actually
## built, because the whole defect lived in the gap between the number and the drawing, and
## a test that asked the menu where it thought the caret was would have agreed with the bug.
## Nodes already queue_free()d are skipped: refresh() frees the previous row of labels and
## builds new ones in the same call, and a freed child is still among get_children() until
## the next idle frame.

const SlotsMenuScene := preload("res://ui/slots_menu.tscn")
const WheelMenuScene := preload("res://ui/wheel_menu.tscn")
const BlackjackMenuScene := preload("res://ui/blackjack_menu.tscn")
const WheelScript := preload("res://systems/wheel.gd")

const CHIPS := 500


## The line the caret is actually drawn on, marker stripped, or "" if nothing is marked.
func _caret_line(menu: CanvasLayer) -> String:
	for child in menu._rows.get_children():
		if child.is_queued_for_deletion():
			continue
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
	return menu


func test_the_slot_machine_marks_the_stake_row_before_and_after_a_spin() -> void:
	var menu: CanvasLayer = _open(SlotsMenuScene)
	assert_true(_caret_line(menu).begins_with("Stake:"),
		"before any spin the caret is on the stake row: '%s'" % _caret_line(menu))
	# A two line result and the blank drawn under it: exactly what every table pushes after
	# a play, and exactly the offset the caret used to be wrong by. Typed before the call
	# rather than at it, for the reason ranch.gd's play_slots() gives.
	var spun: Array[String] = ["Apple Apple Apple", "You win 40 chips."]
	menu.call("show_result", spun)
	assert_true(_caret_line(menu).begins_with("Stake:"),
		"after a spin the caret must still be on the stake row, not up in the result: '%s'"
			% _caret_line(menu))


func test_the_blackjack_table_marks_the_stake_row_before_and_after_a_hand() -> void:
	var menu: CanvasLayer = _open(BlackjackMenuScene)
	assert_true(_caret_line(menu).begins_with("Stake:"),
		"before any hand the caret is on the stake row: '%s'" % _caret_line(menu))
	var dealt: Array[String] = ["You: Ace, King", "Dealer: Nine, Seven", "Blackjack."]
	menu.call("show_result", dealt)
	assert_true(_caret_line(menu).begins_with("Stake:"),
		"after a hand the caret must still be on the stake row: '%s'" % _caret_line(menu))


func test_the_wheel_marks_the_guess_it_is_backing_before_and_after_a_spin() -> void:
	var menu: CanvasLayer = _open(WheelMenuScene)
	var first_colour: String = "Back %s at %d to 1" \
		% [WheelScript.COLOUR_NAMES[0], WheelScript.COLOUR_PAYS_TO_ONE]
	assert_eq(_caret_line(menu), first_colour, "before any spin the caret is on the first bet")
	var spun: Array[String] = [WheelScript.pocket_text(7), "The house takes that one."]
	menu.call("show_result", spun)
	assert_eq(_caret_line(menu), first_colour,
		"after a spin the caret must still be on the bet row, not up in the result")


## And it follows the cursor all the way onto the stake row, which is the row that only
## exists because of the other half of this fix. See test_wheel_menu.gd.
func test_the_wheel_s_caret_follows_the_cursor_onto_the_stake_row() -> void:
	var menu: CanvasLayer = _open(WheelMenuScene)
	var spun: Array[String] = [WheelScript.pocket_text(7), "The house takes that one."]
	menu.call("show_result", spun)
	menu.call("move_selection", int(menu.call("guess_count")))
	assert_true(_caret_line(menu).begins_with("Stake:"),
		"one press past the last colour is the stake row: '%s'" % _caret_line(menu))
