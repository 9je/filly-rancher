class_name Retarget
extends RefCounted
## THE MANE SIX GET THE PONYSFM CAST'S CLIPS (FS4.1). Their rig ships idle, walk and gallop
## only; the PonySFM cast has twenty (sit, graze, hop, startle, struggle, sleep and the rest).
## Each mapped target bone takes the WORLD rotation its source bone made away from its own
## rest pose, applied to the target bone's rest, so the two rigs' different bone axes and
## hierarchies (the Mane Six hang their chest beside the hip, not under it) do not matter.
## The hip's travel is carried too, scaled by hip height. Unmapped target bones keep their
## rest relative to their parent.
##
## bake() samples each source clip the target lacks and returns new Animations; PonyVisuals
## adds them to a Mane Six body when it is built (cached per model, so the work is done once
## a session).

## Target (Mane Six, DEF_) bone -> source (PonySFM ReVAmped) bone.
const MANE_SIX_MAP := {
	"DEF_Hip": "Pelvis", "DEF_Chest1": "Chest1", "DEF_Chest2": "Chest2",
	"DEF_Neck1": "Neck", "DEF_Head": "Head", "DEF_Jaw": "Javv",
	"DEF_Ear1.L": "LeftEar", "DEF_Ear1.R": "RightEar",
	"DEF_FrontUpperLeg.L": "LeftShoulder", "DEF_LowerFrontLeg.L": "LeftForearm", "DEF_FrontHoof.L": "LeftHand",
	"DEF_FrontUpperLeg.R": "RightShoulder", "DEF_LowerFrontLeg.R": "RightForearm", "DEF_FrontHoof.R": "RightHand",
	"DEF_Thigh.L": "LeftThigh", "DEF_RearUpperLeg.L": "LeftLeg1", "DEF_RearLowerLeg.L": "LeftLeg2", "DEF_RearHoof.L": "LeftFoot",
	"DEF_Thigh.R": "RightThigh", "DEF_RearUpperLeg.R": "RightLeg1", "DEF_RearLowerLeg.R": "RightLeg2", "DEF_RearHoof.R": "RightFoot",
	"DEF_Tail1-1": "TailBase", "DEF_Tail1-2": "Tail1", "DEF_Tail1-3": "Tail2", "DEF_Tail1-4": "Tail3",
}
## HER NECK CARRIES HER HEAD DOWN (PS1 item 17, "Twilight twisted at a broken angle"). The
## donor's clips lower the head at the skull joint alone (Lyra's graze keys Head, never Neck),
## and carried bone for bone that whole bend landed on one joint of a rig whose head pivot sits
## elsewhere in the skull: 68 degrees there folded her muzzle into her chest. Each neck bone
## here takes this share of the head's turn beyond the neck's own, measured from the chest end,
## so the head ends where the clip puts it and the bend is spread over three joints.
const NECK_SHARE := {"DEF_Neck1": 0.5, "DEF_Neck2": 0.9}

## The pony whose clips are carried across: an adult mare, so the proportions are a mare's.
const DONOR := "res://data/ponies/lyra.tres"
const FPS := 30.0
## Locomotion stays the rig's own (its walk and gallop are native): a borrowed trot would be
## mixed into every move she makes.
const SKIP: Array[StringName] = [&"trot"]
## HOW MUCH OF A CLIP'S TURN IS CARRIED (P9, playtest 2026-11-10 item 30: "ponies in pens lie
## sideways or face-down"). The donor's graze drops a mare's long neck 62 to 68 degrees and
## pitches her body 16; on the Mane Six's big head and short neck the same turn buried the
## muzzle in the dirt and folded the forelegs, so from the pen rail she read as a pony lying
## face-down. Graze carries this share of every bone's turn and of the body's drop: the head
## still goes down to the grass, the body stays a standing pony's.
const CLIP_CARRY := {&"graze": 0.5}

static var _cache := {}


static func _q(b: Basis) -> Quaternion:
	return b.orthonormalized().get_rotation_quaternion()


## Every bone's skeleton-space transform in `anim` at `t` (rest where it has no track),
## evaluated from the keys alone: no AnimationPlayer, no scene tree.
static func _globals(sk: Skeleton3D, anim: Animation, t: float) -> Array[Transform3D]:
	var rot := {}
	var pos := {}
	if anim != null:
		for tr in anim.get_track_count():
			var bone := sk.find_bone(String(anim.track_get_path(tr)).get_slice(":", 1))
			if bone < 0 or anim.track_get_key_count(tr) == 0:
				continue
			match anim.track_get_type(tr):
				Animation.TYPE_ROTATION_3D:
					rot[bone] = anim.rotation_track_interpolate(tr, t)
				Animation.TYPE_POSITION_3D:
					pos[bone] = anim.position_track_interpolate(tr, t)
	var out: Array[Transform3D] = []
	out.resize(sk.get_bone_count())
	for b in sk.get_bone_count():
		var rest := sk.get_bone_rest(b)
		var local := Transform3D(Basis(rot.get(b, _q(rest.basis)) as Quaternion), pos.get(b, rest.origin) as Vector3)
		var parent := sk.get_bone_parent(b)
		out[b] = (out[parent] * local) if parent >= 0 else local
	return out


