extends SceneTree
## The guide trail through the game camera at play distance (FS1.5): the goal 10 and 18 m
## off, ahead of her.
##   xvfb-run ... godot --display-driver x11 --path game -s res://scenes/test/trail_shot.gd -- --out=/abs/dir
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
	for i in 60:
		await process_frame
	var cs: Node = ranch.get("creation_screen")
	if cs != null and bool(cs.call("is_open")):
		cs.call("confirm")
	var lp: Node = ranch.get("letter_panel")
	if lp != null and bool(lp.call("is_open")):
		lp.call("close")
	paused = false
	for i in 120:
		await process_frame
	var goal: Node3D = ranch.get("_guide_node")
	var player: Node3D = ranch.get("player")
	var rig: Node = ranch.find_child("CameraRig", true, false)
	print("TRAIL goal ", goal.name if goal != null else "none")
	if goal == null:
		quit()
		return
	var k := 0
	for d in [10.0, 18.0]:
		for side in [0.0, 1.2]:
			var dir := Vector3(sin(side), 0, cos(side))
			var at: Vector3 = goal.global_position + dir * d
			at.y = float(ranch.get("terrain").call("height_at", at.x, at.z)) + 0.2
			player.global_position = at
			var yaw := atan2(dir.x, dir.z)
			player.call("face", yaw)
			rig.call("reset_look", yaw)
			for i in 90:
				await process_frame
			root.get_texture().get_image().save_png(out.path_join("trail_%d_%dm.png" % [k, int(d)]))
			var trail: Node = ranch.get("_guide_trail")
			print("TRAIL shot %d at %d m: %d motes, beacon %s" % [k, int(d),
				(trail.call("mote_positions") as Array).size(), trail.call("beacon_shown")])
			k += 1
	quit()
