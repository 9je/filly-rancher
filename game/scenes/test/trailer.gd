extends SceneTree
## THE TRAILER STAGE (TRAILER_PLAN.md, tools/trailer/capture.sh). One shot a run: the real
## game, set up for the shot (time of day, weather, dread, who stands where), then either a
## scripted camera move or the player's own verbs played through the real input actions, for
## exactly the shot's length. Run under Movie Maker:
##
##   tools/bin/godot --path game --audio-driver Dummy --write-movie OUT.avi --fixed-fps 60 \
##       --resolution 3840x2160 -s res://scenes/test/trailer.gd -- --shot=catch [--take=1]
##
## Prints TRAILER_SHOT_START <frame> when the shot proper begins (everything before it is boot
## and set-up, which the edit trims), and TRAILER_SHOT_END <frame> when it ends.

const RANCH := "res://world/ranch.tscn"
const FACTORY := "res://world/factory.tscn"
const BootIntentScript := preload("res://world/boot_intent.gd")
const WorldStateScript := preload("res://systems/world_state.gd")
const GeneratorScript := preload("res://systems/pony_generator.gd")
const FactoryRunScript := preload("res://world/factory_run.gd")
const PonyScene := preload("res://actors/pony/pony.tscn")
const PonyTraitsScript := preload("res://systems/pony_traits.gd")

var shot := "catch"
var take := 1
var ranch: Node
var cam: Camera3D
var _shot_frames := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot = a.substr(7)
		elif a.begins_with("--take="):
			take = int(a.substr(7))
	_run.call_deferred()


# --- the stage --------------------------------------------------------------------------

