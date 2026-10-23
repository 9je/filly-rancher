extends SceneTree
## LOD check (actors/pony/pony_lod.gd): one pony rendered at 6, 10, 14, 20 and 30 m with a
## narrow lens so her face fills the frame each time; the pupils must survive at every range.
const PonyScene := preload("res://actors/pony/pony.tscn")
const GeneratorScript := preload("res://systems/pony_generator.gd")

func _initialize() -> void:
	_go.call_deferred()

func _go() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "/tmp/lod"
	DirAccess.make_dir_recursive_absolute(out)
	root.get_window().size = Vector2i(900, 900)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.6, 0.75, 0.9)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.8)
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	world.add_child(sun)
	var p: Node3D = PonyScene.instantiate()
	world.add_child(p)
	p.set_stock(GeneratorScript.generate(4242).to_dict())
	p.setup(load("res://data/hidden/stock_shy.tres"))
	p.set_physics_process(false)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.make_current()
	for d in [6.0, 10.0, 14.0, 20.0, 30.0]:
		cam.fov = 2.0 * rad_to_deg(atan(0.45 / d))
		cam.global_position = Vector3(0.0, 1.5, -d)
		cam.look_at(Vector3(0, 1.45, -0.55))
		for i in 20:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.path_join("lod_%02dm.png" % int(d)))
	print("LOD_PROBE_OK")
	quit()
