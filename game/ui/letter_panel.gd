class_name LetterPanel
extends CanvasLayer
## THE LETTER, ON THE SCREEN, WHERE SOMEBODY CAN READ IT.
##
## WHAT WAS WRONG. game/systems/letters.gd renders a sender, a title and a BODY, and the
## body is where every word of the game's onboarding lives: catch, pen, collect, sell, the
## balance and the quota, in four numbered steps. Nothing in the game had ever drawn one.
## ranch.gd rendered the welcome letter, threw the body away and toasted the TITLE
## ("Cloudsdale Weather Corporation: Welcome to the family!"), which tells a new player
## nothing at all. The task that letter belongs to exists to say where bits come from, and a
## discarded body does not say it. Whole branch review of 2026-08-31, Ruling 25.
##
## READ ONLY, AND THAT IS THE WHOLE DESIGN. There is no row to pick, nothing to confirm and
## no transaction anywhere near it: the panel is handed a rendered letter, it draws it, and
## it closes. Everything else in this project's UI layer is a list with a caret; this is the
## one panel that is a page.
##
## DELIBERATELY SMALLER THAN THE MAILBOX IT WILL BECOME. The story phase builds Mail (an
## inbox, unread state, StoryBeat resources that post letters over time); this is the reader
## those will be shown through, kept to open()/is_open()/close() so that growing it is
## adding an inbox in front of it rather than rewriting it. It takes a Dictionary in exactly
## the shape Letters.render() answers, so any letter in the game already fits.
##
## IT DRAWS AND EMITS; ranch.gd TRANSACTS AND PAUSES. Same contract as every other panel
## here, and for the reason game/ui/build_menu.gd's class comment sets out at length: a menu
## that reached for get_tree().paused itself would freeze the GUT runner the moment a
## headless test opened one. `opened` and `closed` go to ranch.gd's own shared handlers.
##
## PROCESS_MODE_ALWAYS (set in letter_panel.tscn, like every sibling panel): the tree is
## paused for exactly as long as this is on screen, so it has to be the thing still awake to
## read the key that closes it again.
##
## FIX ROUND 1 (review CRITICAL 1). Task 6 first shipped with a Stage drawn UNDER a
## Title/Sender/Rows/Footer Label stack that still rendered the same sender, title and body
## a second time, so the sheet reserved height for the drawing AND for a second, Label
## shaped copy of the letter stacked beneath it -- for the WELCOME letter that meant a
## panel roughly 1.4x an 1080 viewport tall. The Stage is now the ONLY surface any of that
## text is drawn on: paint() prints the title and the body straight onto the paper, the
## Title/Sender/Rows Labels are gone from the scene entirely, and stage_size() reserves
## height for exactly the one drawing that exists. Footer and the Close button stay as
## Controls below the sheet; they are page furniture, not the letter.

const MenuStyleScript := preload("res://ui/menu_style.gd")
const MouseRowsScript := preload("res://ui/mouse_rows.gd")
const PaperPaintScript := preload("res://ui/paper_paint.gd")
const PlaceSignScript := preload("res://world/place_sign.gd")

## THE SHEET, IN 1920x1080 BASE PIXELS. The width is the Panel's existing 860 so nothing
## about where the letter sits on screen moves; the rest is what turns a column of Labels
## into a page: a margin the text does not touch, and a line height a letter breathes at.
const SHEET_WIDTH := 860.0
const LINE_HEIGHT := 26.0
const SHEET_MARGIN := 44.0

## The letterhead band at the top of the sheet, and the wax seal at the bottom of it.
const HEAD_HEIGHT := 80.0
const SEAL_SIZE := 64.0

## THE TITLE'S OWN ROW, in the same LINE_HEIGHT grid as the body: half again as tall,
## because TITLE_SIZE (30) is half again ROW_SIZE (22). One row is all a title ever needs.
const TITLE_HEIGHT := LINE_HEIGHT * 1.5

signal opened()
signal closed()
## A letter with a question was answered from the sheet (PT5): `choice` is the reply row's.
signal replied(choice: String)

