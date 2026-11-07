extends SceneTree
## BAKES THE MARKET'S DECORATION PICTURES (PS6, G14): each of the twelve decorations in
## game/systems/decor.gd, built exactly as the ranch stands it (world/decor_layer.gd: the prop
## at its world size in the toon look, or the pony in stone on her plinth), lit and seen from
## a three quarter view, cut out on a clear background, into res://assets/ui/decor_icons/ as
## decor_<id>.png (the ShopItem's own id). Run again whenever a decoration changes:
##   xvfb-run ... tools/bin/godot ... --path game -s res://scenes/test/decor_icons.gd [-- --out=/abs/dir]
## --out also writes there a contact sheet of all twelve on the Market tile's cream disc, and
## each one full size before it is shrunk (big_<id>.png).
const DecorScript := preload("res://systems/decor.gd")
const DecorLayerScript := preload("res://world/decor_layer.gd")
const OUT := "res://assets/ui/decor_icons"
const SIZE := 128
const RENDER := 512
## Where the camera looks from: a little to the side and above, the way a shop picture is.
const VIEW := Vector3(0.75, 0.55, 1.0)
const VIEW_FRONT := Vector3(1.0, 0.4, -0.55)
const FOV := 26.0
## The cut-out's ink edge, the catch card's own outline colour, so a pale prop (the hay, the
## stone statues, the white arch) still stands off the Market's cream disc.
const EDGE := Color(0.24, 0.17, 0.3, 1.0)
const EDGE_PX := 7
var sheet_dir := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			sheet_dir = a.substr(6)
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var vp := SubViewport.new()
	vp.size = Vector2i(RENDER, RENDER)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 1, 1)
	e.ambient_light_energy = 0.45
	env.environment = e
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 35, 0)
	sun.light_energy = 0.95
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = FOV
	vp.add_child(cam)
	var layer: Node3D = DecorLayerScript.new()
	vp.add_child(layer)
	var pictures: Array[Image] = []
	for d: Dictionary in DecorScript.CATALOGUE:
		var node: Node3D = layer.call("_make", d)
		layer.add_child(node)
		for k in 3:
			await process_frame
		var box := _bounds(node)
		var centre := box.get_center()
		var radius := box.size.length() * 0.5
		var dist := radius / sin(deg_to_rad(FOV * 0.5)) * 0.92
		# A statue is seen from in front: a pony faces -Z, and from +Z it was her tail.
		var view := VIEW_FRONT if d.has("statue") else VIEW
		cam.global_position = centre + view.normalized() * dist
		cam.look_at(centre)
		cam.make_current()
		for k in 10:
			await process_frame
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img = _outlined(img)
		img = _fitted(img)
		if not sheet_dir.is_empty():
			img.save_png(sheet_dir.path_join("big_" + String(d.id) + ".png"))
		img.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
		var file := "decor_%s.png" % String(d.id)
		img.save_png(ProjectSettings.globalize_path(OUT.path_join(file)))
		pictures.append(img)
		print("DECOR_ICON ", file, " bounds=", box.size)
		node.free()
	if not sheet_dir.is_empty():
		_contact_sheet(pictures)
	print("DECOR_ICONS_OK")
	quit(0)


func _bounds(node: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var b: AABB = mi.global_transform * mi.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


## The cut-out with an ink edge EDGE_PX wide round its silhouette, drawn under it.
func _outlined(img: Image) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	var solid := PackedByteArray()
	solid.resize(w * h)
	for y in h:
		for x in w:
			solid[y * w + x] = 1 if img.get_pixel(x, y).a > 0.4 else 0
	for y in h:
		for x in w:
			if solid[y * w + x] == 1:
				continue
			var near := false
			for dy in range(-EDGE_PX, EDGE_PX + 1, 2):
				for dx in range(-EDGE_PX, EDGE_PX + 1, 2):
					if dx * dx + dy * dy > EDGE_PX * EDGE_PX:
						continue
					var xx := x + dx
					var yy := y + dy
					if xx >= 0 and yy >= 0 and xx < w and yy < h and solid[yy * w + xx] == 1:
						near = true
						break
				if near:
					break
			if near:
				out.set_pixel(x, y, EDGE)
	out.blend_rect(img, Rect2i(0, 0, w, h), Vector2i.ZERO)
	return out


## Cropped to a square round what was drawn, with a little air: a wide prop (the picnic table,
## the wagon) fills its disc as fully as a tall one rather than sitting small in the middle.
func _fitted(img: Image) -> Image:
	var used := img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return img
	var side := int(maxf(used.size.x, used.size.y) * 1.06)
	var out := Image.create(side, side, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	out.blit_rect(img, used, Vector2i(side / 2, side / 2) - used.size / 2)
	return out


## Every picture on the Market tile's cream disc, four to a row, to look at.
func _contact_sheet(pictures: Array[Image]) -> void:
	DirAccess.make_dir_recursive_absolute(sheet_dir)
	var cell := 160
	var sheet := Image.create(cell * 4, cell * 3, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.24, 0.12, 0.30))
	for i in pictures.size():
		var at := Vector2i((i % 4) * cell, (i / 4) * cell)
		var c := Vector2(at) + Vector2(cell, cell) * 0.5
		for y in cell:
			for x in cell:
				if Vector2(at.x + x, at.y + y).distance_to(c) < SIZE * 0.5 + 6:
					sheet.set_pixel(at.x + x, at.y + y, Color(0.98, 0.94, 0.82))
		sheet.blend_rect(pictures[i], Rect2i(0, 0, SIZE, SIZE), at + Vector2i(16, 16))
	sheet.save_png(sheet_dir.path_join("decor_icons_sheet.png"))
