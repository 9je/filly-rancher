extends SceneTree
## The player's stop from a gallop, side-on, and a hard turn from behind (FS4.2: GaitBlend).
##   xvfb-run ... godot --display-driver x11 --path game -s res://scenes/test/gait_shot.gd -- --out=/abs/dir
const BootIntentScript := preload("res://world/boot_intent.gd")
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	root.get_window().size = Vector2i(640, 400)
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
	var player: Node3D = ranch.get("player")
	var anim: AnimationPlayer = player.get("_anim")
	var vis: Node3D = player.get("visuals")
	var cam := Camera3D.new()
	cam.fov = 45.0
	ranch.add_child(cam)
	cam.current = true
	# Gallop, then let go: side-on.
	Input.action_press(&"move_forward")
	Input.action_press(&"gallop")
	for i in 150:
		await physics_frame
	Input.action_release(&"move_forward")
	Input.action_release(&"gallop")
	for k in 16:
		var side := vis.global_basis.x
		cam.global_position = player.global_position + side * 4.5 + Vector3(0, 1.0, 0)
		cam.look_at(player.global_position + Vector3(0, 0.7, 0))
		await process_frame
		root.get_texture().get_image().save_png(out.path_join("stop_%02d.png" % k))
		print("GAIT stop %d clip %s speed %.2f scale %.2f" % [k, anim.current_animation,
			float(player.call("get_ground_speed")), anim.speed_scale])
		for i in 3:
			await physics_frame
	for i in 60:
		await physics_frame
	# Gallop and swing left hard: from behind.
	Input.action_press(&"move_forward")
	Input.action_press(&"gallop")
	for i in 90:
		await physics_frame
	var behind := -vis.global_basis.z
	Input.action_press(&"move_left")
	for k in 10:
		cam.global_position = player.global_position - (-vis.global_basis.z) * 5.0 + Vector3(0, 1.4, 0)
		cam.look_at(player.global_position + Vector3(0, 0.8, 0))
		await process_frame
		root.get_texture().get_image().save_png(out.path_join("turn_%02d.png" % k))
		print("GAIT turn %d roll %.1f deg" % [k, rad_to_deg(vis.rotation.z)])
		for i in 3:
			await physics_frame
	Input.action_release(&"move_left")
	Input.action_release(&"move_forward")
	Input.action_release(&"gallop")
	print("GAIT_OK ", behind != Vector3.ZERO)
	quit()
