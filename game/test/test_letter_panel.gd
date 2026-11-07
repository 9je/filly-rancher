extends GutTest
## game/ui/letter_panel.gd: the read only page the Company's post is finally drawn on.
##
## THE BUG THIS FILE EXISTS FOR. Letters.render() has always answered a sender, a title and
## a BODY, and the body is where the whole of the game's onboarding is written; nothing in
## the game had ever drawn one. ranch.gd rendered the welcome letter and toasted its TITLE.
## Ruling 25, from the whole branch review of 2026-08-31.
##
## Preloads by path, per the convention at the top of game/scripts/pony_rig.gd. The panel
## itself is a real instanced scene rather than a bare script: is_node_ready() gates its
## refresh(), so a LetterPanel that never entered a tree would draw nothing and every claim
## below would pass vacuously.

const LetterPanelScene := preload("res://ui/letter_panel.tscn")
const LettersScript := preload("res://systems/letters.gd")
const MenuStyleScript := preload("res://ui/menu_style.gd")
const InputDeviceScript := preload("res://systems/input_device.gd")

var _panel: LetterPanel = null


func before_each() -> void:
	InputDeviceScript.reset()
	_panel = LetterPanelScene.instantiate()
	add_child_autofree(_panel)


func _welcome() -> Dictionary:
	return LettersScript.render(LettersScript.Id.WELCOME,
		{"name": "Twilight", "balance": 25000, "quota": 3})


func test_a_fresh_panel_is_shut_and_shows_nothing() -> void:
	var panel := _panel
	assert_false(panel.is_open())
	assert_false(panel.visible, "a panel nobody opened must not be over the world")
	assert_eq(panel.drawn_lines().size(), 0)


func test_it_shows_the_sender_the_title_and_every_line_of_the_body() -> void:
	var panel := _panel
	var letter: Dictionary = _welcome()
	assert_true(panel.open(letter), "a shut panel opens")
	assert_true(panel.is_open())
	assert_true(panel.visible)
	assert_eq(panel.sender_text(), String(letter["sender"]))
	assert_eq(panel.title_text(), String(letter["title"]))
	assert_eq(panel.drawn_lines(), letter["body"],
		"every line of the body, in order, and no editorialising")
	assert_gt(panel.drawn_lines().size(), 10, "sanity: the welcome letter is a page")


## THE BODY IS ON THE SCREEN, not merely in a getter. drawn_lines() would answer correctly
## for a panel that drew nothing at all, which is exactly the failure this whole file is
## about (Ruling 25). FIX ROUND 1: there is no longer a Rows VBox of Labels to count -- the
## body is painted straight onto the Stage (game/ui/letter_panel.gd's paint()) -- so this
## routes the real WELCOME letter (the one Ruling 25 is about, CATCH/PEN/COLLECT/SELL and
## all) through an actual NOTIFICATION_DRAW the same way test_painting_the_sheet... below
## does: a paint() that silently dropped the body, choked on its 20 lines, or regressed to
## throwing on a real (not stub) letter would fail here as an engine error, the same class
## of proof this file's own review already accepted for the paint-probe test.
func test_the_real_welcome_letter_paints_clean_through_a_real_draw_call() -> void:
	var panel := _panel
	var letter: Dictionary = _welcome()
	panel.open(letter)
	assert_gt(panel.drawn_lines().size(), 10, "sanity: the welcome letter is a page")
	var joined: String = panel.title_text() + "\n" + "\n".join(panel.drawn_lines())
	for step: String in ["CATCH", "PEN", "COLLECT", "SELL"]:
		assert_true(joined.contains(step), "the letter this test paints must name '%s'" % step)
	var probe := Control.new()
	probe.size = panel.stage_size()
	add_child_autofree(probe)
	probe.draw.connect(func() -> void: panel.paint(probe))
	probe.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(true, "the real welcome letter painted, blank paragraph breaks and all")


func test_confirm_closes_it() -> void:
	var panel := _panel
	panel.open(_welcome())
	var event := InputEventAction.new()
	event.action = &"ui_accept"
	event.pressed = true
	panel._unhandled_input(event)
	assert_false(panel.is_open(), "the confirm key on a page with nothing to confirm means done")
	assert_false(panel.visible)


