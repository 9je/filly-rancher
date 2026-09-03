class_name MenuStyle
extends RefCounted
## ONE LOOK FOR EVERY PANEL IN THE GAME, and one place the keys at the bottom of one are
## written. The owner, 2026-08-31: "menu polish pass across ALL CanvasLayer menus: one
## shared visual style (consistent title bar, row height, selected row treatment, footer)".
##
## WHAT WAS ACTUALLY WRONG. Six menu scripts each declared their own copy of the same four
## or five colours, and three different footers shipped: the market, depot and pause line,
## the build line, and the casino suite's line, each describing the same two keys in
## different words. A player reads that as three different games.
##
## THIS FILE CHANGES NO MENU'S LOGIC. Every menu keeps its own drawn_lines(), its own
## row_count(), its own signals and its own _unhandled_input(); they draw and ranch.gd
## transacts, exactly as before. What they stop doing is each inventing a palette and a
## footer.
##
## Static only, no state, no scene. Preload by path.

const InputDeviceScript := preload("res://systems/input_device.gd")

# --- the palette ----------------------------------------------------------------------------
# Lifted verbatim from game/ui/pause_menu.gd and game/ui/market_menu.gd, which agreed with
# each other; the casino suite's slightly different numbers are the ones that move.

const COLOR_TITLE := Color(1.0, 0.96, 0.86, 1.0)
const COLOR_NAME := Color(1.0, 1.0, 1.0, 0.94)
const COLOR_DIM := Color(1.0, 1.0, 1.0, 0.58)
const COLOR_VALUE := Color(1.00, 0.80, 0.25, 1.0)
const COLOR_UNAFFORDABLE := Color(1.0, 0.45, 0.42, 0.85)
const COLOR_TAB_ON := Color(1.0, 0.86, 0.55, 1.0)
const COLOR_TAB_OFF := Color(1.0, 1.0, 1.0, 0.40)
const ROW_SELECTED_BG := Color(1.0, 0.86, 0.55, 0.16)
const ROW_SELECTED_BORDER := Color(1.0, 0.86, 0.55, 0.75)
const ROW_IDLE_BG := Color(1.0, 1.0, 1.0, 0.04)
const ROW_IDLE_BORDER := Color(1.0, 1.0, 1.0, 0.10)

## Title, row and footer, in 1920x1080 base pixels (game/project.godot stretches
## canvas_items against that viewport, so these are the same size on every screen).
const TITLE_SIZE := 30
const ROW_SIZE := 22
const FOOTER_SIZE := 20

## THE CARET AND ITS PADDING ARE THE SAME WIDTH ON PURPOSE. A marker wider than the space
## that replaces it makes every row shift sideways as the cursor passes over it.
const CARET := "> "
const NO_CARET := "  "


## THE OUTLINE IS NOT STYLING, AND IT IS APPLIED HERE SO NO PANEL CAN FORGET IT.
##
## game/ui/hud.gd's own _style_label() says it first: this game draws its text over a bright
## green field under a bright sky, and unoutlined white text on that is genuinely unreadable.
## Every menu panel in the game is translucent (see the MenuPanel StyleBoxFlat every .tscn
## carries, alpha 0.88), so the field shows through them too. game/ui/build_menu.gd carried
## exactly this pairing and exactly this reasoning in a _style_label() of its own until the
## menus were folded onto this file, and folding them lost it: three panels shipped their
## titles with no outline at all. Putting it in the one function every menu already calls is
## what makes "all menus inherit it" a fact rather than a convention.
##
## THE NUMBERS ARE build_menu.gd's, verbatim: 75% black at 5 px.
const OUTLINE_COLOR := Color(0.0, 0.0, 0.0, 0.75)
const OUTLINE_SIZE := 5


static func style_label(label: Label, size: int, colour: Color) -> void:
	if label == null:
		return
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	label.add_theme_constant_override("outline_size", OUTLINE_SIZE)


static func caret(picked: bool) -> String:
	return CARET if picked else NO_CARET


## The tab strip every multi tab panel prints: the active one in brackets, the rest in the
## same width of space, so the strip does not shuffle as the tab changes. An index outside
## the list brackets nothing, which is what a panel with no tab selected should look like.
static func tab_strip(names: Array[String], active: int) -> String:
	var out: Array[String] = []
	for i in names.size():
		out.append("[%s]" % names[i] if i == active else " %s " % names[i])
	return "   ".join(out)


## A FOOTER, IN THE GLYPHS OF THE DEVICE SHE IS ACTUALLY HOLDING. `pairs` is an array of
## two element arrays: the action (or composite) name, and the verb it performs.
##
## ONE SCHEME, NEVER BOTH. That is the whole point of this function and of
## game/systems/input_device.gd behind it.
static func footer(pairs: Array) -> String:
	var out: Array[String] = []
	for pair: Array in pairs:
		var glyph: String = InputDeviceScript.hint(StringName(pair[0]))
		if glyph.is_empty():
			continue
		out.append("%s  %s" % [glyph, String(pair[1])])
	return NO_CARET + "      ".join(out)


## The footer for a panel with tabs AND rows: the Market, the Depot, the casino lobby and
## every table in it.
static func footer_tabs_and_rows(verb: String, leave: String) -> String:
	return footer([[&"menu_rows", "choose"], [&"menu_tabs", "tab"],
		[&"ui_accept", verb], [&"ui_cancel", leave]])


## The footer for a single list: the build menu, the pause menu's main page.
static func footer_rows(verb: String, leave: String) -> String:
	return footer([[&"menu_rows", "choose"], [&"ui_accept", verb], [&"ui_cancel", leave]])


