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
## PEN_UPGRADE and PLOT_CLEAR are appended rather than slotted in beside the other ground
## kinds, so every int a driver or a test log already holds keeps its meaning.
enum Kind { NONE, PLOT_BUILD, PEN_MOVE_IN, MARKET, BOARD, MAILBOX, DEPOT, PALACE, TALK,
	PEN_UPGRADE, PLOT_CLEAR }

## THE ORDER, HIGHEST FIRST, and every one of these positions is a decision.
##
## GROUND YOU ARE STANDING ON BEATS GROUND YOU ARE STANDING NEAR. The two plot kinds lead
## because a slot's trigger box is a square the player deliberately walked into, and a
## building's radius is a circle she walked past.
##
## THE TWO PLOT KINDS DO NOT BEAT EACH OTHER -- see GROUND_TIER. They used to, in the order
## written here, and it cost the owner a playtest verdict.
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
##
## THE MAILBOX SITS ABOVE THE DEPOT for the reason the note above already gives: the Depot
## and the Palace are last because they are the two biggest buildings with the two widest
## radii, so a smaller thing standing in front of one of them wins the ground. A mailbox is
## the smallest thing on the map.
## TALK ranks right under the ground tier: a person standing beside you is who the key is
## for, ahead of any building behind her (Bramble stands at the Market's counter).
const PRIORITY: Array[int] = [Kind.PLOT_BUILD, Kind.PEN_MOVE_IN, Kind.PEN_UPGRADE,
	Kind.PLOT_CLEAR, Kind.TALK, Kind.MARKET, Kind.BOARD, Kind.MAILBOX, Kind.DEPOT, Kind.PALACE]

## THE KINDS THAT SHARE ONE RANK, so resolve() settles them on distance instead of on the
## order they happen to sit in above.
##
## THE PLAYTEST THIS FIXES. The four plot slots are 9 m apart and a slot's trigger holds the
## player until her centre is 4.77 m out (PlotSlot.TRIGGER_HALF 4.35 plus a 0.42 m capsule).
## Standing at a BUILT pen's gate puts her centre 4.40 m from that pen and 4.60 m from the
## empty slot behind her -- inside both triggers at once. With PLOT_BUILD strictly above
## PEN_MOVE_IN, E opened the build menu for the plot 20 cm further away instead of putting
## the pony in her saddlebag into the pen she was standing at. The owner: "when i place
## ponies in the paddock i press e several times and that sound is terrible" -- the sound
## being the build menu's own open and back ticks, once per press.
##
## Both are ground she is standing IN, decided by an Area3D overlap rather than by a radius,
## so there is no doctrine that says either outranks the other; the nearer one is the one
## she meant. A slot cannot offer both verbs at once (interaction_candidates() offers
## PLOT_BUILD for an empty slot and PEN_MOVE_IN for a built one), so this is only ever
## deciding between two DIFFERENT squares of ground.
##
## THE UPGRADE AND THE CLEARING ARE GROUND TOO (owner playtest 2026-10-25). A built pen
## offers PEN_UPGRADE instead of PEN_MOVE_IN whenever moving in is not what E can do (an
## empty saddlebag, or a full pen), and an overgrown plot offers PLOT_CLEAR instead of
## PLOT_BUILD. Each square still offers exactly one verb, so the tie-break stays a choice
## between squares.
const GROUND_TIER: Array[int] = [Kind.PLOT_BUILD, Kind.PEN_MOVE_IN, Kind.PEN_UPGRADE,
	Kind.PLOT_CLEAR]

## What the pen prompt says when the saddlebag is empty. THE PEN STILL WINS THE GROUND in
## that state, deliberately: a pen that dropped out of the running with an empty bag would
## hand E to whatever building is next nearest, so the player standing in her own paddock
## would press E and open the Market. She keeps the ground and the prompt says why.
const EMPTY_BAG := "your saddlebag is empty"

## What a full pen with no bigger size left says. "That pen is full." alone was the owner's
## dead end (2026-10-25): it said what was wrong and not what to do about it.
const FULL_PEN := "this pen is full, build another pen"


## One candidate, as ranch.gd hands them over. `distance` is metres in the XZ plane and is
## only ever used to settle two candidates of the SAME kind. `subject` is whatever the
## prompt needs to name: the pony at the top of the saddlebag, or a slot's name for a test.
## `reason` is a refusal this candidate ALREADY KNOWS ABOUT -- the plot she is standing on
## that will not take a fence while she is standing on it. It is carried rather than looked
## up so the prompt, the coloured ghost on the ground and the refusal she gets if she presses
## anyway are all one answer from one place.
static func candidate(kind: int, distance: float, subject: String = "",
		reason: String = "") -> Dictionary:
	return {"kind": kind, "distance": distance, "subject": subject, "reason": reason}


## A priced ground verb: PEN_UPGRADE (`what` is the plot it becomes) or PLOT_CLEAR (`what` is
## unused). `subject` is the slot's node name, as for PLOT_BUILD. `price` and `afford` go on
## the prompt, so "not enough bits" is said before E is pressed and not after; `full` says
## the pen she is standing at has no room, which is why the upgrade is being offered.
static func priced(kind: int, distance: float, subject: String, price: int, afford: bool,
		what: String = "", full: bool = false) -> Dictionary:
	var c := candidate(kind, distance, subject)
	c["price"] = price
	c["afford"] = afford
	c["what"] = what
	c["full"] = full
	return c


## Where `kind` sits in PRIORITY, or minus one for a kind that is not in it at all. A kind
## outside the list can never win, which is the correct answer for Kind.NONE and a loud one
## for a kind somebody adds to the enum and forgets to rank.
##
## Every member of GROUND_TIER answers with the SAME rank -- the rank of the tier's first
## member -- so resolve()'s distance tie-break is what separates them.
static func rank_of(kind: int) -> int:
	if PRIORITY.find(kind) < 0:
		return -1
	if GROUND_TIER.has(kind):
		return PRIORITY.find(GROUND_TIER[0])
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
			var reason: String = String(action.get("reason", ""))
			if not reason.is_empty():
				return "%s: cannot build, %s" % [key, reason]
			return "%s: build here" % key
		Kind.PEN_MOVE_IN:
			if bool(action.get("full", false)):
				return "%s: %s" % [key, FULL_PEN]
			if subject.is_empty():
				return "%s: the pen is here, %s" % [key, EMPTY_BAG]
			return "%s: move %s in" % [key, subject]
		Kind.PEN_UPGRADE:
			var line := "%s: %supgrade to %s (%s)" % [key,
				"pen full, " if bool(action.get("full", false)) else "",
				String(action.get("what", "")), _price(int(action.get("price", 0)))]
			return line if bool(action.get("afford", true)) else line + ", not enough bits"
		Kind.PLOT_CLEAR:
			var clear := "%s: clear this plot (%s)" % [key, _price(int(action.get("price", 0)))]
			return clear if bool(action.get("afford", true)) else clear + ", not enough bits"
		Kind.MARKET:
			return "%s: Market, sell gems" % key
		Kind.BOARD:
			return "%s: read the board" % key
		Kind.MAILBOX:
			return "%s: read your mail" % key
		Kind.DEPOT:
			return "%s: Depot, deliver and pay" % key
		Kind.PALACE:
			return "%s: Spectra Palace" % key
		Kind.TALK:
			return "%s: talk to %s" % [key, subject]
	return ""


static func _price(bits: int) -> String:
	return "free" if bits <= 0 else "%d bits" % bits