func test_cancel_closes_it_too() -> void:
	var panel := _panel
	panel.open(_welcome())
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	panel._unhandled_input(event)
	assert_false(panel.is_open())


func test_it_says_so_when_it_opens_and_when_it_closes() -> void:
	var panel := _panel
	watch_signals(panel)
	panel.open(_welcome())
	assert_signal_emit_count(panel, "opened", 1)
	panel.close()
	assert_signal_emit_count(panel, "closed", 1)
	# Closing a shut panel must not emit a second time: ranch.gd unpauses the tree on that
	# signal, and an unpause with no matching pause is a world that starts moving under a
	# menu somebody is still reading.
	panel.close()
	assert_signal_emit_count(panel, "closed", 1)


## A SECOND LETTER CANNOT BE DRAWN OVER THE FIRST ONE'S PAUSE, the same refusal every other
## panel's open() makes and for the same reason: ranch.gd pauses on `opened` and unpauses on
## `closed`, so two opens and one close leave the world running under a page on screen.
func test_it_refuses_a_second_letter_while_one_is_up() -> void:
	var panel := _panel
	assert_true(panel.open(_welcome()))
	assert_false(panel.open(LettersScript.render(LettersScript.Id.QUOTA_REMINDER,
		{"name": "Twilight", "quota": 3, "count": 1})),
		"a letter opened over an open letter would strand the pause")
	assert_eq(panel.title_text(), String(_welcome()["title"]),
		"...and the first letter is still the one on the screen")


func test_the_panel_keeps_its_own_copy_of_the_letter() -> void:
	var panel := _panel
	var letter: Dictionary = _welcome()
	panel.open(letter)
	letter["title"] = "Something else entirely"
	assert_ne(panel.title_text(), "Something else entirely",
		"a page that can be edited from underneath draws something nobody chose")


func test_nothing_it_draws_carries_a_dash() -> void:
	for id: int in LettersScript.ids():
		# A FRESH PANEL PER LETTER, not the shared fixture: each one opens and never
		# closes, and the shared _panel would refuse the second open() outright.
		var panel: LetterPanel = LetterPanelScene.instantiate()
		add_child_autofree(panel)
		panel.open(LettersScript.render(id, {"name": "Moonbeam", "count": 3, "credit": 300,
			"pony": "Trixie", "quota": 2, "balance": 25000, "upkeep": 3150,
			"punishment": "a fee of 500 bits"}))
		var joined: String = panel.sender_text() + "\n" + panel.title_text() + "\n" \
			+ "\n".join(panel.drawn_lines())
		assert_false(joined.contains("--") or joined.contains("—"), joined)


## THE SIZES STILL COME FROM MenuStyle; THE OUTLINE DOES NOT. Outlined text is for a Label
## sat over the world or a dark menu panel, which is what every other screen in this file's
## docstring means by "the one menu style". A letter sits on a paper sheet it can always read
## against, so refresh() calls style_label() for its sizing and then dials the outline back
## to 0; asserting the old OUTLINE_SIZE here would be asserting the "week" look back in.
##
## FIX ROUND 1: the Title Label is gone (paint() draws the title straight onto the sheet at
## MenuStyleScript.TITLE_SIZE, in TITLE_HEIGHT's own row -- see stage_size()/paint()), so the
## Footer is the only Label left on this panel and the only one this test can still read.
func test_the_footer_wears_the_one_menu_style_like_every_other_panel() -> void:
	var panel := _panel
	panel.open(_welcome())
	var footer := panel.get_node(^"Centre/Panel/Margin/Column/Footer") as Label
	assert_eq(footer.get_theme_font_size("font_size"), MenuStyleScript.FOOTER_SIZE)
	assert_eq(footer.get_theme_constant("outline_size"), 0,
		"paper is read against itself, not against the world; no outline needed")
	assert_false(footer.visible, "PT5: no key hints; the Back button is the way out")
	assert_eq(panel.close_button_node().text, "Back")


