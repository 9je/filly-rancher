class_name Slots
extends RefCounted
## THE FAST ONE. Three reels, a strip of sixteen symbols on each, and a paytable, with the whole
## of it enumerable: sixteen cubed is 4096 equally likely position triples, so the return to
## player is a fraction this file can WORK OUT rather than a number somebody measured once
## and typed onto a sign.
##
## THAT IS THE POINT OF THE FILE. The Spectra Palace publishes its house edge in the lobby
## (game/systems/casino_sign.gd) and the spec's promise is that the number on the sign is
## real. Here it is real by construction: return_to_player() walks the strip three deep and
## adds up what the paytable pays, so changing a symbol count or a pay changes the sign in
## the same edit, and there is no way to make the sign lie without the tests noticing.
##
## THE ARITHMETIC, IN UNITS OF THE STAKE, over all 4096 position triples:
##
##   three of a kind   125 apple at 4, 64 horseshoe at 10, 27 bell at 27, 8 gem at 55,
##                     1 star at 150, 1 rainbow at 450                          = 2909
##   exactly two rainbows   3 x 15 = 45 outcomes at 5                           =  225
##   exactly one rainbow    3 x 15 x 15 = 675 outcomes at 1 (the stake back)    =  675
##                                                                        total = 3809
##
## 3809 / 4096 back to the player, 287 / 4096 to the house, which is 7.0 per cent. The three
## cases are disjoint: three rainbows is a triple, so it is never also counted as "exactly
## two" or "exactly one".
##
## STATIC ONLY, no state, no scene, no clock. spin() takes the caller's RandomNumberGenerator
## rather than owning one, the same discipline game/systems/needs.gd's tick() takes its delta
## by, so a gate can seed a hundred thousand spins and get the same hundred thousand back.
## Preload by path, never by the class_name.

enum Symbol { APPLE, HORSESHOE, CLOUD, GEM, STAR, RAINBOW }

## How many reels spin. Three, and named, because payout() indexes the array it is handed.
const REELS := 3

## Positions on one reel.
const REEL_SIZE := 16

## Positions given to each symbol ON EVERY REEL, indexed by Symbol. Sums to REEL_SIZE, which
## test_slots.gd asserts rather than trusts.
const STRIP_COUNTS: Array[int] = [5, 4, 3, 2, 1, 1]

## THE REAL STRIPS, one per reel, top to bottom, as Symbol values. The owner's playtest
## (2026-11-05: "the first 2 reels had all 3 the same if its one line why") saw three apples
## stacked in one window: the old single strip was sorted, five apples in a row, so a window
## showing three adjacent positions showed one symbol three times and read as rigged. These
## strips hold the same counts (so the enumeration below, and the edge on the sign, are
## unchanged to the last chip) in an order where ANY THREE ADJACENT POSITIONS, wrapping round,
## are three different symbols; test_slots.gd checks every window of every reel. Three
## different orders, so the reels do not move in lockstep.
const REEL_STRIPS: Array = [
	[1, 0, 2, 1, 0, 4, 1, 0, 3, 2, 5, 0, 1, 2, 0, 3],
	[1, 0, 3, 2, 0, 1, 2, 0, 1, 2, 4, 0, 1, 5, 0, 3],
	[1, 0, 5, 4, 0, 2, 1, 0, 3, 1, 0, 3, 2, 1, 0, 2],
]

## What three of a kind pays, as a multiple of the stake, indexed by Symbol.
const TRIPLE_PAYS: Array[int] = [4, 10, 27, 55, 150, 450]

## Exactly two rainbows on a line that is not a triple.
const TWO_RAINBOW_PAY := 5

## Exactly one rainbow on a line that is not a triple: the stake back, which is the smallest
## honest thing a slot machine can do and is why the reels feel alive at a low stake.
const ONE_RAINBOW_PAY := 1

## Player facing, so no dashes.
const SYMBOL_NAMES: Array[String] = ["Apple", "Horseshoe", "Cloud", "Gem", "Star", "Rainbow"]


## Reel `reel`'s symbols, in strip order, top to bottom. An index off the machine answers the
## first reel rather than erroring.
static func reel_strip(reel: int) -> Array[int]:
	var out: Array[int] = []
	for symbol in REEL_STRIPS[clampi(reel, 0, REELS - 1)]:
		out.append(int(symbol))
	return out


## Every symbol one reel holds, counted rather than ordered: the multiset every reel shares.
## What the enumeration walks, since the order on a strip changes nothing about the odds.
static func strip() -> Array[int]:
	var out: Array[int] = []
	for symbol in STRIP_COUNTS.size():
		for i in STRIP_COUNTS[symbol]:
			out.append(symbol)
	return out


