class_name BodySpace
extends RefCounted
## BODIES DO NOT PASS THROUGH BODIES (PT4; playtest 2026-11-05 items 17, 19, 65). Every pony,
## the player and the townsfolk collide as a 0.42 m upright capsule, but a pony is a 1.6 m long
## body: heads and rumps went through each other, a full pen fused into one blob, and a pony
## with another inside her read as "twisted". Each body here is a footprint along its length
## (a flat capsule: a segment through the body, nose to rump, with a radius) and footprints
## that overlap ease apart, a little each physics frame, shared by how heavy each one is.
##
## A footprint is {at: Vector3 (centre, world), heading: Vector3 (along the body, flat),
## half: float (centre to the end of the segment), radius: float, weight: float, id: int}.
## Weight 0 is never moved (the player on the move: the road stays open, the townsfolk lesson
## in DECISIONS.md 2026-11-05).

## How fast an overlap is undone, per second, and the fastest a body is ever slid.
const STIFFNESS := 5.0
const MAX_PUSH := 2.0
## An adult pony's segment half-length and radius at body scale 1 (from the roster's bodies:
## about 1.55 m nose to tail root, 0.6 m across the barrel).
const HALF := 0.5
const RADIUS := 0.3
## Within this much of a weightless body (the player, a townspony at her spot), nothing is slid
## toward it.
const NEAR_FIXED := 0.6
## Bodies further apart than this in height are on different floors.
const SAME_FLOOR := 3.0

static var _members: Array[Node3D] = []
static var _frame := -1
static var _pushes := {}


static func join(n: Node3D) -> void:
	if not _members.has(n):
		_members.append(n)


static func leave(n: Node3D) -> void:
	_members.erase(n)
	_pushes.erase(n.get_instance_id())


## A body's footprint: its own body_footprint() when it has one, otherwise one built from its
## position and its Visuals child's facing and scale. Empty for a body that takes no space now.
static func footprint_of(n: Node3D) -> Dictionary:
	if n == null or not is_instance_valid(n) or not n.is_inside_tree():
		return {}
	if n.has_method("body_footprint"):
		return n.call("body_footprint")
	return default_footprint(n, 1.0)


static func default_footprint(n: Node3D, weight: float) -> Dictionary:
	if not n.is_visible_in_tree():
		return {}
	var visuals := n.get_node_or_null(^"Visuals") as Node3D
	var s := 1.0
	var heading := Vector3.FORWARD
	if visuals != null:
		s = absf(visuals.scale.x)
		heading = visuals.global_transform.basis.z
	heading.y = 0.0
	heading = heading.normalized() if heading.length_squared() > 1e-6 else Vector3.FORWARD
	var at := n.global_position
	return {"at": Vector3(at.x, 0.0, at.z), "y": at.y, "heading": heading, "half": HALF * s,
		"radius": RADIUS * s, "weight": weight, "id": n.get_instance_id()}


## The closest points of segments p0-p1 and q0-q1 (flat), as [on_p, on_q].
static func _closest(p0: Vector3, p1: Vector3, q0: Vector3, q1: Vector3) -> Array:
	var d1 := p1 - p0
	var d2 := q1 - q0
	var r := p0 - q0
	var a := d1.dot(d1)
	var e := d2.dot(d2)
	var f := d2.dot(r)
	var s := 0.0
	var t := 0.0
	if a <= 1e-9 and e <= 1e-9:
		return [p0, q0]
	if a <= 1e-9:
		t = clampf(f / e, 0.0, 1.0)
	else:
		var c := d1.dot(r)
		if e <= 1e-9:
			s = clampf(-c / a, 0.0, 1.0)
		else:
			var b := d1.dot(d2)
			var denom := a * e - b * b
			s = clampf((b * f - c * e) / denom, 0.0, 1.0) if denom > 1e-9 else 0.0
			t = (b * s + f) / e
			if t < 0.0:
				t = 0.0
				s = clampf(-c / a, 0.0, 1.0)
			elif t > 1.0:
				t = 1.0
				s = clampf((b - c) / a, 0.0, 1.0)
	return [p0 + d1 * s, q0 + d2 * t]


