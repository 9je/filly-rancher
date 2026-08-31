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


static func style_label(label: Label, size: int, colour: Color) -> void:
	if label == null:
		return
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)


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
