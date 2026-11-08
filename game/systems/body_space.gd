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
const STIFFNESS := 10.0
const MAX_PUSH := 2.0
## An adult pony's segment half-length and radius at body scale 1 (from the roster's bodies:
## about 1.55 m nose to tail root, 0.6 m across the barrel). The radius is wider than the
## barrel because the head is (PS1 item 17b: the Mane Six reach 0.41 to 0.44 m out at the
## eyes and ears, 0.88 m to the nose; at 0.3 two heads met before their footprints did).
const HALF := 0.5
const RADIUS := 0.36
## Closer than this (a gap between footprints, metres), a body walking toward another turns
## aside instead of walking in and being pushed out after (PS1 item 17b: a head went 0.48 m
## into another pony before the push undid it).
const CLEARANCE := 0.15
## Within this much of a weightless body (the player, a townspony at her spot), nothing is slid
## toward it.
const NEAR_FIXED := 0.6
## Bodies further apart than this in height are on different floors.
const SAME_FLOOR := 3.0

## KEEP-OUT ZONES (PS1, playtest 2026-11-05 item 10: "A pony walked through the
## conversation"): a flat capsule (segment a-b, radius r) nobody but its exempt bodies stands
## in, by key. People sets one from the player to whoever she talks to while they talk.
const TALK_RADIUS := 1.3
## Within this much of a zone's edge a walker heading in slides round it instead.
const ZONE_ASIDE := 0.8
static var _zones := {}


static func set_zone(key: StringName, a: Vector3, b: Vector3, r: float, exempt: Array) -> void:
	var ids := {}
	for n in exempt:
		if n is Object and is_instance_valid(n):
			ids[(n as Object).get_instance_id()] = true
	_zones[key] = {"a": a, "b": b, "r": r, "exempt": ids}
	_frame = -1


static func clear_zone(key: StringName) -> void:
	_zones.erase(key)
	_frame = -1


static func has_zone(key: StringName) -> bool:
	return _zones.has(key)


static var _members: Array[Node3D] = []
static var _frame := -1
static var _pushes := {}
static var _aside := {}
## Each member's neighbours within reach this tick, by instance id (_solve): a turn weighs only
## these (closest_gap), not the whole herd (PS11 G11). They are indices into the arrays below.
static var _near := {}
## This tick's bodies (_solve), side by side by index: the node, her body line's two ends, her
## radius, her height and how far she reaches from her centre (half her length and her radius).
## A turn reads these rather than her neighbours' footprints (PS11 G11's second pass).
static var _nodes: Array[Node3D] = []
static var _ats := PackedVector3Array()
static var _p0s := PackedVector3Array()
static var _p1s := PackedVector3Array()
static var _rads := PackedFloat64Array()
static var _ys := PackedFloat64Array()
static var _extents := PackedFloat64Array()
## How many pairs the solves have weighed, ever (the grid's test reads it, PS11 G11).
static var pairs_weighed := 0
## How many body lines turns have weighed, ever (a test reads it, PS11 G11).
static var lines_weighed := 0


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


## _closest()'s two points as one vector, from the second to the first, allocating nothing:
## the per-pair hot path (_solve, closest_gap) runs this thousands of times a tick.
static func _between(p0: Vector3, p1: Vector3, q0: Vector3, q1: Vector3) -> Vector3:
	var d1 := p1 - p0
	var d2 := q1 - q0
	var r := p0 - q0
	var a := d1.dot(d1)
	var e := d2.dot(d2)
	var f := d2.dot(r)
	var s := 0.0
	var t := 0.0
	if a <= 1e-9 and e <= 1e-9:
		return p0 - q0
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
	return (p0 + d1 * s) - (q0 + d2 * t)


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


## The way out from every body within CLEARANCE of `n` (unit length, or zero): a walker drops
## the part of her step that points the other way, so she slides past rather than in.
static func aside_on(n: Node3D) -> Vector3:
	push_on(n)
	return _aside.get(n.get_instance_id(), Vector3.ZERO)


## The narrowest gap between footprint `fp` (of member `n`) and every other member nearby,
## INF when nobody is in reach.
static func closest_gap(n: Node3D, fp: Dictionary) -> float:
	return _gap_within(n, fp, INF)


