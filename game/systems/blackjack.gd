class_name Blackjack
extends RefCounted
## ONE DECK, DEALER STANDS ON SEVENTEEN, and the rules on a placard. The quiet game in the
## corner of the Spectra Palace.
##
## WHY THIS GAME'S PUBLISHED EDGE IS MEASURED AND THE OTHER THREE ARE COMPUTED. Slots and
## the Wheel have an edge that belongs to the machine, so it can be enumerated exactly.
## Blackjack's edge belongs to the machine AND to how the player plays, so a bare number
## would mean nothing. So the placard prints a strategy card, "draw below 17, stand on 17 or
## more", and the published number is the edge AGAINST THAT CARD, measured over
## REFERENCE_HANDS hands from REFERENCE_SEED by this same code. PUBLISHED_EDGE is that
## measurement written down; test_blackjack.gd re measures it every run and fails if the
## placard has drifted from the dealer by more than a rounding. A player who plays better
## than the card does better than the sign says, which is the direction a sign is allowed to
## be wrong in.
##
## THE CARDS. A card is an int 0 to 51 and its rank is card % 13: rank 0 is an ace, worth 11
## until the hand would bust and then worth 1; ranks 1 to 8 are the two through the nine;
## ranks 9 to 12 are the ten, jack, queen and king, all worth 10. Suits exist only so that a
## single deck holds four of each rank, which is what makes the odds a one deck game's odds.
##
## THE DEAL is a partial Fisher Yates over a fresh deck per hand: swap a random undealt card
## to the front of the undealt tail and take it. One swap per card rather than fifty two per
## hand, which is what lets the gate deal a hundred thousand hands in seconds.
##
## DOUBLING YES, SPLITTING AND INSURANCE NO (2026-11-05). The table gained real decisions
## (game/systems/blackjack_round.gd): Hit, Stand, and Double on the first two cards. A split is
## a second hand the felt would have to lay out and insurance is a side bet on the dealer's
## hole card; neither was asked for, and both stay off the placard.
##
## Static only; play_hand() takes the caller's RandomNumberGenerator. Preload by path.

enum Outcome { DEALER_WIN, PLAYER_WIN, PUSH, PLAYER_BLACKJACK }

const DECK_SIZE := 52
const RANKS := 13

## The dealer draws below this and stands on it, hard or soft. One number, because there is
## no soft 17 exception at this table and the placard says so.
const DEALER_STANDS_ON := 17

## The house strategy card the published edge is measured against.
const STRATEGY_DRAWS_BELOW := 17

## Blackjack pays three to two.
const BLACKJACK_PAYS_NUMERATOR := 3
const BLACKJACK_PAYS_DENOMINATOR := 2

## The seed and the sample size the published number was measured over. Constants rather
## than magic numbers in the test, so re measuring it is one call with no arguments to
## remember.
const REFERENCE_SEED := 20260902
const REFERENCE_HANDS := 100000

## Chips staked per hand while measuring. A hundred, so the three to two bonus (150) is a
## whole number of chips and the measurement carries no rounding of its own.
const REFERENCE_STAKE := 100

## WHAT THE PLACARD PUBLISHES: the long run house edge against the strategy card, measured
## by measure_edge(REFERENCE_SEED, REFERENCE_HANDS) on 2026-08-31. Written down rather than
## computed at draw time because a hundred thousand hands is not something a sign should do
## while the player is looking at it. test_blackjack.gd re measures it on every suite run,
## so this number cannot drift from the dealer without the suite going red.
const PUBLISHED_EDGE := 0.0520

const RANK_NAMES: Array[String] = ["Ace", "Two", "Three", "Four", "Five", "Six", "Seven",
	"Eight", "Nine", "Ten", "Jack", "Queen", "King"]


static func is_ace(card: int) -> bool:
	return card % RANKS == 0


## An ace counts 11 here; hand_total() demotes it when it has to.
static func card_value(card: int) -> int:
	var rank: int = card % RANKS
	if rank == 0:
		return 11
	if rank >= 9:
		return 10
	return rank + 1


