extends GutTest
## THE CONTRACT EVERY DRAWN CASINO SCREEN HOLDS, asked of all five of them by one loop.
##
## WHY THIS FILE IS NOT FIVE FILES. These are not five assertions about five screens; they
## are one assertion about the stage mechanism, and a per screen copy of it would drift. The
## screen specific geometry (a reel window is 180 by 300, a lobby tile is 340 by 200) is
## asserted in each screen's own test file by its own *_rect() function.
##
## LAYOUT IS ONLY VALID AFTER A FRAME. A Control's rect is whatever it was before the
## container has run, so every helper below awaits one after open().

const MenuScenes: Array[String] = [
	"res://ui/slots_menu.tscn",
	"res://ui/wheel_menu.tscn",
	"res://ui/blackjack_menu.tscn",
	"res://ui/race_menu.tscn",
	"res://ui/casino_menu.tscn",
]

const CHIPS := 500
const BITS := 500


func _open(path: String) -> CanvasLayer:
	var menu: CanvasLayer = (load(path) as PackedScene).instantiate()
	add_child_autofree(menu)
	menu.set("can_open", func() -> bool: return true)
	menu.set("chips_provider", func() -> int: return CHIPS)
	if menu.has_method("header_line"):
		menu.set("bits_provider", func() -> int: return BITS)
		menu.set("sign_provider", func() -> Array[String]:
			return ["House rules", "Every edge we keep."] as Array[String])
	if "entrants_provider" in menu:
		menu.set("entrants_provider", func() -> Array[Dictionary]: return [
			{"uid": &"a", "name": "Mote", "happiness": 0.8, "odds": 3.5, "chance": 0.28},
			{"uid": &"b", "name": "Pip", "happiness": 0.4, "odds": 7.0, "chance": 0.14},
		] as Array[Dictionary])
	assert_true(bool(menu.call("open")), "%s opened" % path)
	await get_tree().process_frame
	return menu


## EVERY SCREEN HAS A STAGE, AND IT IS THE WIDTH THE PANEL WAS WIDENED TO. A stage that
## instantiated at zero size draws nothing and would pass every geometry test in the branch.
func test_every_casino_screen_has_a_stage_of_the_shared_width() -> void:
	for path: String in MenuScenes:
		var menu: CanvasLayer = await _open(path)
		var size: Vector2 = menu.call("stage_size")
		assert_almost_eq(size.x, 1120.0, 1.0, "%s stage width" % path)
		assert_gt(size.y, 100.0, "%s stage height" % path)


## THE MODEL KEEPS SAYING EVERYTHING. printed_lines() is what the Rows column still prints;
## drawn_lines() is the whole text model and is what test_published_payouts.gd parses. A
## printed line that is not in the model would be a sentence no test can see.
func test_every_printed_line_is_still_in_the_text_model() -> void:
	for path: String in MenuScenes:
		var menu: CanvasLayer = await _open(path)
		var model: Array[String] = menu.call("drawn_lines")
		var printed: Array[String] = menu.call("printed_lines")
		assert_lte(printed.size(), model.size(), "%s prints no more than it models" % path)
		for line: String in printed:
			assert_true(model.has(line), "%s printed a line the model does not carry: '%s'"
				% [path, line])


## THE RING GOES WHERE THE CURSOR IS, on every row of every tab, on every screen. This is the
## whole reason focus_rect() and focused_id() exist rather than a bare index: the defect
## test_table_caret.gd was written for lived entirely in the gap between the two.
func test_the_focus_follows_the_cursor_across_every_row_of_every_tab() -> void:
	for path: String in MenuScenes:
		var menu: CanvasLayer = await _open(path)
		var tabs: int = 3 if menu.has_method("header_line") else 2
		for tab: int in tabs:
			if menu.has_method("set_tab"):
				menu.call("set_tab", tab)
				await get_tree().process_frame
			var seen: Dictionary = {}
			var rows: int = int(menu.call("row_count")) if menu.has_method("row_count") \
				else int(menu.call("_row_count"))
			for row: int in rows:
				menu.call("move_selection", 1 if row > 0 else 0)
				await get_tree().process_frame
				var id: StringName = menu.call("focused_id")
				assert_ne(String(id), "", "%s tab %d row %d has no focus id"
					% [path, tab, row])
				assert_false(seen.has(id),
					"%s tab %d gave two rows the same focus id: %s" % [path, tab, id])
				seen[id] = true
				var rect: Rect2 = menu.call("focus_rect")
				assert_gt(rect.size.x * rect.size.y, 0.0,
					"%s tab %d row %d painted an empty focus" % [path, tab, row])


## A PUSH WITH A VALUE FROM OUTSIDE THE GAME MUST DEGRADE TO A STILL FRAME. These arrive over
## a dynamic call() from ranch.gd, so nothing type checks them at the call site; a gate
## calling play_wheel() directly can hand a menu a pocket that does not exist, and the answer
## to that is a screen that shows nothing rather than a screen that takes the game down.
func test_an_out_of_range_push_degrades_to_a_still_frame() -> void:
	var slots: CanvasLayer = await _open("res://ui/slots_menu.tscn")
	slots.call("show_spin", [] as Array[int], 0, 10)
	slots.call("show_spin", [99, -1, 400] as Array[int], 0, 10)
	var wheel: CanvasLayer = await _open("res://ui/wheel_menu.tscn")
	wheel.call("show_spin", 99, 0, 10)
	wheel.call("show_spin", -7, 0, 10)
	var blackjack: CanvasLayer = await _open("res://ui/blackjack_menu.tscn")
	blackjack.call("show_hand", {} as Dictionary, 0, 10)
	blackjack.call("show_hand",
		{"player": [300, -4] as Array[int], "dealer": [] as Array[int], "outcome": 9}, 0, 10)
	await get_tree().process_frame
	pass_test("four bad pushes and the screens are still standing")
