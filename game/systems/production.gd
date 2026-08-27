class_name Production
extends RefCounted
## GEM PRODUCTION -- how a penned pony's happiness turns into gems over time. Phase 1B
## Task 5's pure-logic half; the world-facing half (spawning an actual beamable gem
## pickup in game/world/pen.gd) is a different task and is not touched here.
##
## PURE FUNCTION OF (uid, happiness, hunger, delta), PLUS A LEDGER. tick() takes no clock,
## no RNG and no scene state -- everything it needs comes in through `inst` and `delta`,
## the same discipline game/systems/needs.gd is built under (see its own doc). That is
## what makes "deterministic given the same inputs" true and GUT-testable in milliseconds.
##
## WHY THERE IS A LEDGER AT ALL, AND WHY IT LIVES HERE AND NOT ON PonyInstance. A single
## tick's `delta` is usually a fraction of a second, far less than the time one whole gem
## takes to produce -- so if progress were not remembered between calls, almost every tick
## would round down to zero gems and production would never actually happen except in
## enormous, unrealistic jumps. The natural place for that running total is a field on
## PonyInstance, but this task does not own that file: Task 1 minted it and Task 4
## (game/systems/needs.gd, hunger/happiness rules) is shaping it concurrently on another
## branch. Adding a field here would risk a merge collision over a file this task has no
## business editing. So Production keeps its own ledger instead, a static
## `{uid: StringName -> leftover_progress: float}` Dictionary local to this class.
##
## KEYED BY uid, NEVER BY data_id. Two ponies of the same character (twilight#000001 and
## twilight#000002) must accumulate completely independently -- see
## test_two_different_ponies_do_not_share_progress in test_production.gd. Using data_id
## would silently pool every Twilight's progress into one shared total, which is exactly
## the "contents=[twilight, twilight]" bug pony_instance.gd's own doc comment describes,
## recurring one layer up.
##
## CLEANUP HOOK FOR THE WORLD-FACING HALF. A pony who is released, sold off, or escapes
## the pen (Task 5's other half, in pen.gd) leaves an orphaned entry in this ledger --
## harmless (bounded by however many individuals ever existed in one process) but not
## free. forget(uid) is exposed for whichever world-facing code retires a pony to call;
## nothing in this file calls it itself, since this file has no notion of a pony leaving.
##
## Preloads by path rather than by the global class_name, matching the convention
## documented at the top of game/scripts/pony_rig.gd.

const PonyInstanceScript := preload("res://systems/pony_instance.gd")

## --- TUNING -----------------------------------------------------------------------------
## See the Task 5/6 report (docs/superpowers, or the worktree's scratch report at the time
## this was written) for the real-time pacing this is meant to imply and the reasoning
## behind these specific numbers; they are a starting point for Task 6's shop tuning to
## push back on, not handed-down constants.

## Real seconds for a FULLY happy (happiness == 1.0), unhungry pony to produce one gem.
## 20s: long enough that production reads as "the ranch is working for you" rather than a
## number ticking every frame, short enough that a player who parks at a pen for under a
## minute already sees a gem or two land -- the loop needs to visibly close inside one
## short play session, not just in principle.
const PRODUCTION_PERIOD_SECONDS := 20.0

## Real seconds for a MINIMALLY happy (happiness == 0.0, but not starving) pony to produce
## one gem. Ten times PRODUCTION_PERIOD_SECONDS: an unhappy pony is not a dead pony (the
## project-wide rule), so she still trickles gems, but slowly enough that "keep them happy"
## is a real, felt incentive rather than a purely cosmetic stat. Only STARVING (see below)
## actually zeroes production; happiness alone only ever throttles it.
const NEGLECTED_PERIOD_SECONDS := PRODUCTION_PERIOD_SECONDS * 10.0

## Gems per real second at happiness == 1.0 / happiness == 0.0, derived from the periods
## above so the tuning knobs stay expressed in the human-legible unit (seconds per gem)
## and the rate math lives in one place.
const MAX_RATE_PER_SECOND := 1.0 / PRODUCTION_PERIOD_SECONDS
const MIN_RATE_PER_SECOND := 1.0 / NEGLECTED_PERIOD_SECONDS