## `node`'s transform in `root`'s space, from the nodes' own transforms (no tree needed).
static func _space(node: Node, root: Node) -> Transform3D:
	var xf := Transform3D()
	var n := node
	while n != null and n != root:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


## The local rotation of each mapped target bone that carries the source's world turns from
## `src_ref` to `src_now` onto the target's own reference pose `tgt_ref` (all skeleton space,
## by bone index). Unmapped target bones keep their reference pose relative to their parent.
static func _locals_for(src: Skeleton3D, src_now: Array[Transform3D], src_ref: Array[Transform3D],
		tgt: Skeleton3D, tgt_ref: Array[Transform3D], map: Dictionary,
		src_space := Quaternion.IDENTITY, tgt_space := Quaternion.IDENTITY, carry := 1.0) -> Dictionary:
	var out := {}
	# Each skeleton sits in its own turned space inside its model (the two rigs were exported
	# with different rotations): a source turn is carried through model space.
	var to_tgt := tgt_space.inverse() * src_space
	# Every mapped bone's world turn away from its reference pose, in the target's space.
	var deltas := {}
	for name: String in map:
		var s := src.find_bone(String(map[name]))
		if s >= 0 and tgt.find_bone(name) >= 0:
			var delta := _q(src_now[s].basis) * _q(src_ref[s].basis).inverse()
			if carry < 1.0:
				delta = Quaternion.IDENTITY.slerp(delta.normalized(), carry)
			deltas[name] = to_tgt * delta * to_tgt.inverse()
	if deltas.has("DEF_Neck1") and deltas.has("DEF_Head"):
		var neck: Quaternion = deltas["DEF_Neck1"]
		var beyond: Quaternion = (neck.inverse() * (deltas["DEF_Head"] as Quaternion)).normalized()
		for name: String in NECK_SHARE:
			if tgt.find_bone(name) >= 0:
				deltas[name] = (neck * Quaternion.IDENTITY.slerp(beyond, float(NECK_SHARE[name]))).normalized()
	var g := {}
	for i in tgt.get_bone_count():
		var parent := tgt.get_bone_parent(i)
		var pg: Quaternion = g[parent] if parent >= 0 else Quaternion.IDENTITY
		var ref_parent := _q(tgt_ref[parent].basis) if parent >= 0 else Quaternion.IDENTITY
		var local := (ref_parent.inverse() * _q(tgt_ref[i].basis)).normalized()
		var name := tgt.get_bone_name(i)
		if deltas.has(name):
			local = (pg.inverse() * ((deltas[name] as Quaternion) * _q(tgt_ref[i].basis))).normalized()
			out[name] = local
		g[i] = pg * local
	return out


## The local rotation of each mapped target bone for the source skeleton's current pose,
## both measured from their rest poses.
static func pose_for(src: Skeleton3D, tgt: Skeleton3D, map: Dictionary) -> Dictionary:
	var now: Array[Transform3D] = []
	var ref: Array[Transform3D] = []
	for b in src.get_bone_count():
		now.append(src.get_bone_global_pose(b))
		ref.append(src.get_bone_global_rest(b))
	var tref: Array[Transform3D] = []
	for b in tgt.get_bone_count():
		tref.append(tgt.get_bone_global_rest(b))
	return _locals_for(src, now, ref, tgt, tref, map)


