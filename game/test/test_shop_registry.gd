extends GutTest
## Tests for the shop catalogue: game/systems/shop_item.gd, game/systems/shop_registry.gd,
## and the .tres files under game/data/shop/. Mirrors test_plot_registry's shape.

const ShopRegistryScript := preload("res://systems/shop_registry.gd")
const ShopItemScript := preload("res://systems/shop_item.gd")
const ShopScript := preload("res://systems/shop.gd")
const FoodRegistryScript := preload("res://systems/food_registry.gd")
const RegionRegistryScript := preload("res://systems/region_registry.gd")


func _registry() -> ShopRegistry:
	var reg: ShopRegistry = ShopRegistryScript.new()
	reg.load_all(ShopRegistryScript.SHOP_DIR)
	return reg


func test_the_shipped_catalogue_loads_and_is_not_empty() -> void:
	var items := _registry().all()
	assert_gt(items.size(), 0)


func test_every_item_has_an_id_a_name_and_a_non_negative_cost() -> void:
	for item in _registry().all():
		assert_false(String(item.id).is_empty(), "every item needs an id")
		assert_false(item.display_name.is_empty(), "%s needs a display name" % item.id)
		assert_gte(item.cost, 0, "%s cannot have a negative cost" % item.id)


func test_ids_are_unique_and_by_id_finds_each() -> void:
	var reg := _registry()
	var seen := {}
	for item in reg.all():
		assert_false(seen.has(item.id), "duplicate id %s" % item.id)
		seen[item.id] = true
		assert_eq(reg.by_id(item.id), item)
	assert_null(reg.by_id(&"no_such_item"))


func test_all_is_sorted_cheapest_first_then_by_id() -> void:
	var items := _registry().all()
	for i in range(1, items.size()):
		var a := items[i - 1]
		var b := items[i]
		var ordered := a.cost < b.cost or (a.cost == b.cost and String(a.id) < String(b.id))
		assert_true(ordered, "%s should come before %s" % [a.id, b.id])


func test_every_care_item_names_a_food_that_exists() -> void:
	var foods: FoodRegistry = FoodRegistryScript.new()
	foods.load_all("res://data/foods")
	var care := _registry().of_kind(ShopItemScript.Kind.CARE)
	assert_gt(care.size(), 0, "the Market must sell at least one food")
	for item in care:
		assert_not_null(foods.by_id(item.food_id),
			"CARE item %s points at food '%s', which is not in game/data/foods" % [item.id, item.food_id])
		assert_gt(item.quantity, 0, "%s must hand over at least one" % item.id)


func test_every_gear_item_has_a_gear_id() -> void:
	var gear := _registry().of_kind(ShopItemScript.Kind.GEAR)
	assert_gt(gear.size(), 0, "the Market must sell at least one piece of gear")
	for item in gear:
		assert_false(String(item.gear_id).is_empty(), "%s needs a gear_id" % item.id)


func test_at_least_one_item_costs_less_than_one_common_gem_sale_of_five() -> void:
	# Five common gems sell for 25 bits (Economy.GEM_VALUE_BY_RARITY). A catalogue whose
	# cheapest row costs more than that is a shop a new player cannot enter.
	var cheapest := _registry().all()[0]
	assert_lte(cheapest.cost, 25, "cheapest item is %s at %d" % [cheapest.id, cheapest.cost])


func test_every_permit_names_a_region_that_exists_and_matches_its_price() -> void:
	var regions: RegionRegistry = RegionRegistryScript.new()
	regions.load_all(RegionRegistryScript.REGION_DIR)
	var permits := _registry().of_kind(ShopItemScript.Kind.PERMIT)
	assert_eq(permits.size(), regions.all().size(), "one permit per region")
	for item in permits:
		var region: RegionData = regions.by_id(item.permit_zone)
		assert_not_null(region, "%s names zone '%s', which is not a region" % [item.id, item.permit_zone])
		assert_eq(item.cost, region.permit_cost, "%s must cost what the region says" % item.id)
		assert_eq(item.id, ShopScript.permit_id_for(item.permit_zone))


func test_every_region_permit_id_matches_shop_permit_id_for() -> void:
	var regions: RegionRegistry = RegionRegistryScript.new()
	regions.load_all(RegionRegistryScript.REGION_DIR)
	for region in regions.all():
		assert_eq(region.permit_id(), ShopScript.permit_id_for(region.id),
			"%s's permit_id must be the one spelling Shop owns" % region.id)


func test_a_missing_directory_loads_nothing_and_does_not_crash() -> void:
	var reg: ShopRegistry = ShopRegistryScript.new()
	var loaded := reg.load_all("res://data/no_such_dir")
	assert_eq(loaded.size(), 0)
	assert_eq(reg.all().size(), 0)
	assert_push_error(1, "a missing shop directory is reported loudly, not swallowed")
