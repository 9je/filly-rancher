class_name BuildMenu
extends CanvasLayer
## THE THING YOU SEE WHEN YOU WALK ONTO AN EMPTY PLOT AND PRESS BUILD.
##
## A list of everything in game/data/plots/, cheapest first, with what each one costs and
## how many ponies it holds. Pick one you can afford and it goes up on the slot you are
## standing in. Phase 1B Task 3.
##
## --- IT IS NAVIGABLE WITHOUT A MOUSE, AND THAT IS NOT OPTIONAL ---------------------------
##
## The HUD's hints card (game/ui/hud.gd's HINTS) lists a keyboard column and a gamepad
## column side by side, because "the build is handed to two people and only one of them is
## going to be at the keyboard". A build menu that needed a mouse click would be the first
## thing in this game that one of those two people could not use.
##
## Navigation is on Godot's BUILT-IN `ui_up` / `ui_down` / `ui_accept` / `ui_cancel` actions
## rather than on new project-specific ones. That is a deliberate exception to this
## project's "every control is a named action in game/project.godot" convention, and the
## reason is that all four are meant to stay in step with every other Godot menu the player
## has ever used, keyboard and d-pad alike -- `ui_up`/`ui_down` get that for free from the
## engine's own defaults (arrows, d-pad, left stick) and are correctly NOT redeclared.
## `ui_accept`/`ui_cancel` looked like they would too, but a headless InputMap dump caught
## them shipping keyboard-only (Enter/Kp Enter/Space, Escape) with no gamepad event at all
## -- a gamepad player could steer this menu with the d-pad and then had no button that
## would ever confirm or back out of it. So project.godot now carries an EXPLICIT override
## for those two (keyboard defaults preserved verbatim, plus south face button 0 for accept
## and east face button 1 for cancel) right next to `interact` -- see the comment there for
## the full story. `interact` (the button that OPENS this) is a real game verb and is
## declared in project.godot with the rest of them.
##
## --- THE WORLD HAS TO STOP WHILE IT IS UP, AND THIS FILE DOES NOT STOP IT ------------------
##
## game/actors/player/player.gd reads movement with Input.is_action_pressed() inside
## _physics_process, which does not go through the event system at all -- so consuming
## events here would NOT stop the player walking away while she reads the menu, and
## `ui_down` shares the down-arrow with `move_back`. Pausing the tree is what actually stops
## her, and it needs no changes to player.gd (which other people are editing this week).
##
## But this file only ANNOUNCES itself -- `opened` and `closed` -- and game/world/ranch.gd
## is what pauses, unpauses, and lets the mouse cursor go. Two reasons. Pausing the whole
## world is a policy decision about the game, not a property of a list of buildings, and the
## ranch is where every other such decision already lives (it is what decides that a gate
## run may not autosave). And a menu that reached for `get_tree().paused` itself would
## freeze the GUT runner the moment a headless test opened one, which would make the single
## most important thing about this menu -- that it is navigable without a mouse -- the one
## thing no test could check.
##
## This node still runs PROCESS_MODE_ALWAYS, so it is the thing still awake to read the
## input that closes it again.
##
## --- WHAT IT DOES NOT DO -------------------------------------------------------------------
##
## It does not build anything itself and it does not touch the wallet. It emits
## `plot_chosen(plot, slot)`; game/world/ranch.gd is what spends the bits and calls
## PlotSlot.build(). Keeping the transaction in one place is what stops "the menu charged
## you and the slot refused" from ever being reachable.

const PlotRegistryScript := preload("res://systems/plot_registry.gd")
const PlotDataScript := preload("res://systems/plot_data.gd")
const PlotSlotScript := preload("res://world/plot_slot.gd")
const MenuStyleScript := preload("res://ui/menu_style.gd")
const MouseRowsScript := preload("res://ui/mouse_rows.gd")

@onready var _dim: ColorRect = $Dim
@onready var _panel: PanelContainer = $Centre/Panel
@onready var _title: Label = $Centre/Panel/Margin/Column/Title
@onready var _wallet: Label = $Centre/Panel/Margin/Column/Wallet
@onready var _rows: VBoxContainer = $Centre/Panel/Margin/Column/Rows
@onready var _footer: Label = $Centre/Panel/Margin/Column/Footer

## The player picked a plot she can afford. The ranch pays for it and builds it.
signal plot_chosen(plot: PlotData, slot: PlotSlot)
## The menu came up on `slot`. game/world/ranch.gd pauses the world on this.
signal opened(slot: PlotSlot)
## The menu went away, for any reason -- chosen, cancelled, or refused.
signal closed()

## The catalogue. Loaded once, on _ready.
var _registry: PlotRegistry = null
var _plots: Array[PlotData] = []
var _row_nodes: Array[PanelContainer] = []

var _slot: PlotSlot = null
var _selected := 0
var _open := false

