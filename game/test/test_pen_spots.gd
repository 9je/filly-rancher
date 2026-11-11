extends GutTest
## EACH STANDING SPOT HAS ONE PONY (P9, playtest 2026-11-10 item 30: "pile into each other").
## A pen that has lived a while (two residents delivered, two more penned) must not hand a new
## pony a spot somepony still holds; spots came from roster position, so it did. The pile-up
## itself is judged from frames (Lane B round 3, lb5/pen2 vs pen3).

const PenScript := preload("res://world/pen.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const IDS := [&"twilight", &"rarity", &"pinkiepie", &"rainbowdash", &"applejack", &"fluttershy",
	&"lyra", &"bonbon", &"octavia", &"cheerilee"]


func test_a_new_resident_takes_a_free_spot_not_a_neighbours() -> void:
	var pen: Pen = PenScript.new()
	pen.capacity = 8
	pen.slot_id = &"slot_spots"
	add_child_autofree(pen)
	var uids: Array[StringName] = []
	for i in 8:
		var inst := PonyInstanceScript.create(IDS[i])
		assert_true(pen.add_pony(inst))
		uids.append(inst.uid)
	pen.remove_pony(uids[2])
	pen.remove_pony(uids[5])
	for i in [8, 9]:
		assert_true(pen.add_pony(PonyInstanceScript.create(IDS[i])))
	var seen := {}
	for inst in pen.ponies():
		var s := pen.spot_of(inst.uid)
		assert_true(s >= 0, "every body has a spot")
		assert_false(seen.has(s), "spot %d is held by one pony only" % s)
		seen[s] = true
	assert_true(seen.has(2) and seen.has(5), "the two freed spots are the ones reused")
