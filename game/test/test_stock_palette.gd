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


func test_draw_triple_is_deterministic_for_a_seed() -> void:
	var palette: StockPalette = StockPaletteScript.load_stock()
	var a := RandomNumberGenerator.new()
	a.seed = 4242
	var b := RandomNumberGenerator.new()
	b.seed = 4242
	assert_eq(palette.draw_triple(a), palette.draw_triple(b), "same seed, same pony")


func test_draw_triple_stays_inside_every_row() -> void:
	var palette: StockPalette = StockPaletteScript.load_stock()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 200:
		var triple: Dictionary = palette.draw_triple(rng)
		assert_between(int(triple["coat"]), 0, palette.coats.size() - 1)
		assert_between(int(triple["mane"]), 0, palette.manes.size() - 1)
		assert_between(int(triple["eyes"]), 0, palette.eyes.size() - 1)


func test_the_three_stock_ids_are_recognised_and_nobody_else_is() -> void:
	for id: StringName in StockPaletteScript.IDS:
		assert_true(StockPaletteScript.is_stock_id(id), "%s is a stock id" % id)
	assert_false(StockPaletteScript.is_stock_id(&"twilight"))
	assert_false(StockPaletteScript.is_stock_id(&""))
