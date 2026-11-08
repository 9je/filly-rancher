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
## three times a tick. A turn only weighs the bodies in reach; nobody else's is built.
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
	var fp := BodySpaceScript.default_footprint(me, 1.0)
	var gap := BodySpaceScript.closest_gap(me, fp)
	for n: Node3D in [me, near] + far:
		BodySpaceScript.leave(n)
	assert_lt(gap, INF, "the pony beside her is weighed")
	assert_eq(near.asked, 1, "her neighbour's footprint is built once")
	var built := 0
	for c in far:
		built += c.asked
	assert_eq(built, 0, "no footprint is built for the 59 out of reach")
