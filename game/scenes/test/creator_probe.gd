extends SceneTree
## The creator alone, opened on a fresh look, one picture per step (a check on its chrome).
##   xvfb-run ... godot --path game -s res://scenes/test/creator_probe.gd -- --out=/abs/dir
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
	for step in 4:
		screen.call("set_step", step)
		for i in 20:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/creator_step%d.png" % [out, step])
	print("CREATOR_PROBE_OK")
	quit(0)
