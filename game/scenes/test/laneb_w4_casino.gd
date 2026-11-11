extends SceneTree
## P9 W4 item 62: into the Spectra Palace the way the owner goes (enter_palace(), its fade and
## walk), frames on arrival and after a few strides, with her feet against the floor measured.
##   -s res://scenes/test/laneb_w4_casino.gd -- --out=<dir>
const Boot := preload("res://scenes/test/laneb_boot.gd")
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _report(ranch: Node, tag: String) -> void:
	var player: Node3D = ranch.get("player")
	var space := player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP * 0.5,
		player.global_position + Vector3.DOWN * 3.0)
	q.exclude = [(player as CollisionObject3D).get_rid()]
	var hit := space.intersect_ray(q)
	var vis: Node3D = player.get_node(^"Visuals")
	var lowest := INF
	for mi: MeshInstance3D in vis.find_children("*", "MeshInstance3D", true, false):
		if mi.is_visible_in_tree() and mi.mesh != null:
			var box: AABB = mi.global_transform * mi.get_aabb()
			lowest = minf(lowest, box.position.y)
	var cam: Camera3D = player.get_node(^"CameraPivot/CameraRig").call("get_camera")
	print("CASINO %s body_y=%.3f floor_y=%s mesh_low=%.3f cam_y=%.3f cam_dist=%.2f vis_scale=%s" % [tag,
		player.global_position.y, str(hit.get("position", Vector3.INF).y) if not hit.is_empty() else "none",
		lowest, cam.global_position.y, cam.global_position.distance_to(player.global_position), vis.scale])


func _run() -> void:
	var ranch: Node = await Boot.boot(self)
	var gs: Object = ranch.get("_game_state")
	gs.get("story").call("set_flag", "palace_open")
	print("ENTER ", ranch.call("enter_palace", false))
	for i in 150:
		await process_frame
	_report(ranch, "arrive")
	await Boot.shot(self, out.path_join("casino_arrive.png"), 5)
	Input.action_press(&"move_forward")
	for i in 70:
		await process_frame
	Input.action_release(&"move_forward")
	for i in 30:
		await process_frame
	_report(ranch, "walked")
	await Boot.shot(self, out.path_join("casino_walk.png"), 5)
	# The mouse pushed up: she looks up at the hall (pitch to its +30 deg limit).
	var rig: Node = ranch.get("player").get_node(^"CameraPivot/CameraRig")
	rig.call("add_look_delta", 0.0, deg_to_rad(-60.0))
	for i in 30:
		await process_frame
	_report(ranch, "look_up")
	await Boot.shot(self, out.path_join("casino_look_up.png"), 5)
	print("CASINO_OK")
	quit()
