class_name CasinoMenu
extends CanvasLayer
## ONE SCREEN YOU WALK INTO, with one row per thing you can do in the building. The owner,
## 2026-08-31: "rework the casino flow so it is playable without reading docs. Entering the
## Palace opens ONE lobby screen with big obvious rows".
##
## WHAT WAS WRONG. The lobby opened on the CAGE tab, whose rows were bare amounts with no
## explanation of what a chip was; the four games lived behind a third tab reachable only
## by pressing left or right, which nothing on the screen said; and the house edge sat on a
## tab in between. A player who had not read the design document could open this menu and
## not find the slot machine.
##
## THE CAGE AND THE RULES ARE STILL TABS, because they are pages rather than rooms and a
## player who picks them from the lobby ends up on them. Everything else about the split is
## unchanged: this file never touches Economy, Casino, GameState or a pony, it is handed
## four Callables and it hands back three signals, and ranch.gd does every transaction.
##
## THE CAGE OFFERS ONLY WHAT SHE CAN COVER, in both directions, for the reason
## DepotMenu.pay_amounts() gives: a menu row that always refuses is a menu row that lies.

const MenuStyleScript := preload("res://ui/menu_style.gd")
const CasinoSignScript := preload("res://systems/casino_sign.gd")

enum Tab { LOBBY, CAGE, RULES }

## The rows in the lobby, in order. The enum and LOBBY_ROWS are indexed together.
enum Row { CAGE, SLOTS, WHEEL, BLACKJACK, RACING, RULES }

## ONE LINE PER ROOM, AND EVERY ONE OF THEM SAYS WHAT IT IS FOR. "Slots" is a noun a player
## already knows; "Wheel" is not, and neither is "Cage". The second half of each row is the
## whole of the onboarding this building needs.
##
## NOT PADDED INTO COLUMNS ANY MORE (Ruling 26). These rows shipped with runs of spaces
## lining the descriptions up under each other, which lines nothing up: the panel draws them
## in the project's proportional UI font, where a space is narrower than an average glyph
## and every row is a different length in pixels. What the padding actually bought was a
## ragged second column plus a caret that shifts the whole row when it lands on one. A
## colon and one space says the same thing and says it truthfully; the grid pattern
## game/ui/hud.gd's _build_hints() uses is the other way to get real columns, and it is what
## a panel that genuinely needs them should reach for.
const LOBBY_ROWS: Array[String] = [
	"Cage: turn bits into chips, and chips back into bits",
	"Slots: three reels, one lever, the fast one",
	"The Wheel: back a colour or back a number",
	"Blackjack: get closer to 21 than the dealer, without going over",
	"Racing: enter one of your own ponies and back her to win",
	"House rules: exactly how much we keep, printed by us",
]

const TAB_NAMES: Array[String] = ["Lobby", "Cage", "House rules"]
const TITLE := "Spectra Palace"

## The amounts the cage offers before they are cut down to what she is holding.
const CAGE_STEPS: Array[int] = [100, 500, 2000, 10000]

signal opened()
signal closed()
signal buy_chips_requested(bits: int)
signal cash_out_requested(chips: int)
signal room_requested(row: int)

var can_open := Callable()
var bits_provider := Callable()
var chips_provider := Callable()
var sign_provider := Callable()

var _tab: int = Tab.LOBBY
var _selected := 0
var _open := false

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
	_tab = Tab.LOBBY
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
	_tab = clampi(value, Tab.LOBBY, Tab.RULES)
	_selected = 0
	refresh()


func switch_tab(step: int) -> void:
	set_tab(posmod(_tab + step, Tab.RULES + 1))


func selected_index() -> int:
	return _selected


func move_selection(step: int) -> void:
	var n: int = _row_count()
	if n <= 0:
		_selected = 0
		return
	_selected = posmod(_selected + step, n)
	refresh()


## What the cage will sell her, cut to the bits she is holding, plus an "everything" row when
## that beats the biggest step.
func buy_amounts() -> Array[int]:
	return _steps_within(int(bits_provider.call()) if bits_provider.is_valid() else 0)


## What the cage will buy back, cut to the chips she is holding.
func cash_amounts() -> Array[int]:
	return _steps_within(int(chips_provider.call()) if chips_provider.is_valid() else 0)


