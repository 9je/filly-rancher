extends SceneTree
## P9 W3 item 55: the cutie mark step of the creator, the blue ink clicked with the pointer;
## the swatch row whole and the picked ring round its pot.
##   -s res://scenes/test/laneb_creator.gd -- --out=<dir>
const Boot := preload("res://scenes/test/laneb_boot.gd")
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	root.get_window().size = Vector2i(1600, 900)
	var screen: Node = load("res://ui/creation_screen.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	screen.call("open", PlayerLook.new())
	screen.call("set_step", 1)
	for i in 20:
		await process_frame
	var blue: Button = screen.get_node(^"Layout/Panel/Margin/Column/InkRow/Ink4")
	await Boot.click(self, Boot.centre_of(self, blue))
	await Boot.shot(self, out.path_join("creator_mark.png"), 20)
	var row: Control = screen.get_node(^"Layout/Panel/Margin/Column/InkRow")
	var col: Control = screen.get_node(^"Layout/Panel/Margin/Column")
	print("ROW ", row.get_global_rect(), " COLUMN ", col.get_global_rect())
	for i in 6:
		var b: Button = screen.get_node(NodePath("Layout/Panel/Margin/Column/InkRow/Ink%d" % i))
		print("INK ", i, " ", b.get_global_rect())
	var r := row.get_global_rect()
	var f := root.get_final_transform()
	var img := root.get_texture().get_image()
	var a := f * r.position - Vector2(40, 30)
	var crop := img.get_region(Rect2i(Vector2i(maxi(0, int(a.x)), maxi(0, int(a.y))), Vector2i(int(r.size.x * f.get_scale().x) + 80, int(r.size.y * f.get_scale().y) + 60)))
	crop.resize(crop.get_width() * 2, crop.get_height() * 2)
	crop.save_png(out.path_join("creator_inks_zoom.png"))
	print("LANEB_CREATOR_OK")
	quit(0)
