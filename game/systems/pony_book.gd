class_name PonyBook
extends RefCounted
## THE PONY BOOK: what the player has to show for caring. Replaces the canon-character
## Compendium (DECISIONS.md, 2026-10-22). Three collections, each a reason to keep ranching:
##   bloomed   every pony who found her mark at your ranch (name, talent, look, the day)
##   talents   which of MarkComposer's 24 talents have turned up, and how many times
##   variants  which rare Drifters (pearl, starry, ember) you have caught
## Plus `delivered`: every pony sent up for Placement, which after the reveal is the list of
## names the game will not let the player forget (STORY.md, Undertale lesson).

var bloomed: Array[Dictionary] = []
var talents: Dictionary = {}
var variants: Dictionary = {}
var delivered: Array[Dictionary] = []


func note_bloom(uid: String, name: String, look: PonyLook, day: int) -> void:
	for b in bloomed:
		if str(b.get("uid", "")) == uid:
			return
	var talent := String(look.mark.get("talent", ""))
	bloomed.append({"uid": uid, "name": name, "talent": talent, "look": look.to_dict(), "day": day})
	if talent != "":
		talents[talent] = int(talents.get(talent, 0)) + 1


func note_catch(look: PonyLook) -> bool:
	if look == null or look.variant == &"":
		return false
	var first := not variants.has(String(look.variant))
	variants[String(look.variant)] = int(variants.get(String(look.variant), 0)) + 1
	return first


func note_delivery(uid: String, name: String, look: PonyLook, day: int, after_reveal: bool) -> void:
	delivered.append({"uid": uid, "name": name, "look": look.to_dict(), "day": day,
		"after_reveal": after_reveal})


func talent_count() -> int:
	return talents.size()


func has_talent(t: StringName) -> bool:
	return talents.has(String(t))


func to_dict() -> Dictionary:
	return {"bloomed": bloomed.duplicate(true), "talents": talents.duplicate(),
		"variants": variants.duplicate(), "delivered": delivered.duplicate(true)}


static func from_dict(d: Dictionary) -> PonyBook:
	var b := PonyBook.new()
	for e in d.get("bloomed", []):
		if e is Dictionary:
			b.bloomed.append(e)
	for k in (d.get("talents", {}) as Dictionary):
		b.talents[str(k)] = int(d["talents"][k])
	for k in (d.get("variants", {}) as Dictionary):
		b.variants[str(k)] = int(d["variants"][k])
	for e in d.get("delivered", []):
		if e is Dictionary:
			b.delivered.append(e)
	return b
