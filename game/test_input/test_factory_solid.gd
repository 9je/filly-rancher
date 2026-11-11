extends "res://test_input/input_test.gd"
## THE FACTORY'S FURNITURE IS SOLID (owner playtest 2026-11-10 item 13: "i can walk through
## almost all props up here"). Loaded as the cloud-lift loads it, the welcome talked through
## with real clicks, then W held straight at a Welcome Hall column: she must stop at it.
## FILLY_SHOT_DIR, when set, gets a frame of her against it.

const FACTORY_SCENE := "res://world/factory.tscn"


func _play() -> void:
	_deadline_s = 900.0
	change_scene_to_file(FACTORY_SCENE)
	var scene: Node = null
	var t := 0.0
	while t < 60.0:
		var s := current_scene
		if s != null and s.get("player") != null and s.get("people") != null:
			scene = s
			break
		await wait(0.1)
		t += 0.1
	if not check(scene != null, "the Factory scene never came up"):
		return
	ranch = scene
	player = scene.get("player")
	rig = player.call("get_camera_pivot").get_node("CameraRig")
	await wait(1.0)
	await wait_out_cinematic()
	var people: Node = scene.get("people")
	t = 0.0
	while t < 30.0 and not bool(people.call("is_talking")):
		await wait(0.2)
		t += 0.2
	await talk_through()
	# The nearest Welcome Hall column (a piece with a Solid box).
	var interior: Node = scene.get("interior")
	var hall: Node3D = interior.get("rooms")[&"welcome"]
	var column: StaticBody3D = null
	for b in hall.find_children("Solid", "StaticBody3D", true, false):
		if "column" in String(b.get_parent().scene_file_path):
			column = b
			break
	if not check(column != null, "no solid column in the Welcome Hall"):
		return
	var c := (column.get_child(0) as CollisionShape3D).global_position
	await walk_to(Vector3(c.x + 3.0, player.global_position.y, c.z), 1.0, 25.0)
	# Into the hall, Marigold talks about it (her room line): hear her out first.
	for k in 3:
		await wait(0.6)
		if bool(people.call("is_talking")):
			await talk_through()
	await look_at_point(Vector3(c.x, player.global_position.y, c.z), false, 0.03, 180, true)
	note("lined up at %s" % player.global_position)
	RI.press(&"move_forward")
	for k in 360:
		await process_frame
	RI.release(&"move_forward")
	var d := Vector2(player.global_position.x - c.x, player.global_position.z - c.z).length()
	note("held W at the column for 360 frames: her centre is %.2f m from its axis" % d)
	var dir := OS.get_environment("FILLY_SHOT_DIR")
	if not dir.is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(dir.path_join("factory_column_stop.png"))
	if not check(d > 0.45, "she walked into the column (%.2f m from its axis)" % d):
		return
	ok("W held into a Welcome Hall column for 360 frames: she stopped %.2f m from its axis" % d)
