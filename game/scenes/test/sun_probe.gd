extends SceneTree
## THE SUN, ALONE: ranch.tscn's sky, environment and sun, the camera aimed at the sun, with the
## light drawn into the sky (sun_sky.png) and kept out of it (sun_lightonly.png), and the
## painted sky dome over both (sun_dome.png). A check on the dotted ring round the sun.
##   xvfb-run ... godot --path game -s res://scenes/test/sun_probe.gd -- --out=/abs/dir
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	root.get_window().size = Vector2i(1280, 720)
	var ranch: Node3D = (load("res://world/ranch.tscn") as PackedScene).instantiate(
		PackedScene.GEN_EDIT_STATE_DISABLED)
	var world := Node3D.new()
	root.add_child(world)
	# Only the sky's own nodes: the environment and the sun, under a parent named like the ranch.
	for n: String in ["WorldEnvironment", "Sun"]:
		var node := ranch.get_node(n)
		ranch.remove_child(node)
		node.owner = null
		world.add_child(node)
	var sun := world.get_node("Sun") as DirectionalLight3D
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.position = Vector3(0, 2, 0)
	cam.fov = 30.0
	cam.look_at(cam.position + sun.global_basis.z, Vector3.UP)
	cam.current = true
	for k in 20:
		await process_frame
	await _shot("sun_sky")
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	for k in 20:
		await process_frame
	await _shot("sun_lightonly")
	var dome := MeshInstance3D.new()
	dome.set_script(load("res://world/sky_dome.gd"))
	dome.name = "SkyDome"
	world.add_child(dome)
	for k in 20:
		await process_frame
	await _shot("sun_dome")
	print("SUN_PROBE_OK")
	ranch.free()
	quit(0)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
