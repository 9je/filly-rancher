extends GutTest
## Item 76 (playtest 2026-11-10): the tail's run carriage (actors/pony/tail_carry.gd). The
## look is judged from frames (Lane B round 3, lb5/tail3); these pin the shape of the rule.

const TailCarryScript := preload("res://actors/pony/tail_carry.gd")


func test_standing_still_turns_nothing() -> void:
	for depth in 4:
		var q: Quaternion = TailCarryScript.turn_for(depth, 0.0, 0.3, Vector3.RIGHT, Vector3.UP)
		assert_almost_eq(q.get_angle(), 0.0, 0.0001, "no carry, no turn at depth %d" % depth)


func test_at_a_run_the_tail_rises_behind_her() -> void:
	# Forward +Z, side = up x forward = +X: a tail pointing back (-Z) must come UP.
	var side := Vector3.UP.cross(Vector3.BACK).normalized()
	var lifted := 0.0
	for k in 8:
		var q: Quaternion = TailCarryScript.turn_for(2, 1.0, k / 8.0, side, Vector3.UP)
		lifted += (q * Vector3.FORWARD).y
	assert_gt(lifted / 8.0, 0.1, "over a stride the tail rides higher than it hangs")


func test_the_tail_moves_through_the_stride() -> void:
	var a: Quaternion = TailCarryScript.turn_for(1, 1.0, 0.0, Vector3.RIGHT, Vector3.UP)
	var b: Quaternion = TailCarryScript.turn_for(1, 1.0, 0.5, Vector3.RIGHT, Vector3.UP)
	assert_gt(a.angle_to(b), deg_to_rad(5.0), "half a stride apart, the tail is somewhere else")


func test_the_player_body_gets_a_carriage_ahead_of_its_springs() -> void:
	assert_true(ResourceLoader.exists("res://assets/converted/ponies/applejack.glb"))
	var pony: Node3D = PonyRig.spawn("applejack")
	add_child_autofree(pony)
	var tc := TailCarryScript.attach(pony)
	assert_not_null(tc, "Applejack has tail bones")
	var sk := tc.get_parent()
	var spring := sk.get_node_or_null(^"HairSpring")
	assert_not_null(spring)
	assert_lt(tc.get_index(), spring.get_index(), "the carriage runs before the springs")
	assert_eq(TailCarryScript.attach(pony), tc, "attaching twice is a no-op")
