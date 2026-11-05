extends GutTest
## THE SLAPSTICK BOUNCE (actors/pony/rump_bounce.gd, shaders/bounce.gdshaderinc). Owner,
## 2026-11-05: "i bet flank jiggle could be used for some funny moments (i see a bouncing butt
## as funny not sexual)", and "its my game i want to see if it creates funny elements". Her
## hindquarters wobble on a spring when something slapstick happens to her (a hard landing, a
## flop into a pen) and settle in about a second; at rest they are exactly as modelled.

const BounceScript := preload("res://actors/pony/rump_bounce.gd")


func test_at_rest_nothing_moves() -> void:
	var b: Node = BounceScript.new()
	add_child_autofree(b)
	for i in 30:
		b.call("step", 1.0 / 60.0)
	assert_eq(float(b.call("amount")), 0.0)


func test_a_kick_wobbles_back_and_forth_and_settles() -> void:
	var b: Node = BounceScript.new()
	add_child_autofree(b)
	b.call("kick", 1.0)
	var signs := 0
	var last := 0.0
	var peak := 0.0
	for i in 60:
		b.call("step", 1.0 / 60.0)
		var a := float(b.call("amount"))
		peak = maxf(peak, absf(a))
		if last != 0.0 and signf(a) != signf(last):
			signs += 1
		last = a
	assert_gt(peak, 0.01, "a visible wobble")
	assert_lte(peak, BounceScript.MAX_AMOUNT + 0.0001, "never more than the cap")
	assert_gte(signs, 3, "it wobbles, not just sags")
	for i in 120:
		b.call("step", 1.0 / 60.0)
	assert_almost_eq(float(b.call("amount")), 0.0, 0.002, "settled within three seconds")


func test_a_built_pony_carries_one_with_its_centre_behind_her_hips() -> void:
	var body: Node3D = PonyVisuals.build(load("res://data/ponies/applebloom.tres"))
	add_child_autofree(body)
	var b := body.get_node_or_null(^"RumpBounce")
	assert_not_null(b)
	if b == null:
		return
	var sk: Skeleton3D = body.find_children("*", "Skeleton3D", true, false)[0]
	var pelvis := sk.get_bone_global_rest(sk.find_bone("Pelvis")).origin
	var chest := sk.get_bone_global_rest(sk.find_bone("Chest2")).origin
	var centre: Vector3 = b.call("centre")
	assert_gt((centre - pelvis).dot(pelvis - chest), 0.0, "behind the hips, away from her chest")
	assert_gt(float(b.call("radius")), 0.05)


func test_the_bounce_reaches_her_body_s_meshes() -> void:
	var body: Node3D = PonyVisuals.build(load("res://data/ponies/applebloom.tres"))
	add_child_autofree(body)
	var b := body.get_node(^"RumpBounce")
	b.call("kick", 1.0)
	b.call("step", 0.05)
	var seen := false
	for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		var v: Variant = mi.get_instance_shader_parameter(&"bounce_amount")
		if v != null and absf(float(v)) > 0.0:
			seen = true
	assert_true(seen)


func test_a_hard_landing_bounces_the_player() -> void:
	var world := Node3D.new()
	add_child_autofree(world)
	var floor_body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 1, 20)
	cs.shape = box
	cs.position = Vector3(0, -0.5, 0)
	floor_body.add_child(cs)
	world.add_child(floor_body)
	var player: CharacterBody3D = preload("res://actors/player/player.tscn").instantiate()
	world.add_child(player)
	player.global_position = Vector3(0, 2.5, 0)
	var bounce: Node = null
	var peak := 0.0
	for i in 120:
		await get_tree().physics_frame
		if bounce == null:
			var found := player.find_children("RumpBounce", "", true, false)
			bounce = found[0] if not found.is_empty() else null
		if bounce != null:
			peak = maxf(peak, absf(float(bounce.call("amount"))))
	assert_not_null(bounce, "her body has a bounce")
	assert_gt(peak, 0.005, "she lands rump first")
