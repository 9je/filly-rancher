extends GutTest
## A GREETING STAYS OUT OF THE SHOT (PS8, playtest 2026-11-05 known gap M: "Marigold walks in
## front of the camera when she greets you"). From anywhere in the yard, with the camera on
## any side of the player, a pony walking up to greet never comes within 1 m of the line from
## the camera to the player, and she ends ahead of the player, facing the camera.

const GreetPathScript := preload("res://systems/greet_path.gd")

const PLAYER := Vector3(3.0, 0.0, -2.0)


func _seg_dist(x: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var ax := Vector2(x.x - a.x, x.z - a.z)
	var t := clampf(ax.dot(ab) / ab.length_squared(), 0.0, 1.0)
	return (ax - ab * t).length()


## Walk `from` the way next_stop() says, 0.05 m a step, as the Npc does; the worst distance to
## the camera's line and where she ends.
func _walk(from: Vector3, cam: Vector3) -> Array:
	var x := from
	var worst := INF
	for i in 4000:
		var stop: Vector3 = GreetPathScript.next_stop(x, PLAYER, cam)
		var d := Vector3(stop.x - x.x, 0.0, stop.z - x.z)
		if d.length() < 0.06:
			break
		x += d.normalized() * 0.05
		worst = minf(worst, _seg_dist(x, cam, PLAYER))
	return [worst, x]


func test_from_every_side_she_never_crosses_the_shot() -> void:
	var fails := 0
	for yaw_deg in range(0, 360, 30):
		var back := Vector3(sin(deg_to_rad(yaw_deg)), 0.0, cos(deg_to_rad(yaw_deg)))
		var cam := PLAYER + back * 4.5 + Vector3(0, 2.0, 0)
		for ang in range(0, 360, 20):
			for r: float in [3.0, 8.0, 20.0]:
				var start := PLAYER + Vector3(sin(deg_to_rad(ang)), 0, cos(deg_to_rad(ang))) * r
				if _seg_dist(start, cam, PLAYER) < 1.2:
					continue
				var walked: Array = _walk(start, cam)
				if float(walked[0]) < 1.0:
					fails += 1
					if fails < 4:
						fail_test("camera yaw %d, start %s: %.2f m from the shot" % [yaw_deg, start, walked[0]])
				var end: Vector3 = walked[1]
				var ahead := (end - PLAYER).dot(-back)
				assert_gt(ahead, 1.5, "she ends ahead of the player, facing the camera")
	assert_eq(fails, 0)


func test_she_is_ready_to_talk_only_once_she_is_in_front() -> void:
	var cam := PLAYER + Vector3(0, 2, 4.5)
	assert_false(GreetPathScript.in_front(PLAYER + Vector3(2.0, 0, 1.0), PLAYER, cam), "beside and behind")
	assert_true(GreetPathScript.in_front(PLAYER + Vector3(0.8, 0, -2.4), PLAYER, cam))
