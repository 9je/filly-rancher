extends SkeletonModifier3D
## THE TAIL AT A RUN (playtest 2026-11-10 item 76, "player tail still moves oddly when
## running"). Root cause: no clip keys a hair bone, so the pose the hair springs start from is
## the REST pose, the tail's sculpted arch with its tip curling down; and at a run
## PonyRig.influence_for_speed() blends the springs 80% back to that pose (PIN_FLOOR, so the
## tail does not glitch at speed). So at the default run the tail kept its standing shape as
## one rigid mass (from behind: hanging straight down), after a fling on the first stride
## before the pin came in.
##
## This runs BEFORE the hair springs (it sits ahead of HairSpring under the skeleton) and gives
## them a carried pose to start from, in proportion to `carry` (0 standing, 1 at a full run):
## each tail bone is raised about her side axis, more toward the tip, so the curl opens and the
## tail streams back; and a wave runs down the tail once a stride on the clip's own phase (a
## rise and fall, and a smaller side swish a quarter-stride behind it), each bone a little
## later than its parent so it travels root to tip like hair in the wind. The springs still
## add follow-through on top, and their pin now holds the tail to THIS pose.
## Stylised on purpose: a toon tail that streams and bounces with the gallop.

## 0..1: how much of the run carriage to show (the owner sets it from ground speed).
var carry := 0.0
## 0..1 through the current stride (the gallop or trot clip's position over its length).
var phase := 0.0

## Raise per bone at a full run (degrees about her side axis), by depth from the tail's root
## bone (the last entry repeats). The root moves least; the curl near the tip opens most.
const LIFT_DEG: Array[float] = [3.0, 5.0, 16.0, 10.0]
## The stride wave: rise and fall, side swish (degrees per bone), and how far behind its
## parent each bone runs (radians of the stride).
const BOB_DEG := 7.0
const SWISH_DEG := 9.0
const WAVE_LAG := 0.9

## [bone, depth] for every tail bone, parents before children.
var _chain: Array = []
var _fwd := Vector3.FORWARD
var _up := Vector3.UP
var _bound_to: Skeleton3D


func _bind(sk: Skeleton3D) -> void:
	_bound_to = sk
	_chain = tail_chain(sk)
	# Up in skeleton space (an imported armature may carry its own rotation).
	if sk.is_inside_tree():
		_up = (sk.global_transform.basis.inverse() * Vector3.UP).normalized()
	# Her forward in skeleton space: from the hip toward the head, whatever the rig's axes.
	var head := _first_bone(sk, ["DEF_Head", "Head", "head"])
	var hip := _first_bone(sk, ["DEF_Hip", "Pelvis", "Hips", "hip"])
	if head >= 0 and hip >= 0:
		var d := sk.get_bone_global_rest(head).origin - sk.get_bone_global_rest(hip).origin
		d -= _up * d.dot(_up)
		if d.length_squared() > 1e-6:
			_fwd = d.normalized()


static func _first_bone(sk: Skeleton3D, names: Array) -> int:
	for n: String in names:
		var b := sk.find_bone(n)
		if b >= 0:
			return b
	return -1


static func _is_tail(bone_name: String) -> bool:
	return bone_name.to_lower().contains("tail")


## Every tail bone as [bone, depth], depth 0 at a root (a tail bone whose parent is not one),
## ordered parents first so each turn carries down to the bones below it.
static func tail_chain(sk: Skeleton3D) -> Array:
	var out: Array = []
	var queue: Array = []
	for b in sk.get_bone_count():
		if not _is_tail(sk.get_bone_name(b)):
			continue
		var p := sk.get_bone_parent(b)
		if p >= 0 and _is_tail(sk.get_bone_name(p)):
			continue
		queue.append([b, 0])
	while not queue.is_empty():
		var item: Array = queue.pop_front()
		out.append(item)
		for c in sk.get_bone_children(item[0]):
			if _is_tail(sk.get_bone_name(c)):
				queue.append([c, int(item[1]) + 1])
	return out


## The turn (skeleton space) for a bone at `depth`, at `carry` and stride `phase`. Pure.
static func turn_for(depth: int, carry_amount: float, stride_phase: float, side: Vector3,
		up: Vector3) -> Quaternion:
	var lift: float = LIFT_DEG[mini(depth, LIFT_DEG.size() - 1)]
	var wave := TAU * stride_phase - WAVE_LAG * float(depth)
	var pitch := deg_to_rad(lift + BOB_DEG * sin(wave)) * carry_amount
	var yaw := deg_to_rad(SWISH_DEG * sin(wave - PI * 0.5)) * carry_amount
	return Quaternion(up, yaw) * Quaternion(side, pitch)


func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if sk != _bound_to:
		_bind(sk)
	if _chain.is_empty() or carry <= 0.001:
		return
	# Positive turns about `side` raise a tail that points behind her.
	var side := _up.cross(_fwd).normalized()
	for item: Array in _chain:
		var b: int = item[0]
		var turn := turn_for(int(item[1]), carry, phase, side, _up)
		var pose := sk.get_bone_global_pose(b)
		var want := Basis(turn) * pose.basis
		var parent := sk.get_bone_parent(b)
		var parent_basis := sk.get_bone_global_pose(parent).basis if parent >= 0 else Basis()
		var local := (parent_basis.inverse() * want).orthonormalized()
		sk.set_bone_pose_rotation(b, local.get_rotation_quaternion())


## Put a TailCarry under `pony`'s skeleton, ahead of its hair springs (modifiers run in child
## order, so the springs start from the carried pose). Idempotent; null with no tail bones.
static func attach(pony: Node3D) -> SkeletonModifier3D:
	var sk := pony.find_child("Skeleton3D", true, false) as Skeleton3D
	if sk == null or tail_chain(sk).is_empty():
		return null
	var existing := sk.get_node_or_null(^"TailCarry") as SkeletonModifier3D
	if existing != null:
		return existing
	var tc: SkeletonModifier3D = load("res://actors/pony/tail_carry.gd").new()
	tc.name = "TailCarry"
	sk.add_child(tc)
	var spring := sk.get_node_or_null(^"HairSpring")
	if spring != null:
		sk.move_child(tc, spring.get_index())
	return tc
