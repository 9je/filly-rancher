extends SceneTree
## P9 W4 leftover 49: the PortraitBaker's raw images for every penned pony (what the race guide
## draws), saved as baked, beside a gameplay frame of the same ponies.
##   -s res://scenes/test/laneb_w4_portraits.gd -- --out=<dir>
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
	var baker := PortraitBaker.shared(self)
	var keys: Array[String] = []
	for pen: Pen in Boot.pens(ranch):
		for inst: PonyInstance in pen.ponies():
			var k := String(inst.uid)
			baker.portrait(k, pen.body_for(inst.uid))
			keys.append(k)
			print("PEN ", k, " ", inst.display_name())
	for i in 240:
		await process_frame
	for k in keys:
		var tex: Texture2D = baker.portrait(k, null)
		if tex != null:
			var img := tex.get_image()
			print("IMG ", k, " format=", img.get_format(), " centre=", img.get_pixel(img.get_width() / 2, img.get_height() / 2))
			img.save_png(out.path_join("p_%s.png" % k))
	print("PORTRAITS_OK")
	quit()