## The footer for a page that is reading matter: the compendium, the house rules, the
## statement. It offers no confirm, because there is nothing to confirm.
static func footer_reading(leave: String) -> String:
	return footer([[&"menu_rows", "scroll"], [&"ui_cancel", leave]])


## A fourth size, for the tile descriptions and the COLOR_DIM second lines the casino's
## drawn screens carry. TITLE_SIZE, ROW_SIZE and FOOTER_SIZE are unchanged.
const SUBTITLE_SIZE := 18

## The rounded box's radius and its left inset, in 1920x1080 base pixels. The inset is what
## makes a selected row read as stepping forward out of the column rather than as a rectangle
## somebody painted behind it.
const ROW_RADIUS := 6
const ROW_INSET_LEFT := 4

## Cached so every panel in the game points at ONE StyleBox rather than at its own copy: this
## is the whole point of the function, and a fresh instance per call would be ten copies again
## with extra steps.
static var _panel_style: StyleBoxFlat = null
static var _row_boxes: Array[StyleBoxFlat] = []
static var _title_font: FontVariation = null
static var _numeral_font: FontVariation = null


## THE PANEL BEHIND EVERY MENU IN THE GAME, and until this function existed it was a
## StyleBoxFlat copy pasted verbatim into ten .tscn files. The numbers below are those
## copies, byte for byte, so this is a refactor and not a redesign: dark navy at 88 per cent,
## a one pixel warm gold border at 32 per cent, twelve pixel corners, no content margin
## (the Margin node owns that).
static func panel_style() -> StyleBoxFlat:
	if _panel_style != null:
		return _panel_style
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.0392157, 0.0470588, 0.0784314, 0.88)
	box.set_border_width_all(1)
	box.border_color = Color(1, 0.858824, 0.552941, 0.32)
	box.set_corner_radius_all(12)
	box.content_margin_left = 0.0
	box.content_margin_top = 0.0
	box.content_margin_right = 0.0
	box.content_margin_bottom = 0.0
	_panel_style = box
	return _panel_style


static func apply_panel(panel: PanelContainer) -> void:
	if panel == null:
		return
	panel.add_theme_stylebox_override(&"panel", panel_style())


## THE ROW TREATMENT THIS FILE ALREADY SPECIFIED AND NOTHING DREW. ROW_SELECTED_BG,
## ROW_SELECTED_BORDER, ROW_IDLE_BG and ROW_IDLE_BORDER shipped declared and unread, because
## every row in the game was a bare Label carrying a two character caret and a colour swap.
##
## THE CARET STAYS. game/test/test_table_caret.gd and this file's own test read it, and a
## caret plus a highlight is more legible than either alone: the caret survives a screenshot
## at any size and reads for a player who cannot separate the two backgrounds by hue.
static func row_box(picked: bool) -> StyleBoxFlat:
	if _row_boxes.is_empty():
		for is_picked: bool in [false, true]:
			var box := StyleBoxFlat.new()
			box.bg_color = ROW_SELECTED_BG if is_picked else ROW_IDLE_BG
			box.border_color = ROW_SELECTED_BORDER if is_picked else ROW_IDLE_BORDER
			box.set_border_width_all(0)
			box.border_width_left = 3 if is_picked else 1
			box.set_corner_radius_all(ROW_RADIUS)
			box.content_margin_left = float(ROW_INSET_LEFT)
			box.content_margin_top = 2.0
			box.content_margin_right = 6.0
			box.content_margin_bottom = 2.0
			_row_boxes.append(box)
	return _row_boxes[1 if picked else 0]


## A fresh container carrying the shared box. The BOX is cached; the CONTAINER cannot be,
## because a Control lives in exactly one place in one tree.
static func row_panel(picked: bool) -> PanelContainer:
	var holder := PanelContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_theme_stylebox_override(&"panel", row_box(picked))
	return holder


## A REAL WEIGHT HIERARCHY FOR ZERO ASSETS. There is no .ttf anywhere in this project, no
## Theme resource, and this slice does not add either; every Label in the game renders in
## Godot's built in default font. A FontVariation is constructed in code over that default,
## ships no file and needs no import pass, so a title can be heavier than a row without any
## of the licence, size and import questions a display font brings with it.
static func title_font() -> FontVariation:
	if _title_font != null:
		return _title_font
	var font := FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.variation_embolden = 0.55
	font.spacing_glyph = 2
	_title_font = font
	return _title_font


## For amounts: chips, bits, odds and stakes. Lighter than a title, heavier than prose, so a
## number reads as a number without shouting.
static func numeral_font() -> FontVariation:
	if _numeral_font != null:
		return _numeral_font
	var font := FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.variation_embolden = 0.3
	_numeral_font = font
	return _numeral_font


static func apply_title(label: Label) -> void:
	if label == null:
		return
	style_label(label, TITLE_SIZE, COLOR_TITLE)
	label.add_theme_font_override(&"font", title_font())


## THE LINE UNDER A TITLE. Two pixels of gold fading to nothing at both ends, drawn as three
## segments because Godot's draw_line takes one colour: it is one piece of geometry and it
## does more for "this looks designed" than anything else on a text panel.
static func rule(ci: CanvasItem, from: Vector2, to: Vector2) -> void:
	var mid_a: Vector2 = from.lerp(to, 0.18)
	var mid_b: Vector2 = from.lerp(to, 0.82)
	var bright := Color(1.0, 0.86, 0.55, 0.85)
	var faded := Color(1.0, 0.86, 0.55, 0.0)
	ci.draw_line(from, mid_a, faded, 2.0, true)
	ci.draw_line(mid_a, mid_b, bright, 2.0, true)
	ci.draw_line(mid_b, to, faded, 2.0, true)
