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

## THE SHEET, IN 1920x1080 BASE PIXELS. The width is the Panel's existing 860 so nothing
## about where the letter sits on screen moves; the rest is what turns a column of Labels
## into a page: a margin the text does not touch, and a line height a letter breathes at.
const SHEET_WIDTH := 860.0
const LINE_HEIGHT := 26.0
const SHEET_MARGIN := 44.0

## The letterhead band at the top of the sheet, and the wax seal at the bottom of it.
const HEAD_HEIGHT := 76.0
const SEAL_SIZE := 46.0

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
var _replies: HFlowContainer = null

@onready var _footer: Label = $Centre/Panel/Margin/Column/Footer
@onready var _stage: Control = get_node_or_null(^"Centre/Panel/Margin/Column/Stage")


func _ready() -> void:
	# THE PANEL IS PAPER NOW, NOT A MENU. MenuStyle.apply_panel() put the dark navy box
	# behind it, which is right for a list and wrong for a letter; the owner's word for the
	# result was "week". paper_box() is the same warm sheet game/ui/paper_paint.gd draws the
	# Mail page's stationery on, so the reader and the archive are made of one material.
	var panel := $Centre/Panel as PanelContainer
	panel.add_theme_stylebox_override(&"panel", MenuStyleScript.paper_box())
	var dim := get_node_or_null(^"Dim") as Control
	if dim != null:
		dim.mouse_filter = Control.MOUSE_FILTER_STOP
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
	# THE ANSWERS, ON THE SHEET (PT5; playtest 2026-11-05: the survey said "answer below" and
	# below was another page). One chip per answer, under the letter, above the way out.
	_replies = HFlowContainer.new()
	_replies.name = "Replies"
	_replies.add_theme_constant_override(&"h_separation", 10)
	_replies.add_theme_constant_override(&"v_separation", 10)
	_replies.custom_minimum_size = Vector2(SHEET_WIDTH, 0.0)
	$Centre/Panel/Margin/Column.add_child(_replies)
	_close = MouseRowsScript.close_button(MouseRowsScript.CLOSE_TEXT,
		func(_index: int) -> void: close())
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
	for row: Dictionary in rows:
		var b := Button.new()
		b.text = String(row.get("label", ""))
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override(&"font_size", MenuStyleScript.font_px(MenuStyleScript.ROW_SIZE))
		var choice := String(row.get("choice", ""))
		b.pressed.connect(func() -> void: _answer(choice))
		_replies.add_child(b)


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
		cur.append(line.strip_edges())
	if not cur.is_empty():
		out.append(" ".join(cur))
	return out


func _body_height(width: float) -> float:
	var font: Font = ThemeDB.fallback_font
	var h := 0.0
	for p in paragraphs():
		if p.is_empty():
			h += LINE_HEIGHT * 0.6
			continue
		h += font.get_multiline_string_size(p, HORIZONTAL_ALIGNMENT_LEFT, width,
			MenuStyleScript.ROW_SIZE).y + LINE_HEIGHT * 0.25
	return h


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
		HEAD_HEIGHT + SHEET_MARGIN + TITLE_HEIGHT + body + SEAL_SIZE + SHEET_MARGIN)


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
	ci.draw_string(font, Vector2(text_left, row_top + TITLE_HEIGHT * 0.75), title_text(),
		HORIZONTAL_ALIGNMENT_LEFT, text_width, MenuStyleScript.TITLE_SIZE,
		MenuStyleScript.COLOR_INK)
	row_top += TITLE_HEIGHT
	for p in paragraphs():
		if p.is_empty():
			row_top += LINE_HEIGHT * 0.6
			continue
		ci.draw_multiline_string(font, Vector2(text_left, row_top + LINE_HEIGHT * 0.75), p,
			HORIZONTAL_ALIGNMENT_LEFT, text_width, MenuStyleScript.ROW_SIZE, -1,
			MenuStyleScript.COLOR_INK)
		row_top += font.get_multiline_string_size(p, HORIZONTAL_ALIGNMENT_LEFT, text_width,
			MenuStyleScript.ROW_SIZE).y + LINE_HEIGHT * 0.25

	# THE SEAL SITS UNDER THE SIGN OFF, bottom right, where a seal goes.
	var seal := Rect2(box.size.x - SHEET_MARGIN - SEAL_SIZE,
		box.size.y - SHEET_MARGIN - SEAL_SIZE, SEAL_SIZE, SEAL_SIZE)
	ci.draw_circle(seal.get_center(), SEAL_SIZE * 0.5, PaperPaintScript.WAX)
	PaperPaintScript.logo_mark(ci, seal.grow(-SEAL_SIZE * 0.24),
		Color(1.0, 1.0, 1.0, 0.85), Color(1.0, 0.92, 0.55, 0.95))


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
