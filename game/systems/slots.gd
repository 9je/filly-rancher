class_name Slots
extends RefCounted
## THE FAST ONE. Three reels, one strip of sixteen symbols, and a paytable, with the whole
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

enum Symbol { APPLE, HORSESHOE, BELL, GEM, STAR, RAINBOW }

## How many reels spin. Three, and named, because payout() indexes the array it is handed.
const REELS := 3

## Positions on one reel. All three reels share the same strip; a different strip per reel
## would buy nothing except an enumeration nobody could check by hand.
const REEL_SIZE := 16

## Positions given to each symbol, indexed by Symbol. Sums to REEL_SIZE, which
## test_slots.gd asserts rather than trusts.
const STRIP_COUNTS: Array[int] = [5, 4, 3, 2, 1, 1]

## What three of a kind pays, as a multiple of the stake, indexed by Symbol.
const TRIPLE_PAYS: Array[int] = [4, 10, 27, 55, 150, 450]

## Exactly two rainbows on a line that is not a triple.
const TWO_RAINBOW_PAY := 5

## Exactly one rainbow on a line that is not a triple: the stake back, which is the smallest
## honest thing a slot machine can do and is why the reels feel alive at a low stake.
const ONE_RAINBOW_PAY := 1

## Player facing, so no dashes.
const SYMBOL_NAMES: Array[String] = ["Apple", "Horseshoe", "Bell", "Gem", "Star", "Rainbow"]


## One reel's symbols, in strip order. Built rather than authored so it cannot drift from
## STRIP_COUNTS.
static func strip() -> Array[int]:
	var out: Array[int] = []
	for symbol in STRIP_COUNTS.size():
		for i in STRIP_COUNTS[symbol]:
			out.append(symbol)
	return out


## Three symbols, one per reel, drawn uniformly over the strip's positions. Uniform over
## POSITIONS and not over symbols, which is what makes the enumeration in return_to_player()
## correct.
static func spin(rng: RandomNumberGenerator) -> Array[int]:
	var reel: Array[int] = strip()
	var out: Array[int] = []
	for i in REELS:
		out.append(reel[rng.randi_range(0, REEL_SIZE - 1)])
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
## equally likely position triples. 4096 iterations, so this is cheap enough to call from a
## sign that is being drawn.
static func return_to_player() -> float:
	var reel: Array[int] = strip()
	var total := 0
	for a in reel:
		for b in reel:
			for c in reel:
				total += payout([a, b, c], 1)
	return float(total) / float(REEL_SIZE * REEL_SIZE * REEL_SIZE)


## What the house keeps, per unit staked. This is the number on the lobby sign.
static func house_edge() -> float:
	return 1.0 - return_to_player()


## One line per winning combination, for the machine's own paytable panel.
static func paytable_lines() -> Array[String]:
	var lines: Array[String] = []
	for symbol in SYMBOL_NAMES.size():
		lines.append("%s %s %s pays %d to 1"
			% [SYMBOL_NAMES[symbol], SYMBOL_NAMES[symbol], SYMBOL_NAMES[symbol],
				TRIPLE_PAYS[symbol]])
	lines.append("Two Rainbows anywhere pays %d to 1" % TWO_RAINBOW_PAY)
	lines.append("One Rainbow anywhere hands your stake back")
	return lines


## The three symbols as one readable line, for the machine's window and for a toast.
static func line_text(reels: Array[int]) -> String:
	var names: Array[String] = []
	for symbol in reels:
		names.append(SYMBOL_NAMES[symbol] if symbol >= 0 and symbol < SYMBOL_NAMES.size()
			else "?")
	return " ".join(names)
