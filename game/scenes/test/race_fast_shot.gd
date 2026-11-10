extends SceneTree
## THE RACE GUIDE, FAST (Fable AAA round 3, #9: "the race guide's lower 40% is empty
## purple"). The race menu on its own over a still (--bg), fed three entrants, then five, and
## again with a result printed, so the panel's height is judged without booting the valley.
##   xvfb-run ... godot --display-driver x11 --path game -s res://scenes/test/race_fast_shot.gd -- --out=/abs/dir [--bg=/abs/still.png]
var out := ""
var bg := ""
var count := 3
var _faces := {}
const NAMES := ["Lark Wish", "Cobble Ribbon", "Honey Muffin", "Mote", "Sunny Day"]
const COATS := [Color(0.62, 0.86, 0.86), Color(0.96, 0.92, 0.96), Color(0.98, 0.9, 0.95),
	Color(0.85, 0.75, 0.55), Color(0.98, 0.85, 0.4)]


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--bg="):
			bg = a.substr(5)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _shot(name: String) -> void:
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("RACESHOT ", name)


func _field(n: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	# Baked faces standing in for the PortraitBaker's, the last runner left unbaked so the
	# swatch fallback is seen too.
	# Held here: a texture loaded fresh inside a draw is not on the GPU yet and draws white.
	var faces := ["marigold", "bramble", "palace_dealer", "palace_host", ""]
	for i in n:
		var face: Texture2D = null
		if faces[i] != "":
			if not _faces.has(faces[i]):
				_faces[faces[i]] = load("res://assets/ui/portraits/%s.png" % faces[i]) as Texture2D
			face = _faces[faces[i]]
		rows.append({"uid": StringName("p%d" % i), "name": NAMES[i], "happiness": 1.0 - 0.2 * i,
			"odds": 3.2 + 3.0 * i, "chance": 0.28 / float(i + 1), "coat": COATS[i],
			"mane": COATS[i].darkened(0.3), "portrait": face})
	return rows


func _run() -> void:
	root.get_window().size = Vector2i(1600, 900)
	var layer := CanvasLayer.new()
	layer.layer = -1
	root.add_child(layer)
	var rect := ColorRect.new()
	rect.color = Color(0.20, 0.10, 0.24)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	if bg != "":
		var still := TextureRect.new()
		still.texture = ImageTexture.create_from_image(Image.load_from_file(bg))
		still.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		still.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		still.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.add_child(still)
	var menu: CanvasLayer = (load("res://ui/race_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	menu.set("can_open", func() -> bool: return true)
	menu.set("chips_provider", func() -> int: return 400)
	menu.set("entrants_provider", func() -> Array[Dictionary]: return _field(count))
	menu.call("open")
	await _shot("race_guide_3")
	count = 5
	menu.call("refresh")
	await _shot("race_guide_5")
	count = 3
	menu.call("show_result", ["Lark Wish won by a length.", "You backed her for 10: 32 back."] as Array[String])
	await _shot("race_guide_result")
	print("RACE_FAST_SHOT_OK")
	quit()
