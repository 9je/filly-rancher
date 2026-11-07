extends SceneTree
## ITEM 56 RENDER: the Collector's walk by, as the player sees it from her own camera (a frame
## every 3 s), and a close look at him by the fence in his coat with his clipboard.
const BootIntentScript := preload("res://world/boot_intent.gd")
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _shot(name: String) -> void:
	await process_frame
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("SHOT ", name)


func _run() -> void:
	root.get_window().size = Vector2i(1280, 720)
	BootIntentScript.driven = true
	BootIntentScript.request_new_game()
	change_scene_to_file("res://world/ranch.tscn")
	var ranch: Node = null
	for i in 900:
		await process_frame
		ranch = current_scene
		if ranch != null and ranch.get("people") != null and i > 30:
			break
	for i in 240:
		await process_frame
	var cs: Node = ranch.get("creation_screen")
	if cs != null and cs.call("is_open"):
		cs.call("confirm")
	for i in 30:
		await process_frame
	print("PAUSED ", paused)
	# At minute 40 nothing is open: close whatever the first minute put up.
	for i in 5:
		var letter := ranch.get_node_or_null(^"LetterPanel")
		if letter != null and letter.has_method("close"):
			letter.call("close")
		await process_frame
	paused = false
	ranch.get("happenings").call("_collector_visit")
	var n: Node3D = null
	for c in ranch.get_children():
		if c is Npc and c.def != null and String(c.def.id) == "collector_visit":
			n = c
	var player: Node3D = ranch.get("player")
	# A bystander in the yard, looking out at the lane he walks.
	var lane := Camera3D.new()
	lane.fov = 70.0
	ranch.add_child(lane)
	lane.global_position = Vector3(0.0, 3.0, 8.0)
	lane.look_at(Vector3(0.0, 1.0, 22.0))
	lane.make_current()
	print("PLAYER ", player.global_position)
	var t0 := Time.get_ticks_msec()
	var k := 0
	var close_done := false
	while is_instance_valid(n) and k < 30:
		var t := float(Time.get_ticks_msec() - t0) / 1000.0
		if t >= 3.0 * k:
			await _shot("walk_%02d" % k)
			print("AT ", k, " ", n.global_position, " d ", n.global_position.distance_to(player.global_position))
			k += 1
		if not close_done and n.call("is_walking_to") == false and t > 5.0:
			close_done = true
			var cam := Camera3D.new()
			ranch.add_child(cam)
			cam.global_position = n.global_position + Vector3(3.2, 1.6, -2.6)
			cam.look_at(n.global_position + Vector3(0, 0.9, 0))
			cam.make_current()
			for i in 3:
				await process_frame
			await _shot("close_fence")
			cam.global_position = n.global_position + Vector3(-3.2, 1.8, 2.4)
			cam.look_at(n.global_position + Vector3(0, 0.9, 0))
			await process_frame
			await _shot("close_fence_back")
			lane.make_current()
			cam.free()
		await process_frame
	print("COLLECTOR_SHOT_OK frames ", k)
	quit(0)
