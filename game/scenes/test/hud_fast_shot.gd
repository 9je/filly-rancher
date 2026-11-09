extends SceneTree
## THE HUD AT REST, FAST (Fable AAA round 2, #9): the HUD over a still of the world (--bg) with
## no ranch booted, the compass strip mounted as ranch.gd mounts it (four places and a goal),
## no tip up (nothing in reach), and three news bubbles in the world at 1.2 m, 4 m and 14 m
## from the lens, so their on-screen sizes can be compared. Shot at 1280 x 720, the size the
## review read the compass letters at.
##   xvfb-run ... godot --display-driver x11 --path game -s res://scenes/test/hud_fast_shot.gd -- --out=/abs/dir --bg=/abs/still.png
const HudScene := preload("res://ui/hud.tscn")
const PeopleScript := preload("res://world/people.gd")
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
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("HUDSHOT ", name)


func _run() -> void:
	root.get_window().size = Vector2i(1280, 720)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	# The still is the sky and the ground: the 3D bubbles draw over it.
	e.background_mode = Environment.BG_CANVAS
	e.background_canvas_max_layer = -1
	env.environment = e
	world.add_child(env)
	var cam := Camera3D.new()
	cam.fov = 70.0
	world.add_child(cam)
	cam.current = true
	cam.global_position = Vector3(0, 1.6, 0)
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
	# Three townsponies' bubbles: beside the lens, a few steps off, and across the plaza.
	var bubbles: Array[Node3D] = []
	for spot: Vector3 in [Vector3(-0.5, 1.6, -1.3), Vector3(1.4, 1.6, -4.0), Vector3(-3.5, 1.6, -14.0), Vector3(2.2, 1.6, -2.6)]:
		var m: Node3D = PeopleScript.news_marker()
		world.add_child(m)
		m.global_position = spot
		bubbles.append(m)
	var hud: CanvasLayer = HudScene.instantiate()
	root.add_child(hud)
	var compass: Control = (load("res://ui/compass.gd") as GDScript).new()
	compass.name = "Compass"
	hud.add_child(compass)
	compass.set("camera_provider", func() -> Camera3D: return cam)
	var list: Array[Dictionary] = []
	var icons := [PlaceSign.Icon.HOUSE, PlaceSign.Icon.COIN, PlaceSign.Icon.FENCE, PlaceSign.Icon.CRATE]
	for i in icons.size():
		var n := Node3D.new()
		world.add_child(n)
		n.global_position = Vector3(cos(-1.9 + i * 0.5), 0, sin(-1.9 + i * 0.5)) * 40.0
		list.append({"name": "Place %d" % i, "icon": int(icons[i]), "node": n})
	compass.call("set_places", list)
	compass.call("set_goal", list[1]["node"], int(icons[1]))
	hud.call("set_tip", "")
	await _shot("hud_rest_720")
	for m in bubbles:
		var at: Vector3 = m.global_position
		print("BUBBLE %.1f m from the lens, on screen at %s" % [at.distance_to(cam.global_position),
			cam.unproject_position(at)])
	# The same HUD with a tip up, as when a pony is under the crosshair.
	hud.call("set_tip", "Hold Right Mouse on a pony to Scoop her up")
	for i in 30:
		await process_frame
	await _shot("hud_pony_in_reach_720")
	# A toast (Fable AAA round 3, #9): on the saddlebag, not over the pony.
	hud.call("toast", "Lark Wish moved into the pen. It is now full.")
	await _shot("hud_toast_720")
	print("TOAST_RECT ", hud.call("toast_rect"))
	print("HUD_FAST_SHOT_OK")
	quit()
