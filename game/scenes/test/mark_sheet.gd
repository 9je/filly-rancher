extends SceneTree
## Writes every talent x motif mark into one PNG sheet for review: --out=<png>
func _init() -> void:
	var out := "user://marks.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	var ids := MarkComposer.talent_ids()
	var sheet := Image.create(128 * 3, 128 * ids.size() / 2, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.97, 0.9, 0.8))
	var cols := 6
	sheet = Image.create(128 * cols, 128 * int(ceil(ids.size() * 3.0 / cols)), false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.97, 0.9, 0.8))
	var i := 0
	for t in ids:
		for m in range(3):
			var img := MarkComposer.compose({"talent": t, "motif": m, "a": Color(0.9, 0.35, 0.5), "b": Color(1.0, 0.85, 0.3)})
			var x := (i % cols) * 128
			var y := (i / cols) * 128
			sheet.blend_rect(img, Rect2i(0, 0, 128, 128), Vector2i(x, y))
			i += 1
	sheet.save_png(out)
	print("MARKS_OK ", out)
	quit()
