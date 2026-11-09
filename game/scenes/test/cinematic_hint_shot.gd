extends SceneTree
## THE CINEMATIC'S CHROME, FAST (Fable AAA round 3, #9: "Hold Esc to skip is tiny grey text").
## A shot over a still (--bg, the world drawn behind the 3D as the canvas background) with a
## caption, photographed at rest and with the skip key half held, so the bars, the caption card
## and the skip pill are judged without booting the valley.
##   xvfb-run ... godot --display-driver x11 --path game -s res://scenes/test/cinematic_hint_shot.gd -- --out=/abs/dir --bg=/abs/still.png
var out := ""
var bg := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--bg="):
			bg = a.substr(5)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("CINESHOT ", name)


func _run() -> void:
	root.get_window().size = Vector2i(1600, 900)
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CANVAS
	e.background_canvas_max_layer = -1
	env.environment = e
	world.add_child(env)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.current = true
	if bg != "":
		var still := TextureRect.new()
		still.texture = ImageTexture.create_from_image(Image.load_from_file(bg))
		still.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		still.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		var layer := CanvasLayer.new()
		layer.layer = -1
		root.add_child(layer)
		still.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.add_child(still)
	var c := Cinematic.shared(self)
	c.play([{"from": Vector3(0, 2, 0), "to": Vector3(0, 2, -0.1), "look": Vector3(0, 2, -10),
		"time": 6.0, "caption": "Welcome to the valley"}], {"host": world})
	for i in 90:
		await process_frame
	await _shot("cine_hint_rest")
	c.set("_skip_held", 0.3)
	var press := InputEventAction.new()
	press.action = &"ui_cancel"
	press.pressed = true
	Input.parse_input_event(press)
	for i in 6:
		await process_frame
	await _shot("cine_hint_held")
	print("CINE_HINT_SHOT_OK")
	quit()
