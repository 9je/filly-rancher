extends SceneTree
## One pony, every clip, side-on (PT1: Twilight twisting). Writes <clip>_<t>.png.
##   xvfb-run ... godot --display-driver x11 --path game -s res://scenes/test/clip_sheet.gd -- --out=/abs/dir --pony=twilight [--from=walk]
var out := ""
var pony_id := "twilight"
var from_clip := ""
var ground_kind := ""
var settle := 4
var kick := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--pony="):
			pony_id = a.substr(7)
		elif a.begins_with("--from="):
			from_clip = a.substr(7)
		elif a.begins_with("--ground="):
			ground_kind = a.substr(9)
		elif a == "--kick":
			kick = true
		elif a.begins_with("--settle="):
			settle = int(a.substr(9))
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	root.get_window().size = Vector2i(640, 480)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.7, 0.85)
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.5
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	world.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	ground.mesh = pm
	world.add_child(ground)
	if ground_kind == "flat":
		HoofPlanter.default_ground = func(_x: float, _z: float) -> float: return 0.0
	elif ground_kind == "slope":
		HoofPlanter.default_ground = func(x: float, _z: float) -> float: return x * 0.3
	var body: Node3D = PonyVisuals.build(load("res://data/ponies/%s.tres" % pony_id))
	world.add_child(body)
	var anim: AnimationPlayer = body.find_children("*", "AnimationPlayer", true, false)[0]
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.global_position = Vector3(3.2, 1.0, 0.6)
	cam.look_at(Vector3(0, 0.5, 0), Vector3.UP)
	cam.make_current()
	if kick:
		anim.play(&"idle")
		for i in 10:
			await process_frame
		RumpBounce.kick_on(body, 1.0)
		for f in 30:
			for i in 2:
				await process_frame
			root.get_texture().get_image().save_png(out.path_join("kick_%02d.png" % f))
		print("CLIPS_OK")
		quit()
		return
	for clip: StringName in anim.get_animation_list():
		if String(clip).begins_with("RESET"):
			continue
		for frac: float in [0.2, 0.5, 0.8]:
			if from_clip != "":
				anim.play(StringName(from_clip))
				for i in 20:
					await process_frame
				anim.play(clip, 0.25)
				for i in 8:
					await process_frame
			else:
				anim.play(clip)
				anim.seek(anim.get_animation(clip).length * frac, true)
				for i in settle:
					await process_frame
			root.get_texture().get_image().save_png(out.path_join("%s_%d.png" % [clip, int(frac * 10)]))
			if from_clip != "":
				break
	print("CLIPS_OK")
	quit()
