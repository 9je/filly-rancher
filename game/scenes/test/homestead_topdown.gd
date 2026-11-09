extends SceneTree
## Top-down orthographic shot of the homestead, and every building's world AABB printed.
const BootIntentScript := preload("res://world/boot_intent.gd")
var out := ""
## --size=N (ortho metres across) and --center=x,z widen the shot past the homestead.
var size := 70.0
var center := Vector2(0, -6)
## --cams=name:x,y,z,tx,ty,tz;... eye-level lenses shot instead of the five street views.
var cams := {}
## --pens: a pen on every plot first (the pen yard as it reads once it is built).
var pens := false
## --time=dusk|night|nightrain|fog: the world pinned before the eye-level lenses.
var time := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--size="):
			size = float(a.substr(7))
		elif a.begins_with("--time="):
			time = a.substr(7)
		elif a == "--pens":
			pens = true
		elif a.begins_with("--cams="):
			for c: String in a.substr(7).split(";"):
				var kv := c.split(":")
				var n: Array = Array(kv[1].split(",")).map(func(v: String) -> float: return float(v))
				cams[kv[0]] = [Vector3(n[0], n[1], n[2]), Vector3(n[3], n[4], n[5])]
		elif a.begins_with("--center="):
			var c := a.substr(9).split(",")
			center = Vector2(float(c[0]), float(c[1]))
	_run.call_deferred()


func _run() -> void:
	root.get_window().size = Vector2i(1400, 1400)
	BootIntentScript.driven = true
	BootIntentScript.request_new_game()
	change_scene_to_file("res://world/ranch.tscn")
	var ranch: Node = null
	for i in 900:
		await process_frame
		ranch = current_scene
		if ranch != null and bool(ranch.get("boot_done")):
			break
	for i in 30:
		await process_frame
	var cs: Node = ranch.get("creation_screen")
	if cs != null and bool(cs.call("is_open")):
		cs.call("confirm")
	var lp: Node = ranch.get("letter_panel")
	if lp != null and bool(lp.call("is_open")):
		lp.call("close")
	paused = false
	if pens:
		var plot: PlotData = load("res://data/plots/pen_small.tres")
		for slot: Node in ranch.call("_plot_slots"):
			slot.call("set_overgrown", false)
			if slot.call("get_built") == null:
				slot.call("build", plot)
		for i in 10:
			await process_frame
	for b in ranch.get_node("Buildings").get_children():
		if b is Node3D:
			var box := AABB()
			var first := true
			for m: MeshInstance3D in (b as Node).find_children("*", "MeshInstance3D", true, false):
				if not m.is_visible_in_tree():
					continue
				var a: AABB = m.global_transform * m.get_aabb()
				box = a if first else box.merge(a)
				first = false
			print("BLD %s at %s aabb_min %s size %s" % [b.name, str((b as Node3D).global_position.snapped(Vector3.ONE*0.1)), str(box.position.snapped(Vector3.ONE*0.1)), str(box.size.snapped(Vector3.ONE*0.1))])
	var player: Node = ranch.get("player")
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var hud := ranch.get_node_or_null(^"HUD") as CanvasLayer
	if hud != null:
		hud.visible = false
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = size
	ranch.add_child(cam)
	cam.global_position = Vector3(center.x, 160, center.y)
	cam.far = 400.0
	cam.rotation_degrees = Vector3(-90, 0, 0)
	for k in 6:
		cam.make_current()
		await process_frame
	root.get_texture().get_image().save_png(out.path_join("topdown.png"))
	print("SHOT topdown")
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 70.0
	var t: Node = ranch.get("terrain")
	if not cams.is_empty():
		cam.fov = 60.0
		if time != "":
			var WS: GDScript = load("res://systems/world_state.gd")
			var phase: int = {"dusk": WS.Phase.DUSK, "night": WS.Phase.NIGHT, "nightrain": WS.Phase.NIGHT,
				"fog": WS.Phase.DAY}.get(time, WS.Phase.DAY)
			var weather: int = WS.Weather.RAIN if time == "nightrain" else (WS.Weather.FOG
				if time == "fog" and "FOG" in WS.Weather else WS.Weather.CLEAR)
			var w: Object = ranch.get("_world")
			w.call("pin", phase, weather)
			var sky: Node = ranch.get("sky_rig")
			if sky != null and sky.has_method("apply_immediately"):
				sky.call("apply_immediately", w)
			var lamps: Node = ranch.get_node_or_null(^"NightLights")
			if lamps != null:
				lamps.call("set_level", 1.0 if time.begins_with("night") else 0.0)
			for i in 20:
				await process_frame
		for k: String in cams:
			cam.global_position = cams[k][0]
			cam.look_at(cams[k][1])
			for i in 4:
				cam.make_current()
				await process_frame
			root.get_texture().get_image().save_png(out.path_join("%s.png" % k))
			print("SHOT ", k)
		quit(0)
		return
	for v in [["north", Vector3(1.75, 0, -1.0), Vector3(1.75, 0, -20)], ["east", Vector3(4.0, 0, -3.0), Vector3(20, 0, -3)], ["west", Vector3(-1.0, 0, -3.0), Vector3(-20, 0, -3)], ["northwest", Vector3(-2.0, 0, 2.0), Vector3(-15, 0, -14)], ["northeast", Vector3(5.0, 0, 2.0), Vector3(14, 0, -12)]]:
		var at: Vector3 = v[1]
		at.y = float(t.call("height_at", at.x, at.z)) + 2.2
		cam.global_position = at
		cam.look_at(Vector3(v[2].x, at.y + 1.5, v[2].z))
		for k in 3:
			cam.make_current()
			await process_frame
		root.get_texture().get_image().save_png(out.path_join("street_%s.png" % v[0]))
		print("SHOT street_", v[0])
	quit(0)
