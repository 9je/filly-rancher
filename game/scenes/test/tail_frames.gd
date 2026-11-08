extends SceneTree
## ITEM 9 MEASURE: the player walks straight for three seconds at 144 rendered frames a second
## (a fast monitor) on the 60 Hz physics tick; each rendered frame (sampled just before it is
## drawn) the tail tip's position in the body's own frame is taken. A smooth tail changes by a
## steady amount frame to frame; a stutter is a frame that moves much more or less than its
## neighbours. Prints the ratio of frame-to-frame jerk to motion for the tail, and the jerk of
## the tail, her body and a fixed ground point in the camera's frame (what the eye sees).
## --old / --pt11 put back the two earlier timings (see below); --ticks samples once a tick;
## --mode=N overrides the skeleton's modifier step; --strip=<png> saves a frame strip. Run it
## with the engine's --fixed-fps 144 for an exact 144 Hz cadence.
const BootIntentScript := preload("res://world/boot_intent.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Engine.max_fps = 144
	root.get_window().size = Vector2i(960, 540)
	if Array(OS.get_cmdline_user_args()).any(func(a: String) -> bool: return a.begins_with("--strip=")):
		root.get_window().size = Vector2i(1920, 1080)
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
	# A strip shows her and the ground only: the HUD's toasts would sit over her tail.
	if Array(OS.get_cmdline_user_args()).any(func(a: String) -> bool: return a.begins_with("--strip=")):
		for layer: Node in root.find_children("*", "CanvasLayer", true, false):
			layer.set("visible", false)
	var player: Node3D = ranch.get("player")
	var body: Node3D = (player.get("visuals") as Node3D).get_child(0)
	var sk: Skeleton3D = body.find_children("*", "Skeleton3D", true, false)[0]
	# --mode=N forces the skeleton's modifier step (0 the physics tick, 1 every frame);
	# --old puts her clip and her springs back on every drawn frame, as before PT11.
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mode="):
			sk.modifier_callback_mode_process = int(a.substr(7))
	# --old: before PT11 -- clip and springs every drawn frame, her body drawn on the tick.
	# --pt11: PT11 -- clip and springs on the tick, her body drawn on the tick.
	# (Neither flag: as built -- clip and springs every drawn frame, her body and camera drawn
	# between ticks, item 9.)
	var args := OS.get_cmdline_user_args()
	if "--old" in args or "--pt11" in args:
		player.set("draw_between_ticks", false)
	if "--old" in args:
		sk.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_IDLE
		(player.get("_anim") as AnimationPlayer).callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	if "--pt11" in args:
		sk.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_PHYSICS
		(player.get("_anim") as AnimationPlayer).callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	# --strip=<png> saves STRIP_FRAMES consecutive drawn frames, cropped round her tail, as one
	# sheet; --fixed-fps 144 on the engine's command line makes the cadence exact.
	var strip_path := ""
	for a in args:
		if a.begins_with("--strip="):
			strip_path = a.substr(8)
	# --ticks samples once per physics tick: the tail's own path, without the 60 Hz steps a
	# 144 Hz display adds to everything.
	var per_tick := "--ticks" in OS.get_cmdline_user_args()
	var tip := -1
	for i in sk.get_bone_count():
		var n := sk.get_bone_name(i).to_lower()
		if n.contains("tail"):
			tip = i
	print("TAIL bone ", sk.get_bone_name(tip), " mode ", sk.modifier_callback_mode_process)
	# --hold: she walks carrying a wild pony in the beam (the hold and the ribbon must keep up
	# with her drawn body, not step on the tick).
	var held: Node3D = null
	if "--hold" in args:
		root.get_node(^"/root/GameState").get("story").call("set_flag", "has_scoop")
		ranch.call("_apply_beam_recall")
		var beam: Node = player.call("get_magic_beam")
		for n in ranch.find_children("*", "CharacterBody3D", true, false):
			if n != player and n.has_method("set_held"):
				held = n
				break
		if held != null:
			held.global_position = player.global_position + Vector3(0, 0.5, -3)
			beam.call("_start_beam")
			beam.call("_begin_hold", held)
			# The struggle is not under test: give her no reason to slip out.
			beam.set("_struggle_seconds", 999.0)
			beam.set("_weave", 0.0)
		print("HOLD ", held)
	Input.action_press(&"move_forward")
	for i in 60:
		await process_frame
	var pts: Array[Vector3] = []
	var on_screen: Array[Vector3] = []
	var body_screen: Array[Vector3] = []
	var world_screen: Array[Vector3] = []
	var held_screen: Array[Vector3] = []
	# A fixed point of the world, a few metres ahead of her: how the ground moves on screen.
	var world_mark: Vector3 = body.global_position + Vector3(0, 0, -6)
	var strip: Array[Image] = []
	var crop := Rect2i()
	var last_tip_px := Vector2.ZERO
	var last_mark_px := Vector2.ZERO
	var last_ticks := 0
	var started_ms := Time.get_ticks_msec()
	var ticks_at_start := Engine.get_physics_frames()
	for i in (180 if per_tick else 432):
		if per_tick:
			await physics_frame
		else:
			# After every _process and before the frame is drawn: what this frame shows.
			# (process_frame fires BEFORE the nodes' _process, so it reads the tick's pose.)
			await RenderingServer.frame_pre_draw
		if strip_path != "":
			# At pre-draw the window's texture still holds the frame drawn LAST time round, so
			# each image is paired with the positions sampled one iteration earlier (waiting
			# for post-draw instead skipped every other frame).
			var cam0 := root.get_viewport().get_camera_3d()
			var to_px := Vector2(root.get_window().size) / root.get_visible_rect().size
			var tip_px := cam0.unproject_position(sk.global_transform * sk.get_bone_global_pose(tip).origin) * to_px
			var mark_px := cam0.unproject_position(world_mark) * to_px
			if i > 200 and strip.size() < STRIP_FRAMES:
				var img := root.get_texture().get_image()
				print("STRIP frame %d  tail tip (%.1f, %.1f) px  world mark (%.1f, %.1f) px  ticks %d" % [
					strip.size(), last_tip_px.x, last_tip_px.y, last_mark_px.x, last_mark_px.y, last_ticks])
				if crop.size == Vector2i.ZERO:
					crop = Rect2i(Vector2i(last_tip_px) - Vector2i(STRIP_CROP / 2, STRIP_CROP * 3 / 4), Vector2i(STRIP_CROP, STRIP_CROP))
					crop = crop.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
				strip.append(img.get_region(crop))
			last_tip_px = tip_px
			last_mark_px = mark_px
			last_ticks = Engine.get_physics_frames()
		var tip_world := sk.global_transform * sk.get_bone_global_pose(tip)
		pts.append(body.global_transform.affine_inverse() * tip_world.origin)
		# What the eye sees: the tail tip and her body in the camera's own frame, drawn as
		# rendered (the interpolated transforms when physics interpolation is on).
		var cam := root.get_viewport().get_camera_3d()
		var view := cam.get_global_transform_interpolated().affine_inverse()
		var b_at: Vector3 = body.get_global_transform_interpolated().origin
		on_screen.append(view * (body.get_global_transform_interpolated() * (body.global_transform.affine_inverse() * tip_world.origin)))
		body_screen.append(view * b_at)
		world_screen.append(view * world_mark)
		if held != null and is_instance_valid(held):
			held_screen.append(view * held.global_position)
	var secs := (Time.get_ticks_msec() - started_ms) / 1000.0
	print("RATE %.1f drawn frames a second, %.1f ticks a second" % [
		(180 if per_tick else 432) / maxf(secs, 0.001), (Engine.get_physics_frames() - ticks_at_start) / maxf(secs, 0.001)])
	Input.action_release(&"move_forward")
	if held != null:
		print("HOLD still held at the end: ", player.call("get_magic_beam").call("is_holding"), "  held frames ", held_screen.size())
	if strip_path != "":
		_save_strip(strip, strip_path)
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
	for pair: Array in [["tail on screen", on_screen], ["body on screen", body_screen], ["world on screen", world_screen], ["held pony on screen", held_screen]]:
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


const STRIP_FRAMES := 12
const STRIP_CROP := 320


## The frames side by side, six to a row, each with how much it differs from the one before
## (mean absolute pixel change; 0.000 is a repeated frame, the step the eye sees).
func _save_strip(frames: Array[Image], path: String) -> void:
	if frames.is_empty():
		return
	var w := frames[0].get_width()
	var h := frames[0].get_height()
	var cols := 6
	var rows := ceili(frames.size() / float(cols))
	var sheet := Image.create(w * cols + (cols - 1) * 4, h * rows + (rows - 1) * 4, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.WHITE)
	var diffs: Array[String] = []
	for k in frames.size():
		var f := frames[k]
		f.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(f, Rect2i(Vector2i.ZERO, f.get_size()), Vector2i((k % cols) * (w + 4), (k / cols) * (h + 4)))
		if k > 0:
			var prev := frames[k - 1]
			var total := 0.0
			for y in range(0, h, 2):
				for x in range(0, w, 2):
					var a := f.get_pixel(x, y)
					var b := prev.get_pixel(x, y)
					total += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
			diffs.append("%.4f" % (total / (ceili(w / 2.0) * ceili(h / 2.0) * 3.0)))
	sheet.save_png(path)
	print("STRIP %s frame-to-frame change %s" % [path, ", ".join(diffs)])
