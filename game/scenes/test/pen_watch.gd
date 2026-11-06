extends SceneTree
## A full pen in the real ranch, filmed from above (PT1/PT4: Twilight rolled in a crowded pen).
##   xvfb-run ... godot --display-driver x11 --path game -s res://scenes/test/pen_watch.gd -- --out=/abs/dir [--plot=pen_small] [--seconds=20] [--night]
const BootIntentScript := preload("res://world/boot_intent.gd")
const WorldStateScript := preload("res://systems/world_state.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const BodySpaceScript := preload("res://systems/body_space.gd")
const CAST := [&"twilight", &"fluttershy", &"rarity", &"applejack", &"rainbowdash", &"pinkiepie",
	&"derpyhooves", &"applebloom"]
var out := ""
var plot_id := "pen_grand"
var seconds := 20.0
var night := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--plot="):
			plot_id = a.substr(7)
		elif a.begins_with("--seconds="):
			seconds = float(a.substr(10))
		elif a == "--night":
			night = true
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	root.get_window().size = Vector2i(960, 720)
	BootIntentScript.driven = true
	BootIntentScript.request_new_game()
	change_scene_to_file("res://world/ranch.tscn")
	var ranch: Node = null
	for i in 900:
		await process_frame
		ranch = current_scene
		if ranch != null and ranch.get("people") != null and i > 30:
			break
	for i in 60:
		await process_frame
	var cs: Node = ranch.get("creation_screen")
	if cs != null and bool(cs.call("is_open")):
		cs.call("confirm")
	var lp: Node = ranch.get("letter_panel")
	if lp != null and bool(lp.call("is_open")):
		lp.call("close")
	paused = false
	var w: Object = ranch.get("_world")
	if w != null:
		w.call("pin", WorldStateScript.Phase.NIGHT if night else WorldStateScript.Phase.DAY, WorldStateScript.Weather.CLEAR)
	var plot: PlotData = null
	for p: PlotData in ranch.call("plots_catalogue").all():
		if String(p.id) == plot_id:
			plot = p
	var slot: PlotSlot = (ranch.call("plot_slots") as Array)[0]
	if slot.is_empty():
		slot.build(plot)
	var pen := slot.get_built() as Pen
	var n := 0
	for id: StringName in CAST:
		if pen.is_full():
			break
		if pen.add_pony(PonyInstanceScript.create(id)):
			n += 1
	print("PEN residents=", n, " cap=", plot.capacity)
	var hud := ranch.get_node_or_null(^"HUD") as CanvasLayer
	if hud != null:
		hud.visible = false
	var cam := Camera3D.new()
	cam.fov = 60.0
	ranch.add_child(cam)
	var c := slot.global_position
	var eyes := [c + Vector3(0, 9, 7), c + Vector3(7, 4, 0), c + Vector3(-6, 3, -6)]
	var frames := int(seconds * 60.0)
	var shot := 0
	for f in frames:
		if f % 30 == 0:
			var e: Vector3 = eyes[shot % eyes.size()]
			cam.global_position = e
			cam.look_at(c + Vector3(0, 0.5, 0), Vector3.UP)
			cam.make_current()
		await process_frame
		if f % 30 == 29:
			root.get_texture().get_image().save_png(out.path_join("p_%03d.png" % shot))
			shot += 1
		if f % 120 == 119:
			var bodies: Array = []
			for inst: PonyInstance in pen.ponies():
				var b := pen.body_for(inst.uid)
				if b != null:
					bodies.append(b)
			var worst := 0.0
			var worst_pair := ""
			for i in bodies.size():
				for j in range(i + 1, bodies.size()):
					var o: float = BodySpaceScript.overlap(BodySpaceScript.footprint_of(bodies[i]), BodySpaceScript.footprint_of(bodies[j]))
					if o > worst:
						worst = o
						worst_pair = "%s/%s" % [bodies[i].name, bodies[j].name]
			print("OVERLAP t=%.0fs worst=%.2f %s n=%d" % [f / 60.0, worst, worst_pair, bodies.size()])
			for b: Node3D in bodies:
				if worst_pair.contains(String(b.name)):
					var fp: Dictionary = BodySpaceScript.footprint_of(b)
					print("   ", b.name, " at=", b.global_position, " room=", BodySpaceScript.push_on(b), " state=", b.get("state"), " wall=", (b as CharacterBody3D).is_on_wall(), " detail=", b.get("detail"), " fp=", fp)
	print("PENWATCH_OK")
	quit()
