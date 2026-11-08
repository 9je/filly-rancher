extends GutTest
## BODIES DO NOT PASS THROUGH BODIES (PT4; playtest 2026-11-05 items 17, 19, 65). A pony's
## collider is a 0.42 m upright capsule under a 1.6 m long body, so heads and rumps went
## through each other: a full pen fused into one blob and a Twilight read as "twisted" with
## another pony inside her. Every body now has a footprint along its length and overlapping
## footprints ease apart (systems/body_space.gd).

const BodySpaceScript := preload("res://systems/body_space.gd")
const PonyScene := preload("res://actors/pony/pony.tscn")
const LayersScript := preload("res://world/collision_layers.gd")


func _fp(at: Vector3, heading: Vector3, half := 0.55, r := 0.3, weight := 1.0) -> Dictionary:
	return {"at": at, "heading": heading, "half": half, "radius": r, "weight": weight}


func test_side_by_side_bodies_are_pushed_apart_sideways() -> void:
	var a := _fp(Vector3(0, 0, 0), Vector3.FORWARD)
	var b := _fp(Vector3(0.3, 0, 0), Vector3.FORWARD)
	var push: Vector3 = BodySpaceScript.push_between(a, b)
	assert_lt(push.x, 0.0, "a goes left, away from b")
	assert_almost_eq(push.z, 0.0, 0.001, "not along their length")


func test_nose_inside_a_rump_is_overlap_though_the_centres_are_far() -> void:
	# 1.0 m apart along their length: two upright capsules would not touch, the bodies do.
	var a := _fp(Vector3(0, 0, 0), Vector3.FORWARD)
	var b := _fp(Vector3(0, 0, -1.0), Vector3.FORWARD)
	assert_gt(BodySpaceScript.overlap(a, b), 0.0)
	assert_gt(BodySpaceScript.push_between(a, b).length(), 0.0)


func test_bodies_clear_of_each_other_are_left_alone() -> void:
	var a := _fp(Vector3(0, 0, 0), Vector3.FORWARD)
	var b := _fp(Vector3(1.0, 0, 0), Vector3.FORWARD)
	assert_eq(BodySpaceScript.overlap(a, b), 0.0)
	assert_eq(BodySpaceScript.push_between(a, b), Vector3.ZERO)


func test_two_bodies_on_the_same_spot_still_part() -> void:
	var a := _fp(Vector3(2, 0, 2), Vector3.FORWARD)
	var b := _fp(Vector3(2, 0, 2), Vector3.FORWARD)
	assert_gt(BodySpaceScript.push_between(a, b).length(), 0.0)
	assert_gt(BodySpaceScript.push_between(b, a).length(), 0.0)


func test_a_weightless_body_is_never_moved() -> void:
	# The player walking: she is never shoved (the townsfolk lesson, FS3.3: a road stays open).
	var me := _fp(Vector3.ZERO, Vector3.FORWARD, 0.55, 0.3, 0.0)
	var other := _fp(Vector3(0.2, 0, 0), Vector3.FORWARD)
	assert_eq(BodySpaceScript.push_between(me, other), Vector3.ZERO)


func test_a_pony_inside_the_player_takes_the_whole_step_out() -> void:
	var pony := _fp(Vector3(0.2, 0, 0), Vector3.FORWARD)
	var player := _fp(Vector3.ZERO, Vector3.FORWARD, 0.55, 0.3, 0.0)
	var o := BodySpaceScript.overlap(pony, player)
	assert_almost_eq(BodySpaceScript.push_between(pony, player).length(), o * BodySpaceScript.STIFFNESS, 0.001)


