extends SceneTree
## P8 S2 RENDER (playtest 2026-11-08 items 14, 22): a Drifter Blooms while the player is far from
## her pen, so the objective card and the trail call her over; then she walks up and the
## ceremony plays again for her.
##   call_over_away     the player 40 m off: "<name> found her mark: come and see" and the trail
##   call_over_arrived  the player at the pen: the ceremony's sparkles, the call done
## Run: xvfb, -s res://scenes/test/call_over_shot.gd -- --out=<dir>
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
		if slot.get_built() is Pen:
			pen = slot.get_built() as Pen
			break
	var d := PonyInstanceScript.create(&"stock_curious", 990001)
	d.stock = GeneratorScript.generate(5150).to_dict()
	if pen.is_full():
		pen.remove_pony(pen.ponies()[0].uid)
	pen.add_pony(d)
	var player: Node3D = ranch.get("player")
	var bag: Storage = player.get_magic_beam().get_storage()
	while bag.count() > 0:
		bag.release()
	player.global_position = pen.global_position + Vector3(30.0, 2.0, 28.0)
	for i in 30:
		await physics_frame
	pen.bloom_now(d)
	print("CALL ", ranch.call("bloom_call"))
	await _shot("call_over_away", 60)
	print("CARD ", ranch.get_node("HUD/ObjectiveCard").get("text") if ranch.get_node_or_null("HUD/ObjectiveCard") != null else "")
	print("GOAL ", ranch.call("guide_goal"))
	player.global_position = pen.global_position + Vector3(5.5, 2.0, 2.0)
	for i in 20:
		await physics_frame
	print("CALL after ", ranch.call("bloom_call"))
	await _shot("call_over_arrived", 25)
	quit(0)
