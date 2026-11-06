class_name SpikeTips
extends RefCounted
## WHAT SPIKE TELLS HER WHEN SHE ASKS (PT8; playtest 2026-11-05: "why does spike just sit
## there"). E at Spike gives the most useful thing to know right now, most urgent first; with
## nothing urgent, one of the valley's general tips in turn. A pure function of a small state
## the ranch builds, so the whole ladder reads and tests in one place, like Guide and Objective.
##
## State keys (all optional): hungry (penned ponies past hungry), pantry (food items stocked),
## escapee (name of an Escape Artist in a Paddock), bloom_goal (the story waits on a Bloom),
## drifters (unmarked Drifters penned), bag_full, rare_hint ({region, when} for a rare she has
## not seen, in a place she can reach).

const GENERAL: Array[String] = [
	"Hold right mouse on a pony to scoop her up. The tricky ones wriggle, so keep your aim on her!",
	"Every pony has a favorite food. Toss her a treat she loves and watch her glow!",
	"Ponies in a pen with a friend are happier, and happy ponies make more gems.",
	"Sell gems at the Market, then spend the bits on bigger pens and better gear.",
	"Tumble spots the rare ones. When she shouts, follow the sparkles!",
	"Rain and night bring different ponies out. The valley is never the same twice.",
	"A Big Pen holds eight. Well, six. Eight is the Grand Pen. I always mix those up.",
	"The Depot pays for every pony you send. Your named ponies will ask before they go.",
]


static func pick(s: Dictionary, nth: int) -> String:
	if int(s.get("hungry", 0)) > 0 and int(s.get("pantry", 0)) <= 0:
		return "Your ponies are getting hungry! Grab some hay at the Market. Once it's in the pantry they eat on their own."
	var escapee := String(s.get("escapee", ""))
	if not escapee.is_empty():
		return "%s's an Escape Artist. She hops a Paddock fence at night and comes back at dawn. A Big Pen holds her!" % escapee
	if bool(s.get("bloom_goal", false)) and int(s.get("drifters", 1)) <= 0:
		return "Only Drifters Bloom! Keep one fed and happy in a pen with a friend, and one morning her cutie mark just appears."
	if bool(s.get("bag_full", false)):
		return "Your saddlebag's full! Pen them, or send some to the Depot."
	var rare: Dictionary = s.get("rare_hint", {})
	if not rare.is_empty():
		return "Somepony rare lives in %s, but she only comes out %s. Go and look!" % [
			String(rare.get("region", "the valley")), String(rare.get("when", "sometimes"))]
	return GENERAL[posmod(nth, GENERAL.size())]
