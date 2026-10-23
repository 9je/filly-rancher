class_name Needs
extends RefCounted
## Hunger and happiness RULES for a PonyInstance (game/systems/pony_instance.gd). The
## pure-logic half of Phase 1B Task 4 -- the world-facing half (a garden that grows food
## over time, dropping food in a pen, the HUD showing these numbers) is a separate task and
## does not live here. Static-only helper, never instantiated, mirroring Gait
## (game/systems/gait.gd) -- preload it by path in callers rather than relying on the
## `class_name` global (the class cache lives in the gitignored game/.godot/ and a fresh
## clone has not built it yet, same convention as everywhere else in this project).
##
## PURE ON PURPOSE. tick() takes `delta` as a parameter instead of reading a clock or a
## Node's _process() -- so this file has no scene dependency, no timer, no randomness, and
## calling it twice with the same inputs always produces the same outputs (see
## test_needs.gd's "two half ticks equal one whole tick" case). That is what makes it
## GUT-testable in milliseconds today, and what lets Task 5's production timers (which DO
## live on a ticking Node) drive this file forward every frame without this file ever
## knowing a frame happened.
##
## PonyInstance (game/systems/pony_instance.gd) owns STORING happiness/hunger and clamping
## them to STATE_MIN..STATE_MAX; this file owns the RULES that move them -- see that file's
## own comment on the split. Every write in here goes back through PonyInstance's own
## STATE_MIN/STATE_MAX constants rather than redeclaring the range, so the two files cannot
## silently disagree about what "full" or "starving" means.
##
## --- THE NUMBERS, IN REAL-TIME TERMS (a later task tunes the economy against these; this
## is what they were meant to mean when chosen) --------------------------------------
##
## HUNGER: 0 (just fed) to 1 (starving), rising at a constant rate with no fed-then-decays
## curve -- a neglected pony, never fed, goes from full to starving in exactly
## HUNGER_FULL_TO_STARVING_SECONDS = 600s, i.e. TEN MINUTES of real, uninterrupted play.
## Chosen so a player pottering around the ranch -- catching one more pony, building a
## plot, walking to the market -- has real slack before anyone needs attention, but a
## whole play session of pure neglect matters: nobody starves (no pony ever dies -- the
## project-wide rule), but Task 5's escape timer has room to fire well before this file's
## own hunger value could ever max out on its own.
##
## HAPPINESS DECAY: does NOT drain on a timer regardless of hunger -- it only drains once
## hunger crosses HUNGRY_THRESHOLD (0.5, halfway to starving), and then at a constant rate.
## A pony who is topped up stays exactly as happy as she was, however long you leave her --
## happiness is not a second countdown stacked on top of hunger, it is a CONSEQUENCE of
## being hungry. Once hungry, she loses all her happiness (1.0 -> 0.0) over
## HAPPY_DECAY_HUNGRY_TO_ZERO_SECONDS = 240s (FOUR MINUTES) if never fed -- deliberately
## faster than hunger climbs, so "I let her go hungry" is felt in her mood well before she
## is anywhere near starving, which is the whole point of tracking two numbers instead of
## one.
##
## FEEDING: always fully satiates on success (hunger -> STATE_MIN), regardless of which
## food. This is deliberate simplicity, not an oversight: it makes "how often do I need to
## feed her" reduce to hunger's own 600s fill time with no second curve to reason about,
## and it means the FOOD CHOICE is entirely about happiness, not about hunger-efficiency --
## which is where favourite-vs-neutral belongs, since the spec ties it to mood, not to
## belly. A favourite food (PonyData.favorite_foods) is worth +0.25 happiness; a neutral
## one +0.10 -- so from a completely unhappy pony (0.0), FOUR feedings of her favourite, or
## TEN of anything else, reaches full happiness (1.0). The 2.5x ratio is chosen to make
## "learn what she likes" a real, felt payoff without making a neutral food useless -- it
## still moves the needle, just slower.

const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const FoodRegistryScript := preload("res://systems/food_registry.gd")
const PonyTraitsScript := preload("res://systems/pony_traits.gd")

## Directory the shared food registry lazily loads from when nobody has injected one --
## same path convention as PonyInstance's ROSTER_DIR.
const FOOD_DIR := "res://data/foods"

## See the class comment's real-time-pacing section: 600s (10 min), 0 -> STATE_MAX hunger,
## for a pony who is never fed at all.
const HUNGER_FULL_TO_STARVING_SECONDS := 600.0
const HUNGER_PER_SECOND := 1.0 / HUNGER_FULL_TO_STARVING_SECONDS

## Hunger level (STATE_MIN..STATE_MAX) above which a pony counts as "hungry" for the
## purpose of happiness decay. Below this, however long she goes un-fed, happiness does
## not move -- see the class comment.
const HUNGRY_THRESHOLD := 0.5

