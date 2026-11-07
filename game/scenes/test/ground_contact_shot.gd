extends SceneTree
## G2 RENDER: the ground at the foot of a region fence and its trees, from a player's height,
## with the contact shade off and on, and the grain close up.
const BootIntentScript := preload("res://world/boot_intent.gd")
const WorldStateScript := preload("res://systems/world_state.gd")
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
	var hud := ranch.get_node_or_null(^"HUD") as CanvasLayer
	if hud != null:
		hud.visible = false
	var fence: Node3D = (ranch.call("get_region_fences") as Array)[0]
	var post: Node3D = fence.find_children("*", "CollisionShape3D", true, false)[3]
	var at: Vector3 = post.global_position
	var cam := Camera3D.new()
	cam.fov = 55.0
	ranch.add_child(cam)
	var away := Vector3(at.x, 0, at.z).normalized() * -1.0
	cam.global_position = at + away * 5.0 + Vector3(0, 1.6, 0)
	cam.global_position.y = ranch.terrain.height_at(cam.global_position.x, cam.global_position.z) + 1.8
	cam.look_at(Vector3(at.x, ranch.terrain.height_at(at.x, at.z), at.z))
	cam.make_current()
	var mat: ShaderMaterial = ranch.terrain.call("ground_material")
	for v in [["off", 0.0, 0.0], ["on", ranch.terrain.CONTACT_DARK, ranch.terrain.GRAIN_AMOUNT]]:
		mat.set_shader_parameter(&"contact_dark", v[1])
		mat.set_shader_parameter(&"grain_amount", v[2])
		for i in 20:
			await process_frame
		root.get_texture().get_image().save_png(out.path_join("ground_%s.png" % v[0]))
	print("GROUND_OK")
	quit()
