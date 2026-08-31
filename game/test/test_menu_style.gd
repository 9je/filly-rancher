extends GutTest
## ONE LOOK FOR EVERY PANEL, and one place the keys at the bottom of it are written.

const MenuStyleScript := preload("res://ui/menu_style.gd")
const InputDeviceScript := preload("res://systems/input_device.gd")


func before_each() -> void:
	InputDeviceScript.reset()


## InputDevice._last IS STATIC AND OUTLIVES THIS FILE. Two tests here note a gamepad event,
## and a GAMEPAD left standing when the last one finishes is read by whatever script GUT
## runs next, which would make some other file's footer assertions pass or fail for a
## reason that file never chose. Put back the way it was found.
func after_all() -> void:
	InputDeviceScript.reset()


func test_the_caret_marks_the_row_and_pads_the_others_to_the_same_width() -> void:
	assert_eq(MenuStyleScript.caret(true).length(), MenuStyleScript.caret(false).length(),
		"a caret that is wider than the padding makes every row jump when it is selected")
	assert_ne(MenuStyleScript.caret(true), MenuStyleScript.caret(false))


func test_the_tab_strip_brackets_exactly_one_tab() -> void:
	var strip: String = MenuStyleScript.tab_strip(["Cage", "House", "Games"], 1)
	assert_true(strip.contains("[House]"))
	assert_false(strip.contains("[Cage]"))
	assert_false(strip.contains("[Games]"))


func test_a_tab_index_out_of_range_brackets_nothing_rather_than_erroring() -> void:
	var strip: String = MenuStyleScript.tab_strip(["Cage", "House"], 9)
	assert_false(strip.contains("["))


## THE REPORT: "show keyboard hints XOR gamepad hints based on the last input device used,
## not both at once". Every shipped footer printed both, on one line, forever.
func test_the_footer_shows_one_scheme_and_never_both() -> void:
	var keyboard: String = MenuStyleScript.footer_tabs_and_rows("confirm", "leave")
	assert_true(keyboard.contains("Enter"))
	assert_false(keyboard.contains("A  confirm"),
		"the gamepad glyph must not be on the keyboard footer")
	var pad := InputEventJoypadButton.new()
	InputDeviceScript.note(pad)
	var gamepad: String = MenuStyleScript.footer_tabs_and_rows("confirm", "leave")
	assert_false(gamepad.contains("Enter"),
		"the keyboard glyph must not be on the gamepad footer")
	assert_true(gamepad.contains("A"))


func test_the_footer_names_the_verb_it_is_given() -> void:
	assert_true(MenuStyleScript.footer_rows("build", "back").contains("build"))
	assert_true(MenuStyleScript.footer_rows("build", "back").contains("back"))


func test_the_reading_footer_offers_only_a_way_out() -> void:
	var line: String = MenuStyleScript.footer_reading("back")
	assert_true(line.contains("back"))
	assert_false(line.contains("confirm"),
		"a page with nothing to confirm must not offer to confirm it")


func test_every_footer_starts_with_the_same_indent() -> void:
	for line: String in [MenuStyleScript.footer_tabs_and_rows("confirm", "leave"),
			MenuStyleScript.footer_rows("build", "back"),
			MenuStyleScript.footer_reading("back")]:
		assert_true(line.begins_with(MenuStyleScript.NO_CARET),
			"footers line up under the rows: %s" % line)


func test_nothing_the_style_prints_carries_a_dash() -> void:
	var lines: Array[String] = [
		MenuStyleScript.footer_tabs_and_rows("confirm", "leave"),
		MenuStyleScript.footer_rows("sell", "back"),
		MenuStyleScript.footer_reading("back"),
		MenuStyleScript.tab_strip(["Deliver", "Pay", "Statement"], 0),
	]
	var pad := InputEventJoypadButton.new()
	InputDeviceScript.note(pad)
	lines.append(MenuStyleScript.footer_tabs_and_rows("confirm", "leave"))
	for line in lines:
		assert_false(line.contains("--") or line.contains("—"), line)


func test_styling_a_label_sets_a_size_and_a_colour_that_can_be_read_back() -> void:
	var label := Label.new()
	add_child_autofree(label)
	MenuStyleScript.style_label(label, MenuStyleScript.ROW_SIZE, MenuStyleScript.COLOR_VALUE)
	assert_eq(label.get_theme_font_size("font_size"), MenuStyleScript.ROW_SIZE)
	assert_eq(label.get_theme_color("font_color"), MenuStyleScript.COLOR_VALUE)


## THE READABILITY THE FOLD ONTO THIS FILE DROPPED (Ruling 28). build_menu.gd used to give
## every one of its own labels a black outline, with a comment saying why; the shared styler
## it was folded onto did not, so three panels lost it. It is applied in style_label() now,
## which means every menu in the game inherits it and this test answers for all of them.
func test_every_styled_label_gets_the_outline_that_makes_it_readable() -> void:
	var label := Label.new()
	add_child_autofree(label)
	MenuStyleScript.style_label(label, MenuStyleScript.TITLE_SIZE, MenuStyleScript.COLOR_TITLE)
	assert_eq(label.get_theme_color("font_outline_color"), MenuStyleScript.OUTLINE_COLOR,
		"unoutlined text over a bright green field is what this exists to stop")
	assert_eq(label.get_theme_constant("outline_size"), MenuStyleScript.OUTLINE_SIZE)
	assert_gt(MenuStyleScript.OUTLINE_SIZE, 0, "a zero width outline is no outline")


## THE PANELS THEMSELVES, not just the helper: every menu that draws a row draws it through
## style_label(), so opening one and reading a Label straight off it is the check that the
## inheritance is real rather than merely available.
func test_a_real_panel_draws_its_rows_with_the_outline() -> void:
	var menu: CasinoMenu = load("res://ui/casino_menu.tscn").instantiate()
	add_child_autofree(menu)
	menu.bits_provider = func() -> int: return 500
	menu.chips_provider = func() -> int: return 0
	assert_true(menu.open())
	var rows := menu.get_node(^"Centre/Panel/Margin/Column/Rows") as VBoxContainer
	assert_gt(rows.get_child_count(), 0, "the lobby drew rows to check")
	var row := rows.get_child(0) as Label
	assert_eq(row.get_theme_constant("outline_size"), MenuStyleScript.OUTLINE_SIZE)
