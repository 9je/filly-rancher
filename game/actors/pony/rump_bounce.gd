class_name RumpBounce
extends Node
## THE SLAPSTICK BOUNCE (the owner's call, DECISIONS.md 2026-11-05: "i see a bouncing butt as
## funny not sexual"). Her hindquarters sit on a damped spring; kick() gives it a shove when
## something slapstick happens to her (a hard landing from a jump, a flop out of the Scoop into
## a pen) and it wobbles a few times and settles. The wobble itself is drawn by the toon and
## outline shaders (shaders/bounce.gdshaderinc) round centre() within radius().
##
## PonyVisuals.build() gives every body one, as a child named RumpBounce of the body root.

## Wobbles a second, and how quickly they die away (a damping ratio).
const HZ := 5.0
const DAMPING := 0.09
## The most the spring ever moves her, in metres.
const MAX_AMOUNT := 0.15
## Her mane and tail are thrown with the spring: an external force on her hair springs of this
## much per metre a second of the spring's speed (owner: "make tail and hair bounce a little
## more obvious"). Gravity on the hair is 0.22 to 0.28, so a good flop throws it several times
## that, down, then up, then down, dying away with the rump.
const HAIR_THROW := 0.25

## A kick of 1.0 is a velocity of this many metres a second.
const KICK_SPEED := 5.0

var _x := 0.0
var _v := 0.0
var _centre := Vector3.ZERO
var _radius := 0.0
var _back := Vector3.BACK
var _meshes: Array[MeshInstance3D] = []
var _skeleton: Skeleton3D
var _hair: Array[SpringBoneSimulator3D] = []
var _written := false


## Kick the bounce of whatever body is under `node` (a pony's Visuals, the player); a no op
## when there is none.
static func kick_on(node: Node, strength: float) -> void:
	if node == null:
		return
	var found := node.find_children("RumpBounce", "", true, false)
	if not found.is_empty() and found[0].has_method("kick"):
		found[0].call("kick", strength)


## Shove the spring: 1.0 a good flop, 0.3 a little hop. Down first, the way weight lands.
func kick(strength: float) -> void:
	_v -= clampf(strength, 0.0, 2.0) * KICK_SPEED


func amount() -> float:
	return _x


func centre() -> Vector3:
	return _centre


func radius() -> float:
	return _radius


## Measure her hindquarters off `body`'s rest pose and find the meshes the bounce draws on.
func bind(body: Node3D) -> void:
	_meshes.clear()
	for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		_meshes.append(mi)
	_hair.clear()
	for sim: SpringBoneSimulator3D in body.find_children("*", "SpringBoneSimulator3D", true, false):
		_hair.append(sim)
	var sks := body.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return
	var sk: Skeleton3D = sks[0]
	_skeleton = sk
	# Anchored on her thighs and sized thigh to shoulder: both rigs put those in the same places
	# (the Mane Six's hip bone sits well forward of their rump, and sizing off it gave them a
	# jiggle a third the size; owner: "it looks like only derpy does it").
	var thighs := _mid(sk, ["LeftThigh", "RightThigh"], ["DEF_Thigh.L", "DEF_Thigh.R"])
	var shoulders := _mid(sk, ["LeftShoulder", "RightShoulder"], ["DEF_Shoulder.L", "DEF_Shoulder.R"])
	if thighs == Vector3.INF or shoulders == Vector3.INF:
		return
	var back := thighs - shoulders
	var length := back.length()
	if length < 1e-4:
		return
	# Level: her shoulders sit lower than her thighs, and the rump is straight behind.
	back = Vector3(back.x, 0.0, back.z).normalized()
	_centre = thighs + back * length * 0.37 + Vector3.UP * length * 0.017
	_radius = length * 0.62
	_back = back


## The middle of a pair of bones, by either rig's names; INF when the skeleton has neither.
static func _mid(sk: Skeleton3D, names: Array, alt: Array) -> Vector3:
	for pair: Array in [names, alt]:
		var a := sk.find_bone(pair[0])
		var b := sk.find_bone(pair[1])
		if a >= 0 and b >= 0:
			return (sk.get_bone_global_rest(a).origin + sk.get_bone_global_rest(b).origin) * 0.5
	return Vector3.INF


func _process(delta: float) -> void:
	step(delta)


## Advance the spring `delta` seconds and hand the shaders where it is.
func step(delta: float) -> void:
	if delta <= 0.0:
		return
	var w := TAU * HZ
	# Semi-implicit Euler in small steps: steady at any frame rate.
	var left := delta
	while left > 0.0:
		var h := minf(left, 1.0 / 120.0)
		_v += (-w * w * _x - 2.0 * DAMPING * w * _v) * h
		_x = clampf(_x + _v * h, -MAX_AMOUNT, MAX_AMOUNT)
		left -= h
	if absf(_x) < 1e-4 and absf(_v) < 1e-3:
		_x = 0.0
		_v = 0.0
	_push()


## Hand the shaders where the spring is (only while it moves, and once more as it stops).
func _push() -> void:
	var moving := _x != 0.0
	if moving or _written:
		var force := Vector3(0.0, _v * HAIR_THROW, 0.0) if moving else Vector3.ZERO
		for sim in _hair:
			if is_instance_valid(sim):
				sim.set_external_force(force)
	if not moving and not _written:
		return
	for mi: MeshInstance3D in _meshes:
		if is_instance_valid(mi):
			if not _written:
				# The centre in this mesh's own space (the shader's VERTEX).
				var at := _centre
				if _skeleton != null and mi.is_inside_tree() and _skeleton.is_inside_tree():
					at = mi.global_transform.affine_inverse() * (_skeleton.global_transform * _centre)
				var back := _back
				if _skeleton != null and mi.is_inside_tree() and _skeleton.is_inside_tree():
					back = (mi.global_transform.basis.inverse() * (_skeleton.global_transform.basis * _back)).normalized()
				mi.set_instance_shader_parameter(&"bounce_at", Vector4(at.x, at.y, at.z, _radius))
				mi.set_instance_shader_parameter(&"bounce_back", back)
			mi.set_instance_shader_parameter(&"bounce_amount", _x)
	_written = moving
