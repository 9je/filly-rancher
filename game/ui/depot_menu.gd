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
##
## THE PAYOUT (PS10, G7; FS6.2: "the Depot pays out per tile with a counter sound; the total
## lands on the balance"). A delivery used to pop one number off the panel's corner. Now her
## tile turns into a receipt card where it stood, her pay counts up on it and ends on a
## counter tick, a coin flies from it to the purse, and once every card in the queue has paid,
## the purse at the top (her bits, and what she still owes) rolls to the new totals in one go.
## Several quick deliveries queue and pay one by one. The menu still moves no money: the cards
## count what ranch.gd already paid, and the purse lands on what the providers say.

const MenuStyleScript := preload("res://ui/menu_style.gd")
const MouseRowsScript := preload("res://ui/mouse_rows.gd")
const TileStyleScript := preload("res://ui/tile_style.gd")
const ShopIconScript := preload("res://ui/shop_icon.gd")
const CatchIconScript := preload("res://ui/catch_icon.gd")
const PaintScript := preload("res://ui/casino_paint.gd")
const TileEntranceScript := preload("res://ui/tile_entrance.gd")
const RarityGlyphScript := preload("res://ui/rarity_glyph.gd")
const LedgerScript := preload("res://systems/ledger.gd")

const SCROLL_MAX := 600.0
const PONY_TILE := Vector2(546.0, 76.0)
const WIDE_TILE := Vector2(1104.0, 64.0)
const ICON_SIZE := 44.0

## The payout's beats, in seconds: each card counts up for PAYOUT_ROLL, holds its total for
## PAYOUT_HOLD (the next card starts as this one's coin leaves), and the purse rolls to the new
## totals over PAYOUT_LAND once the last coin is in.
const PAYOUT_ROLL := 0.55
const PAYOUT_HOLD := 0.22
const PAYOUT_LAND := 0.5
## What she owes, in the purse: a soft red, the colour every "too dear" in the menus wears.
const OWED_COLOUR := Color(1.0, 0.62, 0.58, 0.95)

enum Tab { DELIVER, PAY, STATEMENT }

const TAB_NAMES: Array[String] = ["Deliver", "Pay", "Statement"]
const TITLE := "Depot"
const EMPTY_TEXT := "No ponies in your pens right now."

## The Pay tab with nothing on it. Not "you have no bits": the list is cut to what the
## WALLET holds and to what the LEDGER will accept (pay_amounts), so a paid balance or an
## empty purse both land here, and the quota card above says which.
const EMPTY_PAY_TEXT := "Nothing to pay right now."

## THE SECOND PRESS A NAMED DELIVERY COSTS. A member of the crowd is 300 bits and there are
## dozens of her; a named pony is up to 4,000 bits and there is exactly one, and she is gone
## the moment the counter takes her. So the crowd stays one press and a named pony asks
## first, in as many words, with the cursor already sitting on "no".
##
## THE CURSOR STARTS ON THE REFUSAL deliberately: the mis-press this step exists to catch is
## a second Enter arriving on the heels of the first, and a "yes" under the cursor would
## catch precisely nothing.
const CONFIRM_YES := "Yes, hand %s to the Company"
## "%s" is her pronoun (PonyData.pronoun, item 70): "No, he stays here" for Braeburn.
const CONFIRM_NO := "No, %s stays here"

## The amounts the Pay tab offers, before they are cut down to what she can afford and to
## what the ledger will accept.
const PAY_STEPS: Array[int] = [100, 500, 2000, 10000]

signal opened()
signal closed()
signal deliver_requested(uid: StringName)
signal pay_requested(bits: int)
## A card's count reached her pay: the counter's tick (PS10, G7). One per delivered tile.
signal counter_ticked(paid: int)
## The purse took the queue's total in one go: bits into the wallet, debt off the balance.
signal balance_landed(bits_gained: int, debt_cleared: int)

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
## What she still owes the Company (Ledger.balance), for the purse. Optional: without it the
## purse shows only her bits.
var balance_provider := Callable()
## THE QUOTA CARD on the Pay tab (P8 item 4): Ledger.quota_status() for today. Optional:
## without it the card is not drawn.
var quota_provider := Callable()

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