func _steps_within(held: int) -> Array[int]:
	var out: Array[int] = []
	for step in CAGE_STEPS:
		if step <= held:
			out.append(step)
	if held > 0 and (out.is_empty() or out[out.size() - 1] < held):
		out.append(held)
	return out


## WHAT SHE IS HOLDING, ON EVERY PAGE OF THE BUILDING. Bits and chips together, because
## the one thing a player in a casino needs continuously is her own balance, and because
## seeing them side by side is what makes "one for one" mean something.
func header_line() -> String:
	var bits: int = int(bits_provider.call()) if bits_provider.is_valid() else 0
	var chips: int = int(chips_provider.call()) if chips_provider.is_valid() else 0
	return "You have %d bits and %d chips." % [bits, chips]


## Every line this menu is currently drawing, in order. For the tests, which otherwise have
## no way to ask whether a string carries a dash without walking the Label nodes.
func drawn_lines() -> Array[String]:
	var lines: Array[String] = []
	match _tab:
		Tab.LOBBY:
			for row in LOBBY_ROWS:
				lines.append(row)
		Tab.CAGE:
			for line in CasinoSignScript.cage_explainer():
				lines.append(line)
			var buys: Array[int] = buy_amounts()
			var cashes: Array[int] = cash_amounts()
			if buys.is_empty() and cashes.is_empty():
				lines.append("Come back when you have something to play with.")
			for amount in buys:
				lines.append("Buy %d chips for %d bits" % [amount, amount])
			for amount in cashes:
				lines.append("Cash out %d chips for %d bits" % [amount, amount])
		Tab.RULES:
			if sign_provider.is_valid():
				for line in sign_provider.call():
					lines.append(String(line))
	return lines


## WHICH DRAWN LINE ROW ZERO IS, the same question game/ui/table_menu.gd answers for its own
## tables: the CAGE page prints the explainer above its first choosable row, so the caret
## has to be offset by exactly that many lines or it highlights a sentence.
func first_row_line_index() -> int:
	return CasinoSignScript.cage_explainer().size() if _tab == Tab.CAGE else 0


## Act on the highlighted row. The cage's rows are the buys followed by the cashes, so the
## index decides which of the two signals goes out; the tab is drawn as one list because the
## player is standing at one window.
func confirm() -> bool:
	match _tab:
		Tab.LOBBY:
			if _selected < 0 or _selected >= LOBBY_ROWS.size():
				return false
			room_requested.emit(_selected)
			return true
		Tab.CAGE:
			var buys: Array[int] = buy_amounts()
			var cashes: Array[int] = cash_amounts()
			if _selected < 0:
				return false
			if _selected < buys.size():
				buy_chips_requested.emit(buys[_selected])
				return true
			var index: int = _selected - buys.size()
			if index < cashes.size():
				cash_out_requested.emit(cashes[index])
				return true
			return false
	return false


func refresh() -> void:
	if not is_node_ready():
		return
	_footer.text = MenuStyleScript.footer_tabs_and_rows("confirm", "leave")
	MenuStyleScript.style_label(_footer, MenuStyleScript.FOOTER_SIZE, MenuStyleScript.COLOR_DIM)
	_tabs.text = MenuStyleScript.tab_strip(TAB_NAMES, _tab) + "      " + header_line()
	for child in _rows.get_children():
		child.queue_free()
	MenuStyleScript.apply_title(_title)
	var lines: Array[String] = drawn_lines()
	var caret: int = _selected + first_row_line_index()
	for i in lines.size():
		var picked: bool = i == caret and _row_count() > 0
		var label := Label.new()
		label.text = MenuStyleScript.caret(picked) + lines[i]
		MenuStyleScript.style_label(label, MenuStyleScript.ROW_SIZE,
			MenuStyleScript.COLOR_VALUE if picked else MenuStyleScript.COLOR_NAME)
		var holder: PanelContainer = MenuStyleScript.row_panel(picked)
		holder.add_child(label)
		_rows.add_child(holder)


func _row_count() -> int:
	match _tab:
		Tab.LOBBY:
			return LOBBY_ROWS.size()
		Tab.CAGE:
			return buy_amounts().size() + cash_amounts().size()
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
