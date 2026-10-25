extends "res://test_input/test_camera_terrain.gd"
## fixed-fps: 144
## THE SAME CAMERA CHECK INSIDE THE RAINBOW FACTORY (docs/playtest_fixes/camera.md). The
## Factory is its own scene with its own floor and walls and no Terrain, so the ranch walk in
## test_camera_terrain.gd never goes there. The story only sends you up on Color Day, so this
## test loads the Factory scene the way the cloud-lift does (change_scene_to_file, the same
## call ranch.gd's _ride_lift_to_factory() makes) and from then on plays it with real input:
## walk the landing and the welcome room, press against their walls, and at every stop sweep
## the mouse through the full yaw, pitch and zoom range. Every frame is checked exactly as in
## the ranch test; "the ground" is whatever the Factory's floor is under the lens (a ray down
## onto layer 1, which is where its floor and walls sit).

const FACTORY_SCENE := "res://world/factory.tscn"


func _play() -> void:
	_deadline_s = 1500.0
	change_scene_to_file(FACTORY_SCENE)
	var t := 0.0
	while t < 60.0:
		var s := current_scene
		if s != null and s.get("player") != null and s.get("interior") != null:
			ranch = s
			break
		await wait(0.1)
		t += 0.1
	if not check(ranch != null, "the Factory scene never came up"):
		return
	player = ranch.get("player")
	rig = player.call("get_camera_pivot").get_node("CameraRig")
	await wait(1.0)
	var watcher := _Watcher.new()
	watcher.test = self
	watcher.process_priority = 1 << 30
	watcher.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(watcher)
	_checking = true
	await _clear_ui()

	var interior: Node = ranch.get("interior")
	var landing: Vector3 = interior.call("room_origin", &"landing")
	var welcome: Vector3 = interior.call("room_origin", &"welcome")
	var stops: Array[Dictionary] = [
		{"name": "factory_landing", "at": _flat(landing)},
		{"name": "factory_landing_wall", "at": _flat(landing) + Vector2(4.6, 0), "push": _flat(landing) + Vector2(8, 0)},
		{"name": "factory_welcome", "at": _flat(welcome), "path": [_flat(landing)]},
		{"name": "factory_welcome_wall", "at": _flat(welcome) + Vector2(-4.6, 2.0),
			"push": _flat(welcome) + Vector2(-8, 2.0)},
	]
	for stop: Dictionary in stops:
		_stop = stop.name
		note("-> %s at %s" % [stop.name, stop.at])
		for w: Vector2 in stop.get("path", []):
			await _travel(Vector3(w.x, 0.0, w.y), 20.0)
		await _travel(Vector3(stop.at.x, 0.0, stop.at.y), 20.0)
		if stop.has("push"):
			await _push(Vector3(stop.push.x, 0.0, stop.push.y))
		note("   at %s %s" % [stop.name, player.global_position.snapped(Vector3.ONE * 0.01)])
		await _sweep()
	_checking = false
	note("checked %d frames, %d bad" % [_frames, _bad_frames])
	for k: String in _kinds:
		note("  kind %s: %d frames" % [k, _kinds[k]])
	for s: String in _lowest:
		note("  lowest lens over the floor at %s: %.3f m" % [s, _lowest[s]])
	if _bad_frames > 0:
		fail("%d of %d frames had the camera under or inside the Factory" % [_bad_frames, _frames])
	else:
		ok("%d frames, the camera never went through the Factory's floor or walls" % _frames)


## The Factory's floor under world XZ: a ray down onto layer 1 from well above its 6 m walls.
func _surface(x: float, z: float) -> float:
	var space := (player as Node3D).get_world_3d().direct_space_state
	var rq := PhysicsRayQueryParameters3D.create(Vector3(x, 30.0, z), Vector3(x, -30.0, z),
		LayersScript.TERRAIN)
	rq.hit_back_faces = false
	var hit := space.intersect_ray(rq)
	return (hit.position as Vector3).y if not hit.is_empty() else -30.0
