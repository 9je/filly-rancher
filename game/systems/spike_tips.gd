class_name SpikeTips
extends RefCounted
## WHAT SPIKE TELLS HER WHEN SHE ASKS (PT8; playtest 2026-11-05: "why does spike just sit
## there"). E at Spike gives the most useful thing to know right now, most urgent first; with
## nothing urgent, one of the valley's general tips in turn. A pure function of a small state
## the ranch builds, so the whole ladder reads and tests in one place, like Guide and Objective.
##
## A TIP IS A PICTURE, A FEW WORDS AND A HINT, NOT A PARAGRAPH (P9, playtest 2026-11-10 item
## 33: "Spike's three-line Escape Artist quote ... mechanics should be shown, not paragraphed").
## pick() answers one line in the form
##     Spike[icon]: head | hint
## which the HUD's toast rules (hud.gd TOAST_RULES) draw as a card: the icon from the house
## set, the head in the pill's words, the hint on a cream chip at its end. A head is at most a
## handful of words; a hint says what to do.
##
## State keys (all optional): hungry (penned ponies past hungry), pantry (food items stocked),
## escapee (name of an Escape Artist in a Paddock), bloom_goal (the story waits on a Bloom),
## drifters (unmarked Drifters penned), bag_full, rare_hint ({region, when} for a rare she has
## not seen, in a place she can reach).

## [icon, head, hint] for the general tips, in turn.
const GENERAL: Array = [
	["catch", "Hold right mouse to scoop", "Sneak up behind skittish ones"],
	["apple", "Every pony has a favourite food", "Toss it: she glows"],
	["social", "A friend in the pen", "Happier ponies, more gems"],
	["market", "Sell gems at the Market", "Bits buy bigger pens"],
	["sighting", "Tumble spots the rare ones", "Follow the sparkles"],
	["rain", "Rain and night bring others", "Look again after dark"],
	["pen_grand", "Grand Pen holds eight", "Big Pen holds six"],
	["depot_cart", "The Depot pays per pony", "Named ponies ask first"],
]


static func line(icon: String, head: String, hint: String) -> String:
	return "Spike[%s]: %s | %s" % [icon, head, hint]


static func pick(s: Dictionary, nth: int) -> String:
	if int(s.get("hungry", 0)) > 0 and int(s.get("pantry", 0)) <= 0:
		return line("hay", "Hungry ponies, empty pantry", "Buy hay at the Market, they eat on their own")
	var escapee := String(s.get("escapee", ""))
	if not escapee.is_empty():
		return line("escapee", "%s: Escape Artist" % escapee, "Hops Paddocks at night: Big Pen holds her")
	if bool(s.get("bloom_goal", false)) and int(s.get("drifters", 1)) <= 0:
		return line("drifter_bloom", "Only Drifters Bloom", "Pen one, fed, with a friend")
	if bool(s.get("bag_full", false)):
		return line("bag", "Saddlebag full", "Pen them or send some to the Depot")
	var rare: Dictionary = s.get("rare_hint", {})
	if not rare.is_empty():
		return line("sighting", "Somepony rare: %s" % String(rare.get("region", "the valley")),
			"Out %s" % String(rare.get("when", "sometimes")))
	var tip: Array = GENERAL[posmod(nth, GENERAL.size())]
	return line(String(tip[0]), String(tip[1]), String(tip[2]))
