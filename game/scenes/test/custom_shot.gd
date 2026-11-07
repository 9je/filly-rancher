extends SceneTree
## PS7 item 6: one pony per option, painted through PonyPaint, from the side and the front.
const PonyVisualsScript := preload("res://actors/pony/pony_visuals.gd")
const PonyPaintScript := preload("res://systems/pony_paint.gd")
const PonyLookScript := preload("res://systems/pony_look.gd")
const StockPaletteScript := preload("res://systems/stock_palette.gd")
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	root.get_window().size = Vector2i(900, 900)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.78, 0.86, 0.95)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 1, 1)
	e.ambient_light_energy = 0.55
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 50, 0)
	root.add_child(sun)
	var reg := preload("res://systems/pony_registry.gd").new()
	reg.load_all("res://data/ponies")
	var cam := Camera3D.new()
	cam.fov = 30.0
	root.add_child(cam)
	var cases := [["socks", 1, 0], ["blaze", 2, 0], ["star", 3, 0], ["dapples", 4, 0], ["almond", 0, 1], ["sleepy", 0, 2], ["plain", 0, 0]]
	for c in cases:
		var body: Node3D = PonyVisualsScript.build(reg.by_id(StockPaletteScript.IDS[0]), "")
		root.add_child(body)
		var look := PonyLookScript.new()
		look.coat = Color(0.55, 0.36, 0.24)
		look.mane = Color(0.15, 0.12, 0.14)
		look.marking = int(c[1])
		look.eye_shape = int(c[2])
		look.race = &"earth"
		PonyPaintScript.apply(body, look)
		var anim := body.get_node_or_null(PonyVisualsScript.ANIMATION_PLAYER_PATH) as AnimationPlayer
		if anim != null and anim.has_animation(&"idle"):
			anim.play(&"idle")
		for view in [["side", Vector3(4.2, 1.2, -0.3), Vector3(0, 0.95, -0.3)], ["front", Vector3(0.0, 1.5, -4.0), Vector3(0, 1.3, -0.6)], ["face", Vector3(0.4, 1.55, -2.4), Vector3(0, 1.5, -0.8)]]:
			cam.global_position = view[1]
			cam.look_at(view[2])
			cam.make_current()
			for k in 8:
				await process_frame
			root.get_texture().get_image().save_png(out.path_join("%s_%s.png" % [c[0], view[0]]))
		body.queue_free()
		await process_frame
	print("CUSTOM_SHOT_OK")
	quit(0)
