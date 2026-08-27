extends GutTest
## Tests for FoodData (game/systems/food_data.gd) and FoodRegistry
## (game/systems/food_registry.gd), mirroring test_pony_registry.gd. Preloads by path
## rather than the global class_name -- the class cache lives in the gitignored
## game/.godot/ and a fresh clone has not built it yet (see game/scripts/pony_rig.gd).

const FoodRegistryScript := preload("res://systems/food_registry.gd")
const FoodDataScript := preload("res://systems/food_data.gd")

const FOOD_DIR := "res://data/foods/"

var registry: FoodRegistry


func before_each() -> void:
	registry = FoodRegistryScript.new()


func test_load_all_covers_every_favorite_food_the_three_characters_want() -> void:
	# Twilight wants daffodil+hay, Fluttershy wants daisy+hay, Rainbow Dash wants hay
	# (game/data/ponies/*.tres) -- every one of those must resolve to a real food, or
	# Needs.feed() would refuse to feed a pony her own favourite.
	var foods := registry.load_all(FOOD_DIR)
	assert_true(foods.has(&"hay"), "hay is a favourite of all three characters")
	assert_true(foods.has(&"daffodil"), "daffodil is Twilight's favourite")
	assert_true(foods.has(&"daisy"), "daisy is Fluttershy's favourite")


func test_load_all_also_has_neutral_foods_nobody_favors() -> void:
	# So "feeding a non-favourite" is testable against a real food, not a fixture.
	var foods := registry.load_all(FOOD_DIR)
	assert_true(foods.has(&"apple"), "apple is a neutral (non-favourite) food")
	assert_true(foods.has(&"carrot"), "carrot is a neutral (non-favourite) food")


func test_load_all_entries_are_food_data() -> void:
	var foods := registry.load_all(FOOD_DIR)
	var hay = foods[&"hay"]
	assert_true(hay is FoodDataScript, "loaded entry should be a FoodData resource")
	assert_eq(hay.id, &"hay")
	assert_eq(hay.display_name, "Hay")
	assert_gt(hay.grow_seconds, 0.0, "a food must take a nonzero time to grow")
	assert_gt(hay.seed_cost, 0, "a food must cost something to plant")


func test_by_id_looks_a_food_up_and_answers_null_for_a_stranger() -> void:
	registry.load_all(FOOD_DIR)
	var hay: FoodData = registry.by_id(&"hay")
	assert_not_null(hay, "a food on disk must be findable by id")
	assert_eq(hay.id, &"hay")
	assert_null(registry.by_id(&"not_a_real_food"),
		"an id this registry has never heard of resolves to null, not a crash")


func test_by_id_on_a_registry_that_has_loaded_nothing_is_null_not_a_crash() -> void:
	assert_null(registry.by_id(&"hay"),
		"an unloaded registry knows no foods, and must say so rather than crash")
