extends SceneTree
## P9 W4 items 72, 73: a sighting fired from the plaza with the Flower Bushes bought (so
## Fluttershy is one who could come), the cinematic shot every 0.4 s; the toast and caption
## say what drew her.
##   -s res://scenes/test/laneb_w4_sighting.gd -- --out=<dir>
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
	var gs: Object = ranch.get("_game_state")
	var story: Object = gs.get("story")
	Decor.add(story, &"flower_bushes")
	Boot.stand(ranch, Vector3(-4.0, 0.2, -2.0), Vector3(8.0, 0.2, -6.0))
	for i in 20:
		await process_frame
	var h: Node = ranch.get("happenings")
	var ok: bool = h.call("_sighting")
	var who: Node3D = h.get("sighting")
	if who == null:
		print("SIGHTING_OK no guest")
		quit()
		return
	# Behind the Market from the plaza: the case the straight flight went through a building.
	var terrain: Node = ranch.get("terrain")
	var at := Vector3(32.0, 0.0, -3.0)
	at.y = float(terrain.call("height_at", at.x, at.z)) + 0.3
	who.global_position = at
	var player: Node3D = ranch.get("player")
	var old_eye := player.global_position + Vector3.UP * 3.0 + (player.global_position - at).normalized() * 3.0
	var old_near := old_eye.lerp(at, 0.35) + Vector3.UP
	var space := player.get_world_3d().direct_space_state
	print("OLD legs blocked: ", h.call("_blocked", space, player.global_position + Vector3.UP * 1.6, old_eye),
		" ", h.call("_blocked", space, old_eye, old_near), " view ", h.call("_blocked", space, old_near, at + Vector3.UP))
	h.call("film_sighting", load("res://data/ponies/fluttershy.tres"), at, "flower bushes")
	print("SIGHT ok=", ok, " who=", who.name if who != null else "none", " at=", who.global_position if who != null else Vector3.ZERO)
	for k in 9:
		await Boot.shot(self, out.path_join("sight_%02d.png" % k), 24)
		var cam := root.get_viewport().get_camera_3d()
		print("CAM ", k, " ", cam.global_position)
	print("SIGHTING_OK")
	quit()