## See the class comment: 240s (4 min), STATE_MAX -> STATE_MIN happiness, for a pony held
## continuously above HUNGRY_THRESHOLD and never fed.
const HAPPY_DECAY_HUNGRY_TO_ZERO_SECONDS := 240.0
const HAPPY_DECAY_PER_SECOND := 1.0 / HAPPY_DECAY_HUNGRY_TO_ZERO_SECONDS

## Happiness gained from one successful feeding. See the class comment for the reasoning
## behind the 2.5x ratio between these two.
const FAVORITE_HAPPINESS_BONUS := 0.25
const NEUTRAL_HAPPINESS_BONUS := 0.10

## The shared food registry, lazily loaded from FOOD_DIR on first use; injectable via
## set_food_registry() so a test does not have to hit disk, mirroring
## PonyInstance._registry / set_registry() exactly.
static var _food_registry: FoodRegistry = null


## Point food lookups at a registry of your own, or `null` to make the next lookup lazily
## reload FOOD_DIR. See PonyInstance.set_registry()'s comment -- same pattern, same reason.
static func set_food_registry(registry: FoodRegistry) -> void:
	_food_registry = registry


## The registry food lookups go through, loading FOOD_DIR on first use. Never null.
static func get_food_registry() -> FoodRegistry:
	if _food_registry == null:
		_food_registry = FoodRegistryScript.new()
		_food_registry.load_all(FOOD_DIR)
	return _food_registry


## The FoodData named by `food_id`, or NULL if this build has never heard of it. NULL is a
## supported answer -- see FoodRegistry.by_id()'s comment; feed() relies on this to refuse
## an unknown food_id rather than crash.
static func resolve_food(food_id: StringName) -> FoodData:
	return get_food_registry().by_id(food_id)


## Whether `food_id` is one of `inst`'s own character's favourites (PonyData.favorite_foods,
## game/systems/pony_data.gd). False for a null instance or a character record that failed
## to resolve -- see PonyInstance.data()'s own "null is a supported answer" comment; a pony
## whose character record is missing on this build has no favourites either, not a crash.
static func is_favorite(inst: PonyInstance, food_id: StringName) -> bool:
	if inst == null:
		return false
	# A Drifter's favorite is her own (game/systems/pony_traits.gd), not her stock record's.
	if inst.is_stock():
		return food_id == PonyTraitsScript.favorite_of(inst)
	var record := inst.data()
	if record == null:
		return false
	return food_id in record.favorite_foods


## Advance `inst`'s hunger by `delta` seconds of elapsed, un-fed time, and let happiness
## decay if she is hungry enough for it to matter. See the class comment for the exact
## rates and the real-time pacing they imply.
##
## `delta <= 0.0` is a no-op rather than an error: a caller mid-integration (e.g. Task 5's
## production timer skipping a paused frame) should be able to call this unconditionally
## without special-casing a zero tick, and a NEGATIVE delta must not be allowed to run
## hunger or happiness backwards -- there is no code path in this project that legitimately
## un-ticks time.
static func tick(inst: PonyInstance, delta: float) -> void:
	if inst == null or delta <= 0.0:
		return

	inst.hunger = clampf(
		inst.hunger + HUNGER_PER_SECOND * delta,
		PonyInstanceScript.STATE_MIN, PonyInstanceScript.STATE_MAX)

	if inst.hunger > HUNGRY_THRESHOLD:
		inst.happiness = clampf(
			inst.happiness - HAPPY_DECAY_PER_SECOND * delta,
			PonyInstanceScript.STATE_MIN, PonyInstanceScript.STATE_MAX)


## Feed `inst` one unit of `food_id`. Returns false -- and changes NOTHING at all -- for a
## null instance or a food_id with no matching FoodData, mirroring Storage.store()'s
## contract of "a refusal touches no state". On success, hunger is fully reset to
## STATE_MIN and happiness rises by FAVORITE_HAPPINESS_BONUS (if `food_id` is one of
## `inst`'s character's favourites) or NEUTRAL_HAPPINESS_BONUS otherwise, clamped to
## STATE_MAX.
static func feed(inst: PonyInstance, food_id: StringName) -> bool:
	if inst == null:
		return false

	var food := resolve_food(food_id)
	if food == null:
		return false

	inst.hunger = PonyInstanceScript.STATE_MIN

	var bonus := FAVORITE_HAPPINESS_BONUS if is_favorite(inst, food_id) else NEUTRAL_HAPPINESS_BONUS
	inst.happiness = clampf(
		inst.happiness + bonus, PonyInstanceScript.STATE_MIN, PonyInstanceScript.STATE_MAX)

	return true
