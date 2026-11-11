extends SceneTree
## P9 item 53, round 3: a generated batch of Bloomed Drifters (marked), each penned the way
## the game pens one (Pen.add_pony builds the body), then stood still on open ground and shot
## from a true side view, left flank then right flank, close on the mark. One tile per flank.
##   -s res://scenes/test/laneb_w5_marks.gd -- --out=<dir> [--n=12] [--seed=5100]
const Boot := preload("res://scenes/test/laneb_boot.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const GeneratorScript := preload("res://systems/pony_generator.gd")
var out := ""
var count := 12
var seed0 := 5100


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--n="):
			count = int(a.substr(4))
		elif a.begins_with("--seed="):
			seed0 = int(a.substr(7))
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	var ranch: Node = await Boot.boot(self)
	var pens: Array = Boot.pens(ranch)
	var pen: Pen = pens[pens.size() - 1]
	var terrain: Node = ranch.get("terrain")
	var vp := SubViewport.new()
	vp.size = Vector2i(800, 600)
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	cam.current = true
	var spot := Vector3(8.0, 0.0, -66.0)
	var tiles: Array[Image] = []
	var done := 0
	var s := seed0
	while done < count:
		for inst in pen.ponies():
			pen.remove_pony(inst.uid)
		pen.capacity = 8
		var inst := PonyInstanceScript.create(&"stock_bold", 910000 + s)
		var look: PonyLook = GeneratorScript.generate(s, {"marked": true})
		inst.stock = look.to_dict()
		pen.add_pony(inst)
		s += 1
		var body := pen.body_for(inst.uid) as Pony
		if body == null:
			continue
		for i in 4:
			await process_frame
		body.set_physics_process(false)
		body.set_process(false)
		var at := spot
		at.y = float(terrain.call("height_at", at.x, at.z))
		body.global_position = at
		var vis := body.get_node(^"Visuals") as Node3D
		var sk := body.find_child("Skeleton3D", true, false) as Skeleton3D
		var rb := body.find_child("RumpBounce", true, false)
		for i in 3:
			await process_frame
		var rump: Vector3 = sk.global_transform * (rb.call("centre") as Vector3) if rb != null \
			else at + Vector3.UP * 0.9
		for d: Decal in CutieMark.decals_of(body):
			var model := d.get_parent()
			while model != null and not (model.get_parent() == vis):
				model = model.get_parent()
			var m3 := model as Node3D
			print("DECAL ", d.name, " in model space ", m3.global_transform.affine_inverse() * d.global_position)
		var side := vis.global_transform.basis.x
		side.y = 0.0
		side = side.normalized()
		for flank in [0, 1]:
			# Square to her side, level with the mark: one flank, then the other.
			var sgn := 1.0 if flank == 0 else -1.0
			cam.global_position = rump + side * sgn * 2.4 + Vector3.UP * 0.05
			cam.look_at(rump + Vector3.UP * 0.05, Vector3.UP)
			for i in 6:
				await process_frame
			await RenderingServer.frame_post_draw
			var img := vp.get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			tiles.append(img)
		print("MARK seed=", s - 1, " race=", look.race, " donor=", look.donor, " talent=",
			look.mark.get("talent", ""))
		done += 1
	_sheet(tiles, 6, out.path_join("marks.png"))
	print("LANEB_MARKS_OK")
	quit(0)


func _sheet(tiles: Array[Image], cols: int, path: String) -> void:
	for i in tiles.size():
		tiles[i].save_png(path.get_base_dir().path_join("tile_%02d.png" % i))
	var w := tiles[0].get_width() / 2
	var h := tiles[0].get_height() / 2
	var rows := int(ceil(float(tiles.size()) / cols))
	var sheet := Image.create(w * cols, h * rows, false, Image.FORMAT_RGB8)
	for i in tiles.size():
		var t := tiles[i]
		t.resize(w, h, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(t, Rect2i(0, 0, w, h), Vector2i((i % cols) * w, (i / cols) * h))
	sheet.save_png(path)
