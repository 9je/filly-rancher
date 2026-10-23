class_name Bloom
extends RefCounted
## THE BLOOM: how a Drifter finds her mark (STORY.md section 1, GDD 4.2). Pure arithmetic
## over one penned pony's circumstances, ticked by the pen; the ceremony and the look change
## happen in the caller when `progress` crosses 1.
##
## Tuned to the GDD's curve: a well-kept pony (fed her favorite recently, a friend in the
## pen, happy) Blooms in about BEST_CASE_SECONDS of play; a merely fed one takes about three
## times as long; a hungry, lonely or Calm-Lamped one never does.

## Real seconds to Bloom with every bonus active.
const BEST_CASE_SECONDS := 360.0
const BASE_RATE := 1.0 / (BEST_CASE_SECONDS * 3.0)
const FAVORITE_BONUS := 1.0
const FRIEND_BONUS := 0.6
const RACE_WIN_BONUS := 0.25
## How long a favorite meal keeps her glowing.
const FAVORITE_GLOW_SECONDS := 180.0
const MIN_HAPPINESS := 0.45
const MAX_HUNGER := 0.75
const CROWDED_AT := 6
## Scales the whole curve so the best case lands exactly on BEST_CASE_SECONDS: at full
## happiness the rate doubles and both bonuses stack to 2.6x, so 3 / (2 * 2.6).
const BALANCE := 3.0 / (2.0 * (1.0 + FAVORITE_BONUS + FRIEND_BONUS))


## Progress gained over `delta` seconds. `c` describes her now:
##   happiness (0..1), hunger (0..1), favorite_glow (seconds left), has_friend (bool),
##   pen_count (int), calm_lamp (bool), marked (bool).
static func gain(c: Dictionary, delta: float) -> float:
	if bool(c.get("marked", false)) or bool(c.get("calm_lamp", false)):
		return 0.0
	var happiness: float = c.get("happiness", 0.5)
	if happiness < MIN_HAPPINESS or float(c.get("hunger", 0.0)) > MAX_HUNGER:
		return 0.0
	if int(c.get("pen_count", 1)) >= CROWDED_AT:
		return 0.0
	var rate := BASE_RATE * (1.0 + (happiness - MIN_HAPPINESS) / (1.0 - MIN_HAPPINESS))
	var mult := 1.0
	if float(c.get("favorite_glow", 0.0)) > 0.0:
		mult += FAVORITE_BONUS
	if bool(c.get("has_friend", false)):
		mult += FRIEND_BONUS
	return rate * mult * maxf(delta, 0.0) * BALANCE


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
