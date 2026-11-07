extends GutTest
## NOPONY WALKS THROUGH A CONVERSATION (PS1, playtest 2026-11-05 item 10: "A pony walked
## through the conversation"). While the player talks to somepony, the ground between them
## (and a little round it) is kept clear: a body inside it is eased out, and one walking at it
## slides round it. The two talking are not moved by it.

const BodySpaceScript := preload("res://systems/body_space.gd")

const A := Vector3(0.0, 0.0, 0.0)
const B := Vector3(3.0, 0.0, 0.0)


class Walker:
	extends Node3D


func after_each() -> void:
	BodySpaceScript.clear_zone(&"talk")


func _seg_dist(p: Vector3) -> float:
	var t := clampf((p - A).dot(B - A) / (B - A).length_squared(), 0.0, 1.0)
	var q := A + (B - A) * t
	return Vector2(p.x - q.x, p.z - q.z).length()


## A body walking from `from` across the talk at 1.4 m/s, steering the way a pony does with
## push_on and aside_on (pony.gd: the step into a body she touches is dropped, then the push).
func _cross(from: Vector3, to: Vector3, zone: bool) -> float:
	var w := Walker.new()
	add_child_autofree(w)
	w.global_position = from
	BodySpaceScript.join(w)
	if zone:
		BodySpaceScript.set_zone(&"talk", A, B, BodySpaceScript.TALK_RADIUS, [])
	var worst := INF
	for i in 1200:
		var desired := (to - w.global_position)
		desired.y = 0.0
		if desired.length() < 0.2:
			break
		desired = desired.normalized() * 1.4
		BodySpaceScript._frame = -1
		var touching := BodySpaceScript.push_on(w) + BodySpaceScript.aside_on(w)
		if touching != Vector3.ZERO:
			var out_of := touching.normalized()
			var into := desired.dot(-out_of)
			if into > 0.0:
				desired += out_of * into
		w.global_position += (desired + BodySpaceScript.push_on(w)) / 60.0
		worst = minf(worst, _seg_dist(w.global_position))
	BodySpaceScript.leave(w)
	_arrived = w.global_position.distance_to(to) < 0.4
	return worst


var _arrived := false


func test_a_pony_crossing_a_conversation_goes_round_it() -> void:
	var worst := _cross(Vector3(1.5, 0, -6), Vector3(1.5, 0, 6), true)
	assert_gt(worst, BodySpaceScript.TALK_RADIUS - 0.3, "she keeps out of the talk: %.2f m" % worst)
	assert_true(_arrived, "and goes round it to the other side, not stopping at its edge")


func test_without_a_conversation_she_walks_straight() -> void:
	assert_lt(_cross(Vector3(1.5, 0, -6), Vector3(1.5, 0, 6), false), 0.2)


func test_the_two_talking_are_not_pushed() -> void:
	var talker := Walker.new()
	add_child_autofree(talker)
	talker.global_position = Vector3(1.0, 0, 0.2)
	BodySpaceScript.join(talker)
	BodySpaceScript.set_zone(&"talk", A, B, BodySpaceScript.TALK_RADIUS, [talker])
	BodySpaceScript._frame = -1
	assert_eq(BodySpaceScript.push_on(talker), Vector3.ZERO)
	BodySpaceScript.leave(talker)
