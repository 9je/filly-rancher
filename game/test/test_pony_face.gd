extends GutTest
## EVERY PONY'S FACE MOVES (FS3.1). Only the townsfolk had a PonyFace; wild and penned ponies
## never blinked, flicked an ear or showed a mood. Every body built by PonyVisuals now carries
## one, on both rigs (the PonySFM cast's and the Mane Six's DEF_/CON_ names), and a pony's
## state sets her mood.

const PonyScene := preload("res://actors/pony/pony.tscn")


func _face_of(body: Node) -> PonyFace:
	var found := body.find_children("Face", "", true, false)
	return found[0] as PonyFace if not found.is_empty() else null


func test_both_rigs_get_a_face_that_finds_its_lids_ears_and_jaw() -> void:
	for id: String in ["applebloom", "fluttershy"]:
		var body: Node3D = PonyVisuals.build(load("res://data/ponies/%s.tres" % id))
		add_child_autofree(body)
		var face := _face_of(body)
		assert_not_null(face, "%s has a face" % id)
		if face == null:
			continue
		var found: Dictionary = face.channels_found()
		for ch: String in ["lid_l", "lid_r", "ear_l", "ear_r", "jaw"]:
			assert_true(bool(found.get(ch, false)), "%s: %s" % [id, ch])


func test_a_fleeing_or_held_pony_looks_scared_and_a_grazing_one_does_not() -> void:
	var pony: Node3D = PonyScene.instantiate()
	add_child_autofree(pony)
	pony.call("setup", load("res://data/ponies/applebloom.tres"))
	var face := _face_of(pony)
	assert_not_null(face)
	if face == null:
		return
	pony.call("_transition_to", 3)  # FLEE
	pony.call("_update_mood")
	assert_eq(face.mood, PonyFace.Mood.SCARED)
	pony.call("_transition_to", 2)  # GRAZE
	pony.call("_update_mood")
	assert_ne(face.mood, PonyFace.Mood.SCARED)


func test_a_townspony_keeps_one_face() -> void:
	var npc: Node3D = preload("res://actors/npc/npc.gd").new()
	add_child_autofree(npc)
	npc.call("setup", load("res://data/characters/marigold.tres"))
	await wait_frames(2)
	assert_lte(npc.find_children("Face", "", true, false).size(), 1)
