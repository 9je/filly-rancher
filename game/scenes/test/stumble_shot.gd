extends SceneTree
## G4 RENDER: the player dropped from 2.5 m, filmed from the side: frames through the landing,
## the stumble's pitch printed with each.
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
	var player: CharacterBody3D = ranch.get("player")
	var hud := ranch.get_node_or_null(^"HUD") as CanvasLayer
	if hud != null:
		hud.visible = false
	player.global_position += Vector3(0, 2.5, 0)
	player.velocity = Vector3.ZERO
	var cam := Camera3D.new()
	ranch.add_child(cam)
	var side: Vector3 = (player.get("visuals") as Node3D).global_basis.x
	cam.global_position = player.global_position + side * 4.0 + Vector3(0, -1.4, 0)
	cam.look_at(player.global_position + Vector3(0, -1.6, 0))
	cam.make_current()
	var landed := -1
	var k := 0
	var airborne := false
	for f in 160:
		await physics_frame
		if not player.is_on_floor():
			airborne = true
		if landed < 0 and airborne and player.is_on_floor():
			landed = f
		if landed >= 0 and (f - landed) % 2 == 0 and k < 8:
			await process_frame
			root.get_texture().get_image().save_png(out.path_join("stumble_%02d.png" % k))
			print("FRAME %d pitch %.3f slow %.2f" % [k, (player.get("visuals") as Node3D).rotation.x, player.call("stumble_slow")])
			k += 1
	quit(0)
