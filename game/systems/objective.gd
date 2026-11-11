class_name Objective
extends RefCounted
## THE ONE THING THE STORY WANTS FROM HER NOW (owner playtest 2026-10-25: "idk what to do
## anymore"). game/systems/guide.gd points at chores that are waiting on her; this names the
## main path, at every stage of STORY.md, so the HUD's objective card and the guide's trail
## are never silent while there is somewhere to go. A pure function of a small state, like
## Guide.pick, so the whole ladder reads and tests in one place.
##
## State keys: chapter (Story.Chapter), path ("", "factory", "rescue"), ending (non-empty
## once one has played), flags (the story flags set), deliveries, blooms, pens (built), bag
## (ponies carried), drifters (unmarked Drifters penned), ready (Bloomed Drifters penned),
## pylons (cut), contract
## (PathRules.contract: want, kind, got).
##
## Returns {id, goal, icon (PlaceSign.Icon), words} or {} for no objective. goal is a Guide
## goal (&"marigold", &"static", &"catch", &"pens", &"depot", &"bloom" (the pen holding a
## Drifter who can Bloom), &"drifter" (a wild Drifter)) or &"" when the objective is a wait,
## not a place.

## The invitation's gate (data/dialogue_src/act2.txt, marigold_invites).
const INVITE_DELIVERIES := 6
const INVITE_BLOOMS := 2
## The Rescue path's climax opens at this many pylons cut (act3.txt, static_climax).
const CLIMAX_PYLONS := 4


static func current(s: Dictionary) -> Dictionary:
	if s.is_empty() or not s.has("chapter") or String(s.get("ending", "")) != "":
		return {}
	var flags: Array = s.get("flags", [])
	var path := String(s.get("path", ""))
	if not flags.has("has_scoop"):
		return _o(&"meet", &"marigold", PlaceSign.Icon.STAR, "Talk to Marigold")
	if not flags.has("reveal_done"):
		return _acts_one_two(s, flags)
	match path:
		"factory":
			if flags.has("jubilee_ready"):
				return _o(&"jubilee", &"marigold", PlaceSign.Icon.STAR, "Marigold has the Jubilee")
			var c: Dictionary = s.get("contract", {})
			if c.is_empty():
				return _o(&"deliver", &"depot", PlaceSign.Icon.CRATE, "Ship ponies at the Depot")
			return _o(&"contract", &"depot", PlaceSign.Icon.CRATE,
				"Fill the contract %d/%d" % [int(c.get("got", 0)), int(c.get("want", 0))])
		"rescue":
			if not flags.has("static_met"):
				return _o(&"static", &"static", PlaceSign.Icon.STAR, "Find Static at night")
			var cut := int(s.get("pylons", 0))
			if cut < CLIMAX_PYLONS:
				return _o(&"pylons", &"", PlaceSign.Icon.ARROW,
					"Cut pylons at night %d/%d" % [cut, CLIMAX_PYLONS])
			return _o(&"climax", &"static", PlaceSign.Icon.STAR, "Static is ready: go")
	return {}


## What the HUD's card says when the guide's ring points at `goal` (Guide.pick): the chore
## itself when the guide is pointing at one, the story's step `story` otherwise, so the card
## and the ring never name two places at once.
static func for_guide(goal: StringName, story: Dictionary) -> Dictionary:
	if not story.is_empty() and goal == StringName(story.get("goal", &"")):
		return story
	match goal:
		&"mail":
			return _o(&"mail", &"mail", PlaceSign.Icon.SCROLL, "Read your new letter")
		&"talk":
			return _o(&"talk", &"talk", PlaceSign.Icon.STAR, "Somepony has news")
		&"market":
			return _o(&"market", &"market", PlaceSign.Icon.COIN, "Sell gems at the Market")
		&"pens":
			return _o(&"pen", &"pens", PlaceSign.Icon.FENCE, "Pen the ponies you carry")
		&"catch":
			return _o(&"catch", &"catch", PlaceSign.Icon.STAR, "Catch a Drifter")
		&"sighting":
			return _o(&"sighting", &"sighting", PlaceSign.Icon.STAR, "Find the pony Tumble saw")
		&"bloomed":
			return _o(&"bloomed", &"bloomed", PlaceSign.Icon.FENCE, "A Drifter found her mark: come and see")
	return story


