extends GutTest
## TWILIGHT TWISTED AT A BROKEN ANGLE (playtest 2026-11-05 item 17, [21][52]; PLAN.md PS1).
## The Mane Six borrow the PonySFM cast's clips (systems/retarget.gd). The donor's graze, sleep
## and the rest lower the head at the skull joint alone (Lyra's clips key Head, not Neck), and
## carried bone for bone that whole bend landed on Twilight's head joint: her pivot sits
## elsewhere in the skull, so 68 degrees there folded her muzzle into her chest. A broken
## angle, measured: no joint from the chest to the head bends more than NECK_JOINT_MAX from her
## stand in any borrowed clip, for every one of the Mane Six.

const RetargetScript := preload("res://systems/retarget.gd")
const MANE_SIX := ["twilight", "rarity", "pinkiepie", "rainbowdash", "applejack", "fluttershy"]
const CHAIN := ["DEF_Chest2", "DEF_Neck1", "DEF_Neck2", "DEF_Head"]
const NECK_JOINT_MAX := 45.0


func _dressed(id: String) -> Node3D:
	var data: PonyData = load("res://data/ponies/%s.tres" % id)
	var body: Node3D = (load(data.model_path) as PackedScene).instantiate()
	add_child_autofree(body)
	RetargetScript.dress(body, data.model_path)
	return body


static func _deg(q: Quaternion) -> float:
	var d := rad_to_deg(q.normalized().get_angle())
	return 360.0 - d if d > 180.0 else d


## The worst bend of any chest-to-head joint away from her stand, over every frame of every
## borrowed clip: [degrees, "clip joint"].
func _worst_bend(body: Node3D) -> Array:
	var sk: Skeleton3D = body.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = body.find_children("*", "AnimationPlayer", true, false)[0]
	var ids: Array[int] = []
	for n: String in CHAIN:
		ids.append(sk.find_bone(n))
	var stand: Array[Transform3D] = RetargetScript._globals(sk, ap.get_animation(&"idle"), 0.0)
	var worst := [0.0, ""]
	for clip: StringName in ap.get_animation_list():
		if clip in [&"idle", &"walk", &"gallop", &"RESET"] or String(clip).begins_with("RESET"):
			continue
		var anim := ap.get_animation(clip)
		var t := 0.0
		while t <= anim.length:
			var now: Array[Transform3D] = RetargetScript._globals(sk, anim, t)
			for k in range(1, ids.size()):
				var a: int = ids[k - 1]
				var b: int = ids[k]
				if a < 0 or b < 0:
					continue
				var rel_now := (now[a].basis.inverse() * now[b].basis).get_rotation_quaternion()
				var rel_stand := (stand[a].basis.inverse() * stand[b].basis).get_rotation_quaternion()
				var bend := _deg(rel_stand.inverse() * rel_now)
				if bend > float(worst[0]):
					worst = [bend, "%s %s at %.2fs" % [clip, CHAIN[k], t]]
			t += 1.0 / 15.0
	return worst


func test_no_neck_joint_folds_in_any_borrowed_clip() -> void:
	for id: String in MANE_SIX:
		var worst := _worst_bend(_dressed(id))
		assert_lt(float(worst[0]), NECK_JOINT_MAX,
			"%s: %s bends %.0f degrees from her stand" % [id, worst[1], float(worst[0])])


## The bend is shared down the neck, not lost: her head still drops as far as the donor's.
func test_her_head_still_drops_in_the_graze() -> void:
	var body := _dressed("twilight")
	var sk: Skeleton3D = body.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = body.find_children("*", "AnimationPlayer", true, false)[0]
	var head := sk.find_bone("DEF_Head")
	var stand: Array[Transform3D] = RetargetScript._globals(sk, ap.get_animation(&"idle"), 0.0)
	var graze := ap.get_animation(&"graze")
	var low: Array[Transform3D] = RetargetScript._globals(sk, graze, graze.length * 0.5)
	assert_gt(_deg(stand[head].basis.get_rotation_quaternion().inverse() * low[head].basis.get_rotation_quaternion()), 40.0,
		"the head turns down to the grass")
