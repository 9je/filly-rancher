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
	assert_eq(MenuStyleScript.OUTLINE_SIZE, 0, "PT5: no outline; it made every word heavy")


## THE PANELS THEMSELVES, not just the helper: every menu that draws a row draws it through
## style_label(), so opening one and reading a Label straight off it is the check that the
## inheritance is real rather than merely available.
##
## THE CAGE TAB, NOT THE LOBBY. Phase 3 polish moved the lobby's six rows onto its own drawn
## stage (CasinoMenu.paint()'s LOBBY case), so the Rows VBox column is empty on that tab now;
## the cage still prints its three line explainer into that same column
## (CasinoMenu.printed_lines()'s CAGE case), which is what this test needs a real row from.
func test_a_real_panel_draws_its_rows_with_the_outline() -> void:
	var menu: CasinoMenu = load("res://ui/casino_menu.tscn").instantiate()
	add_child_autofree(menu)
	menu.bits_provider = func() -> int: return 500
	menu.chips_provider = func() -> int: return 0
	assert_true(menu.open())
	menu.set_tab(CasinoMenu.Tab.CAGE)
	var rows := menu.get_node(^"Centre/Panel/Margin/Column/Rows") as VBoxContainer
	assert_gt(rows.get_child_count(), 0, "the cage drew rows to check")
	var holder := rows.get_child(0) as PanelContainer
	assert_not_null(holder)
	var row := holder.get_child(0) as Label
	assert_eq(row.get_theme_constant("outline_size"), MenuStyleScript.OUTLINE_SIZE)


## ONE PANEL STYLE, NOT TEN COPIES. The MenuPanel StyleBoxFlat was duplicated verbatim into
## every menu .tscn in the game, so "change the look of a panel" meant editing ten scene
## files and getting one of them wrong.
func test_the_panel_style_is_one_shared_instance_with_the_shipped_numbers() -> void:
	var a: StyleBox = MenuStyleScript.panel_style()
	var b: StyleBox = MenuStyleScript.panel_style()
	assert_eq(a, b, "cached: every panel in the game points at the same box")
	# P8 S5: the kit's dark paper.
	assert_eq((a as StyleBoxTexture).texture.resource_path, "res://assets/ui/kit/paper_dark.png")
	assert_gte((a as StyleBoxTexture).texture_margin_top, 32.0, "the painted corner is not stretched")


## THE ROW TREATMENT THE STYLE FILE ALREADY INTENDED. These four constants shipped declared
## and unread, because every row in the game was a bare Label with a two character caret.
func test_the_row_box_uses_the_declared_row_colours_and_differs_when_picked() -> void:
	var picked: StyleBoxFlat = MenuStyleScript.row_box(true)
	var idle: StyleBoxFlat = MenuStyleScript.row_box(false)
	assert_eq(picked.bg_color, MenuStyleScript.ROW_SELECTED_BG)
	assert_eq(picked.border_color, MenuStyleScript.ROW_SELECTED_BORDER)
	assert_eq(idle.bg_color, MenuStyleScript.ROW_IDLE_BG)
	assert_eq(idle.border_color, MenuStyleScript.ROW_IDLE_BORDER)
	assert_ne(picked.bg_color, idle.bg_color,
		"a highlight nobody can see is not a highlight")


## A WEIGHT HIERARCHY FOR ZERO ASSETS. There is no .ttf in this project and this slice does
## not add one; a FontVariation over the engine default is constructed in code, ships no file
## and needs no import.
func test_the_title_font_is_heavier_than_the_numeral_font_and_is_cached() -> void:
	# v1: real weights on Fredoka's wght axis (opentype tag 2003265652), not synthetic bold.
	const WGHT := 2003265652
	var font: FontVariation = MenuStyleScript.title_font()
	assert_eq(font, MenuStyleScript.title_font(), "cached")
	var title_w := int(font.variation_opentype.get(WGHT, 0))
	var num_w := int(MenuStyleScript.numeral_font().variation_opentype.get(WGHT, 0))
	assert_gt(title_w, num_w, "a title is heavier than a number")
	assert_gt(num_w, 500, "and a number is heavier than prose (body weight 500)")


func test_the_subtitle_size_sits_under_the_row_size() -> void:
	assert_lt(MenuStyleScript.SUBTITLE_SIZE, MenuStyleScript.ROW_SIZE)


## THE PANELS THEMSELVES. This existing test opened the ONE menu that was already outlining
## its rows, which is why every table in the Palace shipped with unoutlined rows over a
## translucent panel for a whole phase. It now asks a table as well.
func test_a_table_draws_its_rows_with_the_outline_and_in_a_row_box() -> void:
	# THE RACE CARD, since the three casino games stopped having a row column at all
	# (game/ui/casino_table.gd, 2026-11-05); it is the table that still prints rows.
	var menu: CanvasLayer = load("res://ui/race_menu.tscn").instantiate()
	add_child_autofree(menu)
	menu.set("can_open", func() -> bool: return true)
	menu.set("chips_provider", func() -> int: return 500)
	menu.set("entrants_provider", func() -> Array[Dictionary]: return [
		{"uid": &"a", "name": "Mote", "happiness": 0.8, "odds": 3.5, "chance": 0.28},
	] as Array[Dictionary])
	assert_true(bool(menu.call("open")))
	var rows := menu.get_node(^"Centre/Panel/Margin/Column/Rows") as VBoxContainer
	assert_gt(rows.get_child_count(), 0, "the table drew rows to check")
	var holder := rows.get_child(0) as PanelContainer
	assert_not_null(holder, "every cursor driven row sits in a PanelContainer now")
	var label := holder.get_child(0) as Label
	assert_not_null(label)
	assert_eq(label.get_theme_constant("outline_size"), MenuStyleScript.OUTLINE_SIZE)


## FS6.1: a tile menu opens with a little pop instead of appearing, and a hovered tile lifts.
func test_a_menu_pops_in_and_settles_at_full_size() -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 100)
	add_child_autofree(panel)
	MenuStyle.pop_in(panel)
	assert_lt(panel.scale.x, 1.0, "starts small")
	assert_lt(panel.modulate.a, 1.0, "and faint")
	await wait_seconds(MenuStyle.POP_SECONDS + 0.1)
	assert_almost_eq(panel.scale.x, 1.0, 0.001)
	assert_almost_eq(panel.modulate.a, 1.0, 0.001)


func test_a_hovered_tile_lifts_off_the_page() -> void:
	var rest: StyleBoxFlat = TileStyle.box(false, false)
	var hover: StyleBoxFlat = TileStyle.box(false, true)
	assert_gt(hover.shadow_size, rest.shadow_size)
	assert_gt(hover.shadow_offset.y, rest.shadow_offset.y)


## FS6.2: money moving is a moment, not a number changing: a gold "+300 bits" rises off the
## tile and fades.
func test_a_payout_pops_up_and_fades_away() -> void:
	var host := Control.new()
	host.size = Vector2(400, 300)
	add_child_autofree(host)
	var pop: Label = MenuStyle.payout_pop(host, Vector2(200, 150), 300)
	assert_eq(pop.text, "+300 bits")
	var y0 := pop.position.y
	await wait_seconds(MenuStyle.PAYOUT_SECONDS * 0.5)
	assert_lt(pop.position.y, y0, "it rises")
	await wait_seconds(MenuStyle.PAYOUT_SECONDS * 0.7)
	assert_false(is_instance_valid(pop), "and is gone")
	var spend: Label = MenuStyle.payout_pop(host, Vector2(200, 150), -120)
	assert_eq(spend.text, "-120 bits")
