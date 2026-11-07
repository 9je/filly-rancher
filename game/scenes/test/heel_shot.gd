extends SceneTree
## The game camera while Tumble follows and the view turns (PT4: she keeps out of the shot).
##   xvfb-run ... godot --display-driver x11 --path game -s res://scenes/test/heel_shot.gd -- --out=/abs/dir
const BootIntentScript := preload("res://world/boot_intent.gd")
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	root.get_window().size = Vector2i(960, 540)
	BootIntentScript.driven = true
	BootIntentScript.request_new_game()
	change_scene_to_file("res://world/ranch.tscn")
	var ranch: Node = null
	for i in 900:
		await process_frame
		ranch = current_scene
		if ranch != null and ranch.get("people") != null and i > 30:
			break
	for i in 60:
		await process_frame
	var cs: Node = ranch.get("creation_screen")
	if cs != null and bool(cs.call("is_open")):
		cs.call("confirm")
	var lp: Node = ranch.get("letter_panel")
	if lp != null and bool(lp.call("is_open")):
		lp.call("close")
	paused = false
	# Tumble joins with the Scoop (ranch._is_present): past Marigold's welcome, as in play.
	ranch.get("_game_state").story.set_flag("has_scoop")
	ranch.get("people").call("populate")
	for i in 120:
		await process_frame
	var rig: Node = ranch.find_child("CameraRig", true, false)
	# Each turn of the view, a frame half a second, a second and two and a half seconds after
	# (PS8 item 18: she clears the shot within a second of a swing).
	for k in 6:
		var at := 0
		for mark: int in [30, 60, 150]:
			for i in mark - at:
				await process_frame
			at = mark
			root.get_texture().get_image().save_png(out.path_join("h_%d_%03d.png" % [k, mark]))
			var tb: Node3D = ranch.get("people").call("npc", &"tumble")
			var cam := root.get_viewport().get_camera_3d()
			var pl: Node3D = ranch.get("player")
			if tb != null and cam != null:
				var fwd := -cam.global_transform.basis.z
				fwd.y = 0.0
				fwd = fwd.normalized()
				var rel := tb.global_position - pl.global_position
				var to := tb.global_position - cam.global_position
				to.y = 0.0
				print("TUMBLE turn %d +%d ahead %.2f across %.2f in_aim %s" % [k, mark, rel.dot(fwd),
					rel.dot(fwd.cross(Vector3.UP)), rel.dot(fwd) > 0.0 and to.normalized().dot(fwd) > 0.9])
		if rig != null:
			rig.call("add_look_delta", 1.0, 0.0)
	print("HEEL_OK rig=", rig != null)
	quit()
