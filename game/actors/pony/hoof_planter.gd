class_name HoofPlanter
extends SkeletonModifier3D
## HOOVES ON THE GROUND. The clips are authored on a flat floor, so on a slope a pony stood
## with her downhill hooves in the air and her uphill ones in the hill. This runs after the
## clip (a SkeletonModifier3D, like the hair springs) and bends each leg so its hoof keeps the
## height the clip gave it over the ground actually under it; on a dip the body settles a
## little so the downhill legs can reach. The clip's own knee bend is kept: the solve folds
## each leg in the plane the clip bent it in. (After home-equestria's limb solver, analytic
## two-bone IK over the animated pose; owner 2026-11-05: "leg animations seem sick".)

## (x, z) -> ground height. Unset, the ranch's terrain (default_ground) is used.
var ground: Callable
## Set by the ranch with Pony.ground_height (Terrain.height_at).
static var default_ground: Callable

## Never reach further than this for the ground under one hoof (a ledge, a fence base): the
## clip's pose is kept past it rather than a leg pulled out of its socket.
const MAX_REACH := 0.35
## How much of the lowest hoof's drop the body follows, so a downhill leg can reach.
const BODY_FOLLOW := 0.7
## How fast each hoof's offset follows the ground, per second (no pop on a step).
const FOLLOW_RATE := 14.0

## [upper, middle, hoof] bone names, front legs then hind, per rig: the PonySFM cast's
## (SFM ReVAmped) and the Mane Six's (DEF_ names). A skeleton uses whichever it has.
const LEGS := [
	["LeftShoulder", "LeftForearm", "LeftHand"],
	["RightShoulder", "RightForearm", "RightHand"],
	["LeftLeg1", "LeftLeg2", "LeftFoot"],
	["RightLeg1", "RightLeg2", "RightFoot"],
	["DEF_FrontUpperLeg.L", "DEF_LowerFrontLeg.L", "DEF_FrontHoof.L"],
	["DEF_FrontUpperLeg.R", "DEF_LowerFrontLeg.R", "DEF_FrontHoof.R"],
	["DEF_RearUpperLeg.L", "DEF_RearLowerLeg.L", "DEF_RearHoof.L"],
	["DEF_RearUpperLeg.R", "DEF_RearLowerLeg.R", "DEF_RearHoof.R"],
]
const PELVIS := ["Pelvis", "DEF_Hip"]

var _legs: Array = []
var _pelvis := -1
var _offsets := PackedFloat32Array()
var _body_drop := 0.0
var _bound_to: Skeleton3D


## How far to move a hoof whose body stands on `floor_y` to meet ground at `ground_y`.
static func offset_for(floor_y: float, ground_y: float, reach: float) -> float:
	return clampf(ground_y - floor_y, -reach, reach)


## Two-bone IK: the knee and hoof positions that put the hoof on `target` from a hip at `r`,
## keeping both bones their length and folding in the plane the current knee `m` bends in.
static func solve(r: Vector3, m: Vector3, e: Vector3, target: Vector3) -> Array:
	var a := r.distance_to(m)
	var b := m.distance_to(e)
	var to := target - r
	var dist := to.length()
	if a < 1e-5 or b < 1e-5 or dist < 1e-5:
		return [m, e]
	var dir := to / dist
	var reach := clampf(dist, absf(a - b) + 1e-4, a + b - 1e-4)
	# The bend: the knee's side of the hip-hoof line, as the clip had it.
	var bend := (m - r) - dir * (m - r).dot(dir)
	if bend.length_squared() < 1e-10:
		bend = (m - r).cross(Vector3.RIGHT).cross(dir)
		if bend.length_squared() < 1e-10:
			bend = dir.cross(Vector3.RIGHT)
	bend = bend.normalized()
	var along := (a * a - b * b + reach * reach) / (2.0 * reach)
	var height := sqrt(maxf(0.0, a * a - along * along))
	var knee := r + dir * along + bend * height
	return [knee, r + dir * reach]


