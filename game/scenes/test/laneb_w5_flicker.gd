extends SceneTree
## P9 item 61, round 3: hunt the distant flicker. The player walks (real move key) toward the
## homestead wagon by the pink shed from several distances; every drawn frame is cropped round
## the wagon at 1:1 and saved, and the mean frame-to-frame change inside the crop is logged,
## so a flicker (a pixel that toggles while the rest of the view slides smoothly) shows as a
## spike or a sawtooth.
##   -s res://scenes/test/laneb_w5_flicker.gd -- --out=<dir> [--w=2560 --h=1440] [--dists=75,55,38]
const Boot := preload("res://scenes/test/laneb_boot.gd")
var out := ""
var size := Vector2i(2560, 1440)
var dists: Array = [75.0, 55.0, 38.0]
const WAGON := Vector3(-30.5, 0.0, -22.0)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--w="):
			size.x = int(a.substr(4))
		elif a.begins_with("--h="):
			size.y = int(a.substr(4))
		elif a.begins_with("--dists="):
			dists = []
			for v in a.substr(8).split(","):
				dists.append(float(v))
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	var ranch: Node = await Boot.boot(self, Boot.FIXTURE, size)
	var terrain: Node = ranch.get("terrain")
	var player: Node3D = ranch.get("player")
	var wagon := WAGON
	wagon.y = float(terrain.call("height_at", wagon.x, wagon.z))
	# The owner's [18] looked at the wagon from the south-east, across the town path.
	var from_dir := Vector3(1.0, 0.0, 0.55).normalized()
	for d: float in dists:
		var at := wagon + from_dir * d
		at.y = float(terrain.call("height_at", at.x, at.z)) + 0.2
		Boot.stand(ranch, at, wagon)
		for i in 40:
			await process_frame
		Input.action_press(&"move_forward")
		# Walk (Shift toggles the run off: the owner walked here).
		var prev: Image = null
		var diffs := PackedFloat32Array()
		for f in 48:
			await process_frame
			await RenderingServer.frame_post_draw
			var cam := get_root().get_camera_3d()
			var c := cam.unproject_position(wagon + Vector3.UP * 0.8)
			var half := Vector2i(70, 50)
			var rect := Rect2i(Vector2i(c) - half, half * 2)
			rect = rect.intersection(Rect2i(Vector2i.ZERO, size))
			var img := root.get_texture().get_image().get_region(rect)
			img.convert(Image.FORMAT_RGB8)
			if f % 2 == 0 and f < 32:
				img.save_png(out.path_join("d%d_%02d.png" % [int(d), f]))
			if prev != null and prev.get_size() == img.get_size():
				diffs.append(_mean_diff(prev, img))
			prev = img
		Input.action_release(&"move_forward")
		var line := ""
		for v in diffs:
			line += "%.1f " % v
		print("DIST ", d, " diffs: ", line)
	print("LANEB_FLICKER_OK")
	quit(0)


func _mean_diff(a: Image, b: Image) -> float:
	var total := 0.0
	var n := 0
	for y in range(0, a.get_height(), 2):
		for x in range(0, a.get_width(), 2):
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			total += absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b)
			n += 1
	return total / maxf(1.0, float(n)) * 255.0 / 3.0
