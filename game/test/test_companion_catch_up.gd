extends GutTest
## TUMBLE NEVER STAYS STUCK BEHIND A FENCE (PT2; playtest 2026-11-05 item 58: "tumble gets
## stuck outside of apple area running into fence"). Her follow is a straight line to the
## player; a fence across it held her there for good. Fallen well behind and gaining nothing,
## she catches up: set down just behind the player.

const NpcScript := preload("res://actors/npc/npc.gd")
const LayersScript := preload("res://world/collision_layers.gd")


func _ground() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = LayersScript.TERRAIN
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	shape.shape = box
	shape.position.y = -0.5
	floor_body.add_child(shape)
	add_child_autofree(floor_body)


func test_a_companion_behind_a_fence_catches_up() -> void:
	_ground()
	var fence := StaticBody3D.new()
	fence.collision_layer = LayersScript.PROPS
	var fs := CollisionShape3D.new()
	var fb := BoxShape3D.new()
	fb.size = Vector3(30, 2.5, 0.3)
	fs.shape = fb
	fs.position = Vector3(0, 1.25, 0)
	fence.add_child(fs)
	add_child_autofree(fence)
	var target := Node3D.new()
	target.position = Vector3(0, 0, -12)
	add_child_autofree(target)
	var npc: CharacterBody3D = NpcScript.new()
	npc.name = "Npc_tumble"
	npc.position = Vector3(0, 0.1, 4)
	add_child_autofree(npc)
	npc.set_mode_follow(target)
	await wait_physics_frames(60 * 6)
	assert_lt(npc.global_position.distance_to(target.global_position), 5.0,
		"she is back with the player, not pressed against the fence")
	assert_lt(npc.global_position.z, 0.0, "on the player's side of it")


func test_a_companion_who_is_keeping_up_is_never_moved() -> void:
	_ground()
	var target := Node3D.new()
	target.position = Vector3(0, 0, -4)
	add_child_autofree(target)
	var npc: CharacterBody3D = NpcScript.new()
	npc.position = Vector3(0, 0.1, 0)
	add_child_autofree(npc)
	npc.set_mode_follow(target)
	var jumps := 0
	var last: Vector3 = npc.global_position
	for i in 240:
		await wait_physics_frames(1)
		if npc.global_position.distance_to(last) > 0.5:
			jumps += 1
		last = npc.global_position
	assert_eq(jumps, 0, "she walks; she is never set down while she can walk")
