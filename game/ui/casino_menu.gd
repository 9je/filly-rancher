class_name CasinoMenu
extends CanvasLayer
## THE LOBBY OF THE SPECTRA PALACE: the cage, the house sign, and the four doors.
##
## THE MENU DRAWS AND EMITS; ranch.gd TRANSACTS AND PAYS. This file never touches Economy,
## Casino, GameState or a pony. It is handed four Callables (how many bits, how many chips,
## what the sign says, and whether it may open at all) and it hands back three signals. Same
## split as game/ui/depot_menu.gd, same reason: the whole of this is testable in milliseconds
## against four lambdas, and the money lives in exactly one file.
##
## THE HOUSE TAB IS NOT DECORATION. The spec's promise is that the edge is published in the
## lobby, so it is a tab in the lobby menu as well as a sign on the wall; a player who never
## looks up still gets the numbers put in front of her before she buys a chip.
##
## THE CAGE OFFERS ONLY WHAT SHE CAN COVER, in both directions, for the reason
## DepotMenu.pay_amounts() gives: a menu row that always refuses is a menu row that lies.

const MenuStyleScript := preload("res://ui/menu_style.gd")

enum Tab { CAGE, HOUSE, GAMES }
enum Game { SLOTS, WHEEL, BLACKJACK, RACING }

const TAB_NAMES: Array[String] = ["Cage", "House", "Games"]
const GAME_NAMES: Array[String] = ["Slots", "The Wheel", "Blackjack", "Racing"]
const TITLE := "Spectra Palace"

## The amounts the cage offers before they are cut down to what she is holding.
const CAGE_STEPS: Array[int] = [100, 500, 2000, 10000]

signal opened()
signal closed()
signal buy_chips_requested(bits: int)
signal cash_out_requested(chips: int)
signal game_requested(game: int)

var can_open := Callable()
var bits_provider := Callable()
var chips_provider := Callable()
var sign_provider := Callable()

var _tab: int = Tab.CAGE
var _selected := 0
var _open := false

@onready var _title: Label = $Centre/Panel/Margin/Column/Title
@onready var _tabs: Label = $Centre/Panel/Margin/Column/Tabs
@onready var _rows: VBoxContainer = $Centre/Panel/Margin/Column/Rows
@onready var _footer: Label = $Centre/Panel/Margin/Column/Footer


func _ready() -> void:
	visible = false
	_title.text = TITLE


func open() -> bool:
	if _open:
		return false
	if can_open.is_valid() and not can_open.call():
		return false
	_open = true
	_tab = Tab.CAGE
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
	_tab = clampi(value, Tab.CAGE, Tab.GAMES)
	_selected = 0
	refresh()


func switch_tab(step: int) -> void:
	set_tab(posmod(_tab + step, Tab.GAMES + 1))


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


## Every line this menu is currently drawing, in order. For the tests, which otherwise have
## no way to ask whether a string carries a dash without walking the Label nodes.
func drawn_lines() -> Array[String]:
	var lines: Array[String] = []
	match _tab:
		Tab.CAGE:
			var buys: Array[int] = buy_amounts()
			var cashes: Array[int] = cash_amounts()
			if buys.is_empty() and cashes.is_empty():
				lines.append("Come back when you have something to play with.")
			for amount in buys:
				lines.append("Buy %d chips for %d bits" % [amount, amount])
			for amount in cashes:
				lines.append("Cash out %d chips for %d bits" % [amount, amount])
		Tab.HOUSE:
			if sign_provider.is_valid():
				for line in sign_provider.call():
					lines.append(String(line))
		Tab.GAMES:
			for game_name in GAME_NAMES:
				lines.append(game_name)
	return lines


## Act on the highlighted row. The cage's rows are the buys followed by the cashes, so the
## index decides which of the two signals goes out; the tab is drawn as one list because the
## player is standing at one window.
func confirm() -> bool:
	match _tab:
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
		Tab.GAMES:
			if _selected < 0 or _selected >= GAME_NAMES.size():
				return false
			game_requested.emit(_selected)
			return true
	return false


func refresh() -> void:
	if not is_node_ready():
		return
	_footer.text = MenuStyleScript.footer_tabs_and_rows("confirm", "leave")
	MenuStyleScript.style_label(_footer, MenuStyleScript.FOOTER_SIZE, MenuStyleScript.COLOR_DIM)
	_tabs.text = MenuStyleScript.tab_strip(TAB_NAMES, _tab)
	for child in _rows.get_children():
		child.queue_free()
	var lines: Array[String] = drawn_lines()
	for i in lines.size():
		var label := Label.new()
		var picked: bool = i == _selected and _tab != Tab.HOUSE
		label.text = MenuStyleScript.caret(picked) + lines[i]
		label.add_theme_color_override("font_color",
			MenuStyleScript.COLOR_VALUE if picked else MenuStyleScript.COLOR_NAME)
		_rows.add_child(label)


func _row_count() -> int:
	match _tab:
		Tab.CAGE:
			return buy_amounts().size() + cash_amounts().size()
		Tab.GAMES:
			return GAME_NAMES.size()
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
