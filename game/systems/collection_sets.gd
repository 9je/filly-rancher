class_name CollectionSets
extends RefCounted
## COLLECTION SETS (FS7.2): a reason to come back for the last few ponies. Each set pays once,
## the moment its last member is caught: the Mane Six stand a statue on the plaza (or pay its
## price if she has bought it already), the families and teams pay a purse, and every rare and
## every legendary pony pay a bigger one. What is claimed is a story var, so it saves.
##
## A set is either `members` (pony ids) or `rarity` (every pony of that rarity on the roster).

const SETS: Array[Dictionary] = [
	{"id": &"mane_six", "name": "The Mane Six", "bits": 0, "decor": &"statue_rainbowdash",
		"members": [&"twilight", &"rainbowdash", &"fluttershy", &"pinkiepie", &"applejack", &"rarity"]},
	{"id": &"crusaders", "name": "The Cutie Mark Crusaders", "bits": 2000,
		"members": [&"applebloom", &"scootaloo", &"sweetiebelle"]},
	{"id": &"pie_sisters", "name": "The Pie Sisters", "bits": 2500,
		"members": [&"pinkiepie", &"maudpie", &"limestonepie", &"marblepie"]},
	{"id": &"wonderbolts", "name": "The Wonderbolts", "bits": 2000,
		"members": [&"spitfire", &"soarin"]},
	{"id": &"rare", "name": "Every Rare Pony", "bits": 6000, "rarity": PonyData.Rarity.RARE},
	{"id": &"legendary", "name": "Every Legendary Pony", "bits": 10000, "rarity": PonyData.Rarity.LEGENDARY},
]
const VAR := "sets_claimed"


static func members(s: Dictionary, registry: PonyRegistry) -> Array[StringName]:
	var out: Array[StringName] = []
	if s.has("rarity"):
		for data: PonyData in registry.all():
			if data.rarity == int(s.rarity):
				out.append(data.id)
	else:
		for id: StringName in s.get("members", []):
			out.append(id)
	return out


## Every set newly complete in `compendium`, as {id, name, bits, decor}, marked claimed on
## `story` so none pays twice. A decoration she already owns pays its price instead.
static func claim(compendium: Compendium, registry: PonyRegistry, story: Story) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var claimed: Array = (story.get_var(VAR, []) as Array).duplicate()
	for s: Dictionary in SETS:
		if String(s.id) in claimed:
			continue
		var ids := members(s, registry)
		if ids.is_empty():
			continue
		var done := true
		for id: StringName in ids:
			if compendium.state_of(id) < Compendium.State.CAUGHT:
				done = false
				break
		if not done:
			continue
		var decor := StringName(s.get("decor", &""))
		var bits := int(s.get("bits", 0))
		if decor != &"" and Decor.owns(story, decor):
			bits += int(Decor.find(decor).get("cost", 0))
			decor = &""
		claimed.append(String(s.id))
		out.append({"id": s.id, "name": s.name, "bits": bits, "decor": decor})
	story.set_var(VAR, claimed)
	return out
