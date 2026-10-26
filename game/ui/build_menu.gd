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
const TileStyleScript := preload("res://ui/tile_style.gd")
const ShopIconScript := preload("res://ui/shop_icon.gd")
## The picture on a tile (overnight bot review, 2026-10-26: the build card was the old dark
## text row). A fence the size of the pen, or the upgrade's arrow, or the clearing's shears.
const ICON_SIZE := 64.0

@onready var _dim: ColorRect = $Dim
@onready var _panel: PanelContainer = $Centre/Panel
@onready var _title: Label = $Centre/Panel/Margin/Column/Title
@onready var _wallet: Label = $Centre/Panel/Margin/Column/Wallet
@onready var _rows: VBoxContainer = $Centre/Panel/Margin/Column/Rows
@onready var _footer: Label = $Centre/Panel/Margin/Column/Footer

## The player picked a plot she can afford. The ranch pays for it and builds it.
signal plot_chosen(plot: PlotData, slot: PlotSlot)
## The player took the upgrade card on a built pen. The ranch pays `price` and grows it.
signal upgrade_chosen(plot: PlotData, slot: PlotSlot, price: int)
## The player took the clearing card on an overgrown plot. The ranch pays and clears it.
signal clear_chosen(slot: PlotSlot, price: int)
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

## WHAT THIS PANEL IS OFFERING. The same panel, the same rows and the same keys serve three
## questions a plot can ask (owner playtest 2026-10-25, "how do i upgrade my free paddock to
## the 150 bits one not clear"): what to build on an empty plot (the catalogue), what a
## built pen can grow into (one UPGRADE card), and what clearing an overgrown plot costs (one
## CLEAR card). One panel, so a player who has learned to build has already learned to
## upgrade.
enum Mode { BUILD, UPGRADE, CLEAR }
var _mode: int = Mode.BUILD
## The rows as drawn: {"plot": PlotData or null, "name", "holds", "price", "blurb"}.
var _offers: Array[Dictionary] = []

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
	_offers = _catalogue_offers()
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
	if slot == null or not slot.is_empty() or slot.is_overgrown() or _plots.is_empty():
		return false
	if can_open.is_valid() and not bool(can_open.call()):
		return false
	_set_mode(Mode.BUILD, _catalogue_offers(), "BUILD")
	return _show(slot)


## THE UPGRADE CARD. One row: what this pen becomes, how many it will hold against how many
## it holds now, and the price. Refuses (and shows nothing) on a slot with nothing built, a
## null `to`, or a `can_open` that says no.
func open_upgrade(slot: PlotSlot, from: PlotData, to: PlotData, price: int) -> bool:
	if slot == null or slot.is_empty() or to == null:
		return false
	if can_open.is_valid() and not bool(can_open.call()):
		return false
	var now := from.capacity if from != null else 0
	_set_mode(Mode.UPGRADE, [{"plot": to, "name": "%s" % to.display_name,
		"holds": "holds %d, now %d" % [to.capacity, now], "price": maxi(0, price),
		"blurb": "Everyone living here stays put. %s" % to.description}], "UPGRADE")
	return _show(slot)


## THE CLEARING CARD. One row: the brambles, and what it costs to have them gone.
func open_clear(slot: PlotSlot, price: int) -> bool:
	if slot == null or not slot.is_overgrown():
		return false
	if can_open.is_valid() and not bool(can_open.call()):
		return false
	_set_mode(Mode.CLEAR, [{"plot": null, "name": "Clear the brambles", "holds": "",
		"price": maxi(0, price),
		"blurb": "Hack the thicket back to bare ground. Then it is a plot like any other, " +
			"and a Paddock on it is free."}], "CLEAR THE PLOT")
	return _show(slot)


func mode() -> int:
	return _mode


func _set_mode(m: int, offers: Array, title: String) -> void:
	var typed: Array[Dictionary] = []
	for o in offers:
		typed.append(o)
	var same := m == _mode and m == Mode.BUILD and _row_nodes.size() == typed.size()
	_mode = m
	_offers = typed
	_title.text = title
	if not same:
		_build_rows()


func _catalogue_offers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for plot in _plots:
		out.append({"plot": plot, "name": plot.display_name,
			"holds": ("holds %d" % plot.capacity) if plot.capacity > 0 else "",
			"price": plot.cost, "blurb": plot.description})
	return out


