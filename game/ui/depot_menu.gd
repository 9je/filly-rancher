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
##
## TILES (overnight bot review, 2026-10-26), the casino lobby's look through
## game/ui/tile_style.gd: each pony is her race's icon on a disc of her coat, her name and
## what the Company pays for her; each payment is a coin. Two columns of ponies in a scroll
## area that never grows past SCROLL_MAX (four full pens no longer run off the screen). The
## statement stays plain lines. drawn_lines() is still the text of every row.

const MenuStyleScript := preload("res://ui/menu_style.gd")
const MouseRowsScript := preload("res://ui/mouse_rows.gd")
const TileStyleScript := preload("res://ui/tile_style.gd")
const ShopIconScript := preload("res://ui/shop_icon.gd")
const CatchIconScript := preload("res://ui/catch_icon.gd")
const PaintScript := preload("res://ui/casino_paint.gd")

const SCROLL_MAX := 600.0
const PONY_TILE := Vector2(546.0, 76.0)
const WIDE_TILE := Vector2(1104.0, 64.0)
const ICON_SIZE := 44.0

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

## Where the pointer is resting, or -1. Not the cursor: see game/ui/table_menu.gd's own
## comment on the same pair of fields.
var _hovered := -1
var _close: Button = null

## The named pony this menu has asked about and not yet been answered on, or &"" when it is
## not asking. While it is set the Deliver tab draws two rows (yes, no) and nothing else,
## and _row_count() agrees with that, so the cursor cannot wander off the question.
var _confirming: StringName = &""
var _confirming_name := ""

@onready var _title: Label = $Centre/Panel/Margin/Column/Title
@onready var _tabs: HBoxContainer = $Centre/Panel/Margin/Column/Tabs
@onready var _scroll: ScrollContainer = $Centre/Panel/Margin/Column/Scroll
@onready var _rows: GridContainer = $Centre/Panel/Margin/Column/Scroll/Rows
@onready var _footer: Label = $Centre/Panel/Margin/Column/Footer


func _ready() -> void:
	MenuStyleScript.apply_panel($Centre/Panel as PanelContainer)
	visible = false
	_title.text = TITLE
	var dim := get_node_or_null(^"Dim") as Control
	if dim != null:
		dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_close = MouseRowsScript.close_button(MouseRowsScript.CLOSE_TEXT,
		func(_index: int) -> void: close())
	$Centre/Panel/Margin/Column.add_child(_close)


func open() -> bool:
	if _open:
		return false
	if can_open.is_valid() and not can_open.call():
		return false
	_open = true
	_tab = Tab.DELIVER
	_selected = 0
	_hovered = -1
	_cancel_confirm()
	visible = true
	refresh()
	opened.emit()
	MenuStyleScript.tick_open()
	MenuStyleScript.pop_in(get_node_or_null(^"Centre/Panel") as Control)
	return true


func close() -> void:
	if not _open:
		return
	_open = false
	_hovered = -1
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


## I5: the mouse's own door into a tab, beside switch_tab()'s keyboard one. See
## casino_menu.gd's own point_at_tab()/take_tab() for why this skips straight to set_tab().
func point_at_tab(_index: int) -> void:
	pass


func take_tab(index: int) -> void:
	if index == _tab:
		return
	set_tab(index)
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
var _confirming_credit := 0
var _confirming_credit_kept := 0


## Money moving is a moment (FS6.2): her credit pops off the tile she was delivered from.
func _pop_credit(credit: int) -> void:
	var host := get_node_or_null(^"Centre/Panel") as Control
	if host == null or credit <= 0:
		return
	var at := host.size * 0.5
	if _selected >= 0 and _selected < _rows.get_child_count():
		var tile := _rows.get_child(_selected) as Control
		if tile != null:
			at = tile.global_position - host.global_position + tile.size * 0.5
	MenuStyleScript.payout_pop(host, at, credit)


