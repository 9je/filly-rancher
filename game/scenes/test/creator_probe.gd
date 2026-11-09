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
	# The mark step again with three stamps down, in their own colours: the canvas and the
	# flank on the turntable show the same mark.
	screen.call("set_step", 1)
	for kind: StringName in [&"talent:kindness", &"talent:kindness", &"talent:kindness"]:
		screen.call("stamp_symbol", kind)
	# Spread like Fluttershy's three butterflies (a probe reaching into the canvas's stamps).
	var canvas: Node = screen.call("canvas")
	var laid: Array = canvas.get("_stamps")
	for i in laid.size():
		laid[i].at = [Vector2(0.32, 0.34), Vector2(0.68, 0.40), Vector2(0.46, 0.70)][i]
		laid[i].scale = 0.42
	canvas.call("_refresh")
	screen.call("_sync_mark")
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/creator_stamped.png" % out)
	# Round 4: an earth pony's 35 mane cards, in her colours, on the strip; then a coat pick
	# caught mid-reaction (she swings round, hops, smiles at the lens).
	screen.call("set_step", 2)
	screen.call("set_race", 0)
	screen.call("set_coat", 4)
	screen.call("set_mane", 10)
	for i in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/creator_hair_earth.png" % out)
	screen.call("set_step", 0)
	for i in 10:
		await process_frame
	screen.call("set_coat", 2)
	for i in 14:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/creator_react.png" % out)
	print("CREATOR_PROBE_OK")
	quit(0)