## Every clip `donor` has that `target` lacks, carried onto `target`'s skeleton. Both rigs are
## measured from their own standing pose (the first frame of their idle), not their rest: a
## rest pose is often not a stand, and the difference turned every clip by it.
static func bake(donor: Node3D, target: Node3D, map: Dictionary = MANE_SIX_MAP) -> Dictionary:
	var src_sk: Skeleton3D = donor.find_children("*", "Skeleton3D", true, false)[0]
	var tgt_sk: Skeleton3D = target.find_children("*", "Skeleton3D", true, false)[0]
	var src_anim: AnimationPlayer = donor.find_children("*", "AnimationPlayer", true, false)[0]
	var tgt_anim: AnimationPlayer = target.find_children("*", "AnimationPlayer", true, false)[0]
	var root := tgt_anim.get_node(tgt_anim.root_node)
	var sk_path := String(root.get_path_to(tgt_sk))
	var src_ref := _globals(src_sk, src_anim.get_animation(&"idle") if src_anim.has_animation(&"idle") else null, 0.0)
	var tgt_idle: Animation = tgt_anim.get_animation(&"idle") if tgt_anim.has_animation(&"idle") else null
	var tgt_ref := _globals(tgt_sk, tgt_idle, 0.0)
	var src_xf := _space(src_sk, donor)
	var tgt_xf := _space(tgt_sk, target)
	var src_space := _q(src_xf.basis)
	var tgt_space := _q(tgt_xf.basis)
	var src_hip := src_sk.find_bone(String(map.get("DEF_Hip", "")))
	var tgt_hip := tgt_sk.find_bone("DEF_Hip")
	var ratio := 1.0
	if src_hip >= 0 and tgt_hip >= 0:
		ratio = (tgt_xf * tgt_ref[tgt_hip].origin).y / maxf(0.01, (src_xf * src_ref[src_hip].origin).y)
	var out := {}
	for clip: StringName in src_anim.get_animation_list():
		if tgt_anim.has_animation(clip) or String(clip).begins_with("RESET") or clip in SKIP:
			continue
		var src_clip := src_anim.get_animation(clip)
		var carry := float(CLIP_CARRY.get(clip, 1.0))
		var a := Animation.new()
		a.length = src_clip.length
		a.loop_mode = src_clip.loop_mode
		var tracks := {}
		for t: String in map.keys() + NECK_SHARE.keys():
			if tgt_sk.find_bone(t) < 0 or tracks.has(t):
				continue
			var ti := a.add_track(Animation.TYPE_ROTATION_3D)
			a.track_set_path(ti, NodePath("%s:%s" % [sk_path, t]))
			tracks[t] = ti
		# The body's travel goes on the bone the hip AND the chest hang from: on the Mane Six
		# rig they are siblings under CON_Belly, and dropping the hip alone left the chest up
		# and stood her on her hind legs.
		var body_bone := tgt_sk.get_bone_parent(tgt_hip) if tgt_hip >= 0 else -1
		var hip_track := -1
		if body_bone >= 0:
			hip_track = a.add_track(Animation.TYPE_POSITION_3D)
			a.track_set_path(hip_track, NodePath("%s:%s" % [sk_path, tgt_sk.get_bone_name(body_bone)]))
		# Every other bone her idle poses holds that pose (the body roots CON_Belly and kin):
		# the math above assumed it, and left unkeyed they kept whatever the last clip left.
		if tgt_idle != null:
			for tr in tgt_idle.get_track_count():
				var bone_name := String(tgt_idle.track_get_path(tr)).get_slice(":", 1)
				var kind := tgt_idle.track_get_type(tr)
				if tgt_idle.track_get_key_count(tr) == 0 or (tracks.has(bone_name) and kind == Animation.TYPE_ROTATION_3D) \
						or (body_bone >= 0 and bone_name == tgt_sk.get_bone_name(body_bone) and kind == Animation.TYPE_POSITION_3D):
					continue
				if kind != Animation.TYPE_ROTATION_3D and kind != Animation.TYPE_POSITION_3D:
					continue
				var hold := a.add_track(kind)
				a.track_set_path(hold, tgt_idle.track_get_path(tr))
				if kind == Animation.TYPE_ROTATION_3D:
					a.rotation_track_insert_key(hold, 0.0, tgt_idle.rotation_track_interpolate(tr, 0.0))
				else:
					a.position_track_insert_key(hold, 0.0, tgt_idle.position_track_interpolate(tr, 0.0))
		var frames := maxi(1, int(ceil(src_clip.length * FPS)))
		for f in frames + 1:
			var t := minf(float(f) / FPS, src_clip.length)
			var now := _globals(src_sk, src_clip, t)
			var locals := _locals_for(src_sk, now, src_ref, tgt_sk, tgt_ref, map, src_space, tgt_space, carry)
			for name: String in locals:
				if tracks.has(name):
					a.rotation_track_insert_key(tracks[name], t, locals[name])
			if hip_track >= 0 and src_hip >= 0:
				# Through model space, at the target's hip height.
				var travel := tgt_xf.basis.inverse() * (src_xf.basis * (now[src_hip].origin - src_ref[src_hip].origin) * ratio * carry)
				var parent := tgt_sk.get_bone_parent(body_bone)
				var pg: Transform3D = tgt_ref[parent] if parent >= 0 else Transform3D()
				a.position_track_insert_key(hip_track, t, pg.affine_inverse() * (tgt_ref[body_bone].origin + travel))
		out[clip] = a
	return out


## Give a Mane Six body the clips it lacks (built once per model, then shared).
static func dress(target: Node3D, model_path: String) -> int:
	var tgt_sk: Array = target.find_children("*", "Skeleton3D", true, false)
	var tgt_anim: Array = target.find_children("*", "AnimationPlayer", true, false)
	if tgt_sk.is_empty() or tgt_anim.is_empty() or (tgt_sk[0] as Skeleton3D).find_bone("DEF_Hip") < 0:
		return 0
	if not _cache.has(model_path):
		var donor_data: PonyData = load(DONOR)
		if donor_data == null or not ResourceLoader.exists(donor_data.model_path):
			_cache[model_path] = {}
		else:
			var donor: Node3D = (load(donor_data.model_path) as PackedScene).instantiate()
			_cache[model_path] = bake(donor, target)
			donor.free()
	var lib := (tgt_anim[0] as AnimationPlayer).get_animation_library(&"")
	var added := 0
	for clip: StringName in _cache[model_path]:
		if not lib.has_animation(clip):
			lib.add_animation(clip, _cache[model_path][clip])
			added += 1
	return added
