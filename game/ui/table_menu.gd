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

const MenuStyleScript := preload("res://ui/menu_style.gd")
const InputDeviceScript := preload("res://systems/input_device.gd")

## DECLARED HERE AND NOWHERE ELSE ON A TABLE. The base itself paints nothing, but every table
## that extends this one paints through the kit, and GDScript refuses a const that shadows one
## declared on the parent class (the same rule WHEEL_FOOTER's own comment records). So
## slots_menu.gd, wheel_menu.gd, blackjack_menu.gd and race_menu.gd inherit this and must not
## re-declare it; casino_menu.gd is not a TableMenu and declares its own.
const PaintScript := preload("res://ui/casino_paint.gd")

const MouseRowsScript := preload("res://ui/mouse_rows.gd")

## The stage's width in 1920x1080 base pixels: the Panel's 1180 minus the Margin node's
## 30 either side. Every drawn screen in the building is laid out against this one number, so
## a rect computed on the slot machine and a rect computed on the wheel mean the same thing.
const STAGE_WIDTH := 1120.0

## What the tables let her bet. Even numbers, always: Blackjack.payout() pays three to two
## with integer division and an odd stake would round the bonus down by half a chip.
const STAKES: Array[int] = [10, 50, 200]

signal opened()
signal closed()

var can_open := Callable()
var chips_provider := Callable()

var _open := false
var _selected := 0
var _stake_index := 0
var _result: Array[String] = []

## Seconds since this menu opened, advanced in _process while it is up. Read by paint() for
## the focus ring's breath and by every stage's own animation. NOT a clock: it is reset on
## open() so a screen looks the same the second time you walk up to it.
var _anim_t := 0.0

## The row the pointer is resting on, or -1. Distinct from _selected: the cursor is where
## she IS, this is where the pointer merely is, and a screenshot has to be able to show both.
var _hovered := -1

## The close button _ready() appends under the footer. Kept so a test and a subclass can
## reach it without walking the column.
var _close: Button = null

@onready var _title: Label = $Centre/Panel/Margin/Column/Title
@onready var _tabs: HBoxContainer = $Centre/Panel/Margin/Column/Tabs
@onready var _rows: VBoxContainer = $Centre/Panel/Margin/Column/Rows
@onready var _footer: Label = $Centre/Panel/Margin/Column/Footer
@onready var _stage: Control = get_node_or_null(^"Centre/Panel/Margin/Column/Stage")


## get_node_or_null(), not the bare `Sound` identifier: see game/ui/menu_style.gd's own
## comment, and game/actors/player/magic_beam.gd's _sound_call, on why an autoload's name
## does not resolve under the parse sweep's check-only, script-only pass. Every table
## inherits this for the one direct sound a bet makes, chip_clink, which rides the same
## bus as the rest of the room's ambience rather than the UI bus MenuStyle's ticks use.
## is_inside_tree() first, so a table built with .new() and never added anywhere gets a
## silent no-op rather than the engine error get_node() prints on a treeless node.
func _sound_call(method: StringName, args: Array) -> void:
	if not is_inside_tree():
		return
	var node: Node = get_node_or_null(^"/root/Sound")
	if node != null:
		node.callv(method, args)


func _ready() -> void:
	MenuStyleScript.apply_panel($Centre/Panel as PanelContainer)
	visible = false
	_title.text = title_text()
	# THE DIM IS A SHUTTER, NOT A DECORATION. It used to ignore the mouse, so a click beside
	# the panel fell through to the paused world behind it.
	var dim := get_node_or_null(^"Dim") as Control
	if dim != null:
		dim.mouse_filter = Control.MOUSE_FILTER_STOP
		# The world behind, softened rather than blacked out (MenuStyle.soften_dim).
		MenuStyleScript.soften_dim(dim)
	if _stage != null:
		# STOP, not IGNORE: this is the felt, and the felt is where the game is.
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
	_selected = 0
	_hovered = -1
	_stake_index = 0
	_result = []
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
	MenuStyleScript.tick_move()


## Push the lines describing what just happened. Replaces whatever was there, so the panel
## always shows the last hand and never two of them.
func show_result(lines: Array[String]) -> void:
	_result = lines.duplicate()
	refresh()


func result_lines() -> Array[String]:
	return _result.duplicate()


