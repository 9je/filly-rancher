extends SceneTree
## ITEM 17 PROBE (PLAN.md PS1): Twilight twisted at a broken angle [21][52]. Puts the Mane Six
## in the ranch through the owner's chain of events and measures, every frame, how far each
## body bone (root, hip, spine, chest, neck, head) has turned from its rest pose, and how far
## her body leans off upright. Saves a frame the first time a pony passes TWIST_DEG, and
## prints the worst per pony per scene. Scenes: wild on the slopes with the player walking at
## her (startle, flee); held, lifted 3 m and dropped; a full Paddock of the Mane Six.
##   xvfb-run ... godot --display-driver x11 --path game -s <this> -- --out=/abs/dir

const BootIntentScript := preload("res://world/boot_intent.gd")
const PonyScene := preload("res://actors/pony/pony.tscn")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const TWIST_DEG := 50.0
const BODY_WORDS := ["root", "hip", "pelvis", "spine", "chest", "torso", "neck", "head"]
const MANE6 := [&"twilight", &"rarity", &"pinkiepie", &"rainbowdash", &"applejack", &"fluttershy"]

var out := ""
var ranch: Node
var shots := 0
var worst := {}
var saved := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	root.get_window().size = Vector2i(1280, 720)
	BootIntentScript.driven = true
	BootIntentScript.request_new_game()
	change_scene_to_file("res://world/ranch.tscn")
	for i in 900:
		await process_frame
		ranch = current_scene
		if ranch != null and bool(ranch.get("boot_done")):
			break
	var cs: Node = ranch.get("creation_screen")
	if cs != null and bool(cs.call("is_open")):
		cs.call("confirm")
	var lp: Node = ranch.get("letter_panel")
	if lp != null and bool(lp.call("is_open")):
		lp.call("close")
	paused = false
	var player: CharacterBody3D = ranch.get("player")
	var reg: PonyRegistry = root.get_node(^"GameState").call("get_registry")

	if OS.get_cmdline_user_args().has("--pen-only"):
		await _pen_only(player)
		return
	# 1. Wild, on the slopes west of the plaza, the player walking straight at each in turn.
	var wild: Array[Node3D] = []
	for i in MANE6.size():
		var p := PonyScene.instantiate()
		ranch.add_child(p)
		p.call("setup", reg.by_id(MANE6[i]))
		var at := Vector3(-30.0 + i * 2.5, 0.0, 20.0 + (i % 2) * 2.0)
		at.y = _h(at.x, at.z) + 0.3
		p.global_position = at
		wild.append(p)
	for f in 1200:
		var target: Node3D = wild[(f / 200) % wild.size()]
		var to := target.global_position - player.global_position
		to.y = 0.0
		if to.length() > 1.5:
			player.global_position += to.normalized() * 0.08
			player.global_position.y = _h(player.global_position.x, player.global_position.z) + 0.1
		await physics_frame
		await _measure("wild", wild)

	# 2. Held, lifted 3 m and dropped, each in turn, twice.
	for round in 2:
		for p: Node3D in wild:
			p.call("set_held", true)
			var start := p.global_position
			for f in 90:
				p.global_position = start + Vector3(0, 3.0 * minf(1.0, f / 40.0), 0)
				p.rotation.y += 0.9 / 60.0
				await physics_frame
				await _measure("held", [p])
			p.rotation.y = 0.0
			p.call("set_held", false)
			for f in 120:
				await physics_frame
				await _measure("dropped", [p])

	# 3. A full Paddock of the Mane Six, for two minutes.
	for p: Node3D in wild:
		p.queue_free()
	var slot: PlotSlot = null
	for s: PlotSlot in ranch.call("plot_slots"):
		if not s.is_overgrown() and s.is_empty():
			slot = s
			break
	var cat: PlotRegistry = ranch.call("_plots_catalogue")
	slot.build(cat.by_id(&"pen_grand"))
	for f in 10:
		await physics_frame
	var pen := slot.get_built() as Pen
	var k := 0
	while not pen.is_full():
		pen.add_pony(PonyInstanceScript.create(MANE6[k % MANE6.size()]))
		k += 1
	var cam := Camera3D.new()
	ranch.add_child(cam)
	cam.global_position = pen.global_position + Vector3(0, 9, 7)
	cam.look_at(pen.global_position)
	cam.make_current()
	for f in 7200:
		await physics_frame
		var bodies: Array[Node3D] = []
		for inst: PonyInstance in pen.ponies():
			var b := pen.body_for(inst.uid)
			if b != null:
				bodies.append(b)
		await _measure("pen", bodies)
		if f % 1800 == 0:
			await _save("pen_t%d" % (f / 60))
	await _save("pen_end")
	for key: String in worst:
		print("TWIST %s %s" % [key, worst[key]])
	print("TWIST_PROBE_DONE shots=%d" % shots)
	quit(0)