static func _ends(fp: Dictionary) -> Array:
	var at: Vector3 = fp.at
	var h: Vector3 = (fp.heading as Vector3) * float(fp.half)
	return [at - h, at + h]


## How far two footprints sink into each other, in metres (0 when they do not touch).
static func overlap(a: Dictionary, b: Dictionary) -> float:
	if a.is_empty() or b.is_empty():
		return 0.0
	return maxf(0.0, -gap(a, b))


## The clear space between two footprints (negative when they overlap).
static func gap(a: Dictionary, b: Dictionary) -> float:
	var ea := _ends(a)
	var eb := _ends(b)
	var c := _closest(ea[0], ea[1], eb[0], eb[1])
	return Vector3(c[0] - c[1]).length() - float(a.radius) - float(b.radius)


## `push` with any part toward a weightless body near `a` taken out: a pony squeezed out of
## another must not be slid into the player, whose collider would then shove HER aside (the
## pen_upgrade gate: she was put back inside a plot's markers as she pressed E).
static func _spare_the_fixed(a: Dictionary, push: Vector3, fixed: Array[Dictionary]) -> Vector3:
	for f in fixed:
		if gap(a, f) > NEAR_FIXED:
			continue
		var toward := Vector3(f.at) - Vector3(a.at)
		toward.y = 0.0
		if toward.length_squared() < 1e-8:
			continue
		toward = toward.normalized()
		var into := push.dot(toward)
		if into > 0.0:
			push -= toward * into
	return push


## The slide (a velocity, metres a second) `a` makes to get out of `b`: its share of the
## overlap, by weight, along the line between their closest points.
static func push_between(a: Dictionary, b: Dictionary) -> Vector3:
	var o := overlap(a, b)
	var wa := float(a.get("weight", 1.0))
	var wb := float(b.get("weight", 1.0))
	if o <= 0.0 or wa <= 0.0 or wa + wb <= 0.0:
		return Vector3.ZERO
	var ea := _ends(a)
	var eb := _ends(b)
	var c := _closest(ea[0], ea[1], eb[0], eb[1])
	var dir := Vector3(c[0] - c[1])
	dir.y = 0.0
	if dir.length_squared() < 1e-8:
		# On the same line: apart sideways, each its own way.
		dir = Vector3(a.heading).cross(Vector3.UP)
		if int(a.get("id", 0)) > int(b.get("id", 0)):
			dir = -dir
	return dir.normalized() * o * STIFFNESS * (wa / (wa + wb))


## The slide `n` makes this physics frame (every member's is worked out once a frame).
static func push_on(n: Node3D) -> Vector3:
	var frame := Engine.get_physics_frames()
	if frame != _frame:
		_frame = frame
		_solve()
	return _pushes.get(n.get_instance_id(), Vector3.ZERO)


static func _solve() -> void:
	_pushes.clear()
	var fps: Array[Dictionary] = []
	var owners: Array[int] = []
	for i in range(_members.size() - 1, -1, -1):
		if not is_instance_valid(_members[i]):
			_members.remove_at(i)
	for m in _members:
		var fp := footprint_of(m)
		if not fp.is_empty():
			fps.append(fp)
			owners.append(m.get_instance_id())
	var reach := (HALF + RADIUS) * 2.0 * 1.3 + NEAR_FIXED
	for i in fps.size():
		var push := Vector3.ZERO
		var ai: Vector3 = fps[i].at
		var fixed: Array[Dictionary] = []
		for j in fps.size():
			if i == j:
				continue
			if ai.distance_squared_to(fps[j].at) > reach * reach:
				continue
			# A floor apart (the Palace hall is under the map): not the same crowd.
			if absf(float(fps[i].get("y", 0.0)) - float(fps[j].get("y", 0.0))) > SAME_FLOOR:
				continue
			push += push_between(fps[i], fps[j])
			if float(fps[j].get("weight", 1.0)) <= 0.0:
				fixed.append(fps[j])
		if push != Vector3.ZERO and not fixed.is_empty():
			push = _spare_the_fixed(fps[i], push, fixed)
		if push != Vector3.ZERO:
			_pushes[owners[i]] = push.limit_length(MAX_PUSH)
