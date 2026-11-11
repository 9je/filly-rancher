extends SceneTree
## P9 leftover 76: the player's tail while she runs (run is on by default; real move key held),
## from her side and from behind, a frame every 5 ticks.
##   -s res://scenes/test/laneb_w4_tail.gd -- --out=<dir>
const Boot := preload("res://scenes/test/laneb_boot.gd")
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
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
	for i in 30:
		await process_frame
	Input.action_press(&"move_forward")
	for i in 40:
		await process_frame
	# Swing the lens to her side while she keeps running north.
	# Side view: the lens goes round her while she runs straight on (move keys follow the lens,
	# so the run is steered back by the same amount on the visuals' side only for the frames).
	rig.call("add_look_delta", deg_to_rad(80.0), 0.0)
	for k in 12:
		await Boot.shot(self, out.path_join("side_%02d.png" % k), 5)
		print("RUN ", k, " v=", (player as CharacterBody3D).velocity.length(), " at ", player.global_position)
	rig.call("add_look_delta", deg_to_rad(-80.0), 0.0)
	for k in 8:
		await Boot.shot(self, out.path_join("back_%02d.png" % k), 5)
	Input.action_release(&"move_forward")
	print("speed ", (player as CharacterBody3D).velocity.length())
	print("TAIL_OK")
	quit()