var _open := false
var _letter: Dictionary = {}
var _close: Button = null
var _replies: Control = null

@onready var _footer: Label = $Centre/Panel/Margin/Column/Footer
@onready var _stage: Control = get_node_or_null(^"Centre/Panel/Margin/Column/Stage")


func _ready() -> void:
	# THE PANEL IS PAPER NOW, NOT A MENU. MenuStyle.apply_panel() put the dark navy box
	# behind it, which is right for a list and wrong for a letter; the owner's word for the
	# result was "week". paper_box() is the same warm sheet game/ui/paper_paint.gd draws the
	# Mail page's stationery on, so the reader and the archive are made of one material.
	var panel := $Centre/Panel as PanelContainer
	# OPAQUE (PS6 item 51): at the box's own 0.97 the HUD's "Post! The flag is up on your
	# mailbox." toast showed through the sheet as a ghost line beside the survey's answers.
	# The kit's paper (P8 S5) is opaque already.
	panel.add_theme_stylebox_override(&"panel", MenuStyleScript.paper_box())
	var dim := get_node_or_null(^"Dim") as Control
	if dim != null:
		dim.mouse_filter = Control.MOUSE_FILTER_STOP
		# The world behind, softened rather than blacked out (MenuStyle.soften_dim).
		MenuStyleScript.soften_dim(dim)
		# M10, final-review.md M2: A CLICK ON THE DIM CLOSES THE LETTER, FOR REAL THIS TIME.
		# Every Control between here and the sheet (Centre, Panel, Margin, Column, Stage,
		# Footer) is MOUSE_FILTER_IGNORE, so a click anywhere on this panel -- on the sheet
		# included -- falls straight through to Dim, which is STOP and swallowed it with
		# nothing connected. _unhandled_input() below never saw a mouse click at all; its own
		# "a click anywhere off the sheet closes the letter" branch was dead on arrival.
		dim.gui_input.connect(_on_dim_input)
	if _stage != null:
		_stage.mouse_filter = Control.MOUSE_FILTER_STOP
		_stage.focus_mode = Control.FOCUS_NONE
		_stage.draw.connect(func() -> void: paint(_stage))
	# THE ANSWERS ARE STAMPED ON THE SHEET (Fable AAA round 5: "the letter answer buttons sit
	# beneath the paper -- make them part of the paper"). Each answer is a rubber stamp with a
	# tick box, in the stamp pad's plum, laid at the foot of the page beside the seal; they
	# are children of the page itself, so they move and scale with it.
	_replies = Control.new()
	_replies.name = "Replies"
	_replies.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _stage != null:
		_stage.add_child(_replies)
	else:
		$Centre/Panel/Margin/Column.add_child(_replies)
	_close = MouseRowsScript.close_button(MouseRowsScript.CLOSE_TEXT,
		func(_index: int) -> void: close())
	# The kit's one Back (MenuStyle.back_button): its plum pill stands on cream as well as it
	# does on velvet, so the sheet no longer needs a paper button of its own here.
	$Centre/Panel/Margin/Column.add_child(_close)
	visible = false


func close_button_node() -> Button:
	return _close


## Show `letter`, in the shape game/systems/letters.gd's render() answers: "sender", "title"
## and "body" (an Array of lines). Refuses while one is already up, the same way every other
## panel's open() does, so a second letter cannot be drawn over the first one's pause.
##
## A COPY IS KEPT, NOT THE CALLER'S DICTIONARY. Letters.render() builds a fresh one every
## call so nothing is shared today, but a panel that could be edited from underneath by
## whoever handed it a letter is a panel that draws something nobody chose.
func open(letter: Dictionary) -> bool:
	if _open:
		return false
	_letter = letter.duplicate(true)
	_open = true
	visible = true
	refresh()
	opened.emit()
	return true


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	closed.emit()


func is_open() -> bool:
	return _open


func sender_text() -> String:
	return String(_letter.get("sender", ""))


func title_text() -> String:
	return String(_letter.get("title", ""))