## closest_gap(), but a neighbour who cannot be within `limit` of her whichever way either of
## them faces (further apart than both bodies' reach and `limit`) is not weighed: the answer is
## the same whenever it is `limit` or less, and more than `limit` whenever it is more.
static func _gap_within(n: Node3D, fp: Dictionary, limit: float) -> float:
	var best := INF
	if fp.is_empty():
		return best
	var reach := (HALF + RADIUS) * 2.0 * 1.3
	var at: Vector3 = fp.at
	var h: Vector3 = (fp.heading as Vector3) * float(fp.half)
	var a0 := at - h
	var a1 := at + h
	var ry := float(fp.get("y", 0.0))
	var rr := float(fp.radius)
	var mine := float(fp.half) + rr
	# Only her neighbours from this tick's solve, and out of reach by where they stand before a
	# footprint is built: every pony asks this on every turn, and weighing the whole herd was
	# 4.5 times the physics cost at 60 ponies (PS11 G11).
	var frame := Engine.get_physics_frames()
	if frame != _frame:
		_frame = frame
		_solve()
	var near: Array = _near.get(n.get_instance_id(), [])
	for j: int in near:
		var m := _nodes[j]
		if m == n or not is_instance_valid(m):
			continue
		var p := _ats[j]
		var d2 := Vector2(p.x - at.x, p.z - at.z).length_squared()
		if d2 > reach * reach:
			continue
		if absf(ry - _ys[j]) > SAME_FLOOR:
			continue
		if limit < INF and sqrt(d2) - mine - _extents[j] > limit:
			continue
		lines_weighed += 1
		best = minf(best, _between(a0, a1, _p0s[j], _p1s[j]).length() - rr - _rads[j])
	return best


## Whether anybody is within reach of `n` this tick (_solve): a turn with nobody near has
## nothing to weigh (PS11 G11).
static func has_near(n: Node3D) -> bool:
	var frame := Engine.get_physics_frames()
	if frame != _frame:
		_frame = frame
		_solve()
	return _near.has(n.get_instance_id())


## NOT A HEAD SWUNG INTO A NEIGHBOUR (PS1 item 17b): a pony turning on the spot swept her
## head 0.3 m into the pony beside her in a tenth of a second, with neither of them walking
## (seeded trace, 2026-11-06). A turn from footprint `before` to `after` is allowed while it
## leaves her CLEARANCE from everybody, or when she is already closer and it does not close
## the gap further.
## (Weighed only within TURN_LIMIT, _gap_within: both gaps are exact up to it and above it
## past it, and either way the answer is the one the exact gaps give.)
## A held turn asks again the long way round from the same `before`: its gap is kept for that.
static func turn_allowed(n: Node3D, before: Dictionary, after: Dictionary) -> bool:
	var now := _gap_within(n, after, TURN_LIMIT)
	if now >= CLEARANCE:
		return true
	# (The same body, tick and footprint, by value: the same neighbours, so the same gap.)
	var frame := Engine.get_physics_frames()
	var id := n.get_instance_id()
	if not (_before_frame == frame and _before_id == id and before == _before_fp):
		_before_gap = _gap_within(n, before, TURN_LIMIT)
		_before_fp = before.duplicate()
		_before_frame = frame
		_before_id = id
	return now >= _before_gap - 0.001


static var _before_fp: Dictionary = {}
static var _before_frame := -1
static var _before_id := 0
static var _before_gap := INF


## How far turn_allowed() weighs: past CLEARANCE by more than its 0.001 m of slack.
const TURN_LIMIT := CLEARANCE + 0.01


## Whether a turn of `step` radians by a body of scale `body_scale` is too small to weigh: her
## body line's ends move at most HALF * scale * step, so no gap closes by more than that, and
## within turn_allowed()'s 0.001 m of slack (with a tenth of it spare) she is always allowed.
static func turn_too_small(step: float, body_scale: float) -> bool:
	return absf(step) * HALF * body_scale <= 0.0009


## Whether `n` (a body with default_footprint()'s shape) can turn any way at all without
## turn_allowed() having anybody to weigh: every neighbour from this tick's solve is out of a
## turn's reach (_gap_within's own skips, from where she stands now). Then she needs no
## footprint built to turn (PS11 G11's second pass: most turning ponies have nobody that close).
static func turn_is_free(n: Node3D) -> bool:
	var frame := Engine.get_physics_frames()
	if frame != _frame:
		_frame = frame
		_solve()
	var near: Array = _near.get(n.get_instance_id(), [])
	if near.is_empty():
		return true
	var visuals := n.get_node_or_null(^"Visuals") as Node3D
	var s := absf(visuals.scale.x) if visuals != null else 1.0
	var mine := HALF * s + RADIUS * s
	var reach := (HALF + RADIUS) * 2.0 * 1.3
	var at := n.global_position
	for j: int in near:
		var m := _nodes[j]
		if m == n or not is_instance_valid(m):
			continue
		var p := _ats[j]
		var d2 := Vector2(p.x - at.x, p.z - at.z).length_squared()
		if d2 > reach * reach or absf(at.y - _ys[j]) > SAME_FLOOR:
			continue
		if sqrt(d2) - mine - _extents[j] > TURN_LIMIT:
			continue
		return false
	return true


