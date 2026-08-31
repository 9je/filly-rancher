class_name Interaction
extends RefCounted
## WHAT THE E KEY DOES, RIGHT HERE, RIGHT NOW. Exactly one answer per frame, chosen by a
## stated order rather than by whichever handler happened to be called first.
##
## THE BUG THIS REPLACES. game/world/ranch.gd used to run five _update_*_interaction()
## functions in sequence, each with its own "fire once per approach" latch, and four of the
## five additionally refused to act unless _prompt_slot was null. _prompt_slot is written
## by the plot handler, which returns BEFORE writing it whenever any menu is open, so it
## went stale while a menu was up and the next E press after closing one could land on the
## wrong handler. Add to that a prompt that was a fading toast rather than a line on the
## screen, and "pressing e to build a new paddock doesnt always work; gets confused if you
## got ponies" is the report you get (owner, 2026-08-31).
##
## PURE, AND THAT IS THE POINT. Nothing here reads Input, touches a node, opens a menu or
## knows what a Pen is. ranch.gd gathers candidates out of the world and performs the
## winner; this file only decides which one wins and what the prompt says. That is what
## makes the priority order a thing a test can pin, which it could not be while it was an
## emergent property of the order of five function calls.
##
## Static only, no state. Preload by path.

## The verbs E can carry. NONE is the absence of a candidate and never appears in PRIORITY.
enum Kind { NONE, PLOT_BUILD, PEN_MOVE_IN, MARKET, BOARD, DEPOT, PALACE }

## THE ORDER, HIGHEST FIRST, and every one of these positions is a decision.
##
## GROUND YOU ARE STANDING ON BEATS GROUND YOU ARE STANDING NEAR. The two plot kinds lead
## because a slot's trigger box is a square the player deliberately walked into, and a
## building's radius is a circle she walked past.
##
## THE MARKET BEATS THE BOARD, which is the rule ranch.gd's is_near_board() used to carry
## as a hard coded "and not is_near_market()" clause. The board stands five metres from the
## Market's origin and the two radii meet in the middle; the Market is the older and the
## busier of the two and keeps the ground. Now it is one line in one list instead of a
## clause hidden inside a predicate.
##
## THE DEPOT AND THE PALACE ARE LAST because they are the two biggest buildings with the
## two widest radii (4.0 m and 5.0 m), so if a future map ever does overlap one of them
## with something smaller, the smaller thing wins, which is the answer a player expects
## from a big building with a small thing in front of it.
const PRIORITY: Array[int] = [Kind.PLOT_BUILD, Kind.PEN_MOVE_IN, Kind.MARKET, Kind.BOARD,
	Kind.DEPOT, Kind.PALACE]

## What the pen prompt says when the saddlebag is empty. THE PEN STILL WINS THE GROUND in
## that state, deliberately: a pen that dropped out of the running with an empty bag would
## hand E to whatever building is next nearest, so the player standing in her own paddock
## would press E and open the Market. She keeps the ground and the prompt says why.
const EMPTY_BAG := "your saddlebag is empty"


## One candidate, as ranch.gd hands them over. `distance` is metres in the XZ plane and is
## only ever used to settle two candidates of the SAME kind. `subject` is whatever the
## prompt needs to name: the pony at the top of the saddlebag, or a slot's name for a test.
static func candidate(kind: int, distance: float, subject: String = "") -> Dictionary:
	return {"kind": kind, "distance": distance, "subject": subject}


## Where `kind` sits in PRIORITY, or minus one for a kind that is not in it at all. A kind
## outside the list can never win, which is the correct answer for Kind.NONE and a loud one
## for a kind somebody adds to the enum and forgets to rank.
static func rank_of(kind: int) -> int:
	return PRIORITY.find(kind)


## THE ONE WINNER. Ranked by PRIORITY first, then by the shorter distance, then by the kind
## itself, so the answer is a function of the candidates and of nothing else: handing the
## same set in a different order gives the same winner. An empty array answers an empty
## dictionary, which is not the same thing as a candidate of Kind.NONE.
static func resolve(candidates: Array[Dictionary]) -> Dictionary:
	var best: Dictionary = {}
	var best_rank := -1
	for entry: Dictionary in candidates:
		var rank: int = rank_of(int(entry.get("kind", Kind.NONE)))
		if rank < 0:
			continue
		if best.is_empty():
			best = entry
			best_rank = rank
			continue
		if rank < best_rank:
			best = entry
			best_rank = rank
			continue
		if rank > best_rank:
			continue
		var d: float = float(entry.get("distance", 0.0))
		var best_d: float = float(best.get("distance", 0.0))
		if d < best_d:
			best = entry
	return best


## THE LINE ON THE SCREEN, and it always names the verb rather than the place. "E: Market"
## tells a player where she is; "E: Market, sell gems" tells her what pressing it does,
## which is the question she actually has in the first ten minutes.
##
## `key` is the glyph for the device in her hands, handed in rather than looked up, so this
## file stays pure and Task 4's device tracker has exactly one call site to change.
static func prompt_for(action: Dictionary, key: String) -> String:
	if action.is_empty():
		return ""
	var subject: String = String(action.get("subject", ""))
	match int(action.get("kind", Kind.NONE)):
		Kind.PLOT_BUILD:
			return "%s: build here" % key
		Kind.PEN_MOVE_IN:
			if subject.is_empty():
				return "%s: the pen is here, %s" % [key, EMPTY_BAG]
			return "%s: move %s in" % [key, subject]
		Kind.MARKET:
			return "%s: Market, sell gems" % key
		Kind.BOARD:
			return "%s: read the board" % key
		Kind.DEPOT:
			return "%s: Depot, deliver and pay" % key
		Kind.PALACE:
			return "%s: Spectra Palace" % key
	return ""