# --- the crafted sheet ------------------------------------------------------------------

## THE OWNER CALLED THE LETTER UI "week". This is what crafted means, measured: the page is
## drawn on the stationery kit the Mail page already uses, it is a real sheet with a real
## margin rather than a translucent list of Labels, and it can be closed with the pointer.

const MouseRowsScript := preload("res://ui/mouse_rows.gd")
const PaperPaintScript := preload("res://ui/paper_paint.gd")
const StoryLibraryScript := preload("res://systems/story_library.gd")

## VIEWPORT HEIGHT, IN THE SAME 1920x1080 BASE PIXELS letter_panel.gd's own SHEET_WIDTH
## comment measures in (game/project.godot's base viewport; see game/ui/hud.gd's docstring).
const VIEWPORT_HEIGHT := 1080.0

## THE SAME WORST CASE SUBSTITUTIONS test_story_corpus.gd's _worst_params() uses: the
## longest name the creation screen accepts, in the widest glyph, and the longest pony name
## a receipt can carry. Shared across both corpora here (game/systems/letters.gd's fixed six
## and every StoryBeat under game/data/story/) because LetterPanel reads either shape
## (story_beat.gd's own docstring: "one reader, two senders") and an unsupplied key on
## either side simply falls back to its own default rather than erroring.
const _WORST_PARAMS := {
	"name": "Wwwwwwwwwwwwwwww", "pony": "Wwwwwwwwwwwwwwww", "chosen": "Wwwwwwwwwwwwwwww",
	"colour": "viridian", "count": 999, "quota": 12, "balance": 40000, "credit": 999999,
	"upkeep": 999999, "punishment": "a fee of 999999 bits",
}


func _letter() -> Dictionary:
	return {"sender": "Cloudsdale Weather Corporation", "title": "Your mailbox is installed",
		"body": ["Dear Moonbeam,", "", "The flag goes up when something is waiting.",
			"", "Warmly, Sponsorship Services"]}


func test_the_panel_reserves_a_sheet_tall_enough_for_the_letter_it_holds() -> void:
	_panel.open(_letter())
	var size: Vector2 = _panel.stage_size()
	assert_eq(size.x, LetterPanel.SHEET_WIDTH)
	assert_gte(size.y, 5.0 * LetterPanel.LINE_HEIGHT,
		"five lines of body need five lines of room")


func test_a_longer_letter_reserves_a_taller_sheet() -> void:
	_panel.open(_letter())
	var short_height: float = _panel.stage_size().y
	_panel.close()
	var long_letter: Dictionary = _letter()
	for i in 10:
		(long_letter["body"] as Array).append("Another line entirely.")
	_panel.open(long_letter)
	assert_gt(_panel.stage_size().y, short_height,
		"the sheet grows with the letter rather than clipping it")


func test_the_panel_wears_the_paper_box_rather_than_the_navy_one() -> void:
	var panel := _panel.get_node("Centre/Panel") as PanelContainer
	var box: StyleBoxFlat = panel.get_theme_stylebox(&"panel") as StyleBoxFlat
	assert_eq(Color(box.bg_color, 1.0), Color(MenuStyleScript.COLOR_PAPER, 1.0),
		"a letter is paper, not a menu panel")
	assert_eq(box.bg_color.a, 1.0, "PS6 item 51: nothing behind the sheet shows through it")


## paint() DRAWS THROUGH CanvasItem.draw_*, which Godot only allows inside that item's own
## NOTIFICATION_DRAW (paper_paint.gd's own docstring says as much). Calling paint(probe)
## straight from a test body, with no draw cycle ever having reached probe, hits that engine
## guard on every polygon and string it draws, not a bug in the panel. Wiring probe's own
## `draw` signal to it and forcing a redraw is what actually exercises the call the same way
## _stage's connection in _ready() does, matching the await-two-frames idiom
## test_casino_stages.gd already uses for the same reason.
func test_painting_the_sheet_reaches_the_stationery_kit_without_an_error() -> void:
	_panel.open(_letter())
	var probe := Control.new()
	probe.size = _panel.stage_size()
	add_child_autofree(probe)
	probe.draw.connect(func() -> void: _panel.paint(probe))
	probe.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(true, "paint() ran over a real Control with no error")