func test_nothing_is_squeezed_into_the_player() -> void:
	# A pony pressed between another pony and the player gives way along the player, never
	# into her: the player's collider would shove HER aside (test_pen_upgrade, PT4).
	var me := _fp(Vector3(0, 0, 0), Vector3.FORWARD)
	var pony := _fp(Vector3(-0.35, 0, 0), Vector3.FORWARD)
	var player := _fp(Vector3(0.75, 0, 0), Vector3.FORWARD, 0.55, 0.3, 0.0)
	var raw: Vector3 = BodySpaceScript.push_between(me, pony)
	assert_gt(raw.x, 0.0, "the pony alone would slide her toward the player")
	var spared: Vector3 = BodySpaceScript._spare_the_fixed(me, raw, [player] as Array[Dictionary])
	assert_lte(spared.x, 0.0001, "with the player there she is not slid into her")


func test_a_full_pen_spreads_out() -> void:
	# Eight real ponies set down on top of each other in a ring of 0.5 m, as a pen seats them.
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	shape.shape = box
	shape.position.y = -0.5
	floor_body.add_child(shape)
	add_child_autofree(floor_body)
	var ponies: Array[Node3D] = []
	var ids := [&"twilight", &"fluttershy", &"rarity", &"applejack", &"rainbowdash", &"pinkiepie",
		&"derpyhooves", &"applebloom"]
	for i in ids.size():
		var p: CharacterBody3D = PonyScene.instantiate()
		p.collision_layer = LayersScript.PONY
		p.collision_mask = LayersScript.PONY_WALKABLE
		p.roam_radius = 2.0
		p.position = Vector3(cos(i * 2.4) * 0.5 * sqrt(i), 0.05, sin(i * 2.4) * 0.5 * sqrt(i))
		p.call("setup", load("res://data/ponies/%s.tres" % ids[i]))
		add_child_autofree(p)
		ponies.append(p)
	for f in 360:
		await get_tree().physics_frame
	var worst := 0.0
	for i in ponies.size():
		for j in range(i + 1, ponies.size()):
			worst = maxf(worst, BodySpaceScript.overlap(BodySpaceScript.footprint_of(ponies[i]),
				BodySpaceScript.footprint_of(ponies[j])))
	assert_lt(worst, 0.12, "after 6 s no two ponies overlap by more than a hand's width")


## PS11 G11 (the 60-pony check, 4.5 times the physics cost of the commit before the sweep):
## every pony's turn asked for the footprint of every member of the herd, near or far, up to
## three times a tick. A turn only weighs the bodies in reach, by the footprints the tick's
## solve already built; it builds none of its own.
class Counted:
	extends Node3D
	var asked := 0
	func body_footprint() -> Dictionary:
		asked += 1
		return BodySpace.default_footprint(self, 1.0)


func test_a_turn_only_weighs_the_bodies_in_reach() -> void:
	var near := Counted.new()
	add_child_autofree(near)
	near.global_position = Vector3(1.2, 0.0, 0.0)
	var far: Array[Counted] = []
	for i in 59:
		var c := Counted.new()
		add_child_autofree(c)
		c.global_position = Vector3(10.0 + 3.0 * i, 0.0, 0.0)
		far.append(c)
	var me := Counted.new()
	add_child_autofree(me)
	for n: Node3D in [me, near] + far:
		BodySpaceScript.join(n)
	# The tick's own solve builds everyone's once; the turn must build no more.
	BodySpaceScript.push_on(me)
	near.asked = 0
	for c in far:
		c.asked = 0
	var fp := BodySpaceScript.default_footprint(me, 1.0)
	var gap := BodySpaceScript.closest_gap(me, fp)
	for n: Node3D in [me, near] + far:
		BodySpaceScript.leave(n)
	assert_lt(gap, INF, "the pony beside her is weighed")
	assert_eq(near.asked, 0, "her neighbour is weighed by the footprint this tick's solve built")
	var built := 0
	for c in far:
		built += c.asked
	assert_eq(built, 0, "no footprint is built for the 59 out of reach")