## Three symbols, one per reel, each drawn uniformly over ITS OWN strip's positions. Uniform
## over POSITIONS and not over symbols, and every strip holds STRIP_COUNTS, which is what makes
## the enumeration in return_to_player() correct.
static func spin(rng: RandomNumberGenerator) -> Array[int]:
	var out: Array[int] = []
	for i in REELS:
		out.append(int(REEL_STRIPS[i][rng.randi_range(0, REEL_SIZE - 1)]))
	return out


## Chips handed back to the player for this line, THE STAKE INCLUDED. A loss returns 0. That
## contract is shared by every game in the casino, so the settle at ranch.gd is always the
## same two lines: take the stake, then put this back if it is above zero.
static func payout(reels: Array[int], stake: int) -> int:
	if stake <= 0 or reels.size() != REELS:
		return 0
	if reels[0] == reels[1] and reels[1] == reels[2]:
		return TRIPLE_PAYS[reels[0]] * stake
	var rainbows := 0
	for symbol in reels:
		if symbol == Symbol.RAINBOW:
			rainbows += 1
	if rainbows == 2:
		return TWO_RAINBOW_PAY * stake
	if rainbows == 1:
		return ONE_RAINBOW_PAY * stake
	return 0


## The exact long run return per unit staked, by walking every one of the REEL_SIZE cubed
## equally likely position triples of the three real strips. 4096 iterations, so this is cheap enough to call from a
## sign that is being drawn.
##
## THE STAR BONUS IS IN IT (P9, playtest 2026-11-10 item 50: "slots are a pure money sink
## while blackjack feels fair"). Two Stars on a line win FREE_SPINS spins at that stake, and
## a free spin can win more, so a spin is worth base + p * FREE_SPINS * itself:
## rtp = base / (1 - p * FREE_SPINS). With p = 45 / 4096 that lifts 93.0 to 97.3 per cent:
## closer to the blackjack table, still the house's.
static func return_to_player() -> float:
	var total := 0
	var bonus := 0
	for a in reel_strip(0):
		for b in reel_strip(1):
			for c in reel_strip(2):
				total += payout([a, b, c], 1)
				bonus += bonus_spins([a, b, c])
	var n := float(REEL_SIZE * REEL_SIZE * REEL_SIZE)
	return (float(total) / n) / (1.0 - float(bonus) / n)


## Free spins this line wins: FREE_SPINS for exactly two Stars (three is the Star triple and
## pays as one), else none.
static func bonus_spins(reels: Array) -> int:
	if reels.size() != REELS:
		return 0
	var stars := 0
	for symbol in reels:
		if int(symbol) == Symbol.STAR:
			stars += 1
	return FREE_SPINS if stars == 2 else 0


## Free spins two Stars win (item 50).
const FREE_SPINS := 4


## What the house keeps, per unit staked. This is the number on the lobby sign.
static func house_edge() -> float:
	return 1.0 - return_to_player()


## One line per winning combination, for the machine's own paytable panel.
##
## "RETURNS n FOR 1", NOT "PAYS n TO 1", AND THE DIFFERENCE IS THE PLAYER'S MONEY.
## TRIPLE_PAYS and TWO_RAINBOW_PAY are TOTAL RETURN multipliers: payout() hands back the
## whole of `pay * stake`, the stake included. "n to 1" is the other convention, the one a
## racecourse uses, where the winner takes n PLUS her stake back; printing these constants
## that way overstated every line on the wall by one stake (an "Apple Apple Apple pays 4 to
## 1" that actually returns 4x, a net 3 to 1). "for 1" is the total return wording, and it
## is already this project's own precedent: RaceCard.odds_text() prints its decimal odds,
## which are total return by the same contract, as "%.2f for 1".
##
## game/test/test_published_payouts.gd parses the number back out of every line here, the
## Wheel's rules and Blackjack's placard and applies it to a stake, so no wording on any
## wall in the Palace can drift from what the dealer actually pays again.
static func paytable_lines() -> Array[String]:
	var lines: Array[String] = []
	for symbol in SYMBOL_NAMES.size():
		lines.append("%s %s %s returns %d for 1"
			% [SYMBOL_NAMES[symbol], SYMBOL_NAMES[symbol], SYMBOL_NAMES[symbol],
				TRIPLE_PAYS[symbol]])
	lines.append("Two Rainbows anywhere returns %d for 1" % TWO_RAINBOW_PAY)
	# ONE_RAINBOW_PAY is 1, so this line is already true under either convention: the whole
	# of what comes back is the stake. Left in words because "returns 1 for 1" is a sentence
	# nobody reads as "you broke even".
	lines.append("One Rainbow anywhere hands your stake back")
	lines.append("Two Stars anywhere win %d free spins" % FREE_SPINS)
	return lines


## The three symbols as one readable line, for the machine's window and for a toast.
static func line_text(reels: Array[int]) -> String:
	var names: Array[String] = []
	for symbol in reels:
		names.append(SYMBOL_NAMES[symbol] if symbol >= 0 and symbol < SYMBOL_NAMES.size()
			else "?")
	return " ".join(names)
