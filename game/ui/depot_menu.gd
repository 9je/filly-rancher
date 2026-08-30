class_name DepotMenu
extends CanvasLayer
## THE COMPANY'S COUNTER: deliver a pony, pay against the balance, read the statement.
##
## THE MENU DRAWS AND EMITS; ranch.gd TRANSACTS AND PAYS. This file never touches Ledger,
## Economy, GameState or a Pen. It is handed four Callables (what is in the pens, how many
## bits she has, what the statement says, and whether it may open at all) and it hands back
## two signals. That is the same split game/ui/market_menu.gd is built on, and it is what
## lets the whole of this be tested in milliseconds against four lambdas.
##
## Three tabs rather than three menus, because they are three questions about one account
## and the player is standing at one counter.

enum Tab { DELIVER, PAY, STATEMENT }

const TAB_NAMES: Array[String] = ["Deliver", "Pay", "Statement"]
const TITLE := "Depot"
const EMPTY_TEXT := "No ponies in your pens right now."
const FOOTER := "  up down  choose      left right  tab      Enter / A  confirm      Esc / B  leave"

## The amounts the Pay tab offers, before they are cut down to what she can afford and to
## what the ledger will accept.
const PAY_STEPS: Array[int] = [100, 500, 2000, 10000]

const COLOR_TITLE := Color(1.0, 0.96, 0.86, 1.0)
const COLOR_NAME := Color(1.0, 1.0, 1.0, 0.94)
const COLOR_DIM := Color(1.0, 1.0, 1.0, 0.58)
const COLOR_VALUE := Color(1.00, 0.80, 0.25, 1.0)

signal opened()
signal closed()
signal deliver_requested(uid: StringName)
signal pay_requested(bits: int)

## Injected by ranch.gd. Every one of them is a question this menu is not allowed to answer
## for itself.
var can_open := Callable()
var rows_provider := Callable()
var bits_provider := Callable()
var statement_provider := Callable()

var _tab: int = Tab.DELIVER
var _selected := 0
var _open := false

@onready var _title: Label = $Centre/Panel/Margin/Column/Title
@onready var _tabs: Label = $Centre/Panel/Margin/Column/Tabs
@onready var _rows: VBoxContainer = $Centre/Panel/Margin/Column/Rows
@onready var _footer: Label = $Centre/Panel/Margin/Column/Footer


func _ready() -> void:
	visible = false
	_title.text = TITLE
	_footer.text = FOOTER


func open() -> bool:
	if _open:
		return false
	if can_open.is_valid() and not can_open.call():
		return false
	_open = true
	_tab = Tab.DELIVER
	_selected = 0
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


func tab() -> int:
	return _tab


func set_tab(value: int) -> void:
	_tab = clampi(value, Tab.DELIVER, Tab.STATEMENT)
	_selected = 0
	refresh()


func switch_tab(step: int) -> void:
	set_tab(posmod(_tab + step, Tab.STATEMENT + 1))


func selected_index() -> int:
	return _selected


func move_selection(step: int) -> void:
	var n: int = _row_count()
	if n <= 0:
		_selected = 0
		return
	_selected = posmod(_selected + step, n)
	refresh()


## The pens, as the Deliver tab shows them: stock first, then named, each with her credit.
## Sorted HERE rather than by the provider, so the tab's own promise ("stock first, then
## named, with their credit") is a property of this file and is tested against it.
func deliver_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if not rows_provider.is_valid():
		return rows
	for entry in rows_provider.call():
		rows.append(entry as Dictionary)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a["stock"]) != bool(b["stock"]):
			return bool(a["stock"])
		return int(a["credit"]) < int(b["credit"]))
	return rows


## The amounts the Pay tab offers: the steps above, cut to what is in the wallet, plus an
## "everything you have" row when that is more than the largest step. Never an amount she
## cannot cover, because a menu row that always refuses is a menu row that lies.
func pay_amounts() -> Array[int]:
	var bits: int = int(bits_provider.call()) if bits_provider.is_valid() else 0
	var out: Array[int] = []
	for step in PAY_STEPS:
		if step <= bits:
			out.append(step)
	if bits > 0 and (out.is_empty() or out[out.size() - 1] < bits):
		out.append(bits)
	return out


func confirm() -> bool:
	match _tab:
		Tab.DELIVER:
			var rows: Array[Dictionary] = deliver_rows()
			if _selected < 0 or _selected >= rows.size():
				return false
			deliver_requested.emit(StringName(rows[_selected]["uid"]))
			return true
		Tab.PAY:
			var amounts: Array[int] = pay_amounts()
			if _selected < 0 or _selected >= amounts.size():
				return false
			pay_requested.emit(amounts[_selected])
			return true
	return false


## Every line this menu is currently drawing, in order. For the tests, which otherwise have
## no way to ask whether a string carries a dash without walking the Label nodes.
func drawn_lines() -> Array[String]:
	var lines: Array[String] = []
	match _tab:
		Tab.DELIVER:
			var rows: Array[Dictionary] = deliver_rows()
			if rows.is_empty():
				lines.append(EMPTY_TEXT)
			for row in rows:
				lines.append("%s   %d bits" % [String(row["name"]), int(row["credit"])])
		Tab.PAY:
			var amounts: Array[int] = pay_amounts()
			if amounts.is_empty():
				lines.append("You have no bits to pay with today.")
			for amount in amounts:
				lines.append("Pay %d bits" % amount)
		Tab.STATEMENT:
			if statement_provider.is_valid():
				for line in statement_provider.call():
					lines.append(String(line))
	return lines


func refresh() -> void:
	if not is_node_ready():
		return
	_tabs.text = "   ".join(TAB_NAMES.map(func(t: String) -> String:
		return "[%s]" % t if TAB_NAMES.find(t) == _tab else " %s " % t))
	for child in _rows.get_children():
		child.queue_free()
	var lines: Array[String] = drawn_lines()
	for i in lines.size():
		var label := Label.new()
		label.text = ("> " if i == _selected and _tab != Tab.STATEMENT else "  ") + lines[i]
		label.add_theme_color_override("font_color",
			COLOR_VALUE if i == _selected and _tab != Tab.STATEMENT else COLOR_NAME)
		_rows.add_child(label)


func _row_count() -> int:
	match _tab:
		Tab.DELIVER:
			return deliver_rows().size()
		Tab.PAY:
			return pay_amounts().size()
	return 0


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
