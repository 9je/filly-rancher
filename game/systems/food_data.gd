class_name FoodData
extends Resource
## Static description of one growable/feedable food: identity, and the two numbers the
## world-facing half of this task (gardens, the market) needs to act on it. One .tres per
## food under game/data/foods/ -- adding a food is authoring a new data file, never writing
## new code, mirroring the PonyData / game/data/ponies/ pattern (game/systems/pony_data.gd).
##
## Deliberately thin. This file only carries what identifies a food and what a GARDEN or a
## SHOP needs (grow_seconds, seed_cost) -- neither of which game/systems/needs.gd (this
## task's other half) reads at all. Needs.feed() only needs to know a food_id resolves to
## SOME real food (via FoodRegistry) and whether that id is in a pony's
## PonyData.favorite_foods -- the favourite/neutral happiness split lives in needs.gd, not
## here, because "how much a food is worth to a pony" is a NEEDS rule, not a fact about the
## food itself (the same daffodil is a favourite to Twilight and neutral to everyone else).

## Unique lookup key, e.g. &"hay". Matches the FoodRegistry dictionary key and the
## StringNames listed in PonyData.favorite_foods (game/systems/pony_data.gd).
@export var id: StringName = &""
@export var display_name: String = ""
## Seconds a garden plot takes to grow one harvest of this food from planting. Read by
## Task 4's world half (game/world/garden.gd, out of this task's scope) -- not by
## needs.gd, which only cares about a food once it is in a pony's mouth.
@export var grow_seconds: float = 0.0
## Bits cost to buy one seed of this food at the market (Task 6). Not read by needs.gd.
@export var seed_cost: int = 0


func _to_string() -> String:
	return "FoodData(%s, grow_seconds=%.0f, seed_cost=%d)" % [String(id), grow_seconds, seed_cost]