## The best total this hand can make at or under 21, or the busted total if it cannot.
static func hand_total(cards: Array[int]) -> int:
	var total := 0
	var aces := 0
	for card in cards:
		total += card_value(card)
		if is_ace(card):
			aces += 1
	while total > 21 and aces > 0:
		total -= 10
		aces -= 1
	return total


## Twenty one on the first two cards, and only on the first two.
static func is_blackjack(cards: Array[int]) -> bool:
	return cards.size() == 2 and hand_total(cards) == 21


## Deal and play one hand BY THE HOUSE STRATEGY CARD. Returns
## {"player": Array[int], "dealer": Array[int], "outcome": int}.
##
## THE TABLE NO LONGER PLAYS THIS FOR HER. Since the 2026-11-05 playtest she makes her own
## decisions through game/systems/blackjack_round.gd; this is the reference player the
## published edge is measured against, and it plays through that same class so the measured
## dealer and the dealer she sits down with are one piece of code. The card never doubles.
static func play_hand(rng: RandomNumberGenerator) -> Dictionary:
	var hand: RefCounted = (load("res://systems/blackjack_round.gd") as GDScript) \
		.call("deal", rng, REFERENCE_STAKE)
	while not bool(hand.call("is_settled")) \
			and int(hand.call("player_total")) < STRATEGY_DRAWS_BELOW:
		hand.call("hit")
	if not bool(hand.call("is_settled")):
		hand.call("stand")
	return {"player": hand.get("player"), "dealer": hand.get("dealer"),
		"outcome": int(hand.get("outcome"))}


## Chips handed back, THE STAKE INCLUDED; 0 for a loss. See Slots.payout() for the contract
## every game in this casino shares.
##
## The three to two bonus uses integer division, so a stake with an odd number of chips
## rounds the bonus down by half a chip. Every stake the table offers is even
## (game/ui/blackjack_menu.gd), so it never bites; it is written this way rather than in
## floats because a chip is a whole thing.
static func payout(outcome: int, stake: int) -> int:
	if stake <= 0:
		return 0
	match outcome:
		Outcome.PLAYER_BLACKJACK:
			return stake + (stake * BLACKJACK_PAYS_NUMERATOR) / BLACKJACK_PAYS_DENOMINATOR
		Outcome.PLAYER_WIN:
			return stake * 2
		Outcome.PUSH:
			return stake
	return 0


## The house's long run share of a chip staked, over `hands` hands played from `seed` by the
## strategy card. This is the measurement PUBLISHED_EDGE is a copy of.
static func measure_edge(seed_value: int, hands: int) -> float:
	if hands <= 0:
		return 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var staked := 0
	var returned := 0
	for i in hands:
		staked += REFERENCE_STAKE
		returned += payout(int(play_hand(rng)["outcome"]), REFERENCE_STAKE)
	return 1.0 - (float(returned) / float(staked))


## What the lobby sign prints for this table. A constant rather than a measurement, for the
## reason PUBLISHED_EDGE's own comment gives.
static func house_edge() -> float:
	return PUBLISHED_EDGE


static func card_text(card: int) -> String:
	return RANK_NAMES[card % RANKS]


## What just happened, in one line, for the table and for a toast.
static func outcome_text(hand: Dictionary) -> String:
	match int(hand.get("outcome", Outcome.DEALER_WIN)):
		Outcome.PLAYER_BLACKJACK:
			return "Blackjack. Pays three to two."
		Outcome.PLAYER_WIN:
			return "You win."
		Outcome.PUSH:
			return "Push. Your stake comes back."
	return "Dealer wins."


## The placard on the table. Player facing, so no dashes.
static func placard_lines() -> Array[String]:
	return [
		"One deck, shuffled before every hand.",
		"The dealer's second card stays face down until you stand.",
		"Dealer draws to 16 and stands on %d, hard or soft." % DEALER_STANDS_ON,
		"Blackjack pays %d to %d. A tie is a push."
			% [BLACKJACK_PAYS_NUMERATOR, BLACKJACK_PAYS_DENOMINATOR],
		"Double on your first two cards: twice the stake, one more card.",
		"Split a pair once into two hands, one more card each; split aces stand. No insurance.",
		"The lobby sign's edge is for the house card: draw below %d, never double."
			% STRATEGY_DRAWS_BELOW,
	]
