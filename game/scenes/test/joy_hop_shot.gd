extends SceneTree
## ITEMS 19/23 RENDER: a pen of happy ponies in the real ranch, filmed from where the player
## stands beside it; a frame each time a resident's rump bounce peaks (a hop for joy), and how
## many hops there were in the time.
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
	var cam := Camera3D.new()
	cam.fov = 55.0
	ranch.add_child(cam)
	var c := slot.global_position
	cam.global_position = c + Vector3(0, 2.6, 9.0)
	cam.look_at(c + Vector3(0, 0.8, 0), Vector3.UP)
	cam.make_current()
	var springs: Array = []
	for inst: PonyInstance in pen.ponies():
		var b := pen.body_for(inst.uid)
		if b != null:
			springs.append(b.find_children("RumpBounce", "", true, false)[0])
	var shots := 0
	var peaks := 0
	var resting := {}
	# Close on the first resident: at rest, then at the top of her next bounce.
	var first: Node3D = null
	for inst: PonyInstance in pen.ponies():
		first = pen.body_for(inst.uid)
		break
	var close_rest := false
	var close_peak := false
	for f in int(seconds * 60.0):
		await process_frame
		for sp in springs:
			var a := absf(float(sp.call("amount")))
			var key: int = sp.get_instance_id()
			# A hop is a rise from rest, not every wobble of one.
			if a < 0.004:
				resting[key] = true
			elif a > 0.035 and resting.get(key, true):
				resting[key] = false
				peaks += 1
				if shots < 4:
					root.get_texture().get_image().save_png(out.path_join("hop_%02d.png" % shots))
					shots += 1
		if first != null and f > 120 and (not close_rest or not close_peak):
			var sp0: Node = first.find_children("RumpBounce", "", true, false)[0]
			var a0 := absf(float(sp0.call("amount")))
			var want_rest := not close_rest and a0 < 0.002
			var want_peak := close_rest and not close_peak and a0 > 0.06
			if want_rest or want_peak:
				var side := (cam.global_position - first.global_position)
				side.y = 0.0
				var cc := Camera3D.new()
				ranch.add_child(cc)
				cc.global_position = first.global_position + side.normalized() * 3.2 + Vector3(0, 1.3, 0)
				cc.look_at(first.global_position + Vector3(0, 0.9, 0))
				cc.make_current()
				await process_frame
				root.get_texture().get_image().save_png(out.path_join("close_%s.png" % ("rest" if want_rest else "peak")))
				cam.make_current()
				cc.free()
				if want_rest:
					close_rest = true
				else:
					close_peak = true
	print("JOY_HOPS hops=", peaks, " in ", seconds, " s, residents=", springs.size())
	quit()
