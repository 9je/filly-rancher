class_name ShopItem
extends Resource
## ONE ROW OF THE MARKET'S BUY TAB. What it is called, what it costs, and what buying it
## does. One .tres per item under game/data/shop/, so adding a thing to sell is authoring
## a data file, never writing code: the same rule PonyData, FoodData and PlotData follow.
##
## `kind` says which of four things the purchase does, and the payload field for that
## kind is the only one that matters; the others stay at their defaults.
##
##   CARE    the player gets `quantity` of `food_id` in her Inventory. Pens feed hungry
##           residents from it (game/world/pen.gd).
##   GEAR    `gear_id` is appended to GameState.unlocks, once. Game code reads unlocks to
##           apply the effect (a bigger saddlebag, a longer beam). Never sold twice.
##   PERMIT  `permit_zone` is appended to GameState.unlocks; a RegionGate for that zone
##           opens. Phase 2 slice 3 adds the gates; the kind exists now so the data model
##           does not change under them.
##   BUILD   `plot_id`, reserved for moving the plot catalogue into this shop. Not sold
##           in this slice; the build menu still owns building.
##
## Thin on purpose. How a purchase is paid for is Shop's business (game/systems/shop.gd),
## and what a gear id does is the business of whatever reads it.

enum Kind { GEAR, PERMIT, BUILD, CARE }

## Unique lookup key, e.g. &"hay" or &"bigger_saddlebag". The ShopRegistry dictionary key.
@export var id: StringName = &""

## What the Buy tab calls it. Never the id.
@export var display_name: String = ""

## One line for the player choosing between rows.
@export_multiline var description: String = ""

## Bits. Zero is legal (a starter handout), negative is not (ShopRegistry refuses it).
@export var cost: int = 0

@export var kind: Kind = Kind.CARE

## CARE: which FoodData this is, and how many one purchase hands over.
@export var food_id: StringName = &""
@export var quantity: int = 1

## GEAR: the unlock id game code looks for.
@export var gear_id: StringName = &""

## PERMIT: the zone whose gate this opens.
@export var permit_zone: StringName = &""

## BUILD: the PlotData this stands for. Unused in slice 1.
@export var plot_id: StringName = &""


func _to_string() -> String:
	return "ShopItem(%s, %s, cost=%d)" % [String(id), Kind.keys()[kind], cost]
