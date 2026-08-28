class_name Shop
extends RefCounted
## THE MARKET'S TRANSACTION, with no shop building and no menu attached. Sell gems from
## the pouch into the wallet; buy items with the wallet into the inventory or the unlocks.
## game/ui/market_menu.gd draws these and emits; game/world/ranch.gd calls this. One
## place for the money to move, so "charged but not delivered" has nowhere to live.
##
## THE ORDER IS CHECK, THEN SPEND, THEN DELIVER. can_buy() answers every reason a purchase
## could fail before a single bit moves, and buy() re-asks it, so a delivery can only fail
## after a spend for a reason this file did not think of, and Economy.spend() is a no-op
## on refusal so even that leaves the wallet as it was.
##
## `unlocks` is GameState's live Array, mutated in place: appending here is what makes the
## purchase survive quitting. Owning gear is the only thing that stops it being sold twice.

const EconomyScript := preload("res://systems/economy.gd")
const ShopItemScript := preload("res://systems/shop_item.gd")

signal sold(rarity: int, count: int, bits: int)
signal bought(item: ShopItem)

var _economy: Economy
var _pouch: GemPouch
var _inventory: Inventory
var _unlocks: Array


func _init(economy: Economy, pouch: GemPouch, inventory: Inventory, unlocks: Array) -> void:
	_economy = economy
	_pouch = pouch
	_inventory = inventory
	_unlocks = unlocks


## Bits the wallet currently holds. A later task's menu needs this without reaching into
## the Economy instance directly.
func bits() -> int:
	return _economy.bits


# --- selling ------------------------------------------------------------------------------

func gem_count(rarity: int) -> int:
	return _pouch.count(rarity)


func gem_price(rarity: int) -> int:
	return int(EconomyScript.GEM_VALUE_BY_RARITY.get(rarity, 0))


## Sell up to `count` gems of `rarity`. Returns the bits earned.
func sell(rarity: int, count: int) -> int:
	var taken := _pouch.take(rarity, count)
	if taken <= 0:
		return 0
	var earned := _economy.sell(rarity, taken)
	sold.emit(rarity, taken, earned)
	return earned


func sell_all() -> int:
	var earned := 0
	for rarity in EconomyScript.GEM_VALUE_BY_RARITY.keys():
		earned += sell(rarity, _pouch.count(rarity))
	return earned


# --- buying -------------------------------------------------------------------------------

func owns_gear(gear_id: StringName) -> bool:
	return _unlocks.has(String(gear_id))


## Why `item` cannot be bought right now, as a line for the menu footer, or "" if it can.
func refusal(item: ShopItem) -> String:
	if item == null:
		return "Nothing to buy."
	match item.kind:
		ShopItemScript.Kind.CARE:
			if String(item.food_id).is_empty() or item.quantity <= 0:
				return "That is not for sale."
		ShopItemScript.Kind.GEAR:
			if String(item.gear_id).is_empty():
				return "That is not for sale."
			if owns_gear(item.gear_id):
				return "You already have that."
		_:
			return "Not for sale yet."
	if not _economy.can_afford(item.cost):
		return "%s costs %d bits. You have %d." % [item.display_name, item.cost, _economy.bits]
	return ""


func can_buy(item: ShopItem) -> bool:
	return refusal(item).is_empty()


func buy(item: ShopItem) -> bool:
	if not can_buy(item):
		return false
	if not _economy.spend(item.cost):
		return false
	match item.kind:
		ShopItemScript.Kind.CARE:
			_inventory.add(item.food_id, item.quantity)
		ShopItemScript.Kind.GEAR:
			_unlocks.append(String(item.gear_id))
	bought.emit(item)
	return true
