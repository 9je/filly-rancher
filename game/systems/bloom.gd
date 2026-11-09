class_name Bloom
extends RefCounted
## THE BLOOM: how a Drifter finds her mark (STORY.md section 1, GDD 4.2). Pure arithmetic
## over one penned pony's circumstances, ticked by the pen; the ceremony and the look change
## happen in the caller when `progress` crosses 1.
##
## THE COLOUR LOOP (P8, docs/sprint-plan-2026-11-08.md section 2.1). The Factory only wants
## colour, so Bloom is the core activity and it has to be fast and readable: a pony in good
## care (fed, her favourite, a friend, room to move) Blooms in GOOD_CARE_SECONDS, every pen
## in parallel. Each shortfall is a MULTIPLIER, never a silent freeze: the owner's packed
## Grand pens froze at CROWDED_AT 7 with nothing on screen to say so (playtest 2026-11-08
## item 2). The one thing holding her back most is status()'s `reason`, which the pen's
## readout shows. Only an empty belly (hungry), a Calm Lamp or a mark she already has stops
## her outright, and the first of those says so.

## Real seconds to Bloom with every bonus active, before her race and quirk (PonyTraits.
## bloom_mult; an earth pony is a fifth quicker).
const GOOD_CARE_SECONDS := 180.0
const BEST_RATE := 1.0 / GOOD_CARE_SECONDS
## Kept for callers that read the old name: the best case is good care.
const BEST_CASE_SECONDS := GOOD_CARE_SECONDS
const RACE_WIN_BONUS := 0.25
## How long a favorite meal keeps her glowing.
const FAVORITE_GLOW_SECONDS := 180.0
## Past this much hunger her pantry has run dry: she is hungry and does not Bloom.
const MAX_HUNGER := 0.75
## Below this she is unhappy, and Blooms at UNHAPPY_FLOOR of the rate (happiness scales
## linearly from there up to full speed at 1.0).
const MIN_HAPPINESS := 0.45
const UNHAPPY_FLOOR := 0.5
## Fed, but not her favourite lately: about four minutes instead of three.
const WRONG_FOOD_MULT := 0.7
## Nopony in the pen she gets on with.
const BORED_MULT := 0.7
## CROWDING IS A SLOPE, NOT A WALL. Up to a pen's comfortable count she has room; each pony
## past it takes CROWD_STEP off her rate, down to CROWD_FLOOR. A full Grand pen (8, two past
## its comfortable 6) runs at 0.6.
const CROWD_STEP := 0.2
const CROWD_FLOOR := 0.35
## Below this multiplier a shortfall is worth naming (a pony at 0.9 is doing fine).
const REASON_BELOW := 0.95

## The reasons, in the order a tie goes to: the first one is the one to fix first.
const HUNGRY := &"hungry"
const WRONG_FOOD := &"wrong_food"
const CROWDED := &"crowded"
const BORED := &"bored"
const LAMP := &"lamp"
const MARKED := &"marked"
const REASON_WORDS := {
	&"hungry": "Hungry: stock the pantry",
	&"wrong_food": "Wants her favourite",
	&"crowded": "Crowded: give her room",
	&"bored": "Bored: needs a friend",
	&"lamp": "Calm Lamp: no Bloom",
	&"marked": "Bloomed",
}


## How many ponies a pen of `capacity` holds before it starts to feel crowded. A Paddock
## (3) never does; a Big pen (6) from its fifth; a Grand pen (8) from its seventh.
static func comfortable_for(capacity: int) -> int:
	return maxi(3, capacity - 2)


## The crowding multiplier for `count` ponies where `comfortable` is the pen's easy number.
static func crowd_mult(count: int, comfortable: int) -> float:
	var over := count - comfortable
	if over <= 0:
		return 1.0
	return maxf(CROWD_FLOOR, 1.0 - CROWD_STEP * float(over))


## Her Bloom right now, as {rate (progress per second), reason (StringName, &"" when she is
## Blooming at full speed), mults ({reason: multiplier})}. `c` describes her:
##   happiness (0..1), hunger (0..1), favorite_glow (seconds left), has_friend (bool),
##   pen_count (int), comfortable (int, the pen's comfortable_for(); default 6),
##   calm_lamp (bool), marked (bool).
static func status(c: Dictionary) -> Dictionary:
	if bool(c.get("marked", false)):
		return {"rate": 0.0, "reason": MARKED, "mults": {}}
	if bool(c.get("calm_lamp", false)):
		return {"rate": 0.0, "reason": LAMP, "mults": {}}
	if float(c.get("hunger", 0.0)) > MAX_HUNGER:
		return {"rate": 0.0, "reason": HUNGRY, "mults": {HUNGRY: 0.0}}
	var happiness: float = clampf(float(c.get("happiness", 0.5)), 0.0, 1.0)
	var happy := lerpf(UNHAPPY_FLOOR, 1.0, clampf((happiness - MIN_HAPPINESS) / (1.0 - MIN_HAPPINESS), 0.0, 1.0)) \
		if happiness >= MIN_HAPPINESS else UNHAPPY_FLOOR
	var mults := {
		WRONG_FOOD: 1.0 if float(c.get("favorite_glow", 0.0)) > 0.0 else WRONG_FOOD_MULT,
		CROWDED: crowd_mult(int(c.get("pen_count", 1)), int(c.get("comfortable", 6))),
		# Unhappiness reads as boredom: nothing to do, nopony to do it with.
		BORED: (1.0 if bool(c.get("has_friend", false)) else BORED_MULT) * happy,
	}
	var rate := BEST_RATE
	var reason: StringName = &""
	var worst := REASON_BELOW
	for key: StringName in [WRONG_FOOD, CROWDED, BORED]:
		var m: float = mults[key]
		rate *= m
		if m < worst:
			worst = m
			reason = key
	return {"rate": rate, "reason": reason, "mults": mults}


## Progress gained over `delta` seconds under `c` (see status()).
static func gain(c: Dictionary, delta: float) -> float:
	return float(status(c)["rate"]) * maxf(delta, 0.0)


## The words for `reason`. `favorite` names her favourite food for WRONG_FOOD.
static func reason_words(reason: StringName, favorite: String = "") -> String:
	if reason == WRONG_FOOD and not favorite.is_empty():
		return "Wants %s" % favorite
	return String(REASON_WORDS.get(reason, ""))


## A race win's one-off push ("her talent is speed!").
static func race_win() -> float:
	return RACE_WIN_BONUS


## Two penned ponies are friends when their personalities get along: bold with shy,
## curious with anyone, shy with shy.
static func are_friends(a: int, b: int) -> bool:
	const SHY := 0
	const BOLD := 1
	const CURIOUS := 2
	if a == CURIOUS or b == CURIOUS:
		return true
	if (a == BOLD and b == SHY) or (a == SHY and b == BOLD):
		return true
	return a == SHY and b == SHY


## Seconds to Bloom from zero under `c`, or INF if she never will (for tests and the UI).
static func seconds_to_bloom(c: Dictionary) -> float:
	var per := gain(c, 1.0)
	return INF if per <= 0.0 else 1.0 / per
