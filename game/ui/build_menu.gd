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

## Colours, matching game/ui/hud.gd's palette rather than inventing a second one.
const COLOR_TITLE := Color(1.0, 0.96, 0.86, 1.0)
const COLOR_NAME := Color(1.0, 1.0, 1.0, 0.94)
const COLOR_DIM := Color(1.0, 1.0, 1.0, 0.58)
const COLOR_COST := Color(1.00, 0.80, 0.25, 1.0)
## An unaffordable row is drawn in this instead of being hidden: seeing what you are saving
## up for is most of what makes saving up for it interesting.
const COLOR_UNAFFORDABLE := Color(1.0, 0.45, 0.42, 0.85)

const ROW_SELECTED_BG := Color(1.0, 0.86, 0.55, 0.16)
const ROW_SELECTED_BORDER := Color(1.0, 0.86, 0.55, 0.75)
const ROW_IDLE_BG := Color(1.0, 1.0, 1.0, 0.04)
const ROW_IDLE_BORDER := Color(1.0, 1.0, 1.0, 0.10)

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

## `func() -> int`, the current bits. Injected by game/world/ranch.gd rather than reached
## for through the GameState autoload, so this menu is testable with a two-line lambda and
## so Task 6's Economy can replace the source without this file changing.
var bits_provider := Callable()


func _ready() -> void:
	# ALWAYS, because the ranch pauses the tree while this is up and this is the node that
	# has to keep running to read the input that closes it again. See the class comment.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_registry = PlotRegistryScript.new()
	_registry.load_all(PlotRegistryScript.PLOT_DIR)
	_plots = _registry.all()
	_style_label(_title, 34, COLOR_TITLE)
	_style_label(_wallet, 22, COLOR_DIM)
	_style_label(_footer, 20, COLOR_DIM)
	_title.text = "BUILD"
	_footer.text = "  ↑ ↓ / D-pad  choose      Enter / A  build      Esc / B  back"
	_build_rows()
	visible = false


# --- opening and closing ------------------------------------------------------------------

## Show the menu for `slot`. Returns false (and shows nothing) for a null slot, a slot that
## already has something on it, or an empty catalogue -- all three are states where there
## is no decision to offer, and popping an empty panel would be worse than not popping one.
func open(slot: PlotSlot) -> bool:
	if slot == null or not slot.is_empty() or _plots.is_empty():
		return false
	_slot = slot
	_selected = 0
	_open = true
	visible = true
	_refresh()
	opened.emit(slot)
	return true


func close() -> void:
	if not _open:
		return
	_open = false
	_slot = null
	visible = false
	closed.emit()


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


## Try to build what is under the cursor. Returns false if it is unaffordable -- and says
## so, rather than closing, because a menu that shut itself when you pressed the button
## looks exactly like a menu that built something.
func confirm() -> bool:
	var plot := selected_plot()
	if plot == null or _slot == null:
		return false
	if not can_afford(plot):
		_footer.text = "  %s costs %d bits -- you have %d." % [plot.display_name, plot.cost,
			bits()]
		_style_label(_footer, 20, COLOR_UNAFFORDABLE)
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

	for plot in _plots:
		var row := PanelContainer.new()
		row.name = "Row_%s" % String(plot.id)
		row.add_theme_stylebox_override(&"panel", _row_style(false))

		var margin := MarginContainer.new()
		margin.add_theme_constant_override(&"margin_left", 18)
		margin.add_theme_constant_override(&"margin_right", 18)
		margin.add_theme_constant_override(&"margin_top", 12)
		margin.add_theme_constant_override(&"margin_bottom", 12)
		row.add_child(margin)

		var column := VBoxContainer.new()
		column.add_theme_constant_override(&"separation", 3)
		margin.add_child(column)

		var head := HBoxContainer.new()
		head.add_theme_constant_override(&"separation", 24)
		column.add_child(head)

		var title := Label.new()
		title.name = "Name"
		title.text = plot.display_name
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_label(title, 27, COLOR_NAME)
		head.add_child(title)

		var holds := Label.new()
		holds.name = "Holds"
		holds.text = ("holds %d" % plot.capacity) if plot.capacity > 0 else ""
		_style_label(holds, 21, COLOR_DIM)
		head.add_child(holds)

		var price := Label.new()
		price.name = "Cost"
		price.text = "FREE" if plot.cost == 0 else "%d bits" % plot.cost
		_style_label(price, 24, COLOR_COST)
		head.add_child(price)

		var blurb := Label.new()
		blurb.name = "Description"
		blurb.text = plot.description
		blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		blurb.custom_minimum_size = Vector2(720.0, 0.0)
		_style_label(blurb, 19, COLOR_DIM)
		column.add_child(blurb)

		_rows.add_child(row)
		_row_nodes.append(row)


## Repaint the selection highlight, the wallet line and the affordability colours.
func _refresh() -> void:
	_wallet.text = "%d bits" % bits()
	_style_label(_footer, 20, COLOR_DIM)
	_footer.text = "  ↑ ↓ / D-pad  choose      Enter / A  build      Esc / B  back"
	for i in range(_row_nodes.size()):
		var row := _row_nodes[i]
		row.add_theme_stylebox_override(&"panel", _row_style(i == _selected))
		var affordable := can_afford(_plots[i])
		var price := row.find_child("Cost", true, false) as Label
		if price != null:
			_style_label(price, 24, COLOR_COST if affordable else COLOR_UNAFFORDABLE)
		var title := row.find_child("Name", true, false) as Label
		if title != null:
			_style_label(title, 27, COLOR_NAME if affordable else COLOR_DIM)


func _row_style(selected: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = ROW_SELECTED_BG if selected else ROW_IDLE_BG
	box.border_color = ROW_SELECTED_BORDER if selected else ROW_IDLE_BORDER
	box.set_border_width_all(2 if selected else 1)
	box.set_corner_radius_all(8)
	box.content_margin_left = 0.0
	return box


## Same treatment game/ui/hud.gd gives its labels, and for the same reason: this panel is
## translucent over a bright green field, and unoutlined text on it is genuinely hard to
## read.
func _style_label(label: Label, size: int, color: Color) -> void:
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.75))
	label.add_theme_constant_override(&"outline_size", 5)
