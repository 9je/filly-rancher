extends SceneTree
## One baked portrait per pony file, written to --out (a check on PortraitBaker's framing).
##   xvfb-run ... godot --path game -s res://scenes/test/portrait_probe.gd -- --out=/abs/dir
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	var baker := PortraitBaker.shared(self)
	await process_frame
	for f: String in ["fluttershy", "derpyhooves", "rainbowdash"]:
		var holder := Node3D.new()
		root.add_child(holder)
		holder.add_child(PonyVisuals.build(load("res://data/ponies/%s.tres" % f)))
		baker.portrait(f, holder)
		for i in 60:
			await process_frame
			if baker.has_portrait(f):
				break
		var tex: Texture2D = baker.portrait(f, null)
		if tex != null:
			tex.get_image().save_png("%s/%s.png" % [out, f])
		holder.queue_free()
	print("PORTRAIT_PROBE_OK")
	quit(0)
