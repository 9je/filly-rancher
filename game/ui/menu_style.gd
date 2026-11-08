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
## ZERO SINCE PT5 (playtest 2026-11-05: "text is a bit thick", the letters "hard to read"):
## white on plum and ink on cream both read cleanly, and a dark ring round every glyph made
## them smear into one heavy weight. Kept as a constant so the theme and the drawn screens
## still agree on one number.
const OUTLINE_SIZE := 0


## TEXT SIZE (FS8.2; Settings.text_size): every size the menus style is scaled by this.
static var text_scale := 1.0


## `size` px at the player's text size.
static func font_px(size: int) -> int:
	return int(round(size * text_scale))


static func style_label(label: Label, size: int, colour: Color) -> void:
	if label == null:
		return
	label.add_theme_font_size_override("font_size", font_px(size))
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


## THE PAPER AND THE WOOD. The palette above is the dark navy panel this game has always
## drawn; these are the two materials the redesign adds, and they are the ones the generated
## Theme is built out of. The paper numbers are game/ui/paper_paint.gd's own, copied rather
## than imported so a const can hold them, and game/test/test_theme.gd asserts the two
## copies agree so they cannot drift apart in silence.
const COLOR_PAPER := Color(0.96, 0.94, 0.88, 0.97)
const COLOR_PAPER_EDGE := Color(0.72, 0.68, 0.58, 0.90)
const COLOR_INK := Color(0.13, 0.12, 0.15, 1.0)

## The frame around a panel: a dark stained board with a lit edge, which is what reads as
## wood at this size without a texture anywhere near it.
const COLOR_WOOD := Color(0.31, 0.20, 0.13, 1.0)
const COLOR_WOOD_LIT := Color(0.49, 0.33, 0.20, 1.0)

## HOVER IS ITS OWN STATE AND IT IS NOT SELECTION. A pointer resting on a row has to say
## "this is what you would take" without claiming "this is what is taken": weaker than
## ROW_SELECTED_BG, stronger than ROW_IDLE_BG, and the same hue as both.
const COLOR_HOVER_BG := Color(1.0, 0.86, 0.55, 0.09)
const COLOR_HOVER_BORDER := Color(1.0, 0.86, 0.55, 0.40)

## Where the generated Theme lives. Written by game/scripts/make_theme.gd, installed by
## game/project.godot's gui/theme/custom, read back by theme_resource() below.
const THEME_PATH := "res://ui/theme/filly_theme.tres"

const BUTTON_RADIUS := 8
const FRAME_WIDTH := 3

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
## StyleBoxFlat copy pasted verbatim into ten .tscn files. No content margin: the Margin
## node owns that.
static func panel_style() -> StyleBox:
	# THE KIT (P8 S5): the menus' plum is a painted surface now, paper stock with grain, an
	# ink edge and a drop shadow (tools/make_ui_kit.py), not a flat rounded rectangle. Still
	# dark, so every menu's light words keep their contrast.
	return kit(&"paper_dark")


static func apply_panel(panel: PanelContainer) -> void:
	if panel == null:
		return
	panel.add_theme_stylebox_override(&"panel", panel_style())


## The Spectra Palace's panels are plum velvet with gold piping (P8 S5), so the casino reads as
## a different place from the ranch at a glance.
static func apply_palace_panel(panel: PanelContainer) -> void:
	if panel == null:
		return
	panel.add_theme_stylebox_override(&"panel", kit(&"velvet"))


# --- the kit (P8 S5; tools/make_ui_kit.py) --------------------------------------------------

const KIT_DIR := "res://assets/ui/kit/"
## Per surface: the nine-patch margin (px of the source PNG that stay unstretched: corner plus
## shadow) and the content margin inside it.
const KIT := {
	&"paper": [40, 26], &"paper_dark": [40, 26], &"wood": [52, 40], &"velvet": [40, 26],
	&"button": [30, 16], &"button_hover": [30, 16], &"button_pressed": [30, 16],
	&"button_disabled": [30, 16], &"button_primary": [30, 16],
	&"button_primary_hover": [30, 16], &"chip": [20, 8], &"tab_on": [26, 14],
	&"tab_off": [26, 14], &"card": [22, 10],
}

static var _kit_boxes: Dictionary = {}