## Every line of the body, in order. Public for the same reason every other panel here has a
## drawn_lines(): a test can then ask what is on the screen without walking Label nodes, and
## the dash sweep every panel is held to has something to sweep.
func drawn_lines() -> Array[String]:
	var out: Array[String] = []
	for line in _letter.get("body", []):
		out.append(String(line))
	return out


func refresh() -> void:
	if not is_node_ready():
		return
	# NO KEY HINTS (PT5; owner: "why esc back and close annoying"): the Back button is the way
	# out, and Enter and Esc still close it for a player who reaches for them.
	_footer.text = MenuStyleScript.footer([[&"ui_accept", "close"]])
	_footer.visible = false
	MenuStyleScript.style_label(_footer, MenuStyleScript.FOOTER_SIZE,
		MenuStyleScript.COLOR_INK)
	_footer.add_theme_constant_override(&"outline_size", 0)
	_build_replies()
	if _stage != null:
		_stage.custom_minimum_size = stage_size()
		_stage.queue_redraw()


## The letter's answers as buttons, rebuilt from _letter["replies"] ({label, choice} rows).
func _build_replies() -> void:
	if _replies == null:
		return
	for child in _replies.get_children():
		_replies.remove_child(child)
		child.queue_free()
	var rows: Array = _letter.get("replies", [])
	_replies.visible = not rows.is_empty()
	var k := 0
	for row: Dictionary in rows:
		var b := Button.new()
		b.text = String(row.get("label", ""))
		b.focus_mode = Control.FOCUS_NONE
		_stamp_button(b, k)
		var choice := String(row.get("choice", ""))
		b.pressed.connect(func() -> void: _answer(choice))
		_replies.add_child(b)
		k += 1
	_place_stamps()


## THE STAMPS' PLACES ON THE PAGE: left to right from the text's left edge along the foot of
## the sheet, wrapping short of the seal; [Rect2] per answer, in page pixels, for a page of
## `width`. The first row sits level with the seal; more rows push the page taller.
const STAMP_H := 52.0
const STAMP_GAP := 14.0
const STAMP_TICK := 22.0
const STAMP_FONT := 24


func stamp_rects(width: float) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var rows: Array = _letter.get("replies", [])
	var font: Font = MenuStyleScript.title_font()
	var left := SHEET_MARGIN + _REPLY_LEAD
	var right := width - SHEET_MARGIN - SEAL_SIZE - 20.0
	var x := left
	var row := 0
	for r: Dictionary in rows:
		var w: float = font.get_string_size(String(r.get("label", "")), HORIZONTAL_ALIGNMENT_LEFT,
			-1, STAMP_FONT).x + STAMP_TICK + 44.0
		if x > left and x + w > right:
			x = left
			row += 1
		out.append(Rect2(x, float(row) * (STAMP_H + STAMP_GAP), w, STAMP_H))
		x += w + STAMP_GAP
	return out


## How much taller than one stamp row the answers make the page.
func _stamp_extra(width: float) -> float:
	var rects := stamp_rects(width)
	if rects.is_empty():
		return 0.0
	var bottom := 0.0
	for r: Rect2 in rects:
		bottom = maxf(bottom, r.end.y)
	return maxf(0.0, bottom - SEAL_SIZE) + 18.0


## Room at the row's left for the hand-written "Tick one".
const _REPLY_LEAD := 118.0


## Where the first row of stamps starts on a page of `size`: level with the seal when one row
## fits beside it, else as high as the rows need.
func _stamps_top(size: Vector2) -> float:
	var bottom := 0.0
	for r: Rect2 in stamp_rects(size.x):
		bottom = maxf(bottom, r.end.y)
	if bottom <= SEAL_SIZE:
		return size.y - SHEET_MARGIN - SEAL_SIZE + (SEAL_SIZE - STAMP_H) * 0.5
	return size.y - SHEET_MARGIN - bottom


