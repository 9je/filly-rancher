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