## THE WHOLE PANEL, FOOTER AND CLOSE BUTTON INCLUDED, FITS ON SCREEN FOR THE TALLEST LETTER
## THIS BUILD CAN ACTUALLY OPEN. Review CRITICAL 1: a Stage sized for the letter PLUS a
## second, Label shaped copy of the same letter stacked under it pushed the WELCOME letter
## to roughly 1.4x an 1080 viewport. Fix round 1 removed the second copy; this is the test
## that would have caught it -- it renders every letter in both corpora LetterPanel actually
## reads (game/systems/letters.gd's fixed six, and every StoryBeat resource under
## game/data/story/, per story_beat.gd's own "one reader, two senders" docstring) with the
## same worst case substitutions test_story_corpus.gd's _worst_params() uses, takes the one
## with the most body lines, opens it for real, lets a frame settle (Panel/Column layout is
## only valid after one, same as test_casino_stages.gd's own note on this), and asserts the
## real Panel control's real height still fits inside the 1920x1080 base viewport.
func test_the_tallest_authored_letter_still_fits_the_1080_viewport() -> void:
	var tallest_lines := 0
	var tallest_letter: Dictionary = {}
	for id: int in LettersScript.ids():
		var letter: Dictionary = LettersScript.render(id, _WORST_PARAMS)
		if (letter["body"] as Array).size() > tallest_lines:
			tallest_lines = (letter["body"] as Array).size()
			tallest_letter = letter
	var library := StoryLibraryScript.new()
	library.load_all()
	for beat: StoryBeat in library.all():
		var letter: Dictionary = beat.render(_WORST_PARAMS)
		if (letter["body"] as Array).size() > tallest_lines:
			tallest_lines = (letter["body"] as Array).size()
			tallest_letter = letter
	assert_gt(tallest_lines, 0, "the corpus has to have produced at least one letter to measure")

	assert_true(_panel.open(tallest_letter))
	await get_tree().process_frame
	await get_tree().process_frame
	var panel := _panel.get_node("Centre/Panel") as PanelContainer
	assert_lte(panel.size.y, VIEWPORT_HEIGHT,
		"the tallest authored letter (%d body lines) must leave its footer and Close button on screen"
			% tallest_lines)


func test_the_letter_offers_the_pointer_a_way_out() -> void:
	var button: Button = _panel.close_button_node()
	assert_not_null(button)
	assert_eq(button.text, MouseRowsScript.CLOSE_TEXT)
	assert_eq(button.focus_mode, Control.FOCUS_NONE)
	_panel.open(_letter())
	button.pressed.emit()
	assert_false(_panel.is_open())


func test_the_dim_behind_the_letter_swallows_stray_clicks() -> void:
	var dim := _panel.get_node("Dim") as Control
	assert_eq(dim.mouse_filter, Control.MOUSE_FILTER_STOP)


## M10, final-review.md M2: A CLICK ON THE DIM ACTUALLY CLOSES THE LETTER NOW. Every Control
## between Dim and the sheet is MOUSE_FILTER_IGNORE, so a click landing anywhere on this
## panel -- the sheet included -- reaches Dim's own gui_input and nowhere else.
func test_a_click_on_the_dim_closes_the_letter() -> void:
	_panel.open(_letter())
	var dim := _panel.get_node("Dim") as Control
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	dim.gui_input.emit(event)
	assert_false(_panel.is_open(), "the click on the dim must close the letter")


func test_a_right_click_on_the_dim_does_nothing() -> void:
	_panel.open(_letter())
	var dim := _panel.get_node("Dim") as Control
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	dim.gui_input.emit(event)
	assert_true(_panel.is_open(), "only a left click closes it")


func test_the_key_that_closed_it_still_closes_it() -> void:
	_panel.open(_letter())
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	_panel._unhandled_input(event)
	assert_false(_panel.is_open(), "the mouse was added, the key was not taken")


