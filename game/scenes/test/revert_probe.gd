extends SceneTree
## P9 CHECK (Lane B round 3 report): does rest_till_night() revert the state? It does not.
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
	paused = false
	var gs: Node = ranch.get("_game_state")
	var econ = ranch.get("_economy")
	econ.call("grant", 30)
	var bag: Storage = ranch.get("player").call("get_magic_beam").call("get_storage")
	bag.release()
	bag.release()
	print("BEFORE bits ", ranch.call("_current_bits"), " bag ", bag.count())
	var world = ranch.call("get_world_state")
	var t: float = fposmod(world.call("elapsed"), 1200.0)
	if t > 300.0:
		world.call("advance", 1200.0 - t + 300.0)
	print("RESTED ", ranch.call("rest_till_night"))
	for i in 120:
		await process_frame
	ranch = current_scene
	bag = ranch.get("player").call("get_magic_beam").call("get_storage")
	print("AFTER bits ", ranch.call("_current_bits"), " bag ", bag.count(), " same ranch ", ranch == current_scene)
	print("REVERT_SHOT_OK")
	quit(0)