## Hunger at or above this fraction of PonyInstance.STATE_MAX counts as STARVING: zero
## production regardless of happiness. Not pinned to exactly STATE_MAX (1.0) -- Task 4's
## needs.gd decays/raises hunger by float increments, and a corrupt-or-lucky value that
## lands at 0.999999 rather than exactly 1.0 should still read as starving rather than
## slip through on a floating-point technicality. 0.95 leaves a 5% band that is
## unambiguously "about to starve" under any plausible needs-tuning without being so wide
## it starts zeroing ponies who are merely quite hungry.
const STARVING_HUNGER_THRESHOLD := PonyInstanceScript.STATE_MAX * 0.95

## {uid: StringName -> leftover_progress: float}. leftover_progress is always in [0, 1) --
## the whole-number part is emitted as gems and only the fraction is kept. Static and
## process-wide for the reason in the class comment: uniqueness of a pony's progress has
## to hold no matter which pen or system last ticked her.
static var _progress: Dictionary = {}


## Advances `inst` by `delta` real seconds and returns how many WHOLE gems she produced
## this call (>= 0). Scaled by inst.happiness between MIN_RATE_PER_SECOND and
## MAX_RATE_PER_SECOND; zero unconditionally while inst.hunger is at/above
## STARVING_HUNGER_THRESHOLD, no matter how happy she is. A pony who is neither happy nor
## starving still trickles gems -- see NEGLECTED_PERIOD_SECONDS above.
##
## `delta <= 0` is refused (returns 0, ledger untouched) rather than banked as negative
## progress or as a free zero-cost gem -- a caller passing a bad delta (a paused frame, a
## clock hiccup) must not be rewarded or punished for it.
static func tick(inst: PonyInstance, delta: float) -> int:
	if inst == null or delta <= 0.0:
		return 0

	if inst.hunger >= STARVING_HUNGER_THRESHOLD:
		return 0

	var rate := _rate_for_happiness(inst.happiness)
	var progress: float = _progress.get(inst.uid, 0.0) + rate * delta
	var gems := int(floor(progress))
	_progress[inst.uid] = progress - float(gems)
	return gems


## Gems per second at `happiness` (clamped to PonyInstance's STATE_MIN..STATE_MAX), linear
## between MIN_RATE_PER_SECOND at 0.0 and MAX_RATE_PER_SECOND at 1.0. Only happiness feeds
## this curve -- hunger's entire effect on production is the binary starving gate in
## tick(), not a second multiplier here, so the two needs stay legible as two separate
## incentives (keep her happy = faster; keep her fed = producing at all) instead of
## compounding into one opaque number.
static func _rate_for_happiness(happiness: float) -> float:
	var h := clampf(happiness, PonyInstanceScript.STATE_MIN, PonyInstanceScript.STATE_MAX)
	return lerpf(MIN_RATE_PER_SECOND, MAX_RATE_PER_SECOND, h)


## A pony's banked fractional progress toward her next gem, in [0, 1). Zero for a pony this
## ledger has never heard of -- which is the same answer as "she has just been forgotten",
## and deliberately so: forget() is defined as making her indistinguishable from a pony who
## has never produced.
##
## READ-ONLY, AND ADDED SO forget() COULD BE PROVEN. Without it, "leaving a pen clears her
## entry" can only be checked by re-penning her and inferring it from when the next gem
## arrives, which is a test that would still pass if forget() merely halved her progress.
static func progress_of(uid: StringName) -> float:
	return float(_progress.get(uid, 0.0))


## Clears one pony's banked fractional progress, as if she had never produced anything.
## Exposed for tests (replaying a tick sequence from a clean slate) and for the
## world-facing half: pen.gd may call this when a pony leaves a pen for any reason other
## than "still in it and still working" -- see the class comment's cleanup-hook note.
static func reset_progress(uid: StringName) -> void:
	_progress.erase(uid)


## Alias for reset_progress(), named for the call site that matters in the real game: a
## pony who is gone (released, sold, escaped) should be forgotten, not merely "reset".
## Kept as a separate name rather than folding callers onto reset_progress() directly so
## intent reads at the call site.
static func forget(uid: StringName) -> void:
	reset_progress(uid)


## Clears every pony's banked progress. Test isolation only -- nothing in normal play
## should ever want to forget the whole ranch's progress at once.
static func clear_all_progress() -> void:
	_progress.clear()