## Where the pointer is resting, or -1. Not the cursor: see game/ui/table_menu.gd's own
## comment on the same pair of fields.
var _hovered := -1
var _close: Button = null

## `func() -> int`, the current bits. Injected by game/world/ranch.gd rather than reached
## for through the GameState autoload, so this menu is testable with a two-line lambda and
## so Task 6's Economy can replace the source without this file changing.
var bits_provider := Callable()

## `func() -> bool`. Invalid means "always allowed".
##
## The same guard game/ui/pause_menu.gd and game/ui/market_menu.gd carry, and for the same
## two reasons. Every menu on this ranch pauses the tree on open and unpauses it on close,
## so a build menu opened over an already-open Market would unpause the world underneath it
## the moment it closed; and during the ranch's boot, before anything is wired, this says
## "not yet" rather than opening a menu whose `plot_chosen` nobody is listening for.
## game/world/ranch.gd sets it, being the thing that knows which other menus exist.
var can_open := Callable()


func _ready() -> void:
	# ALWAYS, because the ranch pauses the tree while this is up and this is the node that
	# has to keep running to read the input that closes it again. See the class comment.
	process_mode = Node.PROCESS_MODE_ALWAYS
	MenuStyleScript.apply_panel(_panel)
	_registry = PlotRegistryScript.new()
	_registry.load_all(PlotRegistryScript.PLOT_DIR)
	_plots = _registry.all()
	MenuStyleScript.style_label(_title, MenuStyleScript.TITLE_SIZE, MenuStyleScript.COLOR_TITLE)
	MenuStyleScript.style_label(_wallet, MenuStyleScript.ROW_SIZE, MenuStyleScript.COLOR_DIM)
	_title.text = "BUILD"
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_close = MouseRowsScript.close_button(MouseRowsScript.CLOSE_TEXT,
		func(_index: int) -> void: close())
	$Centre/Panel/Margin/Column.add_child(_close)
	_build_rows()
	visible = false


# --- opening and closing ------------------------------------------------------------------

## Show the menu for `slot`. Returns false (and shows nothing) for a null slot, a slot that
## already has something on it, an empty catalogue, or a `can_open` that refuses. All four
## are states where there is no decision to offer, and popping an empty panel would be worse
## than not popping one.
func open(slot: PlotSlot) -> bool:
	if slot == null or not slot.is_empty() or _plots.is_empty():
		return false
	if can_open.is_valid() and not bool(can_open.call()):
		return false
	_slot = slot
	_selected = 0
	_hovered = -1
	_open = true
	visible = true
	_refresh()
	opened.emit(slot)
	MenuStyleScript.tick_open()
	return true


func close() -> void:
	if not _open:
		return
	_open = false
	_hovered = -1
	_slot = null
	visible = false
	closed.emit()
	MenuStyleScript.tick_back()


func is_open() -> bool:
	return _open


## The slot this menu is open for, or null.
func get_slot() -> PlotSlot:
	return _slot


## The catalogue as drawn, cheapest first. For gates and tests.
func entries() -> Array[PlotData]:
	return _plots.duplicate()


func selected_index() -> int:
	return _selected


## The plot currently under the cursor, or null if the catalogue is empty.
func selected_plot() -> PlotData:
	if _selected < 0 or _selected >= _plots.size():
		return null
	return _plots[_selected]


## Bits the player has, via the injected provider. Zero if nothing was injected -- which
## makes an unwired menu show everything as unaffordable rather than let everything through
## for free.
func bits() -> int:
	if bits_provider.is_valid():
		return int(bits_provider.call())
	return 0


func can_afford(plot: PlotData) -> bool:
	return plot != null and bits() >= plot.cost


# --- input ---------------------------------------------------------------------------------

## Move the cursor by `step`, wrapping. WRAPPING RATHER THAN CLAMPING: on a gamepad, holding
## down past the last row and having nothing happen reads as the menu having frozen, and
## with three rows the wrap is never disorienting.
func move_selection(step: int) -> void:
	if _plots.is_empty():
		return
	_selected = posmod(_selected + step, _plots.size())
	_refresh()
	MenuStyleScript.tick_move()


