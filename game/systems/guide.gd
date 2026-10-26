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
## Goals: &"pens", &"mail", &"talk", &"market", &"catch", or &"" for nowhere.


static func pick(s: Dictionary) -> StringName:
	var news := bool(s.get("news", false))
	if not bool(s.get("has_scoop", false)):
		# The first minutes are people: whoever hands her the Scoop has the "!".
		return &"talk" if news else &""
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
	return &""
