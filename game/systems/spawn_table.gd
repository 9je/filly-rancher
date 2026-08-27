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

## Relative weight per PonyData.Rarity TIER (not per entry). The single
## source of truth for spawn odds -- do not duplicate these numbers
## elsewhere. A `const` (not an `@export var`) so it is a class-level
## constant reachable as `SpawnTable.WEIGHTS` / `SpawnTableScript.WEIGHTS`
## without an instance, and exported here in the sense of "the one place
## other code and tests reach into" -- RefCounted scripts have no inspector
## to `@export` into anyway. Keyed by PonyData.Rarity int values
## (COMMON/UNCOMMON/RARE/LEGENDARY).
##
## PER-TIER SEMANTICS (deliberate, not per-entry): each tier's configured
## weight is a fixed slice of the total draw probability, split EVENLY among
## however many entries currently occupy that tier. A tier with zero entries
## contributes nothing -- draw() renormalizes over only the tiers actually
## present, it never lets an empty tier's weight silently vanish or leak
## into another tier.
##
## This is the only semantics under which these constants mean what their
## names say: "RARE ponies are rarer than UNCOMMON ones" only holds as a
## roster-size-independent statement if RARE-the-tier keeps a fixed 12%
## share regardless of how many RARE ponies exist. Per-entry weighting was
## tried first and rejected: it makes each entry within a tier worth the
## full tier weight, so tier proportions drift with roster composition. E.g.
## with today's real 3-pony roster (twilight RARE, rainbowdash RARE,
## fluttershy UNCOMMON) per-entry gives RARE 2*12=24 vs UNCOMMON's 25 --
## RARE draws almost as often as UNCOMMON, inverting the intended rarity
## ordering. Per-tier keeps the 60/25/12/3 tier split fixed no matter how
## many ponies occupy each tier -- individual ponies within a tier become
## rarer as that tier fills up (the correct behaviour for a collection
## game), while the tier split itself never decays as Phase 2 adds more
## COMMON background ponies.
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
## rarity TIER per WEIGHTS (see the comment there): each tier present gets
## its configured weight, split evenly among that tier's entries. Returns
## null (instead of crashing) if the table has no entries.
func draw() -> PonyData:
	if _entries.is_empty():
		return null

	var counts_by_tier := _count_by_tier()

	var total_weight := 0.0
	for tier in counts_by_tier.keys():
		total_weight += WEIGHTS.get(tier, 0)

	# Every rarity present must map to a positive weight in WEIGHTS (all four
	# current rarities do), so total_weight > 0 whenever _entries is
	# non-empty. Guard anyway so an unexpected zero-weight tier set falls
	# back to uniform selection rather than dividing by zero.
	if total_weight <= 0.0:
		return _entries[_rng.randi() % _entries.size()]

	var roll := _rng.randf() * total_weight
	var running := 0.0
	for data in _entries:
		running += _effective_weight(data, counts_by_tier)
		if roll < running:
			return data

	# Floating-point edge case: roll landed exactly on (or a hair past, due
	# to rounding) total_weight. Fall back to the last entry rather than
	# falling through to an implicit null.
	return _entries[_entries.size() - 1]


## {rarity_tier: count of _entries in that tier}, used to split each tier's
## fixed weight evenly among its current members.
func _count_by_tier() -> Dictionary:
	var counts := {}
	for data in _entries:
		counts[data.rarity] = counts.get(data.rarity, 0) + 1
	return counts


## This entry's share of its tier's weight: the tier's WEIGHTS value divided
## evenly among all entries sharing that tier. Summing this over every entry
## in a tier reproduces exactly that tier's WEIGHTS value -- the per-tier
## total is preserved regardless of how many entries split it.
func _effective_weight(data: PonyData, counts_by_tier: Dictionary) -> float:
	var tier_weight: float = WEIGHTS.get(data.rarity, 0)
	var tier_count: int = counts_by_tier[data.rarity]
	return tier_weight / tier_count