func confirm() -> bool:
	match _tab:
		Tab.DELIVER:
			if is_confirming():
				var uid: StringName = _confirming
				var yes: bool = _selected == 0
				_confirming_credit_kept = _confirming_credit
				_cancel_confirm()
				_selected = 0
				refresh()
				if yes:
					_pop_credit(_confirming_credit_kept)
					deliver_requested.emit(uid)
				return true
			var rows: Array[Dictionary] = deliver_rows()
			if _selected < 0 or _selected >= rows.size():
				return false
			var row: Dictionary = rows[_selected]
			if not bool(row.get("stock", false)):
				_confirming_credit = int(row.get("credit", 0))
				_confirming = StringName(row["uid"])
				_confirming_name = String(row.get("name", ""))
				# On "no", for the reason CONFIRM_NO's comment gives.
				_selected = 1
				refresh()
				return true
			_pop_credit(int(row.get("credit", 0)))
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
	MouseRowsScript.tab_strip(_tabs, TAB_NAMES, _tab, point_at_tab, take_tab)
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	MenuStyleScript.apply_title(_title)
	var lines: Array[String] = drawn_lines()
	var ponies: Array[Dictionary] = []
	if _tab == Tab.DELIVER and not is_confirming():
		ponies = deliver_rows()
	_rows.columns = 2 if not ponies.is_empty() else 1
	for i in lines.size():
		var picked: bool = i == _selected and _tab != Tab.STATEMENT
		var row: int = i if i < count else -1
		if row < 0:
			# The statement and the empty notes: words, not choices.
			var note := Label.new()
			note.text = lines[i]
			note.mouse_filter = Control.MOUSE_FILTER_IGNORE
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			note.custom_minimum_size = Vector2(WIDE_TILE.x, 0.0)
			MenuStyleScript.style_label(note, 21, MenuStyleScript.COLOR_NAME)
			_rows.add_child(note)
			continue
		var holder := MouseRowsScript.row(row, picked, row == _hovered, point_at_row, take_row)
		TileStyleScript.dress(holder, picked, row == _hovered)
		if not ponies.is_empty():
			_pony_tile(holder, ponies[row])
		else:
			_word_tile(holder, lines[i], _tab == Tab.PAY)
		_rows.add_child(holder)
	_fit_scroll.call_deferred()


func _fit_scroll() -> void:
	if _scroll == null or not _open:
		return
	_scroll.custom_minimum_size.y = minf(_rows.get_combined_minimum_size().y, SCROLL_MAX)
	if _selected >= 0 and _selected < _rows.get_child_count():
		_scroll.ensure_control_visible(_rows.get_child(_selected) as Control)


## A pony: her race on a disc of her coat, her name, and the Company's price for her.
func _pony_tile(holder: PanelContainer, pony: Dictionary) -> void:
	holder.custom_minimum_size = PONY_TILE
	var body := GridContainer.new()
	body.columns = 3
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override(&"h_separation", 14)
	holder.add_child(body)
	var coat: Color = pony.get("coat_color", PaintScript.CARD_FACE)
	var plate := TileStyleScript.disc(ICON_SIZE, coat)
	body.add_child(plate)
	var icon: Control = CatchIconScript.new()
	icon.kind = StringName(pony.get("race", &"earth"))
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(icon)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(column)
	var who := Label.new()
	who.text = _row_name(pony)
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	who.clip_text = true
	who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	MenuStyleScript.style_label(who, 22, MenuStyleScript.COLOR_TITLE)
	who.add_theme_font_override(&"font", MenuStyleScript.title_font())
	column.add_child(who)
	var sub := Label.new()
	sub.text = "from the crowd" if bool(pony.get("stock", true)) \
		else "one of a kind: she asks before she goes"
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	MenuStyleScript.style_label(sub, 16, MenuStyleScript.COLOR_DIM)
	column.add_child(sub)
	var price := Label.new()
	price.text = "%d bits" % int(pony.get("credit", 0))
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price.add_theme_font_override(&"font", MenuStyleScript.numeral_font())
	MenuStyleScript.style_label(price, 22, MenuStyleScript.COLOR_VALUE)
	body.add_child(price)


## A payment (a coin and its amount) or one of the two answers to a named pony's confirm.
func _word_tile(holder: PanelContainer, text: String, coin: bool) -> void:
	holder.custom_minimum_size = WIDE_TILE
	var body := HBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override(&"separation", 14)
	holder.add_child(body)
	if coin:
		var plate := TileStyleScript.disc(ICON_SIZE * 0.8)
		var icon: Control = ShopIconScript.new()
		icon.kind = &"sell_all"
		icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE) * 0.8
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.add_child(icon)
		body.add_child(plate)
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	MenuStyleScript.style_label(label, 22, MenuStyleScript.COLOR_TITLE)
	body.add_child(label)


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


# --- the pointer ----------------------------------------------------------------------------


func hovered_index() -> int:
	return _hovered


func close_button_node() -> Button:
	return _close


## ONE CURSOR, TWO WAYS TO MOVE IT. Absolute where move_selection() is relative, and it makes
## the same sound, because both are the player choosing a row.
func point_at_row(index: int) -> void:
	if index < 0 or index >= _row_count():
		return
	if index == _selected and index == _hovered:
		return
	_hovered = index
	if index != _selected:
		_selected = index
		MenuStyleScript.tick_move()
	refresh()


func take_row(index: int) -> void:
	point_at_row(index)
	if _selected == index:
		confirm()
