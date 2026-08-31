class_name TableMenu
extends CanvasLayer
## THE SHAPE EVERY TABLE IN THE PALACE HAS. Pick a stake you can cover, confirm, read what
## happened. The slot machine, the wheel and the blackjack table each add their own rows and
## their own signal and inherit the rest of this.
##
## THE MENU DRAWS AND EMITS; ranch.gd TRANSACTS AND PAYS. Nothing under game/ui/ may touch
## Economy, Casino or GameState, so a table is handed `chips_provider` and `can_open` and
## hands back one request signal. Same split as game/ui/depot_menu.gd.
##
## IT NEVER OFFERS A STAKE SHE CANNOT COVER. stakes() is cut to the purse, so confirming on
## an empty purse cannot even reach the signal; ranch.gd checks again anyway, because two
## checks on a bet is the right number.
##
## SHOWING A RESULT IS A PUSH, NOT A POLL. ranch.gd settles the bet and then calls
## show_result() with the lines to print, so the table never has to ask what happened and
## never has an opinion about it.
##
## Subclasses override title_text(), drawn_lines(), confirm() and row_count(). The scene tree
## every table's .tscn must have is the one game/ui/depot_menu.tscn has: Dim, and
## Centre/Panel/Margin/Column holding Title, Tabs, Rows and Footer.

## What the tables let her bet. Even numbers, always: Blackjack.payout() pays three to two
## with integer division and an odd stake would round the bonus down by half a chip.
const STAKES: Array[int] = [10, 50, 200]

const FOOTER := "  up down  choose      left right  tab      Enter / A  confirm      Esc / B  leave"
const COLOR_NAME := Color(1.0, 1.0, 1.0, 0.94)
const COLOR_VALUE := Color(1.00, 0.80, 0.25, 1.0)
const COLOR_DIM := Color(1.0, 1.0, 1.0, 0.58)

signal opened()
signal closed()

var can_open := Callable()
var chips_provider := Callable()

var _open := false
var _selected := 0
var _stake_index := 0
var _result: Array[String] = []

@onready var _title: Label = $Centre/Panel/Margin/Column/Title
@onready var _tabs: Label = $Centre/Panel/Margin/Column/Tabs
@onready var _rows: VBoxContainer = $Centre/Panel/Margin/Column/Rows
@onready var _footer: Label = $Centre/Panel/Margin/Column/Footer


func _ready() -> void:
	visible = false
	_title.text = title_text()
	_footer.text = FOOTER


func open() -> bool:
	if _open:
		return false
	if can_open.is_valid() and not can_open.call():
		return false
	_open = true
	_selected = 0
	_stake_index = 0
	_result = []
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


## The stakes she can actually cover, in order. Never empty rows, never a row that refuses.
func stakes() -> Array[int]:
	var chips: int = int(chips_provider.call()) if chips_provider.is_valid() else 0
	var out: Array[int] = []
	for stake in STAKES:
		if stake <= chips:
			out.append(stake)
	return out


func selected_stake() -> int:
	var available: Array[int] = stakes()
	if available.is_empty():
		return 0
	return available[clampi(_stake_index, 0, available.size() - 1)]


func set_stake_index(index: int) -> void:
	_stake_index = index
	refresh()


func stake_index() -> int:
	return _stake_index


func selected_index() -> int:
	return _selected


func move_selection(step: int) -> void:
	var n: int = row_count()
	if n <= 0:
		_selected = 0
		return
	_selected = posmod(_selected + step, n)
	refresh()


## Push the lines describing what just happened. Replaces whatever was there, so the panel
## always shows the last hand and never two of them.
func show_result(lines: Array[String]) -> void:
	_result = lines.duplicate()
	refresh()


func result_lines() -> Array[String]:
	return _result.duplicate()


## The stake row, drawn by every table above its own rows.
func stake_lines() -> Array[String]:
	var available: Array[int] = stakes()
	if available.is_empty():
		return ["No chips. The cage is in the lobby."]
	var out: Array[String] = []
	for i in available.size():
		out.append("[%d chips]" % available[i] if i == clampi(_stake_index, 0,
			available.size() - 1) else " %d chips " % available[i])
	return ["Stake:  " + "  ".join(out)]


func refresh() -> void:
	if not is_node_ready():
		return
	_title.text = title_text()
	_tabs.text = tabs_text()
	for child in _rows.get_children():
		child.queue_free()
	var lines: Array[String] = drawn_lines()
	var caret: int = _selected + first_row_line_index()
	for i in lines.size():
		var label := Label.new()
		var picked: bool = i == caret and row_count() > 0
		label.text = ("> " if picked else "  ") + lines[i]
		label.add_theme_color_override("font_color", COLOR_VALUE if picked else COLOR_NAME)
		_rows.add_child(label)


# --- what a table fills in ---------------------------------------------------------------

func title_text() -> String:
	return "Table"


func tabs_text() -> String:
	return ""


## Every line this menu is currently drawing, in order. For the tests, which otherwise have
## no way to ask whether a string carries a dash without walking the Label nodes.
func drawn_lines() -> Array[String]:
	return []


## How many of those lines the selection may sit on.
func row_count() -> int:
	return 0


## WHICH DRAWN LINE ROW ZERO IS. `_selected` counts SELECTABLE rows; drawn_lines() counts
## PRINTED lines, and every table in the Palace prints the last result above its rows. So
## the two agree only until the first spin, after which the caret was drawn three lines
## above the row it was actually on (two result lines plus the blank under them) and the
## player was reading a highlight that pointed at the wrong thing.
##
## A table that prints anything above its first selectable row says how much, here, and
## refresh() adds it. Zero by default, which is the answer for a table whose first printed
## line IS its first row, and for the panels that draw no cursor at all.
func first_row_line_index() -> int:
	return 0


## Act on the highlighted row. Returns whether anything was emitted.
func confirm() -> bool:
	return false


func switch_tab(_step: int) -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	if not _open or not event.is_pressed():
		return
	if event.is_action(&"ui_cancel"):
		close()
	elif event.is_action(&"ui_up"):
		move_selection(-1)
	elif event.is_action(&"ui_down"):
		move_selection(1)
	elif event.is_action(&"ui_left"):
		switch_tab(-1)
	elif event.is_action(&"ui_right"):
		switch_tab(1)
	elif event.is_action(&"ui_accept"):
		confirm()
	else:
		return
	get_viewport().set_input_as_handled()