## The tiles deal themselves in (PS10, G6; game/ui/tile_entrance.gd).
var _entrance = TileEntranceScript.new()
## Where the receipt cards and the coins live: over the panel, never laid out by it.
var _fx: Control = null
var _purse_coin: TextureRect = null
var _wallet_label: Label = null
var _owed_label: Label = null
## What the purse SHOWS, which trails what the providers say while a payout is running.
var _shown_bits := 0
var _shown_owed := 0
## The payout queue: one entry per delivered tile, {start, card, paid, credit, shown, ticked,
## flown}, timed on _pay_clock.
var _payouts: Array[Dictionary] = []
var _pay_clock := 0.0
## The purse rolling to its new totals: {from_bits, to_bits, from_owed, to_owed, t}, or empty.
var _landing := {}
## Each tile's place at the last laid-out redraw (see market_menu.gd's own _tile_rects).
var _tile_rects: Array[Rect2] = []
## The process frame the tiles were last built on. A tile built this frame already has its
## minimum size but no place yet (the grid sorts at the end of the frame), so its rect lies.
var _built_frame := -1
## The row a named pony's question is about, for her receipt card.
var _confirming_row := {}


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
	_build_purse()
	_build_quota_card()
	_fx = MenuStyleScript.effects_layer(self)


## THE PURSE, under the title: the bits coin and her bits in gold, and on the right what she
## still owes. It is where the payout lands.
func _build_purse() -> void:
	var column := $Centre/Panel/Margin/Column as VBoxContainer
	var purse := HBoxContainer.new()
	purse.name = "Purse"
	purse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	purse.add_theme_constant_override(&"separation", 10)
	column.add_child(purse)
	column.move_child(purse, _title.get_index() + 1)
	_purse_coin = MenuStyleScript.coin_icon(34.0)
	purse.add_child(_purse_coin)
	_wallet_label = Label.new()
	_wallet_label.name = "Wallet"
	_wallet_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_wallet_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	MenuStyleScript.style_label(_wallet_label, 26, MenuStyleScript.COLOR_VALUE)
	_wallet_label.add_theme_font_override(&"font", MenuStyleScript.numeral_font())
	purse.add_child(_wallet_label)
	_owed_label = Label.new()
	_owed_label.name = "Owed"
	_owed_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	MenuStyleScript.style_label(_owed_label, 22, OWED_COLOUR)
	_owed_label.add_theme_font_override(&"font", MenuStyleScript.numeral_font())
	purse.add_child(_owed_label)


func wallet_text() -> String:
	return _wallet_label.text if _wallet_label != null else ""


func owed_text() -> String:
	return _owed_label.text if _owed_label != null and _owed_label.visible else ""


## Where a coin lands: the middle of the purse's coin.
func wallet_target() -> Vector2:
	return _purse_coin.get_global_rect().get_center() if _purse_coin != null else Vector2.ZERO


func _provided_bits() -> int:
	return int(bits_provider.call()) if bits_provider.is_valid() else 0


func _provided_owed() -> int:
	return int(balance_provider.call()) if balance_provider.is_valid() else 0


func _draw_purse() -> void:
	if _wallet_label == null:
		return
	_wallet_label.text = "%d bits" % _shown_bits
	_owed_label.visible = balance_provider.is_valid()
	_owed_label.text = "%d owed" % _shown_owed


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
	_shown_bits = _provided_bits()
	_shown_owed = _provided_owed()
	visible = true
	_entrance.restart()
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
	_end_payout()
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
	_entrance.restart()
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
	_confirming_row = {}


