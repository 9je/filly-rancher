extends GutTest
## TUMBLE AT YOUR HEEL, NOT IN THE SHOT (PS8, playtest 2026-11-05 item 18: "Tumble gets in the
## way at catch time: in front of the camera, and her talk prompt steals E"). When the camera
## swings round (aiming at a pony), her old heel spot is suddenly ahead of the player. From
## anywhere ahead she leaves the aim cone within a second, never walks through the line from
## the camera to the player, and settles at her heel. A companion is never offered on E while
## a wild pony is in the aim.

const NpcScript := preload("res://actors/npc/npc.gd")
const PeopleScript := preload("res://world/people.gd")

const PLAYER := Vector3(1.0, 0.0, 2.0)
const STEP := 1.0 / 60.0


func _seg_dist(x: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var ax := Vector2(x.x - a.x, x.z - a.z)
	var t := clampf(ax.dot(ab) / ab.length_squared(), 0.0, 1.0)
	return (ax - ab * t).length()


## Inside the aim cone: ahead of the player and within LOOK_CONE of the camera's line.
func _in_aim(x: Vector3, cam: Vector3, fwd: Vector3) -> bool:
	var to := Vector3(x.x - cam.x, 0.0, x.z - cam.z)
	return (x - PLAYER).dot(fwd) > 0.0 and to.normalized().dot(fwd) > PeopleScript.LOOK_CONE


func test_after_a_camera_swing_she_clears_the_aim_and_settles_behind() -> void:
	for yaw_deg in range(0, 360, 45):
		var back := Vector3(sin(deg_to_rad(yaw_deg)), 0.0, cos(deg_to_rad(yaw_deg)))
		var fwd := -back
		var cam := PLAYER + back * 4.5
		# Everywhere a swing of the view can leave her: her heel is about 2 m from the player,
		# so a turn puts her at most that far ahead, anywhere across.
		for lateral: float in [-2.0, -1.0, -0.4, 0.0, 0.5, 1.0, 2.0]:
			for ahead: float in [0.5, 1.0, 1.5, 2.0]:
				var x := PLAYER + fwd * ahead + fwd.cross(Vector3.UP) * lateral
				var start_d := _seg_dist(x, cam, PLAYER)
				var in_aim_for := 0.0
				var worst := INF
				# As the Npc moves: aim at the stop, ease in near it, pick up speed at heel_accel.
				var v := Vector3.ZERO
				for i in 900:
					var stop: Vector3 = NpcScript.heel_route(x, PLAYER, back)
					var to := Vector3(stop.x - x.x, 0.0, stop.z - x.z)
					var speed: float = NpcScript.heel_speed(x, PLAYER, back, 1.1, 3.4)
					if to.length() < 0.6 and v.length() < 0.2:
						break
					var desired := Vector3.ZERO
					if to.length() > NpcScript.HEEL_STOP:
						desired = to.normalized() * minf(speed, (to.length() - NpcScript.HEEL_STOP) * 2.0 + 0.4)
					v = v.move_toward(desired, NpcScript.heel_accel(x, PLAYER, back) * STEP)
					x += v * STEP
					if _in_aim(x, cam, fwd):
						in_aim_for += STEP
					worst = minf(worst, _seg_dist(x, cam, PLAYER))
				assert_lt(in_aim_for, 1.0, "yaw %d, from %.1f ahead %.1f across: out of the aim in a second" % [yaw_deg, ahead, lateral])
				# Never closer to the camera's line than she started (or 0.8 m, whichever is less).
				assert_gt(worst, minf(0.8, start_d) - 0.05, "yaw %d: never through the camera's line" % yaw_deg)
				assert_lt((x - PLAYER).dot(fwd), NpcScript.HEEL_AHEAD, "and she settles at her heel, not ahead of the player")


func test_at_catch_time_e_is_not_hers() -> void:
	var player := Node3D.new()
	add_child_autofree(player)
	var people: People = PeopleScript.new()
	people.player = player
	people.context_provider = func() -> Dictionary:
		return {"chapter": 0, "path": "", "flags": {}, "counts": {}, "name": "Juniper", "tumble": "Tumble"}
	people.presence = func(id: StringName) -> bool: return id == &"tumble"
	add_child_autofree(people)
	people.populate()
	await wait_physics_frames(2)
	var tumble := people.npc(&"tumble")
	tumble.global_position = player.global_position + Vector3(1.0, 0, -1.0)
	var at := player.global_position
	assert_eq(people.candidates(at).size(), 1, "with nothing to catch, she is offered")
	var wild := Node3D.new()
	add_child_autofree(wild)
	wild.global_position = player.global_position + Vector3(0, 0, -6.0)
	people.wild_provider = func() -> Array: return [wild]
	assert_eq(people.candidates(at).size(), 0, "a wild pony in the aim: no prompt for her, news or none")