## PS11 G11, the second pass (2026-11-08): the solve still weighed every pair of the herd's 104
## bodies, about 5,400 a tick at 3.7 ms, most of the 60-pony check's physics tick. It now
## weighs only the pairs in neighbouring cells of a grid as wide as its reach, and gives the very
## same pushes, asides and neighbours as the pair rules (push_between, gap, _spare_the_fixed).
class Placed:
	extends Node3D
	var fp_weight := 1.0
	func body_footprint() -> Dictionary:
		return BodySpace.default_footprint(self, fp_weight)


func _herd(count: int, spread: float, seed_value: int) -> Array[Placed]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: Array[Placed] = []
	for i in count:
		var p := Placed.new()
		var v := Node3D.new()
		v.name = "Visuals"
		p.add_child(v)
		add_child_autofree(p)
		p.global_position = Vector3(rng.randf_range(-spread, spread), rng.randf_range(0.0, 0.2),
			rng.randf_range(-spread, spread))
		v.rotation.y = rng.randf_range(-PI, PI)
		v.scale = Vector3.ONE * rng.randf_range(0.7, 1.1)
		# A few weightless bodies (the player, a townspony at her spot) among them.
		p.fp_weight = 0.0 if i % 9 == 4 else 1.0
		out.append(p)
	return out


func test_the_solve_weighs_only_the_pairs_in_reach() -> void:
	var herd := _herd(100, 40.0, 7)
	for n in herd:
		BodySpaceScript.join(n)
	BodySpaceScript._frame = -1
	BodySpaceScript.pairs_weighed = 0
	BodySpaceScript.push_on(herd[0])
	var weighed: int = BodySpaceScript.pairs_weighed
	for n in herd:
		BodySpaceScript.leave(n)
	assert_lt(weighed, 100 * 99 / 2 / 4, "a spread herd is not weighed pair by pair (%d)" % weighed)


func test_the_solve_gives_what_the_pair_rules_give() -> void:
	for trial in 3:
		# Crowded (a full pen), loose and spread: every case of the grid's cells.
		var herd := _herd(70, [2.5, 6.0, 30.0][trial], 11 + trial)
		for n in herd:
			BodySpaceScript.join(n)
		BodySpaceScript._frame = -1
		BodySpaceScript.push_on(herd[0])
		var reach := (BodySpaceScript.HALF + BodySpaceScript.RADIUS) * 2.0 * 1.3 + BodySpaceScript.NEAR_FIXED
		var fps: Array[Dictionary] = []
		for n in herd:
			fps.append(BodySpaceScript.footprint_of(n))
		var bad := 0
		for i in herd.size():
			var push := Vector3.ZERO
			var side := Vector3.ZERO
			var fixed: Array[Dictionary] = []
			var near := 0
			for j in herd.size():
				if j == i:
					continue
				if Vector3(fps[i].at).distance_squared_to(fps[j].at) > reach * reach \
						or absf(float(fps[i].y) - float(fps[j].y)) > BodySpaceScript.SAME_FLOOR:
					continue
				near += 1
				if float(fps[j].weight) <= 0.0:
					fixed.append(fps[j])
				push += BodySpaceScript.push_between(fps[i], fps[j])
				var g := BodySpaceScript.gap(fps[i], fps[j])
				var ea := BodySpaceScript._ends(fps[i])
				var eb := BodySpaceScript._ends(fps[j])
				var c := BodySpaceScript._closest(ea[0], ea[1], eb[0], eb[1])
				var between := Vector3(c[0] - c[1])
				between.y = 0.0
				if g < BodySpaceScript.CLEARANCE and between.length_squared() > 1e-8:
					side += between.normalized()
			if push != Vector3.ZERO and not fixed.is_empty():
				push = BodySpaceScript._spare_the_fixed(fps[i], push, fixed)
			push = push.limit_length(BodySpaceScript.MAX_PUSH)
			side = side.normalized() if side != Vector3.ZERO else Vector3.ZERO
			var got_push: Vector3 = BodySpaceScript.push_on(herd[i])
			var got_side: Vector3 = BodySpaceScript.aside_on(herd[i])
			var got_near: int = (BodySpaceScript._near.get(herd[i].get_instance_id(), []) as Array).size()
			if not got_push.is_equal_approx(push) or not got_side.is_equal_approx(side) or got_near != near:
				bad += 1
		for n in herd:
			BodySpaceScript.leave(n)
		assert_eq(bad, 0, "trial %d: every body's push, aside and neighbours as the pair rules have them" % trial)


