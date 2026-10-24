extends SceneTree
## Every canon pony's face, from the front (found from her own head and hip bones), one image
## each, for checking eyes across the whole roster:
##   tools/bin/godot --path game -s res://scenes/test/roster_eyes.gd -- --out=/abs/dir
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "/tmp"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	var sun := DirectionalLight3D.new()
	root.add_child(sun)
	sun.rotation_degrees = Vector3(-40, 160, 0)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.6, 0.75, 0.9)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.75)
	root.add_child(env)
	var cam := Camera3D.new()
	cam.fov = 30.0
	root.add_child(cam)
	cam.make_current()
	var scene: PackedScene = load("res://actors/pony/pony.tscn")
	var ids: Array = []
	for f in DirAccess.get_files_at("res://data/ponies"):
		if f.ends_with(".tres"):
			ids.append(f.get_basename())
	ids.sort()
	for id: String in ids:
		var p: Node3D = scene.instantiate()
		root.add_child(p)
		p.call("setup", load("res://data/ponies/%s.tres" % id))
		p.set_physics_process(false)
		for i in 40:
			await process_frame
		var sks := p.find_children("*", "Skeleton3D", true, false)
		if sks.is_empty():
			p.free()
			continue
		var sk: Skeleton3D = sks[0]
		var head := -1
		var hip := -1
		for j in sk.get_bone_count():
			var n := sk.get_bone_name(j).to_lower()
			if head < 0 and "head" in n:
				head = j
			if hip < 0 and ("hip" in n or "pelvis" in n):
				hip = j
		var hp := sk.global_transform * sk.get_bone_global_pose(head).origin
		var pp := sk.global_transform * sk.get_bone_global_pose(maxi(hip, 0)).origin
		var fwd := hp - pp
		fwd.y = 0.0
		fwd = fwd.normalized()
		cam.global_position = hp + fwd * 1.6 + Vector3(0, 0.05, 0)
		cam.look_at(hp + Vector3(0, -0.02, 0))
		for i in 4:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, id])
		p.free()
		await process_frame
	print("ROSTER_EYES_OK %d" % ids.size())
	quit(0)
