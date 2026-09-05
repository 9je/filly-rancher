class_name SwatchGrid
extends GridContainer
## THE ROW OF BIG SWATCHES THAT REPLACED THE TINY ARROWS. The owner, on the first full
## playtest: the creation screen is "not industry standard". The `<` and `>` steppers are the
## thing she meant. Every character creator worth the name shows the whole palette at once
## and lets a pointer land on the colour it wants.
##
## ONE WIDGET, TWO SHAPES. With no labels it is a grid of colour swatches (coat, mane, eyes);
## with labels it is a grid of cards (mane style). Two widgets that differed by whether a
## Button carried text would be one widget with extra steps.
##
## NOTHING HERE TAKES KEYBOARD FOCUS. game/ui/creation_screen.gd runs its own cursor over
## these rows, exactly as every menu in this game does, and a focusable Button would take the
## arrow keys off it. The mouse is added; the keyboard is not traded.
##
## NO RANDOMNESS ANYWHERE. game/test/test_menu_sound.gd sweeps game/ui/ for a generator and
## this file has none: the order of the cells is the order of the palette it was handed.

const MenuStyleScript := preload("res://ui/menu_style.gd")

signal picked(index: int)

## In 1920x1080 base pixels, the size the project's canvas_items stretch is measured against.
## 56, not 72: C1's fix. The LOOK step's four grids stacked at 72 with 6 columns put the
## column at 1281 px in a 1080 px viewport (final-review.md, C1); 56 with 8 columns (4 for
## the mane-style cards) is the cheapest correct change that keeps every cell a real click
## target and brings the whole column back inside the base viewport.
const CELL_SIZE := Vector2(56.0, 56.0)
const CARD_SIZE := Vector2(168.0, 96.0)

const CELL_RADIUS := 8
const IDLE_BORDER := 2
const CHOSEN_BORDER := 5
const CURSOR_BORDER := 4

const DEFAULT_COLUMNS := 6

var _colours: Array[Color] = []
var _labels: Array[String] = []
var _cells: Array[Button] = []
var _selected := 0

## THE KEYBOARD CURSOR, SEPARATE FROM THE PICK. -1 when nothing outside a mouse is pointing
## at this grid. creation_screen.gd's own cursor sets this as she moves the highlight with
## the arrow keys; it is not the chosen swatch (_selected) until Enter says so.
var _highlighted := -1


func _ready() -> void:
	if columns <= 0:
		columns = DEFAULT_COLUMNS


## Rebuild the grid on `colours`. `labels` is either empty (bare swatches) or the same length
## as `colours` (cards). A mismatched length is treated as empty rather than as an error: a
## palette and a label list of different sizes is a caller bug, and a half labelled grid is a
## worse way to find out about it than an unlabelled one.
func set_swatches(colours: Array[Color], labels: Array[String]) -> void:
	_colours = colours.duplicate()
	# NOT A TERNARY: GDScript 4.5's ternary operator drops the element type off both
	# branches even when they agree, so the assignment below sees a bare Array where the
	# declared type is Array[String] and refuses it at runtime.
	if labels.size() == colours.size():
		_labels = labels.duplicate()
	else:
		_labels = [] as Array[String]
	for child in get_children():
		remove_child(child)
		# free(), NOT queue_free(). A rebuilt grid's old Buttons are never referenced again
		# the instant they leave _cells below, and a deferred free left them as orphans GUT
		# still counted at the end of a synchronous test (test_swatch_grid.gd's own rebuild
		# test): freeing the moment they are detached is the same node lifetime with no gap
		# for a test's assertions to run inside.
		child.free()
	_cells = []
	for i in _colours.size():
		var cell := Button.new()
		cell.focus_mode = Control.FOCUS_NONE
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		cell.custom_minimum_size = CARD_SIZE if not _labels.is_empty() else CELL_SIZE
		cell.text = _labels[i] if not _labels.is_empty() else ""
		cell.clip_text = true
		var index := i
		# M12, final-review.md M4: THE STANDARD MenuStyle TICK. Every other screen's rows
		# tick on the gesture that picks them; this grid was the one silent exception. Not
		# tick_confirm(): a click here is a pick within a screen still open, the tier
		# set_step()'s own tick_page() call is already in -- move_highlight()'s own tick, not
		# activate_highlight()'s.
		cell.pressed.connect(func() -> void:
			MenuStyleScript.tick_move()
			picked.emit(index))
		_cells.append(cell)
		add_child(cell)
	_restyle()


func cell_count() -> int:
	return _cells.size()


func cell(index: int) -> Button:
	if index < 0 or index >= _cells.size():
		return null
	return _cells[index]


## Which cell is chosen. Wraps, exactly as StockPalette's own rows do and for the same
## reason: an off by one in a caller produces the wrong swatch rather than a read off the end.
func set_selected(index: int) -> void:
	if _colours.is_empty():
		_selected = 0
		return
	_selected = posmod(index, _colours.size())
	_restyle()


func selected() -> int:
	return _selected


## THE KEYBOARD CURSOR. Set by creation_screen.gd as its own _unhandled_input moves the
## highlight across whichever grid is the active region; -1 clears it (leaving the tree, or
## another region taking the cursor). Wraps like set_selected() when the grid is not empty,
## so a caller's off-by-one lands on a real cell rather than reading off the end.
func set_highlighted(index: int) -> void:
	_highlighted = -1 if (index < 0 or _colours.is_empty()) else posmod(index, _colours.size())
	_restyle()


func highlighted() -> int:
	return _highlighted


## THE SWATCH IS ITS OWN COLOUR IN EVERY STATE, and the STATE is the border. A hover that
## changed the fill would change the colour the player is trying to judge, which is the one
## thing a swatch may never do.
##
## THREE TIERS OF BORDER, WIDEST WINS. Chosen (CHOSEN_BORDER, gold) is what she picked;
## cursor (CURSOR_BORDER, the same hover gold at one tier down) is only where the keyboard
## is pointing right now and says nothing about what she picked; idle is everything else. A
## cell can be both at once (the cursor usually starts on the current pick), and chosen
## always wins the width so pressing an arrow key never reads as "she changed her coat".
func _restyle() -> void:
	for i in _cells.size():
		var chosen: bool = i == _selected
		var cursor: bool = i == _highlighted
		for state: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
			var box := StyleBoxFlat.new()
			box.bg_color = _colours[i]
			box.set_corner_radius_all(CELL_RADIUS)
			var border: int = IDLE_BORDER
			if chosen:
				border = CHOSEN_BORDER
			elif cursor:
				border = CURSOR_BORDER
			if state == &"hover" or state == &"pressed":
				border = maxi(border, CHOSEN_BORDER - 1)
			box.set_border_width_all(border)
			box.border_color = MenuStyleScript.COLOR_TAB_ON if chosen \
				else (MenuStyleScript.COLOR_HOVER_BORDER if (cursor or state == &"hover") \
					else MenuStyleScript.ROW_IDLE_BORDER)
			_cells[i].add_theme_stylebox_override(state, box)
		MenuStyleScript.style_label_button(_cells[i])
