extends GutTest
## OWNER PLAYTEST 2026-10-25: "the 2 talking ponies are stuck inside each other". Two
## townsfolk sent to one spot (or following the same player) end up apart.

const NpcScript := preload("res://actors/npc/npc.gd")


func _floor() -> StaticBody3D:
	var f := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	cs.shape = box
	cs.position = Vector3(0, -0.5, 0)
	f.add_child(cs)
	f.collision_layer = 0xFFFF
	return f


func _npc(at: Vector3, n: String) -> CharacterBody3D:
	var npc: CharacterBody3D = NpcScript.new()
	npc.name = n
	add_child_autofree(npc)
	npc.global_position = at
	return npc


func test_two_sent_to_one_spot_settle_apart() -> void:
	add_child_autofree(_floor())
	var a := _npc(Vector3(0, 0.05, 0), "Marigold")
	var b := _npc(Vector3(0.1, 0.05, 0), "Tumble")
	a.call("set_mode_stand", Vector3.ZERO)
	b.call("set_mode_stand", Vector3.ZERO)
	await wait_physics_frames(240)
	var d := Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length()
	assert_gt(d, 1.3, "two townsfolk on one spot step apart (%.2f m)" % d)


func test_two_following_one_target_do_not_overlap() -> void:
	add_child_autofree(_floor())
	var target := Node3D.new()
	add_child_autofree(target)
	target.global_position = Vector3(8, 0, 0)
	var a := _npc(Vector3(0, 0.05, 0.2), "Marigold")
	var b := _npc(Vector3(0, 0.05, -0.2), "Tumble")
	a.call("set_mode_follow", target)
	b.call("set_mode_follow", target)
	await wait_physics_frames(300)
	var d := Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length()
	assert_gt(d, 1.3, "two townsfolk following one player keep apart (%.2f m)" % d)


func _body(at: Vector3, layer: int) -> CharacterBody3D:
	var b := CharacterBody3D.new()
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.42
	cap.height = 1.3
	cs.shape = cap
	cs.position = Vector3(0, 0.65, 0)
	b.add_child(cs)
	b.collision_layer = layer
	b.collision_mask = 0
	add_child_autofree(b)
	b.global_position = at
	return b


## FS3.3: the player stood half inside Old Fennel (bot frames 2026-11-05). A townspony steps
## out of someone STANDING in her, and never out of the way of someone walking (pushed along a
## walker's heading she was herded into the Market wall and blocked the road).
func test_a_townspony_steps_out_of_a_player_standing_in_her() -> void:
	add_child_autofree(_floor())
	var npc := _npc(Vector3(0, 0.05, 0), "Old Fennel")
	npc.call("set_mode_stand", Vector3.ZERO)
	var player := _body(Vector3(0.5, 0.05, 0), preload("res://world/collision_layers.gd").PLAYER)
	await wait_physics_frames(240)
	var d := Vector2(npc.global_position.x - player.global_position.x, npc.global_position.z - player.global_position.z).length()
	assert_gt(d, NpcScript.STANDING_SPACE - 0.2, "clear of her (%.2f m)" % d)


func test_a_walking_player_does_not_push_her() -> void:
	add_child_autofree(_floor())
	var npc := _npc(Vector3(0, 0.05, -0.8), "Bramble")
	npc.call("set_mode_stand", Vector3(0, 0, -0.8))
	var player := _body(Vector3(0, 0.05, 0), preload("res://world/collision_layers.gd").PLAYER)
	player.velocity = Vector3(0, 0, -3.0)
	await wait_physics_frames(5)
	assert_eq(npc.call("_space_push"), Vector3.ZERO, "no push from someone on the move")


## Review 2026-11-06: the step out of the player moved her spot for good, so standing in Old
## Fennel a few times walked her metres off her talk spot, onto the road. She makes room, and
## once nobody is standing in her she goes back.
func test_she_goes_back_to_her_spot_when_the_player_steps_away() -> void:
	add_child_autofree(_floor())
	var npc := _npc(Vector3(0, 0.05, 0), "Old Fennel")
	npc.call("set_mode_stand", Vector3.ZERO)
	var player := _body(Vector3(0.5, 0.05, 0), preload("res://world/collision_layers.gd").PLAYER)
	await wait_physics_frames(240)
	var d := Vector2(npc.global_position.x - player.global_position.x, npc.global_position.z - player.global_position.z).length()
	assert_gt(d, NpcScript.STANDING_SPACE - 0.2, "she made room (%.2f m)" % d)
	player.global_position = Vector3(20, 0.05, 20)
	await wait_physics_frames(600)
	var off := Vector2(npc.global_position.x, npc.global_position.z).length()
	assert_lt(off, 0.7, "back on her spot (%.2f m off)" % off)
