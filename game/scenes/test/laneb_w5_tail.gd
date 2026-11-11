extends SceneTree
## P9 item 76, round 3: the player's tail through a real run (move key held, run on by
## default), from a true side view (a camera riding beside her) and from the gameplay camera
## behind. --off disables the TailCarry modifier (the before).
##   -s res://scenes/test/laneb_w5_tail.gd -- --out=<dir> [--off]
const Boot := preload("res://scenes/test/laneb_boot.gd")
var out := ""
var off := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a == "--off":
			off = true
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	var ranch: Node = await Boot.boot(self)
	var player: Node3D = ranch.get("player")
	var terrain: Node = ranch.get("terrain")
	var at := Vector3(8.0, 0.0, -66.0)
	at.y = float(terrain.call("height_at", at.x, at.z)) + 0.2
	Boot.stand(ranch, at, at + Vector3(-30.0, 0.0, 0.0))
	var rig: Node = player.get_node(^"CameraPivot/CameraRig")
	rig.call("add_zoom_delta", 3.0 - float(rig.call("get_zoom_distance")))
	var tc := player.find_child("TailCarry", true, false) as SkeletonModifier3D
	print("TAILCARRY ", tc != null, " off=", off)
	if tc != null:
		var sk := tc.get_parent() as Skeleton3D
		print("SK basis ", sk.global_transform.basis, " fwd ", tc.get("_fwd"), " up ", tc.get("_up"))
		for it in tc.get("_chain"):
			print("CHAIN ", sk.get_bone_name(it[0]), " depth ", it[1])
		for b in sk.get_bone_count():
			if sk.get_bone_name(b).to_lower().contains("tail") or sk.get_bone_name(b).to_lower().contains("head") or sk.get_bone_name(b).to_lower().contains("hip") or sk.get_bone_name(b).to_lower().contains("pelvis"):
				print("BONE ", b, " ", sk.get_bone_name(b), " at ", sk.get_bone_global_rest(b).origin)
	if tc != null and off:
		tc.active = false
	for i in 30:
		await process_frame
	# Standing, from the side.
	# The side view renders in its own viewport on the same world, so the gameplay camera stays
	# current and the move key steers her exactly as the player's would.
	var vp := SubViewport.new()
	vp.size = Vector2i(1600, 900)
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var cam := Camera3D.new()
	cam.fov = 40.0
	vp.add_child(cam)
	cam.current = true
	_side(cam, player)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out.path_join("side_stand.png"))
	Input.action_press(&"move_forward")
	for k in 16:
		for i in 3:
			await process_frame
			_side(cam, player)
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(out.path_join("side_%02d.png" % k))
		print("RUN ", k, " v=%.2f" % (player as CharacterBody3D).velocity.length(),
			" carry=", tc.get("carry") if tc != null else -1.0)
	vp.queue_free()
	for k in 8:
		await Boot.shot(self, out.path_join("back_%02d.png" % k), 4)
	Input.action_release(&"move_forward")
	print("TAIL_OK")
	quit()


## The camera 4.2 m off her left side, level with her barrel, looking square at her.
func _side(cam: Camera3D, player: Node3D) -> void:
	var vis := player.get_node(^"Visuals") as Node3D
	var fwd := -vis.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var side := Vector3.UP.cross(fwd).normalized()
	var c := player.global_position + Vector3(0, 0.9, 0)
	cam.global_position = c + side * 4.2
	cam.look_at(c, Vector3.UP)
