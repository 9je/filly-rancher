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
const MouseRowsScript := preload("res://ui/mouse_rows.gd")

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

## PaintScript is NOT re-declared here: the class comment above already carries it, and
## GDScript refuses a const that shadows one already declared on this same class.
const CasinoScript := preload("res://systems/casino.gd")

# --- the floor plan, in stage local pixels ----------------------------------------------------
const STAGE_HEIGHT := 510.0
const WALLET := Rect2(20.0, 8.0, 1080.0, 54.0)
const TILE_SIZE := Vector2(340.0, 200.0)
const TILE_ORIGIN := Vector2(30.0, 80.0)
const TILE_PITCH := Vector2(360.0, 216.0)
const TILE_ART_HEIGHT := 120.0
const RULES_PAGE := Rect2(40.0, 80.0, 1040.0, 410.0)
const EXCHANGE := Rect2(40.0, 80.0, 1040.0, 130.0)
const CAGE_ROW_ORIGIN := Vector2(60.0, 240.0)
const CAGE_ROW_SIZE := Vector2(500.0, 52.0)
const CAGE_ROW_PITCH := 60.0
const CAGE_ROWS_PER_COLUMN := 4

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

## Where the pointer is resting, or -1. Not the cursor: see game/ui/table_menu.gd's own
## comment on the same pair of fields.
var _hovered := -1
var _close: Button = null

## Seconds since this menu opened, advanced in _process while it is up. Read by paint() for
## the focus ring's breath and by every stage's own animation. NOT a clock: it is reset on
## open() so a screen looks the same the second time you walk up to it.
var _anim_t := 0.0

@onready var _title: Label = $Centre/Panel/Margin/Column/Title
@onready var _tabs: Label = $Centre/Panel/Margin/Column/Tabs
@onready var _rows: VBoxContainer = $Centre/Panel/Margin/Column/Rows
@onready var _footer: Label = $Centre/Panel/Margin/Column/Footer
@onready var _stage: Control = get_node_or_null(^"Centre/Panel/Margin/Column/Stage")


## get_node_or_null(), not the bare `Sound` identifier: see game/ui/menu_style.gd's own
## comment, and game/actors/player/magic_beam.gd's _sound_call, on why an autoload's name
## does not resolve under the parse sweep's check-only, script-only pass. is_inside_tree()
## first, so a menu built with .new() and never added anywhere gets a silent no-op rather
## than the engine error get_node() prints on a treeless node.
func _sound_call(method: StringName, args: Array) -> void:
	if not is_inside_tree():
		return
	var node: Node = get_node_or_null(^"/root/Sound")
	if node != null:
		node.callv(method, args)


func _ready() -> void:
	MenuStyleScript.apply_panel($Centre/Panel as PanelContainer)
	visible = false
	_title.text = TITLE
	var dim := get_node_or_null(^"Dim") as Control
	if dim != null:
		dim.mouse_filter = Control.MOUSE_FILTER_STOP
	if _stage != null:
		_stage.mouse_filter = Control.MOUSE_FILTER_STOP
		_stage.focus_mode = Control.FOCUS_NONE
		_stage.custom_minimum_size = stage_size()
		_stage.draw.connect(_paint_stage)
		_stage.gui_input.connect(_on_stage_input)
	_close = MouseRowsScript.close_button(MouseRowsScript.CLOSE_TEXT,
		func(_index: int) -> void: close())
	$Centre/Panel/Margin/Column.add_child(_close)
	set_process(false)


func open() -> bool:
	if _open:
		return false
	if can_open.is_valid() and not can_open.call():
		return false
	_open = true
	_tab = Tab.LOBBY
	_selected = 0
	_hovered = -1
	_anim_t = 0.0
	set_process(true)
	visible = true
	refresh()
	opened.emit()
	MenuStyleScript.tick_open()
	return true


