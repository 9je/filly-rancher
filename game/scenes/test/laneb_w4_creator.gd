extends SceneTree
## P9 W4 items 51-54, 56: every body the creator offers, for each kind of pony, as the stage
## draws it (the creator's own SubViewport, turntable stopped at a side and a rear three
## quarter), with a bright mane, the tail left on "same as mane", a stamped flower mark and
## (pegasus) the freckles marking. A contact sheet per race, plus the surfaces PonyPaint left
## unpainted (Role.NONE) or hid, per style.
##   -s res://scenes/test/laneb_w4_creator.gd -- --out=<dir> [--race=0|1|2] [--angles=90,200]
const PonyPaintScript := preload("res://systems/pony_paint.gd")
const DonorTableScript := preload("res://systems/donor_table.gd")
var out := ""
var races: Array = [0, 1, 2]
var angles: Array = [90.0, 215.0, 270.0]
var marking := 4
var fov := 0.0
var styles: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--race="):
			races = [int(a.substr(7))]
		elif a.begins_with("--angles="):
			angles = []
			for v in a.substr(9).split(","):
				angles.append(float(v))
		elif a.begins_with("--fov="):
			fov = float(a.substr(6))
		elif a.begins_with("--styles="):
			for v in a.substr(9).split(","):
				styles.append(int(v))
		elif a.begins_with("--marking="):
			marking = int(a.substr(10))
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	root.get_window().size = Vector2i(1600, 900)
	var screen: Node = load("res://ui/creation_screen.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	screen.call("open", PlayerLook.new())
	var sub: SubViewport = screen.get_node(^"Layout/Stage/Viewport/SubViewport")
	print("STAGE msaa=", sub.msaa_3d, " size=", sub.size)
	var turntable: Node3D = screen.get("_turntable")
	var pal: StockPalette = screen.get("_palette")
	var best := 0
	for i in pal.manes.size():
		var c: Color = pal.manes[i]
		if c.r - c.b > (pal.manes[best] as Color).r - (pal.manes[best] as Color).b:
			best = i
	screen.call("set_mane", best)
	var coat_i := 0
	for i in pal.coats.size():
		var c: Color = pal.coats[i]
		if c.b - c.r > (pal.coats[coat_i] as Color).b - (pal.coats[coat_i] as Color).r:
			coat_i = i
	screen.call("set_coat", coat_i)
	screen.call("set_ink", 1)
	screen.call("stamp", 4)
	if fov > 0.0:
		var cam: Camera3D = screen.get("_camera")
		cam.fov = fov
		cam.look_at(Vector3(0.0, 0.95, 0.0), Vector3.UP)
	screen.call("set_marking", marking)
	for race in races:
		screen.call("set_race", race)
		var n: int = PlayerLook.style_count(race)
		var tiles: Array[Image] = []
		for style in n:
			if not styles.is_empty() and not style in styles:
				continue
			screen.call("set_mane_style", style)
			for i in 6:
				await process_frame
			_report(screen, race, style)
			for ang: float in angles:
				screen.set("_drag_rest", 999.0)
				turntable.rotation.y = deg_to_rad(ang)
				for i in 4:
					await process_frame
				await RenderingServer.frame_post_draw
				var img := sub.get_texture().get_image()
				img.convert(Image.FORMAT_RGB8)
				tiles.append(img)
		var img0: Image = (screen.call("canvas") as Object).call("image")
		img0.save_png(out.path_join("mark_drawn.png"))
		print("MARK size=", img0.get_size())
		_sheet(tiles, angles.size(), out.path_join("race%d.png" % race))
	print("CREATOR_SHEET_OK")
	quit(0)


func _report(screen: Node, race: int, style: int) -> void:
	var model: Node3D = screen.get("_model")
	var look: PlayerLook = screen.get("_look")
	var pl: PonyLook = look.to_pony_look(screen.get("_palette"))
	var donor: Dictionary = DonorTableScript.load_table().find(pl.donor)
	var bad := []
	var hidden := []
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		if not mi.is_visible_in_tree():
			hidden.append(String(mi.name))
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			var nm := m.resource_name if m != null else ""
			var r: int = PonyPaintScript.role_of(nm, donor)
			if r == PonyPaintScript.Role.NONE:
				bad.append("%s/%s" % [mi.name, nm])
			elif r == PonyPaintScript.Role.HIDE:
				hidden.append("%s/%s(hide)" % [mi.name, nm])
	var ov := []
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh != null and mi.get_surface_override_material_count() > 0:
			var m := mi.get_surface_override_material(0)
			if m is ShaderMaterial:
				ov.append(str((m as ShaderMaterial).get_shader_parameter(&"albedo")))
				break
	print("LOOK coat=", pl.coat, " mane=", pl.mane, " tail=", pl.tail, " first_override=", ov, " shading=", ToonStyler.shading_enabled)
	print("STYLE race=%d %d %s NONE=%s HIDDEN=%s" % [race, style, pl.donor, bad, hidden])


func _sheet(tiles: Array[Image], cols: int, path: String) -> void:
	if tiles.is_empty():
		return
	var w := tiles[0].get_width() / 2
	var h := tiles[0].get_height() / 2
	var per_row := cols * 3
	var rows := int(ceil(float(tiles.size()) / per_row))
	var sheet := Image.create(w * per_row, h * rows, false, Image.FORMAT_RGB8)
	for i in tiles.size():
		var t := tiles[i]
		t.resize(w, h, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(t, Rect2i(0, 0, w, h), Vector2i((i % per_row) * w, (i / per_row) * h))
	sheet.save_png(path)
	print("SHEET ", path, " tiles=", tiles.size())
