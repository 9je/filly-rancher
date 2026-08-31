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
