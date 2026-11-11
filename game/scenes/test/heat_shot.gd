extends SceneTree
## P9 RENDER (playtest 2026-11-10 items 21-23): the Rescue path after the reveal on the old-save
## fixture, at night by a pylon: the Heat gauge, the pylon prompt, and the gauge after a cut.
## Run: gpu weston, -s res://scenes/test/heat_shot.gd -- --out=<dir>
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
	var story: Story = ranch.call("get_story")
	for fl in ["has_scoop", "depot_explained", "invited", "color_day", "reveal_done", "in_factory", "color_day_done", "static_met"]:
		story.set_flag(fl)
	load("res://systems/story_v1.gd").choose_path(story, "rescue")
	story.set_var("heat", 30)
	var world = ranch.call("get_world_state")
	world.call("advance", 800.0)
	for i in 30:
		await process_frame
	var act3: Node = ranch.get("act3")
	print("ACT3 ", act3 != null)
	var player: Node3D = ranch.get("player")
	var pylon: Node3D = null
	for s in act3.get("sites"):
		if String(s.kind) == "pylon":
			pylon = s.node
			break
	player.global_position = pylon.global_position + Vector3(2.2, 0.5, 2.2)
	for i in 60:
		await process_frame
	await _shot("heat_pylon", 2)
	Input.action_press(&"interact")
	for i in 400:
		await process_frame
	Input.action_release(&"interact")
	await _shot("heat_after_cut", 60)
	print("HEAT ", load("res://systems/path_rules.gd").heat(story), " CUT ", load("res://systems/path_rules.gd").pylons_cut(story))
	# THE CORRAL (item 23): stand back from one and look.
	var corral: Node3D = null
	for s2 in act3.get("sites"):
		if String(s2.kind) == "corral":
			corral = s2.node
			break
	player.global_position = corral.global_position + Vector3(0, 0.5, 7.5)
	player.look_at(corral.global_position, Vector3.UP)
	for i in 90:
		await process_frame
	var kids := 0
	for c in corral.get_children():
		if c.has_meta(&"penned"):
			kids += 1
			print("CORRAL pony at ", c.global_position, " vis ", c.is_visible_in_tree())
	print("CORRAL ponies ", kids, " at ", corral.global_position)
	await _shot("corral_view", 2)
	print("HEAT_SHOT_OK")
	quit(0)
