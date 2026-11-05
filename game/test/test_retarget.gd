extends GutTest
## THE MANE SIX GET THE FULL CLIP SET (FS4.1; systems/retarget.gd). Their rig ships idle, walk
## and gallop only, so Fluttershy, Rainbow Dash, Twilight, Applejack and Rarity could never sit,
## graze, hop, startle or struggle. The PonySFM cast's twenty clips are carried across: each
## mapped bone takes the WORLD rotation its source bone made away from rest, so the two rigs'
## different bone axes and hierarchies do not matter.

const RetargetScript := preload("res://systems/retarget.gd")


## Root -> hip -> leg, the hip turned on its own axis so the two rigs' axes differ.
func _skeleton(names: Array, hip_axis_twist: float) -> Skeleton3D:
	var sk := Skeleton3D.new()
	sk.add_bone(names[0])
	sk.add_bone(names[1])
	sk.set_bone_parent(1, 0)
	sk.add_bone(names[2])
	sk.set_bone_parent(2, 1)
	sk.set_bone_rest(0, Transform3D(Basis(), Vector3(0, 0, 0)))
	sk.set_bone_rest(1, Transform3D(Basis(Vector3.UP, hip_axis_twist), Vector3(0, 1, 0)))
	sk.set_bone_rest(2, Transform3D(Basis(), Vector3(0, -0.5, 0)))
	for i in 3:
		sk.set_bone_pose(i, sk.get_bone_rest(i))
	add_child_autofree(sk)
	return sk


func test_a_turned_source_bone_turns_its_target_the_same_way_in_the_world() -> void:
	var src := _skeleton(["Root", "Pelvis", "LeftThigh"], 0.0)
	var tgt := _skeleton(["Belly", "DEF_Hip", "DEF_Thigh.L"], 1.2)
	var turn := Quaternion(Vector3.RIGHT, 0.6)
	# The source hip bends forward 0.6 rad in the world.
	var rest_g := src.get_bone_global_rest(1).basis.get_rotation_quaternion()
	var want_g := turn * rest_g
	src.set_bone_pose_rotation(1, (src.get_bone_global_rest(0).basis.get_rotation_quaternion().inverse() * want_g))
	var locals: Dictionary = RetargetScript.pose_for(src, tgt, {"DEF_Hip": "Pelvis", "DEF_Thigh.L": "LeftThigh"})
	tgt.set_bone_pose_rotation(1, locals["DEF_Hip"])
	tgt.set_bone_pose_rotation(2, locals["DEF_Thigh.L"])
	var got := tgt.get_bone_global_pose(1).basis.get_rotation_quaternion() \
		* tgt.get_bone_global_rest(1).basis.get_rotation_quaternion().inverse()
	assert_almost_eq(got.angle_to(turn), 0.0, 0.001, "the target hip made the same world turn")
	# Its child (unturned in the source) stays at rest relative to the world change: its world
	# delta equals the hip's.
	var child := tgt.get_bone_global_pose(2).basis.get_rotation_quaternion() \
		* tgt.get_bone_global_rest(2).basis.get_rotation_quaternion().inverse()
	assert_almost_eq(child.angle_to(turn), 0.0, 0.001)


func test_the_mane_six_map_names_bones_both_rigs_have() -> void:
	var sfm: Node3D = PonyVisuals.build(load("res://data/ponies/applebloom.tres"))
	var m6: Node3D = PonyVisuals.build(load("res://data/ponies/fluttershy.tres"))
	add_child_autofree(sfm)
	add_child_autofree(m6)
	var ss: Skeleton3D = sfm.find_children("*", "Skeleton3D", true, false)[0]
	var ts: Skeleton3D = m6.find_children("*", "Skeleton3D", true, false)[0]
	for t: String in RetargetScript.MANE_SIX_MAP:
		assert_gte(ts.find_bone(t), 0, "Mane Six rig has %s" % t)
		assert_gte(ss.find_bone(RetargetScript.MANE_SIX_MAP[t]), 0, "PonySFM rig has %s" % RetargetScript.MANE_SIX_MAP[t])


func test_a_mane_six_pony_can_sit_graze_and_struggle() -> void:
	var m6: Node3D = PonyVisuals.build(load("res://data/ponies/fluttershy.tres"))
	add_child_autofree(m6)
	var anim: AnimationPlayer = m6.find_children("*", "AnimationPlayer", true, false)[0]
	for clip: StringName in [&"sit", &"graze", &"hop", &"startle", &"struggle", &"sleep"]:
		assert_true(anim.has_animation(clip), "Fluttershy has %s" % clip)
	assert_true(anim.has_animation(&"idle"), "and keeps her own idle")
	assert_false(anim.has_animation(&"trot"), "and her own walk and gallop: no borrowed trot")
	# And the clips move her: a baked sit is not her rest pose over and over.
	var sit := anim.get_animation(&"sit")
	var sk: Skeleton3D = m6.find_children("*", "Skeleton3D", true, false)[0]
	var moved := 0.0
	for t in sit.get_track_count():
		if sit.track_get_type(t) != Animation.TYPE_ROTATION_3D or sit.track_get_key_count(t) == 0:
			continue
		var bone := sk.find_bone(String(sit.track_get_path(t)).get_slice(":", 1))
		var rest := sk.get_bone_rest(bone).basis.orthonormalized().get_rotation_quaternion()
		var mid: Quaternion = sit.track_get_key_value(t, sit.track_get_key_count(t) / 2)
		moved = maxf(moved, mid.angle_to(rest))
	assert_gt(moved, 0.2, "some bone of hers bends in the sit")
