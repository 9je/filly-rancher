extends SceneTree
## P9 item 61, round 3: hunt the distant flicker. The player walks (real move key) toward the
## homestead wagon by the pink shed from several distances; every drawn frame is cropped round
## the wagon at 1:1 and saved, and the mean frame-to-frame change inside the crop is logged,
## so a flicker (a pixel that toggles while the rest of the view slides smoothly) shows as a
## spike or a sawtooth.
##   -s res://scenes/test/laneb_w5_flicker.gd -- --out=<dir> [--w=2560 --h=1440] [--dists=75,55,38]
##      [--dir=x,z] (the bearing FROM the wagon; round 4: 1,0 is the owner's [18], due east)
const Boot := preload("res://scenes/test/laneb_boot.gd")
var out := ""
var size := Vector2i(2560, 1440)
var dists: Array = [75.0, 55.0, 38.0]
var from_dir := Vector3(1.0, 0.0, 0.55).normalized()
## --stand: hold still (no move key), so any frame-to-frame change round the wagon is flicker.
var stand := false
## --pan=deg: stand and turn the camera this many degrees a frame (a hand on the mouse), crop
## fixed on screen; --noshadow / --nolod switch the sun's shadow / mesh LOD off to isolate a cause.
var pan := 0.0
## --glide=m: stand, then slide her this far toward the wagon each frame (no stride, no bob).
var glide := 0.0
var noshadow := false
var nolod := false
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
		elif a.begins_with("--pan="):
			pan = float(a.substr(6))
			stand = true
		elif a.begins_with("--glide="):
			glide = float(a.substr(8))
			stand = true
		elif a == "--noshadow":
			noshadow = true
		elif a == "--nolod":
			nolod = true
		elif a == "--stand":
			stand = true
		elif a.begins_with("--dir="):
			var xz := a.substr(6).split(",")
			from_dir = Vector3(float(xz[0]), 0.0, float(xz[1])).normalized()
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	var ranch: Node = await Boot.boot(self, Boot.FIXTURE, size)
	var terrain: Node = ranch.get("terrain")
	var player: Node3D = ranch.get("player")
	var wagon := WAGON
	if noshadow:
		(ranch.get_node(^"Sun") as DirectionalLight3D).shadow_enabled = false
	if nolod:
		get_root().mesh_lod_threshold = 0.0
	var rig: Node = player.get_node(^"CameraPivot/CameraRig")
	var fixed := Rect2i()
	wagon.y = float(terrain.call("height_at", wagon.x, wagon.z))
	for d: float in dists:
		var at := wagon + from_dir * d
		at.y = float(terrain.call("height_at", at.x, at.z)) + 0.2
		Boot.stand(ranch, at, wagon)
		for i in 40:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join("full_d%d.png" % int(d)))
		if not stand:
			Input.action_press(&"move_forward")
		# Walk (Shift toggles the run off: the owner walked here).
		var prev: Image = null
		var diffs := PackedFloat32Array()
		var moving := pan > 0.0 or glide > 0.0
		for f in (60 if moving else (150 if stand else 48)):
			if pan > 0.0:
				rig.call("add_look_delta", deg_to_rad(pan), 0.0)
			if glide > 0.0:
				var p := player.global_position - from_dir * glide
				p.y = float(terrain.call("height_at", p.x, p.z)) + 0.05
				player.global_position = p
			await process_frame
			await RenderingServer.frame_post_draw
			# The player's own lens (round 4: the viewport's "current" camera was not it, so
			# round 3's crops watched a tree crown, not the wagon).
			var cam: Camera3D = player.get_node(^"CameraPivot/CameraRig").call("get_camera")
			# unproject_position() answers in the window's canvas units (the stretch base), the
			# drawn texture is the full 2560x1440: scale across.
			var c := cam.unproject_position(wagon + Vector3.UP * 0.8) \
				* Vector2(size) / get_root().get_visible_rect().size
			if f == 0:
				print("CROP cam=", cam.get_path(), " current=", get_root().get_camera_3d().get_path(), " at=", c)
			var half := Vector2i(200, 130)
			var rect := Rect2i(Vector2i(c) - half, half * 2)
			rect = rect.intersection(Rect2i(Vector2i.ZERO, size))
			if moving:
				if f == 0:
					fixed = rect
				rect = fixed
			var img := root.get_texture().get_image().get_region(rect)
			img.convert(Image.FORMAT_RGB8)
			if not stand or moving or f % 5 == 0:
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
