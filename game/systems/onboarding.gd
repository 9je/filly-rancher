class_name Onboarding
extends RefCounted
## CONTEXTUAL PROMPTS, NOT TEXT WALLS (RESEARCH.md section 4). Each tip appears only at the
## moment it is needed, one line, never blocking, and retires for good once the player has
## done the thing it teaches twice. The HUD shows whichever live tip ranks highest.
##
## `state` is what the game knows right now (a Dictionary of booleans and counts: see
## TIPS for the keys each tip reads); `note(action)` is called when the player does
## something a tip teaches.

## id -> [action that retires it, priority, text with {key} glyph slots, condition key]
const TIPS := {
	&"scoop": [&"catch", 100, "Hold {beam} on a pony to Scoop her up", "pony_in_view"],
	&"pen": [&"pen", 90, "Walk onto the pen and press {interact} to let her out", "bag_has_pony_near_pen"],
	&"build": [&"build", 85, "Press {interact} on an empty plot to build a pen", "bag_has_pony_no_pen"],
	&"feed": [&"feed", 80, "Toss a treat with {treat} to feed a penned pony", "hungry_pony_near"],
	&"gems": [&"collect", 70, "Walk over gems to pick them up", "gems_on_ground"],
	&"sell": [&"sell", 60, "Sell gems to Bramble at the market", "gems_in_pouch"],
	&"talk": [&"talk", 95, "Press {interact} to talk", "npc_has_news"],
	# Owner playtest 2026-10-24: these two named keys that do not exist. A full bag empties
	# into a pen; running is already the default gait.
	&"launch": [&"launch", 50, "The Scoop is full: let them out in a pen with {interact}", "bag_full"],
}
const RETIRE_AFTER := 2

var done: Dictionary = {}


func note(action: StringName) -> void:
	for id: StringName in TIPS:
		if TIPS[id][0] == action:
			done[String(id)] = int(done.get(String(id), 0)) + 1


func retired(id: StringName) -> bool:
	return int(done.get(String(id), 0)) >= RETIRE_AFTER


## The tip to show now, as {id, text}, or {} for none. `glyph` maps an action name to the
## key or button that triggers it on the current device.
func current(state: Dictionary, glyph: Callable) -> Dictionary:
	var best: StringName = &""
	var best_p := -1
	for id: StringName in TIPS:
		if retired(id):
			continue
		var row: Array = TIPS[id]
		if not bool(state.get(row[3], false)):
			continue
		if int(row[1]) > best_p:
			best_p = int(row[1])
			best = id
	if best == &"":
		return {}
	var text: String = TIPS[best][2]
	for key in ["beam", "interact", "treat"]:
		text = text.replace("{%s}" % key, str(glyph.call(StringName(key))))
	return {"id": best, "text": text}


func to_dict() -> Dictionary:
	return {"done": done.duplicate()}


func from_dict(d: Dictionary) -> void:
	done.clear()
	for k in (d.get("done", {}) as Dictionary):
		done[str(k)] = int(d["done"][k])
