extends SceneTree
## GAP M RENDER: Marigold's welcome walk-up from the player's own camera, turned so that she
## starts behind it (the case that walked her across the shot). A frame every half second
## until the welcome opens; the nearest she came to the camera-to-player line is printed.
const BootIntentScript := preload("res://world/boot_intent.gd")
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _seg(x: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var ax := Vector2(x.x - a.x, x.z - a.z)
	var t := clampf(ax.dot(ab) / ab.length_squared(), 0.0, 1.0)
	return (ax - ab * t).length()


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
	var player: Node3D = ranch.get("player")
	var m: Node3D = ranch.get("people").call("npc", &"marigold")
	var rig: Node3D = player.find_child("CameraRig", true, false)
	var d := player.global_position - m.global_position
	rig.global_rotation.y = atan2(-d.x, -d.z)
	print("MARIGOLD starts ", m.global_position, " player ", player.global_position)
	var cs: Node = ranch.get("creation_screen")
	cs.call("confirm")
	# The welcome letter follows the creator; she reads it and closes it, as anypony would.
	for i in 60:
		await process_frame
		var lp: Node = ranch.get("letter_panel")
		if lp != null and lp.get("visible") and lp.has_method("close"):
			(lp.call("close_button_node") as Button).pressed.emit()
			break
	rig.global_rotation.y = atan2(-d.x, -d.z)
	var worst := INF
	var k := 0
	var t0 := Time.get_ticks_msec()
	while not ranch.get("people").call("is_talking") and k < 40:
		await process_frame
		var cam := root.get_viewport().get_camera_3d()
		worst = minf(worst, _seg(m.global_position, cam.global_position, player.global_position))
		if Time.get_ticks_msec() - t0 >= 500 * k:
			root.get_texture().get_image().save_png(out.path_join("greet_%02d.png" % k))
			k += 1
	for i in 20:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join("greet_talk.png"))
	print("GREET_SHOT_OK frames ", k, " nearest to the shot ", worst, " talking ", ranch.get("people").call("is_talking"))
	quit(0)
