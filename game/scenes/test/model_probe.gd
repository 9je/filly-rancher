extends SceneTree
## Render one model (toon-styled like the game) from four angles: model_probe.gd -- <res path> <out dir>
func _initialize() -> void:
	_go.call_deferred()

func _go() -> void:
	var args := OS.get_cmdline_user_args()
	var path: String = args[0]
	var out: String = args[1]
	DirAccess.make_dir_recursive_absolute(out)
	root.get_window().size = Vector2i(900, 900)
	var world := Node3D.new()
	root.add_child(world)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.8, 0.95)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.5, 0.55)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	sun.shadow_enabled = true
	sun.light_energy = 1.0
	world.add_child(sun)
	var m: Node3D = (load(path) as PackedScene).instantiate()
	world.add_child(m)
	ToonStyler.style(m, StringName(args[2]) if args.size() > 2 else &"pony")
	var aabb := AABB()
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		aabb = aabb.merge((mi as MeshInstance3D).get_aabb())
	var c := aabb.get_center()
	var r := aabb.size.length()
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.make_current()
	var i := 0
	for yaw in [0.0, 35.0, 90.0, 180.0]:
		var d := Vector3(sin(deg_to_rad(yaw)), 0.25, cos(deg_to_rad(yaw))).normalized() * r * 1.2
		cam.global_position = c + d
		cam.look_at(c)
		for k in 10:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.path_join("view_%d.png" % i))
		i += 1
	print("MODEL_PROBE_OK")
	quit()
