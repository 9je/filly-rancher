extends SceneTree
## Pre-review item 9 (2026-11-21): candidate end poses for the arrival flyover's first leg,
## each a still from a bare Camera3D at fov 50 looking at the plaza.
##   -s res://scenes/test/arrival_pose_probe.gd -- --out=<dir> --pose=name,x,y,z,lx,ly,lz ...
const Boot := preload("res://scenes/test/laneb_boot.gd")
var out := ""
var poses: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--pose="):
			poses.append(a.substr(7).split(","))
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	var ranch: Node = await Boot.boot(self, Boot.FIXTURE, Vector2i(1600, 900))
	var cam := Camera3D.new()
	cam.fov = 50.0
	ranch.add_child(cam)
	for p in poses:
		cam.global_position = Vector3(float(p[1]), float(p[2]), float(p[3]))
		cam.look_at(Vector3(float(p[4]), float(p[5]), float(p[6])))
		for i in 5:
			cam.make_current()
			await process_frame
		await Boot.shot(self, out.path_join(String(p[0]) + ".png"), 30)
	print("POSE_OK")
	quit()