## The amounts the Pay tab offers: the steps above, cut to what is in the wallet AND to what
## the ledger will accept, plus an "everything that will go" row when that is more than the
## largest step. Never an amount she cannot cover and never one that would be trimmed on the
## way through, because a menu row that always refuses is a menu row that lies, and
## Ledger.pay() caps every payment at payable() (the balance owed; it used to be the balance
## over a hidden floor), so offering 10,000 to a player the ledger will only take 200 from was exactly
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
				var asked: Dictionary = _confirming_row
				# Her card starts where "yes" was pressed: her own tile is not on screen while
				# the counter asks.
				var rect := _tile_rect(0)
				_cancel_confirm()
				_selected = 0
				refresh()
				if yes:
					_deliver(uid)
					_after_delivery(asked, rect)
				return true
			var rows: Array[Dictionary] = deliver_rows()
			if _selected < 0 or _selected >= rows.size():
				return false
			var row: Dictionary = rows[_selected]
			if not bool(row.get("stock", false)):
				_confirming = StringName(row["uid"])
				_confirming_name = String(row.get("name", ""))
				_confirming_row = row
				# On "no", for the reason CONFIRM_NO's comment gives.
				_selected = 1
				refresh()
				return true
			var from := _tile_rect(_selected)
			_deliver(StringName(row["uid"]))
			_after_delivery(row, from)
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
				lines.append(CONFIRM_NO % String(_confirming_row.get("she", "she")))
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
	var drawn: Array[Rect2] = []
	for child in _rows.get_children():
		var was := child as Control
		drawn.append(was.get_global_rect() if was != null and was.is_inside_tree() else Rect2())
		_rows.remove_child(child)
		child.queue_free()
	# Kept only from a laid-out grid: a grid rebuilt twice in one frame has no rects yet.
	if not drawn.is_empty() and _built_frame != Engine.get_process_frames():
		_tile_rects = drawn
	_built_frame = Engine.get_process_frames()
	_sync_purse()
	_draw_quota_card()
	MenuStyleScript.apply_title(_title)
	var lines: Array[String] = drawn_lines()
	var ponies: Array[Dictionary] = []
	if _tab == Tab.DELIVER and not is_confirming():
		ponies = deliver_rows()
	# How many of each named character the pens hold, read once per draw for _tag().
	_kind_counts = {}
	for p: Dictionary in ponies:
		var kind := String(p.get("kind", ""))
		if not bool(p.get("stock", true)) and not kind.is_empty():
			_kind_counts[kind] = int(_kind_counts.get(kind, 0)) + 1
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
	_entrance.apply(_rows.get_children())
	_fit_scroll.call_deferred()


## The tiles on screen, in row order (notes included).
func row_nodes() -> Array[Node]:
	return _rows.get_children()


func _process(delta: float) -> void:
	if not _open:
		return
	if _entrance.running(_rows.get_child_count()):
		_entrance.advance(delta, _rows.get_children())
	advance_payout(delta)


## Step the tiles' deal-in by `dt` seconds, as a frame would.
func advance_entrance(dt: float) -> void:
	_entrance.advance(dt, _rows.get_children())


## Row `index`'s tile on screen: its laid-out rect, or where it was drawn last.
func _tile_rect(index: int) -> Rect2:
	if index >= 0 and index < _rows.get_child_count():
		var tile := _rows.get_child(index) as Control
		if tile != null and tile.is_inside_tree() and _built_frame != Engine.get_process_frames():
			return tile.get_global_rect()
	if index >= 0 and index < _tile_rects.size():
		return _tile_rects[index]
	var host := get_node_or_null(^"Centre/Panel") as Control
	return host.get_global_rect() if host != null else Rect2()


# --- the payout -----------------------------------------------------------------------------

## True while deliver_requested's handler runs: ranch.gd pays and redraws inside it, and the
## purse must not land that pay before her card has counted it.
var _delivering := false


func _deliver(uid: StringName) -> void:
	_delivering = true
	deliver_requested.emit(uid)
	_delivering = false


## The purse follows the providers whenever nothing is paying out. A change it did not see
## coming (a payment on the Pay tab) rolls in the same way a payout lands.
func _sync_purse() -> void:
	if _open and not payout_busy() and not _delivering \
			and (_provided_bits() != _shown_bits or _provided_owed() != _shown_owed):
		_start_landing()
	_draw_purse()


