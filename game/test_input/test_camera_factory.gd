extends "res://test_input/test_camera_terrain.gd"
## fixed-fps: 144
## THE SAME CAMERA CHECK INSIDE THE RAINBOW FACTORY (docs/playtest_fixes/camera.md). The
## Factory is its own scene with its own floor and walls and no Terrain, so the ranch walk in
## test_camera_terrain.gd never goes there. The story only sends you up on Color Day, so this
## test loads the Factory scene the way the cloud-lift does (change_scene_to_file, the same
## call ranch.gd's _ride_lift_to_factory() makes) and from then on plays it with real input:
## walk the landing room, press against its walls, and at every stop sweep
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

	# The landing only. room_origin() is a room's far (+Z) edge, so the landing's floor runs
	# from there 12 m toward -Z. Walking on toward the welcome room, the first run of this
	# test saw her fall straight through the Factory floor (y -63 and still falling) -- a
	# separate fault, reported rather than fixed here, and one that would only test the
	# camera in free fall.
	var interior: Node = ranch.get("interior")
	var landing: Vector3 = interior.call("room_origin", &"landing") + Vector3(0, 0, -6.0)
	var stops: Array[Dictionary] = [
		{"name": "factory_landing", "at": _flat(landing)},
		{"name": "factory_landing_wall", "at": _flat(landing) + Vector2(4.6, 0), "push": _flat(landing) + Vector2(8, 0)},
		# The landing's +Z edge is where the cloud-lift sets you down, and it is OPEN: a run that
		# pushed her at it walked her off into the void (y -245). Stopped a metre short instead.
		{"name": "factory_landing_edge", "at": _flat(landing) + Vector2(-2.0, 5.0)},
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


## The Factory's floor under world XZ: every room's floor is a slab whose top is y = 0
## (factory_interior.gd), 12 m wide, the eight rooms in a row from the landing's +Z edge
## toward -Z; anywhere else there is no floor. (A ray down would answer with the top of a 6 m
## wall for a lens just past it; a lens through a wall is the legs check's to report.)
func _surface(x: float, z: float) -> float:
	var edge: float = (ranch.get("interior").call("room_origin", &"landing") as Vector3).z
	if absf(x) <= 6.0 and z <= edge and z >= edge - 12.0 * 8.0:
		return 0.0
	return -30.0
