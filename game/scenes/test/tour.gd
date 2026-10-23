extends SceneTree
## THE VISUAL REVIEW TOUR (tools/tour.sh): the real game, rendered on the real GPU, walked
## round a fixed list of viewpoints so every major scene can be looked at side by side:
## the creator, the homestead by day, dusk, night and rain, the town, each region, the Strip
## and the Palace, the pens full, a herd of generated ponies, both tones (cozy and the
## Factory path's grey), the Rescue path's pylon and corral, the ending flyover, and the
## Rainbow Factory's rooms. One PNG per view into --out (default build/review).
##
##   tools/bin/godot --path game --audio-driver Dummy -s res://scenes/test/tour.gd -- \
##       [--out=/abs/dir] [--only=homestead_day,regions] [--size=1920x1080]
##
## Prints TOUR_OK <count> at the end.

const RANCH := "res://world/ranch.tscn"
const FACTORY := "res://world/factory.tscn"
const BootIntentScript := preload("res://world/boot_intent.gd")
const WorldStateScript := preload("res://systems/world_state.gd")
const GeneratorScript := preload("res://systems/pony_generator.gd")
const StoryV1Script := preload("res://systems/story_v1.gd")
const FactoryRunScript := preload("res://world/factory_run.gd")
const EndingsScript := preload("res://systems/endings.gd")

var out := ""
var only: PackedStringArray = []
var size := Vector2i(1920, 1080)
var ranch: Node
var cam: Camera3D
var shots := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--only="):
			only = a.substr(7).split(",")
		elif a.begins_with("--size="):
			var p := a.substr(7).split("x")
			size = Vector2i(int(p[0]), int(p[1]))
	if out == "":
		out = ProjectSettings.globalize_path("res://").path_join("../build/review")
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _want(name: String) -> bool:
	return only.is_empty() or name in only or name.get_slice("_", 0) in only


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	var path := out.path_join(name + ".png")
	img.save_png(path)
	shots += 1
	print("TOUR_SHOT %s" % path)


func _run() -> void:
	root.get_window().size = size
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	BootIntentScript.driven = true
	BootIntentScript.request_new_game()
	change_scene_to_file(RANCH)
	for i in 600:
		await process_frame
		ranch = current_scene
		if ranch != null and ranch.get("people") != null and i > 30:
			break
	await _frames(40)
	var cs: Node = ranch.get("creation_screen")
	if cs != null and bool(cs.call("is_open")):
		if _want("creator"):
			await _frames(30)
			await _shot("creator_start")
			cs.call("cycle_coat", 4)
			cs.call("cycle_mane", 3)
			cs.call("cycle_mane_style", 1)
			await _frames(30)
			await _shot("creator_changed")
		cs.call("confirm")
	await _frames(10)
	var lp: Node = ranch.get("letter_panel")
	if lp != null and bool(lp.call("is_open")):
		if _want("letter"):
			await _frames(20)
			await _shot("letter_welcome")
		lp.call("close")
	paused = false
	await _frames(20)
	await _ranch_tour()
	await _factory_tour()
	print("TOUR_OK %d" % shots)
	quit(0)


# --- the ranch -------------------------------------------------------------------------

func _world() -> Object:
	return ranch.get("_world")


func _pin(phase: int, weather: int) -> void:
	var w: Object = _world()
	if w != null:
		w.call("pin", phase, weather)
		# The sky eases between phases over seconds; a still frame wants it already there.
		var sky: Node = ranch.get("sky_rig")
		if sky != null and sky.has_method("apply_immediately"):
			sky.call("apply_immediately", w)
	await _frames(20)


func _height(x: float, z: float) -> float:
	var terrain: Node = ranch.get("terrain")
	return float(terrain.call("height_at", x, z)) if terrain != null else 0.0


func _view(from: Vector3, at: Vector3, fov: float = 55.0) -> void:
	if cam == null or not is_instance_valid(cam):
		cam = Camera3D.new()
		ranch.add_child(cam)
	cam.fov = fov
	# A clear line to what the shot is of: climb (and step back) until nothing solid is in
	# the way, so a bush or a hill beside the camera never fills the frame.
	var space: PhysicsDirectSpaceState3D = (ranch as Node3D).get_world_3d().direct_space_state
	var p := from
	for i in 10:
		var q := PhysicsRayQueryParameters3D.create(p, at)
		q.collision_mask = 0b11
		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty() or (hit.position as Vector3).distance_to(at) < 3.0:
			break
		p += Vector3(0, 2.5, 0) + (p - at).normalized() * 0.5
	cam.global_position = p
	cam.look_at(at)
	cam.make_current()


