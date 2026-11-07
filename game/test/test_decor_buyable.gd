extends GutTest
## DECOR CAN BE BOUGHT (found while rendering PS9 item 55, 2026-11-07). The Market listed
## twelve decorations since FS7.1, but Shop.refusal() had no case for DECOR and refused every
## one "Not for sale yet.", so each tile drew its price in red and no purchase went through.

const ShopScript := preload("res://systems/shop.gd")
const EconomyScript := preload("res://systems/economy.gd")
const GemPouchScript := preload("res://systems/gem_pouch.gd")
const InventoryScript := preload("res://systems/inventory.gd")


func test_an_affordable_decoration_is_bought() -> void:
	var econ := EconomyScript.new(2000)
	var shop := ShopScript.new(econ, GemPouchScript.new(), InventoryScript.new(), [])
	var hay: ShopItem = load("res://data/shop/decor_hay_bales.tres")
	assert_eq(shop.refusal(hay), "")
	assert_true(shop.buy(hay))
	assert_eq(econ.bits, 2000 - hay.cost)


func test_a_decoration_she_owns_is_not_sold_twice() -> void:
	var econ := EconomyScript.new(2000)
	var shop := ShopScript.new(econ, GemPouchScript.new(), InventoryScript.new(), [])
	var hay: ShopItem = load("res://data/shop/decor_hay_bales.tres")
	shop.decor_provider = func(id: StringName) -> bool: return id == hay.decor_id
	assert_false(shop.buy(hay))
	assert_eq(econ.bits, 2000)