## Injected by ranch.gd alongside chips_provider, so a table can say what she is holding.
## Already present as chips_provider; this is only the sentence built from it.
##
## THE REPORT: "each table screen shows your chips, the stake picker, and what keys do
## what". A table that shows only a stake row is a table a player cannot tell she is broke
## at until a bet silently refuses.
func chips_line() -> String:
	var chips: int = int(chips_provider.call()) if chips_provider.is_valid() else 0
	if chips <= 0:
		return "You have no chips. The cage is in the lobby, and it is one for one."
	return "You have %d chips." % chips


## WHAT THE KEYS DO ON THIS TABLE, in the glyphs of the device in her hands. Distinct from
## the footer, which says how to move around a menu: this says what the CONTROLS OF THE GAME
## are, which on every table in this building is "the stake is on the last row".
func keys_line() -> String:
	return "Pick a stake on the stake row, then %s to play. %s leaves." % [
		InputDeviceScript.hint(&"ui_accept"), InputDeviceScript.hint(&"ui_cancel")]


## THE LAST HAND, AS ITS OWN BLOCK, set off by a blank line either side (the "= = =" rules
## that once boxed it were typewriter art in a drawn screen; Fable AAA round 3). Empty until
## something has been settled, which is the correct state for a table nobody has played yet.
func result_block() -> Array[String]:
	if _result.is_empty():
		return []
	var out: Array[String] = [""]
	for line in _result:
		out.append(line)
	out.append("")
	return out


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
	_footer.text = MenuStyleScript.footer_tabs_and_rows("confirm", "leave")
	MenuStyleScript.style_label(_footer, MenuStyleScript.FOOTER_SIZE, MenuStyleScript.COLOR_DIM)
	_title.text = title_text()
	MouseRowsScript.tab_strip(_tabs, tab_names(), tab(), point_at_tab, take_tab)
	var note_text := tabs_text()
	if not note_text.is_empty():
		var note := Label.new()
		note.text = ("      " if not tab_names().is_empty() else "") + note_text
		note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		MenuStyleScript.style_label(note, MenuStyleScript.ROW_SIZE, MenuStyleScript.COLOR_NAME)
		_tabs.add_child(note)
	for child in _rows.get_children():
		child.queue_free()
	MenuStyleScript.apply_title(_title)
	if _stage != null:
		_stage.custom_minimum_size = stage_size()
		_stage.queue_redraw()
	var lines: Array[String] = printed_lines()
	var caret: int = _selected + first_row_line_index()
	# A TABLE THAT DRAWS ITS ROWS ON THE STAGE STILL NEEDS A MOUSE TARGET FOR EACH OF THEM.
	# slots_menu.gd and wheel_menu.gd both print nothing for their rows (the stake chips and
	# the felt draw them instead), so first_row_line_index() sits past the end of
	# printed_lines() and this loop would otherwise never reach a row at all. printed_count
	# marks where the real text ends; every index padded on past it is a hit target ONLY --
	# the stage already paints the selection, so a padded row paints nothing of its own at
	# rest or picked, and at most the plain hover box while the pointer is actually on it.
	var printed_count: int = lines.size()
	while lines.size() < first_row_line_index() + row_count():
		lines.append("")
	for i in lines.size():
		var picked: bool = i == caret and row_count() > 0
		var row: int = _row_at_line(i)
		var padded: bool = i >= printed_count
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var holder: PanelContainer
		if padded:
			label.text = ""
			holder = PanelContainer.new()
			if row >= 0:
				MouseRowsScript.arm(holder, row, point_at_row, take_row)
			holder.add_theme_stylebox_override(&"panel",
				MenuStyleScript.row_box_hover() if row == _hovered else StyleBoxEmpty.new())
		else:
			label.text = MenuStyleScript.caret(picked) + lines[i]
			# style_label() AND NOT A BARE font_color OVERRIDE. This line used to set the
			# colour alone, so every row on every table in the Palace shipped with no
			# outline, over a translucent panel, over a bright green field: exactly the
			# readability failure MenuStyle.OUTLINE_COLOR's own comment exists to prevent.
			# CasinoMenu was already doing it correctly, which is why the shared test never
			# caught this one.
			MenuStyleScript.style_label(label, MenuStyleScript.ROW_SIZE,
				MenuStyleScript.COLOR_VALUE if picked else MenuStyleScript.COLOR_NAME)
			if row >= 0:
				holder = MouseRowsScript.row(row, picked, row == _hovered,
					point_at_row, take_row)
			else:
				# A PRINTED LINE THAT IS NOT A ROW. The result block and the chips line are
				# text the panel prints above its rows; nothing may pick them, so nothing
				# arms them.
				holder = MenuStyleScript.row_panel(picked)
		holder.add_child(label)
		_rows.add_child(holder)


