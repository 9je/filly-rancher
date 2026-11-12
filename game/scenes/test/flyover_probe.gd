extends SceneTree
## Review 2026-11-11: frames along the arrival flyover path (ranch.gd, "Welcome to the valley").
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
	root.get_window().size = Vector2i(1600, 900)
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
	var cam := Camera3D.new()
	ranch.add_child(cam)
	cam.fov = 50.0
	var a := Vector3(62.0, 15.0, 74.0)
	var b := Vector3(36.0, 13.0, 48.0)
	for k in [0.0, 0.5, 0.85, 1.0]:
		cam.global_position = a.lerp(b, k)
		cam.look_at(Vector3(-5.0, 5.0, 4.0))
		for i in 12:
			cam.make_current()
			await process_frame
		await _shot("fly_%d" % int(k * 100), 2)
	print("FLY_SHOT_OK")
	quit(0)
