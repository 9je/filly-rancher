extends GutTest
## The five Company owned runners, as authored data.

const CompanyRunnersScript := preload("res://systems/company_runners.gd")
const StockPaletteScript := preload("res://systems/stock_palette.gd")


func test_the_shipped_card_loads_and_holds_five_runners() -> void:
	var runners: CompanyRunners = CompanyRunnersScript.load_shipped()
	assert_not_null(runners, "res://data/casino/company_runners.tres must load")
	assert_eq(runners.count(), 5, "five Company runners and one lane for your pony")
	assert_true(runners.is_valid(), "every column must be the same length")


func test_every_column_is_filled_in_and_in_range() -> void:
	var runners: CompanyRunners = CompanyRunnersScript.load_shipped()
	var palette: StockPalette = StockPaletteScript.load_stock()
	for i in runners.count():
		var entry: Dictionary = runners.entry(i)
		assert_false(String(entry["name"]).is_empty())
		assert_between(float(entry["speed"]), 3.0, 6.5, "inside the roster's own speed range")
		assert_between(float(entry["stamina"]), 3.5, 7.5)
		assert_between(float(entry["spirit"]), 4.0, 8.5)
		assert_true(StockPaletteScript.is_stock_id(entry["base_id"]),
			"a Company runner is built on a hidden stock record")
		var triple: Dictionary = entry["stock"]
		assert_between(int(triple["coat"]), 0, palette.coats.size() - 1)
		assert_between(int(triple["mane"]), 0, palette.manes.size() - 1)
		assert_between(int(triple["eyes"]), 0, palette.eyes.size() - 1)


func test_no_two_runners_share_a_name() -> void:
	var runners: CompanyRunners = CompanyRunnersScript.load_shipped()
	var seen: Dictionary = {}
	for i in runners.count():
		var runner_name: String = runners.entry(i)["name"]
		assert_false(seen.has(runner_name), "%s is on the card twice" % runner_name)
		seen[runner_name] = true


func test_the_names_are_player_facing_and_carry_no_dashes() -> void:
	var runners: CompanyRunners = CompanyRunnersScript.load_shipped()
	for i in runners.count():
		var runner_name: String = runners.entry(i)["name"]
		assert_false(runner_name.contains("--") or runner_name.contains("—"), runner_name)


func test_an_index_off_the_end_answers_an_empty_entry_rather_than_erroring() -> void:
	var runners: CompanyRunners = CompanyRunnersScript.load_shipped()
	assert_true(runners.entry(-1).is_empty())
	assert_true(runners.entry(99).is_empty())


func test_a_half_authored_card_is_not_valid() -> void:
	var runners: CompanyRunners = CompanyRunnersScript.new()
	runners.runner_names = ["Only One"]
	assert_false(runners.is_valid(), "a name with no stats behind it is a broken card")
