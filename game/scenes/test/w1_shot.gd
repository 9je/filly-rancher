extends SceneTree
## P9 RENDER (playtest 2026-11-10 items 2 and 4) on the old-save fixture, the HUD up:
##   w1_rest_day      at the farmhouse door by day: "rest till nightfall"
##   w1_rest_after    after a real E press: night has fallen
##   w1_bloom_card    pens of Drifters, nothing Bloomed, the bag empty: the objective card
## Run: gpu weston, -s res://scenes/test/w1_shot.gd -- --out=<dir>
const BootIntentScript := preload("res://world/boot_intent.gd")
const GeneratorScript := preload("res://systems/pony_generator.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const FIXTURE := "res://test/fixtures/old_save_pre_ps/slot_0.json"
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _shot(shot_name: String, frames: int = 20) -> void:
	for i in frames:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join(shot_name + ".png"))
	print("SHOT ", shot_name)


func _drifter(kind: StringName, seed_value: int) -> PonyInstance:
	var inst := PonyInstanceScript.create(kind, 900000 + seed_value)
	inst.stock = GeneratorScript.generate(seed_value).to_dict()
	inst.happiness = 1.0
	inst.hunger = 0.1
	return inst


func _run() -> void:
	root.get_window().size = Vector2i(1280, 720)
	var dst := ProjectSettings.globalize_path(SaveIO.slot_path(0))
	DirAccess.make_dir_recursive_absolute(dst.get_base_dir())
	var f := FileAccess.open(dst, FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string(FIXTURE))
	f.close()
	BootIntentScript.driven = true
	change_scene_to_file("res://world/ranch.tscn")
	var ranch: Node = null
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
	var player: Node3D = ranch.get("player")
	var beam: Node = player.call("get_magic_beam")
	var storage: Storage = beam.call("get_storage") if beam != null else null
	while storage != null and storage.count() > 0:
		storage.release()
	# The story where item 2 bit: the Depot explained, nothing delivered, keepers and Drifters.
	var story: Story = ranch.call("get_story")
	for fl in ["has_scoop", "met_fennel", "depot_explained"]:
		story.set_flag(fl)
	story.deliveries = 0
	var pen: Pen = null
	for slot in ranch.call("plot_slots"):
		var p = slot.get_built()
		if p is Pen:
			pen = p
			break
	for inst in pen.ponies():
		pen.remove_pony(inst.uid)
	# Nothing Bloomed anywhere: keepers (named) may stay, Bloomed Drifters go.
	for slot in ranch.call("plot_slots"):
		var other = slot.get_built()
		if other is Pen:
			for inst in other.ponies().duplicate():
				if inst.is_stock() and inst.is_marked():
					other.remove_pony(inst.uid)
	for i in 3:
		pen.add_pony(_drifter(&"stock_curious", 6100 + i))
	player.global_position = pen.global_position + Vector3(0, 0.6, 9.0)
	for i in 120:
		await process_frame
	print("OBJECTIVE ", ranch.call("current_objective"), " bag ", storage.count())
	await _shot("w1_bloom_card", 2)
	# Day, at the farmhouse door.
	var world = ranch.call("get_world_state")
	var t: float = fposmod(world.call("elapsed"), 1200.0)
	if t > 300.0:
		world.call("advance", 1200.0 - t + 300.0)
	var door: Node3D = ranch.get_node("Buildings/Farmhouse")
	player.global_position = door.global_position + door.global_basis.z * 3.6 + Vector3(0, 0.6, 0)
	player.look_at(door.global_position, Vector3.UP)
	for i in 90:
		await process_frame
	print("CANDIDATES ", ranch.call("interaction_candidates"))
	await _shot("w1_rest_day", 2)
	Input.action_press(&"interact")
	await process_frame
	await process_frame
	Input.action_release(&"interact")
	for i in 200:
		await process_frame
	print("PHASE ", world.call("phase"))
	await _shot("w1_rest_after", 2)
	# Item 26: drawn in the Lottery, what does Tumble say now?
	for fl in ["invited", "tumble_hides", "tumble_joined"]:
		story.set_flag(fl)
	var people: Node = ranch.get("people")
	var tumble: Node3D = people.call("npc", &"tumble")
	if tumble != null:
		player.global_position = tumble.global_position + Vector3(0, 0.6, 2.4)
		player.look_at(tumble.global_position, Vector3.UP)
	for i in 30:
		await process_frame
	print("TUMBLE_TALK ", people.call("talk", "tumble"))
	await _shot("w1_tumble_after_lottery", 200)
	print("W1_SHOT_OK")
	quit(0)
