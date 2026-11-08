extends GutTest
## THE CINEMATIC PLAYER (P8 S9): a scene plays its shots on its own camera, gives the game its
## camera back, freezes and thaws who it was told to, waits for can_start, and can be skipped.


func _scene() -> Node3D:
	var world := Node3D.new()
	add_child_autofree(world)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.current = true
	return world


func test_it_plays_on_its_own_camera_and_hands_the_old_one_back() -> void:
	var world := _scene()
	var game_cam := get_viewport().get_camera_3d()
	var c := Cinematic.shared(get_tree())
	var body := Node3D.new()
	world.add_child(body)
	var seen := []
	c.started.connect(func() -> void: seen.append(get_viewport().get_camera_3d()), CONNECT_ONE_SHOT)
	var skipped: bool = await c.play([
		{"from": Vector3(0, 2, 5), "to": Vector3(1, 2, 5), "look": Vector3.ZERO, "time": 0.2},
		{"from": "here", "to": Vector3(2, 3, 5), "look": Vector3.ZERO, "time": 0.2,
			"caption": "A test"}], {"host": world, "freeze": [body]})
	assert_false(skipped)
	assert_ne(seen[0], game_cam, "the scene had its own camera")
	assert_eq(get_viewport().get_camera_3d(), game_cam, "and gave the game's back")
	assert_eq(body.process_mode, Node.PROCESS_MODE_INHERIT, "thawed")
	assert_false(c.playing)


func test_it_waits_for_can_start_and_can_be_skipped() -> void:
	var world := _scene()
	var c := Cinematic.shared(get_tree())
	var ok := [false]
	get_tree().create_timer(0.3).timeout.connect(func() -> void: ok[0] = true)
	get_tree().create_timer(0.8).timeout.connect(func() -> void: c.skip())
	var t0 := Time.get_ticks_msec()
	var skipped: bool = await c.play([{"from": Vector3(0, 2, 5), "look": Vector3.ZERO,
		"time": 30.0}], {"host": world, "can_start": func() -> bool: return ok[0]})
	assert_true(skipped, "a long shot ends early when skipped")
	assert_gte(Time.get_ticks_msec() - t0, 300, "it waited for can_start")
	assert_lt(Time.get_ticks_msec() - t0, 5000)