func close() -> void:
	if not _open:
		return
	_open = false
	_hovered = -1
	visible = false
	set_process(false)
	closed.emit()
	MenuStyleScript.tick_back()


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
			# CAGE and RULES turn a tab on this same panel; the four games open their own
			# panel over the top of it, which already fires its own tick_open() (see
			# table_menu.gd's open()). Ticking tick_confirm() here too made one keypress
			# fire two sounds on those four rows, so only the tab-turn rows get one here.
			var opens_a_table: bool = _selected == Row.SLOTS or _selected == Row.WHEEL \
				or _selected == Row.BLACKJACK or _selected == Row.RACING
			room_requested.emit(_selected)
			if not opens_a_table:
				MenuStyleScript.tick_confirm()
			return true
		Tab.CAGE:
			var buys: Array[int] = buy_amounts()
			var cashes: Array[int] = cash_amounts()
			if _selected < 0:
				return false
			if _selected < buys.size():
				buy_chips_requested.emit(buys[_selected])
				MenuStyleScript.tick_confirm()
				_sound_call(&"play", [&"chip_clink"])
				return true
			var index: int = _selected - buys.size()
			if index < cashes.size():
				cash_out_requested.emit(cashes[index])
				MenuStyleScript.tick_confirm()
				_sound_call(&"play", [&"chip_clink"])
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
		# THE STAGE ALREADY COVERS EVERY ROW ON BOTH TABS: tile_rect() for the lobby,
		# cage_row_rect() for the cage (see stage_hit_rects() below), so nothing this loop
		# prints is ALSO a row nothing else already made clickable. Padding invisible rows
		# in here the way table_menu.gd does for the tables would draw empty boxes under a
		# tab (the lobby) whose column is otherwise blank, which is worse than not doing it.
		var row: int = i - first_row_line_index()
		if row < 0 or row >= _row_count():
			row = -1
		var label := Label.new()
		label.text = MenuStyleScript.caret(picked) + lines[i]
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		MenuStyleScript.style_label(label, MenuStyleScript.ROW_SIZE,
			MenuStyleScript.COLOR_VALUE if picked else MenuStyleScript.COLOR_NAME)
		var holder: PanelContainer
		if row >= 0:
			holder = MouseRowsScript.row(row, picked, row == _hovered, point_at_row, take_row)
		else:
			holder = MenuStyleScript.row_panel(picked)
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


func stage_size() -> Vector2:
	return Vector2(STAGE_WIDTH, STAGE_HEIGHT)


func tile_rect(index: int) -> Rect2:
	var lift: float = 6.0 if (index == _selected and _tab == Tab.LOBBY) else 0.0
	return Rect2(TILE_ORIGIN + Vector2(TILE_PITCH.x * float(index % 3),
		TILE_PITCH.y * float(index / 3)) - Vector2(0.0, lift), TILE_SIZE)


func wallet_rect() -> Rect2:
	return WALLET


func rules_rect() -> Rect2:
	return RULES_PAGE


## The cage's rows are the buys followed by the cashes, drawn as one list in two columns
## because the player is standing at one window. confirm()'s index arithmetic is unchanged.
func cage_row_rect(index: int) -> Rect2:
	return Rect2(CAGE_ROW_ORIGIN + Vector2(
		(CAGE_ROW_SIZE.x + 20.0) * float(index / CAGE_ROWS_PER_COLUMN),
		CAGE_ROW_PITCH * float(index % CAGE_ROWS_PER_COLUMN)), CAGE_ROW_SIZE)


# --- the felt, under the pointer ------------------------------------------------------------
#
## THE LOBBY'S TILES AND THE CAGE'S ROWS ARE ALREADY RECTS. tile_rect() and cage_row_rect()
## are what paint() draws into, so the hit test asks the drawing where things are rather than
## computing a second opinion. The house rules page is reading matter and offers no hits,
## which is the correct answer for a page with nothing on it to choose.


func stage_hit_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	match tab():
		Tab.LOBBY:
			for i in _row_count():
				out.append(tile_rect(i))
		Tab.CAGE:
			for i in _row_count():
				out.append(cage_row_rect(i))
	return out


func on_stage_hit(index: int) -> void:
	take_row(index)


func _on_stage_input(event: InputEvent) -> void:
	if not is_open() or _stage == null or not MouseRowsScript.is_left_click(event):
		return
	var button := event as InputEventMouseButton
	var index: int = MouseRowsScript.hit(stage_hit_rects(), button.position)
	if index < 0:
		return
	on_stage_hit(index)
	_stage.accept_event()


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


## Whether an animation is running RIGHT NOW, as opposed to the idle breath. While this is
## true confirm() refuses and move_selection() is ignored, so a spin cannot be started twice
## or re staked halfway through; ui_cancel still closes, because a player who wants out of a
## spinning reel gets out.
func animating() -> bool:
	return false


