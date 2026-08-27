class_name SpawnTable
extends RefCounted
## Rarity-weighted spawn table: given a pool of PonyData entries (typically
## the result of a PonyRegistry.by_zone()/by_rarity() query), draw() picks
## one at random, biased by each entry's rarity. No scene-tree dependency --
## constructible and testable headlessly with plain `.new()` (see
## game/test/test_spawn_table.gd).
##
## The RNG is injected rather than using the global RandomNumberGenerator so
## tests can seed it and get a fully deterministic draw sequence.

## Relative weight per PonyData.Rarity value. The single source of truth for
## spawn odds -- do not duplicate these numbers elsewhere. A `const` (not an
## `@export var`) so it is a class-level constant reachable as
## `SpawnTable.WEIGHTS` / `SpawnTableScript.WEIGHTS` without an instance, and
## exported here in the sense of "the one place other code and tests reach
## into" -- RefCounted scripts have no inspector to `@export` into anyway.
## Keyed by PonyData.Rarity int values (COMMON/UNCOMMON/RARE/LEGENDARY).
const WEIGHTS: Dictionary = {
	PonyData.Rarity.COMMON: 60,
	PonyData.Rarity.UNCOMMON: 25,
	PonyData.Rarity.RARE: 12,
	PonyData.Rarity.LEGENDARY: 3,
}

var _entries: Array[PonyData] = []
var _rng: RandomNumberGenerator


func _init(entries: Array[PonyData], rng: RandomNumberGenerator) -> void:
	_entries = entries
	_rng = rng


## Draws one PonyData from the entries supplied at construction, weighted by
## each entry's rarity per WEIGHTS. Returns null (instead of crashing) if the
## table has no entries.
func draw() -> PonyData:
	if _entries.is_empty():
		return null

	var total_weight := 0.0
	for data in _entries:
		total_weight += _weight_for(data)

	# Every rarity present must map to a positive weight in WEIGHTS (all four
	# current rarities do), so total_weight > 0 whenever _entries is
	# non-empty. Guard anyway so an unexpected zero-weight entry set falls
	# back to uniform selection rather than dividing by zero.
	if total_weight <= 0.0:
		return _entries[_rng.randi() % _entries.size()]

	var roll := _rng.randf() * total_weight
	var running := 0.0
	for data in _entries:
		running += _weight_for(data)
		if roll < running:
			return data

	# Floating-point edge case: roll landed exactly on (or a hair past, due
	# to rounding) total_weight. Fall back to the last entry rather than
	# falling through to an implicit null.
	return _entries[_entries.size() - 1]


func _weight_for(data: PonyData) -> float:
	return WEIGHTS.get(data.rarity, 0)