func _show(slot: PlotSlot) -> bool:
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


## The catalogue as drawn, cheapest first. For gates and tests. In the UPGRADE mode it is
## the one plot on offer; in CLEAR, nothing.
func entries() -> Array[PlotData]:
	if _mode == Mode.BUILD:
		return _plots.duplicate()
	var out: Array[PlotData] = []
	for o in _offers:
		if o.get("plot") != null:
			out.append(o["plot"])
	return out


## The price on row `index`, as drawn.
func price_at(index: int) -> int:
	if index < 0 or index >= _offers.size():
		return 0
	return int(_offers[index].get("price", 0))


## The row nodes, for a real-input test that clicks one.
func row_nodes() -> Array[PanelContainer]:
	return _row_nodes.duplicate()


func selected_index() -> int:
	return _selected


## The plot currently under the cursor, or null if the catalogue is empty.
func selected_plot() -> PlotData:
	if _selected < 0 or _selected >= _offers.size():
		return null
	return _offers[_selected].get("plot") as PlotData


## Bits the player has, via the injected provider. Zero if nothing was injected -- which
## makes an unwired menu show everything as unaffordable rather than let everything through
## for free.
func bits() -> int:
	if bits_provider.is_valid():
		return int(bits_provider.call())
	return 0


func can_afford(plot: PlotData) -> bool:
	return plot != null and bits() >= plot.cost


func _can_afford_row(index: int) -> bool:
	return bits() >= price_at(index)


# --- input ---------------------------------------------------------------------------------

## Move the cursor by `step`, wrapping. WRAPPING RATHER THAN CLAMPING: on a gamepad, holding
## down past the last row and having nothing happen reads as the menu having frozen, and
## with three rows the wrap is never disorienting.
func move_selection(step: int) -> void:
	if _offers.is_empty():
		return
	_selected = posmod(_selected + step, _offers.size())
	_refresh()
	MenuStyleScript.tick_move()


## Try to build what is under the cursor. Returns false if it is unaffordable -- and says
## so, rather than closing, because a menu that shut itself when you pressed the button
## looks exactly like a menu that built something.
func confirm() -> bool:
	if _slot == null or _selected < 0 or _selected >= _offers.size():
		return false
	var plot := selected_plot()
	if _mode != Mode.CLEAR and plot == null:
		return false
	var price := price_at(_selected)
	if not _can_afford_row(_selected):
		_footer.text = "  Not enough bits yet: %d needed, you have %d." % [price, bits()]
		MenuStyleScript.style_label(_footer, MenuStyleScript.FOOTER_SIZE,
			MenuStyleScript.COLOR_UNAFFORDABLE)
		MenuStyleScript.tick_back()
		return false
	var slot := _slot
	var mode_was := _mode
	close()
	match mode_was:
		Mode.UPGRADE:
			upgrade_chosen.emit(plot, slot, price)
		Mode.CLEAR:
			clear_chosen.emit(slot, price)
		_:
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
		# Out of the column first: a mode switch rebuilds the rows while the panel is up,
		# and a row only queued for deletion would be laid out beside its replacement.
		_rows.remove_child(child)
		child.queue_free()
	_row_nodes.clear()

	for i in _offers.size():
		var offer: Dictionary = _offers[i]
		# ARMED ONCE, HERE, NOT IN _refresh(). MouseRows.arm() carries no double connect
		# guard; these nodes survive every refresh() this menu ever does (see the class
		# comment above), so arming them again on every repaint would stack a second
		# gui_input connection on top of the first and fire take_row() twice per click.
		var row := PanelContainer.new()
		var plot := offer.get("plot") as PlotData
		row.name = "Row_%s" % (String(plot.id) if plot != null else "clear")
		MouseRowsScript.arm(row, i, point_at_row, take_row)
		row.add_theme_stylebox_override(&"panel", TileStyleScript.box(false, false))

		# The picture beside the words, in a grid of two so the name line stays the tile's
		# first HBoxContainer.
		var body := GridContainer.new()
		body.columns = 2
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_theme_constant_override(&"h_separation", 16)
		row.add_child(body)
		var plate := TileStyleScript.disc(ICON_SIZE)
		body.add_child(plate)
		var icon: Control = ShopIconScript.new()
		icon.name = "Icon"
		icon.kind = (&"upgrade" if _mode == Mode.UPGRADE else plot.id) if plot != null else &"clear"
		icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.add_child(icon)

		var column := VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override(&"separation", 3)
		body.add_child(column)

		var head := HBoxContainer.new()
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_theme_constant_override(&"separation", 24)
		column.add_child(head)

		var title := Label.new()
		title.name = "Name"
		title.text = String(offer.get("name", ""))
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		MenuStyleScript.style_label(title, 27, MenuStyleScript.COLOR_TITLE)
		title.add_theme_font_override(&"font", MenuStyleScript.title_font())
		head.add_child(title)

		var holds := Label.new()
		holds.name = "Holds"
		holds.text = String(offer.get("holds", ""))
		holds.mouse_filter = Control.MOUSE_FILTER_IGNORE
		MenuStyleScript.style_label(holds, 21, MenuStyleScript.COLOR_DIM)
		head.add_child(holds)

		var price := Label.new()
		price.name = "Cost"
		var cost := int(offer.get("price", 0))
		price.text = "FREE" if cost == 0 else "%d bits" % cost
		price.mouse_filter = Control.MOUSE_FILTER_IGNORE
		MenuStyleScript.style_label(price, 24, MenuStyleScript.COLOR_VALUE)
		head.add_child(price)

		var blurb := Label.new()
		blurb.name = "Description"
		blurb.text = String(offer.get("blurb", ""))
		blurb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		blurb.custom_minimum_size = Vector2(640.0, 0.0)
		MenuStyleScript.style_label(blurb, 19, MenuStyleScript.COLOR_DIM)
		column.add_child(blurb)

		# NOT ENOUGH BITS, SAID ON THE CARD ITSELF and not only after a refused press: a
		# red line under the price that is shown by _refresh() while she is short.
		var short := Label.new()
		short.name = "Short"
		short.mouse_filter = Control.MOUSE_FILTER_IGNORE
		short.visible = false
		MenuStyleScript.style_label(short, 20, MenuStyleScript.COLOR_UNAFFORDABLE)
		column.add_child(short)

		_rows.add_child(row)
		_row_nodes.append(row)


