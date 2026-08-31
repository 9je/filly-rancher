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


func before_each() -> void:
	InputDeviceScript.reset()


func _panel() -> LetterPanel:
	var panel: LetterPanel = LetterPanelScene.instantiate()
	add_child_autofree(panel)
	return panel


func _welcome() -> Dictionary:
	return LettersScript.render(LettersScript.Id.WELCOME,
		{"name": "Twilight", "balance": 25000, "quota": 3})


func test_a_fresh_panel_is_shut_and_shows_nothing() -> void:
	var panel := _panel()
	assert_false(panel.is_open())
	assert_false(panel.visible, "a panel nobody opened must not be over the world")
	assert_eq(panel.drawn_lines().size(), 0)


func test_it_shows_the_sender_the_title_and_every_line_of_the_body() -> void:
	var panel := _panel()
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
## about, so the Label nodes themselves are counted and read.
func test_the_body_reaches_the_labels_rather_than_only_the_getter() -> void:
	var panel := _panel()
	var letter: Dictionary = _welcome()
	panel.open(letter)
	var rows := panel.get_node(^"Centre/Panel/Margin/Column/Rows") as VBoxContainer
	assert_eq(rows.get_child_count(), panel.drawn_lines().size(),
		"one Label per line of the letter")
	var drawn: Array[String] = []
	for child in rows.get_children():
		drawn.append((child as Label).text)
	var joined: String = "\n".join(drawn)
	for step: String in ["CATCH", "PEN", "COLLECT", "SELL"]:
		assert_true(joined.contains(step), "the drawn page must name '%s'" % step)


## A BLANK LINE IS A PARAGRAPH BREAK. An empty Label collapses to nothing and would close
## the gaps the letter was written with, so an empty line is drawn as a space.
func test_the_blank_lines_between_paragraphs_survive() -> void:
	var panel := _panel()
	panel.open(LettersScript.render(LettersScript.Id.WELCOME, {"name": "M", "quota": 1}))
	var rows := panel.get_node(^"Centre/Panel/Margin/Column/Rows") as VBoxContainer
	for child in rows.get_children():
		assert_false((child as Label).text.is_empty(),
			"a Label with no text at all has no height and closes the paragraph gap")


func test_confirm_closes_it() -> void:
	var panel := _panel()
	panel.open(_welcome())
	var event := InputEventAction.new()
	event.action = &"ui_accept"
	event.pressed = true
	panel._unhandled_input(event)
	assert_false(panel.is_open(), "the confirm key on a page with nothing to confirm means done")
	assert_false(panel.visible)


func test_cancel_closes_it_too() -> void:
	var panel := _panel()
	panel.open(_welcome())
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	panel._unhandled_input(event)
	assert_false(panel.is_open())


func test_it_says_so_when_it_opens_and_when_it_closes() -> void:
	var panel := _panel()
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
	var panel := _panel()
	assert_true(panel.open(_welcome()))
	assert_false(panel.open(LettersScript.render(LettersScript.Id.QUOTA_REMINDER,
		{"name": "Twilight", "quota": 3, "count": 1})),
		"a letter opened over an open letter would strand the pause")
	assert_eq(panel.title_text(), String(_welcome()["title"]),
		"...and the first letter is still the one on the screen")


func test_the_panel_keeps_its_own_copy_of_the_letter() -> void:
	var panel := _panel()
	var letter: Dictionary = _welcome()
	panel.open(letter)
	letter["title"] = "Something else entirely"
	assert_ne(panel.title_text(), "Something else entirely",
		"a page that can be edited from underneath draws something nobody chose")


func test_nothing_it_draws_carries_a_dash() -> void:
	for id: int in LettersScript.ids():
		var panel := _panel()
		panel.open(LettersScript.render(id, {"name": "Moonbeam", "count": 3, "credit": 300,
			"pony": "Trixie", "quota": 2, "balance": 25000, "upkeep": 3150,
			"punishment": "a fee of 500 bits"}))
		var joined: String = panel.sender_text() + "\n" + panel.title_text() + "\n" \
			+ "\n".join(panel.drawn_lines())
		assert_false(joined.contains("--") or joined.contains("—"), joined)


func test_it_wears_the_one_menu_style_like_every_other_panel() -> void:
	var panel := _panel()
	panel.open(_welcome())
	var title := panel.get_node(^"Centre/Panel/Margin/Column/Title") as Label
	assert_eq(title.get_theme_font_size("font_size"), MenuStyleScript.TITLE_SIZE)
	assert_eq(title.get_theme_constant("outline_size"), MenuStyleScript.OUTLINE_SIZE)
	var footer := panel.get_node(^"Centre/Panel/Margin/Column/Footer") as Label
	assert_ne(footer.text.strip_edges(), "", "the page says how to leave it")