func _hud(on: bool) -> void:
	var hud := ranch.get_node_or_null(^"HUD") as CanvasLayer
	if hud != null:
		hud.visible = on


func _ranch_tour() -> void:
	_hud(false)
	if _want("homestead"):
		for v in [["homestead_day", WorldStateScript.Phase.DAY, WorldStateScript.Weather.CLEAR],
				["homestead_dawn", WorldStateScript.Phase.DAWN, WorldStateScript.Weather.CLEAR],
				["homestead_dusk", WorldStateScript.Phase.DUSK, WorldStateScript.Weather.CLEAR],
				["homestead_night", WorldStateScript.Phase.NIGHT, WorldStateScript.Weather.CLEAR],
				["homestead_rain", WorldStateScript.Phase.DAY, WorldStateScript.Weather.RAIN]]:
			await _pin(v[1], v[2])
			_view(Vector3(14, _height(14, 30) + 7, 30), Vector3(-1, 1.5, 0))
			await _frames(30)
			await _shot(v[0])
	await _pin(WorldStateScript.Phase.DAY, WorldStateScript.Weather.CLEAR)
	if _want("town"):
		_view(Vector3(9, 4.5, 12), Vector3(-1, 1.8, -1), 60.0)
		await _frames(30)
		await _shot("town_market")
		_view(Vector3(16, 3.5, 2), Vector3(9, 1.5, 3), 60.0)
		await _frames(20)
		await _shot("town_depot_mailbox")
	if _want("gameplay"):
		_hud(true)
		var pcam: Camera3D = ranch.get("player").get_camera_pivot().get_node("CameraRig").call("get_camera")
		pcam.make_current()
		await _frames(40)
		await _shot("gameplay_hud")
		_hud(false)
	if _want("pens"):
		await _fill_pens()
		_view(Vector3(-2, 7, 26), Vector3(-14, 0.5, 12), 55.0)
		await _frames(40)
		await _shot("pens_full")
		_view(Vector3(-6, 2.2, 10.5), Vector3(-9.5, 0.6, 8.5), 50.0)
		await _frames(30)
		await _shot("pens_close")
	if _want("herd"):
		await _herd()
	if _want("regions"):
		var reg: RegionRegistry = ranch.call("_regions_registry")
		for r: RegionData in reg.all():
			var c := r.centre
			var h := _height(c.x, c.y)
			_view(Vector3(c.x + 20, h + 11, c.y + 20), Vector3(c.x, h + 1, c.y), 58.0)
			await _frames(40)
			await _shot("region_" + String(r.id))
	if _want("palace"):
		_view(Vector3(14, _height(14, 84) + 6, 84), Vector3(-6, 3, 64), 60.0)
		await _frames(30)
		await _shot("palace_strip")
	if _want("tone"):
		var tone: Node = ranch.get("world_tone")
		if tone != null:
			for d in [0.3, 0.6, 0.9]:
				tone.call("set_target", d)
				for i in 120:
					await process_frame
				_view(Vector3(14, _height(14, 30) + 7, 30), Vector3(-1, 1.5, 0))
				await _frames(10)
				await _shot("tone_dread_%02d" % int(d * 10))
			tone.call("set_target", 0.0)
			for i in 120:
				await process_frame
	if _want("rescue"):
		await _rescue_views()
	if _want("ending"):
		await _ending_views()


func _fill_pens() -> void:
	var gs: Node = root.get_node("GameState")
	var plot: PlotData = load("res://data/plots/pen_large.tres") if ResourceLoader.exists("res://data/plots/pen_large.tres") else null
	var slots: Array = ranch.call("_plot_slots")
	for i in mini(2, slots.size()):
		var slot: Node = slots[i]
		if slot.call("get_built") == null and plot != null:
			slot.call("build", plot)
	await _frames(10)
	var beam: Node = ranch.get("player").get_magic_beam()
	var bag: Storage = beam.call("get_storage")
	var n := 0
	for i in mini(2, slots.size()):
		for k in 5:
			var inst := PonyInstance.create(&"stock_shy", 9000 + n)
			inst.stock = GeneratorScript.generate(3100 + n * 13).to_dict()
			n += 1
			if bag.store(inst):
				ranch.call("_move_pony_into_pen", slots[i])
	await _frames(60)