## A delivery the counter took: queue her card. One it refused (she is racing, she has her
## mark) is still in the pens and paid nothing, so nothing rolls.
func _after_delivery(row: Dictionary, from: Rect2) -> void:
	if row.is_empty() or not _open:
		return
	for r: Dictionary in deliver_rows():
		if r["uid"] == row["uid"]:
			return
	_finish_landing()
	var start := _pay_clock
	if not _payouts.is_empty():
		start = maxf(start, float(_payouts[-1]["start"]) + PAYOUT_ROLL + PAYOUT_HOLD)
	var credit := int(row.get("credit", 0))
	var card := _receipt_card(row, from)
	card.visible = false
	_payouts.append({"start": start, "card": card, "paid": paid_for(row),
		"credit": credit, "shown": 0, "ticked": false, "flown": false})


func payout_busy() -> bool:
	return not _payouts.is_empty() or not _landing.is_empty()


func payout_count() -> int:
	return _payouts.size()


func payout_cards() -> Array[Control]:
	var out: Array[Control] = []
	for e: Dictionary in _payouts:
		out.append(e["card"] as Control)
	return out


## What card `index` shows right now, in bits (0 before it starts counting).
func payout_figure(index: int) -> int:
	return int(_payouts[index]["shown"]) if index >= 0 and index < _payouts.size() else 0


## Run the payout `dt` seconds on: every card's count, its tick, its coin, and the landing.
## Called every frame by _process(); the suite steps it directly.
func advance_payout(dt: float) -> void:
	if not payout_busy():
		return
	_pay_clock += dt
	var done := true
	for e: Dictionary in _payouts:
		var t: float = _pay_clock - float(e["start"])
		if t < 0.0:
			done = false
			continue
		var card := e["card"] as Control
		if not bool(e["flown"]):
			_count_up(e, card, t)
		if t >= PAYOUT_ROLL and not bool(e["ticked"]):
			e["ticked"] = true
			counter_ticked.emit(int(e["paid"]))
			MenuStyleScript.tick_move()
		if t >= PAYOUT_ROLL + PAYOUT_HOLD and not bool(e["flown"]):
			e["flown"] = true
			MenuStyleScript.fly_coin(_fx, card.get_global_rect().get_center(), wallet_target())
			var tw := card.create_tween().set_parallel(true)
			tw.tween_property(card, ^"scale", Vector2.ONE * 0.7, 0.22).set_ease(Tween.EASE_IN)
			tw.tween_property(card, ^"modulate:a", 0.0, 0.22)
		if t < PAYOUT_ROLL + PAYOUT_HOLD + MenuStyleScript.COIN_SECONDS:
			done = false
	if done and not _payouts.is_empty():
		for e: Dictionary in _payouts:
			(e["card"] as Node).queue_free()
		_payouts.clear()
		_start_landing()
	if not _landing.is_empty():
		_landing["t"] = float(_landing["t"]) + dt
		var g := clampf(float(_landing["t"]) / PAYOUT_LAND, 0.0, 1.0)
		var eased := 1.0 - pow(1.0 - g, 2.0)
		_shown_bits = int(round(lerpf(float(_landing["from_bits"]), float(_landing["to_bits"]), eased)))
		_shown_owed = int(round(lerpf(float(_landing["from_owed"]), float(_landing["to_owed"]), eased)))
		_draw_purse()
		if g >= 1.0:
			_finish_landing()