static func _solve() -> void:
	_before_frame = -1
	_pushes.clear()
	_aside.clear()
	_near.clear()
	var fps: Array[Dictionary] = []
	var owners := PackedInt64Array()
	var nodes: Array[Node3D] = []
	for i in range(_members.size() - 1, -1, -1):
		if not is_instance_valid(_members[i]):
			_members.remove_at(i)
	for m in _members:
		var fp := footprint_of(m)
		if not fp.is_empty():
			fps.append(fp)
			owners.append(m.get_instance_id())
			nodes.append(m)
	# Each pair once, with one closest-points solve between their body lines feeding the gap,
	# both pushes and both asides; and each body's line worked out once a tick. The same rules
	# as push_between(), gap() and _ends(), which used to be called per pair over and over:
	# that made this solve 4 ms a tick at 60 ponies, most of the physics frame (PS11 G11).
	# The footprints are read once into flat arrays, and only the pairs in neighbouring cells
	# of a grid as wide as the reach are weighed, in the same order as every pair would be
	# (PS11 G11's second pass: weighing all 5,400 pairs of the herd was 3.7 ms a tick).
	var n := fps.size()
	var ats := PackedVector3Array()
	var p0s := PackedVector3Array()
	var p1s := PackedVector3Array()
	var heads := PackedVector3Array()
	var ys := PackedFloat64Array()
	var ws := PackedFloat64Array()
	var rs := PackedFloat64Array()
	var ext := PackedFloat64Array()
	var fids := PackedInt64Array()
	var pushes := PackedVector3Array()
	var asides := PackedVector3Array()
	var fixed: Array = []
	ats.resize(n)
	p0s.resize(n)
	p1s.resize(n)
	heads.resize(n)
	ys.resize(n)
	ws.resize(n)
	rs.resize(n)
	ext.resize(n)
	fids.resize(n)
	pushes.resize(n)
	asides.resize(n)
	fixed.resize(n)
	var reach := (HALF + RADIUS) * 2.0 * 1.3 + NEAR_FIXED
	var cells := {}
	for i in n:
		var fp: Dictionary = fps[i]
		var at: Vector3 = fp.at
		var h: Vector3 = (fp.heading as Vector3) * float(fp.half)
		ats[i] = at
		p0s[i] = at - h
		p1s[i] = at + h
		heads[i] = fp.heading
		ys[i] = float(fp.get("y", 0.0))
		ws[i] = float(fp.get("weight", 1.0))
		rs[i] = float(fp.radius)
		ext[i] = float(fp.half) + rs[i]
		fids[i] = int(fp.get("id", 0))
		var key := Vector2i(floori(at.x / reach), floori(at.z / reach))
		# (A packed array is a value: appended to, it goes back in.)
		var cell: PackedInt32Array = cells.get(key, PackedInt32Array())
		cell.append(i)
		cells[key] = cell
	var reach2 := reach * reach
	# Each cell's nine-cell neighbourhood, gathered once for all who stand in it.
	var around := {}
	var weighed := 0
	var near: Array = []
	near.resize(n)
	for i in n:
		var ai := ats[i]
		var yi := ys[i]
		var wi := ws[i]
		var ri := rs[i]
		var key := Vector2i(floori(ai.x / reach), floori(ai.z / reach))
		var nine: PackedInt32Array
		if around.has(key):
			nine = around[key]
		else:
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					var c := Vector2i(key.x + dx, key.y + dz)
					if cells.has(c):
						nine.append_array(cells[c])
			# Everyone in the nine cells in the herd's order, so the pairs go as they always did.
			nine.sort()
			around[key] = nine
		for j in nine:
			if j <= i:
				continue
			weighed += 1
			var d2 := ai.distance_squared_to(ats[j])
			if d2 > reach2:
				continue
			# A floor apart (the Palace hall is under the map): not the same crowd.
			if absf(yi - ys[j]) > SAME_FLOOR:
				continue
			if near[i] == null:
				near[i] = [j]
			else:
				(near[i] as Array).append(j)
			if near[j] == null:
				near[j] = [i]
			else:
				(near[j] as Array).append(i)
			var wj := ws[j]
			if wj <= 0.0:
				if fixed[i] == null:
					fixed[i] = [] as Array[Dictionary]
				(fixed[i] as Array).append(fps[j])
			if wi <= 0.0:
				if fixed[j] == null:
					fixed[j] = [] as Array[Dictionary]
				(fixed[j] as Array).append(fps[i])
			# Further apart than both their lengths and CLEARANCE, neither is pushed nor turned
			# aside, whichever way they face: their body lines need not be weighed.
			if sqrt(d2) - ext[i] - ext[j] >= CLEARANCE:
				continue
			var between := _between(p0s[i], p1s[i], p0s[j], p1s[j])
			var g := between.length() - ri - rs[j]
			between.y = 0.0
			if g < 0.0 and wi + wj > 0.0:
				var dir := between
				if dir.length_squared() < 1e-8:
					# On the same line: apart sideways, each its own way.
					dir = heads[i].cross(Vector3.UP)
					if fids[i] > fids[j]:
						dir = -dir
				dir = dir.normalized()
				# push_between(i, j) and push_between(j, i): opposite ways, shared by weight.
				if wi > 0.0:
					pushes[i] += dir * -g * STIFFNESS * (wi / (wi + wj))
				if wj > 0.0:
					var back := -dir
					if between.length_squared() < 1e-8:
						back = heads[j].cross(Vector3.UP)
						if fids[j] > fids[i]:
							back = -back
						back = back.normalized()
					pushes[j] += back * -g * STIFFNESS * (wj / (wi + wj))
			if g < CLEARANCE and between.length_squared() > 1e-8:
				var away := between.normalized()
				asides[i] += away
				asides[j] -= away
	pairs_weighed += weighed
	for i in n:
		if near[i] != null:
			_near[owners[i]] = near[i]
	_nodes = nodes
	_ats = ats
	_p0s = p0s
	_p1s = p1s
	_rads = rs
	_ys = ys
	_extents = ext
	for i in n:
		var push: Vector3 = pushes[i]
		if push != Vector3.ZERO and fixed[i] != null:
			var f: Array[Dictionary] = []
			f.assign(fixed[i])
			push = _spare_the_fixed(fps[i], push, f)
		if push != Vector3.ZERO:
			_pushes[owners[i]] = push.limit_length(MAX_PUSH)
		if asides[i] != Vector3.ZERO:
			_aside[owners[i]] = asides[i].normalized()
	if not _zones.is_empty():
		_solve_zones()


