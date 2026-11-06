extends SceneTree
## A real Pony actor beside a stand-in player, filmed (PT1: Twilight twisting in play).
##   xvfb-run ... godot --display-driver x11 --path game -s res://scenes/test/actor_watch.gd -- --out=/abs/dir --pony=twilight [--near=3] [--seconds=12] [--penned]
const PonyScene := preload("res://actors/pony/pony.tscn")
var out := ""
var pony_id := "twilight"
var near := 3.0
var seconds := 12.0
var penned := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--pony="):
			pony_id = a.substr(7)
		elif a.begins_with("--near="):
			near = float(a.substr(7))
		elif a.begins_with("--seconds="):
			seconds = float(a.substr(10))
		elif a == "--penned":
			penned = true
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
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	shape.shape = box
	shape.position.y = -0.5
	floor_body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	mesh.mesh = pm
	floor_body.add_child(mesh)
	world.add_child(floor_body)
	HoofPlanter.default_ground = func(_x: float, _z: float) -> float: return 0.0
	var player := CharacterBody3D.new()
	player.add_to_group(&"player")
	var ps := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	ps.shape = cap
	player.add_child(ps)
	player.position = Vector3(near, 0.9, 0)
	world.add_child(player)
	var pony: Node3D = PonyScene.instantiate()
	pony.call("setup", load("res://data/ponies/%s.tres" % pony_id))
	pony.position = Vector3.ZERO
	if penned:
		pony.add_to_group(&"penned")
	world.add_child(pony)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.make_current()
	var frames := int(seconds * 60.0)
	var shot := 0
	for f in frames:
		var p: Vector3 = pony.global_position
		cam.global_position = p + Vector3(0.6, 1.4, 3.2)
		cam.look_at(p + Vector3(0, 0.5, 0), Vector3.UP)
		await process_frame
		if f % 20 == 0:
			root.get_texture().get_image().save_png(out.path_join("f_%03d.png" % shot))
			shot += 1
	print("WATCH_OK")
	quit()
