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

const MenuStyleScript := preload("res://ui/menu_style.gd")

signal opened()
signal closed()

var _open := false
var _letter: Dictionary = {}

@onready var _title: Label = $Centre/Panel/Margin/Column/Title
@onready var _sender: Label = $Centre/Panel/Margin/Column/Sender
@onready var _rows: VBoxContainer = $Centre/Panel/Margin/Column/Rows
@onready var _footer: Label = $Centre/Panel/Margin/Column/Footer


func _ready() -> void:
	MenuStyleScript.apply_panel($Centre/Panel as PanelContainer)
	visible = false


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
	_title.text = title_text()
	MenuStyleScript.style_label(_title, MenuStyleScript.TITLE_SIZE, MenuStyleScript.COLOR_TITLE)
	_sender.text = sender_text()
	MenuStyleScript.style_label(_sender, MenuStyleScript.ROW_SIZE, MenuStyleScript.COLOR_DIM)
	_footer.text = MenuStyleScript.footer([[&"ui_accept", "close"]])
	MenuStyleScript.style_label(_footer, MenuStyleScript.FOOTER_SIZE, MenuStyleScript.COLOR_DIM)
	for child in _rows.get_children():
		child.queue_free()
	for line in drawn_lines():
		var label := Label.new()
		# A BLANK LINE IS A BLANK LINE. Letters use them to break the body into paragraphs,
		# and a Label with an empty string collapses to nothing, which would close the gaps
		# the letter was written with. One space keeps the row at its font's height.
		label.text = line if not line.is_empty() else " "
		MenuStyleScript.style_label(label, MenuStyleScript.ROW_SIZE, MenuStyleScript.COLOR_NAME)
		_rows.add_child(label)


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
