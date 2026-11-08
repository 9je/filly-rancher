extends SceneTree
## P8 S3 RENDER (playtest 2026-11-08 items 23, 25; ideas A1 to A3): 10 fps strips, a frame every
## six physics ticks, from a camera off to the side so both the player and the pony are in it.
##   run_*      a skittish Drifter facing the player, who RUNS at her: she bolts
##   sneak_*    another, facing away, the player WALKS up behind her: she grazes on, and the
##              beam takes her on the first hold (one clean catch)
##   bait_*     a shy Drifter; the player drops her favourite food: she comes, eats, and is
##              caught while eating
## STRIP lines in the log carry each frame's distance, her state and whether she is held.
## Run: xvfb, -s res://scenes/test/catch_strip_shot.gd -- --out=<dir>
const BootIntentScript := preload("res://world/boot_intent.gd")
const GeneratorScript := preload("res://systems/pony_generator.gd")
const PonyTraitsScript := preload("res://systems/pony_traits.gd")
const PonyScript := preload("res://actors/pony/pony.gd")
const FIXTURE := "res://test/fixtures/old_save_pre_ps/slot_0.json"
var out := ""
var ranch: Node
var player: CharacterBody3D
var cam: Camera3D


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _frame(tag: String, i: int, pony: Variant) -> void:
	root.get_texture().get_image().save_png(out.path_join("%s_%03d.png" % [tag, i]))
	var d: float = player.global_position.distance_to((pony as Node3D).global_position) if is_instance_valid(pony) else -1.0
	var st: String = PonyScript.state_name(int((pony as Node3D).get("state"))) if is_instance_valid(pony) else "CAUGHT"
	print("STRIP %s %03d d=%.1f state=%s" % [tag, i, d, st])


func _ground(x: float, z: float) -> Vector3:
	var terrain: Node = ranch.get("terrain")
	return Vector3(x, float(terrain.call("height_at", x, z)), z)


## A Drifter seed whose quirk is `want` (skittish) and personality record `kind`.
func _drifter(at: Vector3, kind: StringName, want: StringName) -> Node3D:
	var data: PonyData = load("res://data/hidden/%s.tres" % kind)
	var look: Dictionary = {}
	for s in range(1, 5000):
		look = GeneratorScript.generate(s * 13).to_dict()
		if want == &"" or PonyTraitsScript.quirk_for(look, &"") == want:
			break
	return ranch.get("spawner").call("spawn_guest", data, look, at, 9.0)


func _aim_cam(a: Vector3, b: Vector3) -> void:
	var mid := (a + b) * 0.5
	var along := (b - a)
	along.y = 0.0
	var side := along.cross(Vector3.UP).normalized()
	cam.global_position = mid + side * 9.0 + Vector3(0, 9.0, 0)
	cam.look_at(mid + Vector3(0, 0.8, 0))
	cam.make_current()