## The kit's surface `name` as a StyleBoxTexture, shared (do not edit the one returned;
## duplicate() it).
static func kit(name: StringName) -> StyleBoxTexture:
	if _kit_boxes.has(name):
		return _kit_boxes[name]
	var m: Array = KIT.get(name, [32, 16])
	var box := StyleBoxTexture.new()
	box.texture = load(KIT_DIR + String(name) + ".png") as Texture2D
	box.texture_margin_left = float(m[0])
	box.texture_margin_right = float(m[0])
	box.texture_margin_top = float(m[0])
	box.texture_margin_bottom = float(m[0])
	box.content_margin_left = float(m[1]) + 6.0
	box.content_margin_right = float(m[1]) + 6.0
	box.content_margin_top = float(m[1])
	box.content_margin_bottom = float(m[1])
	_kit_boxes[name] = box
	return box


## apply_panel() with the box named rather than assumed. The letter and the creation screen
## are paper and wood; every list in the game is still the navy panel apply_panel() applies.
static func apply_panel_box(panel: PanelContainer, box: StyleBox) -> void:
	if panel == null or box == null:
		return
	panel.add_theme_stylebox_override(&"panel", box)


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
	font.base_font = _fredoka()
	# Fredoka's own weight axis (wght, opentype tag 2003265652) rather than synthetic bold.
	font.variation_opentype = {2003265652: 650}
	font.spacing_glyph = 1
	_title_font = font
	return _title_font


## For amounts: chips, bits, odds and stakes. Lighter than a title, heavier than prose, so a
## number reads as a number without shouting.
static func numeral_font() -> FontVariation:
	if _numeral_font != null:
		return _numeral_font
	var font := FontVariation.new()
	font.base_font = _fredoka()
	font.variation_opentype = {2003265652: 600}
	_numeral_font = font
	return _numeral_font


## The game's display face: Fredoka (SIL OFL 1.1, game/assets/fonts/OFL.txt), round and
## friendly like the show's own lettering. Falls back to Godot's default if the file is gone.
static func _fredoka() -> Font:
	var path := "res://assets/fonts/Fredoka.ttf"
	if ResourceLoader.exists(path):
		return load(path)
	return ThemeDB.fallback_font


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


# --- the boxes the generated Theme is made of ---------------------------------------------
#
# ONE SOURCE, TWO CONSUMERS. Every function below is called twice: once by
# game/scripts/make_theme.gd when it writes game/ui/theme/filly_theme.tres, and once by
# game/test/test_theme.gd when it checks that the file on disk still says what these say.
# Nothing here caches, because each of them is called a handful of times per build and a
# cached StyleBox handed to a Theme and then to a Control is a box three owners can edit.


