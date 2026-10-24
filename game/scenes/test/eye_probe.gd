extends "res://scenes/test/trailer.gd"
## A close look at a canon pony's eyes (with and without PonyLod), for the eye bug.
##   tools/bin/godot --path game -s res://scenes/test/eye_probe.gd -- --pony=fluttershy [--nolod] --out=/abs.png


func _run() -> void:
	var pony := "fluttershy"
	var out := "/tmp/eye.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pony="):
			pony = a.substr(7)
		elif a.begins_with("--out="):
			out = a.substr(6)
		elif a == "--nolod":
			PonyLod.enabled = false
	await _boot_ranch()
	var moving := "--moving" in OS.get_cmdline_user_args()
	var p := _canon(pony, _g(30.0, 40.0), 0.0 if moving else 999.0, PI)
	if not moving:
		p.set_physics_process(false)
	else:
		_player().global_position = _g(30.0, 44.5, 0.2)
	await _frames(40)
	for other in ranch.get("spawner").call("get_spawned"):
		if other != p and is_instance_valid(other):
			(other as Node3D).visible = false
	var people: Node = ranch.get("people")
	if people != null:
		for n in people.find_children("*", "Node3D", false, false):
			(n as Node3D).visible = false
	var sk: Skeleton3D = p.find_children("*", "Skeleton3D", true, false)[0]
	var hb := sk.find_bone("DEF_Head")
	var head := sk.global_transform * sk.get_bone_global_pose(hb).origin
	print("EYE_POS pony=%s head=%s fwd=%s" % [p.global_position, head, (p.get_node("Visuals") as Node3D).global_basis.z])
	for mi: MeshInstance3D in p.find_children("*", "MeshInstance3D", true, false):
		if "Eye" in String(mi.name) or "Iris" in String(mi.name):
			var aabb := mi.global_transform * mi.get_aabb()
			print("EYE_POS %s at %s parent=%s(%s) vis=%s" % [mi.name, aabb.get_center(), mi.get_parent().name, mi.get_parent().get_class(), mi.is_visible_in_tree()])
	var c := _free_cam()
	c.fov = 30.0
	for k in 4:
		var at := p.global_position
		var fwd := (p.get_node("Visuals") as Node3D).global_basis.z
		fwd.y = 0.0
		c.global_position = at + fwd.normalized() * 2.6 + Vector3(0, 1.45, 0)
		c.look_at(at + Vector3(0, 1.2, 0))
		await _frames(2)
		root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_%d.png" % k))
		await _frames(25)
	print("EYE_OK ", out)
	quit(0)
