extends SceneTree
## CHARACTERS UNDER THE RANCH'S OWN NOON, WITHOUT BOOTING THE RANCH (a ranch boot is most of an
## hour on the software renderer; this is minutes). Four canon ponies, toon-styled the way
## pony.gd styles a live one, on a patch of grass under ranch.tscn's sun, fill and exposure.
## Writes chars_line.png (the four side by side, three-quarter on) and chars_face.png (a close
## head-and-shoulders of the first) into --out.
##   xvfb-run ... godot --path game -s res://scenes/test/char_probe.gd -- --out=/abs/dir
const ToonStylerScript := preload("res://systems/toon_styler.gd")
const SkyRigScript := preload("res://world/sky_rig.gd")
const PONIES := ["fluttershy", "derpyhooves", "rainbowdash", "twilight"]
var out := ""
## --phase=0..3 (dawn, day, dusk, night): the rig's light and fill for that hour, a low sun at
## dawn and dusk.
var phase := 1


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--phase="):
			phase = int(a.substr(8))
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	root.get_window().size = Vector2i(1600, 900)
	# As the game's settings leave it (systems/settings.gd, high quality).
	root.msaa_3d = Viewport.MSAA_4X
	var world := Node3D.new()
	root.add_child(world)
	# ranch.tscn's Environment and Sun at DAY, as the sky rig leaves them.
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = SkyRigScript.sky_top(phase, WorldState.Weather.CLEAR)
	sky_mat.sky_horizon_color = SkyRigScript.sky_horizon(phase, WorldState.Weather.CLEAR)
	sky_mat.ground_horizon_color = SkyRigScript.ground_horizon(phase, WorldState.Weather.CLEAR)
	sky_mat.ground_bottom_color = sky_mat.ground_horizon_color.darkened(0.4)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = SkyRigScript.AMBIENT_SKY_CONTRIBUTION
	env.ambient_light_color = Color(0.729412, 0.803922, 0.878431)
	env.ambient_light_energy = SkyRigScript.PHASE_AMBIENT_ENERGY[phase]
	env.ambient_light_color = SkyRigScript.PHASE_AMBIENT_COLORS[phase]
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 4.5
	env.tonemap_exposure = 0.8
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_hdr_threshold = 1.8
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.transform = Transform3D(Basis(Vector3(0.7071068, 0, -0.7071068), Vector3(-0.3535534, 0.8660254, -0.3535534),
		Vector3(0.6123724, 0.5, 0.6123724)), Vector3(0, 22, 0))
	sun.light_color = SkyRigScript.PHASE_LIGHT_COLORS[phase]
	sun.light_energy = SkyRigScript.PHASE_LIGHT_ENERGY[phase]
	if phase == 0 or phase == 2:
		sun.rotation = Vector3(deg_to_rad(-14.0), deg_to_rad(60.0 if phase == 2 else -60.0), 0.0)
	sun.shadow_enabled = true
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	world.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.38, 0.6, 0.27)
	gm.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	gm.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	pm.material = gm
	ground.mesh = pm
	world.add_child(ground)
	var bodies: Array[Node3D] = []
	for i in PONIES.size():
		var holder := Node3D.new()
		world.add_child(holder)
		var body := PonyVisuals.build(load("res://data/ponies/%s.tres" % PONIES[i]))
		holder.add_child(body)
		ToonStylerScript.style(body, &"pony", {})
		if "--mats" in OS.get_cmdline_user_args() and i == 0:
			for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
				for si in mi.mesh.get_surface_count():
					var m := mi.get_active_material(si)
					var sh := (m as ShaderMaterial).shader.resource_path if m is ShaderMaterial else m.get_class() if m != null else "null"
					print("MAT %s/%d %s" % [mi.name, si, sh])
		holder.position = Vector3((float(i) - 1.5) * 1.7, 0, 0)
		# Three-quarter on to the lens (a holder's -Z is her tail).
		holder.rotation.y = deg_to_rad(200.0)
		bodies.append(holder)
	if "--rim" in OS.get_cmdline_user_args():
		# The valley's rim hills from inside the valley: chars_rim.png.
		var vf := Node3D.new()
		vf.set_script(load("res://world/valley_frame.gd"))
		world.add_child(vf)
		var rc := Camera3D.new()
		world.add_child(rc)
		rc.fov = 60.0
		rc.far = 1000.0
		rc.global_position = Vector3(20, 6, 40)
		rc.look_at(Vector3(60, 8, 120))
		rc.current = true
		for k in 20:
			await process_frame
		await _shot("chars_rim")
		rc.current = false
	if "--plot" in OS.get_cmdline_user_args():
		# A free plot as the pen yard has it: chars_plot.png.
		var slot: Node3D = load("res://world/plot_slot.gd").new()
		world.add_child(slot)
		slot.global_position = Vector3(0, 0, -2.0)
		slot.call("set_marker_focus", 0.0)
		slot.call("set_ghost", 1)
		var sc := Camera3D.new()
		world.add_child(sc)
		sc.fov = 60.0
		sc.global_position = Vector3(5.5, 3.2, 6.5)
		sc.look_at(Vector3(0, 0.3, -2.0))
		sc.current = true
		for k in 20:
			await process_frame
		await _shot("chars_plot")
		sc.current = false
		slot.queue_free()
	if "--player" in OS.get_cmdline_user_args():
		# The player as she is built in the ranch (her Scoop and all), from behind and to the
		# side, the way the game's camera sees her: chars_player.png.
		var player: Node3D = (load("res://actors/player/player.tscn") as PackedScene).instantiate()
		var floor_body := StaticBody3D.new()
		var floor_shape := CollisionShape3D.new()
		floor_shape.shape = WorldBoundaryShape3D.new()
		floor_body.add_child(floor_shape)
		world.add_child(floor_body)
		world.add_child(player)
		player.global_position = Vector3(0, 0, 3.0)
		for k in 30:
			await process_frame
		# Held still where she stands: the probe is about how she looks, not how she moves.
		player.process_mode = Node.PROCESS_MODE_DISABLED
		var pc := Camera3D.new()
		world.add_child(pc)
		pc.fov = 60.0
		pc.global_position = player.global_position + Vector3(1.2, 1.9, 3.4)
		pc.look_at(player.global_position + Vector3(0, 1.1, 0))
		pc.current = true
		for k in 10:
			await process_frame
		await _shot("chars_player")
		pc.current = false
		player.queue_free()
	if "--mark" in OS.get_cmdline_user_args():
		# A stamped mark on each of the four, side on: chars_mark.png (Fable round 6, #2).
		var mark: Image = MarkStamps.build(MarkStamps.Stamp.STAR, Color(0.95, 0.4, 0.7))
		for b in bodies:
			CutieMark.apply(b.get_child(0), mark)
			b.rotation.y = deg_to_rad(90.0)
		var mc := Camera3D.new()
		world.add_child(mc)
		mc.fov = 40.0
		mc.position = Vector3(0.0, 1.3, 7.0)
		mc.look_at(Vector3(0, 0.9, 0))
		mc.current = true
		for k in 10:
			await process_frame
		await _shot("chars_mark")
		mc.current = false
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.fov = 40.0
	cam.position = Vector3(0.0, 1.5, 7.2)
	cam.look_at(Vector3(0, 0.85, 0))
	cam.current = true
	for k in 40:
		await process_frame
	await _shot("chars_line_p%d" % phase if phase != 1 else "chars_line")
	cam.fov = 28.0
	var head := bodies[0].global_position + Vector3(0, 1.15, 0)
	cam.position = head + Vector3(0.4, 0.15, 2.4)
	cam.look_at(head)
	for k in 10:
		await process_frame
	await _shot("chars_face")
	print("CHAR_PROBE_OK")
	quit(0)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
