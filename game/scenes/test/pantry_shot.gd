extends SceneTree
## ITEM 64 RENDER: the HUD's pantry row (stocked; hungry with an empty pantry) and a hungry
## resident's face, on the old-save fixture (pens with ponies).
const BootIntentScript := preload("res://world/boot_intent.gd")
const FIXTURE := "res://test/fixtures/old_save_pre_ps/slot_0.json"
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _shot(name: String, frames: int = 20) -> void:
	for i in frames:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("SHOT ", name)


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
	var inv0: Inventory = ranch.call("_current_inventory")
	inv0.add(&"hay", 6)
	for i in 70:
		await process_frame
	print("COUNTS stocked ", ranch.call("pantry_counts"))
	await _shot("hud_pantry_stocked", 60)
	var target0: Node3D = null
	for slot in ranch.call("plot_slots"):
		var pen0 = slot.get_built()
		if pen0 != null and not pen0.ponies().is_empty():
			target0 = pen0.body_for(pen0.ponies()[0].uid)
			break
	var cam := Camera3D.new()
	ranch.add_child(cam)
	var player: Node = ranch.get("player")
	player.process_mode = Node.PROCESS_MODE_DISABLED
	target0.process_mode = Node.PROCESS_MODE_DISABLED
	var fwd: Vector3 = -(target0.get_node(^"Visuals") as Node3D).global_transform.basis.z
	fwd.y = 0.0
	cam.global_position = target0.global_position + fwd.normalized() * 1.6 + Vector3(0, 1.4, 0)
	cam.look_at(target0.global_position + Vector3(0, 1.3, 0))
	for k in 3:
		cam.make_current()
		await process_frame
	target0.process_mode = Node.PROCESS_MODE_INHERIT
	for i in 40:
		cam.make_current()
		await process_frame
	print("FACE fed mood ", target0.call("_face_ref").mood)
	await _shot("face_fed", 2)
	var inv: Inventory = ranch.call("_current_inventory")
	for id in inv.ids():
		inv.remove(id, inv.count(id))
	var target: Node3D = null
	for slot in ranch.call("plot_slots"):
		var pen = slot.get_built()
		if pen == null:
			continue
		for inst in pen.ponies():
			inst.hunger = 0.85
			if target == null:
				target = pen.body_for(inst.uid)
	for i in 90:
		await process_frame
	print("COUNTS hungry ", ranch.call("pantry_counts"), " hud ", ranch.get_node("HUD").call("pantry_state"))
	await _shot("hud_pantry_hungry_empty", 10)
	cam.make_current()
	print("FACE hungry mood ", target0.call("_face_ref").mood, " hungry ", target0.call("looks_hungry"))
	await _shot("face_hungry", 2)
	cam.global_position = target0.global_position + fwd.normalized() * 7.0 + Vector3(0, 3.2, 0)
	cam.look_at(target0.global_position + Vector3(0, 1.0, 0))
	print("BUBBLE ", target0.call("hunger_bubble_shown"))
	await _shot("pen_hungry_wide", 4)
	quit(0)
