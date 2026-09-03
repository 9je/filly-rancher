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

## DECLARED HERE AND NOWHERE ELSE ON THE LOBBY. `CasinoMenu` is not a `TableMenu`: same scene
## tree, same stage mechanism, but its own `CanvasLayer`, so it carries its own copy of this
## preload and the constant below rather than inheriting `TableMenu`'s. See table_menu.gd's
## own comment on why that duplication is deliberate.
const PaintScript := preload("res://ui/casino_paint.gd")

## The stage's width in 1920x1080 base pixels: the Panel's 1180 minus the Margin node's
## 30 either side. Every drawn screen in the building is laid out against this one number, so
## a rect computed on the lobby and a rect computed on a table means the same thing.
const STAGE_WIDTH := 1120.0

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

## Seconds since this menu opened, advanced in _process while it is up. Read by paint() for
## the focus ring's breath and by every stage's own animation. NOT a clock: it is reset on
## open() so a screen looks the same the second time you walk up to it.
var _anim_t := 0.0

@onready var _title: Label = $Centre/Panel/Margin/Column/Title
@onready var _tabs: Label = $Centre/Panel/Margin/Column/Tabs
@onready var _rows: VBoxContainer = $Centre/Panel/Margin/Column/Rows
@onready var _footer: Label = $Centre/Panel/Margin/Column/Footer
@onready var _stage: Control = get_node_or_null(^"Centre/Panel/Margin/Column/Stage")


func _ready() -> void:
	MenuStyleScript.apply_panel($Centre/Panel as PanelContainer)
	visible = false
	_title.text = TITLE
	if _stage != null:
		_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stage.custom_minimum_size = stage_size()
		_stage.draw.connect(_paint_stage)
	set_process(false)


func open() -> bool:
	if _open:
		return false
	if can_open.is_valid() and not can_open.call():
		return false
	_open = true
	_tab = Tab.LOBBY
	_selected = 0
	_anim_t = 0.0
	set_process(true)
	visible = true
	refresh()
	opened.emit()
	return true


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	set_process(false)
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
	if _stage != null:
		_stage.custom_minimum_size = stage_size()
		_stage.queue_redraw()
	var lines: Array[String] = printed_lines()
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


# --- the stage ------------------------------------------------------------------------------

## THE MENU REDRAWS WHILE IT IS OPEN AND NEVER WHILE IT IS SHUT. Every casino screen has at
## least one thing moving on it the whole time it is up (the focus ring breathes, so a still
## screenshot and a live screen say the same thing about where the cursor is), and the world
## is paused behind it, so "while open" IS the window in which an animation is live. Closed,
## set_process(false) stops it dead: a menu nobody is looking at must cost nothing, which is
## the same discipline SkyRig._needs_ticks() follows.
func _process(delta: float) -> void:
	if not _open or _stage == null:
		return
	_anim_t += delta
	_stage.queue_redraw()


func _paint_stage() -> void:
	if _stage != null:
		paint(_stage)


func anim_time() -> float:
	return _anim_t


## What this screen paints. Overridden by the lobby's own stage; the base paints nothing,
## which is the right answer for a screen that has no stage yet.
func paint(_ci: Control) -> void:
	pass


## THE SIZE THE STAGE NODE RESERVES. Overridden per screen; a screen with no stage reserves
## nothing and its column closes over the gap.
func stage_size() -> Vector2:
	return Vector2.ZERO


## Whether an animation is running RIGHT NOW, as opposed to the idle breath. While this is
## true confirm() refuses and move_selection() is ignored, so a spin cannot be started twice
## or re staked halfway through; ui_cancel still closes, because a player who wants out of a
## spinning reel gets out.
func animating() -> bool:
	return false


## THE LINES THE Rows VBOX ACTUALLY PRINTS. drawn_lines() stays the whole text model of the
## screen and is what the tests and game/test/test_published_payouts.gd read; a screen whose
## stage already SHOWS a line overrides this to leave it out of the column, so the panel does
## not say the same thing twice.
func printed_lines() -> Array[String]:
	return drawn_lines()


## WHERE THE FOCUS RING WAS LAST ACTUALLY PAINTED, in VIEWPORT coordinates, and what it was
## painted on. For the caret test, which must keep asking the DRAWING where the cursor is
## rather than asking the number; see game/test/test_table_caret.gd for the defect that rule
## exists for.
##
## VIEWPORT AND NOT STAGE LOCAL, because the answer can come from either of two coordinate
## spaces: a stage computes its rects in its own, and a screen with no stage yet reports the
## row PanelContainer refresh() marked, which is in the Rows column's. A caller that had to
## know which one it was looking at is a caller that can be wrong.
func focus_rect() -> Rect2:
	for holder in _rows.get_children():
		if holder.is_queued_for_deletion():
			continue
		var panel := holder as PanelContainer
		if panel == null:
			continue
		for child in panel.get_children():
			var label := child as Label
			if label != null and label.text.begins_with(MenuStyleScript.CARET):
				return panel.get_global_rect()
	return Rect2()


func focused_id() -> StringName:
	return StringName("row:%d" % _selected) if _row_count() > 0 else &""


## The stage's own rect in viewport coordinates, so a stage can hand a local rect back out
## through focus_rect() without every stage repeating the conversion.
func to_viewport(local: Rect2) -> Rect2:
	if _stage == null:
		return Rect2()
	return Rect2(_stage.get_global_rect().position + local.position, local.size)


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
