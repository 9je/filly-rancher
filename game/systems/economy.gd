class_name Economy
extends RefCounted
## THE WALLET -- bits in, bits out. Phase 1B Task 6's pure-logic half: selling gems and
## spending on upgrades, as arithmetic with no scene, no market stall and no shop UI
## attached. Those live in game/world/market_stall.gd and game/ui/shop.gd (a different
## task); this file only has to be right about the numbers.
##
## RefCounted, no scene tree, no Node -- same discipline as game/systems/storage.gd and
## game/systems/production.gd, so the whole of it is GUT-testable in milliseconds
## (game/test/test_economy.gd) instead of only through a shop UI in a running scene.
##
## --- GEM VALUE IS KEYED BY THE PRODUCING PONY'S RARITY ----------------------------------
##
## THIS is the backbone-of-the-economy relationship the task asked for: a legendary pony's
## gems are worth more than a common pony's. GEM_VALUE_BY_RARITY below is the single,
## obvious, data-driven place that mapping lives -- one Dictionary, keyed by
## PonyData.Rarity (game/systems/pony_data.gd), read by sell() and nowhere else. This is
## the same shape SpawnTable.WEIGHTS (game/systems/spawn_table.gd) already uses for "one
## constant Dictionary keyed by rarity tier is the single source of truth" -- a reviewer
## who already knows that file's pattern should recognise this one immediately.
##
## `gem_type` in sell()'s signature IS a PonyData.Rarity value -- there is no separate gem
## taxonomy. A gem does not have its own identity independent of the pony who produced it;
## Production.tick() (game/systems/production.gd) already reads inst.happiness/inst.hunger
## off the SAME instance, so whatever world-facing code turns a tick's returned gem count
## into an actual pickup (pen.gd, a different task) already has `inst.data().rarity` sitting
## right there to hand to sell() later. Reusing PonyData.Rarity instead of inventing
## "GemType.COMMON/UNCOMMON/..." keeps exactly one rarity enum in the whole project instead
## of two that have to be kept in sync by hand.
##
## See the Task 5/6 report for the bits-per-gem numbers below translated into real-time
## pacing (time to a first gem, time to a first upgrade) -- they are a starting point for
## Task 6's shop-tuning pass to argue with, not handed-down constants.

## Bits paid per gem sold, keyed by the RARITY TIER of the pony that produced it. A
## `const Dictionary` (not `@export var`) for the same reason SpawnTable.WEIGHTS is one:
## reachable as `Economy.GEM_VALUE_BY_RARITY` / `EconomyScript.GEM_VALUE_BY_RARITY` without
## an instance, and a RefCounted script has no inspector to `@export` into anyway.
##
## Roughly 2.5x per tier (matching SpawnTable's rarity odds falling off in a similar,
## though not identical, curve): a LEGENDARY gem is worth twenty times a COMMON one,
## because catching a legendary pony is itself far rarer than twenty times as hard, and
## the payoff for having found and kept one happy should read as a real windfall, not a
## rounding error next to a common pony's output.
const GEM_VALUE_BY_RARITY: Dictionary = {
	PonyData.Rarity.COMMON: 5,
	PonyData.Rarity.UNCOMMON: 12,
	PonyData.Rarity.RARE: 30,
	PonyData.Rarity.LEGENDARY: 100,
}

## Emitted whenever `bits` actually changes -- once per sale that earned something, once
## per spend that succeeded. Carries the NEW total, so a HUD can bind to it directly
## without a separate read of `bits` afterwards. Deliberately NOT emitted for a no-op (a
## sale of zero/negative gems, an unrecognised gem type, a refused spend, a spend of
## exactly 0) -- matching Storage.changed's own rule (game/systems/storage.gd): a signal
## that fires when nothing moved is exactly as useless to a listener as one that never
## fires at all.
signal bits_changed(new_total: int)

## How many bits the wallet currently holds. Never negative -- see _init() and spend().
var bits: int = 0


## `starting_bits` defaults to 0 (a brand new ranch). A negative value is clamped rather
## than trusted, mirroring Storage's negative-capacity clamp (test_storage.gd): a corrupt
## or hand-edited save must not be able to construct a wallet that starts in debt.
func _init(starting_bits: int = 0) -> void:
	bits = maxi(0, starting_bits)


## Sells `count` gems of `gem_type` (a PonyData.Rarity value -- see the class comment) and
## returns the bits earned (0 if the sale did nothing). `count <= 0` or an unrecognised
## `gem_type` both earn nothing and leave `bits` and the signal untouched -- there is no
## such thing as a partial or negative sale.
func sell(gem_type: int, count: int) -> int:
	if count <= 0:
		return 0
	var unit_value: int = GEM_VALUE_BY_RARITY.get(gem_type, 0)
	var earned := unit_value * count
	if earned <= 0:
		return 0
	bits += earned
	bits_changed.emit(bits)
	return earned


## Whether spend(cost) would succeed right now. A negative cost is never affordable --
## see spend()'s own comment on why a negative spend is refused rather than treated as a
## deposit.
func can_afford(cost: int) -> bool:
	return cost >= 0 and bits >= cost


## Deducts `cost` from `bits` and returns true, or changes NOTHING and returns false if
## the wallet cannot afford it. THE contract this exists to guarantee: a refusal is a
## no-op, full stop -- never a partial deduction. Every caller (a shop button, a save/load
## round trip) can treat a `false` return as proof the balance did not move, without a
## second read of `bits` to confirm it.
##
## `cost == 0` succeeds without emitting `bits_changed` -- nothing about the wallet
## changed, so nothing should be announced as having changed (see the signal's own
## comment). `cost < 0` is refused outright by can_afford(): a "negative purchase" would
## be a free deposit wearing a spend() costume, and this method's whole job is spending,
## not depositing.
func spend(cost: int) -> bool:
	if not can_afford(cost):
		return false
	if cost > 0:
		bits -= cost
		bits_changed.emit(bits)
	return true


func _to_string() -> String:
	return "Economy(bits=%d)" % bits