static func _box(bg: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 14.0
	box.content_margin_right = 14.0
	box.content_margin_top = 7.0
	box.content_margin_bottom = 7.0
	return box


## A BUTTON, IN FIVE STATES, AND THEY LOOK DIFFERENT ON PURPOSE. An unknown state name
## answers normal rather than null: a Theme entry that came back null would style nothing
## and say nothing about why.
static func button_box(state: StringName) -> StyleBox:
	# The kit's cream pill (P8 S5) with ink words, on paper and on the dark panels alike, so a
	# button looks like a button everywhere: lifted at rest, gold-rimmed under the pointer,
	# pushed down when pressed.
	match state:
		&"hover", &"focus":
			return kit(&"button_hover")
		&"pressed":
			return kit(&"button_pressed")
		&"disabled":
			return kit(&"button_disabled")
	return kit(&"button")


static func tab_box(state: StringName) -> StyleBox:
	match state:
		&"selected":
			return kit(&"tab_on")
		&"hovered":
			return kit(&"button_hover")
	return kit(&"tab_off")


## THE NAME BOX. Ink on paper, because it is the one control in this game somebody types
## into and dark text on a light field is what a person expects to type into.
static func field_box(focused: bool) -> StyleBoxFlat:
	return _box(COLOR_PAPER, COLOR_TAB_ON if focused else COLOR_PAPER_EDGE,
		2 if focused else 1, 6)


static func slider_box(filled: bool) -> StyleBoxFlat:
	var box := _box(COLOR_VALUE if filled else ROW_IDLE_BG,
		ROW_SELECTED_BORDER if filled else ROW_IDLE_BORDER, 1, 4)
	box.content_margin_top = 4.0
	box.content_margin_bottom = 4.0
	return box


## WARM PAPER, FOR THE PANELS THAT ARE PAGES: the letter, the statement, the house rules.
static func paper_box() -> StyleBox:
	return kit(&"paper")


## THE TOOLTIP IS ONE OF THE HUD'S CARDS (PS10, G1: a lesson chip shows its sentence under the
## pointer). The engine's own tooltip box is a grey slab with white words, the "text
## scaffolding" look the owner turned down; the theme gives every tooltip in the game the
## HUD's cream card with its plum edge and ink words instead. The two colours are
## game/ui/hud.gd's CARD_FILL and INK, copied because a const cannot reach across.
const TOOLTIP_FILL := Color(1.0, 0.97, 0.91, 0.97)
const TOOLTIP_LINE := Color(0.47, 0.31, 0.64)
const TOOLTIP_INK := Color(0.24, 0.17, 0.3)


static func tooltip_box() -> StyleBox:
	var box: StyleBoxTexture = kit(&"paper").duplicate()
	box.content_margin_left = 22.0
	box.content_margin_right = 22.0
	box.content_margin_top = 16.0
	box.content_margin_bottom = 17.0
	return box


## A BUTTON THAT SITS ON PAPER (PS6, G13; batch check of the 2026-11-05 playtest: the welcome
## letter's Back and the survey's answers were "white on cream, nearly invisible"). The theme's
## Button is made for the dark menu panels: a 4% white face and white words, which on a sheet
## of cream is nothing at all. Anything put on a paper panel takes this instead: a face a shade
## darker than the sheet, an ink edge, ink words, and a gold face under the pointer.
const PAPER_BUTTON_FACE := Color(0.88, 0.84, 0.74, 1.0)
const PAPER_BUTTON_EDGE := Color(0.42, 0.36, 0.30, 1.0)
const PAPER_BUTTON_LIT := Color(1.0, 0.84, 0.48, 1.0)


static func paper_button_box(state: StringName) -> StyleBox:
	return button_box(state)


## THE ONE BUTTON THAT MOVES THINGS ON (P8 S5): gold, bigger, at the end of a screen
## ("This is me", "Deal", "Place bet"), so the way forward is never a plain row.
static func primary_button(button: Button) -> void:
	if button == null:
		return
	button.add_theme_stylebox_override(&"normal", kit(&"button_primary"))
	button.add_theme_stylebox_override(&"hover", kit(&"button_primary_hover"))
	button.add_theme_stylebox_override(&"focus", kit(&"button_primary_hover"))
	button.add_theme_stylebox_override(&"pressed", kit(&"button_pressed"))
	for slot: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color",
			&"font_focus_color", &"font_hover_pressed_color"]:
		button.add_theme_color_override(slot, COLOR_INK)
	button.add_theme_font_override(&"font", title_font())
	button.add_theme_font_size_override(&"font_size", font_px(28))
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, 64.0)


static func paper_button(button: Button) -> void:
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		button.add_theme_stylebox_override(state, paper_button_box(state))
	for slot: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color",
			&"font_focus_color", &"font_hover_pressed_color"]:
		button.add_theme_color_override(slot, COLOR_INK)
	button.add_theme_color_override(&"font_disabled_color", Color(COLOR_INK, 0.45))
	button.add_theme_constant_override(&"outline_size", 0)


## THE WOODEN FRAME. Used around the turntable and the cutie mark canvas, which are the two
## things on screen that are pictures rather than text.
static func frame_box() -> StyleBox:
	return kit(&"wood")


## THE THIRD ROW STATE. row_box() answers idle and selected; a pointer needs a third, and it
## is built here rather than inside row_box() so that function's two cached boxes stay two.
static func row_box_hover() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = COLOR_HOVER_BG
	box.border_color = COLOR_HOVER_BORDER
	box.set_border_width_all(0)
	box.border_width_left = 2
	box.set_corner_radius_all(ROW_RADIUS)
	box.content_margin_left = float(ROW_INSET_LEFT)
	box.content_margin_top = 2.0
	box.content_margin_right = 6.0
	box.content_margin_bottom = 2.0
	return box


static var _theme: Theme = null


## The generated Theme, or NULL on a checkout where it has not been generated yet. Null is a
## supported answer for the reason PonyRegistry.by_id()'s is: a missing resource must not
## take a boot down, and project.godot installs this file itself, so a screen that asks for
## it here is asking only so that it can style something by hand.
static func theme_resource() -> Theme:
	if _theme != null:
		return _theme
	if not ResourceLoader.exists(THEME_PATH):
		return null
	_theme = load(THEME_PATH) as Theme
	return _theme