func _run() -> void:
	root.get_window().size = Vector2i(960, 540)
	var dst := ProjectSettings.globalize_path(SaveIO.slot_path(0))
	DirAccess.make_dir_recursive_absolute(dst.get_base_dir())
	var f := FileAccess.open(dst, FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string(FIXTURE))
	f.close()
	BootIntentScript.driven = true
	change_scene_to_file("res://world/ranch.tscn")
	for i in 1200:
		await process_frame
		ranch = current_scene
		if ranch != null and bool(ranch.get("boot_done")):
			break
	for i in 60:
		await process_frame
	var lp: Node = ranch.get("letter_panel")
	if lp != null and bool(lp.call("is_open")):
		lp.call("close")
	paused = false
	player = ranch.get("player")
	# Moved by hand, frame by frame, at her gait; her own physics would fight the teleports.
	player.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.get_magic_beam().process_mode = Node.PROCESS_MODE_ALWAYS
	var bag: Storage = player.get_magic_beam().get_storage()
	while bag.count() > 0:
		bag.release()
	cam = Camera3D.new()
	ranch.add_child(cam)
	# An open stretch of grass: the zone marker furthest from the homestead and the Strip.
	var best := Vector3.ZERO
	for m: Node3D in ranch.get("spawner").call("get_markers"):
		if m.global_position.length() > best.length() and absf(m.global_position.x) < 70.0 and absf(m.global_position.z) < 70.0 and m.global_position.z < 30.0:
			best = m.global_position
	var base := _ground(best.x, best.z)
	print("BASE ", base)

	# --- A: run at a skittish Drifter who faces you: she bolts --------------------------
	var a := _drifter(base, &"stock_curious", &"skittish")
	a.call("face", Vector3(0, 0, -1))
	var start := base + Vector3(0, 0, -15)
	player.global_position = start + Vector3(0, 0.3, 0)
	for i in 30:
		await physics_frame
	_aim_cam(start, base)
	for i in 24:
		player.global_position = player.global_position.move_toward(base, 5.0 / 10.0)
		for k in 6:
			await physics_frame
		_frame("run", i, a)
	# --- B: walk up behind a skittish Drifter who faces away -----------------------------
	var b_at := base + Vector3(14, 0, 0)
	b_at = _ground(b_at.x, b_at.z)
	var b := _drifter(b_at, &"stock_curious", &"skittish")
	b.call("_transition_to", PonyScript.State.GRAZE)
	b.set("_state_timer", 60.0)
	b.call("face", Vector3(0, 0, -1))
	var behind := b_at + Vector3(0, 0, 11)
	player.global_position = behind + Vector3(0, 0.3, 0)
	Input.action_press(&"sneak")
	for i in 20:
		await physics_frame
	_aim_cam(behind, b_at)
	var beam: Node3D = player.get_magic_beam()
	var caught_at := -1
	for i in 70:
		var d := player.global_position.distance_to(b.global_position) if is_instance_valid(b) else 0.0
		if d > 5.5:
			player.global_position = player.global_position.move_toward(b.global_position, 1.32 / 10.0)
		elif caught_at < 0 and is_instance_valid(b):
			caught_at = i
			beam.set("_beaming", true)
			beam.call("_begin_hold", b)
		for k in 6:
			await physics_frame
		_frame("sneak", i, b)
		if caught_at >= 0 and i > caught_at + 12:
			break
	beam.call("release")
	Input.action_release(&"sneak")
	print("SNEAK bag=", bag.count())
	# --- C: drop her favourite: she comes, eats, and is caught eating --------------------
	var c_at := _ground(base.x - 14.0, base.z)
	var c := _drifter(c_at, &"stock_shy", &"")
	var fav := PonyTraitsScript.favorite_for(c.call("get_stock"), c.call("get_data"))
	var inv: Inventory = ranch.call("_current_inventory")
	inv.add(fav, 3)
	var stand := c_at + Vector3(0, 0, 9)
	player.global_position = stand + Vector3(0, 0.3, 0)
	Input.action_press(&"sneak")
	c.call("face", Vector3(0, 0, -1))
	for i in 10:
		await physics_frame
	_aim_cam(stand, c_at)
	player.call("face", atan2(-(c_at - stand).x, -(c_at - stand).z))
	var tools: Node = ranch.get("tools")
	tools.set("_treat_cd", 0.0)
	var came: int = tools.call("toss_treat")
	print("BAIT fav=%s came=%d" % [fav, came])
	var held := false
	for i in 130:
		for k in 6:
			await physics_frame
		_frame("bait", i, c)
		if not held and is_instance_valid(c) and bool(c.call("is_eating")):
			print("BAIT eating at frame ", i)
			if i > 0:
				held = true
				beam.set("_beaming", true)
				beam.call("_begin_hold", c)
		if held and not is_instance_valid(c):
			for j in 3:
				for k in 6:
					await physics_frame
				_frame("bait", i + 1 + j, c)
			break
	Input.action_release(&"sneak")
	print("BAIT bag=", bag.count())
	quit(0)