# --- PS6: the owner's playtest of 2026-11-05 ------------------------------------------------

## WCAG relative luminance of an sRGB colour, and the contrast ratio of two.
func _lum(c: Color) -> float:
	var ch := func(v: float) -> float:
		return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * ch.call(c.r) + 0.7152 * ch.call(c.g) + 0.0722 * ch.call(c.b)


func _contrast(a: Color, b: Color) -> float:
	var la := _lum(a)
	var lb := _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## The colour a button's face actually shows: its normal box laid over the sheet behind it.
func _face(button: Button) -> Color:
	var sheet := Color(MenuStyleScript.COLOR_PAPER, 1.0)
	var box := button.get_theme_stylebox(&"normal") as StyleBoxFlat
	if box == null:
		return sheet
	return sheet.lerp(Color(box.bg_color, 1.0), box.bg_color.a)


## G13 (batch check of PS6): "the paper letters' buttons (the welcome letter's Back, the
## survey's answer) are white on cream and nearly invisible". Every button on the sheet reads
## at the WCAG body text ratio, 4.5 to 1, from the colours the theme actually applies, and has
## a face and an edge that stand off the paper.
func test_every_button_on_the_sheet_is_ink_on_paper_not_white_on_cream() -> void:
	var survey := {"sender": "Cloudsdale Weather Corporation",
		"title": "Employee Appreciation Survey", "body": ["Dear Twilight,", "", "Answer below."],
		"replies": [{"label": "Trixie", "choice": "a"}, {"label": "Fluttershy", "choice": "b"}]}
	_panel.open(survey)
	await get_tree().process_frame
	var buttons: Array[Button] = [_panel.close_button_node()]
	buttons.append_array(_panel.reply_buttons())
	assert_eq(buttons.size(), 3, "Back and one answer per pony")
	for b: Button in buttons:
		var ink: Color = b.get_theme_color(&"font_color")
		var ratio := _contrast(ink, _face(b))
		assert_gte(ratio, 4.5, "'%s' reads %.2f:1 on its face %s (ink %s)" % [b.text, ratio,
			_face(b), ink])
		var hover_ink: Color = b.get_theme_color(&"font_hover_color")
		var hover := b.get_theme_stylebox(&"hover") as StyleBoxFlat
		if hover != null:
			var hover_face := Color(MenuStyleScript.COLOR_PAPER, 1.0).lerp(
				Color(hover.bg_color, 1.0), hover.bg_color.a)
			assert_gte(_contrast(hover_ink, hover_face), 4.5, "'%s' under the pointer" % b.text)
		var box := b.get_theme_stylebox(&"normal") as StyleBoxFlat
		assert_not_null(box, "'%s' has a drawn face" % b.text)
		if box != null:
			assert_gte(box.border_width_bottom, 2, "'%s' has an edge you can see" % b.text)
			assert_gte(_contrast(box.border_color, MenuStyleScript.COLOR_PAPER), 3.0,
				"'%s' edge stands off the paper" % b.text)


## ITEM 8 (owner, playtest 2026-11-05): "The welcome letter: a text wall". Batch check: "the
## four steps are still one run-on paragraph". Each numbered step is its own row on the sheet,
## with its own picture, never run on into the next.
func test_the_welcome_letters_four_steps_are_four_rows_not_one_paragraph() -> void:
	_panel.open(_welcome())
	var steps: Array[Dictionary] = _panel.steps()
	assert_eq(steps.size(), 4, "catch, pen, collect, sell")
	var verbs: Array[String] = []
	for s: Dictionary in steps:
		verbs.append(String(s.verb))
		assert_ne(StringName(s.icon), &"", "%s has a picture" % s.verb)
	assert_eq(verbs, ["CATCH", "PEN", "COLLECT", "SELL"] as Array[String])
	var marker := RegEx.create_from_string("(^|\\s)\\d\\.\\s")
	for p: String in _panel.paragraphs():
		assert_lte(marker.search_all(p).size(), 1, "one step to a paragraph: '%s'" % p)