## A BUTTON'S TEXT, OUTLINED THE WAY EVERY LABEL IN THIS GAME IS OUTLINED. The generated
## Theme sets this for every Button in the project; a Button carrying per state StyleBox
## overrides keeps the Theme's font settings, so this is belt and braces for the ones built
## in code before the tree hands them a theme.
static func style_label_button(button: Button) -> void:
	if button == null:
		return
	button.add_theme_font_size_override("font_size", font_px(ROW_SIZE))
	button.add_theme_color_override("font_color", COLOR_NAME)
	button.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	button.add_theme_constant_override("outline_size", OUTLINE_SIZE)


# --- the menu tick kit --------------------------------------------------------------------
#
# THE ONE PLACE THAT DECIDES WHAT A MENU SOUNDS LIKE. Nine files under game/ui/ call these
# six functions and none of them names a sound id, a level or a bus. Changing the character
# of every menu in the game is changing six lines here.
#
# THESE ARE THE ONLY AUDIO CALLS ALLOWED UNDER game/ui/ THAT NAME AN ID. A menu calls
# MenuStyle.tick_move(); it never calls Sound.play(&"ui_move") itself. The RNG rule is
# untouched either way: every variation decision is made inside game/systems/sound.gd.


## THE BARE `Sound` IDENTIFIER FAILS THE PARSE SWEEP HERE. tools/run_tests.sh parses every
## script through Godot's check-only, script-only pass, which loads project.godot's
## autoload list but never boots a SceneTree, so an autoload's global name resolves to
## nothing there (see game/test/test_sound.gd's own comment on the same limitation;
## verified directly: a bare `Sound.play()` added to this file raised "Identifier not
## found: Sound" under that pass, though it runs fine in the game or under GUT). A test
## script can shadow the name with `get_node()` inside a method body; a static function has
## no `self` and no instance to call `get_node()` on, so this goes through the active
## SceneTree instead. `Engine` is a builtin singleton, not an autoload, so it resolves on
## both passes. The two guards mirror game/actors/player/magic_beam.gd's own `_sound_call`:
## no loop (that parse pass, or a tool script run outside the game) and no `Sound` node
## registered (a bare test fixture) both fall through as a silent no-op rather than an
## error.
static func _sound_call(method: StringName, args: Array) -> void:
	var loop: MainLoop = Engine.get_main_loop()
	if loop == null or not (loop is SceneTree):
		return
	var tree: SceneTree = loop as SceneTree
	var node: Node = tree.root.get_node_or_null(^"/root/Sound")
	if node != null:
		node.callv(method, args)


## The selection cursor moved.
static func tick_move() -> void:
	_sound_call(&"play", [&"ui_move"])


## An action was taken.
static func tick_confirm() -> void:
	_sound_call(&"play", [&"ui_confirm"])


## A panel or a page was left.
static func tick_back() -> void:
	_sound_call(&"play", [&"ui_back"])


## A panel was opened.
## A TILE MENU POPS OPEN (FS6.1): from a little smaller and faint to full size, overshooting
## a touch, instead of appearing between one frame and the next.
const POP_SECONDS := 0.18
const POP_FROM := 0.92


static func pop_in(panel: Control) -> void:
	if panel == null or not panel.is_inside_tree():
		return
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2.ONE * POP_FROM
	panel.modulate.a = 0.0
	var tw := panel.create_tween().set_parallel(true)
	tw.tween_property(panel, ^"scale", Vector2.ONE, POP_SECONDS) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, ^"modulate:a", 1.0, POP_SECONDS * 0.8)


## MONEY MOVING IS A MOMENT (FS6.2): a gold "+N bits" (or "-N bits") rises from `at` over
## `host` and fades, freeing itself.
const PAYOUT_SECONDS := 0.9
const PAYOUT_RISE := 70.0
const PAYOUT_GAIN := Color(1.0, 0.84, 0.3)
const PAYOUT_SPEND := Color(0.98, 0.72, 0.78)


