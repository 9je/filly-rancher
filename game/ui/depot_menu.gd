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

const MenuStyleScript := preload("res://ui/menu_style.gd")

enum Tab { DELIVER, PAY, STATEMENT }

const TAB_NAMES: Array[String] = ["Deliver", "Pay", "Statement"]
const TITLE := "Depot"
const EMPTY_TEXT := "No ponies in your pens right now."

## The Pay tab with nothing on it. Not "you have no bits": the list is cut to what the
## WALLET holds and to what the LEDGER will accept (pay_amounts), and a player sitting on a
## pile of bits at the principal floor would read that as a bug in her own wallet.
const EMPTY_PAY_TEXT := "Nothing to settle here today. Bits settle the service charges."

## THE SECOND PRESS A NAMED DELIVERY COSTS. A member of the crowd is 300 bits and there are
## dozens of her; a named pony is up to 4,000 bits and there is exactly one, and she is gone
## the moment the counter takes her. So the crowd stays one press and a named pony asks
## first, in as many words, with the cursor already sitting on "no".
##
## THE CURSOR STARTS ON THE REFUSAL deliberately: the mis-press this step exists to catch is
## a second Enter arriving on the heels of the first, and a "yes" under the cursor would
## catch precisely nothing.
const CONFIRM_YES := "Yes, hand %s to the Company"
const CONFIRM_NO := "No, she stays here"

## The amounts the Pay tab offers, before they are cut down to what she can afford and to
## what the ledger will accept.
const PAY_STEPS: Array[int] = [100, 500, 2000, 10000]

signal opened()
signal closed()
signal deliver_requested(uid: StringName)
signal pay_requested(bits: int)

## Injected by ranch.gd. Every one of them is a question this menu is not allowed to answer
## for itself.
var can_open := Callable()
var rows_provider := Callable()
var bits_provider := Callable()

## What the ledger will actually accept against the balance right now. Injected like the
## rest; a menu with no provider for it offers what the wallet holds and lets the ledger
## trim, which is what this menu did before the provider existed.
var payable_provider := Callable()
var statement_provider := Callable()

var _tab: int = Tab.DELIVER
var _selected := 0
var _open := false

## The named pony this menu has asked about and not yet been answered on, or &"" when it is
## not asking. While it is set the Deliver tab draws two rows (yes, no) and nothing else,
## and _row_count() agrees with that, so the cursor cannot wander off the question.
var _confirming: StringName = &""
var _confirming_name := ""

@onready var _title: Label = $Centre/Panel/Margin/Column/Title
@onready var _tabs: Label = $Centre/Panel/Margin/Column/Tabs
@onready var _rows: VBoxContainer = $Centre/Panel/Margin/Column/Rows
@onready var _footer: Label = $Centre/Panel/Margin/Column/Footer


func _ready() -> void:
	MenuStyleScript.apply_panel($Centre/Panel as PanelContainer)
	visible = false
	_title.text = TITLE


func open() -> bool:
	if _open:
		return false
	if can_open.is_valid() and not can_open.call():
		return false
	_open = true
	_tab = Tab.DELIVER
	_selected = 0
	_cancel_confirm()
	visible = true
	refresh()
	opened.emit()
	MenuStyleScript.tick_open()
	return true


func close() -> void:
	if not _open:
		return
	_open = false
	_cancel_confirm()
	visible = false
	closed.emit()
	MenuStyleScript.tick_back()


func is_open() -> bool:
	return _open


func tab() -> int:
	return _tab


func set_tab(value: int) -> void:
	_tab = clampi(value, Tab.DELIVER, Tab.STATEMENT)
	_selected = 0
	_cancel_confirm()
	refresh()


func switch_tab(step: int) -> void:
	set_tab(posmod(_tab + step, Tab.STATEMENT + 1))
	MenuStyleScript.tick_page()


func selected_index() -> int:
	return _selected


func move_selection(step: int) -> void:
	var n: int = _row_count()
	if n <= 0:
		_selected = 0
		return
	_selected = posmod(_selected + step, n)
	refresh()
	MenuStyleScript.tick_move()


## The pens, as the Deliver tab shows them: stock first, then named, each with her credit.
## Sorted HERE rather than by the provider, so the tab's own promise ("stock first, then
## named, with their credit") is a property of this file and is tested against it.
##
## THE UID IS THE LAST TIEBREAK, AND IT IS NOT DECORATION. Array.sort_custom() is NOT a
## stable sort, so a pen holding six stock ponies at one credit each had six rows in
## whatever order the sort happened to leave them, and the SAME six could come back in a
## different order from the next refresh(). The cursor addresses a row by INDEX, so that is
## a menu where the pony under the cursor can change identity between looking at her and
## pressing the button. Comparing uids (unique, per individual, never reused) makes the
## order total, so the sort has exactly one answer and refresh() cannot shuffle it.
func deliver_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if not rows_provider.is_valid():
		return rows
	for entry in rows_provider.call():
		rows.append(entry as Dictionary)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a["stock"]) != bool(b["stock"]):
			return bool(a["stock"])
		if int(a["credit"]) != int(b["credit"]):
			return int(a["credit"]) < int(b["credit"])
		return String(a["uid"]) < String(b["uid"]))
	return rows


## Is the menu waiting on a yes or no about a named pony? See CONFIRM_YES.
func is_confirming() -> bool:
	return _confirming != &""


