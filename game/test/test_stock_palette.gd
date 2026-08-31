extends GutTest
## The swatch rows and the safe index lookup behind every recolour in the game.

const StockPaletteScript := preload("res://systems/stock_palette.gd")


func test_the_shipped_stock_palette_loads_and_is_valid() -> void:
	var palette: StockPalette = StockPaletteScript.load_stock()
	assert_not_null(palette, "res://data/stock_palette.tres must load")
	assert_true(palette.is_valid(), "every row of the stock palette must hold at least one swatch")


func test_the_player_palette_is_wider_than_the_stock_palette() -> void:
	var stock: StockPalette = StockPaletteScript.load_stock()
	var player: StockPalette = StockPaletteScript.load_player()
	assert_gt(player.coats.size(), stock.coats.size(), "the player picks from a wider coat row")
	assert_gt(player.manes.size(), stock.manes.size(), "the player picks from a wider mane row")


func test_an_index_out_of_range_wraps_instead_of_crashing() -> void:
	var palette: StockPalette = StockPaletteScript.load_stock()
	var n: int = palette.coats.size()
	assert_eq(palette.coat_at(n), palette.coat_at(0), "one past the end wraps to the start")
	assert_eq(palette.coat_at(-1), palette.coat_at(n - 1), "a negative index wraps from the end")


func test_an_empty_row_answers_white_rather_than_erroring() -> void:
	var palette := StockPalette.new()
	assert_eq(palette.coat_at(0), Color.WHITE)
	assert_eq(palette.mane_at(3), Color.WHITE)
	assert_eq(palette.eye_at(-2), Color.WHITE)
	assert_false(palette.is_valid())


func test_draw_look_is_deterministic_for_a_seed() -> void:
	var palette: StockPalette = StockPaletteScript.load_stock()
	var a := RandomNumberGenerator.new()
	a.seed = 4242
	var b := RandomNumberGenerator.new()
	b.seed = 4242
	assert_eq(palette.draw_look(a), palette.draw_look(b), "same seed, same pony")


func test_draw_look_stays_inside_every_row() -> void:
	var palette: StockPalette = StockPaletteScript.load_stock()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 200:
		var look: Dictionary = palette.draw_look(rng)
		assert_between(int(look["coat"]), 0, palette.coats.size() - 1)
		assert_between(int(look["mane"]), 0, palette.manes.size() - 1)
		assert_between(int(look["eyes"]), 0, palette.eyes.size() - 1)
		assert_between(int(look["mane_style"]), 0, StockPaletteScript.mane_style_count() - 1)


func test_the_three_stock_ids_are_recognised_and_nobody_else_is() -> void:
	for id: StringName in StockPaletteScript.IDS:
		assert_true(StockPaletteScript.is_stock_id(id), "%s is a stock id" % id)
	assert_false(StockPaletteScript.is_stock_id(&"twilight"))
	assert_false(StockPaletteScript.is_stock_id(&""))


# --- one word for a colour ------------------------------------------------------------------

## What the Depot's Deliver tab tells two members of the crowd apart by. The property that
## matters is not which word any one coat gets, it is that the shipped coats do not all get
## the SAME word: a pen of six stock ponies has to list six readable rows.
func test_every_shipped_stock_coat_gets_a_word_of_its_own() -> void:
	var palette: StockPalette = StockPaletteScript.load_stock()
	assert_gt(palette.coats.size(), 1, "sanity: there is a row to name")
	var seen := {}
	for i in palette.coats.size():
		var word: String = StockPaletteScript.colour_name(palette.coat_at(i))
		assert_false(word.is_empty(), "coat %d has no word at all" % i)
		seen[word] = true
	assert_eq(seen.size(), palette.coats.size(),
		"two coats sharing one word is two identical rows on the Deliver tab")


func test_a_washed_out_colour_is_named_by_how_light_it_is_rather_than_by_hue() -> void:
	assert_eq(StockPaletteScript.colour_name(Color(0.98, 0.97, 0.96)), "Cream")
	assert_eq(StockPaletteScript.colour_name(Color(0.55, 0.54, 0.56)), "Ash")
	assert_eq(StockPaletteScript.colour_name(Color(0.06, 0.06, 0.07)), "Coal")


func test_a_saturated_colour_is_named_by_its_hue() -> void:
	assert_eq(StockPaletteScript.colour_name(Color(0.90, 0.20, 0.30)), "Rose")
	assert_eq(StockPaletteScript.colour_name(Color(0.35, 0.70, 0.40)), "Meadow")
	assert_eq(StockPaletteScript.colour_name(Color(0.25, 0.45, 0.85)), "Sky")