##
## `host` must be a plain Control (a menu's effects layer), not a container: a container lays
## its children out and would put the pop at its own top left corner. `delay` holds it back,
## unseen, while a coin is still on its way to `at`.
static func payout_pop(host: Control, at: Vector2, bits: int, delay := 0.0) -> Label:
	var pop := Label.new()
	pop.name = "Payout"
	pop.text = "%s%d bits" % ["+" if bits >= 0 else "-", absi(bits)]
	pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	style_label(pop, 30, PAYOUT_GAIN if bits >= 0 else PAYOUT_SPEND)
	pop.add_theme_font_override(&"font", numeral_font())
	pop.add_theme_color_override(&"font_shadow_color", Color(0.1, 0.02, 0.12, 0.6))
	pop.add_theme_constant_override(&"shadow_offset_y", 2)
	host.add_child(pop)
	pop.position = at - pop.get_combined_minimum_size() * 0.5
	var tw := pop.create_tween()
	if delay > 0.0:
		pop.modulate.a = 0.0
		tw.tween_interval(delay)
		tw.tween_property(pop, ^"modulate:a", 1.0, 0.06)
	tw.tween_property(pop, ^"position:y", pop.position.y - PAYOUT_RISE, PAYOUT_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(pop, ^"modulate:a", 0.0, PAYOUT_SECONDS * 0.45) \
		.set_delay(PAYOUT_SECONDS * 0.55)
	tw.tween_callback(pop.queue_free)
	return pop


## A COIN FLIES TO THE WALLET (PS10, G6; FS6.1: "a purchase flies a coin from the tile to the
## wallet"). The bits coin the HUD and the signs already wear (PlaceSign's COIN icon), arcing
## from `from` up and over to `to` on `host` (an effects layer, as payout_pop's), spinning as
## it goes; it lands, swells and fades. Named "Coin" so the suite can find it.
const COIN_SECONDS := 0.42
const COIN_SIZE := 42.0
const COIN_ARC := 110.0
const COIN_LAND := 0.14


static func fly_coin(host: Control, from: Vector2, to: Vector2, delay := 0.0) -> Control:
	var coin := Control.new()
	coin.name = "Coin"
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin.size = Vector2.ONE * COIN_SIZE
	coin.pivot_offset = coin.size * 0.5
	var face: Texture2D = PlaceSign.icon_texture(PlaceSign.Icon.COIN)
	coin.draw.connect(func() -> void:
		coin.draw_circle(coin.size * 0.5 + Vector2(0, 3), coin.size.x * 0.46, Color(0.1, 0.02, 0.12, 0.35))
		coin.draw_texture_rect(face, Rect2(Vector2.ZERO, coin.size), false))
	host.add_child(coin)
	var place := func(t: float) -> void:
		var arc := Vector2(0.0, -COIN_ARC * 4.0 * t * (1.0 - t))
		coin.position = from.lerp(to, t) + arc - coin.size * 0.5
		var swell := 1.0 + 0.3 * sin(t * PI)
		# Turning over as it flies: the face narrows and widens three times.
		coin.scale = Vector2(swell * maxf(0.2, absf(cos(t * PI * 3.0))), swell)
	place.call(0.0)
	if delay > 0.0:
		coin.modulate.a = 0.0
	var tw := coin.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
		tw.tween_property(coin, ^"modulate:a", 1.0, 0.04)
	tw.tween_method(place, 0.0, 1.0, COIN_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(coin, ^"scale", Vector2.ONE * 1.5, COIN_LAND)
	tw.parallel().tween_property(coin, ^"modulate:a", 0.0, COIN_LAND)
	tw.tween_callback(coin.queue_free)
	return coin


## A plain Control over the whole of a menu's CanvasLayer, for the coins and pops to fly on:
## added last, so it draws over the panel, and never in the pointer's way.
static func effects_layer(menu: CanvasLayer) -> Control:
	var fx := Control.new()
	fx.name = "Effects"
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(fx)
	return fx


## The bits coin as a small picture, for a wallet line to show where the coins land.
static func coin_icon(size: float) -> TextureRect:
	var icon := TextureRect.new()
	icon.name = "PurseCoin"
	icon.texture = PlaceSign.icon_texture(PlaceSign.Icon.COIN)
	icon.custom_minimum_size = Vector2.ONE * size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.pivot_offset = Vector2.ONE * size * 0.5
	return icon


static func tick_open() -> void:
	_sound_call(&"play", [&"ui_open"])


## An action was refused: a row that cannot be taken, a price she cannot pay.
static func tick_denied() -> void:
	_sound_call(&"play", [&"ui_denied"])


## A page turned inside a panel that was already open.
static func tick_page() -> void:
	_sound_call(&"play", [&"ui_page"])
