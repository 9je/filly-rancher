extends GutTest
## Tests for game/systems/shop.gd: the transaction between the pouch, the wallet and the
## inventory. Every refusal is re-checked afterwards for "nothing moved", the same way
## test_economy.gd does for spend().

const ShopScript := preload("res://systems/shop.gd")
const EconomyScript := preload("res://systems/economy.gd")
const GemPouchScript := preload("res://systems/gem_pouch.gd")
const InventoryScript := preload("res://systems/inventory.gd")
const ShopItemScript := preload("res://systems/shop_item.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")

var _econ: Economy
var _pouch: GemPouch
var _inv: Inventory
var _unlocks: Array
var _shop: Shop


func before_each() -> void:
	_econ = EconomyScript.new(0)
	_pouch = GemPouchScript.new()
	_inv = InventoryScript.new()
	_unlocks = []
	_shop = ShopScript.new(_econ, _pouch, _inv, _unlocks)


func _care(id: String, cost: int, food: String, qty: int = 1) -> ShopItem:
	var item: ShopItem = ShopItemScript.new()
	item.id = StringName(id)
	item.display_name = id.capitalize()
	item.cost = cost
	item.kind = ShopItemScript.Kind.CARE
	item.food_id = StringName(food)
	item.quantity = qty
	return item


func _gear(id: String, cost: int) -> ShopItem:
	var item: ShopItem = ShopItemScript.new()
	item.id = StringName(id)
	item.display_name = id.capitalize()
	item.cost = cost
	item.kind = ShopItemScript.Kind.GEAR
	item.gear_id = StringName(id)
	return item


# --- selling ------------------------------------------------------------------------------

func test_selling_gems_pays_the_rarity_price_and_empties_that_tier() -> void:
	_pouch.add(PonyDataScript.Rarity.RARE, 2)
	watch_signals(_shop)
	var earned := _shop.sell(PonyDataScript.Rarity.RARE, 2)
	assert_eq(earned, 2 * EconomyScript.GEM_VALUE_BY_RARITY[PonyDataScript.Rarity.RARE])
	assert_eq(_econ.bits, earned)
	assert_eq(_pouch.count(PonyDataScript.Rarity.RARE), 0)
	assert_signal_emitted_with_parameters(_shop, "sold", [PonyDataScript.Rarity.RARE, 2, earned])


func test_selling_more_than_held_sells_only_what_is_held() -> void:
	_pouch.add(PonyDataScript.Rarity.COMMON, 1)
	var earned := _shop.sell(PonyDataScript.Rarity.COMMON, 10)
	assert_eq(earned, EconomyScript.GEM_VALUE_BY_RARITY[PonyDataScript.Rarity.COMMON])
	assert_eq(_pouch.total(), 0)


func test_selling_from_an_empty_tier_earns_nothing_and_does_not_signal() -> void:
	watch_signals(_shop)
	assert_eq(_shop.sell(PonyDataScript.Rarity.LEGENDARY, 1), 0)
	assert_eq(_econ.bits, 0)
	assert_signal_not_emitted(_shop, "sold")


func test_sell_all_sums_every_tier() -> void:
	_pouch.add(PonyDataScript.Rarity.COMMON, 2)
	_pouch.add(PonyDataScript.Rarity.LEGENDARY, 1)
	var expected: int = 2 * EconomyScript.GEM_VALUE_BY_RARITY[PonyDataScript.Rarity.COMMON] \
		+ EconomyScript.GEM_VALUE_BY_RARITY[PonyDataScript.Rarity.LEGENDARY]
	assert_eq(_shop.sell_all(), expected)
	assert_true(_pouch.is_empty())
	assert_eq(_econ.bits, expected)


func test_gem_price_reads_the_economy_table() -> void:
	for rarity in EconomyScript.GEM_VALUE_BY_RARITY.keys():
		assert_eq(_shop.gem_price(rarity), EconomyScript.GEM_VALUE_BY_RARITY[rarity])


# --- buying care --------------------------------------------------------------------------

func test_buying_care_spends_bits_and_adds_the_food() -> void:
	_econ.sell(PonyDataScript.Rarity.COMMON, 4)  # 20 bits
	var hay := _care("hay", 5, "hay", 2)
	assert_true(_shop.can_buy(hay))
	watch_signals(_shop)
	assert_true(_shop.buy(hay))
	assert_eq(_econ.bits, 15)
	assert_eq(_shop.bits(), _econ.bits)
	assert_eq(_inv.count(&"hay"), 2)
	assert_signal_emitted(_shop, "bought")


func test_buying_what_you_cannot_afford_is_refused_and_nothing_moves() -> void:
	var hay := _care("hay", 5, "hay")
	assert_false(_shop.can_buy(hay))
	assert_false(_shop.buy(hay))
	assert_eq(_econ.bits, 0)
	assert_eq(_inv.count(&"hay"), 0)
	assert_false(_shop.refusal(hay).is_empty(), "the menu needs a reason to show")


