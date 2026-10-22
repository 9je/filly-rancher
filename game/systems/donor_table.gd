class_name DonorTable
extends Resource
## The pony models a generated pony can be built from: the 38 SFM ReVAmped bodies, which
## share one skeleton and one body template (AUDIT.md section 5). Written by
## tools/make_donors.py from the converted .glb files; never edited by hand.
##
## Each row: `id` (the .glb basename), `race` (earth, pegasus, unicorn: what the model
## natively has), `mane`/`mane2`/`tail` (material names per color role), `hide` (canon
## signature accessories, never shown), `eye_from` (borrow another donor's eye texture),
## `foal` (foal-proportioned body).

const PATH := "res://data/donors.tres"
const MODEL_DIR := "res://assets/converted/ponies/"

@export var donors: Array[Dictionary] = []

static var _cached: DonorTable


static func load_table() -> DonorTable:
	if _cached == null:
		var res: Resource = load(PATH)
		_cached = res as DonorTable if res is DonorTable else DonorTable.new()
	return _cached


func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for d: Dictionary in donors:
		out.append(StringName(d.get("id", "")))
	return out


func find(id: StringName) -> Dictionary:
	for d: Dictionary in donors:
		if StringName(d.get("id", "")) == id:
			return d
	return {}


## Donors that can wear `race`: any donor makes an earth pony (horn and wings hidden);
## unicorns and pegasi need a donor that natively has the part.
func for_race(race: StringName, foal: bool = false) -> Array[StringName]:
	var out: Array[StringName] = []
	for d: Dictionary in donors:
		if bool(d.get("foal", false)) != foal:
			continue
		if race == &"earth" or StringName(d.get("race", "")) == race:
			out.append(StringName(d.get("id", "")))
	return out


static func model_path(id: StringName) -> String:
	return MODEL_DIR + String(id) + ".glb"
