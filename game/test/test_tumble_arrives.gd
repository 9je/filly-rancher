extends GutTest
## TUMBLE ARRIVES, SHE DOES NOT APPEAR (PS1, playtest 2026-11-05 item 13: "Tumble spawned
## mid-conversation, inside the player"). When she joins, she is stood up well away from the
## player (never within 6 m), behind the camera (out of the shot), never inside a building,
## and then trots in to her heel.

const PeopleScript := preload("res://world/people.gd")


func _people(player: Node3D) -> People:
	var people: People = PeopleScript.new()
	people.player = player
	people.context_provider = func() -> Dictionary:
		return {"chapter": 0, "path": "", "flags": {}, "counts": {}, "name": "Juniper", "tumble": "Tumble"}
	people.presence = func(id: StringName) -> bool: return id == &"tumble"
	add_child_autofree(people)
	return people


func test_she_joins_from_behind_the_camera_well_away_and_comes_in() -> void:
	for yaw_deg in [0, 90, 200]:
		var player := Node3D.new()
		add_child_autofree(player)
		player.global_position = Vector3(3.0, 0.0, 7.0)
		player.rotation.y = deg_to_rad(float(yaw_deg))
		var people := _people(player)
		people.populate()
		var t := people.npc(&"tumble")
		assert_not_null(t)
		var d := t.global_position.distance_to(player.global_position)
		assert_gt(d, 6.0, "she is not stood up beside (or in) the player: %.1f m" % d)
		# Behind: the side the camera is on (headless: behind the player's facing).
		var back: Vector3 = player.global_basis.z
		assert_gt((t.global_position - player.global_position).normalized().dot(back), 0.3,
			"she comes from behind the camera")
		assert_eq(Building.rescue_point(t.global_position), Vector3.INF, "never inside a building")
		await wait_physics_frames(240)
		# Along the ground: there is no floor in a test, so she falls as she goes.
		var flat := Vector2(t.global_position.x - player.global_position.x,
			t.global_position.z - player.global_position.z).length()
		assert_lt(flat, 4.0, "and she trots in")
