extends SceneTree
## P8 S2 RENDER: a pen's Bloom readout (world/pen_readout.gd) with each blocking reason, and
## the gate sign at "Pen full" (playtest 2026-11-08 items 2, 9, 10, 76). On the old-save
## fixture: one pen is emptied and refilled with Drifters whose care is set by hand.
##   bloom_reasons    three bold Drifters: one hungry, one never had her favourite, one with
##                    nopony she gets on with (hungry / wants X / bored)
##   bloom_crowded    five curious Drifters join (eight in a Grand-sized pen of 8): crowded,
##                    and the gate reads "Pen full"
## Run: xvfb, -s res://scenes/test/bloom_pen_shot.gd -- --out=<dir>
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
	var inv: Inventory = ranch.call("_current_inventory")
	for id in inv.ids():
		inv.remove(id, inv.count(id))
	inv.add(&"hay", 5)
	var pen: Pen = null
	for slot in ranch.call("plot_slots"):
		var p = slot.get_built()
		if p is Pen:
			pen = p
			break
	for inst in pen.ponies():
		pen.remove_pony(inst.uid)
	pen.capacity = 8
	var bold: Array[PonyInstance] = []
	for i in 3:
		var d := _drifter(&"stock_bold", 4100 + i)
		bold.append(d)
		d.bloom = 0.2 + 0.25 * i
		pen.add_pony(d)
	var player: Node3D = ranch.get("player")
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var side: int = posmod(int(round(pen.gate_yaw_degrees / 90.0)), 4)
	var outward := Vector3(cos(float(side) * PI * 0.5), 0.0, sin(float(side) * PI * 0.5))
	player.global_position = pen.global_position + outward.rotated(Vector3.UP, 0.9) * 9.0
	var cam := Camera3D.new()
	ranch.add_child(cam)
	cam.global_position = pen.global_position + outward * 9.5 + Vector3(0, 4.2, 0)
	cam.look_at(pen.global_position + Vector3(0, 1.4, 0))
	for i in 6:
		cam.make_current()
		await process_frame
	for k in 40:
		bold[0].hunger = 0.9
		bold[1].favorite_glow = 0.0
		bold[2].favorite_glow = 120.0
		bold[2].hunger = 0.1
		cam.make_current()
		await process_frame
	for inst in pen.ponies():
		print("STATUS ", inst.uid, " ", pen.bloom_status(inst))
	await _shot("bloom_reasons", 2)
	for i in 5:
		var c := _drifter(&"stock_curious", 4200 + i)
		c.favorite_glow = 150.0
		c.bloom = 0.15 + 0.15 * i
		pen.add_pony(c)
	for k in 40:
		bold[0].hunger = 0.9
		bold[1].favorite_glow = 0.0
		cam.make_current()
		await process_frame
	for inst in pen.ponies():
		print("STATUS ", inst.uid, " ", pen.bloom_status(inst))
	print("GATE ", pen.readout.call("gate_text"))
	await _shot("bloom_crowded", 2)
	cam.global_position = pen.global_position + outward * 7.0 + Vector3(0, 3.0, 0)
	cam.look_at(pen.global_position + Vector3(0, 1.6, 0))
	for k in 6:
		cam.make_current()
		await process_frame
	await _shot("bloom_crowded_close", 2)
	quit(0)