## A turn weighs a neighbour's body line only when the two could come within CLEARANCE of each
## other: further apart than both bodies' lengths and CLEARANCE, no turn can bring them that
## close (PS11 G11's second pass: 13 ponies turning a tick spent 1.3 ms weighing them).
func test_a_turn_clear_of_everybody_weighs_no_body_line() -> void:
	var herd: Array[Placed] = []
	for i in 7:
		var p := Placed.new()
		var v := Node3D.new()
		v.name = "Visuals"
		p.add_child(v)
		add_child_autofree(p)
		# Her in the middle, six round her 2 m off: in reach of the solve, out of reach of a turn.
		p.global_position = Vector3.ZERO if i == 0 else Vector3(cos(i) * 2.0, 0.0, sin(i) * 2.0)
		herd.append(p)
	for n in herd:
		BodySpaceScript.join(n)
	BodySpaceScript._frame = -1
	var before := BodySpaceScript.footprint_of(herd[0])
	(herd[0].get_node("Visuals") as Node3D).rotation.y = 0.3
	var after := BodySpaceScript.footprint_of(herd[0])
	assert_true(BodySpaceScript.has_near(herd[0]), "her neighbours are in the solve's reach")
	BodySpaceScript.lines_weighed = 0
	var ok := BodySpaceScript.turn_allowed(herd[0], before, after)
	var weighed: int = BodySpaceScript.lines_weighed
	for n in herd:
		BodySpaceScript.leave(n)
	assert_true(ok, "nobody is near enough to stop her turning")
	assert_eq(weighed, 0, "and nobody's body line was weighed to find that out")


func test_a_turn_is_allowed_as_the_pair_rules_allow_it() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var checked := 0
	var held := 0
	var bad := 0
	for trial in 4:
		var herd := _herd(40, [1.5, 2.5, 4.0, 8.0][trial], 31 + trial)
		for n in herd:
			BodySpaceScript.join(n)
		BodySpaceScript._frame = -1
		BodySpaceScript.push_on(herd[0])
		var reach := (BodySpaceScript.HALF + BodySpaceScript.RADIUS) * 2.0 * 1.3
		for i in herd.size():
			var v := herd[i].get_node("Visuals") as Node3D
			var before := BodySpaceScript.footprint_of(herd[i])
			var keep := v.rotation.y
			v.rotation.y += rng.randf_range(-0.6, 0.6)
			var after := BodySpaceScript.footprint_of(herd[i])
			v.rotation.y = keep
			var gaps := []
			for fp in [after, before]:
				var best := INF
				for j in herd.size():
					if j == i:
						continue
					var other := BodySpaceScript.footprint_of(herd[j])
					var d := Vector3(other.at) - Vector3(fp.at)
					if Vector2(d.x, d.z).length_squared() > reach * reach \
							or absf(float(fp.y) - float(other.y)) > BodySpaceScript.SAME_FLOOR:
						continue
					best = minf(best, BodySpaceScript.gap(fp, other))
				gaps.append(best)
			var want: bool = gaps[0] >= BodySpaceScript.CLEARANCE or gaps[0] >= gaps[1] - 0.001
			if not want:
				held += 1
			checked += 1
			if BodySpaceScript.turn_allowed(herd[i], before, after) != want:
				bad += 1
		for n in herd:
			BodySpaceScript.leave(n)
	assert_gt(held, 5, "some of the turns are held (the crowded herds)")
	assert_eq(bad, 0, "every one of %d turns is allowed or held as the pair rules have it" % checked)


