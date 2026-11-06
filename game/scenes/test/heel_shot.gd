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
	var rig: Node = ranch.find_child("CameraRig", true, false)
	for k in 6:
		for i in 150:
			await process_frame
		root.get_texture().get_image().save_png(out.path_join("h_%d.png" % k))
		if rig != null:
			rig.call("add_look_delta", 1.0, 0.0)
	print("HEEL_OK rig=", rig != null)
	quit()