func test_care_can_be_bought_repeatedly() -> void:
	_econ.sell(PonyDataScript.Rarity.RARE, 1)  # 30 bits
	var hay := _care("hay", 5, "hay")
	assert_true(_shop.buy(hay))
	assert_true(_shop.buy(hay))
	assert_eq(_inv.count(&"hay"), 2)
	assert_eq(_econ.bits, 20)


# --- buying gear --------------------------------------------------------------------------

func test_buying_gear_records_the_unlock_once() -> void:
	_econ.sell(PonyDataScript.Rarity.LEGENDARY, 3)  # 300 bits
	var bag := _gear("bigger_saddlebag", 120)
	assert_false(_shop.owns_gear(&"bigger_saddlebag"))
	assert_true(_shop.buy(bag))
	assert_true(_shop.owns_gear(&"bigger_saddlebag"))
	assert_eq(_unlocks, ["bigger_saddlebag"], "the live unlocks array is what changed")
	assert_eq(_econ.bits, 180)


func test_gear_already_owned_cannot_be_bought_again() -> void:
	_unlocks.append("long_beam")
	_econ.sell(PonyDataScript.Rarity.LEGENDARY, 5)
	var beam := _gear("long_beam", 200)
	assert_true(_shop.owns_gear(&"long_beam"))
	assert_false(_shop.can_buy(beam))
	assert_false(_shop.buy(beam))
	assert_eq(_econ.bits, 500, "a refused purchase costs nothing")
	assert_eq(_unlocks.size(), 1)


func test_a_care_item_with_no_food_is_refused_before_any_bits_move() -> void:
	_econ.sell(PonyDataScript.Rarity.RARE, 1)
	var broken := _care("broken", 5, "")
	assert_false(_shop.can_buy(broken))
	assert_false(_shop.buy(broken))
	assert_eq(_econ.bits, 30)


func test_buying_a_permit_records_it_once_and_never_twice() -> void:
	_econ.sell(PonyDataScript.Rarity.LEGENDARY, 5)  # 500 bits
	var permit: ShopItem = ShopItemScript.new()
	permit.id = &"permit_lake"
	permit.display_name = "Permit: The Lake"
	permit.cost = 150
	permit.kind = ShopItemScript.Kind.PERMIT
	permit.permit_zone = &"lake"
	assert_false(_shop.owns_permit(&"lake"))
	assert_true(_shop.can_buy(permit))
	assert_true(_shop.buy(permit))
	assert_true(_shop.owns_permit(&"lake"))
	assert_eq(_unlocks, ["permit_lake"])
	assert_eq(_econ.bits, 350)
	assert_false(_shop.can_buy(permit), "a held permit is not sold again")
	assert_false(_shop.refusal(permit).is_empty())
	assert_false(_shop.buy(permit))
	assert_eq(_econ.bits, 350)


func test_a_permit_with_no_zone_is_refused() -> void:
	_econ.sell(PonyDataScript.Rarity.LEGENDARY, 5)
	var broken: ShopItem = ShopItemScript.new()
	broken.id = &"permit_nowhere"
	broken.cost = 1
	broken.kind = ShopItemScript.Kind.PERMIT
	assert_false(_shop.buy(broken))
	assert_eq(_econ.bits, 500)


func test_the_build_kind_is_still_refused() -> void:
	_econ.sell(PonyDataScript.Rarity.LEGENDARY, 5)
	var build: ShopItem = ShopItemScript.new()
	build.id = &"pen"
	build.cost = 1
	build.kind = ShopItemScript.Kind.BUILD
	build.plot_id = &"pen_small"
	assert_false(_shop.buy(build))
	assert_eq(_econ.bits, 500)


func test_buying_null_is_refused() -> void:
	assert_false(_shop.can_buy(null))
	assert_false(_shop.buy(null))


## v1: the Supply Desk's gear is refused (and unlisted) off the Factory path.
func test_factory_gear_needs_the_factory_path() -> void:
	var item: ShopItem = load("res://data/shop/calm_lamp.tres")
	var shop := ShopScript.new(EconomyScript.new(), GemPouchScript.new(), InventoryScript.new(), [])
	assert_false(shop.listed(item))
	assert_ne(shop.refusal(item), "")
	shop.path_provider = func() -> String: return "factory"
	assert_true(shop.listed(item))


## MISSION.md's fun rules: at least half of all upgrades change HOW you play. Every gear and
## build item in the catalogue counts; food and permits (areas, not upgrades) do not.
func test_at_least_half_the_upgrades_are_verb_changing() -> void:
	var registry = load("res://systems/shop_registry.gd").new()
	registry.load_all()
	var verbs := 0
	var total := 0
	for item: ShopItem in registry.all():
		if item.kind == ShopItemScript.Kind.GEAR or item.kind == ShopItemScript.Kind.BUILD:
			total += 1
			if item.verb:
				verbs += 1
	# The two bigger pens are upgrades too (number-only), though they are built, not bought.
	total += 2
	assert_gt(total, 0)
	assert_true(float(verbs) / float(total) >= 0.5,
		"%d of %d upgrades are verb-changing; the rule is at least half" % [verbs, total])
