extends GutTest
## YOU CAN TELL A TOWNSPONY FROM A CATCH (PS8, playtest 2026-11-05 item 34: "You can't tell
## which ponies aren't catchable (townsfolk)"). With the crosshair on a townspony, at the
## distances you meet them, the HUD shows the speech bubble beside the reticle; on a wild
## pony it does not.

const RanchScene := preload("res://world/ranch.tscn")


## Stand `who` where the crosshair's ray passes `height` metres above the ground, about
## `dist` metres out: the crosshair is then on her legs, her middle or her head.
func _aim_at(ranch: Node, who: Node3D, dist: float, height: float = 1.0) -> void:
	var cam := ranch.get_viewport().get_camera_3d()
	var dir := -cam.global_transform.basis.z
	var at := cam.global_position + dir * dist
	# Slide along the ray until it is `height` above the ground.
	if absf(dir.y) > 0.01:
		at = cam.global_position + dir * ((height - cam.global_position.y) / dir.y)
	who.global_position = Vector3(at.x, cam.global_position.y + (at.y - cam.global_position.y) - height, at.z)
	if who is Npc:
		(who as Npc).set_mode_stand(who.global_position)


## The check runs each frame only for somebody playing (ranch._physics_process); a test
## calls it, with its tenth-of-a-second timer run out.
func _check(ranch: Node) -> void:
	ranch.set("_person_aim_t", 0.0)
	ranch.call("_update_person_aim")


func test_the_crosshair_marks_a_townspony_and_not_a_wild_pony() -> void:
	var ranch = RanchScene.instantiate()
	add_child_autofree(ranch)
	await wait_frames(240)
	var cam := ranch.get_viewport().get_camera_3d()
	assert_not_null(cam)
	var hud: Node = ranch.get_node(^"HUD")
	# Tests stand no cast (ranch._people_enabled), so a townspony is stood up the way the
	# Collector's visit builds one.
	var def := CharacterDef.new()
	def.id = &"townspony_test"
	def.display_name = "Townspony"
	def.char_seed = 77
	def.look = {"coat": "c9a0dc", "mane": "6a3d8f"}
	var fennel: Npc = (load("res://actors/npc/npc.gd") as Script).new()
	ranch.add_child(fennel)
	fennel.setup(def)
	for height: float in [0.5, 1.0, 1.5, 1.9]:
		_aim_at(ranch, fennel, 8.0, height)
		await wait_physics_frames(6)
		_check(ranch)
		assert_true(bool(hud.call("aiming_person")),
			"the crosshair %.1f m up her (%.1f m away) shows the bubble" % [height,
			fennel.global_position.distance_to(cam.global_position)])
	fennel.global_position += Vector3(40, 0, 40)
	var wild: Node3D = null
	for p in ranch.get("spawner").call("get_spawned"):
		if is_instance_valid(p) and not (p as Node3D).is_in_group(&"penned"):
			wild = p
			break
	assert_not_null(wild)
	_aim_at(ranch, wild, 7.0)
	wild.set_physics_process(false)
	await wait_physics_frames(6)
	_check(ranch)
	assert_false(bool(hud.call("aiming_person")), "a wild pony is a catch, no bubble")
