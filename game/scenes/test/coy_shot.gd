extends SceneTree
## ITEM 67 RENDER: a calm Drifter 1.5 m from the player (where the look used to switch off),
## her face close up: the half-lidded look when she notices the player, and her ordinary eyes
## once the moment has passed.
const BootIntentScript := preload("res://world/boot_intent.gd")
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


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
	var player: Node3D = ranch.get("player")
	var pony: Node3D = null
	for p in ranch.get("spawner").call("get_spawned"):
		if is_instance_valid(p) and not (p as Node3D).is_in_group(&"penned") and p.get("_data") == null:
			pony = p
			break
	if pony == null:
		pony = ranch.get("spawner").call("get_spawned")[0]
	# Far away first, so she has not noticed the player yet; then 1.5 m in front of her.
	pony.set("calm", 9999.0)
	pony.call("_transition_to", 0)
	pony.set("_state_timer", 999.0)
	pony.global_position = player.global_position - player.global_basis.z * 1.5 * -1.0 + Vector3(0, 0.2, 0)
	var face_dir := player.global_position - pony.global_position
	var facing := atan2(-face_dir.x, -face_dir.z)
	(pony.get("visuals") as Node3D).rotation.y = facing
	var cam := Camera3D.new()
	ranch.add_child(cam)
	var mid := (player.global_position + pony.global_position) * 0.5
	# Over the player's shoulder, as she sees it.
	var side := face_dir.normalized().cross(Vector3.UP)
	cam.global_position = player.global_position + Vector3(0, 1.9, 0) + side * 0.6 + face_dir.normalized() * 0.4
	cam.look_at(pony.global_position + Vector3(0, 1.45, 0))
	cam.fov = 40.0
	cam.make_current()
	var t0 := Time.get_ticks_msec()
	var shots := {700: "coy_noticed", 6500: "coy_passed"}
	for at: int in shots:
		while Time.get_ticks_msec() - t0 < at:
			pony.call("_transition_to", 0) if pony.get("state") != 0 else null
			pony.set("_state_timer", 999.0)
			(pony.get("visuals") as Node3D).rotation.y = facing
			await process_frame
		root.get_texture().get_image().save_png(out.path_join(String(shots[at]) + ".png"))
		print("SHOT ", shots[at], " coy ", pony.call("is_coy"), " d ", pony.global_position.distance_to(player.global_position))
	quit(0)