func _bind(sk: Skeleton3D) -> void:
	_bound_to = sk
	_legs.clear()
	for names: Array in LEGS:
		var ids := [sk.find_bone(names[0]), sk.find_bone(names[1]), sk.find_bone(names[2])]
		if ids.min() >= 0:
			_legs.append(ids)
	_pelvis = -1
	for n: String in PELVIS:
		if _pelvis < 0:
			_pelvis = sk.find_bone(n)
	# The body settles from the bone both pairs of legs hang from: the Mane Six's rig hangs its
	# chest beside the hip, not under it, so moving the hip alone left her front standing.
	if _pelvis >= 0 and _legs.size() == 4:
		while _pelvis >= 0 and not _is_ancestor(sk, _pelvis, int(_legs[0][0])):
			_pelvis = sk.get_bone_parent(_pelvis)
	_offsets.resize(_legs.size())
	_offsets.fill(0.0)


static func _is_ancestor(sk: Skeleton3D, ancestor: int, bone: int) -> bool:
	var b := bone
	while b >= 0:
		if b == ancestor:
			return true
		b = sk.get_bone_parent(b)
	return false


func _process_modification_with_delta(delta: float) -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if sk != _bound_to:
		_bind(sk)
	var g := ground if ground.is_valid() else default_ground
	if not g.is_valid() or _legs.is_empty():
		return
	var xf := sk.global_transform
	var floor_y := xf.origin.y
	var k := 1.0 - exp(-FOLLOW_RATE * maxf(delta, 0.0)) if delta > 0.0 else 1.0
	# The ground under each hoof, as an offset from the floor the body stands on.
	var lowest := 0.0
	for i in _legs.size():
		var hoof := xf * sk.get_bone_global_pose(_legs[i][2]).origin
		var want := offset_for(floor_y, float(g.call(hoof.x, hoof.z)), MAX_REACH)
		_offsets[i] = lerpf(_offsets[i], want, k)
		lowest = minf(lowest, _offsets[i])
	# The body settles toward the lowest hoof so a downhill leg can reach.
	_body_drop = lerpf(_body_drop, lowest * BODY_FOLLOW, k)
	var inv := xf.affine_inverse()
	if _pelvis >= 0 and absf(_body_drop) > 1e-4:
		var pp := sk.get_bone_pose_position(_pelvis)
		var parent := sk.get_bone_parent(_pelvis)
		var down := inv.basis * Vector3(0, _body_drop, 0)
		if parent >= 0:
			down = sk.get_bone_global_pose(parent).basis.inverse() * down
		sk.set_bone_pose_position(_pelvis, pp + down)
	for i in _legs.size():
		var ids: Array = _legs[i]
		_place(sk, ids, inv * _clip_hoof(sk, ids, xf, i))


## The hoof's world target: the clip's hoof, before the body settled, raised or lowered onto
## the ground under it.
func _clip_hoof(sk: Skeleton3D, ids: Array, xf: Transform3D, i: int) -> Vector3:
	var now := xf * sk.get_bone_global_pose(ids[2]).origin
	return now + Vector3(0, _offsets[i] - _body_drop, 0)


## Bend the leg `ids` so its hoof reaches `target` (skeleton space).
func _place(sk: Skeleton3D, ids: Array, target: Vector3) -> void:
	var r_pose := sk.get_bone_global_pose(ids[0])
	var m_pose := sk.get_bone_global_pose(ids[1])
	var e_pose := sk.get_bone_global_pose(ids[2])
	var out: Array = solve(r_pose.origin, m_pose.origin, e_pose.origin, target)
	_aim(sk, ids[0], r_pose, m_pose.origin, out[0])
	m_pose = sk.get_bone_global_pose(ids[1])
	_aim(sk, ids[1], m_pose, sk.get_bone_global_pose(ids[2]).origin, out[1])


## Turn `bone` (global pose `pose`) so the child it points at moves from `from` to `to`.
func _aim(sk: Skeleton3D, bone: int, pose: Transform3D, from: Vector3, to: Vector3) -> void:
	var a := from - pose.origin
	var b := to - pose.origin
	if a.length_squared() < 1e-12 or b.length_squared() < 1e-12:
		return
	var turn := Quaternion(a.normalized(), b.normalized())
	var want := Basis(turn) * pose.basis
	var parent := sk.get_bone_parent(bone)
	var parent_basis := sk.get_bone_global_pose(parent).basis if parent >= 0 else Basis()
	var local := (parent_basis.inverse() * want).orthonormalized()
	sk.set_bone_pose_rotation(bone, local.get_rotation_quaternion())
