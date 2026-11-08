extends SceneTree
## P8 S5 EVIDENCE: the icon set's contact sheet (docs/aaa-review-2026-11-08.md section 3). Every
## game/assets/ui/icons/*.svg (plated) rasterised at 128, 64 and 32 px on cream, plum and grass,
## plus a silhouette row at 24 px (thresholded black) for the "name it as a shape" test. Runs
## headless: SVG is rasterised on the CPU.
##   godot --headless --path game -s res://scenes/test/icon_sheet.gd -- --out=/abs/sheet.png [--size=64]
const DIR := "res://assets/ui/icons/"
const BGS := [Color(1.0, 0.95, 0.84), Color(0.29, 0.18, 0.36), Color(0.45, 0.66, 0.32)]


func _initialize() -> void:
	var out := ""
	var only := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--size="):
			only = int(a.substr(7))
	var names: Array[String] = []
	for f in DirAccess.get_files_at(DIR):
		if f.ends_with(".svg") and not f.ends_with("_bare.svg"):
			names.append(f.get_basename())
	names.sort()
	var sizes := [128, 64, 32] if only == 0 else [only]
	var cols := 10
	var rows := int(ceil(names.size() / float(cols)))
	var cell := 0
	for s: int in sizes:
		cell += s + 8
	var label_h := 0
	var w := cols * (cell * BGS.size() + 12)
	var h: int = rows * (int(sizes[0]) + 16)
	var sheet := Image.create(w, h, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.85, 0.85, 0.85))
	for i in names.size():
		var src := FileAccess.get_file_as_string(DIR + names[i] + ".svg")
		var cx := (i % cols) * (cell * BGS.size() + 12)
		var cy: int = int(i / cols) * (int(sizes[0]) + 16) + label_h
		var x := cx
		for bg: Color in BGS:
			for s: int in sizes:
				var img := Image.new()
				img.load_svg_from_string(src, s / 64.0)
				img.convert(Image.FORMAT_RGBA8)
				var tile := Image.create(s + 8, sizes[0] + 8, false, Image.FORMAT_RGBA8)
				tile.fill(bg)
				tile.blend_rect(img, Rect2i(0, 0, s, s), Vector2i(4, 4))
				sheet.blit_rect(tile, Rect2i(0, 0, s + 8, sizes[0] + 8), Vector2i(x, cy))
				x += s + 8
	sheet.save_png(out)
	print("ICON_SHEET_OK %d icons -> %s" % [names.size(), out])
	quit(0)