## Repaint the selection highlight, the wallet line and the affordability colours.
func _refresh() -> void:
	_footer.text = MenuStyleScript.footer_rows(["build", "upgrade", "clear"][_mode], "back")
	MenuStyleScript.style_label(_footer, MenuStyleScript.FOOTER_SIZE, MenuStyleScript.COLOR_DIM)
	_wallet.text = "%d bits" % bits()
	for i in range(_row_nodes.size()):
		var row := _row_nodes[i]
		# THE STYLEBOX ONLY, NEVER MouseRows.row() AGAIN HERE. .row() would hand back a new
		# PanelContainer and arm it a second time; these rows are armed once, in
		# _build_rows(), and this repaints the same three states row(): picked, hovered,
		# idle -- MouseRows.row() computes internally.
		var picked: bool = i == _selected
		row.add_theme_stylebox_override(&"panel", TileStyleScript.box(picked, i == _hovered))
		var affordable := _can_afford_row(i)
		var short := row.find_child("Short", true, false) as Label
		if short != null:
			short.visible = not affordable
			short.text = "Not enough bits: you need %d more." % (price_at(i) - bits())
		var price := row.find_child("Cost", true, false) as Label
		if price != null:
			MenuStyleScript.style_label(price, 24,
				MenuStyleScript.COLOR_VALUE if affordable else MenuStyleScript.COLOR_UNAFFORDABLE)
		var title := row.find_child("Name", true, false) as Label
		if title != null:
			MenuStyleScript.style_label(title, 27,
				MenuStyleScript.COLOR_TITLE if affordable else MenuStyleScript.COLOR_DIM)


# --- the pointer ----------------------------------------------------------------------------


func hovered_index() -> int:
	return _hovered


func close_button_node() -> Button:
	return _close


## ONE CURSOR, TWO WAYS TO MOVE IT. Absolute where move_selection() is relative, and it makes
## the same sound, because both are the player choosing a row.
func point_at_row(index: int) -> void:
	if index < 0 or index >= _offers.size():
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
