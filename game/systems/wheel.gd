class_name Wheel
extends RefCounted
## THE BIG WHEEL. One wheel of forty five equal segments, each painted with a payout tier,
## 1x, 3x, 5x, 10x or 20x; the player stakes chips on as many tiers as she likes, the pointer
## stops on one segment, and a bet on that segment's tier is paid. Every other bet is lost.
## The owner asked for it by name (2026-11-05: "closer to the rust wheel with different
## payout levels"); it replaced a colour and number roulette nobody understood at a glance.
##
## THE CONVENTION, which the felt prints: A TIER OF n PAYS n TO 1. A winning bet hands back
## n times the stake PLUS the stake itself, so 10 chips on 3x come back as 40. That is the
## Rust wheel's own convention and it is the honest reading of a big "3x" painted on a
## segment: you win three times what you put down.
##
## THE ARITHMETIC. A tier of n with c segments returns c (n + 1) / 45 of every chip staked on
## it, over the long run:
##
##   1x   21 segments   21 x 2  / 45 = 42 / 45   house keeps 6.67 per cent
##   3x   11 segments   11 x 4  / 45 = 44 / 45   house keeps 2.22 per cent
##   5x    7 segments    7 x 6  / 45 = 42 / 45   house keeps 6.67 per cent
##   10x   4 segments    4 x 11 / 45 = 44 / 45   house keeps 2.22 per cent
##   20x   2 segments    2 x 21 / 45 = 42 / 45   house keeps 6.67 per cent
##
## WHY FORTY FIVE, and why the five edges are not all equal. The returns 2, 4, 6, 11 and 21 have
## no small common multiple, so no wheel under a few hundred segments makes every tier
## exactly as good as every other. Forty five is the wheel (searched from 20 to 60 segments)
## whose WORST tier is kindest: no bet on it is worse than 6.67 per cent, every bet is between
## 2.22 and 6.67, and the old roulette's 4.0 and the slots' 7.0 bracket it. The lobby sign
## prints the worst tier (house_edge()), because a sign is allowed to be wrong in the player's
## favour and never the other way; the felt prints all five.
##
## Static only; spin() takes the caller's RandomNumberGenerator. Preload by path.

enum Tier { ONE, THREE, FIVE, TEN, TWENTY }

## How many tiers there are, and so how long a bets array is.
const TIERS := 5

## What each tier pays TO ONE, indexed by Tier.
const MULTIPLIERS: Array[int] = [1, 3, 5, 10, 20]

## Equal segments round the wheel.
const SEGMENTS := 45

## THE WHEEL, clockwise from segment 0, as Tier values. Laid out by a search (recorded in
## DECISIONS.md, 2026-11-05) for no two neighbours alike and each rare tier spread as evenly
## round the rim as its count allows: the two 20x segments sit opposite each other and the
## four 10x near the quarters, the way the Rust wheel spreads its own. test_wheel.gd counts it.
const LAYOUT: Array[int] = [4, 1, 0, 2, 0, 3, 0, 1, 0, 1, 0, 2, 0, 1, 0, 1, 3, 0, 2, 0, 1, 0,
	4, 0, 2, 0, 1, 0, 3, 0, 1, 2, 0, 1, 0, 1, 0, 2, 0, 3, 0, 1, 0, 2, 0]

## Player facing tier labels.
const TIER_LABELS: Array[String] = ["1x", "3x", "5x", "10x", "20x"]


## The tier painted on `segment`, or -1 for a segment that is not on the wheel.
static func tier_of(segment: int) -> int:
	if segment < 0 or segment >= SEGMENTS:
		return -1
	return LAYOUT[segment]


## How many segments carry `tier`.
static func segment_count(tier: int) -> int:
	var count := 0
	for painted: int in LAYOUT:
		if painted == tier:
			count += 1
	return count


## Where the pointer stops: 0 to SEGMENTS - 1, uniform.
static func spin(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(0, SEGMENTS - 1)


## Chips staked across every tier. A negative entry counts as nothing, the same way payout()
## treats it.
static func total_staked(bets: Array) -> int:
	var total := 0
	for i: int in mini(bets.size(), TIERS):
		total += maxi(0, int(bets[i]))
	return total


## A fresh, empty bets array: one stake per tier, all zero.
static func empty_bets() -> Array[int]:
	var out: Array[int] = []
	out.resize(TIERS)
	out.fill(0)
	return out


## Chips handed back, THE STAKE INCLUDED; 0 when every bet lost. See Slots.payout() for the
## contract every game in this Palace shares. `bets[t]` is the stake on Tier t; only the
## winning tier's bet comes back, at (multiplier + 1) times. A segment that is not on the
## wheel pays nothing rather than erroring: it arrives from a caller, and a caller that has
## drifted should cost a spin, not the game.
static func payout(bets: Array, segment: int) -> int:
	var tier: int = tier_of(segment)
	if tier < 0 or tier >= bets.size():
		return 0
	var stake: int = int(bets[tier])
	if stake <= 0:
		return 0
	return (MULTIPLIERS[tier] + 1) * stake


## The long run return per chip staked on `tier`: c (n + 1) / SEGMENTS.
static func tier_return(tier: int) -> float:
	if tier < 0 or tier >= TIERS:
		return 0.0
	return float(segment_count(tier) * (MULTIPLIERS[tier] + 1)) / float(SEGMENTS)


static func tier_edge(tier: int) -> float:
	return 1.0 - tier_return(tier)


## WHAT THE LOBBY SIGN PRINTS: the worst tier on the wheel. See the class comment.
static func house_edge() -> float:
	var worst := 0.0
	for tier: int in TIERS:
		worst = maxf(worst, tier_edge(tier))
	return worst


## The kindest tier's edge, for the felt's "between" line.
static func best_edge() -> float:
	var best := 1.0
	for tier: int in TIERS:
		best = minf(best, tier_edge(tier))
	return best


## The felt's own rules, for the rules card and test_published_payouts.gd, which reads every
## "n to 1" here back against payout(). Player facing, so no dashes.
static func rules_lines() -> Array[String]:
	var lines: Array[String] = [
		"%d segments. Stake on any tiers you like; the pointer picks one segment." % SEGMENTS,
	]
	for tier: int in TIERS:
		lines.append("%s pays %d to 1, on %d of %d segments."
			% [TIER_LABELS[tier], MULTIPLIERS[tier], segment_count(tier), SEGMENTS])
	lines.append("The house keeps between %.1f and %.1f bits of every 100."
		% [best_edge() * 100.0, house_edge() * 100.0])
	return lines
