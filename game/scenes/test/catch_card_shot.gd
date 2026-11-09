extends SceneTree
## THE CATCH MOMENT, FRAME BY FRAME (Fable AAA round 1: "make it a full-screen moment rather
## than a toast"). The HUD over a still of the world (--bg), a pony body on a stage of its own
## for the portrait, then a catch, photographed at points through the moment: the burst, the
## stars popping, the hold, the flight to the corner, the corner card. Then a second catch
## skipped by a click. The clock runs slow (Engine.time_scale) so each frame lands where asked
## on the software renderer.
##   xvfb-run ... godot --display-driver x11 --path game -s res://scenes/test/catch_card_shot.gd -- --out=/abs/dir --bg=/abs/still.png
const HudScene := preload("res://ui/hud.tscn")
const PonyScene := preload("res://actors/pony/pony.tscn")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
var out := ""
var bg := ""
var pony := "fluttershy"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--bg="):
			bg = a.substr(5)
		elif a.begins_with("--pony="):
			pony = a.substr(7)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("CATCHSHOT ", name)


func _body(id: StringName) -> Node3D:
	var stage := Node3D.new()
	stage.position = Vector3(0, -500, 0)
	root.add_child(stage)
	var p: Node3D = PonyScene.instantiate()
	stage.add_child(p)
	var inst = PonyInstanceScript.create(id)
	if p.has_method("setup"):
		p.call("setup", inst.data())
	return p


func _until(card: Control, t: float) -> void:
	while float(card.get("_moment_t")) < t and card.visible:
		await process_frame


func _run() -> void:
	root.get_window().size = Vector2i(1600, 900)
	var world := Node3D.new()
	root.add_child(world)
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
	var hud: CanvasLayer = HudScene.instantiate()
	root.add_child(hud)
	# The rest of the HUD as ranch.gd mounts it (Fable AAA round 3, #9: the compass and Getting
	# started stood at full strength under the sunburst): the compass strip, the objective card
	# and the three lessons, so the frames show the HUD stepping out for the beat. Use a --bg
	# still with no HUD baked into it.
	var compass: Control = (load("res://ui/compass.gd") as GDScript).new()
	compass.name = "Compass"
	hud.add_child(compass)
	compass.set("camera_provider", func() -> Camera3D: return cam)
	var spot := Node3D.new()
	world.add_child(spot)
	spot.position = Vector3(10, 0, -30)
	var places: Array[Dictionary] = [{"name": "Pens", "icon": int(PlaceSign.Icon.FENCE), "node": spot}]
	compass.call("set_places", places)
	compass.call("set_goal", spot, int(PlaceSign.Icon.STAR))
	var objective: Control = (load("res://ui/objective_card.gd") as GDScript).new()
	objective.name = "ObjectiveCard"
	hud.add_child(objective)
	objective.call("show_objective", {"id": &"probe", "words": "Catch a Drifter",
		"icon": int(PlaceSign.Icon.STAR)}, 7.0)
	var rows: Array = []
	for id: String in ["tutorial_catch", "tutorial_pen", "tutorial_sell"]:
		rows.append({"id": id, "text": id, "done": false, "paid": false, "reward_bits": 20})
	hud.call("set_tasks", rows)
	var body := _body(StringName(pony))
	for i in 10:
		await process_frame
	await _shot("catch_before")
	var card: Control = hud.call("catch_card")
	Engine.time_scale = 0.08
	card.call("show_catch", PonyInstanceScript.create(StringName(pony)), body)
	for at: float in [0.06, 0.16, 0.34, 0.50, 0.70, 1.00, 1.45, 1.62, 1.75]:
		await _until(card, at)
		await _shot("catch_%03d" % roundi(at * 100.0))
	await _until(card, 2.4)
	await _shot("catch_settled")
	print("SETTLED_IN_CORNER=", not bool(card.call("in_moment")))
	# A second catch, skipped by a click a third of a second in.
	card.call("show_catch", PonyInstanceScript.create(&"rainbowdash"), _body(&"rainbowdash"))
	await _until(card, 0.3)
	await _shot("skip_before")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(800, 450)
	root.push_input(click)
	print("SKIPPED=", not bool(card.call("in_moment")))
	var panel: Control = card.get_node("Panel")
	while panel.scale.x > 1.001 and card.visible:
		await process_frame
	await _shot("skip_after")
	Engine.time_scale = 1.0
	print("CATCH_SHOT_OK")
	quit()
