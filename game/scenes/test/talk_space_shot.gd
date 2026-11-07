extends SceneTree
## ITEM 10 RENDER: the player talking to Old Fennel while a wild pony is sent straight across
## the ground between them; seen from above, a frame every half second, and the nearest she
## came to the line between the two talking.
const BootIntentScript := preload("res://world/boot_intent.gd")
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _seg(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := Vector3(b.x - a.x, 0, b.z - a.z)
	var t := clampf(Vector3(p.x - a.x, 0, p.z - a.z).dot(ab) / ab.length_squared(), 0.0, 1.0)
	var q := a + ab * t
	return Vector2(p.x - q.x, p.z - q.z).length()


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
	for i in 120:
		await process_frame
	ranch.get("creation_screen").call("confirm")
	for i in 60:
		await process_frame
		var lp: Node = ranch.get("letter_panel")
		if lp != null and lp.get("visible"):
			(lp.call("close_button_node") as Button).pressed.emit()
			break
	paused = false
	var people: Node = ranch.get("people")
	var fennel: Node3D = people.call("npc", &"fennel")
	var player: Node3D = ranch.get("player")
	player.global_position = fennel.global_position + Vector3(3.0, 0.0, 0.0)
	for i in 10:
		await physics_frame
	people.call("talk", "fennel")
	print("TALKING ", people.call("is_talking"))
	var mid := (player.global_position + fennel.global_position) * 0.5
	var wild: Node3D = null
	for p in ranch.get("spawner").call("get_spawned"):
		if is_instance_valid(p) and not (p as Node3D).is_in_group(&"penned"):
			wild = p
			break
	wild.global_position = mid + Vector3(0, 0.3, -6.0)
	wild.set("calm", 9999.0)
	# Her territory moved here, so the leash lets her cross.
	wild.set("_home", mid)
	wild.set("roam_radius", 40.0)
	wild.call("_transition_to", 1)
	wild.set("_wander_target", mid + Vector3(0, 0, 6.0))
	wild.set("_state_timer", 60.0)
	var cam := Camera3D.new()
	ranch.add_child(cam)
	cam.global_position = mid + Vector3(7.0, 6.0, 0.0)
	cam.look_at(mid)
	cam.make_current()
	var worst := INF
	var t0 := Time.get_ticks_msec()
	var k := 0
	while k < 32:
		await physics_frame
		worst = minf(worst, _seg(wild.global_position, player.global_position, fennel.global_position))
		if Time.get_ticks_msec() - t0 >= 500 * k:
			root.get_texture().get_image().save_png(out.path_join("talk_%02d.png" % k))
			if k % 4 == 0:
				print("AT %.1f s: %.2f m from the line, at %s" % [k * 0.5,
					_seg(wild.global_position, player.global_position, fennel.global_position),
					(wild.global_position - mid).snapped(Vector3.ONE * 0.1)])
			k += 1
	print("TALK_SPACE_OK nearest ", worst, " moved ", wild.global_position.distance_to(mid + Vector3(0, 0.3, -6.0)), " still talking ", people.call("is_talking"), " wild at ", wild.global_position, " state ", wild.get("state"))
	quit(0)