func _run() -> void:
	seed(1000 * take + hash(shot))
	if shot.begins_with("factory_"):
		await _boot_factory()
	else:
		await _boot_ranch()
	await _frames(30)
	print("TRAILER_SIZES window=%s viewport=%s screen=%s" % [DisplayServer.window_get_size(),
		root.get_viewport().get_visible_rect().size, DisplayServer.screen_get_size()])
	print("TRAILER_SHOT_START %d" % Engine.get_frames_drawn())
	_shot_frames = Engine.get_frames_drawn()
	match shot:
		"catch":
			await _shot_catch()
		"bloom":
			await _shot_bloom(&"ranch")
		"bloom2":
			await _shot_bloom(&"second")
		"valley":
			await _shot_valley(0.0)
		"launch":
			await _shot_launch()
		"treat":
			await _shot_treat()
		"gems":
			await _shot_gems()
		"herd":
			await _shot_herd()
		"creator":
			await _shot_creator()
		"everfree":
			await _shot_everfree()
		"lake":
			await _shot_lake()
		"meadow":
			await _shot_meadow()
		"whistle":
			await _shot_whistle()
		"orchard":
			await _shot_orchard()
		"slots":
			await _shot_slots()
		"dusk":
			await _shot_dusk()
		"delivery":
			await _shot_delivery()
		"tumble":
			await _shot_tumble()
		"lift":
			await _shot_lift()
		"valley_grey":
			await _shot_valley(0.8)
		"dawn":
			await _shot_dawn()
		"factory_hall":
			await _shot_factory_room(&"welcome", 3.0)
		"factory_walkway":
			await _shot_factory_room(&"walkway", 3.0)
		"factory_tank":
			await _shot_factory_tank()
		_:
			printerr("TRAILER: no shot called %s" % shot)
	print("TRAILER_SHOT_END %d" % Engine.get_frames_drawn())
	quit(0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _seconds(s: float) -> void:
	await _frames(int(round(s * 60.0)))


## A new ranch past its first ten minutes: the Scoop given, everyone met, nopony waiting to
## say anything, a pen built, a couple of ponies in it. Nothing pops up over a shot.
func _boot_ranch() -> void:
	BootIntentScript.driven = true
	BootIntentScript.bot = true
	BootIntentScript.request_new_game()
	change_scene_to_file(RANCH)
	for i in 600:
		await process_frame
		ranch = current_scene
		if ranch != null and ranch.get("people") != null and ranch.get("player") != null and i > 20:
			break
	await _frames(20)
	var cs: Node = ranch.get("creation_screen")
	if shot != "creator" and cs != null and bool(cs.call("is_open")):
		cs.call("cycle_coat", 5)
		cs.call("cycle_mane", 3)
		cs.call("confirm")
	await _frames(5)
	var lp: Node = ranch.get("letter_panel")
	if lp != null and bool(lp.call("is_open")):
		lp.call("close")
	var story: Story = root.get_node("GameState").get("story")
	for f in ["has_scoop", "tumble_joined", "met_fennel", "met_bramble", "met_pip", "depot_explained",
			"thanked_first", "fennel_saw_bloom", "saw_fennel_wall", "pip_cloud_line", "bramble_dye",
			"tumble_depot", "marigold_vivid", "palace_open"]:
		story.set_flag(f)
	story.set_var("catches", 12)
	var people: Node = ranch.get("people")
	people.call("populate")
	if people.has_method("is_talking") and bool(people.call("is_talking")):
		people.get("talk_box").call("close")
	ranch.call("_apply_beam_recall") if ranch.has_method("_apply_beam_recall") else null
	paused = false
	# The trailer has its own score: the game's music bus is muted for the take, its sound
	# effects and ambience are kept (the edit mixes them under the score).
	var mb := AudioServer.get_bus_index("Music")
	if mb >= 0:
		AudioServer.set_bus_mute(mb, true)
	_pin(WorldStateScript.Phase.DAY, WorldStateScript.Weather.CLEAR)
	_hud("off")
	await _frames(30)


func _boot_factory() -> void:
	await _boot_ranch()
	root.get_node("GameState").call("save_to_slot")
	FactoryRunScript.mode = &"reveal"
	change_scene_to_file(FACTORY)
	await _frames(90)
	ranch = current_scene
	var hud := ranch.get_node_or_null(^"HUD") as CanvasLayer
	if hud != null:
		hud.visible = false


func _pin(phase: int, weather: int) -> void:
	var w: Object = ranch.get("_world")
	if w == null:
		return
	w.call("pin", phase, weather)
	var sky: Node = ranch.get("sky_rig")
	if sky != null and sky.has_method("apply_immediately"):
		sky.call("apply_immediately", w)


func _dread(d: float) -> void:
	var tone: Node = ranch.get("world_tone")
	if tone != null:
		tone.call("set_target", d)
		if tone.has_method("snap"):
			tone.call("snap")
	ranch.set("_dread_pinned", true)


## "off": no HUD (beauty shots). "min": the bag, the bits and the prompt; nothing else.
func _hud(mode: String) -> void:
	var hud := ranch.get_node_or_null(^"HUD") as CanvasLayer
	if hud == null:
		return
	hud.visible = mode != "off"
	if mode == "min":
		for c in hud.get_children():
			var n := String(c.name)
			if c is CanvasItem:
				(c as CanvasItem).visible = "Bag" in n or "Crosshair" in n or "Prompt" in n
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if DisplayServer.get_name() != "headless" else Input.mouse_mode


func _height(x: float, z: float) -> float:
	var terrain: Node = ranch.get("terrain")
	return float(terrain.call("height_at", x, z)) if terrain != null else 0.0


func _g(x: float, z: float, up: float = 0.0) -> Vector3:
	return Vector3(x, _height(x, z) + up, z)


func _free_cam() -> Camera3D:
	if cam == null or not is_instance_valid(cam):
		cam = Camera3D.new()
		cam.fov = 50.0
		ranch.add_child(cam)
	cam.make_current()
	return cam


## A smooth camera move through `points`, looking through `looks`, over `seconds`
## (Curve3D through both, eased at the ends so it starts and settles gently).
func _move(points: Array, looks: Array, seconds: float, fov: float = 50.0) -> void:
	var c := _free_cam()
	c.fov = fov
	var path := _curve(points)
	var aim := _curve(looks)
	var n := int(round(seconds * 60.0))
	for i in n:
		var f := float(i) / float(maxi(1, n - 1))
		var e := f * f * (3.0 - 2.0 * f)
		c.global_position = path.sample_baked(e * path.get_baked_length(), true)
		c.look_at(aim.sample_baked(e * aim.get_baked_length(), true))
		await process_frame


func _curve(pts: Array) -> Curve3D:
	var cv := Curve3D.new()
	cv.bake_interval = 0.05
	if pts.size() == 1:
		cv.add_point(pts[0])
		cv.add_point(pts[0] + Vector3(0, 0.0001, 0))
		return cv
	for i in pts.size():
		var p: Vector3 = pts[i]
		var prev: Vector3 = pts[maxi(0, i - 1)]
		var next: Vector3 = pts[mini(pts.size() - 1, i + 1)]
		var tan := (next - prev) * 0.25
		cv.add_point(p, -tan, tan)
	return cv


## A wild pony stood where a shot wants her, calm (she will not bolt mid shot unless asked).
func _pony(at: Vector3, seed_value: int, opts: Dictionary = {}, calm: float = 999.0, yaw: float = 0.0) -> CharacterBody3D:
	var spawner: Node = ranch.get("spawner")
	var data: PonyData = load("res://data/hidden/stock_curious.tres")
	var look := GeneratorScript.generate(seed_value, opts)
	var p: CharacterBody3D = spawner.call("spawn_guest", data, look.to_dict(), at, 3.0)
	p.set("calm", calm)
	(p.get_node("Visuals") as Node3D).rotation.y = yaw
	return p


func _player() -> CharacterBody3D:
	return ranch.get("player")


func _rig() -> Node:
	return _player().get_camera_pivot().get_node("CameraRig")


func _player_cam() -> void:
	var c: Camera3D = _rig().call("get_camera")
	c.make_current()


## Turn the player's camera smoothly to look at `at` over `seconds`.
func _aim_at(at: Vector3, seconds: float) -> void:
	var rig := _rig()
	var c: Camera3D = rig.call("get_camera")
	var n := int(round(seconds * 60.0))
	for i in n:
		var d := at - c.global_position
		var yaw_t := atan2(-d.x, -d.z)
		var err := wrapf(yaw_t - (rig as Node3D).global_rotation.y, -PI, PI)
		rig.call("add_look_delta", -err * 0.12, 0.0)
		var flat := Vector2(d.x, d.z).length()
		var pitch_t := rad_to_deg(atan2(d.y, maxf(flat, 0.01)))
		var pe := pitch_t - float(rig.call("get_look_pitch_degrees"))
		rig.call("add_look_delta", 0.0, -deg_to_rad(pe * 0.12))
		await process_frame


func _pen_slot(i: int) -> Node3D:
	return (ranch.call("_plot_slots") as Array)[i]


## Build a Big Pen on plot `i` and fill it with `n` generated Drifters.
func _fill_pen(i: int, n: int, base_seed: int) -> Node:
	var slot := _pen_slot(i)
	if slot.call("get_built") == null:
		slot.call("build", load("res://data/plots/pen_large.tres"))
	await _frames(5)
	var bag: Storage = _player().get_magic_beam().call("get_storage")
	for k in n:
		var inst := PonyInstance.create(&"stock_curious", base_seed + k)
		inst.stock = GeneratorScript.generate(base_seed * 7 + k * 13).to_dict()
		inst.happiness = 0.9
		if bag.store(inst):
			ranch.call("_move_pony_into_pen", slot)
	await _frames(20)
	return slot.call("get_built")


# --- the shots -----------------------------------------------------------------------------

## 1. THE HOOK: the Scoop takes a pony. Over the shoulder, the beam on her, she lifts and
## kicks, and goes into the bag.
func _shot_catch() -> void:
	var pl := _player()
	pl.global_position = _g(6.0, 26.0, 0.2)
	_hud("min")
	var p := _pony(_g(6.0, 20.5), 31 + take, {}, 999.0, PI)
	await _frames(40)
	_player_cam()
	await _aim_at(p.global_position + Vector3(0, 0.55, 0), 0.4)
	Input.action_press(&"beam")
	var beam: Node = pl.get_magic_beam()
	var t := 0
	while t < 150:
		await process_frame
		t += 1
		if is_instance_valid(p):
			_aim_at_now(p.global_position + Vector3(0, 0.55, 0))
		if bool(beam.call("is_holding")) and bool(beam.call("is_secured")) and t > 70:
			break
	Input.action_release(&"beam")
	await _seconds(0.6)


func _aim_at_now(at: Vector3) -> void:
	var rig := _rig()
	var c: Camera3D = rig.call("get_camera")
	var d := at - c.global_position
	var err := wrapf(atan2(-d.x, -d.z) - (rig as Node3D).global_rotation.y, -PI, PI)
	rig.call("add_look_delta", -err * 0.08, 0.0)


## 2. A BLOOM: a penned pony rears, sparkles, and her mark appears.
func _shot_bloom(which: StringName) -> void:
	var pen := await _fill_pen(0, 3, 700 if which == &"ranch" else 900)
	var slot := _pen_slot(0)
	var ponies: Array = pen.call("ponies")
	var star: PonyInstance = ponies[0]
	var body: Node3D = pen.call("body_of", star.uid)
	if body == null:
		return
	body.set_physics_process(false)
	var at := body.global_position
	var side := Vector3(2.6, 1.3, 2.4) if which == &"ranch" else Vector3(-2.4, 1.1, 2.6)
	create_timer(0.35).timeout.connect(func() -> void: pen.call("bloom_now", star))
	await _move([at + side, at + side.rotated(Vector3.UP, 0.5)],
		[at + Vector3(0, 0.9, 0), at + Vector3(0, 1.0, 0)], 2.4, 42.0)


## 3. THE VALLEY: wide and high, a slow rise; the pens, Ponyville, the rainbow.
func _shot_valley(dread: float) -> void:
	if dread > 0.0:
		_dread(dread)
	await _fill_pen(0, 4, 100)
	await _fill_pen(1, 3, 200)
	await _frames(30)
	await _move([_g(26, 44, 7), _g(24, 42, 10)], [_g(-6, -2, 4), _g(-6, -2, 6)], 2.6, 55.0)


func _shot_launch() -> void:
	ranch.get("_game_state").unlocks.append("scoop_launcher")
	ranch.call("_apply_unlocks")
	await _fill_pen(0, 1, 300)
	var pl := _player()
	pl.global_position = _g(2.0, 12.0, 0.2)
	_hud("min")
	var bag: Storage = pl.get_magic_beam().call("get_storage")
	for k in 3:
		var inst := PonyInstance.create(&"stock_curious", 400 + k)
		inst.stock = GeneratorScript.generate(4400 + k * 31).to_dict()
		bag.store(inst)
	_player_cam()
	var target := _pen_slot(0).global_position
	await _aim_at(target, 0.5)
	for k in 2:
		Input.action_press(&"interact")
		await process_frame
		Input.action_release(&"interact")
		await _seconds(0.75)


func _shot_treat() -> void:
	ranch.get("_game_state").unlocks.append("treat_pouch")
	(ranch.get("_game_state").get("inventory") as Inventory).add(&"apple", 6)
	(ranch.get("_game_state").get("inventory") as Inventory).add(&"carrot", 6)
	var pl := _player()
	pl.global_position = _g(10.0, 30.0, 0.2)
	_hud("min")
	var p := _pony(_g(10.0, 22.0), 52, {}, 0.0, 0.4)
	await _frames(30)
	_player_cam()
	await _aim_at(p.global_position + Vector3(0, 0.4, 0), 0.4)
	Input.action_press(&"treat")
	await process_frame
	Input.action_release(&"treat")
	await _seconds(1.6)


func _shot_gems() -> void:
	var pen := await _fill_pen(0, 4, 500)
	var at := _pen_slot(0).global_position
	await _move([at + Vector3(5.5, 2.0, 4.0), at + Vector3(4.0, 1.6, 5.4)], [at + Vector3(0, 0.6, 0)], 2.0, 46.0)


## 8. THE HERD: fourteen generated Drifters in a line, the camera tracking along it.
func _shot_herd() -> void:
	var data: PonyData = load("res://data/hidden/stock_curious.tres")
	var root3 := Node3D.new()
	ranch.add_child(root3)
	for i in 14:
		var p: CharacterBody3D = PonyScene.instantiate()
		var x := 26.0 + float(i) * 1.7
		var z := 6.0 + sin(float(i) * 1.3) * 0.6
		p.position = Vector3(x, _height(x, z) + 0.05, z)
		root3.add_child(p)
		var opts := {"foal": true} if i % 5 == 3 else {}
		if i == 9:
			opts["variant"] = &"starry"
		p.set_stock(GeneratorScript.generate(777 + i * 31 + take, opts).to_dict())
		p.setup(data)
		p.set_physics_process(false)
		(p.get_node("Visuals") as Node3D).rotation.y = deg_to_rad(180.0 + randf_range(-20, 20))
	await _frames(40)
	await _move([_g(25, 10.5, 1.4), _g(49, 10.5, 1.6)], [_g(27, 6, 0.8), _g(51, 6, 0.8)], 2.2, 40.0)


func _shot_creator() -> void:
	var cs: Node = ranch.get("creation_screen")
	if cs == null or not bool(cs.call("is_open")):
		await _seconds(2.0)
		return
	for i in 6:
		cs.call("cycle_coat", 1 + i % 3) if i % 2 == 0 else cs.call("cycle_mane", 2)
		await _seconds(0.33)


func _region_centre(id: StringName) -> Vector3:
	var reg: RegionRegistry = ranch.call("_regions_registry")
	var r: RegionData = reg.by_id(id)
	return _g(r.centre.x, r.centre.y)


func _open_permits() -> void:
	for z in ["orchard", "lake", "nightmeadow", "everfree"]:
		ranch.get("_game_state").unlocks.append("permit_" + z)
	ranch.call("_apply_permits")


func _shot_everfree() -> void:
	_open_permits()
	var c := _region_centre(&"everfree")
	ranch.get("_game_state").unlocks.append("gallop_shoes")
	_pin(WorldStateScript.Phase.DUSK, WorldStateScript.Weather.CLEAR)
	await _frames(20)
	await _move([c + Vector3(16, 1.2, 10), c + Vector3(-4, 1.4, 2)], [c + Vector3(6, 1.0, 4), c + Vector3(-14, 1.6, -4)], 2.2, 60.0)


func _shot_lake() -> void:
	_open_permits()
	var c := _region_centre(&"lake")
	for i in 3:
		_pony(c + Vector3(-6 + i * 4, 0.3, 14), 6100 + i, {"race": &"pegasus"} if i == 1 else {}, 999.0, PI * 0.8)
	await _frames(30)
	await _move([c + Vector3(20, 7, 20), c + Vector3(14, 2.0, 20)], [c + Vector3(0, 0, 4), c + Vector3(-2, 0.8, 8)], 2.2, 52.0)


func _shot_meadow() -> void:
	_open_permits()
	var c := _region_centre(&"nightmeadow")
	_pin(WorldStateScript.Phase.NIGHT, WorldStateScript.Weather.CLEAR)
	for i in 3:
		_pony(c + Vector3(-4 + i * 3.5, 0.3, 3 + i), 6300 + i, {"race": &"unicorn"}, 999.0, PI)
	await _frames(30)
	await _move([c + Vector3(14, 3, 14), c + Vector3(9, 2.2, 15)], [c + Vector3(0, 1, 0), c + Vector3(-1, 1.2, 2)], 2.2, 50.0)


func _shot_whistle() -> void:
	ranch.get("_game_state").unlocks.append("pony_whistle")
	var pl := _player()
	pl.global_position = _g(12.0, 30.0, 0.2)
	_hud("min")
	for i in 3:
		_pony(_g(8.0 + i * 3.0, 22.0 + i), 6500 + i, {}, 0.0, PI)
	await _frames(30)
	_player_cam()
	await _aim_at(_g(11, 22, 0.6), 0.3)
	Input.action_press(&"whistle")
	await process_frame
	Input.action_release(&"whistle")
	await _seconds(1.7)


func _shot_orchard() -> void:
	_open_permits()
	var c := _region_centre(&"orchard")
	for i in 4:
		_pony(c + Vector3(-6 + i * 4, 0.3, randf_range(-6, 6)), 6700 + i, {}, 999.0, randf() * TAU)
	await _frames(30)
	await _move([c + Vector3(-12, 14, 16), c + Vector3(4, 13, 18)], [c + Vector3(-4, 0, 0), c + Vector3(4, 0, 0)], 2.2, 50.0)


func _shot_slots() -> void:
	var cm: Node = ranch.get("casino_menu")
	(ranch.get("_game_state").get("casino") as Object).call("add_chips", 500)
	ranch.call("_on_room_requested", int((cm.get_script() as Script).get_script_constant_map().get("Row", {}).get("SLOTS", 0))) if ranch.has_method("_on_room_requested") else null
	var sm: Node = ranch.get("slots_menu")
	if sm != null and not bool(sm.call("is_open")):
		sm.call("open")
	await _frames(10)
	if sm != null:
		sm.call("confirm")
	await _seconds(2.0)


func _shot_dusk() -> void:
	await _fill_pen(0, 5, 800)
	await _fill_pen(1, 4, 820)
	_pin(WorldStateScript.Phase.DUSK, WorldStateScript.Weather.CLEAR)
	await _frames(30)
	await _move([_g(-30, 30, 9), _g(-16, 36, 7), _g(0, 38, 6)], [_g(-14, 12, 1), _g(-10, 10, 1), _g(-4, 4, 2)], 4.1, 52.0)


func _shot_delivery() -> void:
	var depot := (ranch.get_node(^"Buildings/Depot") as Node3D).global_position
	var vf: Node = ranch.get("valley_frame")
	var pl := _player()
	pl.global_position = depot + Vector3(-1.5, 0.3, 5.0)
	_hud("off")
	await _move([depot + Vector3(-4, 2.0, 9)], [depot + Vector3(0, 8, -20)], 0.3, 55.0)
	if vf != null:
		vf.call("send_up", depot + Vector3(0, 1.5, 0), Color(1.0, 0.55, 0.75), 0.9)
	await _move([depot + Vector3(-4, 2.0, 9), depot + Vector3(-4.5, 3.0, 10)],
		[depot + Vector3(0, 6, -10), depot + Vector3(0, 22, -60)], 1.8, 55.0)


func _shot_tumble() -> void:
	var people: Node = ranch.get("people")
	var t: Node3D = people.call("npc", &"tumble")
	if t == null:
		await _seconds(2.0)
		return
	t.set_physics_process(false)
	t.global_position = _g(1.0, -1.5, 0.0)
	t.rotation.y = 0.0
	if t.has_method("act"):
		t.call("act", &"sad", &"look")
	await _frames(20)
	var at := t.global_position
	await _move([at + Vector3(1.4, 0.6, 2.2), at + Vector3(0.9, 0.55, 1.9)], [at + Vector3(0, 0.6, 0)], 2.0, 34.0)


func _shot_lift() -> void:
	var vf: Node = ranch.get("valley_frame")
	var depot := (ranch.get_node(^"Buildings/Depot") as Node3D).global_position
	_dread(0.35)
	await _move([depot + Vector3(-6, 3, 8), depot + Vector3(-6, 14, 8)], [depot + Vector3(-30, 30, -80), depot + Vector3(-30, 50, -120)], 2.0, 60.0)


func _shot_dawn() -> void:
	await _fill_pen(0, 5, 950)
	_pin(WorldStateScript.Phase.DAWN, WorldStateScript.Weather.CLEAR)
	await _frames(30)
	await _move([_g(-8, 20, 3), _g(-6, 30, 7)], [_g(-14, 10, 1), _g(-12, 4, 3)], 6.0, 50.0)


func _shot_factory_room(room: StringName, seconds: float) -> void:
	var interior: Node = ranch.get("interior")
	var o: Vector3 = interior.call("room_origin", room) - Vector3(0, 0, 6.0)
	await _move([o + Vector3(1.0, 1.7, 5.0), o + Vector3(0.6, 1.7, 1.5)], [o + Vector3(0, 1.6, -4), o + Vector3(0, 1.5, -6)], seconds, 62.0)


func _shot_factory_tank() -> void:
	var interior: Node = ranch.get("interior")
	var o: Vector3 = interior.call("room_origin", &"control") - Vector3(0, 0, 6.0)
	var tank := o + Vector3(-4.86, 0, -4.4)
	await _move([tank + Vector3(2.4, 2.4, 2.2), tank + Vector3(2.0, 1.6, 2.6)], [tank + Vector3(0, 2.0, 0), tank + Vector3(0, 1.7, 0)], 1.0, 45.0)
