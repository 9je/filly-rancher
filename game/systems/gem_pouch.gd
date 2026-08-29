class_name GemPouch
extends RefCounted
## THE GEMS THE PLAYER HOLDS, counted by the rarity of the pony who produced them.
##
## A gem has no identity of its own: Economy.sell() prices it by PonyData.Rarity and by
## nothing else (see economy.gd's class comment), so this pouch is four integers. It exists
## so that gems survive quitting: a pen's tray (game/world/pen.gd) is a transient staging
## area, and game/world/ranch.gd folds every tray into this pouch before a save and when
## the Market opens. GameState carries the pouch as `gems`.
##
## RefCounted, no scene, GUT-tested in isolation (game/test/test_gem_pouch.gd), the same
## discipline as Economy and Storage.

const PonyDataScript := preload("res://systems/pony_data.gd")

## Emitted once per real change. Not for a no-op (an add of zero, a take from an empty
## tier), matching Storage.changed's rule.
signal changed()

var _counts: Dictionary = {}


static func _is_rarity(rarity: int) -> bool:
	return PonyDataScript.Rarity.values().has(rarity)


func add(rarity: int, count: int) -> void:
	if count <= 0 or not _is_rarity(rarity):
		return
	_counts[rarity] = int(_counts.get(rarity, 0)) + count
	changed.emit()


func count(rarity: int) -> int:
	return int(_counts.get(rarity, 0))


func total() -> int:
	var sum := 0
	for value in _counts.values():
		sum += int(value)
	return sum


func is_empty() -> bool:
	return total() == 0


## Take up to `count` gems of `rarity`. Returns how many actually left the pouch.
func take(rarity: int, count: int) -> int:
	if count <= 0:
		return 0
	var have := self.count(rarity)
	var taken := mini(have, count)
	if taken <= 0:
		return 0
	_counts[rarity] = have - taken
	changed.emit()
	return taken


func take_all(rarity: int) -> int:
	return take(rarity, count(rarity))


## String keys, because JSON has no integer keys and GameState.plots learned that the
## hard way (see game_state.gd).
func to_dict() -> Dictionary:
	var out := {}
	for rarity in _counts.keys():
		if int(_counts[rarity]) > 0:
			out[str(rarity)] = int(_counts[rarity])
	return out


static func from_dict(d: Dictionary) -> GemPouch:
	var pouch := GemPouch.new()
	for key in d.keys():
		var rarity := int(str(key)) if str(key).is_valid_int() else -1
		var raw: Variant = d[key]
		if not _is_rarity(rarity):
			continue
		if typeof(raw) != TYPE_INT and typeof(raw) != TYPE_FLOAT:
			continue
		var value := maxi(0, int(raw))
		if value > 0:
			pouch._counts[rarity] = value
	return pouch