## Per pony: the torso's turn from its rest (deg), the head's turn against the torso beyond
## its rest (deg), and the body's lean off upright (deg).
func _measure(scene: String, bodies: Array) -> void:
	for p: Node3D in bodies:
		if not is_instance_valid(p):
			continue
		var visuals := p.get_node_or_null(^"Visuals") as Node3D
		var lean := rad_to_deg(visuals.global_basis.y.normalized().angle_to(Vector3.UP)) if visuals != null else 0.0
		var sk := _skeleton(p)
		var torso := 0.0
		var head := 0.0
		if sk != null:
			var c := _bone(sk, ["DEF_Chest1", "DEF_Chest", "Spine2", "Spine1", "Spine", "DEF_Hip", "Pelvis"])
			var h := _bone(sk, ["DEF_Head", "Head"])
			if c >= 0:
				var cr := sk.get_bone_global_rest(c).basis.get_rotation_quaternion()
				var cp := sk.get_bone_global_pose(c).basis.get_rotation_quaternion()
				torso = _deg(cr.inverse() * cp)
				if h >= 0:
					var hr := sk.get_bone_global_rest(h).basis.get_rotation_quaternion()
					var hp := sk.get_bone_global_pose(h).basis.get_rotation_quaternion()
					head = _deg((cr.inverse() * hr).inverse() * (cp.inverse() * hp))
		var who := String(p.call("get_data").id) if p.has_method("get_data") and p.call("get_data") != null else String(p.name)
		var key := "%s/%s" % [scene, who]
		var w: Dictionary = worst.get(key, {"torso": 0.0, "head": 0.0, "lean": 0.0})
		for pair in [["torso", torso], ["head", head], ["lean", lean]]:
			if float(pair[1]) > float(w[pair[0]]):
				w[pair[0]] = snappedf(float(pair[1]), 0.1)
		worst[key] = w
		if (torso > 40.0 or head > 70.0 or lean > 25.0) and not saved.has(key):
			saved[key] = true
			await _shoot_at(p, "%s_%s_t%d_h%d_l%d" % [scene, who, int(torso), int(head), int(lean)])


func _deg(q: Quaternion) -> float:
	var d := rad_to_deg(q.normalized().get_angle())
	return 360.0 - d if d > 180.0 else d


func _bone(sk: Skeleton3D, names: Array) -> int:
	for n: String in names:
		var i := sk.find_bone(n)
		if i >= 0:
			return i
	return -1


func _shoot_at(p: Node3D, name: String) -> void:
	var player: Node = ranch.get("player")
	var prev := root.get_viewport().get_camera_3d()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var cam := Camera3D.new()
	ranch.add_child(cam)
	cam.global_position = p.global_position + Vector3(2.2, 1.6, 2.2)
	cam.look_at(p.global_position + Vector3(0, 0.6, 0))
	cam.make_current()
	await _save(name)
	player.process_mode = Node.PROCESS_MODE_INHERIT
	if prev != null:
		prev.make_current()
	cam.queue_free()


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	shots += 1


func _skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var s := _skeleton(c)
		if s != null:
			return s
	return null


func _h(x: float, z: float) -> float:
	return float(ranch.get("terrain").call("height_at", x, z))


func _pen_only(player: Node3D) -> void:
	var w: Object = ranch.get("_world")
	w.call("pin", 3, 1)
	var sky: Node = ranch.get("sky_rig")
	sky.call("apply_immediately", w)
	var slot: PlotSlot = null
	for s: PlotSlot in ranch.call("plot_slots"):
		if not s.is_overgrown() and s.is_empty():
			slot = s
			break
	slot.build((ranch.call("_plots_catalogue") as PlotRegistry).by_id(&"pen_grand"))
	for f in 10:
		await physics_frame
	var pen := slot.get_built() as Pen
	var k := 0
	while not pen.is_full():
		pen.add_pony(PonyInstanceScript.create(MANE6[k % MANE6.size()]))
		k += 1
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var cam := Camera3D.new()
	ranch.add_child(cam)
	cam.global_position = pen.global_position + Vector3(0, 7, 6)
	cam.look_at(pen.global_position)
	cam.make_current()
	for f in 5400:
		await physics_frame
		var bodies: Array[Node3D] = []
		for inst: PonyInstance in pen.ponies():
			var b := pen.body_for(inst.uid)
			if b != null:
				bodies.append(b)
		_measure_quiet("pen_night", bodies)
		if f % 900 == 0:
			await _save("grand_night_t%d" % (f / 60))
	for key: String in worst:
		print("TWIST %s %s" % [key, worst[key]])
	print("TWIST_PROBE_DONE shots=%d" % shots)
	quit(0)


func _measure_quiet(scene: String, bodies: Array) -> void:
	var keep := saved.duplicate()
	for p in bodies:
		saved["%s/%s" % [scene, String(p.call("get_data").id)]] = true
	await _measure(scene, bodies)
	saved = keep
