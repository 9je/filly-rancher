extends SceneTree
## P8 S10 EVIDENCE: the title over its key art, and the loading screen's key-art mode.
##   xvfb-run ... godot --display-driver x11 --path game -s res://scenes/test/title_shot.gd -- --out=/abs/dir
const BootIntentScript := preload("res://world/boot_intent.gd")
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	root.get_window().size = Vector2i(1600, 900)
	BootIntentScript.driven = true
	change_scene_to_file("res://ui/title_screen.tscn")
	for i in 60:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("title.png"))
	# As _enter_world() does it: the menu goes, then the card comes up over the title. The
	# ranch claims the screen while it builds, so the probe claims it too; otherwise the card
	# finds the cached title already loaded and is caught mid-fade.
	var menu := current_scene.get_node_or_null(^"Centre") as CanvasItem
	if menu != null:
		menu.visible = false
	var ls: CanvasLayer = load("res://ui/loading_screen.gd").new()
	ls.set("scene_path", "res://ui/title_screen.tscn")
	root.add_child(ls)
	ls.get_script().claim()
	for i in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("loading.png"))
	print("TITLE_SHOT_OK")
	quit(0)
