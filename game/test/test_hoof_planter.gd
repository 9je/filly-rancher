extends GutTest
## HOOVES ON THE GROUND (actors/pony/hoof_planter.gd). The clips are authored on a flat floor,
## so on a slope a pony stood with her downhill hooves in the air and her uphill ones in the
## hill. HoofPlanter runs after the clip and bends each leg so its hoof meets the ground under
## it (owner 2026-11-05, of home-equestria's procedural legs: "leg animations seem sick").

const Planter := preload("res://actors/pony/hoof_planter.gd")


func test_the_solve_reaches_a_target_it_can_reach_and_keeps_both_bones_their_length() -> void:
	var r := Vector3(0, 1.0, 0)
	var m := Vector3(0, 0.5, 0.05)
	var e := Vector3(0, 0.0, 0)
	var target := Vector3(0, 0.2, 0.1)
	var out: Array = Planter.solve(r, m, e, target)
	var m2: Vector3 = out[0]
	var e2: Vector3 = out[1]
	assert_almost_eq(e2.distance_to(target), 0.0, 0.001)
	assert_almost_eq(r.distance_to(m2), r.distance_to(m), 0.001)
	assert_almost_eq(m2.distance_to(e2), m.distance_to(e), 0.001)


func test_the_knee_bends_the_way_the_clip_bent_it() -> void:
	var r := Vector3(0, 1.0, 0)
	var m := Vector3(0, 0.5, 0.05)
	var e := Vector3(0, 0.0, 0)
	var out: Array = Planter.solve(r, m, e, Vector3(0, 0.3, 0))
	assert_gt((out[0] as Vector3).z, 0.05, "folded further forward, not flipped back")


func test_a_target_out_of_reach_straightens_the_leg_toward_it() -> void:
	var r := Vector3(0, 1.0, 0)
	var m := Vector3(0, 0.5, 0.05)
	var e := Vector3(0, 0.0, 0)
	var out: Array = Planter.solve(r, m, e, Vector3(0, -1.0, 0))
	var e2: Vector3 = out[1]
	assert_lt(e2.y, 0.0)
	assert_almost_eq(r.distance_to(e2), r.distance_to(m) + m.distance_to(e), 0.01)


func test_a_hoof_is_lifted_onto_higher_ground_and_dropped_onto_lower() -> void:
	assert_almost_eq(Planter.offset_for(0.0, 0.15, 0.4), 0.15, 0.0001)
	assert_almost_eq(Planter.offset_for(0.0, -0.1, 0.4), -0.1, 0.0001)


func test_a_cliff_under_a_hoof_is_not_reached_for() -> void:
	assert_almost_eq(Planter.offset_for(0.0, 3.0, 0.4), 0.4, 0.0001)
	assert_almost_eq(Planter.offset_for(0.0, -3.0, 0.4), -0.4, 0.0001)


func _hooves(sk: Skeleton3D) -> Dictionary:
	var out := {}
	for leaf: String in ["LeftHand", "RightHand", "LeftFoot", "RightFoot"]:
		out[leaf] = sk.global_transform * sk.get_bone_global_pose(sk.find_bone(leaf)).origin
	return out


func test_on_a_slope_every_hoof_of_a_real_pony_stands_on_the_ground() -> void:
	# A hill rising across her and along her length through her feet; she stands on it at
	# the origin.
	var hill := func(x: float, z: float) -> float: return x * 0.2 + z * 0.2
	var data: PonyData = load("res://data/ponies/applebloom.tres")
	var body: Node3D = PonyVisuals.build(data)
	add_child_autofree(body)
	var sk: Skeleton3D = body.find_children("*", "Skeleton3D", true, false)[0]
	var anim: AnimationPlayer = body.find_children("*", "AnimationPlayer", true, false)[0]
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var clip: StringName = &"idle" if anim.has_animation(&"idle") else anim.get_animation_list()[0]
	anim.play(clip)
	anim.seek(0.0, true)
	# Her hooves on the flat, the way the clip stands her.
	var flat := _hooves(sk)
	var planter: Node = Planter.new()
	planter.set("ground", hill)
	sk.add_child(planter)
	var planted := {}
	var grab := func() -> void: planted.merge(_hooves(sk), true)
	sk.skeleton_updated.connect(grab)
	for i in 4:
		anim.seek(0.0, true)
		await get_tree().process_frame
	sk.skeleton_updated.disconnect(grab)
	assert_false(planted.is_empty(), "the skeleton was posed")
	var spread := 0.0
	for leaf: String in flat:
		var f: Vector3 = flat[leaf]
		var p: Vector3 = planted[leaf]
		spread = maxf(spread, absf(float(hill.call(f.x, f.z))))
		# Planted, a hoof sits the clip's height over the hill under it, not over the flat.
		assert_almost_eq(p.y - f.y, float(hill.call(p.x, p.z)), 0.04, "%s on the hill" % leaf)
	assert_gt(spread, 0.04, "the hill really is under her hooves")