## Try to build what is under the cursor. Returns false if it is unaffordable -- and says
## so, rather than closing, because a menu that shut itself when you pressed the button
## looks exactly like a menu that built something.
func confirm() -> bool:
	var plot := selected_plot()
	if plot == null or _slot == null:
		return false
	if not can_afford(plot):
		_footer.text = "  %s costs %d bits. You have %d." % [plot.display_name, plot.cost,
			bits()]
		MenuStyleScript.style_label(_footer, MenuStyleScript.FOOTER_SIZE,
			MenuStyleScript.COLOR_UNAFFORDABLE)
		return false
	var slot := _slot
	close()
	plot_chosen.emit(plot, slot)
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_down"):
		move_selection(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_up"):
		move_selection(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_accept"):
		confirm()
		get_viewport().set_input_as_handled()


# --- drawing ---------------------------------------------------------------------------------

## One PanelContainer per plot, built once on _ready. Rebuilding the rows on every open
## would throw away the selection highlight's styleboxes and reallocate a dozen Controls
## every time the player walks onto a plot.
func _build_rows() -> void:
	for child in _rows.get_children():
		child.queue_free()
	_row_nodes.clear()

	for i in _plots.size():
		var plot: PlotData = _plots[i]
		# ARMED ONCE, HERE, NOT IN _refresh(). MouseRows.arm() carries no double connect
		# guard; these nodes survive every refresh() this menu ever does (see the class
		# comment above), so arming them again on every repaint would stack a second
		# gui_input connection on top of the first and fire take_row() twice per click.
		var row := PanelContainer.new()
		row.name = "Row_%s" % String(plot.id)
		MouseRowsScript.arm(row, i, point_at_row, take_row)
		row.add_theme_stylebox_override(&"panel", MenuStyleScript.row_box(false))

		var margin := MarginContainer.new()
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_theme_constant_override(&"margin_left", 18)
		margin.add_theme_constant_override(&"margin_right", 18)
		margin.add_theme_constant_override(&"margin_top", 12)
		margin.add_theme_constant_override(&"margin_bottom", 12)
		row.add_child(margin)

		var column := VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_theme_constant_override(&"separation", 3)
		margin.add_child(column)

		var head := HBoxContainer.new()
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_theme_constant_override(&"separation", 24)
		column.add_child(head)

		var title := Label.new()
		title.name = "Name"
		title.text = plot.display_name
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		MenuStyleScript.style_label(title, 27, MenuStyleScript.COLOR_NAME)
		head.add_child(title)

		var holds := Label.new()
		holds.name = "Holds"
		holds.text = ("holds %d" % plot.capacity) if plot.capacity > 0 else ""
		holds.mouse_filter = Control.MOUSE_FILTER_IGNORE
		MenuStyleScript.style_label(holds, 21, MenuStyleScript.COLOR_DIM)
		head.add_child(holds)

		var price := Label.new()
		price.name = "Cost"
		price.text = "FREE" if plot.cost == 0 else "%d bits" % plot.cost
		price.mouse_filter = Control.MOUSE_FILTER_IGNORE
		MenuStyleScript.style_label(price, 24, MenuStyleScript.COLOR_VALUE)
		head.add_child(price)

		var blurb := Label.new()
		blurb.name = "Description"
		blurb.text = plot.description
		blurb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		blurb.custom_minimum_size = Vector2(720.0, 0.0)
		MenuStyleScript.style_label(blurb, 19, MenuStyleScript.COLOR_DIM)
		column.add_child(blurb)

		_rows.add_child(row)
		_row_nodes.append(row)


## Repaint the selection highlight, the wallet line and the affordability colours.
func _refresh() -> void:
	_footer.text = MenuStyleScript.footer_rows("build", "back")
	MenuStyleScript.style_label(_footer, MenuStyleScript.FOOTER_SIZE, MenuStyleScript.COLOR_DIM)
	_wallet.text = "%d bits" % bits()
	for i in range(_row_nodes.size()):
		var row := _row_nodes[i]
		# THE STYLEBOX ONLY, NEVER MouseRows.row() AGAIN HERE. .row() would hand back a new
		# PanelContainer and arm it a second time; these rows are armed once, in
		# _build_rows(), and this repaints the same three states row(): picked, hovered,
		# idle -- MouseRows.row() computes internally.
		var picked: bool = i == _selected
		var box: StyleBoxFlat = MenuStyleScript.row_box(true) if picked \
			else (MenuStyleScript.row_box_hover() if i == _hovered else MenuStyleScript.row_box(false))
		row.add_theme_stylebox_override(&"panel", box)
		var affordable := can_afford(_plots[i])
		var price := row.find_child("Cost", true, false) as Label
		if price != null:
			MenuStyleScript.style_label(price, 24,
				MenuStyleScript.COLOR_VALUE if affordable else MenuStyleScript.COLOR_UNAFFORDABLE)
		var title := row.find_child("Name", true, false) as Label
		if title != null:
			MenuStyleScript.style_label(title, 27,
				MenuStyleScript.COLOR_NAME if affordable else MenuStyleScript.COLOR_DIM)


# --- the pointer ----------------------------------------------------------------------------


func hovered_index() -> int:
	return _hovered


func close_button_node() -> Button:
	return _close


## ONE CURSOR, TWO WAYS TO MOVE IT. Absolute where move_selection() is relative, and it makes
## the same sound, because both are the player choosing a row.
func point_at_row(index: int) -> void:
	if index < 0 or index >= _plots.size():
		return
	if index == _selected and index == _hovered:
		return
	_hovered = index
	if index != _selected:
		_selected = index
		MenuStyleScript.tick_move()
	_refresh()


func take_row(index: int) -> void:
	point_at_row(index)
	if _selected == index:
		confirm()