## Drop the question, if there is one. Called by anything that moves the player off it: the
## tab keys, closing, opening, and the answer itself.
func _cancel_confirm() -> void:
	_confirming = &""
	_confirming_name = ""


## The amounts the Pay tab offers: the steps above, cut to what is in the wallet AND to what
## the ledger will accept, plus an "everything that will go" row when that is more than the
## largest step. Never an amount she cannot cover and never one that would be trimmed on the
## way through, because a menu row that always refuses is a menu row that lies, and
## Ledger.pay() caps every payment at payable() (bits settle the service charges, not the
## principal), so offering 10,000 to a player the ledger will only take 200 from was exactly
## that lie.
func pay_amounts() -> Array[int]:
	var bits: int = int(bits_provider.call()) if bits_provider.is_valid() else 0
	var cap: int = bits
	if payable_provider.is_valid():
		cap = mini(bits, maxi(0, int(payable_provider.call())))
	var out: Array[int] = []
	for step in PAY_STEPS:
		if step <= cap:
			out.append(step)
	if cap > 0 and (out.is_empty() or out[out.size() - 1] < cap):
		out.append(cap)
	return out


## The button. On the Deliver tab a member of the crowd goes on one press; a NAMED pony
## turns this into the question CONFIRM_YES asks, and the next press answers it. Returns
## whether the press did anything at all.
func confirm() -> bool:
	match _tab:
		Tab.DELIVER:
			if is_confirming():
				var uid: StringName = _confirming
				var yes: bool = _selected == 0
				_cancel_confirm()
				_selected = 0
				refresh()
				if yes:
					deliver_requested.emit(uid)
				return true
			var rows: Array[Dictionary] = deliver_rows()
			if _selected < 0 or _selected >= rows.size():
				return false
			var row: Dictionary = rows[_selected]
			if not bool(row.get("stock", false)):
				_confirming = StringName(row["uid"])
				_confirming_name = String(row.get("name", ""))
				# On "no", for the reason CONFIRM_NO's comment gives.
				_selected = 1
				refresh()
				return true
			deliver_requested.emit(StringName(row["uid"]))
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
			if is_confirming():
				lines.append(CONFIRM_YES % _confirming_name)
				lines.append(CONFIRM_NO)
				return lines
			var rows: Array[Dictionary] = deliver_rows()
			if rows.is_empty():
				lines.append(EMPTY_TEXT)
			for row in rows:
				lines.append("%s   %d bits" % [_row_name(row), int(row["credit"])])
		Tab.PAY:
			var amounts: Array[int] = pay_amounts()
			if amounts.is_empty():
				lines.append(EMPTY_PAY_TEXT)
			for amount in amounts:
				lines.append("Pay %d bits" % amount)
		Tab.STATEMENT:
			if statement_provider.is_valid():
				for line in statement_provider.call():
					lines.append(String(line))
	return lines


## HOW ONE ROW READS. A named pony is her own name. A member of the crowd shares one
## display_name with every other member of the crowd ("Pony"), so the coat word the rows
## provider hands over goes in front of it and a pen of six lists "Butter Pony", "Sky Pony",
## "Rose Pony" instead of six identical lines. A provider that supplies no coat (this menu's
## own tests, a future caller) falls back to the bare name, which is what it drew before.
func _row_name(row: Dictionary) -> String:
	var coat: String = String(row.get("coat", ""))
	var who: String = String(row["name"])
	return "%s %s" % [coat, who] if not coat.is_empty() else who


func refresh() -> void:
	if not is_node_ready():
		return
	# CLAMPED HERE, at the one place every redraw goes through. The row list is rebuilt from
	# the pens on every refresh and it SHRINKS: delivering the last pony in a pen, or a pony
	# escaping while the menu is open, leaves _selected pointing past the end, and the next
	# confirm() would read a row that is not there. Clamping at the draw keeps the cursor on
	# the row the player can actually see.
	_footer.text = MenuStyleScript.footer_tabs_and_rows("confirm", "leave")
	MenuStyleScript.style_label(_footer, MenuStyleScript.FOOTER_SIZE, MenuStyleScript.COLOR_DIM)
	var count: int = _row_count()
	_selected = clampi(_selected, 0, maxi(0, count - 1)) if count > 0 else 0
	_tabs.text = MenuStyleScript.tab_strip(TAB_NAMES, _tab)
	for child in _rows.get_children():
		child.queue_free()
	MenuStyleScript.apply_title(_title)
	var lines: Array[String] = drawn_lines()
	for i in lines.size():
		var picked: bool = i == _selected and _tab != Tab.STATEMENT
		var label := Label.new()
		label.text = MenuStyleScript.caret(picked) + lines[i]
		label.add_theme_color_override("font_color",
			MenuStyleScript.COLOR_VALUE if picked else MenuStyleScript.COLOR_NAME)
		var holder: PanelContainer = MenuStyleScript.row_panel(picked)
		holder.add_child(label)
		_rows.add_child(holder)


func _row_count() -> int:
	match _tab:
		Tab.DELIVER:
			return 2 if is_confirming() else deliver_rows().size()
		Tab.PAY:
			return pay_amounts().size()
	return 0


func _unhandled_input(event: InputEvent) -> void:
	if not _open or not event.is_pressed():
		return
	if event.is_action(&"ui_cancel"):
		# Escape answers the question before it closes the menu: a player who opened a
		# confirm by accident must be able to back out of it without leaving the counter.
		if _tab == Tab.DELIVER and is_confirming():
			_cancel_confirm()
			_selected = 0
			refresh()
		else:
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
