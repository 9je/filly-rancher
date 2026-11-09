extends SceneTree
## The creator's stage alone, in the creator's own environment (a check on its colours).
##   xvfb-run ... godot --path game -s res://scenes/test/stage_probe.gd -- --out=/abs/file.png
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	_run.call_deferred()


func _run() -> void:
	root.get_window().size = Vector2i(480, 640)
	var screen: Node = load("res://ui/creation_screen.tscn").instantiate()
	var vp: SubViewport = screen.get_node("Layout/Stage/Viewport/SubViewport")
	var world := Node3D.new()
	root.add_child(world)
	for n: String in ["WorldEnvironment", "DirectionalLight3D", "FillLight", "Camera3D"]:
		var c := vp.get_node(n)
		vp.remove_child(c)
		c.owner = null
		world.add_child(c)
	var stage: Node3D = (load("res://assets/models/creator_stage.glb") as PackedScene).instantiate()
	world.add_child(stage)
	ToonStyler.style(stage, &"prop", {}, load("res://ui/creation_screen.gd").STAGE_LIFT)
	if "--paint" in OS.get_cmdline_user_args():
		var cols := {"m_leaf": Color.RED, "m_leaf_dark": Color.BLUE, "m_white": Color.BLACK}
		for mi: MeshInstance3D in stage.find_children("*", "MeshInstance3D", true, false):
			for sidx in mi.mesh.get_surface_count():
				var m := mi.get_active_material(sidx) as ShaderMaterial
				if m != null and cols.has(m.resource_name):
					var c := m.duplicate() as ShaderMaterial
					c.set_shader_parameter(&"albedo", cols[m.resource_name])
					mi.set_surface_override_material(sidx, c)
	var pony: Node3D = PonyVisuals.build(load("res://data/ponies/fluttershy.tres"))
	world.add_child(pony)
	(world.get_node("Camera3D") as Camera3D).current = true
	var env: Environment = (world.get_node("WorldEnvironment") as WorldEnvironment).environment
	if "--noreflect" in OS.get_cmdline_user_args():
		env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	if "--nolight" in OS.get_cmdline_user_args():
		(world.get_node("DirectionalLight3D") as Light3D).light_energy = 0.0
		(world.get_node("FillLight") as Light3D).light_energy = 0.0
	if "--noambient" in OS.get_cmdline_user_args():
		env.ambient_light_energy = 0.0
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	for mi: MeshInstance3D in stage.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s)
			if m is ShaderMaterial and m.resource_name == "m_leaf":
				for u: Dictionary in (m as ShaderMaterial).shader.get_shader_uniform_list():
					print("U ", u.name, " = ", m.get_shader_parameter(u.name))
				print("NEXT ", m.next_pass, " shader ", (m as ShaderMaterial).shader.resource_path)
	print("STAGE_PROBE_OK")
	quit(0)
