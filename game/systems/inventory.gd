class_name Inventory
extends RefCounted
## CONSUMABLES THE PLAYER HOLDS, counted by item id: hay, apples, whatever the Market's
## CARE rows sell. Pens draw from it to feed hungry residents (game/world/pen.gd), so the
## running cost of a ranch is visible here going down.
##
## Item ids are the ShopItem/FoodData ids. This class does not know what an id means; it
## counts. RefCounted, no scene, GUT-tested (game/test/test_inventory.gd).

signal changed()

var _counts: Dictionary = {}


func add(item_id: StringName, count: int) -> void:
	if count <= 0 or String(item_id).is_empty():
		return
	_counts[item_id] = int(_counts.get(item_id, 0)) + count
	changed.emit()


## All or nothing: a remove that cannot be fully honoured changes nothing.
func remove(item_id: StringName, count: int) -> bool:
	if count <= 0:
		return false
	var have := int(_counts.get(item_id, 0))
	if have < count:
		return false
	if have == count:
		_counts.erase(item_id)
	else:
		_counts[item_id] = have - count
	changed.emit()
	return true


func count(item_id: StringName) -> int:
	return int(_counts.get(item_id, 0))


func has(item_id: StringName) -> bool:
	return count(item_id) > 0


func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for key in _counts.keys():
		out.append(key)
	# sort_custom rather than plain sort(): StringName's default comparator is not
	# reliably lexicographic once other scripts have interned the same names first
	# (observed only under the full suite, never in isolation), so compare as String.
	out.sort_custom(func(a, b): return String(a) < String(b))
	return out


func to_dict() -> Dictionary:
	var out := {}
	for key in _counts.keys():
		out[String(key)] = int(_counts[key])
	return out


static func from_dict(d: Dictionary) -> Inventory:
	var inv := Inventory.new()
	for key in d.keys():
		var id := String(key)
		var raw: Variant = d[key]
		if id.is_empty():
			continue
		if typeof(raw) != TYPE_INT and typeof(raw) != TYPE_FLOAT:
			continue
		var value := int(raw)
		if value > 0:
			inv._counts[StringName(id)] = value
	return inv
