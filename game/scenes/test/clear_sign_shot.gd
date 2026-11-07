extends SceneTree
## ITEM 26 RENDER: an overgrown plot's price sign as the player walks up to it, at eye height
## from 6 m and 10 m, by day and at night.
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
	var sign: Node3D = null
	for slot: Node in ranch.get_node(^"Plots").get_children():
		if slot.has_method("is_overgrown") and bool(slot.call("is_overgrown")):
			sign = slot.find_child("Sign", true, false)
			break
	var board: Node3D = sign.get_node(^"Board")
	var face: Vector3 = board.global_transform.basis.z
	face.y = 0.0
	face = face.normalized()
	var hud := ranch.get_node_or_null(^"HUD") as CanvasLayer
	if hud != null:
		hud.visible = false
	var cam := Camera3D.new()
	cam.fov = 60.0
	ranch.add_child(cam)
	cam.make_current()
	var w: Object = ranch.get("_world")
	for phase in [["day", WorldStateScript.Phase.DAY], ["night", WorldStateScript.Phase.NIGHT]]:
		if w != null:
			w.call("pin", phase[1], WorldStateScript.Weather.CLEAR)
		for d: float in [6.0, 10.0]:
			cam.global_position = board.global_position + face * d + Vector3(0, -0.4, 0)
			cam.global_position.y = 1.7
			cam.look_at(board.global_position)
			for i in 90:
				await process_frame
			root.get_texture().get_image().save_png(out.path_join("sign_%s_%dm.png" % [phase[0], int(d)]))
	print("CLEAR_SIGN_OK")
	quit()