## Card `e`, `t` seconds into its count: the figures ease up to her pay and her credit, and
## the card comes in with a little pop and swells for a beat when the count lands.
func _count_up(e: Dictionary, card: Control, t: float) -> void:
	card.visible = true
	var f := clampf(t / PAYOUT_ROLL, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - f, 3.0)
	e["shown"] = int(round(float(e["paid"]) * eased))
	(card.find_child("Figure", true, false) as Label).text = "+%d bits" % int(e["shown"])
	(card.find_child("Debt", true, false) as Label).text = \
		"-%d debt" % int(round(float(e["credit"]) * eased))
	var s := lerpf(0.9, 1.0, clampf(t / 0.12, 0.0, 1.0))
	if f >= 1.0:
		s += 0.07 * maxf(0.0, 1.0 - (t - PAYOUT_ROLL) / PAYOUT_HOLD)
	card.scale = Vector2.ONE * s
	card.modulate.a = clampf(t / 0.08, 0.0, 1.0)


## The queue has paid in: the purse rolls from what it shows to what the providers say, once.
func _start_landing() -> void:
	var to_bits := _provided_bits()
	var to_owed := _provided_owed()
	_landing = {"from_bits": _shown_bits, "to_bits": to_bits, "from_owed": _shown_owed,
		"to_owed": to_owed, "t": 0.0}
	balance_landed.emit(to_bits - _shown_bits, _shown_owed - to_owed)
	MenuStyleScript.tick_confirm()
	if _fx != null and to_bits != _shown_bits:
		MenuStyleScript.payout_pop(_fx, wallet_target() + Vector2(230.0, 0.0), to_bits - _shown_bits)
	if _purse_coin != null and _purse_coin.is_inside_tree():
		_purse_coin.scale = Vector2.ONE * 1.35
		_purse_coin.create_tween().tween_property(_purse_coin, ^"scale", Vector2.ONE, 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _finish_landing() -> void:
	if _landing.is_empty():
		return
	_shown_bits = int(_landing["to_bits"])
	_shown_owed = int(_landing["to_owed"])
	_landing = {}
	_draw_purse()


## Closing mid payout: the cards go, and the purse is simply right.
func _end_payout() -> void:
	for e: Dictionary in _payouts:
		var card := e["card"] as Node
		if is_instance_valid(card):
			card.queue_free()
	_payouts.clear()
	_landing = {}
	_shown_bits = _provided_bits()
	_shown_owed = _provided_owed()
	_draw_purse()


## HER RECEIPT: her tile again, lifted off the grid where it stood, with the count on it.
func _receipt_card(row: Dictionary, from: Rect2) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "Receipt"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := TileStyleScript.box(true, true)
	box.bg_color = PaintScript.PLUM.lightened(0.06)
	card.add_theme_stylebox_override(&"panel", box)
	_fx.add_child(card)
	var body := HBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override(&"separation", 12)
	card.add_child(body)
	var plate := TileStyleScript.disc(ICON_SIZE, row.get("coat_color", PaintScript.CARD_FACE))
	body.add_child(plate)
	var icon: Control = CatchIconScript.new()
	icon.kind = StringName(row.get("race", &"earth"))
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(icon)
	body.add_child(_rarity_glyph(row))
	var who := Label.new()
	who.text = _row_name(row)
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	who.clip_text = true
	who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	MenuStyleScript.style_label(who, 22, MenuStyleScript.COLOR_TITLE)
	who.add_theme_font_override(&"font", MenuStyleScript.title_font())
	body.add_child(who)
	var sums := VBoxContainer.new()
	sums.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sums.alignment = BoxContainer.ALIGNMENT_CENTER
	sums.add_theme_constant_override(&"separation", -4)
	body.add_child(sums)
	for line: Array in [["Figure", "+0 bits", 30, MenuStyleScript.COLOR_VALUE],
			["Debt", "-0 debt", 17, MenuStyleScript.COLOR_NAME]]:
		var l := Label.new()
		l.name = String(line[0])
		l.text = String(line[1])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.add_theme_font_override(&"font", MenuStyleScript.numeral_font())
		MenuStyleScript.style_label(l, int(line[2]), line[3])
		sums.add_child(l)
	card.size = PONY_TILE
	card.position = from.get_center() - PONY_TILE * 0.5
	card.pivot_offset = PONY_TILE * 0.5
	return card


## Her rarity as a shape as well as a colour (PS10, G8; FS8.3: "not colour alone"): the gem's
## colour from the Market's Sell tab, in the shape RarityGlyph gives each rarity.
func _rarity_glyph(row: Dictionary) -> Control:
	var glyph := RarityGlyphScript.new()
	var rarity := int(row.get("rarity", 0))
	glyph.rarity = rarity
	glyph.colour = ShopIconScript.GEM_COLOURS[clampi(rarity, 0, ShopIconScript.GEM_COLOURS.size() - 1)]
	glyph.custom_minimum_size = Vector2(22, 22)
	return glyph


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
	# Her name, with her rarity's shape in front of it (PS10, G8).
	var name_line := HBoxContainer.new()
	name_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_line.add_theme_constant_override(&"separation", 8)
	column.add_child(name_line)
	name_line.add_child(_rarity_glyph(pony))
	var who := Label.new()
	who.text = _row_name(pony)
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.clip_text = true
	who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	MenuStyleScript.style_label(who, 22, MenuStyleScript.COLOR_TITLE)
	who.add_theme_font_override(&"font", MenuStyleScript.title_font())
	name_line.add_child(who)
	var sub := Label.new()
	sub.text = _tag(pony)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	MenuStyleScript.style_label(sub, 16, MenuStyleScript.COLOR_DIM)
	column.add_child(sub)
	var price := Label.new()
	# What she is worth, both ways (PT9): off the balance, and the handler's share to her. A
	# blank Drifter is only the intake fee, and says so.
	price.text = price_text(pony)
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price.add_theme_font_override(&"font", MenuStyleScript.numeral_font())
	MenuStyleScript.style_label(price, 22, MenuStyleScript.COLOR_VALUE)
	body.add_child(price)


## THE LINE UNDER HER NAME (playtest 2026-11-05 item 63: 'everyone tagged "one of a kind"',
## two Sweetie Belles among them). A Drifter is from the crowd; a named pony is one of a kind
## only when no other pony in the pens is the same character. A save from before the
## spawner stopped drawing owned ponies can still hold twins, and nobody owned is ever
## deleted, so a twin says so rather than claiming to be unique.
var _kind_counts := {}


## WHAT SHE IS TO THE COMPANY (playtest 2026-11-08 item 9): a blank Drifter (a token fee,
## counts for nothing), a Bloomed Drifter (counts toward the quota), or a named pony, in
## her own pronoun (item 70).
func _tag(pony: Dictionary) -> String:
	if bool(pony.get("stock", true)):
		if bool(pony.get("blank", false)):
			return "Drifter, blank: intake fee only, no quota"
		return "Drifter, Bloomed: counts toward the quota"
	var she := String(pony.get("she", "she"))
	var her := "him" if she == "he" else "her"
	var same := int(_kind_counts.get(String(pony.get("kind", "")), 1))
	if same <= 1:
		return "one of a kind: %s asks before %s goes" % [she, she]
	return "there are two of %s here" % her if same == 2 else "there are %d of %s here" % [same, her]


## Her price on her tile: "-300 debt / +75 bits", or a blank Drifter's "+30 bits / no credit".
static func price_text(pony: Dictionary) -> String:
	if bool(pony.get("blank", false)):
		return "+%d bits\nno credit" % LedgerScript.BLANK_INTAKE_FEE
	var credit := int(pony.get("credit", 0))
	return "-%d debt\n+%d bits" % [credit, LedgerScript.handler_share(credit)]


## What her receipt card counts up to: the intake fee for a blank, the share otherwise.
static func paid_for(row: Dictionary) -> int:
	if bool(row.get("blank", false)):
		return LedgerScript.BLANK_INTAKE_FEE
	return LedgerScript.handler_share(int(row.get("credit", 0)))


# --- the quota card (P8 item 4) -------------------------------------------------------------

## THE QUOTA, OUT LOUD. The Pay tab used to say "Nothing to settle" over a hidden 5,000 floor.
## Now it opens on a card: the quota as a bar (coloured ponies delivered of the quota) and the
## collection day it is due, and one line on how the account closes.
var _quota_card: PanelContainer = null
var _quota_bar: ProgressBar = null
var _quota_words: Label = null
var _quota_rule: Label = null


func _build_quota_card() -> void:
	var column := $Centre/Panel/Margin/Column as VBoxContainer
	_quota_card = PanelContainer.new()
	_quota_card.name = "QuotaCard"
	_quota_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quota_card.add_theme_stylebox_override(&"panel", TileStyleScript.box(false, false))
	column.add_child(_quota_card)
	column.move_child(_quota_card, _scroll.get_index())
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override(&"separation", 6)
	_quota_card.add_child(v)
	_quota_words = Label.new()
	_quota_words.name = "QuotaWords"
	MenuStyleScript.style_label(_quota_words, 22, MenuStyleScript.COLOR_TITLE)
	_quota_words.add_theme_font_override(&"font", MenuStyleScript.title_font())
	v.add_child(_quota_words)
	_quota_bar = ProgressBar.new()
	_quota_bar.name = "QuotaBar"
	_quota_bar.show_percentage = false
	_quota_bar.custom_minimum_size = Vector2(WIDE_TILE.x - 40.0, 22.0)
	_quota_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.12)
	bg.set_corner_radius_all(11)
	var fg := StyleBoxFlat.new()
	fg.bg_color = MenuStyleScript.COLOR_VALUE
	fg.set_corner_radius_all(11)
	_quota_bar.add_theme_stylebox_override(&"background", bg)
	_quota_bar.add_theme_stylebox_override(&"fill", fg)
	v.add_child(_quota_bar)
	_quota_rule = Label.new()
	_quota_rule.name = "QuotaRule"
	_quota_rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quota_rule.custom_minimum_size = Vector2(WIDE_TILE.x - 40.0, 0.0)
	MenuStyleScript.style_label(_quota_rule, 18, MenuStyleScript.COLOR_DIM)
	v.add_child(_quota_rule)
	_quota_card.visible = false


