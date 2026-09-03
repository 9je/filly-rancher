extends GutTest
## THE CONTRACT EVERY DRAWN CASINO SCREEN HOLDS, asked of all five of them by one loop.
##
## THE CONTRACT IS CONDITIONAL, NOT DEFERRED. A red suite between tasks would mask a real
## regression the next task introduces, so this file never goes red waiting for Tasks 4
## through 7. STAGED below is the declaration that a menu has grown a real stage; until a
## menu's own path is in it, the correct and currently TRUE state is the TableMenu/CasinoMenu
## base -- stage_size() is Vector2.ZERO, paint() draws nothing (and does not crash), and
## printed_lines() is exactly drawn_lines(), because nothing has moved onto a stage yet to
## warrant dropping a line from the Rows column. Both branches below assert something real;
## neither is vacuous.
##
## WHY THIS FILE IS NOT FIVE FILES. These are not five assertions about five screens; they
## are one assertion about the stage mechanism, and a per screen copy of it would drift. The
## screen specific geometry (a reel window is 180 by 300, a lobby tile is 340 by 200) is
## asserted in each screen's own test file by its own *_rect() function, once that screen is
## staged.
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

## EACH OF TASKS 4 TO 7 APPENDS ITS OWN MENU HERE, in the same commit that overrides
## paint()/stage_size()/printed_lines()/focus_rect()/focused_id() for real. Empty is the
## correct state through Task 3: every menu still draws through the TableMenu/CasinoMenu
## base. The look pass (Task 9) expects all five present.
##
## THIS IS THE ONE SOURCE OF TRUTH. game/scenes/test/casino_test.gd's gate block preloads
## this very script and reads STAGED directly off it rather than keeping a second copy, so
## the two can never quietly drift apart; see that file's own comment on the stage block.
const STAGED: Array[String] = ["res://ui/slots_menu.tscn", "res://ui/wheel_menu.tscn",
	"res://ui/blackjack_menu.tscn"]

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


## EVERY STAGED SCREEN HAS A STAGE OF THE SHARED WIDTH; EVERY OTHER SCREEN RESERVES NONE
## YET. A staged stage that instantiated at zero size draws nothing and would pass every
## OTHER geometry test in the branch; an unstaged screen that somehow reserved space would
## mean its column is already lying about how much room its rows have, ahead of its own
## task landing.
func test_every_screen_has_the_stage_size_its_task_promises() -> void:
	for path: String in MenuScenes:
		var menu: CanvasLayer = await _open(path)
		var size: Vector2 = menu.call("stage_size")
		if STAGED.has(path):
			assert_almost_eq(size.x, 1120.0, 1.0, "%s stage width" % path)
			assert_gt(size.y, 100.0, "%s stage height" % path)
		else:
			assert_eq(size, Vector2.ZERO, "%s has not been staged yet and reserves nothing"
				% path)


## PAINT NEVER CRASHES THE SCREEN, staged or not. queue_redraw() only SCHEDULES a draw; a
## second frame proves paint() actually ran under NOTIFICATION_DRAW rather than merely being
## queued. An unstaged screen paints nothing (the TableMenu/CasinoMenu base is a no-op), which
## trivially cannot crash; a staged screen paints for real, and this is the one test in the
## file that would catch a paint() that throws regardless of what its own screen-specific
## test file checks about the picture it draws.
func test_paint_does_not_crash_any_screen() -> void:
	for path: String in MenuScenes:
		var menu: CanvasLayer = await _open(path)
		await get_tree().process_frame
		await get_tree().process_frame
	pass_test("every screen painted two frames without raising")


## THE MODEL KEEPS SAYING EVERYTHING. drawn_lines() is the whole text model and is what
## test_published_payouts.gd parses. An unstaged screen has not moved anything onto a stage,
## so its printed column IS the whole model, exactly -- not merely a subset of it. A staged
## screen may have dropped a line onto its stage, so printed_lines() there is only asserted to
## be a subset that never invents a sentence the model does not carry.
func test_every_printed_line_is_still_in_the_text_model() -> void:
	for path: String in MenuScenes:
		var menu: CanvasLayer = await _open(path)
		var model: Array[String] = menu.call("drawn_lines")
		var printed: Array[String] = menu.call("printed_lines")
		if STAGED.has(path):
			assert_lte(printed.size(), model.size(), "%s prints no more than it models" % path)
			for line: String in printed:
				assert_true(model.has(line), "%s printed a line the model does not carry: '%s'"
					% [path, line])
		else:
			assert_eq(printed, model,
				"%s has not staged anything, so its printed column is the whole model" % path)


