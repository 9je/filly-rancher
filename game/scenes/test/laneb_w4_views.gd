extends SceneTree
## P9 W4: gameplay-camera frames of the real ranch (fixture save, play.sh's load path, the
## player's own Settings: High), the player stood at a spot and the camera swung behind her.
##   -s res://scenes/test/laneb_w4_views.gd -- --out=<dir> [--size=2560x1440]
##      --shot=name,px,pz,tx,tz[,zoom[,pitch[,ty]]] ...   (zoom: rig distance, pitch: degrees)
##      a shot named *_beam holds the beam (right mouse) through it
##      [--walk=secs]  hold move_forward that long before each shot (her real stride)
## The ranch's own --phase=/--weather= pin the sky.
const Boot := preload("res://scenes/test/laneb_boot.gd")
var out := ""
var shots: Array = []
var size := Vector2i(1600, 900)
var walk := 0.0
var atlas := 0
var softq := -1
var blur := -1.0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--shot="):
			shots.append(a.substr(7).split(","))
		elif a.begins_with("--size="):
			var p := a.substr(7).split("x")
			size = Vector2i(int(p[0]), int(p[1]))
		elif a.begins_with("--atlas="):
			atlas = int(a.substr(8))
		elif a.begins_with("--softq="):
			softq = int(a.substr(8))
		elif a.begins_with("--blur="):
			blur = float(a.substr(7))
		elif a.begins_with("--walk="):
			walk = float(a.substr(7))
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	var ranch: Node = await Boot.boot(self, Boot.FIXTURE, size)
	var terrain: Node = ranch.get("terrain")
	var player: Node3D = ranch.get("player")
	var rig: Node = player.get_node_or_null(^"CameraPivot/CameraRig")
	if atlas > 0:
		RenderingServer.directional_shadow_atlas_set_size(atlas, true)
	if softq >= 0:
		RenderingServer.directional_soft_shadow_filter_set_quality(softq)
	if blur >= 0.0:
		(ranch.get_node(^"Sun") as DirectionalLight3D).shadow_blur = blur
	print("VIEWPORT msaa=", root.msaa_3d, " scale=", root.scaling_3d_scale, " size=", root.get_visible_rect().size)
	for s in shots:
		var at := Vector3(float(s[1]), 0.0, float(s[2]))
		at.y = float(terrain.call("height_at", at.x, at.z)) + 0.2
		var tgt := Vector3(float(s[3]), at.y, float(s[4]))
		if s.size() > 7:
			tgt.y = float(s[7])
		Boot.stand(ranch, at, tgt)
		if s.size() > 5 and rig != null:
			rig.call("add_zoom_delta", float(s[5]) - float(rig.call("get_zoom_distance")))
		if s.size() > 6 and rig != null:
			rig.call("add_look_delta", 0.0, deg_to_rad(float(rig.call("get_look_pitch_degrees")) - float(s[6])))
		if walk > 0.0:
			Input.action_press(&"move_forward")
			for i in int(walk * 60.0):
				await process_frame
			Input.action_release(&"move_forward")
		var beam := String(s[0]).ends_with("_beam")
		var mb: Node = player.call("get_magic_beam")
		if beam:
			Input.action_press(&"beam")
			mb.call("set_recalled", false)
			mb.call("grab")
		await Boot.shot(self, out.path_join(String(s[0]) + ".png"), 45)
		if beam:
			print("BEAM active=", mb.call("is_active"), " recalled=", mb.get("_recalled"), " scoop=", player.get("_scoop"), " out=", player.get("_scoop_out"))
		if beam:
			Input.action_release(&"beam")
			mb.set("_beaming", false)
			for i in 30:
				await process_frame
		print("AT ", s[0], " ", player.global_position)
	print("VIEWS_OK")
	quit()
