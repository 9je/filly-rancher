extends GutTest
## COLLECTION SETS (FS7.2; systems/collection_sets.gd): a reason to come back for the last few.
## A full set of caught ponies pays once: the Mane Six a statue for the plaza (or its price if
## she bought it already), the Crusaders, the Pie sisters and the Wonderbolts a purse, and every
## rare and every legendary pony a bigger one.

const SetsScript := preload("res://systems/collection_sets.gd")


func _registry() -> PonyRegistry:
	var r := PonyRegistry.new()
	r.load_all("res://data/ponies")
	return r


func test_every_named_member_is_on_the_roster() -> void:
	var r := _registry()
	for s: Dictionary in SetsScript.SETS:
		for id: StringName in s.get("members", []):
			assert_not_null(r.by_id(id), "%s: %s" % [s.id, id])


func test_a_set_is_done_when_all_of_it_is_caught_and_pays_once() -> void:
	var r := _registry()
	var c := Compendium.new()
	var story := Story.new()
	for id: StringName in [&"applebloom", &"scootaloo"]:
		c.mark_caught(id)
	assert_eq(SetsScript.claim(c, r, story), [] as Array[Dictionary], "two of three Crusaders is not a set")
	c.mark_caught(&"sweetiebelle")
	var got := SetsScript.claim(c, r, story)
	assert_eq(got.size(), 1)
	assert_eq(got[0].id, &"crusaders")
	assert_gt(int(got[0].bits), 0)
	assert_eq(SetsScript.claim(c, r, story), [] as Array[Dictionary], "and only once")


func test_the_mane_six_give_a_statue_or_its_price() -> void:
	var r := _registry()
	var c := Compendium.new()
	var story := Story.new()
	for id: StringName in [&"twilight", &"rainbowdash", &"fluttershy", &"pinkiepie", &"applejack", &"rarity"]:
		c.mark_caught(id)
	var got := SetsScript.claim(c, r, story)
	var m6: Dictionary = got.filter(func(g: Dictionary) -> bool: return g.id == &"mane_six")[0]
	assert_eq(m6.decor, &"statue_rainbowdash")
	var story2 := Story.new()
	Decor.add(story2, &"statue_rainbowdash")
	var again: Dictionary = SetsScript.claim(c, r, story2).filter(func(g: Dictionary) -> bool: return g.id == &"mane_six")[0]
	assert_eq(again.decor, &"", "already standing: no second statue")
	assert_eq(int(again.bits), int(Decor.find(&"statue_rainbowdash").cost), "its price instead")


func test_every_legendary_pony_is_a_set() -> void:
	var r := _registry()
	var c := Compendium.new()
	for data: PonyData in r.all():
		if data.rarity == PonyData.Rarity.LEGENDARY:
			c.mark_caught(data.id)
	var ids: Array = SetsScript.claim(c, r, Story.new()).map(func(g: Dictionary) -> StringName: return g.id)
	assert_has(ids, &"legendary")
