extends SceneTree
## ITEM 9 MEASURE: the player walks straight for three seconds at 144 rendered frames a second
## (a fast monitor) on the 60 Hz physics tick; each rendered frame the tail tip's position in
## the body's own frame is sampled. A smooth tail changes by a steady amount frame to frame; a
## stutter is a frame that moves much more or less than its neighbours. Prints the ratio of
## frame-to-frame jerk to motion for the tail as built (--mode=N overrides the skeleton's
## modifier step: 0 the physics tick, 1 every rendered frame).
const BootIntentScript := preload("res://world/boot_intent.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Engine.max_fps = 144
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
	var body: Node3D = (player.get("visuals") as Node3D).get_child(0)
	var sk: Skeleton3D = body.find_children("*", "Skeleton3D", true, false)[0]
	# --mode=N forces the skeleton's modifier step (0 the physics tick, 1 every frame);
	# --old puts her clip and her springs back on every drawn frame, as before PT11.
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mode="):
			sk.modifier_callback_mode_process = int(a.substr(7))
	if "--old" in OS.get_cmdline_user_args():
		sk.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_IDLE
		(player.get("_anim") as AnimationPlayer).callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	# --ticks samples once per physics tick: the tail's own path, without the 60 Hz steps a
	# 144 Hz display adds to everything.
	var per_tick := "--ticks" in OS.get_cmdline_user_args()
	var tip := -1
	for i in sk.get_bone_count():
		var n := sk.get_bone_name(i).to_lower()
		if n.contains("tail"):
			tip = i
	print("TAIL bone ", sk.get_bone_name(tip), " mode ", sk.modifier_callback_mode_process)
	Input.action_press(&"move_forward")
	for i in 60:
		await process_frame
	var pts: Array[Vector3] = []
	var on_screen: Array[Vector3] = []
	var body_screen: Array[Vector3] = []
	for i in (180 if per_tick else 432):
		if per_tick:
			await physics_frame
		else:
			await process_frame
		var tip_world := sk.global_transform * sk.get_bone_global_pose(tip)
		pts.append(body.global_transform.affine_inverse() * tip_world.origin)
		# What the eye sees: the tail tip and her body in the camera's own frame, drawn as
		# rendered (the interpolated transforms when physics interpolation is on).
		var cam := root.get_viewport().get_camera_3d()
		var view := cam.get_global_transform_interpolated().affine_inverse()
		var b_at: Vector3 = body.get_global_transform_interpolated().origin
		on_screen.append(view * (body.get_global_transform_interpolated() * (body.global_transform.affine_inverse() * tip_world.origin)))
		body_screen.append(view * b_at)
	Input.action_release(&"move_forward")
	var motion := 0.0
	var jerk := 0.0
	var spike := 0.0
	for i in range(2, pts.size()):
		var v1 := pts[i] - pts[i - 1]
		var v0 := pts[i - 1] - pts[i - 2]
		motion += v1.length()
		jerk += (v1 - v0).length()
		spike = maxf(spike, (v1 - v0).length())
	# A stutter is a lone kick: the largest single step's jerk against the average step.
	print("TAIL_SPIKE %.2f" % (spike / maxf(motion / float(pts.size() - 2), 1e-6)))
	print("TAIL_FRAMES jerk/motion %.3f  (motion %.4f m over %d frames)" % [jerk / maxf(motion, 1e-6), motion, pts.size()])
	for pair: Array in [["tail on screen", on_screen], ["body on screen", body_screen]]:
		var arr: Array = pair[1]
		var m2 := 0.0
		var j2 := 0.0
		for i in range(2, arr.size()):
			var a1: Vector3 = arr[i] - arr[i - 1]
			var a0: Vector3 = arr[i - 1] - arr[i - 2]
			m2 += a1.length()
			j2 += (a1 - a0).length()
		print("SCREEN %s jerk %.4f m, motion %.4f m" % [pair[0], j2, m2])
	quit(0)
