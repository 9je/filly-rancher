extends GutTest
## THE GUIDE (game/systems/guide.gd): the one place the game wants her to go next, and the
## trail of motes that leads there (game/world/guide_trail.gd). Owner playtest 2026-10-25:
## "idk what to do anymore", "cant find the market", "build area hard to find".

const GuideScript := preload("res://systems/guide.gd")
const TrailScript := preload("res://world/guide_trail.gd")


func _state(over: Dictionary = {}) -> Dictionary:
	var s := {
		"has_scoop": true, "mail": false, "news": false, "bag": 0, "bag_full": false,
		"pen_room": 0, "gems": 0, "tasks": [] as Array,
	}
	s.merge(over, true)
	return s


func _task(id: String, done := false) -> Dictionary:
	return {"id": id, "done": done, "paid": false}


func test_nothing_to_do_points_nowhere() -> void:
	assert_eq(GuideScript.pick(_state()), &"")


func test_before_the_scoop_only_somebody_with_news_is_pointed_at() -> void:
	assert_eq(GuideScript.pick(_state({"has_scoop": false})), &"")
	assert_eq(GuideScript.pick(_state({"has_scoop": false, "news": true})), &"talk")
	assert_eq(GuideScript.pick(_state({"has_scoop": false, "mail": true,
		"tasks": [_task("tutorial_catch")]})), &"", "no chores before she can do them")


func test_the_first_task_points_at_a_wild_pony() -> void:
	assert_eq(GuideScript.pick(_state({"tasks": [_task("tutorial_catch"), _task("tutorial_pen"),
		_task("tutorial_sell")]})), &"catch")


func test_a_pony_in_the_bag_and_room_in_a_pen_points_at_the_pens_while_she_is_learning() -> void:
	var tasks := [_task("tutorial_catch", true), _task("tutorial_pen")]
	assert_eq(GuideScript.pick(_state({"bag": 1, "pen_room": 3, "tasks": tasks})), &"pens")
	assert_eq(GuideScript.pick(_state({"bag": 1, "pen_room": 3})), &"",
		"after the lessons one pony in the bag is her business")


func test_a_full_bag_always_points_at_the_pens() -> void:
	assert_eq(GuideScript.pick(_state({"bag": 12, "bag_full": true, "news": true})), &"pens")


func test_mail_beats_news_and_news_beats_lessons() -> void:
	var tasks := [_task("tutorial_catch")]
	assert_eq(GuideScript.pick(_state({"mail": true, "news": true, "tasks": tasks})), &"mail")
	assert_eq(GuideScript.pick(_state({"news": true, "tasks": tasks})), &"talk")


func test_gems_and_the_sell_lesson_point_at_the_market() -> void:
	var tasks := [_task("tutorial_catch", true), _task("tutorial_pen", true), _task("tutorial_sell")]
	assert_eq(GuideScript.pick(_state({"tasks": tasks})), &"catch",
		"no gems yet: more ponies make gems")
	assert_eq(GuideScript.pick(_state({"gems": 2, "tasks": tasks})), &"market")


func test_the_trail_lies_between_her_and_the_goal() -> void:
	var trail: GuideTrail = TrailScript.new()
	add_child_autofree(trail)
	trail.point(Vector3.ZERO, Vector3(30, 0, 0))
	var motes := trail.mote_positions()
	assert_gt(motes.size(), 4)
	for m: Vector3 in motes:
		assert_between(m.x, 0.5, 30.0)
		assert_almost_eq(m.z, 0.0, 0.6)


func test_the_trail_ends_short_of_a_goal_close_by_and_goes_when_she_arrives() -> void:
	var trail: GuideTrail = TrailScript.new()
	add_child_autofree(trail)
	trail.point(Vector3.ZERO, Vector3(5, 0, 0))
	for m: Vector3 in trail.mote_positions():
		assert_lt(m.x, 5.0)
	trail.point(Vector3.ZERO, Vector3(1.5, 0, 0))
	assert_eq(trail.mote_positions().size(), 0, "she is there")
	trail.point(Vector3.ZERO, Vector3.INF)
	assert_eq(trail.mote_positions().size(), 0, "no goal, no trail")


func test_the_trail_follows_the_ground() -> void:
	var trail: GuideTrail = TrailScript.new()
	trail.height_at = func(x: float, _z: float) -> float: return x * 0.1
	add_child_autofree(trail)
	trail.point(Vector3.ZERO, Vector3(20, 0, 0))
	for m: Vector3 in trail.mote_positions():
		assert_almost_eq(m.y - m.x * 0.1, TrailScript.HOVER, 0.35)
