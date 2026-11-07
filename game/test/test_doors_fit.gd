extends GutTest
## A DOOR A PONY FITS THROUGH (PS4, playtest 2026-11-05 item 29: "Doors far too small next to
## buildings everywhere (Market, Depot)"). Measured off the models (orthographic renders with
## a half-metre grid, 2026-11-07), the doors you SEE stood 0.47 to 0.69 pony heights: shorter
## than the pony at them, though the hidden shell's doorway was 3.85 m and test_scale passed on
## it. Every building that wears a model with a door now has its painted door at least
## SCALE.md's door minimum, 1.3 pony heights, and no more than its maximum, 2.2.

const RanchScene := preload("res://world/ranch.tscn")
const BuildingScript := preload("res://world/building.gd")
## 1 PH, SCALE.md: the player's rendered body, hoof to ear tips.
const PH := 2.19
const DOOR_MIN_PH := 1.3
const DOOR_MAX_PH := 2.2


func test_every_painted_door_is_pony_sized() -> void:
	var ranch: Node = RanchScene.instantiate()
	var checked := 0
	for b: Node in ranch.get_node(^"Buildings").get_children():
		if not (b is BuildingScript) or float(b.door_width) <= 0.001 or String(b.model_file).is_empty():
			continue
		if String(b.model_file).begins_with("res://"):
			continue  # the Palace: its own doors are a separate, pony-sized model (pc_palace_doors)
		assert_gt(float(b.model_door_height), 0.0, "%s has its door measured" % b.name)
		var h: float = b.door_clear_height()
		assert_between(h / PH, DOOR_MIN_PH, DOOR_MAX_PH,
			"%s: its door stands %.2f m, %.2f pony heights" % [b.name, h, h / PH])
		checked += 1
	assert_eq(checked, 4, "the Barn, the Farmhouse, the Market and the Depot")
	ranch.free()
