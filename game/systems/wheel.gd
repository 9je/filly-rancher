class_name Wheel
extends RefCounted
## THE RAINBOW WHEEL. Roulette without the layout: back a colour or back a number, one
## pocket of house edge either way, and no bet on the felt that is worse than the sign says.
##
## TWENTY FIVE POCKETS. Pocket 0 is the Cloudsdale house pocket: it has no colour, no number
## may be laid on it, and it beats every bet on the wheel. Pockets 1 to 24 run in six colour
## bands of four, in rainbow order, which is where the wheel gets its name and its paint.
##
## WHY THE EDGE IS THE SAME ON BOTH BETS, and why that is worth a test. A number wins one
## time in twenty five and pays 23 to 1, so it hands back 24 stakes on a win, 24 / 25 of a
## stake on average. A colour wins four times in twenty five and pays 5 to 1, so it hands
## back 6 stakes on a win, 24 / 25 on average. Both are one pocket, 4.0 per cent, which is
## what the lobby sign prints. A casino where the pretty bet is the bad bet is a casino that
## is quietly lying to a player who has not done the arithmetic, and this one does not.
##
## Static only; spin() takes the caller's RandomNumberGenerator. Preload by path.

enum Colour { RED, ORANGE, YELLOW, GREEN, BLUE, VIOLET, HOUSE }
enum Bet { NUMBER, COLOUR }

## Numbers on the wheel, 1 to NUMBERS.
const NUMBERS := 24

## Numbers per colour band.
const COLOUR_RUN := 4

## The colourless pocket the house owns.
const HOUSE_POCKET := 0

## Every pocket, the house one included.
const POCKETS := NUMBERS + 1

## A number bet pays this to one, so a winner takes back this plus her stake.
const NUMBER_PAYS_TO_ONE := 23

## A colour bet pays this to one.
const COLOUR_PAYS_TO_ONE := 5

## Player facing, so no dashes. Indexed by Colour, with the house pocket last.
const COLOUR_NAMES: Array[String] = ["Red", "Orange", "Yellow", "Green", "Blue", "Violet",
	"Cloudsdale"]


## The colour band a pocket belongs to. The house pocket answers Colour.HOUSE, which no bet
## may name, so it wins nothing for anybody.
static func colour_of(pocket: int) -> int:
	if pocket < 1 or pocket > NUMBERS:
		return Colour.HOUSE
	return (pocket - 1) / COLOUR_RUN


## Where the ball lands: 0 to NUMBERS inclusive, uniform.
static func spin(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(0, NUMBERS)


## Chips handed back, THE STAKE INCLUDED; 0 for a loss. See Slots.payout() for the contract.
##
## A bet naming something that is not on the wheel loses rather than erroring: `guess` comes
## in from a menu, and a menu that has drifted should cost the player one stake and a raised
## eyebrow rather than take the game down.
static func payout(kind: int, guess: int, pocket: int, stake: int) -> int:
	if stake <= 0:
		return 0
	match kind:
		Bet.NUMBER:
			if guess < 1 or guess > NUMBERS:
				return 0
			return (NUMBER_PAYS_TO_ONE + 1) * stake if guess == pocket else 0
		Bet.COLOUR:
			if guess < 0 or guess >= Colour.HOUSE:
				return 0
			return (COLOUR_PAYS_TO_ONE + 1) * stake if colour_of(pocket) == guess else 0
	return 0


## The long run return per unit staked. The same for a number and for a colour; the number
## bet's form is the one written out here because it is the shorter of the two, and
## test_wheel.gd checks the colour bet's form against it.
static func return_to_player() -> float:
	return float(NUMBER_PAYS_TO_ONE + 1) / float(POCKETS)


## What the house keeps: exactly one pocket.
static func house_edge() -> float:
	return 1.0 - return_to_player()


## What the ball did, as a line the felt can show.
static func pocket_text(pocket: int) -> String:
	if pocket < 1 or pocket > NUMBERS:
		return "Cloudsdale pocket. The house takes this one."
	return "%d, %s" % [pocket, COLOUR_NAMES[colour_of(pocket)]]


## The felt's own rules, for the table panel.
static func rules_lines() -> Array[String]:
	return [
		"The Wheel: %d pockets, %d numbers in six colours, and one for us."
			% [POCKETS, NUMBERS],
		"A number pays %d to 1. A colour pays %d to 1."
			% [NUMBER_PAYS_TO_ONE, COLOUR_PAYS_TO_ONE],
		"Both bets are worth the same; we did the arithmetic so you can check it.",
		"The Cloudsdale pocket is ours. It comes up one spin in %d." % POCKETS,
	]