## Every member out of every keep-out zone it is not exempt from: inside, eased out like an
## overlap; near the edge, turned aside (aside_on) so a walker slides round.
static func _solve_zones() -> void:
	for m in _members:
		if not is_instance_valid(m):
			continue
		var id := m.get_instance_id()
		var p := m.global_position
		for z: Dictionary in _zones.values():
			if (z.exempt as Dictionary).has(id):
				continue
			var a: Vector3 = z.a
			var b: Vector3 = z.b
			var ab := Vector3(b.x - a.x, 0.0, b.z - a.z)
			var t := 0.0
			if ab.length_squared() > 1e-6:
				t = clampf(Vector3(p.x - a.x, 0.0, p.z - a.z).dot(ab) / ab.length_squared(), 0.0, 1.0)
			var q := a + ab * t
			var away := Vector3(p.x - q.x, 0.0, p.z - q.z)
			var d := away.length()
			var r: float = z.r
			if d >= r + ZONE_ASIDE:
				continue
			if d < 1e-4:
				away = ab.cross(Vector3.UP) if ab.length_squared() > 1e-6 else Vector3.RIGHT
			away = away.normalized()
			# Aside leans along the zone toward its nearer end, so a walker heading straight
			# at it slides round instead of stopping dead at the edge (render, 2026-11-07).
			var along := ab.normalized() * (1.0 if t >= 0.5 else -1.0) \
				if ab.length_squared() > 1e-6 else Vector3.ZERO
			var side: Vector3 = _aside.get(id, Vector3.ZERO)
			_aside[id] = (side + away + along).normalized()
			if d < r:
				var push: Vector3 = _pushes.get(id, Vector3.ZERO)
				_pushes[id] = (push + away * (r - d) * STIFFNESS).limit_length(MAX_PUSH)


## Whether the straight walk from `from` to `to` passes through a keep-out zone (within its
## radius of the zone's segment), for a walker that would rather go somewhere else.
static func crosses_zone(from: Vector3, to: Vector3) -> bool:
	for z: Dictionary in _zones.values():
		var c := _closest(Vector3(z.a), Vector3(z.b), from, to)
		var d := Vector3(c[0] - c[1])
		d.y = 0.0
		if d.length() < float(z.r):
			return true
	return false
