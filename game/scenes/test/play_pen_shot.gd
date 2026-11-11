extends SceneTree
## P9 RENDER (playtest 2026-11-10 item 1): play with the Drifters. On the old-save fixture one
## pen is refilled with three Drifters; the player stands at its gate, bag empty, through her
## own camera with the HUD up.
##   play_prompt   the E prompt the pen offers ("play with the Drifters")
##   play_hop_N    frames after a real E press (Input action): the hop, the prompt gone
## Run: gpu weston, -s res://scenes/test/play_pen_shot.gd -- --out=<dir>
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
	var pen: Pen = null
	for slot in ranch.call("plot_slots"):
		var p = slot.get_built()
		if p is Pen:
			pen = p
			break
	for inst in pen.ponies():
		pen.remove_pony(inst.uid)
	var ds: Array[PonyInstance] = []
	for i in 3:
		var d := _drifter(&"stock_curious", 5100 + i)
		d.bloom = 0.3 + 0.2 * i
		ds.append(d)
		pen.add_pony(d)
	# Empty the saddlebag so the pen's key is not "move her in".
	var player: Node3D = ranch.get("player")
	var beam: Node = player.call("get_magic_beam")
	var storage: Storage = beam.call("get_storage") if beam != null else null
	while storage != null and storage.count() > 0:
		storage.release()
	var side: int = posmod(int(round(pen.gate_yaw_degrees / 90.0)), 4)
	var outward := Vector3(cos(float(side) * PI * 0.5), 0.0, sin(float(side) * PI * 0.5))
	player.global_position = pen.global_position + outward * (Pen.HALF_EXTENT + 0.5) + Vector3(0, 0.5, 0)
	player.look_at(pen.global_position, Vector3.UP)
	for k in 90:
		await process_frame
	print("CANDIDATES ", ranch.call("interaction_candidates"))
	await _shot("play_prompt", 2)
	var before: Array = ds.map(func(d: PonyInstance) -> float: return d.bloom)
	Input.action_press(&"interact")
	await process_frame
	await process_frame
	Input.action_release(&"interact")
	for n in 4:
		await _shot("play_hop_%d" % n, 6)
	var after: Array = ds.map(func(d: PonyInstance) -> float: return d.bloom)
	print("BLOOM before ", before, " after ", after, " cooldown ", pen.play_cooldown_left())
	await _shot("play_after", 40)
	print("PLAY_SHOT_OK")
	quit(0)
