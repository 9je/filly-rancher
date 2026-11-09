extends SceneTree
## THE HUD IN THE HOUSE STYLE, FAST (Fable AAA review round 1, #3). The HUD scene alone over a
## still of the world (any PNG, --bg), so a look change is judged in seconds rather than after a
## whole valley boots on the software renderer: the lessons, the compass strip and the objective
## card, the saddlebag with ponies in it and bits, the tip with its key glyph, the prompt as a
## key and a verb, then a toast (the tip steps aside), then the controls card.
##   xvfb-run ... godot --display-driver x11 --path game -s res://scenes/test/hud_style_shot.gd -- --out=/abs/dir --bg=/abs/still.png
const HudScene := preload("res://ui/hud.tscn")
const StorageScript := preload("res://systems/storage.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
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
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))


func _run() -> void:
	root.get_window().size = Vector2i(1600, 900)
	var world := Node3D.new()
	root.add_child(world)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.current = true
	if bg != "":
		var img := Image.load_from_file(bg)
		var still := TextureRect.new()
		still.texture = ImageTexture.create_from_image(img)
		still.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		still.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		var layer := CanvasLayer.new()
		layer.layer = -1
		root.add_child(layer)
		still.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.add_child(still)
	var hud: CanvasLayer = HudScene.instantiate()
	root.add_child(hud)
	await process_frame
	# The places the compass points at, round the camera.
	var places: Array[Dictionary] = []
	var spots := [[Vector3(-14, 0, -30), PlaceSign.Icon.CRATE, "Depot"],
		[Vector3(0, 0, -40), PlaceSign.Icon.HOUSE, "Home"], [Vector3(16, 0, -30), PlaceSign.Icon.COIN, "Market"],
		[Vector3(30, 0, -14), PlaceSign.Icon.FENCE, "Pens"]]
	var goal: Node3D = null
	for s: Array in spots:
		var n := Node3D.new()
		world.add_child(n)
		n.global_position = s[0]
		places.append({"name": s[2], "icon": s[1], "node": n})
		if s[2] == "Market":
			goal = n
	var compass: Control = (load("res://ui/compass.gd") as GDScript).new()
	compass.name = "Compass"
	hud.add_child(compass)
	compass.set("player", cam)
	compass.call("set_places", places)
	compass.call("set_goal", goal, PlaceSign.Icon.COIN)
	var card: Control = (load("res://ui/objective_card.gd") as GDScript).new()
	card.name = "ObjectiveCard"
	hud.add_child(card)
	card.call("show_objective", {"id": &"sell", "icon": PlaceSign.Icon.COIN,
		"words": "Sell your gems to Bramble"}, 23.0)
	hud.call("set_tasks", [
		{"id": "tutorial_catch", "text": "Catch a pony with your magic beam.", "done": true, "reward_bits": 20},
		{"id": "tutorial_pen", "text": "Move a pony into a pen.", "done": false, "reward_bits": 30},
		{"id": "tutorial_sell", "text": "Sell a gem at the market.", "done": false, "reward_bits": 50}])
	var bag := StorageScript.new(12)
	for id: StringName in [&"twilight", &"stock_shy", &"stock_curious", &"fluttershy"]:
		bag.store(PonyInstanceScript.create(id))
	hud.set("_storage", bag)
	hud.call("_on_storage_changed")
	hud.call("set_bits", 1240)
	hud.call("set_pantry", 14, 0)
	hud.call("set_tip", "Hold Right Mouse on a pony to Scoop her up")
	hud.call("set_prompt", "E: talk to Tumble")
	for i in 30:
		await process_frame
	await _shot("hud_tip_prompt")
	hud.call("set_prompt", "")
	hud.call("toast", "Lark Wish moved into the pen. It is now full.")
	for i in 30:
		await process_frame
	await _shot("hud_toast")
	print("TIP_SHOWING_UNDER_TOAST=", hud.call("tip_showing"))
	hud.call("toast", "Pip: \"Smile! You're in the Cloudsdale newsletter!\" Steward of the Week: 12 ponies placed. \"The whole valley will see your pens by Tuesday!\"")
	hud.set("_toast_left", 0.0)
	for i in 10:
		await process_frame
	var ev := InputEventAction.new()
	ev.action = &"toggle_hints"
	ev.pressed = true
	hud.call("_unhandled_input", ev)
	for i in 10:
		await process_frame
	await _shot("hud_hints")
	print("HUD_STYLE_SHOT_OK")
	quit()
