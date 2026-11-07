extends SceneTree
## ITEM 34 RENDER: the crosshair on a townspony's face, then on a wild pony, from the player's
## own camera; the speech bubble beside the reticle marks the townspony.
const BootIntentScript := preload("res://world/boot_intent.gd")
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _place(who: Node3D, height: float) -> void:
	var cam := root.get_viewport().get_camera_3d()
	var dir := -cam.global_transform.basis.z
	var t := (height - cam.global_position.y) / dir.y if absf(dir.y) > 0.01 else 7.0
	t = clampf(t, 5.0, 9.0)
	var at := cam.global_position + dir * t
	who.global_position = Vector3(at.x, 0.0, at.z)
	var face := cam.global_position - who.global_position
	(who.get_node(^"Visuals") as Node3D).rotation.y = atan2(face.x, face.z) + PI if who is Npc else 0.0


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
	var rig: Node3D = ranch.get("player").find_child("CameraRig", true, false)
	rig.call("add_look_delta", 0.0, -0.08)
	var fennel: Npc = ranch.get("people").call("npc", &"fennel")
	fennel.set_process(false)
	fennel.set_physics_process(false)
	_place(fennel, 1.75)
	for i in 30:
		await process_frame
	ranch.set("_person_aim_t", 0.0)
	ranch.call("_update_person_aim")
	await process_frame
	root.get_texture().get_image().save_png(out.path_join("aim_townspony.png"))
	print("AIM townspony ", ranch.get_node(^"HUD").call("aiming_person"))
	fennel.global_position += Vector3(60, 0, 60)
	var wild: Node3D = null
	for p in ranch.get("spawner").call("get_spawned"):
		if is_instance_valid(p) and not (p as Node3D).is_in_group(&"penned"):
			wild = p
			break
	wild.set_physics_process(false)
	_place(wild, 1.0)
	for i in 30:
		await process_frame
	ranch.set("_person_aim_t", 0.0)
	ranch.call("_update_person_aim")
	await process_frame
	root.get_texture().get_image().save_png(out.path_join("aim_wild.png"))
	print("AIM wild ", ranch.get_node(^"HUD").call("aiming_person"))
	quit(0)
