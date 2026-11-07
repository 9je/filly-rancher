extends SceneTree
## Each building model at scale 1, orthographic from four sides, with a red line every 0.5 m
## and a thicker one every metre, so the door's height can be read off.
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	_run.call_deferred()


func _run() -> void:
	root.get_window().size = Vector2i(1200, 900)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.8, 0.9, 1.0)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 1, 1)
	e.ambient_light_energy = 1.0
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	root.add_child(sun)
	for f in ["pv_wide_b", "pv_general", "pv_bridged_b", "pv_tower_b", "saa_barn"]:
		var n: Node3D = (load("res://assets/converted/props/%s.glb" % f) as PackedScene).instantiate()
		root.add_child(n)
		var lines := Node3D.new()
		root.add_child(lines)
		for i in 30:
			var y := i * 0.5
			var bar := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(40, 0.03 if i % 2 == 1 else 0.07, 40)
			bar.mesh = box
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(1, 0, 0) if i % 2 == 0 else Color(1, 0.6, 0.6)
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color.a = 0.6
			bar.material_override = m
			bar.position = Vector3(0, y, 0)
			lines.add_child(bar)
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 16.0
		root.add_child(cam)
		for side in 4:
			var yaw := side * PI * 0.5
			var dir := Vector3(sin(yaw), 0, cos(yaw))
			cam.global_position = dir * 30.0 + Vector3(0, 6, 0)
			cam.look_at(Vector3(0, 6, 0))
			cam.make_current()
			for k in 4:
				await process_frame
			root.get_texture().get_image().save_png(out.path_join("%s_side%d.png" % [f, side]))
		cam.queue_free()
		lines.queue_free()
		n.queue_free()
		await process_frame
	quit(0)