func _place_stamps() -> void:
	if _replies == null or _stage == null:
		return
	var size := stage_size()
	var rects := stamp_rects(size.x)
	_replies.position = Vector2(0.0, _stamps_top(size))
	var i := 0
	for b in reply_buttons():
		if i >= rects.size():
			break
		b.position = rects[i].position
		b.size = rects[i].size
		b.pivot_offset = rects[i].size * 0.5
		# Stamped by hand: none of them quite straight.
		b.rotation = deg_to_rad(-2.0 if i % 2 == 0 else 1.5)
		i += 1


## A RUBBER STAMP AS A BUTTON: plum stamp-pad ink on the paper, a double border, a tick box at
## its left; under the pointer the pad's ink fills it and the box gets its tick.
func _stamp_button(b: Button, index: int) -> void:
	var ink: Color = Color(PaperPaintScript.STAMP_INK, 1.0)
	var paper: Color = PaperPaintScript.PAPER.lerp(ink, 0.06)
	paper.a = 1.0
	var normal := StyleBoxFlat.new()
	normal.bg_color = paper
	normal.border_color = ink
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(5)
	normal.content_margin_left = STAMP_TICK + 22.0
	normal.content_margin_right = 16.0
	normal.anti_aliasing = true
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = ink
	hover.border_color = ink.darkened(0.3)
	hover.shadow_color = Color(ink, 0.35)
	hover.shadow_size = 6
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = ink.darkened(0.2)
	b.add_theme_stylebox_override(&"normal", normal)
	b.add_theme_stylebox_override(&"hover", hover)
	b.add_theme_stylebox_override(&"pressed", pressed)
	b.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	b.add_theme_font_override(&"font", MenuStyleScript.title_font())
	b.add_theme_font_size_override(&"font_size", STAMP_FONT)
	for slot: StringName in [&"font_color", &"font_focus_color"]:
		b.add_theme_color_override(slot, ink)
	var cream := Color(1.0, 0.97, 0.9)
	for slot: StringName in [&"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color"]:
		b.add_theme_color_override(slot, cream)
	b.add_theme_constant_override(&"outline_size", 0)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.set_meta(&"stamp", index)
	# The inner rule of a stamp and its tick box, over the face.
	b.draw.connect(func() -> void:
		var lit := b.is_hovered() or b.button_pressed
		var c: Color = cream if lit else ink
		var r := Rect2(Vector2.ZERO, b.size).grow(-6.0)
		b.draw_rect(r, Color(c, 0.6), false, 1.0)
		var box := Rect2(Vector2(14.0, (b.size.y - STAMP_TICK) * 0.5), Vector2(STAMP_TICK, STAMP_TICK))
		b.draw_rect(box, c, false, 2.5)
		if lit:
			b.draw_polyline(PackedVector2Array([box.position + Vector2(4, 11), box.position + Vector2(9, 17),
				box.position + Vector2(19, 3)]), c, 3.5, true))
	b.mouse_entered.connect(b.queue_redraw)
	b.mouse_exited.connect(b.queue_redraw)


func _answer(choice: String) -> void:
	if not _open:
		return
	replied.emit(choice)
	close()


## The answer buttons on the sheet, in order. For the tests.
func reply_buttons() -> Array[Button]:
	var out: Array[Button] = []
	if _replies != null:
		for c in _replies.get_children():
			if c is Button and not c.is_queued_for_deletion():
				out.append(c)
	return out


## THE BODY AS PARAGRAPHS (PT5; playtest 2026-11-05 item 8: the welcome letter was a narrow
## column with the right half of the sheet empty). The authored lines are hard wrapped short;
## consecutive lines join into one paragraph and wrap to the sheet's own width, and a blank
## line is still a paragraph break.
func paragraphs() -> Array[String]:
	var out: Array[String] = []
	var cur: Array[String] = []
	for line in drawn_lines():
		if line.strip_edges().is_empty():
			if not cur.is_empty():
				out.append(" ".join(cur))
				cur.clear()
			out.append("")
			continue
		# A NUMBERED STEP STARTS ITS OWN PARAGRAPH (PS6 item 8: the welcome letter's four
		# steps joined into one run on block, "1. CATCH ... 2. PEN ... 3. COLLECT ...").
		if _step_marker().search(line.strip_edges()) != null and not cur.is_empty():
			out.append(" ".join(cur))
			cur.clear()
		cur.append(line.strip_edges())
	if not cur.is_empty():
		out.append(" ".join(cur))
	return out