# --- what a table fills in ---------------------------------------------------------------

func title_text() -> String:
	return "Table"


## I5, final-review.md I3: the names on the tab strip, in tab-index order. Empty by default
## -- slots_menu.gd never overrides this, because the felt is the only screen the lever and
## the reels open onto -- so MouseRows.tab_strip() below builds nothing for it, exactly as an
## empty Tabs Label used to draw nothing. wheel_menu.gd, blackjack_menu.gd and race_menu.gd
## each override this with their own two names and keep tabs_text() for the note beside them
## ("the house keeps X% ...").
func tab_names() -> Array[String]:
	return []


## Which tab is current. Every table that HAS tabs already defines this with exactly this
## signature (wheel_menu.gd, blackjack_menu.gd, race_menu.gd); this default is only ever
## reached by a table, like slots_menu.gd, whose tab_names() is empty, so nothing ever asks.
func tab() -> int:
	return 0


func set_tab(_value: int) -> void:
	pass


## I5: the mouse's own door into a tab, beside switch_tab()'s keyboard one. A click direct on
## the tab it names is unambiguous, so this skips straight to set_tab() rather than
## switch_tab()'s step-by-step posmod -- and, on race_menu.gd and wheel_menu.gd, rather than
## switch_tab()'s stake-row special case, which exists only to disambiguate an OVERLOADED
## arrow key and has nothing to disambiguate when the click already named the tab.
func point_at_tab(_index: int) -> void:
	pass


func take_tab(index: int) -> void:
	if index == tab():
		return
	set_tab(index)
	MenuStyleScript.tick_page()


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
	MenuStyleScript.tick_page()


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


## What this table paints. Overridden by each table; the base paints nothing, which is the
## right answer for a table that has no stage yet.
func paint(_ci: Control) -> void:
	pass


## THE SIZE THE STAGE NODE RESERVES. Overridden per table; a table with no stage reserves
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
## screen and is what the tests and game/test/test_published_payouts.gd read; a table whose
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
## spaces: a stage computes its rects in its own, and a table with no stage yet reports the
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
	return StringName("row:%d" % _selected) if row_count() > 0 else &""


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


# --- the pointer ----------------------------------------------------------------------------
#
# ONE CURSOR, TWO WAYS TO MOVE IT. point_at_row() is move_selection() with an absolute
# destination instead of a step, and it makes the same sound, because a player who moves the
# cursor with the mouse and a player who moves it with the arrow keys have done the same
# thing and should hear the same thing.


## Which drawn line is selectable row `index`, or -1 for a line nothing may pick. The
## printed column and the selectable rows are not the same list; see first_row_line_index().
func _row_at_line(line: int) -> int:
	var index: int = line - first_row_line_index()
	return index if index >= 0 and index < row_count() else -1


func hovered_index() -> int:
	return _hovered


func close_button_node() -> Button:
	return _close


## Put the cursor on `index`. Refuses while an animation is running, exactly as
## move_selection() is refused by every table that overrides it, so a spinning reel cannot be
## re staked with the pointer either.
func point_at_row(index: int) -> void:
	if not _open or animating():
		return
	if index < 0 or index >= row_count():
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


## THE STAGE'S OWN CLICKABLE RECTS, in stage local coordinates. Empty on the base, which is
## the right answer for a table that paints nothing worth pointing at.
func stage_hit_rects() -> Array[Rect2]:
	return []


## What a click on stage rect `_index` does. Overridden by the tables that have one.
func on_stage_hit(_index: int) -> void:
	pass


func _on_stage_input(event: InputEvent) -> void:
	if not _open or _stage == null or not MouseRowsScript.is_left_click(event):
		return
	var button := event as InputEventMouseButton
	var index: int = MouseRowsScript.hit(stage_hit_rects(), button.position)
	if index < 0:
		return
	on_stage_hit(index)
	_stage.accept_event()
