class_name Guide
extends RefCounted
## THE ONE PLACE THE GAME WANTS HER TO GO NEXT (owner playtest 2026-10-25: "idk what to do
## anymore", "i cant find the market", "build area hard to find"). The checklist says what
## to do; this says where, so the world can show it: a trail of motes on the ground and the
## goal's icon lit on the compass (game/world/guide_trail.gd, game/ui/compass.gd).
##
## A pure function of a small state dictionary, so the rules can be read and tested apart
## from the ranch that measures them. It is a guide, not a nag: past the three first lessons
## it speaks only for things that are waiting on her (a full bag, the mail, somebody's news).
##
## State keys: has_scoop, mail, news (somebody shows the gold "!"), bag, bag_full, pen_room
## (free places across the built pens), gems (in the pouch and the pens), tasks (the board's
## tutorial_rows()).
##
## Goals: &"pens", &"mail", &"talk", &"market", &"catch", or the story's own (objective_goal:
## &"depot", &"marigold", &"static"), or &"" for nowhere.


static func pick(s: Dictionary) -> StringName:
	var news := bool(s.get("news", false))
	# Where the story goes next (Objective.current), when nothing is waiting on her.
	var story := StringName(s.get("objective_goal", &""))
	if not bool(s.get("has_scoop", false)):
		# The first minutes are people: whoever hands her the Scoop has the "!".
		return &"talk" if news else story
	var bag := int(s.get("bag", 0))
	if bool(s.get("bag_full", false)):
		return &"pens"
	var open := {}
	for t: Dictionary in s.get("tasks", []):
		if not bool(t.get("done", false)) and not bool(t.get("paid", false)):
			open[String(t.get("id", ""))] = true
	var learning := not open.is_empty()
	if learning and bag > 0 and int(s.get("pen_room", 0)) > 0 and open.has("tutorial_pen"):
		return &"pens"
	# A PONY TUMBLE HAS JUST POINTED OUT (PT8; playtest 2026-11-05: "it said octavia to north
	# east and i couldnt find her"). She will not wait, so past the lessons she comes before
	# the mail and the news.
	if not learning and bool(s.get("sighting", false)):
		return &"sighting"
	# THE FIRST CATCH FIRST (PS1, playtest 2026-11-05 item 16: "The start doesn't show where to
	# go for a first catch"): the welcome letter and four townsfolk's news are all waiting when
	# she gets the Scoop, and the trail went to each of them before it ever showed a pony.
	if open.has("tutorial_catch"):
		return &"catch"
	if bool(s.get("mail", false)):
		return &"mail"
	if news:
		return &"talk"
	if open.has("tutorial_catch"):
		return &"catch"
	if open.has("tutorial_pen"):
		return &"pens" if bag > 0 else &"catch"
	if open.has("tutorial_sell"):
		return &"market" if int(s.get("gems", 0)) > 0 else &"catch"
	return story