static func _acts_one_two(s: Dictionary, flags: Array) -> Dictionary:
	# The first lessons: a pen, ponies in it. After the Depot, a full bag is the guide's to
	# point out (Guide.pick), not the story's.
	if not flags.has("depot_explained"):
		# Catch first: Fennel shows her the pens after her first catches (act1.txt).
		if not flags.has("met_fennel"):
			return _o(&"first_catch", &"catch", PlaceSign.Icon.STAR, "Catch a Drifter")
		if int(s.get("pens", 0)) == 0:
			return _o(&"build", &"pens", PlaceSign.Icon.FENCE, "Build your first pen")
		if int(s.get("bag", 0)) > 0:
			return _o(&"pen", &"pens", PlaceSign.Icon.FENCE, "Pen the ponies you carry")
		return _o(&"catch", &"catch", PlaceSign.Icon.STAR, "Catch Drifters for your pens")
	if not flags.has("invited"):
		var d := int(s.get("deliveries", 0))
		if d < INVITE_DELIVERIES:
			# NOTHING READY TO SHIP (playtest 2026-11-10 item 2): pens of keepers and blank
			# Drifters, an empty bag, and "Deliver ponies 0/6" said nothing about how. Bloom one
			# first; the trail goes to her pen, where E plays with them.
			if int(s.get("ready", 1)) <= 0 and int(s.get("drifters", 0)) > 0 and int(s.get("bag", 0)) == 0:
				return _o(&"deliver", &"bloom", PlaceSign.Icon.FENCE,
					"Bloom a Drifter, then deliver her %d/%d" % [d, INVITE_DELIVERIES])
			return _o(&"deliver", &"depot", PlaceSign.Icon.CRATE,
				"Deliver ponies %d/%d" % [d, INVITE_DELIVERIES])
		var b := int(s.get("blooms", 0))
		if b < INVITE_BLOOMS:
			# ONLY A DRIFTER BLOOMS (PT3; playtest 2026-11-05 item 53): with every Drifter
			# delivered and the named ponies kept, "Help ponies Bloom" pointed at pens where
			# nobody could. Say who, and send her for one when none is penned. The goals are
			# her own, not &"pens" and &"catch": those lead to a pen with ROOM and the nearest
			# wild pony of any kind, so with every pen upgraded and full the trail fell back
			# to the old Paddock and stayed there ("0/2", item 53).
			# PLAIN WORDS (playtest 2026-11-08 item 74: "Feed Drifters to Bloom" meant nothing):
			# what to do and what it gets her. The two terms are explained once, the first time
			# they are on the card (EXPLAIN).
			if int(s.get("drifters", 1)) <= 0:
				return _o(&"bloom", &"drifter", PlaceSign.Icon.STAR,
					"Catch and pen a Drifter %d/%d" % [b, INVITE_BLOOMS])
			return _o(&"bloom", &"bloom", PlaceSign.Icon.FENCE,
				"Keep Drifters fed to Bloom %d/%d" % [b, INVITE_BLOOMS])
		return _o(&"invite", &"marigold", PlaceSign.Icon.STAR, "Marigold wants a word")
	if not flags.has("color_day"):
		return _o(&"wait", &"", PlaceSign.Icon.HOUSE, "Sleep at home till Color Day")
	# At HER, not the Depot (playtest 2026-11-08 item 17): the trail led to the building and
	# E there opened the Depot instead of her lift talk.
	return _o(&"lift", &"marigold", PlaceSign.Icon.STAR, "Meet Marigold at the Depot")


## THE ONE-TIME EXPLAINERS (item 74): the first time a term is on the card, what it means.
## {flag: [term, the explanation]}; the ranch shows each once and sets its flag.
const EXPLAIN := {
	"explained_drifter": ["Drifter", "A Drifter is a pony with no mark yet: a blank cutie mark. Catch her, pen her, and look after her."],
	"explained_bloom": ["Bloom", "Bloom: a Drifter finds her talent and her cutie mark. Play with her at her pen (E), and her favourite food and a friend speed it up."],
}


## The explainer due for `words` given the story `flags` set, as {flag, text}, or {}.
static func explainer_for(words: String, flags: Array) -> Dictionary:
	for flag: String in EXPLAIN:
		if flags.has(flag):
			continue
		var row: Array = EXPLAIN[flag]
		if words.contains(String(row[0])):
			return {"flag": flag, "text": String(row[1])}
	return {}


static func _o(id: StringName, goal: StringName, icon: int, words: String) -> Dictionary:
	return {"id": id, "goal": goal, "icon": icon, "words": words}