## A lineup of generated Drifters, stood in the grass by the homestead.
func _herd() -> void:
	var data: PonyData = load("res://data/hidden/stock_curious.tres")
	var root3: Node3D = Node3D.new()
	ranch.add_child(root3)
	for i in 14:
		var p: CharacterBody3D = (load("res://actors/pony/pony.tscn") as PackedScene).instantiate()
		var x := 26.0 + float(i % 7) * 2.3
		var z := 4.0 + float(i / 7) * 3.2
		p.position = Vector3(x, _height(x, z) + 0.05, z)
		root3.add_child(p)
		var opts := {}
		if i == 3 or i == 10:
			opts["foal"] = true
		p.set_stock(GeneratorScript.generate(777 + i * 31, opts).to_dict())
		p.setup(data)
		p.set_physics_process(false)
		(p.get_node("Visuals") as Node3D).rotation.y = deg_to_rad(200.0 + i * 7.0)
	await _frames(60)
	_view(Vector3(33, _height(33, 15) + 2.6, 15.5), Vector3(33, _height(33, 5) + 0.7, 5.5), 50.0)
	await _frames(20)
	await _shot("herd_generated")
	root3.queue_free()


func _rescue_views() -> void:
	var gs: Node = root.get_node("GameState")
	var story: Story = gs.get("story")
	StoryV1Script.choose_path(story, "rescue")
	await _frames(30)
	ranch.call("_setup_act3")
	await _frames(30)
	var act3: Node = ranch.get("act3")
	if act3 == null:
		return
	await _pin(WorldStateScript.Phase.NIGHT, WorldStateScript.Weather.CLEAR)
	for s: Dictionary in act3.get("sites"):
		if str(s.kind) in ["pylon", "corral", "gate", "vat"] and (str(s.id).ends_with("orchard") or str(s.kind) in ["gate", "vat"]):
			var n: Node3D = s.node
			var at := n.global_position
			_view(at + Vector3(8, 4.5, 8), at + Vector3(0, 1.5, 0), 55.0)
			await _frames(40)
			await _shot("rescue_" + str(s.id))
	await _pin(WorldStateScript.Phase.DAY, WorldStateScript.Weather.CLEAR)


func _ending_views() -> void:
	ranch.set("_interactive", true)
	var gs: Node = root.get_node("GameState")
	var story: Story = gs.get("story")
	for e in [EndingsScript.LIGHTS_OUT, EndingsScript.BRIGHTEST_RAINBOW]:
		story.set_var("ending", "")
		ranch.call("play_ending", e)
		var ep: Node = ranch.get("epilogue")
		for t in [3.0, 9.0]:
			var until := Time.get_ticks_msec() + int(t * 1000.0)
			while Time.get_ticks_msec() < until:
				await process_frame
			await _shot("ending_%s_%02ds" % [String(e), int(t)])
		if ep != null and is_instance_valid(ep):
			ep.call("advance")
			await _frames(90)
			await _shot("ending_%s_letter" % String(e))
			ep.call("advance")
			await _frames(200)
			await _shot("ending_%s_credits" % String(e))
			ep.call("advance")
		await _frames(30)
	paused = false


# --- the Rainbow Factory ------------------------------------------------------------------

func _factory_tour() -> void:
	if not _want("factory"):
		return
	root.get_node("GameState").call("save_to_slot")
	FactoryRunScript.mode = &"reveal"
	change_scene_to_file(FACTORY)
	await _frames(120)
	var f := current_scene
	var interior: Node = f.get("interior")
	if interior == null:
		return
	var c := Camera3D.new()
	c.fov = 70
	f.add_child(c)
	for room in ["landing", "welcome", "classroom", "giftshop", "walkway", "gallery", "holding", "control"]:
		var o: Vector3 = interior.call("room_origin", StringName(room))
		c.global_position = o + Vector3(4.5, 2.4, 5.0)
		c.look_at(o + Vector3(-2, 1.4, -4))
		c.make_current()
		await _frames(40)
		await _shot("factory_" + room)