## THE LETTER'S HOW-TO, AS STEPS (PS6 item 8; owner: "a text wall"). A paragraph that opens
## "N. VERB" is a step: {n, verb, head, rest, icon}. `head` is its first sentence with the verb
## in sentence case ("Catch a pony."), `rest` the remainder, and `icon` the picture its tile
## wears (the HUD checklist's own Catch, Pen and Sell icons, and a gem for Collect).
func steps() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p in paragraphs():
		var step := _step(p)
		if not step.is_empty():
			out.append(step)
	return out


const STEP_ICONS := {"CATCH": &"star", "PEN": &"fence", "COLLECT": &"gem", "SELL": &"coin"}
const _STEP_PLACE_ICONS := {&"star": PlaceSignScript.Icon.STAR,
	&"fence": PlaceSignScript.Icon.FENCE, &"coin": PlaceSignScript.Icon.COIN}

static var _marker: RegEx = null


static func _step_marker() -> RegEx:
	if _marker == null:
		_marker = RegEx.create_from_string("^(\\d+)\\.\\s+([A-Z]{2,})\\b\\s*(.*)$")
	return _marker


func _step(p: String) -> Dictionary:
	var m := _step_marker().search(p)
	if m == null:
		return {}
	var verb := m.get_string(2)
	var after := m.get_string(3)
	var stop := after.find(". ")
	var head := after if stop < 0 else after.substr(0, stop + 1)
	var rest := "" if stop < 0 else after.substr(stop + 2).strip_edges()
	return {"n": int(m.get_string(1)), "verb": verb,
		"head": (verb.capitalize() + " " + head).strip_edges(), "rest": rest,
		"icon": STEP_ICONS.get(verb, &"star")}


## The step rows' measurements, in base pixels: the picture tile and the gap after a row.
const STEP_TILE := 56.0
const STEP_GAP := 12.0


## THE BODY, LAID OUT ONCE. Measures when `ci` is null and draws when it is not, so the sheet
## stage_size() reserves and the sheet paint() fills cannot disagree. Answers the height used.
func _lay_body(ci: Control, left: float, top: float, width: float) -> float:
	var font: Font = ThemeDB.fallback_font
	var bold: Font = MenuStyleScript.title_font()
	var y := top
	for p in paragraphs():
		if p.is_empty():
			y += LINE_HEIGHT * 0.6
			continue
		var step := _step(p)
		if step.is_empty():
			if ci != null:
				ci.draw_multiline_string(font, Vector2(left, y + LINE_HEIGHT * 0.75), p,
					HORIZONTAL_ALIGNMENT_LEFT, width, MenuStyleScript.ROW_SIZE, -1,
					MenuStyleScript.COLOR_INK)
			y += font.get_multiline_string_size(p, HORIZONTAL_ALIGNMENT_LEFT, width,
				MenuStyleScript.ROW_SIZE).y + LINE_HEIGHT * 0.25
			continue
		# A STEP ROW: its picture on a tile, the step in bold beside it, the how-to under that.
		var text_left := left + STEP_TILE + 18.0
		var text_width := width - STEP_TILE - 18.0
		var head := String(step.head)
		var rest := String(step.rest)
		var head_h := bold.get_multiline_string_size(head, HORIZONTAL_ALIGNMENT_LEFT,
			text_width, MenuStyleScript.ROW_SIZE).y
		var rest_h := 0.0 if rest.is_empty() else font.get_multiline_string_size(rest,
			HORIZONTAL_ALIGNMENT_LEFT, text_width, MenuStyleScript.FOOTER_SIZE).y + 4.0
		var row_h := maxf(STEP_TILE, head_h + rest_h)
		if ci != null:
			_paint_step_tile(ci, Rect2(left, y + (row_h - STEP_TILE) * 0.5, STEP_TILE,
				STEP_TILE), StringName(step.icon), int(step.n))
			var text_top := y + (row_h - head_h - rest_h) * 0.5
			ci.draw_multiline_string(bold, Vector2(text_left, text_top + LINE_HEIGHT * 0.75),
				head, HORIZONTAL_ALIGNMENT_LEFT, text_width, MenuStyleScript.ROW_SIZE, -1,
				MenuStyleScript.COLOR_INK)
			if not rest.is_empty():
				ci.draw_multiline_string(font,
					Vector2(text_left, text_top + head_h + 4.0 + LINE_HEIGHT * 0.65), rest,
					HORIZONTAL_ALIGNMENT_LEFT, text_width, MenuStyleScript.FOOTER_SIZE, -1,
					MenuStyleScript.COLOR_INK)
		y += row_h + STEP_GAP
	return y - top


