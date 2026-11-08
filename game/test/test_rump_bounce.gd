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


## PS11 G11: a spring at rest stays at rest until it is kicked, so it stops stepping itself
## every frame (108 of them were 0.4 ms of every frame of the 60-pony check doing nothing), and
## a kick wakes it.
func test_a_spring_at_rest_sleeps_until_kicked() -> void:
	var b: Node = BounceScript.new()
	add_child_autofree(b)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(b.is_processing(), "at rest, it does not step every frame")
	b.call("kick", 1.0)
	assert_true(b.is_processing(), "a kick wakes it")
	for i in 20:
		await get_tree().process_frame
	assert_ne(float(b.call("amount")), 0.0, "and it wobbles on its own")
	for i in 900:
		b.call("step", 1.0 / 60.0)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(float(b.call("amount")), 0.0, "settled")
	assert_false(b.is_processing(), "and asleep again")


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
	assert_lte(peak, BounceScript.MAX_AMOUNT * float(b.call("gain")) + 0.0001,
		"never more than the cap, at this body's gain (P8 item 36)")
	assert_gte(signs, 3, "it wobbles, not just sags")
	# Long enough to read at full speed (owner: "at full speed it's too short and fast"), and
	# still gone in a few seconds.
	for i in 180:
		b.call("step", 1.0 / 60.0)
	assert_almost_eq(float(b.call("amount")), 0.0, 0.002, "settled within four seconds")


func test_a_built_pony_carries_one_with_its_centre_behind_her_hips() -> void:
	for id: String in ["applebloom", "fluttershy"]:
		await _centre_behind_hips(id)


## Both rigs: the PonySFM cast (Pelvis, Chest2) and the Mane Six's (DEF_Hip, DEF_Chest2).
func _centre_behind_hips(id: String) -> void:
	var body: Node3D = PonyVisuals.build(load("res://data/ponies/%s.tres" % id))
	add_child_autofree(body)
	var b := body.get_node_or_null(^"RumpBounce")
	assert_not_null(b)
	if b == null:
		return
	var sk: Skeleton3D = body.find_children("*", "Skeleton3D", true, false)[0]
	var hip_bone := sk.find_bone("Pelvis") if sk.find_bone("Pelvis") >= 0 else sk.find_bone("DEF_Hip")
	var chest_bone := sk.find_bone("Chest2") if sk.find_bone("Chest2") >= 0 else sk.find_bone("DEF_Chest2")
	var pelvis := sk.get_bone_global_rest(hip_bone).origin
	var chest := sk.get_bone_global_rest(chest_bone).origin
	var centre: Vector3 = b.call("centre")
	assert_gt((centre - pelvis).dot(pelvis - chest), 0.0, "behind the hips, away from her chest")
	assert_gt(float(b.call("radius")), 0.05, "%s has a rump to bounce" % id)


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


func test_both_rigs_get_a_jiggle_the_same_size() -> void:
	# The Mane Six's rig sized off its hip bone gave them a third of everyone else's.
	var sizes := {}
	for id: String in ["applebloom", "fluttershy", "rainbowdash", "derpyhooves"]:
		var body: Node3D = PonyVisuals.build(load("res://data/ponies/%s.tres" % id))
		add_child_autofree(body)
		sizes[id] = float(body.get_node(^"RumpBounce").call("radius"))
	var lo: float = sizes.values().min()
	var hi: float = sizes.values().max()
	assert_gt(lo, hi * 0.75, "every pony's jiggle within a quarter of the others: %s" % sizes)


func test_her_mane_and_tail_are_thrown_with_the_bounce_and_let_go_after() -> void:
	# Owner: "maybe make tail and hair bounce a little more obvious".
	var body: Node3D = PonyVisuals.build(load("res://data/ponies/applebloom.tres"))
	add_child_autofree(body)
	var sims := body.find_children("*", "SpringBoneSimulator3D", true, false)
	assert_false(sims.is_empty(), "she has hair springs")
	if sims.is_empty():
		return
	var sim: SpringBoneSimulator3D = sims[0]
	var b := body.get_node(^"RumpBounce")
	b.call("kick", 1.0)
	b.call("step", 1.0 / 60.0)
	assert_lt(sim.get_external_force().y, -0.1, "flung down as she lands")
	for i in 420:
		b.call("step", 1.0 / 60.0)
	assert_eq(sim.get_external_force(), Vector3.ZERO, "let go once she has settled")


## PT11 (playtest 2026-11-05: "i was dropping twilight from the beam i thought it would do it
## from that height"): a pony who lands hard bounces, as the player does.
func test_a_pony_dropped_from_a_height_bounces_on_landing() -> void:
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 1, 20)
	shape.shape = box
	shape.position.y = -0.5
	floor_body.add_child(shape)
	add_child_autofree(floor_body)
	var pony: CharacterBody3D = preload("res://actors/pony/pony.tscn").instantiate()
	pony.position = Vector3(0, 4.0, 0)
	pony.call("setup", load("res://data/ponies/applebloom.tres"))
	add_child_autofree(pony)
	var bounce: Node = pony.find_children("RumpBounce", "", true, false)[0]
	var moved := false
	for f in 120:
		await wait_physics_frames(1)
		if absf(float(bounce.call("amount"))) > 0.005:
			moved = true
			break
	assert_true(moved, "she bounced when she hit the ground")


## P8, playtest 2026-11-08 item 36: the jiggle read on big ponies only. A smaller drawn body
## bounces harder, up to the cap on the size gain, and every body at least GAIN.
func test_a_small_body_bounces_harder_than_a_full_size_one() -> void:
	var body: Node3D = PonyVisuals.build(load("res://data/ponies/applebloom.tres"))
	add_child_autofree(body)
	var b: Node = body.find_children("RumpBounce", "", true, false)[0]
	b.call("scale_to", 1.0)
	var full := float(b.call("gain"))
	b.call("scale_to", 0.7)
	var small := float(b.call("gain"))
	assert_gte(full, BounceScript.GAIN - 0.0001)
	assert_gt(small, full, "a 0.7 body bounces harder")
	assert_lte(small, BounceScript.GAIN * BounceScript.MAX_SIZE_GAIN + 0.0001)