## THE RING GOES WHERE THE CURSOR IS, on every row of every tab, on every screen -- ALWAYS
## somewhere real (a non empty id, a non empty rect), the same way the pre-stage caret always
## painted on a real row. UNIQUE per row is the stronger half of the contract, and it is only
## guaranteed once a screen is staged: SlotsMenu and BlackjackMenu still route move_selection()
## through `_stake_index` rather than `_selected` (pre-existing, unstaged code), so the base
## `"row:%d" % _selected` cannot yet tell their rows apart -- exactly the gap Tasks 4 and 6
## close by giving each screen its own vocabulary (`stake:<n>`, `guess:<n>`, ...).
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
				var rect: Rect2 = menu.call("focus_rect")
				assert_ne(String(id), "", "%s tab %d row %d has no focus id"
					% [path, tab, row])
				assert_gt(rect.size.x * rect.size.y, 0.0,
					"%s tab %d row %d painted an empty focus" % [path, tab, row])
				if STAGED.has(path):
					assert_false(seen.has(id),
						"%s tab %d gave two rows the same focus id: %s" % [path, tab, id])
				seen[id] = true


## A PUSH WITH A VALUE FROM OUTSIDE THE GAME MUST DEGRADE TO A STILL FRAME. These arrive over
## a dynamic call() from ranch.gd, so nothing type checks them at the call site. Once a table
## is staged it grows its own show_spin()/show_hand() push, and an out of range value through
## THAT push is the exact scenario this test exists for. Until then a table's only push is the
## base show_result(), which already exists and is already exercised elsewhere; running a page
## of garbage through it here is the same exercise (a bad push must not take the screen down)
## aimed at the push that actually exists today.
func test_a_bad_push_degrades_to_a_still_frame() -> void:
	const GARBAGE: Array[String] = ["", "-1", "not a real result", "%d" % 99999999]
	for path: String in ["res://ui/slots_menu.tscn", "res://ui/wheel_menu.tscn",
			"res://ui/blackjack_menu.tscn"]:
		var menu: CanvasLayer = await _open(path)
		if STAGED.has(path):
			match path:
				"res://ui/slots_menu.tscn":
					menu.call("show_spin", [] as Array[int], 0, 10)
					menu.call("show_spin", [99, -1, 400] as Array[int], 0, 10)
				"res://ui/wheel_menu.tscn":
					menu.call("show_spin", 99, 0, 10)
					menu.call("show_spin", -7, 0, 10)
				"res://ui/blackjack_menu.tscn":
					menu.call("show_hand", {} as Dictionary, 0, 10)
					menu.call("show_hand",
						{"player": [300, -4] as Array[int], "dealer": [] as Array[int],
							"outcome": 9}, 0, 10)
		else:
			menu.call("show_result", GARBAGE)
		await get_tree().process_frame
		assert_true(bool(menu.call("is_open")), "%s is still standing after a bad push" % path)
	pass_test("bad pushes and the screens are still standing")


## THE DECLARATION IS HONEST. A path in STAGED that could not actually pass the full stage
## contract would be a screen marked staged while still drawing through the base -- a lie
## every OTHER test above would just quietly start skipping rather than catch. Duplicates and
## unknown paths are the same class of lie: this is what makes flipping an entry here a
## conscious, single line act rather than silent coverage creep.
func test_the_staged_list_is_honest() -> void:
	var seen: Dictionary = {}
	for path: String in STAGED:
		assert_true(MenuScenes.has(path), "%s in STAGED is not one of the five known menus"
			% path)
		assert_false(seen.has(path), "%s appears twice in STAGED" % path)
		seen[path] = true
		var menu: CanvasLayer = await _open(path)
		var size: Vector2 = menu.call("stage_size")
		assert_almost_eq(size.x, 1120.0, 1.0,
			"%s claims STAGED but its stage width is wrong" % path)
		assert_gt(size.y, 100.0, "%s claims STAGED but its stage height is wrong" % path)
	pass_test("STAGED has %d honest entries" % STAGED.size())