## THE STAGE SHOWS EVERY LOBBY ROW AND EVERY CAGE ROW, so the column under it keeps only the
## cage's three line explainer. drawn_lines() is unchanged and still returns all of it.
func printed_lines() -> Array[String]:
	if _tab != Tab.CAGE:
		return [] as Array[String]
	var lines: Array[String] = []
	for line in CasinoSignScript.cage_explainer():
		lines.append(line)
	return lines


func focus_rect() -> Rect2:
	match _tab:
		Tab.LOBBY:
			return to_viewport(tile_rect(clampi(_selected, 0, LOBBY_ROWS.size() - 1)))
		Tab.CAGE:
			if _row_count() <= 0:
				return Rect2()
			return to_viewport(cage_row_rect(clampi(_selected, 0, _row_count() - 1)))
	return Rect2()


func focused_id() -> StringName:
	match _tab:
		Tab.LOBBY:
			return StringName("tile:%d" % clampi(_selected, 0, LOBBY_ROWS.size() - 1))
		Tab.CAGE:
			if _row_count() <= 0:
				return &""
			return StringName("cage:%d" % clampi(_selected, 0, _row_count() - 1))
	return &""


func paint(ci: Control) -> void:
	var font: Font = ThemeDB.fallback_font
	var t: float = anim_time()

	# --- the wallet strip, on every page of the building ---------------------------------------
	# What she is holding, continuously, and the two side by side is what makes "one for one"
	# mean something. header_line() keeps returning its sentence for drawn_lines().
	PaintScript.rounded(ci, WALLET, 12.0, Color(PaintScript.PLUM_DARK, 0.9),
		PaintScript.GOLD_DIM, 2.0)
	var bits: int = int(bits_provider.call()) if bits_provider.is_valid() else 0
	var chips: int = int(chips_provider.call()) if chips_provider.is_valid() else 0
	PaintScript.draw_bit(ci, Rect2(WALLET.position + Vector2(18.0, 15.0), Vector2(24.0, 24.0)))
	PaintScript.text(ci, MenuStyleScript.numeral_font(),
		WALLET.position + Vector2(52.0, 37.0), "%d bits" % bits, MenuStyleScript.ROW_SIZE,
		PaintScript.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1.0)
	PaintScript.draw_chip_icon(ci,
		Rect2(WALLET.position + Vector2(200.0, 15.0), Vector2(24.0, 24.0)))
	PaintScript.text(ci, MenuStyleScript.numeral_font(),
		WALLET.position + Vector2(234.0, 37.0), "%d chips" % chips, MenuStyleScript.ROW_SIZE,
		PaintScript.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1.0)
	PaintScript.text(ci, font, WALLET.position + Vector2(400.0, 37.0),
		"one for one at the cage", MenuStyleScript.SUBTITLE_SIZE, MenuStyleScript.COLOR_DIM,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0)
	MenuStyleScript.rule(ci, Vector2(20.0, 70.0), Vector2(STAGE_WIDTH - 20.0, 70.0))

	match _tab:
		Tab.LOBBY:
			for i: int in LOBBY_ROWS.size():
				var tile: Rect2 = tile_rect(i)
				var picked: bool = i == _selected
				PaintScript.rounded(ci, tile, 14.0,
					Color(PaintScript.PLUM_DARK, 1.0 if picked else 0.74),
					PaintScript.GOLD if picked else PaintScript.GOLD_DIM, 2.0)
				PaintScript.draw_room(ci, Rect2(tile.position + Vector2(16.0, 10.0),
					Vector2(tile.size.x - 32.0, TILE_ART_HEIGHT)), i)
				# SPLIT AT THE COLON OF ITS OWN LOBBY_ROWS ENTRY. The six strings are not
				# rewritten: game/test/test_casino_menu.gd and the no dash sweeps read them,
				# and the wording is already good.
				var halves: PackedStringArray = LOBBY_ROWS[i].split(": ", true, 1)
				PaintScript.text(ci, MenuStyleScript.title_font(),
					tile.position + Vector2(18.0, TILE_ART_HEIGHT + 44.0), halves[0], 26,
					MenuStyleScript.COLOR_TITLE, HORIZONTAL_ALIGNMENT_LEFT, tile.size.x - 36.0)
				if halves.size() > 1:
					PaintScript.text(ci, font,
						tile.position + Vector2(18.0, TILE_ART_HEIGHT + 72.0), halves[1],
						MenuStyleScript.SUBTITLE_SIZE, MenuStyleScript.COLOR_DIM,
						HORIZONTAL_ALIGNMENT_LEFT, tile.size.x - 36.0)
				if picked:
					PaintScript.focus_ring(ci, tile, 14.0, t)
		Tab.CAGE:
			PaintScript.rounded(ci, EXCHANGE, 12.0, Color(PaintScript.FELT_DARK, 0.85),
				PaintScript.GOLD_DIM, 2.0)
			PaintScript.chip_stack(ci, EXCHANGE.position + Vector2(140.0, 104.0), 5,
				PaintScript.GOLD, 9.0)
			PaintScript.chip_stack(ci, EXCHANGE.position + Vector2(900.0, 104.0), 5,
				PaintScript.CHIP_COLORS[1], 9.0)
			for direction: float in [-1.0, 1.0]:
				var y: float = EXCHANGE.position.y + 62.0
				ci.draw_line(Vector2(EXCHANGE.position.x + 240.0, y),
					Vector2(EXCHANGE.position.x + 800.0, y), PaintScript.GOLD, 3.0, true)
				var tip_x: float = EXCHANGE.position.x + (800.0 if direction > 0.0 else 240.0)
				ci.draw_colored_polygon(PackedVector2Array([
					Vector2(tip_x + 18.0 * direction, y),
					Vector2(tip_x, y - 12.0), Vector2(tip_x, y + 12.0)]), PaintScript.GOLD)
			PaintScript.text(ci, MenuStyleScript.numeral_font(),
				EXCHANGE.position + Vector2(520.0, 48.0),
				"%d for %d" % [CasinoScript.CHIP_RATE, CasinoScript.CHIP_RATE],
				MenuStyleScript.ROW_SIZE, PaintScript.GOLD, HORIZONTAL_ALIGNMENT_CENTER, -1.0)
			var buys: Array[int] = buy_amounts()
			var cashes: Array[int] = cash_amounts()
			var index := 0
			for amount: int in buys:
				_paint_cage_row(ci, font, index, "Buy %d chips for %d bits" % [amount, amount],
					PaintScript.CHIP_COLORS[1], t)
				index += 1
			for amount: int in cashes:
				_paint_cage_row(ci, font, index,
					"Cash out %d chips for %d bits" % [amount, amount], PaintScript.GOLD, t)
				index += 1
			if buys.is_empty() and cashes.is_empty():
				PaintScript.text(ci, font, CAGE_ROW_ORIGIN + Vector2(0.0, 34.0),
					"Come back when you have something to play with.",
					MenuStyleScript.ROW_SIZE, MenuStyleScript.COLOR_DIM,
					HORIZONTAL_ALIGNMENT_LEFT, -1.0)
		Tab.RULES:
			# THE PUBLISHED EDGES LIVE HERE NOW. sign_provider is ranch.gd's own lambda over
			# CasinoSign.lines(), which asks each game for its real number; nothing about that
			# promise changed when the board outside stopped being a paragraph in the air.
			var rules: Array[String] = []
			if sign_provider.is_valid():
				for line in sign_provider.call():
					rules.append(String(line))
			PaintScript.plate(ci, RULES_PAGE, font, "", rules)


func _paint_cage_row(ci: Control, font: Font, index: int, label: String, colour: Color,
		t: float) -> void:
	var rect: Rect2 = cage_row_rect(index)
	var picked: bool = index == _selected
	PaintScript.rounded(ci, rect, 8.0, Color(PaintScript.FELT_DARK, 0.8),
		PaintScript.GOLD_DIM, 1.0)
	PaintScript.chip(ci, rect.position + Vector2(30.0, rect.size.y * 0.5), 18.0, colour, false)
	PaintScript.text(ci, font, rect.position + Vector2(62.0, 34.0), label,
		MenuStyleScript.ROW_SIZE, MenuStyleScript.COLOR_NAME, HORIZONTAL_ALIGNMENT_LEFT,
		rect.size.x - 80.0)
	if picked:
		PaintScript.focus_ring(ci, rect, 8.0, t)


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