## A pony whose neighbours all stand too far off for any turn to bring her within CLEARANCE of
## them turns without building a footprint at all (turn_is_free); every such turn is one
## turn_allowed() would allow, whichever way she turns (PS11 G11's second pass).
func test_a_free_turn_is_one_the_rules_would_allow() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var free := 0
	var bound := 0
	var wrong := 0
	for trial in 4:
		var herd := _herd(40, [1.5, 3.0, 5.0, 9.0][trial], 51 + trial)
		for n in herd:
			BodySpaceScript.join(n)
		BodySpaceScript._frame = -1
		BodySpaceScript.push_on(herd[0])
		for i in herd.size():
			if not BodySpaceScript.has_near(herd[i]):
				continue
			if not BodySpaceScript.turn_is_free(herd[i]):
				bound += 1
				continue
			free += 1
			var v := herd[i].get_node("Visuals") as Node3D
			var keep := v.rotation.y
			for k in 6:
				var before := BodySpaceScript.footprint_of(herd[i])
				v.rotation.y = rng.randf_range(-PI, PI)
				if not BodySpaceScript.turn_allowed(herd[i], before, BodySpaceScript.footprint_of(herd[i])):
					wrong += 1
			v.rotation.y = keep
		for n in herd:
			BodySpaceScript.leave(n)
	assert_gt(free, 10, "some ponies with neighbours turn free")
	assert_gt(bound, 10, "and some, in the crowds, do not")
	assert_eq(wrong, 0, "no free turn is one the rules would hold")


## The last of a turn, a step too small to move her nose a millimetre, can never close a gap by
## more than turn_allowed()'s own millimetre of slack: it is let through unweighed (PS11 G11).
func test_a_turn_too_small_to_weigh_is_always_allowed() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 61
	var small := 0
	var wrong := 0
	for trial in 3:
		var herd := _herd(40, [1.2, 2.0, 3.0][trial], 71 + trial)
		for n in herd:
			BodySpaceScript.join(n)
		BodySpaceScript._frame = -1
		BodySpaceScript.push_on(herd[0])
		for i in herd.size():
			var v := herd[i].get_node("Visuals") as Node3D
			var keep := v.rotation.y
			for k in 8:
				var step := rng.randf_range(-0.004, 0.004)
				if not BodySpaceScript.turn_too_small(step, absf(v.scale.x)):
					continue
				small += 1
				var before := BodySpaceScript.footprint_of(herd[i])
				v.rotation.y = keep + step
				if not BodySpaceScript.turn_allowed(herd[i], before, BodySpaceScript.footprint_of(herd[i])):
					wrong += 1
				v.rotation.y = keep
		for n in herd:
			BodySpaceScript.leave(n)
	assert_gt(small, 100, "plenty of small steps were tried")
	assert_eq(wrong, 0, "none of them is one the rules would hold")
	assert_false(BodySpaceScript.turn_too_small(0.01, 1.0), "a real turn is weighed")


func test_a_pony_two_metres_from_everybody_turns_free() -> void:
	var herd: Array[Placed] = []
	for i in 7:
		var p := Placed.new()
		var v := Node3D.new()
		v.name = "Visuals"
		p.add_child(v)
		add_child_autofree(p)
		p.global_position = Vector3.ZERO if i == 0 else Vector3(cos(i) * 2.0, 0.0, sin(i) * 2.0)
		herd.append(p)
	for n in herd:
		BodySpaceScript.join(n)
	BodySpaceScript._frame = -1
	var free := BodySpaceScript.turn_is_free(herd[0])
	herd[1].global_position = Vector3(1.2, 0.0, 0.0)
	BodySpaceScript._frame = -1
	var crowded := BodySpaceScript.turn_is_free(herd[0])
	for n in herd:
		BodySpaceScript.leave(n)
	assert_true(free, "nobody within a turn's reach")
	assert_false(crowded, "a neighbour 1.2 m off could be swung into")