## One step's tile: the HUD checklist's own white rounded tile and icon, with the step's
## number on a violet badge at its corner.
func _paint_step_tile(ci: Control, r: Rect2, icon: StringName, n: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(14)
	sb.bg_color = Color(1, 1, 1, 0.9)
	sb.border_color = MenuStyleScript.PAPER_BUTTON_EDGE
	sb.set_border_width_all(2)
	ci.draw_style_box(sb, r)
	var inner := r.grow(-9.0)
	if _STEP_PLACE_ICONS.has(icon):
		ci.draw_texture_rect(PlaceSignScript.icon_texture(int(_STEP_PLACE_ICONS[icon])), inner,
			false)
	else:
		_paint_gem(ci, inner)
	var badge := r.position + Vector2(3.0, 3.0)
	ci.draw_circle(badge, 11.0, PaperPaintScript.STAMP_INK)
	ci.draw_string(MenuStyleScript.title_font(), badge + Vector2(-5.0, 6.0), str(n),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)


## A gem, the thing a happy pony leaves in her pen: the Market's own cut, in its rare blue.
static func _paint_gem(ci: Control, box: Rect2) -> void:
	var c := box.get_center() + Vector2(0.0, box.size.y * 0.04)
	var r := box.size.x * 0.44
	var pts := PackedVector2Array([c + Vector2(-r, -r * 0.35), c + Vector2(-r * 0.5, -r * 0.85),
		c + Vector2(r * 0.5, -r * 0.85), c + Vector2(r, -r * 0.35), c + Vector2(0, r)])
	var fill := Color(0.45, 0.55, 1.0)
	ci.draw_colored_polygon(pts, fill)
	var edge := pts.duplicate()
	edge.append(pts[0])
	ci.draw_polyline(edge, fill.darkened(0.45), 2.5, true)
	ci.draw_line(pts[0], pts[3], fill.darkened(0.45), 2.0, true)
	ci.draw_line(c + Vector2(-r * 0.35, -r * 0.35), c + Vector2(0, r), Color(1, 1, 1, 0.6),
		2.0, true)


func _body_height(width: float) -> float:
	return _lay_body(null, 0.0, 0.0, width)


# --- the sheet ------------------------------------------------------------------------------
#
## THE PAGE IS DRAWN AND THE TEXT IS LAID OVER IT. game/ui/paper_paint.gd already knows how to
## draw a sheet with a drop shadow, a letterhead with the Company's cloud and bolt, and a wax
## seal; the Mail page in the pause menu has used it since the story slice. This is the same
## kit under the reader, so the letter she opens at the mailbox and the copy she re reads in
## the archive are made of the same paper.


## How tall a sheet this letter needs. Grows with the body rather than clipping it, which is
## the whole difference between a page and a text box. Reserves height for exactly what
## paint() draws below: the letterhead, one row for the title, one row per body line, and
## the seal -- nothing here is reserved twice.
func stage_size() -> Vector2:
	var body := maxf(_body_height(SHEET_WIDTH - SHEET_MARGIN * 2.0), LINE_HEIGHT)
	return Vector2(SHEET_WIDTH,
		HEAD_HEIGHT + SHEET_MARGIN + TITLE_HEIGHT + body + SEAL_SIZE + SHEET_MARGIN
		+ _stamp_extra(SHEET_WIDTH))


## THE WHOLE LETTER, DRAWN ONCE. Sheet, letterhead (which prints the sender itself), the
## title, every body line and the seal all land on `ci` here and nowhere else -- there is no
## Label anywhere in this scene printing any of the same words a second time.
func paint(ci: Control) -> void:
	if ci == null:
		return
	var box := Rect2(Vector2.ZERO, ci.size)
	PaperPaintScript.sheet(ci, box)
	var font: Font = ThemeDB.fallback_font
	var text_left: float = box.position.x + SHEET_MARGIN
	var text_width: float = box.size.x - SHEET_MARGIN * 2.0
	var head_top: float = box.position.y + SHEET_MARGIN * 0.4
	PaperPaintScript.letterhead(ci, Rect2(text_left, head_top, text_width, HEAD_HEIGHT),
		font, sender_text())

	# THE TITLE, THEN THE BODY, straight onto the paper in ink -- no outline, the same call
	# a stamp or a coupon's word would use, minus the outline pass casino_paint.gd's own
	# text() always adds: ink on cream reads fine without one, and an outline meant for a
	# translucent menu panel is exactly the "week" look this task exists to remove.
	var row_top: float = head_top + HEAD_HEIGHT
	ci.draw_string(MenuStyleScript.title_font(), Vector2(text_left, row_top + TITLE_HEIGHT * 0.75),
		title_text(), HORIZONTAL_ALIGNMENT_LEFT, text_width, MenuStyleScript.TITLE_SIZE,
		PaperPaintScript.HAND_INK)
	row_top += TITLE_HEIGHT
	_lay_body(ci, text_left, row_top, text_width)

	# THE SEAL SITS UNDER THE SIGN OFF, bottom right, where a seal goes.
	var seal := Rect2(box.size.x - SHEET_MARGIN - SEAL_SIZE,
		box.size.y - SHEET_MARGIN - SEAL_SIZE, SEAL_SIZE, SEAL_SIZE)
	PaperPaintScript.wax_seal(ci, seal.get_center() + Vector2(0, -SEAL_SIZE * 0.12),
		SEAL_SIZE * 0.42)
	# THE ANSWER LINE: "Tick one" in the hand that signed the letter, a ruled line under the
	# stamps the way a form leaves room for a mark.
	if not (_letter.get("replies", []) as Array).is_empty():
		var top := _stamps_top(box.size)
		ci.draw_string(PaperPaintScript.hand_font(), Vector2(text_left, top + STAMP_H * 0.68),
			"Tick one", HORIZONTAL_ALIGNMENT_LEFT, _REPLY_LEAD - 10.0, 26, PaperPaintScript.HAND_INK)
		var rule_y: float = box.size.y - SHEET_MARGIN + 6.0
		ci.draw_line(Vector2(text_left, rule_y), Vector2(seal.position.x - 20.0, rule_y),
			Color(PaperPaintScript.HAND_INK, 0.25), 1.5, true)


## M10, final-review.md M2: A CLICK OFF THE SHEET CLOSES THE LETTER. Wired to Dim's own
## gui_input in _ready(). The Stage is a STOP sibling drawn over Dim, so a click ON the
## sheet lands there and does nothing -- deliberately: a reader resting her cursor on the
## page must not lose the letter to a stray click. Only the dimmed margin around the paper
## reaches Dim and closes. The Close button under the footer is the discoverable version.
func _on_dim_input(event: InputEvent) -> void:
	if not _open or not MouseRowsScript.is_left_click(event):
		return
	close()
	get_viewport().set_input_as_handled()


## CONFIRM AND CANCEL BOTH CLOSE IT, and that is not laziness. There is nothing on this page
## to confirm, so a player who presses the confirm key on a letter she has finished reading
## means "done"; a page that answered that with silence would be the same class of dead
## control the race panel's old stake row was.
func _unhandled_input(event: InputEvent) -> void:
	if not _open or not event.is_pressed():
		return
	if event.is_action(&"ui_accept") or event.is_action(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