## The card's words, as {headline, rule}, for `q` (a Ledger.quota_status()). Static so the
## tests read the words without a menu.
static func quota_lines(q: Dictionary) -> Dictionary:
	var delivered := int(q.get("delivered", 0))
	var quota := int(q.get("quota", 0))
	var days := int(q.get("days_left", 0))
	var when := "today" if days <= 0 else ("tomorrow" if days == 1 else "in %d days" % days)
	var head := "Quota: %d of %d coloured ponies by collection day, Day %d (%s)" % [
		mini(delivered, quota), quota, int(q.get("day", 0)), when]
	if delivered >= quota:
		head = "Quota met: %d coloured ponies. Collection day is Day %d (%s)" % [delivered,
			int(q.get("day", 0)), when]
	var rule := ""
	if bool(q.get("closed", false)):
		rule = "Account closed. The quota stands. Thank you for choosing Cloudsdale!"
	elif int(q.get("balance", 1)) <= 0:
		rule = "Paid in full. The account closes on collection day if the quota is met."
	else:
		rule = ("Owed: %d bits. Bits pay the balance; the account closes on a collection day, "
			+ "paid in full with the quota met. Blank Drifters do not count.") % int(q.get("balance", 0))
	return {"headline": head, "rule": rule}


## The card's two lines as drawn, or "" when it is not up.
func quota_card_text() -> String:
	if _quota_card == null or not _quota_card.visible:
		return ""
	return "%s\n%s" % [_quota_words.text, _quota_rule.text]


func _draw_quota_card() -> void:
	if _quota_card == null:
		return
	_quota_card.visible = _tab == Tab.PAY and quota_provider.is_valid()
	if not _quota_card.visible:
		return
	var q: Dictionary = quota_provider.call()
	var words := quota_lines(q)
	_quota_words.text = String(words["headline"])
	_quota_rule.text = String(words["rule"])
	_quota_bar.max_value = maxf(1.0, float(q.get("quota", 1)))
	_quota_bar.value = minf(float(q.get("delivered", 0)), _quota_bar.max_value)


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
