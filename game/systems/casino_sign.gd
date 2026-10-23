class_name CasinoSign
extends RefCounted
## THE SIGN IN THE LOBBY, and it is the whole ethical position of this building.
##
## The spec's line is that the casino "is honest: real odds, house edge published on the
## lobby sign, never rigged". So the sign does not carry numbers somebody typed onto it. It
## ASKS EACH GAME what its edge is, and each game answers with a number it worked out from
## its own strip, its own pockets or its own takeout, or in blackjack's case measured against
## the strategy card on its own placard. There is no way to change what the house keeps
## without changing what this sign says in the same edit, which is what makes the promise
## structural instead of aspirational.
##
## THE REGISTER IS GLITZY CORPORATE, the same voice game/systems/letters.gd writes in: a
## welcome, an exclamation mark, and one line at the bottom that is funnier than it should
## be. Nothing here is grim. Player facing, so no dashes anywhere.
##
## Static only, no state, no scene. Preload by path.

const SlotsScript := preload("res://systems/slots.gd")
const WheelScript := preload("res://systems/wheel.gd")
const BlackjackScript := preload("res://systems/blackjack.gd")
const RaceCardScript := preload("res://systems/race_card.gd")
const CasinoScript := preload("res://systems/casino.gd")

const HEADLINE := "Spectra Palace"
const SPONSOR := "proudly sponsored by Brightsky Weather Company"

## What the outdoor marquee says, in one line, for the sign on the approach.
const MARQUEE := "Spectra Palace, proudly sponsored by Brightsky Weather Company"


## THE MARQUEE, AS TWO LINES RATHER THAN ONE. MARQUEE above is the whole sentence, and it
## is still what the lobby sign and the toast say; the board outside is a headline with the
## sponsor under it in smaller letters, because 66 characters on one line across a 14 metre
## building is exactly the sign the owner could not read (2026-08-31).
static func marquee_headline() -> String:
	return HEADLINE


static func marquee_sponsor() -> String:
	return SPONSOR


## One published edge, as a line a person can check with a pencil. Bits in a hundred rather
## than a percentage sign, because "the house keeps 7 of every 100" is a sentence and "7%"
## is a number you can nod at without reading.
static func edge_line(game_name: String, edge: float) -> String:
	return "%s: the house keeps %.1f bits of every 100 wagered." % [game_name, edge * 100.0]


## Everything the lobby sign says, top to bottom. No blank spacer lines: every entry is a
## sentence a player can read, because the sign panel has no room to waste on a gap and the
## sign gate checks that every line on it says something.
static func lines() -> Array[String]:
	return [
		HEADLINE,
		SPONSOR,
		"The odds on this sign are the real ones.",
		"We print them because we do not need to hide them.",
		edge_line("Slots", SlotsScript.house_edge()),
		edge_line("The Wheel", WheelScript.house_edge()),
		edge_line("Blackjack", BlackjackScript.house_edge()),
		edge_line("Racing", RaceCardScript.TAKEOUT),
		"Blackjack is measured against the card on the placard.",
		"Play better than the card and you do better than that.",
		"Please gamble responsibly. Your ponies are counting on you!",
	]


## What is written on the cage counter itself.
static func cage_lines() -> Array[String]:
	return [
		"The cage: %d bit buys one chip, and one chip cashes out for %d bit."
			% [CasinoScript.CHIP_RATE, CasinoScript.CHIP_RATE],
		"We take nothing at this window. We take it at the tables,",
		"and we told you exactly how much on the way in.",
	]


## THE SAME THING, SHORT ENOUGH TO SIT ABOVE THE AMOUNTS ON THE CAGE PAGE. The owner,
## 2026-08-31: "the cage explains itself (bits to chips, one to one, both ways)". A page of
## bare amounts is a page a player leaves without knowing what a chip is.
##
## THREE LINES AND NOT FIVE, because the rows underneath are what she came for and a wall
## of text above them is the same problem in the other direction.
static func cage_explainer() -> Array[String]:
	return [
		"Bits buy chips one for one, and chips cash out one for one, both ways.",
		"The cage keeps nothing. The tables keep what the House rules page says.",
		"",
	]
