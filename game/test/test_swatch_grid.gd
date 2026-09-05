extends GutTest
## THE SWATCH GRID. The owner, on the old creation screen: "not industry standard ... for
## character creation". The tiny prev/next steppers are what she meant; this is what replaces
## them, and it is one widget used three times for colour and once for mane style cards.

const SwatchGridScript := preload("res://ui/swatch_grid.gd")

var _picked: Array[int] = []


func before_each() -> void:
	_picked = []


func _on_picked(index: int) -> void:
	_picked.append(index)


func _grid(colours: Array[Color], labels: Array[String] = [] as Array[String]) -> SwatchGrid:
	var grid: SwatchGrid = SwatchGridScript.new()
	add_child_autofree(grid)
	grid.picked.connect(_on_picked)
	grid.set_swatches(colours, labels)
	return grid


func test_a_grid_builds_one_cell_per_colour() -> void:
	var grid: SwatchGrid = _grid([Color.RED, Color.GREEN, Color.BLUE])
	assert_eq(grid.cell_count(), 3)
	for i in 3:
		assert_not_null(grid.cell(i), "cell %d" % i)
	assert_null(grid.cell(3), "out of range is null, not a crash")


func test_a_cell_is_a_real_button_that_never_takes_keyboard_focus() -> void:
	var grid: SwatchGrid = _grid([Color.RED, Color.GREEN])
	assert_eq(grid.cell(0).focus_mode, Control.FOCUS_NONE,
		"the arrow keys belong to the creation screen's own cursor")


func test_clicking_a_cell_emits_its_index() -> void:
	var grid: SwatchGrid = _grid([Color.RED, Color.GREEN, Color.BLUE])
	grid.cell(2).pressed.emit()
	assert_eq(_picked, [2] as Array[int])


func test_the_selected_cell_is_outlined_and_the_others_are_not() -> void:
	var grid: SwatchGrid = _grid([Color.RED, Color.GREEN, Color.BLUE])
	grid.set_selected(1)
	assert_eq(grid.selected(), 1)
	var chosen: StyleBoxFlat = grid.cell(1).get_theme_stylebox(&"normal") as StyleBoxFlat
	var other: StyleBoxFlat = grid.cell(0).get_theme_stylebox(&"normal") as StyleBoxFlat
	assert_gt(chosen.border_width_top, other.border_width_top,
		"a selected swatch has to be visibly selected")


func test_a_cell_carries_the_colour_it_stands_for() -> void:
	var grid: SwatchGrid = _grid([Color(0.2, 0.4, 0.6), Color(0.9, 0.1, 0.1)])
	var box: StyleBoxFlat = grid.cell(0).get_theme_stylebox(&"normal") as StyleBoxFlat
	assert_eq(box.bg_color, Color(0.2, 0.4, 0.6),
		"a swatch that does not show its colour is a grey square")


func test_labels_turn_the_grid_into_cards_and_the_labels_are_the_button_text() -> void:
	var grid: SwatchGrid = _grid([Color.RED, Color.GREEN],
		["Straight", "Curly"] as Array[String])
	assert_eq(grid.cell(0).text, "Straight")
	assert_eq(grid.cell(1).text, "Curly")
	assert_eq(grid.cell(0).custom_minimum_size, SwatchGridScript.CARD_SIZE)


func test_a_bare_grid_uses_the_swatch_size_and_carries_no_text() -> void:
	var grid: SwatchGrid = _grid([Color.RED])
	assert_eq(grid.cell(0).text, "")
	assert_eq(grid.cell(0).custom_minimum_size, SwatchGridScript.CELL_SIZE)


func test_rebuilding_a_grid_replaces_its_cells_rather_than_stacking_them() -> void:
	var grid: SwatchGrid = _grid([Color.RED, Color.GREEN, Color.BLUE])
	grid.set_swatches([Color.BLACK] as Array[Color], [] as Array[String])
	assert_eq(grid.cell_count(), 1, "a rebuilt grid is the new grid, not both")


func test_a_selection_out_of_range_wraps_rather_than_reading_off_the_end() -> void:
	var grid: SwatchGrid = _grid([Color.RED, Color.GREEN, Color.BLUE])
	grid.set_selected(4)
	assert_eq(grid.selected(), 1, "the palettes wrap and so does this")
	grid.set_selected(-1)
	assert_eq(grid.selected(), 2)


func test_an_empty_grid_is_empty_and_not_an_error() -> void:
	var grid: SwatchGrid = _grid([] as Array[Color])
	assert_eq(grid.cell_count(), 0)
	assert_eq(grid.selected(), 0)
