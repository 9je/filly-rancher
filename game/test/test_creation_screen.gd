extends GutTest
## The creation screen, driven through its own methods rather than through a mouse.

const CreationScreenScene := preload("res://ui/creation_screen.tscn")
const PlayerLookScript := preload("res://systems/player_look.gd")
const StockPaletteScript := preload("res://systems/stock_palette.gd")
const MarkPaintScript := preload("res://systems/mark_paint.gd")
const MarkStampsScript := preload("res://systems/mark_stamps.gd")

var _screen: CreationScreen = null


func before_each() -> void:
	_screen = CreationScreenScene.instantiate()
	add_child_autofree(_screen)
	_screen.open(PlayerLookScript.default_look())


func after_each() -> void:
	get_tree().paused = false


func test_it_opens_on_the_default_look() -> void:
	assert_true(_screen.is_open())
	assert_eq(_screen.look().player_name, PlayerLookScript.DEFAULT_NAME)


func test_cycling_a_swatch_row_wraps_and_stays_in_range() -> void:
	var palette: StockPalette = StockPaletteScript.load_player()
	for i in palette.coats.size() + 3:
		_screen.cycle_coat(1)
		assert_between(_screen.look().coat, 0, palette.coats.size() - 1)
	_screen.cycle_coat(-1)
	assert_between(_screen.look().coat, 0, palette.coats.size() - 1)


func test_every_row_can_be_cycled_independently() -> void:
	_screen.cycle_coat(1)
	_screen.cycle_mane(2)
	_screen.cycle_eyes(3)
	var look: PlayerLook = _screen.look()
	assert_ne(look.coat, look.mane, "three rows, three choices")


func test_a_typed_name_is_sanitised_into_the_look() -> void:
	_screen.set_name_text("  Moon--beam  ")
	assert_eq(_screen.look().player_name, "Moonbeam")


func test_a_drawn_mark_reaches_the_look_on_confirm() -> void:
	_screen.canvas().set_colour(Color(0.2, 0.6, 0.9))
	_screen.canvas().stamp(MarkStampsScript.Stamp.GEM)
	watch_signals(_screen)
	assert_true(_screen.confirm())
	assert_signal_emitted(_screen, "confirmed")
	var look: PlayerLook = _screen.look()
	assert_true(look.has_mark())
	assert_true(MarkPaintScript.equal(look.mark(), _screen.canvas().image()))


func test_confirming_closes_the_screen_and_unpauses_the_world() -> void:
	_screen.confirm()
	assert_false(_screen.is_open())
	assert_false(get_tree().paused)


func test_confirming_twice_emits_once() -> void:
	watch_signals(_screen)
	assert_true(_screen.confirm())
	assert_false(_screen.confirm())
	assert_signal_emit_count(_screen, "confirmed", 1)


func test_the_turntable_holds_a_tinted_pony() -> void:
	if _screen.model() == null:
		pass_test("no converted assets on this machine")
		return
	_screen.cycle_coat(2)
	var palette: StockPalette = StockPaletteScript.load_player()
	assert_eq(StockTint.override_of(_screen.model(), &"body").albedo_color,
		palette.coat_at(_screen.look().coat),
		"the swatch she picked is the colour standing on the turntable")


func test_nothing_the_screen_draws_carries_a_dash() -> void:
	for line in _screen.drawn_lines():
		assert_false(line.contains("--"), "'%s' carries a double hyphen" % line)
		assert_false(line.contains(char(0x2014)), "'%s' carries an em dash" % line)


# --- the ink row --------------------------------------------------------------------------
##
## THE GAP THESE PIN. MarkCanvas.set_colour() shipped with the canvas and nothing ever
## called it, so every cutie mark in the game came out the one hard coded grey the widget
## opens on. The screen now has a row of ink buttons over it, and what matters is that
## PRESSING ONE reaches the canvas: an ink row that changes a swatch and not the ink is the
## same bug with a nicer face on it.

## The first non transparent pixel in `image`, or EMPTY if she drew nothing. Read this way
## rather than at a fixed coordinate because a headless Control has no layout, so the canvas
## maps every local point to the same pixel; WHERE the ink landed is not what is under test
## here, WHICH ink landed is.
func _first_ink(image: Image) -> Color:
	for y in image.get_height():
		for x in image.get_width():
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a > 0.0:
				return pixel
	return MarkPaintScript.EMPTY


## An 8-bit-per-channel image cannot store a float colour exactly, so this is the tolerance
## a round trip through Image.set_pixel/get_pixel actually needs (1/255 is about 0.004).
func _same_colour(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01


func test_the_screen_offers_a_row_of_inks() -> void:
	assert_gt(CreationScreen.ink_count(), 1, "one ink is not a palette")
	assert_eq(CreationScreen.INK_NAMES.size(), CreationScreen.INK_COLOURS.size(),
		"every ink has a name and every name has an ink")


func test_the_ink_buttons_exist_and_are_wired_to_the_canvas() -> void:
	var canvas: MarkCanvas = _screen.canvas()
	for index in CreationScreen.ink_count():
		var button := _screen.get_node_or_null(
			NodePath("Panel/Column/InkRow/Ink%d" % index)) as BaseButton
		assert_not_null(button, "ink %d has no button to press" % index)
		if button == null:
			continue
		assert_eq((button as Button).text, CreationScreen.ink_name(index),
			"the button says what the const says")
		button.pressed.emit()
		canvas.clear_all()
		canvas.paint_at(Vector2.ZERO)
		assert_true(_same_colour(_first_ink(canvas.image()), CreationScreen.ink_at(index)),
			"pressing ink %d has to reach the canvas, not only the swatch" % index)


func test_two_different_inks_leave_two_different_colours() -> void:
	var canvas: MarkCanvas = _screen.canvas()
	_screen.set_ink(0)
	canvas.clear_all()
	canvas.paint_at(Vector2.ZERO)
	var first: Color = _first_ink(canvas.image())
	_screen.set_ink(1)
	canvas.clear_all()
	canvas.paint_at(Vector2.ZERO)
	var second: Color = _first_ink(canvas.image())
	assert_false(_same_colour(first, second),
		"two inks that paint the same colour are one ink and a lie")


func test_picking_an_ink_turns_the_eraser_off() -> void:
	var canvas: MarkCanvas = _screen.canvas()
	canvas.set_eraser(true)
	assert_true(canvas.is_erasing())
	_screen.set_ink(2)
	assert_false(canvas.is_erasing(), "asking for a colour is asking to draw with it")


func test_the_ink_names_are_part_of_what_the_screen_draws() -> void:
	var drawn: Array[String] = _screen.drawn_lines()
	for index in CreationScreen.ink_count():
		assert_true(drawn.has(CreationScreen.ink_name(index)),
			"ink '%s' is on a button, so the copy rule applies to it"
				% CreationScreen.ink_name(index))


func test_cycling_the_mane_style_row_walks_the_pool_and_comes_back() -> void:
	var n: int = StockPaletteScript.mane_style_count()
	for i in n:
		assert_eq(_screen.look().mane_style, i)
		_screen.cycle_mane_style(1)
	assert_eq(_screen.look().mane_style, 0, "one full lap returns to the base model")


func test_cycling_backwards_from_zero_reaches_the_last_style() -> void:
	_screen.cycle_mane_style(-1)
	assert_eq(_screen.look().mane_style, StockPaletteScript.mane_style_count() - 1)


func test_the_mane_style_survives_confirm() -> void:
	_screen.cycle_mane_style(2)
	_screen.confirm()
	assert_eq(_screen.look().mane_style, 2)
